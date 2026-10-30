"""
Training manager: manages background training subprocesses,
evaluation, promotions, hot-reloading, rollbacks, and version retention.
Supports both 'variety' and 'ripeness' tasks.
"""

import datetime
import json
import os
import shutil
import subprocess
import sys
import threading
from typing import Any, Optional
import numpy as np

from app.ml.dataset import (
    load_training_state,
    save_training_state,
    IMAGES_PROCESSED_DIR,
)
from app.ml.labels import VALID_RIPENESS_STAGES

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
APP_ML_DIR = os.path.join(BASE_DIR, "app", "ml")
TRAIN_PIPELINE_SCRIPT = os.path.join(APP_ML_DIR, "training", "train_pipeline.py")

# Variety paths (active & versions)
ACTIVE_VARIETY_DIR = os.path.join(APP_ML_DIR, "model")
ACTIVE_VARIETY_MODEL_PATH = os.path.join(ACTIVE_VARIETY_DIR, "variety_classifier.keras")
ACTIVE_VARIETY_CLASSES_PATH = os.path.join(ACTIVE_VARIETY_DIR, "class_names.txt")
ACTIVE_VARIETY_CONFIG_PATH = os.path.join(ACTIVE_VARIETY_DIR, "model_config.json")
VARIETY_VERSIONS_DIR = os.path.join(APP_ML_DIR, "model_versions")

# Ripeness paths (active & versions)
ACTIVE_RIPENESS_DIR = os.path.join(APP_ML_DIR, "ripeness_model")
ACTIVE_RIPENESS_MODEL_PATH = os.path.join(ACTIVE_RIPENESS_DIR, "ripeness_classifier.keras")
ACTIVE_RIPENESS_CLASSES_PATH = os.path.join(ACTIVE_RIPENESS_DIR, "class_names.txt")
ACTIVE_RIPENESS_CONFIG_PATH = os.path.join(ACTIVE_RIPENESS_DIR, "model_config.json")
RIPENESS_VERSIONS_DIR = os.path.join(APP_ML_DIR, "ripeness_versions")

# Backward compatibility aliases
ACTIVE_MODEL_DIR = ACTIVE_VARIETY_DIR
ACTIVE_MODEL_PATH = ACTIVE_VARIETY_MODEL_PATH
ACTIVE_CLASSES_PATH = ACTIVE_VARIETY_CLASSES_PATH
VERSIONS_DIR = VARIETY_VERSIONS_DIR

_train_lock = threading.Lock()
_current_runs: dict[str, dict[str, Any]] = {
    "variety": {
        "status": "idle",  # idle | running | failed
        "version": None,
        "start_time": None,
        "reason": None,
    },
    "ripeness": {
        "status": "idle",
        "version": None,
        "start_time": None,
        "reason": None,
    },
}
# Backward compatibility reference
_current_run = _current_runs["variety"]


def _get_task_paths(task: str = "variety"):
    """Returns (active_dir, versions_dir, active_model_path, active_classes_path, active_config_path)."""
    if task == "ripeness":
        return (
            ACTIVE_RIPENESS_DIR,
            RIPENESS_VERSIONS_DIR,
            ACTIVE_RIPENESS_MODEL_PATH,
            ACTIVE_RIPENESS_CLASSES_PATH,
            ACTIVE_RIPENESS_CONFIG_PATH,
        )
    return (
        ACTIVE_VARIETY_DIR,
        VARIETY_VERSIONS_DIR,
        ACTIVE_VARIETY_MODEL_PATH,
        ACTIVE_VARIETY_CLASSES_PATH,
        ACTIVE_VARIETY_CONFIG_PATH,
    )


