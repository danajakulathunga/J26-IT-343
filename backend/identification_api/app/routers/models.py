import csv
import json
import os
from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse

from app.routers.dataset import verify_admin_key
from app.ml.registry import (
    list_versions,
    resolve_version,
    set_pinned_version,
    validate_version_id,
)
from app.ml.trainer import promote_version

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ALLOWED_REPORT_IMAGES = {
    "accuracy_curve.png",
    "loss_curve.png",
    "confusion_matrix.png",
    "confusion_matrix_normalized.png",
}

router = APIRouter(prefix="/models", tags=["models"])


@router.get("", response_model=List[dict])
@router.get("/", response_model=List[dict], include_in_schema=False)
def get_models(
    include_experiments: bool = Query(False),
    task: str = Query("variety"),
    _: bool = Depends(verify_admin_key),
):
    """
    Returns list of all available and registered model versions for the specified task.
    """
    return list_versions(include_experiments=include_experiments, task=task)


@router.get("/tuning", response_model=dict)
def get_tuning_experiments(
    task: str = Query("variety"),
    _: bool = Depends(verify_admin_key),
):
    """
    Parses data/diagnostics/tuning_table.csv into JSON labelled as experiment runs.
    """
    tuning_csv_path = os.path.join("data", "diagnostics", "tuning_table.csv")
    if not os.path.exists(tuning_csv_path):
        tuning_csv_path = os.path.join(BASE_DIR, "data", "diagnostics", "tuning_table.csv")
    if not os.path.exists(tuning_csv_path):
        raise HTTPException(
            status_code=404,
            detail="Tuning table not found at data/diagnostics/tuning_table.csv",
        )

    runs = []
    winner = None
    try:
        with open(tuning_csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for idx, row in enumerate(reader):
                if not row or not row.get("run_id"):
                    continue

                def _to_float(v):
                    try:
                        return float(v)
                    except (ValueError, TypeError):
                        return None

                run_id = row.get("run_id", "").strip()
                is_winner = (idx == 0 or "baseline" in row.get("what_changed", "").lower())
                if is_winner and not winner:
                    winner = run_id

                runs.append({
                    "run_id": run_id,
                    "what_changed": row.get("what_changed", "").strip(),
                    "best_val_acc": _to_float(row.get("best_val_acc")),
                    "best_val_loss": _to_float(row.get("best_val_loss")),
                    "final_train_acc": _to_float(row.get("final_train_acc")),
                    "train_val_gap": _to_float(row.get("train_val_gap")),
                    "time": row.get("time", "").strip(),
                    "is_winner": is_winner,
                })
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to parse tuning table: {e}")

    return {
        "task": task,
        "source": "data/diagnostics/tuning_table.csv",
        "winner": winner or "T1",
        "experiment_runs": runs,
    }


@router.get("/{version_id}/report", response_model=dict)
def get_model_report(
    version_id: str,
    task: str = Query("variety"),
    _: bool = Depends(verify_admin_key),
):
    """
    Returns structured JSON performance report for a model version.
    """
    if not validate_version_id(version_id):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid model version ID '{version_id}'. Format must match ^[A-Za-z0-9_\\-]+$",
        )

    ok, meta, err = resolve_version(version_id, include_experiments=True, task=task)
    if not ok or not meta:
        raise HTTPException(
            status_code=404,
            detail=f"Model version '{version_id}' not found in {task} registry: {err}",
        )

    version_dir = meta.get("version_dir")
    if not version_dir or not os.path.isdir(version_dir):
        raise HTTPException(
            status_code=404,
            detail=f"Version directory not found for '{version_id}'.",
        )

    # Automatically generate report folder if not present
    report_dir = os.path.join(version_dir, "report")
    if not os.path.isdir(report_dir) or not os.path.exists(os.path.join(report_dir, "summary.md")):
        try:
            from app.ml.report import generate_report
            generate_report(run_dir=version_dir)
        except Exception:
            pass

    # Load config.json
    config_path = os.path.join(version_dir, "config.json")
    model_config_path = os.path.join(version_dir, "model_config.json")
    config = {}
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                config = json.load(f)
        except Exception:
            pass
    elif os.path.exists(model_config_path):
        try:
            with open(model_config_path, "r", encoding="utf-8") as f:
                config = json.load(f)
        except Exception:
            pass

    # Load metrics.json
    metrics_path = os.path.join(version_dir, "metrics.json")
    metrics = {}
    if os.path.exists(metrics_path):
        try:
            with open(metrics_path, "r", encoding="utf-8") as f:
                metrics = json.load(f)
        except Exception:
            pass

    # Load history.json
    hist_path = os.path.join(version_dir, "history.json")
    history_records = []
    if os.path.exists(hist_path):
        try:
            with open(hist_path, "r", encoding="utf-8") as f:
                history_records = json.load(f)
        except Exception:
            pass

    # Load classification_report
    rep_path = os.path.join(report_dir, "classification_report.json")
    class_rep = {}
    if os.path.exists(rep_path):
        try:
            with open(rep_path, "r", encoding="utf-8") as f:
                class_rep = json.load(f)
        except Exception:
            pass
    if not class_rep and "classification_report" in metrics:
        class_rep = metrics["classification_report"]

    # Class names
    class_names = meta.get("class_names") or config.get("classes_used") or metrics.get("class_names") or []

    # Final epoch from history
    last_hist = history_records[-1] if history_records else {}
    train_acc = last_hist.get("accuracy")
    train_loss = last_hist.get("loss")
    val_acc = last_hist.get("val_accuracy")
    val_loss = last_hist.get("val_loss")

    test_acc = metrics.get("test_accuracy")
    test_loss = metrics.get("test_loss")
    macro_f1 = metrics.get("macro_f1") or class_rep.get("macro avg", {}).get("f1-score")
    macro_prec = class_rep.get("macro avg", {}).get("precision")
    macro_rec = class_rep.get("macro avg", {}).get("recall")

    summary = {
        "train_accuracy": train_acc,
        "train_loss": train_loss,
        "val_accuracy": val_acc,
        "val_loss": val_loss,
        "test_accuracy": test_acc,
        "test_loss": test_loss,
        "macro_precision": macro_prec,
        "macro_recall": macro_rec,
        "macro_f1": macro_f1,
    }

    # Confusion matrix
    raw_cm = metrics.get("confusion_matrix") or []
    norm_cm = []
    for row in raw_cm:
        tot = sum(row)
        if tot > 0:
            norm_cm.append([round(v / tot, 4) for v in row])
        else:
            norm_cm.append([0.0 for _ in row])

    confusion_matrix_data = {
        "counts": raw_cm,
        "normalized": norm_cm,
        "class_names": class_names,
        "classes": class_names,
    }

    # History formatted
    history_formatted = []
    for r in history_records:
        history_formatted.append({
            "epoch": r.get("global_epoch"),
            "loss": r.get("loss"),
            "val_loss": r.get("val_loss"),
            "accuracy": r.get("accuracy"),
            "val_accuracy": r.get("val_accuracy"),
            "lr": r.get("learning_rate"),
            "stage": r.get("stage"),
        })

    # Config summary
    config_summary = {
        "architecture": config.get("architecture") or meta.get("architecture"),
        "image_size": config.get("image_size") or meta.get("image_size"),
        "stage_1_learning_rate": config.get("lr_stage1"),
        "stage_2_learning_rate": config.get("lr_stage2"),
        "unfrozen_layers": config.get("unfrozen_layers_count"),
        "batch_size": config.get("batch_size"),
        "seed": config.get("seed"),
        "label_smoothing": config.get("label_smoothing"),
        "dropout": config.get("dropout"),
        "split_mode": config.get("split_mode") or metrics.get("split_metadata", {}).get("split_strategy", "hash"),
    }

    # Augmentation list
    aug_list = config.get("augmentation_list")
    if not aug_list:
        aug_dict = config.get("augmentation", {})
        bg_swap = config.get("bg_swap_prob", 0.0)
        aug_list = [f"bg_swap_prob_{bg_swap}"]
        for k, v in aug_dict.items():
            if k != "bg_swap_prob":
                aug_list.append(f"{k}_{v}")

    # Evaluation label
    is_confounded = (
        meta.get("is_legacy_confounded", False)
        or metrics.get("is_legacy_confounded", False)
        or not metrics.get("generalisation_estimate_valid", True)
        or config_summary.get("split_mode") == "hash"
    )
    eval_label = (
        "same-session, not a generalisation estimate"
        if is_confounded
        else "held-out sessions"
    )

    # Background-only test result if exists
    bg_test_path = os.path.join(report_dir, "bg_corner_logistic_regression.json")
    if not os.path.exists(bg_test_path):
        bg_test_path = os.path.join(version_dir, "bg_corner_logistic_regression.json")
    bg_test_result = None
    if os.path.exists(bg_test_path):
        try:
            with open(bg_test_path, "r", encoding="utf-8") as f:
                bg_test_result = json.load(f)
        except Exception:
            pass

    return {
        "version_id": version_id,
        "task": task,
        "summary": summary,
        "classification_report": class_rep,
        "confusion_matrix": confusion_matrix_data,
        "history": history_formatted,
        "config": config_summary,
        "augmentation_list": aug_list,
        "evaluation_label": eval_label,
        "background_only_test": bg_test_result,
    }


