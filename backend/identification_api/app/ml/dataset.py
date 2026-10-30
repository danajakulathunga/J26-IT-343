import hashlib
import io
import json
import os
import re
import threading
from typing import Any, Optional
import cv2
from filelock import FileLock
from PIL import Image, ImageOps

from app.ml.preprocessing import (
    load_image_from_bytes,
    process_bgr_image,
    TARGET_SIZE,
)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = os.path.join(BASE_DIR, "data")
IMAGES_RAW_DIR = os.path.join(DATA_DIR, "images", "raw")
IMAGES_PROCESSED_DIR = os.path.join(DATA_DIR, "images", "processed")
HASH_INDEX_PATH = os.path.join(DATA_DIR, "image_hashes.json")
STATE_PATH = os.path.join(DATA_DIR, "training_state.json")
STATE_RIPENESS_PATH = os.path.join(DATA_DIR, "training_state_ripeness.json")
PIPELINE_LOCK_PATH = os.path.join(DATA_DIR, ".pipeline.lock")

CLASS_REGEX = re.compile(r"^[A-Za-z0-9]+_[A-Za-z0-9]+$")
MAX_FILE_SIZE = 15 * 1024 * 1024  # 15 MB
MIN_IMAGE_DIM = 100

_lock = threading.Lock()


_pipeline_lock = FileLock(PIPELINE_LOCK_PATH, timeout=60.0)


def get_pipeline_lock() -> FileLock:
    os.makedirs(DATA_DIR, exist_ok=True)
    return _pipeline_lock


def _ensure_dirs():
    os.makedirs(IMAGES_RAW_DIR, exist_ok=True)
    os.makedirs(IMAGES_PROCESSED_DIR, exist_ok=True)