def get_training_status(task: str = "variety") -> dict[str, Any]:
    state = load_training_state(task=task)
    history = state.get("history", [])
    last_10 = list(reversed(history))[:10]
    run_info = _current_runs.get(task, _current_runs["variety"])

    # Read progress tracking file if present
    prog_path = os.path.join(BASE_DIR, "data", f"training_progress_{task}.json")
    prog_data = {}
    if os.path.exists(prog_path):
        try:
            with open(prog_path, "r", encoding="utf-8") as f:
                prog_data = json.load(f)
        except Exception:
            pass

    phase = prog_data.get("phase")
    epoch = prog_data.get("epoch")
    total_epochs = prog_data.get("total_epochs")
    version_id = prog_data.get("version_id") or run_info.get("version")

    if run_info["status"] == "running":
        if not phase or phase in ("idle", "done"):
            phase = "stage 1"
    else:
        if not phase:
            phase = "done" if history else "idle"

    active_metrics = dict(state.get("active_metrics", {}))
    if active_metrics:
        # Addition A: compute is_legacy_confounded dynamically at read time
        if "n_groups_per_class" in active_metrics:
            n_groups = active_metrics.get("n_groups_per_class", {})
            test_counts = active_metrics.get("split_metadata", {}).get("test_counts_by_class", {}) or active_metrics.get("classification_report", {})
            test_classes = [c for c in test_counts.keys() if c in n_groups]
            if test_classes:
                active_metrics["is_legacy_confounded"] = any(n_groups.get(c, 0) < 3 for c in test_classes)
            else:
                active_metrics["is_legacy_confounded"] = any(cnt < 3 for cnt in n_groups.values())
        else:
            # For older runs without n_groups_per_class: test images from classes with < 3 groups
            active_metrics["is_legacy_confounded"] = True

    return {
        "task": task,
        "status": run_info["status"],
        "phase": phase,
        "epoch": epoch,
        "total": total_epochs,
        "total_epochs": total_epochs,
        "version_id": version_id,
        "new_version_id": version_id,
        "current_run": run_info if run_info["status"] == "running" else None,
        "active_version": state.get("active_version", "initial"),
        "active_metrics": active_metrics,
        "history": last_10,
    }


def _get_next_version_name(task: str = "variety") -> str:
    _, versions_dir, _, _, _ = _get_task_paths(task)
    os.makedirs(versions_dir, exist_ok=True)
    existing = [
        d for d in os.listdir(versions_dir)
        if os.path.isdir(os.path.join(versions_dir, d)) and d.startswith("v")
    ]
    max_num = 0
    for v in existing:
        try:
            num = int(v.lstrip("v"))
            if num > max_num:
                max_num = num
        except ValueError:
            pass
    return f"v{max_num + 1:04d}"


def _cleanup_old_versions(active_version: str, task: str = "variety", dry_run: bool = True) -> list[str]:
    """
    Retention check: identifies candidate files that would be cleaned up.
    PER STRICT SYSTEM RULE: Never deletes anything; lists what the rule would remove and logs it.
    """
    _, versions_dir, _, _, _ = _get_task_paths(task)
    if not os.path.isdir(versions_dir):
        return []

    try:
        from app.ml.registry import get_pinned_versions
        pinned_ids = set(get_pinned_versions(task=task))
    except Exception:
        pinned_ids = set()

    versions = sorted([
        d for d in os.listdir(versions_dir)
        if os.path.isdir(os.path.join(versions_dir, d)) and d.startswith("v")
    ])

    if len(versions) <= 5:
        return []

    would_remove = []
    older_versions = versions[:-5]
    for v in older_versions:
        if v == active_version or v in pinned_ids:
            continue
        v_dir = os.path.join(versions_dir, v)
        keras_file = os.path.join(v_dir, "model.keras")
        if os.path.exists(keras_file):
            would_remove.append(keras_file)

    if would_remove:
        print(f"[RETENTION NOTICE] Old candidate model files that retention rule WOULD remove (no deletion performed per rule): {would_remove}")
    return would_remove


