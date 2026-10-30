import datetime
import json
import os
import re
import subprocess
import sys
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app.ml.dataset import DATA_DIR, IMAGES_PROCESSED_DIR, get_dataset_stats, ingest
from app.ml.labels import load_labels, save_labels, VALID_RIPENESS_STAGES, RIPENESS_STAGE_SET
from app.ml.trainer import check_and_auto_trigger, get_training_status

router = APIRouter(prefix="/dataset", tags=["dataset"])
SYNC_STATUS_PATH = os.path.join(DATA_DIR, "sync_status.json")
SYNC_LOG_PATH = os.path.join(DATA_DIR, "sync.log")
_sync_process: Optional[subprocess.Popen] = None


def verify_admin_key(x_api_key: str = Header(None, alias="X-API-Key")):
    admin_key = os.environ.get("ADMIN_API_KEY")
    if not admin_key:
        raise HTTPException(
            status_code=503,
            detail="ADMIN_API_KEY environment variable is not configured on the server.",
        )
    if not x_api_key or x_api_key != admin_key:
        raise HTTPException(
            status_code=401,
            detail="Unauthorized: Invalid or missing X-API-Key header.",
        )
    return True


@router.get("/stats")
def get_stats(_: bool = Depends(verify_admin_key)):
    return get_dataset_stats()


@router.post("/upload")
async def upload_images(
    variety_class: str = Form(...),
    files: List[UploadFile] = File(...),
    ripeness: Optional[str] = Form(None),
    bunch_id: Optional[str] = Form(None),
    _: bool = Depends(verify_admin_key),
):
    if len(files) > 30:
        raise HTTPException(
            status_code=400,
            detail="Maximum 30 files allowed per upload request.",
        )

    if ripeness is not None and ripeness not in RIPENESS_STAGE_SET:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid ripeness stage '{ripeness}'. Allowed: {VALID_RIPENESS_STAGES}",
        )

    results = []
    added_count = 0

    for f in files:
        filename = f.filename or "unknown.jpg"
        content = await f.read()
        res = ingest(variety_class, content, filename, stage=ripeness, bunch_id=bunch_id)
        results.append(res)
        if res.get("status") == "added":
            added_count += 1

    # Check if threshold reached to auto-trigger retrain
    if added_count > 0:
        try:
            check_and_auto_trigger()
        except Exception as e:
            print(f"Auto-trigger check notice: {e}")

    return {
        "variety_class": variety_class,
        "total": len(files),
        "added": added_count,
        "results": results,
    }


@router.post("/sync")
def trigger_sync(
    variety_class: Optional[str] = Query(None, alias="class"),
    _: bool = Depends(verify_admin_key),
):
    global _sync_process

    # Check if subprocess is still running
    if _sync_process is not None and _sync_process.poll() is None:
        return {"status": "already running", "message": "Raw folder sync is already running."}

    # Check status file
    if os.path.exists(SYNC_STATUS_PATH):
        try:
            with open(SYNC_STATUS_PATH, "r", encoding="utf-8") as f:
                st = json.load(f)
                if st.get("status") == "running" and _sync_process is not None and _sync_process.poll() is None:
                    return {"status": "already running", "message": "Raw folder sync is already running."}
        except Exception:
            pass

    # Check if training is running
    train_status = get_training_status()
    if train_status.get("status") == "running":
        raise HTTPException(
            status_code=409,
            detail="Cannot start sync: training is currently in progress.",
        )

    cmd = [sys.executable, "-m", "app.ml.sync_raw"]
    if variety_class:
        cmd.extend(["--class", variety_class])

    os.makedirs(DATA_DIR, exist_ok=True)
    log_file = open(SYNC_LOG_PATH, "w", encoding="utf-8")
    _sync_process = subprocess.Popen(
        cmd,
        cwd=os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")),
        stdout=log_file,
        stderr=subprocess.STDOUT,
        text=True,
    )

    return {
        "status": "started",
        "message": "Raw folder sync started successfully in background.",
        "log_path": "data/sync.log",
    }


@router.get("/sync/status")
def get_sync_status(_: bool = Depends(verify_admin_key)):
    global _sync_process
    status_data = {
        "status": "idle",
        "progress": None,
        "last_summary": None,
    }

    if os.path.exists(SYNC_STATUS_PATH):
        try:
            with open(SYNC_STATUS_PATH, "r", encoding="utf-8") as f:
                saved = json.load(f)
                status_data.update(saved)
        except Exception:
            pass

    # Reconcile if subprocess completed
    if _sync_process is not None:
        poll_res = _sync_process.poll()
        if poll_res is not None and status_data.get("status") == "running":
            status_data["status"] = "idle" if poll_res == 0 else "failed"

    return status_data