def _load_hashes() -> set[str]:
    if os.path.exists(HASH_INDEX_PATH):
        try:
            with open(HASH_INDEX_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return set(data)
                elif isinstance(data, dict):
                    return set(data.keys())
        except Exception:
            return set()
    return set()


def _save_hashes(hashes: set[str]):
    with get_pipeline_lock():
        tmp_path = f"{HASH_INDEX_PATH}.tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(sorted(list(hashes)), f, indent=2)
        os.replace(tmp_path, HASH_INDEX_PATH)


def load_training_state(task: str = "variety") -> dict[str, Any]:
    with _lock:
        with get_pipeline_lock():
            state_file = STATE_RIPENESS_PATH if task == "ripeness" else STATE_PATH
            if os.path.exists(state_file):
                try:
                    with open(state_file, "r", encoding="utf-8") as f:
                        return json.load(f)
                except Exception:
                    pass
            return {
                "task": task,
                "new_images_since_last_train": 0,
                "classes": {},
                "known_classes": [],
                "history": [],
                "active_version": "initial",
                "active_metrics": {},
            }


def save_training_state(state: dict[str, Any], task: str = "variety"):
    with _lock:
        with get_pipeline_lock():
            os.makedirs(DATA_DIR, exist_ok=True)
            state_file = STATE_RIPENESS_PATH if task == "ripeness" else STATE_PATH
            tmp_path = f"{state_file}.tmp"
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(state, f, indent=2)
            os.replace(tmp_path, state_file)


def validate_variety_class(variety_class: str) -> tuple[bool, str]:
    if not variety_class or not isinstance(variety_class, str):
        return False, "Variety class name is required."
    if ".." in variety_class or "/" in variety_class or "\\" in variety_class:
        return False, "Path traversal sequences are not allowed in class name."
    if not CLASS_REGEX.match(variety_class):
        return False, "Class name must match format 'Name_Banana' (^[A-Za-z0-9]+_[A-Za-z0-9]+$)."
    return True, ""


def validate_image_file(file_bytes: bytes, filename: str) -> tuple[bool, str, str]:
    """
    Validates size, format and decodability. Returns (valid, error_reason, extension).
    """
    if len(file_bytes) > MAX_FILE_SIZE:
        return False, f"File exceeds maximum allowed size of 15MB ({len(file_bytes)} bytes).", ""

    ext = os.path.splitext(filename)[1].lower().lstrip(".")
    if not ext:
        ext = "jpg"

    allowed_exts = {"jpg", "jpeg", "png", "heic", "heif"}
    if ext not in allowed_exts:
        return False, f"Unsupported file extension '{ext}'. Allowed: jpg, jpeg, png, heic, heif.", ""

    try:
        pil_img = Image.open(io.BytesIO(file_bytes))
        width, height = pil_img.size
        if width < MIN_IMAGE_DIM or height < MIN_IMAGE_DIM:
            return False, f"Image dimensions ({width}x{height}) below minimum required ({MIN_IMAGE_DIM}x{MIN_IMAGE_DIM}).", ""
    except Exception as e:
        return False, f"Corrupted or invalid image data: {e}", ""

    return True, "", ext


from app.ml.labels import (
    extract_exif_capture_time,
    set_label,
    load_labels,
    VALID_RIPENESS_STAGES,
    RIPENESS_STAGE_SET,
    parse_filename_bunch_id,
    BUNCH_ID_REGEX,
)


def ingest(
    variety_class: str,
    file_bytes: bytes,
    original_name: str,
    stage: Optional[str] = None,
    bunch_id: Optional[str] = None,
) -> dict[str, Any]:
    """
    Ingests an image into the dataset:
    - Validates class name, stage (if given), bunch_id (if given), and image integrity
    - Priority for bunch_id: filename prefix '<bunch_id>__' > bunch_id argument
    - Deduplicates via sha256 (supports relabelling existing images if stage/bunch changed)
    - Saves raw and processed images
    - Updates labels.json and training state atomically
    """
    _ensure_dirs()

    # 1. Validate class name and stage
    valid_class, class_err = validate_variety_class(variety_class)
    if not valid_class:
        return {"status": "rejected", "file": original_name, "reason": class_err}

    if stage is not None and stage not in RIPENESS_STAGE_SET:
        return {
            "status": "rejected",
            "file": original_name,
            "reason": f"Invalid stage '{stage}'. Allowed: {VALID_RIPENESS_STAGES}",
        }

    # Determine bunch_id from filename or argument
    file_bunch = parse_filename_bunch_id(original_name)
    effective_bunch = file_bunch if file_bunch else bunch_id
    if effective_bunch is not None and not BUNCH_ID_REGEX.match(effective_bunch):
        return {
            "status": "rejected",
            "file": original_name,
            "reason": f"Invalid bunch_id '{effective_bunch}'. Must match ^[A-Za-z0-9-]+$",
        }

    # 2. Validate image
    valid_img, img_err, ext = validate_image_file(file_bytes, original_name)
    if not valid_img:
        return {"status": "rejected", "file": original_name, "reason": img_err}

    # 3. Compute sha256 & deduplicate / relabel
    sha = hashlib.sha256(file_bytes).hexdigest()
    short_sha = sha[:16]

    with _lock:
        known_hashes = _load_hashes()
        if sha in known_hashes:
            # Check if this image has a new or updated ripeness stage or bunch_id
            labels = load_labels()
            existing_rec = labels.get(short_sha, {})
            current_ripeness = existing_rec.get("ripeness")
            current_bunch = existing_rec.get("bunch_id")

            needs_update = False
            if stage is not None and current_ripeness != stage:
                needs_update = True
            if effective_bunch is not None and current_bunch != effective_bunch:
                needs_update = True

            if needs_update:
                set_label(
                    short_sha,
                    variety=variety_class,
                    ripeness=stage if stage is not None else current_ripeness,
                    bunch_id=effective_bunch if effective_bunch is not None else current_bunch,
                    label_source="ingest_relabelled",
                )
                print(f"[RELABELLED] {short_sha} updated (ripeness: '{current_ripeness}' -> '{stage}', bunch: '{current_bunch}' -> '{effective_bunch}').")
                return {
                    "status": "relabelled",
                    "file": original_name,
                    "hash": short_sha,
                    "variety_class": variety_class,
                    "ripeness": stage,
                    "bunch_id": effective_bunch,
                    "reason": "Updated label metadata without reprocessing.",
                }
            return {"status": "duplicate", "file": original_name, "hash": sha, "reason": "Already exists in dataset."}
        known_hashes.add(sha)
        _save_hashes(known_hashes)

    # Determine raw directory based on stage
    if stage:
        raw_class_dir = os.path.join(IMAGES_RAW_DIR, variety_class, stage)
    else:
        raw_class_dir = os.path.join(IMAGES_RAW_DIR, variety_class)

    proc_class_dir = os.path.join(IMAGES_PROCESSED_DIR, variety_class)
    os.makedirs(raw_class_dir, exist_ok=True)
    os.makedirs(proc_class_dir, exist_ok=True)

    # 4. Save raw
    raw_file_path = os.path.join(raw_class_dir, f"{short_sha}.{ext}")
    with open(raw_file_path, "wb") as f:
        f.write(file_bytes)

    # 5. Process and save processed (always flat 300x300 under processed/<variety>/)
    proc_file_path = os.path.join(proc_class_dir, f"{short_sha}.jpg")
    try:
        bgr = load_image_from_bytes(file_bytes)
        processed = process_bgr_image(bgr, TARGET_SIZE)
        cv2.imwrite(proc_file_path, processed)
    except Exception as e:
        # Revert hash if processing failed
        with _lock:
            known_hashes = _load_hashes()
            known_hashes.discard(sha)
            _save_hashes(known_hashes)
        return {"status": "rejected", "file": original_name, "reason": f"Processing failed: {e}"}

    # 6. Extract EXIF capture time and store in labels.json
    capture_time = extract_exif_capture_time(file_bytes)
    set_label(
        short_sha,
        variety=variety_class,
        ripeness=stage,
        bunch_id=effective_bunch,
        capture_time=capture_time,
        label_source="ingest",
    )

    # 7. Update training state atomically
    state = load_training_state()
    state["new_images_since_last_train"] = state.get("new_images_since_last_train", 0) + 1

    classes_info = state.get("classes", {})
    if variety_class not in classes_info:
        classes_info[variety_class] = {"raw_count": 0, "processed_count": 0}

    # Compute accurate raw and processed counts
    v_raw_dir = os.path.join(IMAGES_RAW_DIR, variety_class)
    classes_info[variety_class]["raw_count"] = (
        sum(len([f for f in files if not f.startswith(".")]) for _, _, files in os.walk(v_raw_dir))
        if os.path.isdir(v_raw_dir)
        else 0
    )
    classes_info[variety_class]["processed_count"] = (
        len([f for f in os.listdir(proc_class_dir) if not f.startswith(".")])
        if os.path.isdir(proc_class_dir)
        else 0
    )
    state["classes"] = classes_info

    known = set(state.get("known_classes", []))
    known.add(variety_class)
    state["known_classes"] = sorted(list(known))

    save_training_state(state)

    return {
        "status": "added",
        "file": original_name,
        "hash": short_sha,
        "variety_class": variety_class,
        "ripeness": stage,
        "raw_path": raw_file_path,
        "processed_path": proc_file_path,
    }


def get_dataset_stats() -> dict[str, Any]:
    """
    Returns current counts for raw and processed images per class,
    6x4 coverage grid for variety x stage, unlabelled count, and new images since last train.
    """
    _ensure_dirs()
    state = load_training_state()

    raw_classes = [
        d for d in os.listdir(IMAGES_RAW_DIR)
        if os.path.isdir(os.path.join(IMAGES_RAW_DIR, d)) and not d.startswith(".")
    ]
    proc_classes = [
        d for d in os.listdir(IMAGES_PROCESSED_DIR)
        if os.path.isdir(os.path.join(IMAGES_PROCESSED_DIR, d)) and not d.startswith(".")
    ]

    model_classes = state.get("active_metrics", {}).get("class_names", [])
    known_classes = [
        c for c in state.get("known_classes", [])
        if c in model_classes or c in raw_classes or c in proc_classes
    ]
    all_classes = sorted(list(set(raw_classes + proc_classes + known_classes + model_classes)))
    classes_summary = {}

    duplicates_map = {}
    sync_status_file = os.path.join(DATA_DIR, "sync_status.json")
    if os.path.exists(sync_status_file):
        try:
            with open(sync_status_file, "r", encoding="utf-8") as f:
                sync_st = json.load(f)
                ls = sync_st.get("last_summary") or sync_st.get("summary")
                if ls and isinstance(ls.get("class_stats"), dict):
                    for c_name, st in ls["class_stats"].items():
                        duplicates_map[c_name] = st.get("duplicate", 0)
        except Exception:
            pass

    for c in all_classes:
        r_dir = os.path.join(IMAGES_RAW_DIR, c)
        p_dir = os.path.join(IMAGES_PROCESSED_DIR, c)

        r_count = (
            sum(
                len([f for f in files if not f.startswith(".") and f.lower().endswith((".jpg", ".jpeg", ".png", ".heic", ".heif"))])
                for _, _, files in os.walk(r_dir)
            )
            if os.path.isdir(r_dir)
            else 0
        )
        p_count = (
            len([f for f in os.listdir(p_dir) if not f.startswith(".") and f.lower().endswith((".jpg", ".jpeg", ".png"))])
            if os.path.isdir(p_dir)
            else 0
        )
        unsynced = max(0, r_count - p_count)
        classes_summary[c] = {
            "raw_count": r_count,
            "processed_count": p_count,
            "unsynced_count": unsynced,
            "duplicates_skipped": duplicates_map.get(c, 0),
        }

    # Coverage grid & stage counts
    labels = load_labels()
    coverage_grid: dict[str, dict[str, int]] = {c: {s: 0 for s in VALID_RIPENESS_STAGES} for c in all_classes}
    stage_totals: dict[str, int] = {s: 0 for s in VALID_RIPENESS_STAGES}
    unlabeled_count = 0

    for sha16, rec in labels.items():
        v = rec.get("variety")
        r = rec.get("ripeness")
        if v in coverage_grid and r in RIPENESS_STAGE_SET:
            coverage_grid[v][r] += 1
            stage_totals[r] += 1
        else:
            unlabeled_count += 1

    return {
        "new_images_since_last_train": state.get("new_images_since_last_train", 0),
        "classes": classes_summary,
        "known_classes": all_classes,
        "total_raw": sum(info["raw_count"] for info in classes_summary.values()),
        "total_processed": sum(info["processed_count"] for info in classes_summary.values()),
        "total_unsynced": sum(info["unsynced_count"] for info in classes_summary.values()),
        "coverage_grid": coverage_grid,
        "stage_totals": stage_totals,
        "unlabeled_count": unlabeled_count,
        "total_labeled": sum(stage_totals.values()),
    }