def _evaluate_active_model_on_split(candidate_metrics: dict[str, Any]) -> float:
    """
    Evaluates the currently active variety model on the candidate's test split
    to obtain a comparable baseline macro-F1 score.
    Delegates preprocessing and tensor formatting to predictor's prepare_input_tensor.
    """
    if not os.path.exists(ACTIVE_VARIETY_MODEL_PATH) or not os.path.exists(ACTIVE_VARIETY_CLASSES_PATH):
        return 0.0

    try:
        import tensorflow as tf
        from sklearn.metrics import f1_score

        with open(ACTIVE_VARIETY_CLASSES_PATH, "r", encoding="utf-8") as f:
            active_classes = [l.strip() for l in f if l.strip()]

        active_config = {"architecture": "mobilenetv2", "image_size": [300, 300]}
        if os.path.exists(ACTIVE_VARIETY_CONFIG_PATH):
            try:
                with open(ACTIVE_VARIETY_CONFIG_PATH, "r", encoding="utf-8") as f:
                    active_config = json.load(f)
            except Exception:
                pass

        active_model = tf.keras.models.load_model(ACTIVE_VARIETY_MODEL_PATH)
        candidate_classes = candidate_metrics.get("class_names", [])

        # Reconstruct test file list
        from app.ml.training.train_pipeline import get_hash_split
        from app.ml.predictor import prepare_input_tensor

        test_paths = []
        test_labels = []

        for idx, cname in enumerate(candidate_classes):
            cdir = os.path.join(IMAGES_PROCESSED_DIR, cname)
            if not os.path.isdir(cdir):
                continue
            for fname in sorted(os.listdir(cdir)):
                if not fname.startswith(".") and get_hash_split(fname) == "test":
                    test_paths.append(os.path.join(cdir, fname))
                    if cname in active_classes:
                        test_labels.append(active_classes.index(cname))
                    else:
                        test_labels.append(-1)

        valid_paths = [p for p, lbl in zip(test_paths, test_labels) if lbl >= 0]
        y_true = [lbl for lbl in test_labels if lbl >= 0]

        if not valid_paths:
            return 0.0

        # Batch inputs using the shared predictor input loader
        batch_tensors = [prepare_input_tensor(p, active_config, already_processed=True)[0] for p in valid_paths]
        batch_arr = np.array(batch_tensors, dtype=np.float32)
        preds = active_model.predict(batch_arr, batch_size=32, verbose=0)
        y_pred = [int(np.argmax(p)) for p in preds]

        return float(f1_score(y_true, y_pred, average="macro", zero_division=0))
    except Exception as e:
        print(f"Error evaluating active variety model on test split: {e}")
        return 0.0