class LabelUpdateItem(BaseModel):
    sha16: str
    ripeness: Optional[str] = None


@router.put("/labels")
def update_labels_batch(
    updates: List[LabelUpdateItem],
    _: bool = Depends(verify_admin_key),
):
    """
    Batch updates ripeness labels for existing images.
    Protected by admin API key.
    """
    if not updates:
        raise HTTPException(status_code=400, detail="Update batch cannot be empty.")

    # 1. Validate all items before writing
    for item in updates:
        if item.ripeness is not None and item.ripeness not in RIPENESS_STAGE_SET:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid ripeness stage '{item.ripeness}'. Allowed: {VALID_RIPENESS_STAGES}",
            )
        if not re.match(r"^[0-9a-f]{16}$", item.sha16):
            raise HTTPException(
                status_code=400,
                detail=f"Invalid image sha16 format '{item.sha16}'. Must be 16 lowercase hex characters.",
            )

    labels_data = load_labels()
    updated_ids = []

    for item in updates:
        rec = labels_data.get(item.sha16)
        if rec:
            rec["ripeness"] = item.ripeness
            rec["label_source"] = "api_put"
            rec["updated_at"] = datetime.datetime.now().isoformat()
            updated_ids.append(item.sha16)

    save_labels(labels_data)
    return {
        "success": True,
        "updated_count": len(updated_ids),
        "updated_ids": updated_ids,
    }


CLASS_REGEX = re.compile(r"^[A-Za-z0-9]+_[A-Za-z0-9]+$")


@router.get("/unlabeled")
def get_unlabeled(
    limit: int = Query(50, ge=1),
    offset: int = Query(0, ge=0),
    variety_class: Optional[str] = Query(None, alias="class"),
    _: bool = Depends(verify_admin_key),
):
    """
    Returns image IDs that currently have no ripeness label (ripeness=null).
    Results are sorted by sha16 for stable pagination.
    Optional class filter validated against ^[A-Za-z0-9]+_[A-Za-z0-9]+$.
    Protected by admin API key.
    """
    clean_class = variety_class if isinstance(variety_class, str) else None
    if clean_class is not None and not CLASS_REGEX.match(clean_class):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid class format '{clean_class}'. Must match ^[A-Za-z0-9]+_[A-Za-z0-9]+$.",
        )

    labels_data = load_labels()
    matching_ids = []
    for sha16, rec in labels_data.items():
        if rec.get("ripeness") is not None:
            continue
        if clean_class and rec.get("variety") != clean_class:
            continue
        matching_ids.append(sha16)

    # Sort stably by sha16
    matching_ids.sort()

    total_count = len(matching_ids)
    paginated = matching_ids[offset : offset + limit]

    return {
        "unlabeled": paginated,
        "total_unlabeled": total_count,
        "limit": limit,
        "offset": offset,
        "class": clean_class,
    }


@router.get("/image/{sha16}")
def get_dataset_image(
    sha16: str,
    _: bool = Depends(verify_admin_key),
):
    """
    Returns the processed JPEG for a given image sha16.
    Rejects path traversal attempts.
    Protected by admin API key.
    """
    if not re.match(r"^[0-9a-f]{16}$", sha16):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid image ID '{sha16}'. Path traversal or invalid characters detected.",
        )

    labels_data = load_labels()
    rec = labels_data.get(sha16)

    img_path = None
    if rec and rec.get("variety"):
        cand = os.path.join(IMAGES_PROCESSED_DIR, rec["variety"], f"{sha16}.jpg")
        if os.path.isfile(cand):
            img_path = cand

    if not img_path and os.path.isdir(IMAGES_PROCESSED_DIR):
        for v in os.listdir(IMAGES_PROCESSED_DIR):
            cand = os.path.join(IMAGES_PROCESSED_DIR, v, f"{sha16}.jpg")
            if os.path.isfile(cand):
                img_path = cand
                break

    if not img_path or not os.path.isfile(img_path):
        raise HTTPException(
            status_code=404,
            detail=f"Processed image for '{sha16}' not found.",
        )

    return FileResponse(img_path, media_type="image/jpeg")