@router.get("/{version_id}/report/image/{name}")
def get_report_image(
    version_id: str,
    name: str,
    task: str = Query("variety"),
    _: bool = Depends(verify_admin_key),
):
    """
    Serves generated report plots (accuracy_curve.png, loss_curve.png, confusion_matrix.png,
    confusion_matrix_normalized.png) from the model's report/ directory.
    Enforces whitelist and blocks path traversal.
    """
    if name not in ALLOWED_REPORT_IMAGES:
        raise HTTPException(
            status_code=400,
            detail=f"Image '{name}' not allowed. Whitelisted image names: {sorted(list(ALLOWED_REPORT_IMAGES))}",
        )

    # Path traversal defense
    if ".." in version_id or "/" in version_id or "\\" in version_id:
        raise HTTPException(status_code=400, detail="Invalid version ID path traversal attempt.")
    if ".." in name or "/" in name or "\\" in name:
        raise HTTPException(status_code=400, detail="Invalid image name path traversal attempt.")

    ok, meta, err = resolve_version(version_id, include_experiments=True, task=task)
    if not ok or not meta:
        raise HTTPException(
            status_code=404,
            detail=f"Model version '{version_id}' not found in {task} registry: {err}",
        )

    version_dir = meta.get("version_dir")
    img_path = os.path.join(version_dir, "report", name)
    if not os.path.isfile(img_path):
        raise HTTPException(
            status_code=404,
            detail=f"Image '{name}' not found for version '{version_id}'.",
        )

    return FileResponse(img_path, media_type="image/png")