def _evaluate_active_ripeness_on_split(candidate_metrics: dict[str, Any]) -> tuple[float, float]:
    """
    Evaluates currently active ripeness model on the candidate's test split
    using active model's preprocessing. Returns (macro_f1, quadratic_kappa).
    """
    active_model_p = ACTIVE_RIPENESS_MODEL_PATH
    if not os.path.exists(active_model_p):
        fallback = os.path.join(ACTIVE_RIPENESS_DIR, "model.keras")
        if os.path.exists(fallback):
            active_model_p = fallback
        else:
            return 0.0, 0.0

    if not os.path.exists(ACTIVE_RIPENESS_CLASSES_PATH):
        return 0.0, 0.0

    try:
        import tensorflow as tf
        from sklearn.metrics import f1_score, cohen_kappa_score
        import cv2
        from app.ml.preprocessing import process_bgr_image, to_mobilenet_input
        from app.ml.labels import load_labels
        from app.ml.training.train_pipeline import partition_dataset, RIPENESS_CLASSES

        with open(ACTIVE_RIPENESS_CLASSES_PATH, "r", encoding="utf-8") as f:
            active_classes = [l.strip() for l in f if l.strip()]

        active_config = {"architecture": "mobilenetv2", "image_size": [300, 300]}
        if os.path.exists(ACTIVE_RIPENESS_CONFIG_PATH):
            try:
                with open(ACTIVE_RIPENESS_CONFIG_PATH, "r", encoding="utf-8") as f:
                    active_config = json.load(f)
            except Exception:
                pass

        active_model = tf.keras.models.load_model(active_model_p)
        prep_mode = active_config.get("preprocessing")
        is_effnet = prep_mode == "raw_0_255" or "efficientnet" in active_config.get("architecture", "").lower()
        target_size = tuple(active_config.get("image_size", (300, 300)))

        # Load labelled records
        labels_data = load_labels()
        records = []
        for sha16, rec in labels_data.items():
            r_stage = rec.get("ripeness")
            if r_stage and r_stage in active_classes:
                v = rec.get("variety", "Unknown")
                img_path = os.path.join(IMAGES_PROCESSED_DIR, v, f"{sha16}.jpg")
                if os.path.exists(img_path):
                    records.append({
                        "sha16": sha16,
                        "filename": f"{sha16}.jpg",
                        "path": img_path,
                        "variety": v,
                        "label_name": r_stage,
                        "label_idx": active_classes.index(r_stage),
                        "bunch_id": rec.get("bunch_id"),
                        "group_id": rec.get("group_id") or rec.get("bunch_id") or f"legacy_{v}",
                    })

        split_mode = candidate_metrics.get("split_metadata", {}).get("split_strategy", "hash")
        holdout_path = os.path.join(BASE_DIR, "data", "holdout.json")
        _, _, test_recs, _ = partition_dataset(records, split_mode=split_mode, holdout_file=holdout_path)

        if not test_recs:
            return 0.0, 0.0

        from app.ml.predictor import prepare_input_tensor
        batch_tensors = [prepare_input_tensor(r["path"], active_config, already_processed=True)[0] for r in test_recs]
        batch_arr = np.array(batch_tensors, dtype=np.float32)
        preds = active_model.predict(batch_arr, batch_size=32, verbose=0)
        y_pred = [int(np.argmax(p)) for p in preds]
        y_true = [r["label_idx"] for r in test_recs]

        if not y_true:
            return 0.0, 0.0

        y_t = np.array(y_true)
        y_p = np.array(y_pred)
        f1 = float(f1_score(y_t, y_p, average="macro", zero_division=0))
        kappa = float(cohen_kappa_score(y_t, y_p, weights="quadratic"))
        return f1, kappa
    except Exception as e:
        print(f"Error evaluating active ripeness model on test split: {e}")
        return 0.0, 0.0


def check_promotion(
    version_dir: str,
    candidate_metrics: dict[str, Any],
    task: str = "variety",
) -> tuple[bool, str]:
    """
    Evaluates whether a candidate model satisfies promotion criteria.
    - Variety:
        If same classes: cand_f1 >= active_f1 - 0.005
        If changed classes/initial: cand_acc >= MIN_PROMOTE_ACCURACY (default 0.80)
    - Ripeness:
        If no active model: cand_acc >= MIN_PROMOTE_ACCURACY_RIPENESS (default 0.70)
        If active model: cand_f1 >= active_f1 - 0.005 AND cand_kappa >= active_kappa - 0.02
    """
    cand_f1 = float(candidate_metrics.get("macro_f1", 0.0))
    cand_acc = float(candidate_metrics.get("test_accuracy", 0.0))

    if task == "ripeness":
        min_promote_ripeness = float(os.environ.get("MIN_PROMOTE_ACCURACY_RIPENESS", 0.70))
        active_model_p = ACTIVE_RIPENESS_MODEL_PATH
        has_active = os.path.exists(active_model_p) or os.path.exists(os.path.join(ACTIVE_RIPENESS_DIR, "model.keras"))

        if not has_active:
            print(f"[RIPENESS PROMOTION] No active model. Candidate Acc: {cand_acc:.4f} (Required: {min_promote_ripeness})")
            if cand_acc >= min_promote_ripeness:
                return True, f"Candidate accuracy {cand_acc:.4f} >= threshold {min_promote_ripeness}."
            return False, f"Candidate accuracy {cand_acc:.4f} < threshold {min_promote_ripeness}."

        active_f1, active_kappa = _evaluate_active_ripeness_on_split(candidate_metrics)
        cand_kappa = float(candidate_metrics.get("ripeness_metrics", {}).get("quadratic_weighted_cohen_kappa", 0.0))

        print(f"[RIPENESS PROMOTION] Candidate F1: {cand_f1:.4f} vs Active F1: {active_f1:.4f}")
        print(f"[RIPENESS PROMOTION] Candidate Kappa: {cand_kappa:.4f} vs Active Kappa: {active_kappa:.4f}")

        passes_f1 = cand_f1 >= (active_f1 - 0.005)
        passes_kappa = cand_kappa >= (active_kappa - 0.02)

        if passes_f1 and passes_kappa:
            return True, f"Candidate passed F1 ({cand_f1:.4f} >= {active_f1 - 0.005:.4f}) and Kappa ({cand_kappa:.4f} >= {active_kappa - 0.02:.4f})."
        return False, f"Candidate failed promotion (F1 pass={passes_f1}, Kappa pass={passes_kappa})."

    else:
        # Variety promotion
        active_classes = []
        if os.path.exists(ACTIVE_VARIETY_CLASSES_PATH):
            with open(ACTIVE_VARIETY_CLASSES_PATH, "r", encoding="utf-8") as f:
                active_classes = [l.strip() for l in f if l.strip()]

        cand_classes = candidate_metrics.get("class_names", [])
        min_promote_acc = float(os.environ.get("MIN_PROMOTE_ACCURACY", 0.80))

        if active_classes and sorted(active_classes) == sorted(cand_classes):
            active_f1 = _evaluate_active_model_on_split(candidate_metrics)
            print(f"[VARIETY PROMOTION] Candidate F1: {cand_f1:.4f} vs Active F1: {active_f1:.4f}")
            if cand_f1 >= (active_f1 - 0.005):
                return True, f"Candidate macro-F1 {cand_f1:.4f} >= active {active_f1:.4f} - 0.005."
            return False, f"Candidate macro-F1 {cand_f1:.4f} < active {active_f1:.4f} - 0.005."
        else:
            print(f"[VARIETY PROMOTION] Initial or new classes present. Candidate Acc: {cand_acc:.4f} (Required: {min_promote_acc})")
            if cand_acc >= min_promote_acc:
                return True, f"Candidate accuracy {cand_acc:.4f} >= threshold {min_promote_acc}."
            return False, f"Candidate accuracy {cand_acc:.4f} < threshold {min_promote_acc}."


def _promote_candidate(
    version_name: str,
    version_dir: str,
    candidate_metrics: dict[str, Any],
    task: str = "variety",
):
    """
    Safely promotes a candidate model:
    1. Backs up current active model into versions directory
    2. Atomically replaces active model files
    3. Calls hot-reload on predictor
    4. Updates training state and checks retention
    """
    active_dir, versions_dir, active_model_path, active_classes_path, active_config_path = _get_task_paths(task)
    os.makedirs(active_dir, exist_ok=True)
    state = load_training_state(task=task)
    current_active_version = state.get("active_version", "initial")

    # Backup current active model if exists
    if os.path.exists(active_model_path) and os.path.exists(active_classes_path):
        backup_dir = os.path.join(versions_dir, current_active_version)
        os.makedirs(backup_dir, exist_ok=True)
        backup_model = os.path.join(backup_dir, "model.keras")
        backup_classes = os.path.join(backup_dir, "class_names.txt")
        if not os.path.exists(backup_model):
            shutil.copy2(active_model_path, backup_model)
        if not os.path.exists(backup_classes):
            shutil.copy2(active_classes_path, backup_classes)

    # Copy candidate to temp files in active_dir, then atomic os.replace
    cand_model = os.path.join(version_dir, "model.keras")
    cand_classes = os.path.join(version_dir, "class_names.txt")

    tmp_model = f"{active_model_path}.tmp"
    tmp_classes = f"{active_classes_path}.tmp"

    shutil.copy2(cand_model, tmp_model)
    shutil.copy2(cand_classes, tmp_classes)

    os.replace(tmp_model, active_model_path)
    os.replace(tmp_classes, active_classes_path)

    cand_config = os.path.join(version_dir, "model_config.json")
    if os.path.exists(cand_config):
        tmp_config = f"{active_config_path}.tmp"
        shutil.copy2(cand_config, tmp_config)
        os.replace(tmp_config, active_config_path)

    # Hot-reload in predictor
    try:
        from app.ml.predictor import reload as reload_variety, reload_ripeness
        if task == "ripeness":
            reload_ripeness()
        else:
            reload_variety()
    except Exception as e:
        print(f"Warning: hot-reloading predictor encountered error: {e}")

    # Mark candidate status as promoted
    with open(os.path.join(version_dir, "status.txt"), "w", encoding="utf-8") as f:
        f.write("promoted\n")

    state["active_version"] = version_name
    state["active_metrics"] = candidate_metrics
    state["new_images_since_last_train"] = 0
    save_training_state(state, task=task)

    _cleanup_old_versions(active_version=version_name, task=task)