@router.post("/{version_id}/promote")
def promote_model_version(
    version_id: str,
    task: str = Query("variety"),
    _: bool = Depends(verify_admin_key),
):
    """
    Explicitly promotes a candidate or legacy model version to active for the specified task.
    Training NEVER promotes automatically.
    """
    if not validate_version_id(version_id):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid model version ID '{version_id}'. Format must match ^[A-Za-z0-9_\\-]+$",
        )

    success, msg = promote_version(version_id, task=task)
    if not success:
        raise HTTPException(status_code=400, detail=msg)

    return {
        "success": True,
        "task": task,
        "promoted_version": version_id,
        "message": msg,
    }


@router.post("/{model_id}/pin")
def pin_model(
    model_id: str,
    task: str = Query("variety"),
    _: bool = Depends(verify_admin_key),
):
    """
    Pins a model version to prevent automatic retention cleanup.
    """
    if not validate_version_id(model_id):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid model version ID '{model_id}'. Must match ^[A-Za-z0-9_\\-]+$.",
        )

    ok, meta, err = resolve_version(model_id, include_experiments=True, task=task)
    if not ok or not meta:
        raise HTTPException(
            status_code=404,
            detail=f"Model version '{model_id}' not found in {task} registry: {err}",
        )

    set_pinned_version(model_id, True, task=task)
    return {
        "success": True,
        "id": model_id,
        "task": task,
        "pinned": True,
        "message": f"Model version '{model_id}' pinned successfully for {task}.",
    }


@router.delete("/{model_id}/pin")
def unpin_model(
    model_id: str,
    task: str = Query("variety"),
    _: bool = Depends(verify_admin_key),
):
    """
    Unpins a model version.
    """
    if not validate_version_id(model_id):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid model version ID '{model_id}'. Must match ^[A-Za-z0-9_\\-]+$.",
        )

    ok, meta, err = resolve_version(model_id, include_experiments=True, task=task)
    if not ok or not meta:
        raise HTTPException(
            status_code=404,
            detail=f"Model version '{model_id}' not found in {task} registry: {err}",
        )

    set_pinned_version(model_id, False, task=task)
    return {
        "success": True,
        "id": model_id,
        "task": task,
        "pinned": False,
        "message": f"Model version '{model_id}' unpinned successfully for {task}.",
    }