def rollback_to_version(target_version: str, task: str = "variety") -> tuple[bool, str]:
    """
    Restores a chosen earlier version from versions directory as the active model.
    """
    active_dir, versions_dir, active_model_path, active_classes_path, active_config_path = _get_task_paths(task)
    run_info = _current_runs.get(task, _current_runs["variety"])

    with _train_lock:
        if run_info["status"] == "running":
            return False, f"Cannot rollback while {task} training is currently running."

        v_dir = os.path.join(versions_dir, target_version)
        if not os.path.isdir(v_dir):
            return False, f"Version directory '{target_version}' not found in {task} versions."

        v_model = os.path.join(v_dir, "model.keras")
        v_classes = os.path.join(v_dir, "class_names.txt")

        if not os.path.exists(v_model):
            return False, f"Model file model.keras missing in '{target_version}'."
        if not os.path.exists(v_classes):
            return False, f"Class names file class_names.txt missing in '{target_version}'."

        os.makedirs(active_dir, exist_ok=True)
        tmp_model = f"{active_model_path}.tmp"
        tmp_classes = f"{active_classes_path}.tmp"

        shutil.copy2(v_model, tmp_model)
        shutil.copy2(v_classes, tmp_classes)

        os.replace(tmp_model, active_model_path)
        os.replace(tmp_classes, active_classes_path)

        v_config = os.path.join(v_dir, "model_config.json")
        if os.path.exists(v_config):
            tmp_config = f"{active_config_path}.tmp"
            shutil.copy2(v_config, tmp_config)
            os.replace(tmp_config, active_config_path)

        # Reload predictor
        from app.ml.predictor import reload as reload_variety, reload_ripeness
        if task == "ripeness":
            reload_ripeness()
        else:
            reload_variety()

        # Update state
        state = load_training_state(task=task)
        state["active_version"] = target_version
        metrics_file = os.path.join(v_dir, "metrics.json")
        if os.path.exists(metrics_file):
            try:
                with open(metrics_file, "r", encoding="utf-8") as f:
                    state["active_metrics"] = json.load(f)
            except Exception:
                pass
        save_training_state(state, task=task)

        return True, f"Successfully rolled back {task} to version {target_version}."


def _run_training_worker(
    version_name: str,
    version_dir: str,
    reason: str,
    epochs1: int,
    epochs2: int,
    task: str = "variety",
    arch: Optional[str] = None,
    split: str = "hash",
    bg_swap_prob: float = 0.6,
):
    run_info = _current_runs[task]
    log_path = os.path.join(version_dir, "train.log")

    cmd = [
        sys.executable,
        TRAIN_PIPELINE_SCRIPT,
        "--out-dir", version_dir,
        "--task", task,
        "--epochs-stage1", str(epochs1),
        "--epochs-stage2", str(epochs2),
        "--split", split,
        "--bg-swap-prob", str(bg_swap_prob),
    ]
    if arch:
        cmd.extend(["--arch", arch])

    try:
        env = os.environ.copy()
        env["PYTHONPATH"] = BASE_DIR + (os.pathsep + env["PYTHONPATH"] if "PYTHONPATH" in env else "")
        with open(log_path, "w", encoding="utf-8") as log_file:
            proc = subprocess.run(
                cmd,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=BASE_DIR,
                env=env,
            )

        if proc.returncode != 0:
            print(f"Training failed for {task} {version_name} with return code {proc.returncode}")
            run_info["status"] = "failed"
            state = load_training_state(task=task)
            state.setdefault("history", []).append({
                "version": version_name,
                "status": "failed",
                "reason": reason,
                "timestamp": datetime.datetime.now().isoformat(),
            })
            save_training_state(state, task=task)
            return

        # Check metrics.json
        metrics_path = os.path.join(version_dir, "metrics.json")
        if not os.path.exists(metrics_path):
            run_info["status"] = "failed"
            return

        with open(metrics_path, "r", encoding="utf-8") as f:
            cand_metrics = json.load(f)

        cand_f1 = float(cand_metrics.get("macro_f1", 0.0))
        cand_acc = float(cand_metrics.get("test_accuracy", 0.0))

        eligible, reason_msg = check_promotion(version_dir, cand_metrics, task=task)
        status = "candidate"  # Training NEVER promotes automatically! Explicit promotion required.

        with open(os.path.join(version_dir, "status.txt"), "w", encoding="utf-8") as f:
            f.write(f"{status}\n")

        state = load_training_state(task=task)
        state["new_images_since_last_train"] = 0
        save_training_state(state, task=task)

        # Record in history
        state = load_training_state(task=task)
        history_entry = {
            "version": version_name,
            "status": status,
            "accuracy": cand_acc,
            "macro_f1": cand_f1,
            "reason": reason,
            "promotion_note": f"Candidate saved (requires explicit POST /models/{version_name}/promote). Promotion check: {reason_msg}",
            "timestamp": datetime.datetime.now().isoformat(),
        }
        if task == "ripeness":
            history_entry["quadratic_kappa"] = cand_metrics.get("ripeness_metrics", {}).get("quadratic_weighted_cohen_kappa")
            history_entry["within_one_stage_accuracy"] = cand_metrics.get("ripeness_metrics", {}).get("within_one_stage_accuracy")

        state.setdefault("history", []).append(history_entry)
        save_training_state(state, task=task)
        run_info["status"] = "idle"

        # Mark progress as done
        prog_path = os.path.join(BASE_DIR, "data", f"training_progress_{task}.json")
        try:
            with open(prog_path, "w", encoding="utf-8") as f:
                json.dump({
                    "phase": "done",
                    "epoch": epochs1 + epochs2,
                    "total_epochs": epochs1 + epochs2,
                    "version_id": version_name,
                    "task": task,
                    "updated_at": datetime.datetime.now().isoformat(),
                }, f, indent=2)
        except Exception:
            pass

    except Exception as e:
        print(f"Exception during training worker ({task}): {e}")
        run_info["status"] = "failed"
        prog_path = os.path.join(BASE_DIR, "data", f"training_progress_{task}.json")
        try:
            with open(prog_path, "w", encoding="utf-8") as f:
                json.dump({
                    "phase": "done",
                    "epoch": 0,
                    "total_epochs": epochs1 + epochs2,
                    "version_id": version_name,
                    "task": task,
                    "status": "failed",
                    "updated_at": datetime.datetime.now().isoformat(),
                }, f, indent=2)
        except Exception:
            pass
    finally:
        if run_info["status"] == "running":
            run_info["status"] = "idle"


def promote_version(version_id: str, task: str = "variety") -> tuple[bool, str]:
    """
    Explicitly promotes a candidate version to active for the specified task.
    Training NEVER promotes automatically.
    """
    if task not in ("variety", "ripeness"):
        return False, f"Invalid task '{task}'. Allowed: 'variety', 'ripeness'."

    from app.ml.registry import resolve_version
    ok, meta, err = resolve_version(version_id, include_experiments=True, task=task)
    if not ok or not meta:
        return False, f"Model version '{version_id}' not found in {task} registry: {err}"

    version_dir = meta.get("version_dir")
    if not version_dir or not os.path.isdir(version_dir):
        return False, f"Version directory for '{version_id}' not found."

    cand_model = os.path.join(version_dir, "model.keras")
    cand_classes = os.path.join(version_dir, "class_names.txt")
    if not os.path.exists(cand_model) or not os.path.exists(cand_classes):
        return False, f"Version '{version_id}' is missing model.keras or class_names.txt."

    metrics_path = os.path.join(version_dir, "metrics.json")
    cand_metrics = {}
    if os.path.exists(metrics_path):
        try:
            with open(metrics_path, "r", encoding="utf-8") as f:
                cand_metrics = json.load(f)
        except Exception:
            pass

    with _train_lock:
        _promote_candidate(version_name=version_id, version_dir=version_dir, candidate_metrics=cand_metrics, task=task)

    return True, f"Model version '{version_id}' successfully promoted to active {task} model."


def start_training(
    reason: str = "manual",
    epochs1: int = 10,
    epochs2: int = 5,
    task: str = "variety",
    arch: Optional[str] = None,
    split: str = "hash",
    bg_swap_prob: float = 0.6,
) -> tuple[bool, str]:
    """
    Initiates training for the specified task if not already running.
    """
    if task not in ("variety", "ripeness"):
        return False, f"Invalid task '{task}'. Allowed: 'variety', 'ripeness'."

    # Check if raw sync is currently running
    sync_status_path = os.path.join(BASE_DIR, "data", "sync_status.json")
    if os.path.exists(sync_status_path):
        try:
            with open(sync_status_path, "r", encoding="utf-8") as f:
                sync_st = json.load(f)
                if sync_st.get("status") == "running":
                    return False, "Cannot start training: raw folder sync is currently running."
        except Exception:
            pass

    run_info = _current_runs[task]
    with _train_lock:
        if run_info["status"] == "running":
            return False, f"Training for task '{task}' is already running."

        version_name = _get_next_version_name(task=task)
        _, versions_dir, _, _, _ = _get_task_paths(task)
        version_dir = os.path.join(versions_dir, version_name)
        os.makedirs(version_dir, exist_ok=True)

        run_info["status"] = "running"
        run_info["version"] = version_name
        run_info["start_time"] = datetime.datetime.now().isoformat()
        run_info["reason"] = reason

        prog_path = os.path.join(BASE_DIR, "data", f"training_progress_{task}.json")
        try:
            with open(prog_path, "w", encoding="utf-8") as f:
                json.dump({
                    "phase": "sync",
                    "epoch": 0,
                    "total_epochs": epochs1 + epochs2,
                    "version_id": version_name,
                    "task": task,
                    "updated_at": datetime.datetime.now().isoformat(),
                }, f, indent=2)
        except Exception:
            pass

        thread = threading.Thread(
            target=_run_training_worker,
            args=(version_name, version_dir, reason, epochs1, epochs2, task, arch, split, bg_swap_prob),
            daemon=True,
        )
        thread.start()
        return True, f"Training started for {task} version {version_name}."


def check_and_auto_trigger():
    """
    Auto trigger logic:
    If new_images_since_last_train >= RETRAIN_THRESHOLD and there are >= 2 classes with enough images,
    trigger auto training for variety.
    """
    state = load_training_state(task="variety")
    retrain_threshold = int(os.environ.get("RETRAIN_THRESHOLD", 50))
    min_images = int(os.environ.get("MIN_IMAGES_PER_CLASS", 30))

    new_images = state.get("new_images_since_last_train", 0)
    if new_images < retrain_threshold:
        return

    if not os.path.isdir(IMAGES_PROCESSED_DIR):
        return

    classes = [
        d for d in os.listdir(IMAGES_PROCESSED_DIR)
        if os.path.isdir(os.path.join(IMAGES_PROCESSED_DIR, d)) and not d.startswith(".")
    ]

    valid_classes = 0
    for c in classes:
        cdir = os.path.join(IMAGES_PROCESSED_DIR, c)
        count = len([f for f in os.listdir(cdir) if not f.startswith(".")])
        if count >= min_images:
            valid_classes += 1

    if valid_classes >= 2:
        start_training(reason="auto", task="variety")
