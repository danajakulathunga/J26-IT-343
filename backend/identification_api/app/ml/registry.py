"""
Model Registry for banana variety classification models.
Lists active, archived, and experimental versions, tracks metadata,
and manages pinned models to prevent automatic cleanup.
"""

import datetime
import json
import os
import re
import threading
from typing import Any, Optional

from app.ml.labels import VALID_RIPENESS_STAGES

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = os.path.join(BASE_DIR, "data")
ACTIVE_MODEL_DIR = os.path.join(os.path.dirname(__file__), "model")
ACTIVE_RIPENESS_DIR = os.path.join(os.path.dirname(__file__), "ripeness_model")
MODEL_VERSIONS_DIR = os.path.join(os.path.dirname(__file__), "model_versions")
RIPENESS_VERSIONS_DIR = os.path.join(os.path.dirname(__file__), "ripeness_versions")
EXPERIMENTS_DIR = os.path.join(MODEL_VERSIONS_DIR, "experiments")
PINNED_FILE_PATH = os.path.join(DATA_DIR, "pinned_versions.json")
PINNED_FILE_RIPENESS_PATH = os.path.join(DATA_DIR, "pinned_versions_ripeness.json")
TRAINING_STATE_PATH = os.path.join(DATA_DIR, "training_state.json")
TRAINING_STATE_RIPENESS_PATH = os.path.join(DATA_DIR, "training_state_ripeness.json")
PLACEHOLDER_VERSIONS_PATH = os.path.join(os.path.dirname(__file__), "placeholder_versions.json")

VERSION_ID_REGEX = re.compile(r"^[A-Za-z0-9_\-]+$")
_pinned_lock = threading.Lock()


def _get_pinned_file(task: str = "variety") -> str:
    return PINNED_FILE_RIPENESS_PATH if task == "ripeness" else PINNED_FILE_PATH


def get_pinned_versions(task: str = "variety") -> list[str]:
    """Returns list of pinned model version IDs."""
    pinned_file = _get_pinned_file(task)
    if os.path.exists(pinned_file):
        try:
            with open(pinned_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data
        except Exception:
            return []
    return []


def get_placeholder_versions() -> dict[str, list[str]]:
    """Returns mapping of task -> list of placeholder version IDs."""
    if os.path.exists(PLACEHOLDER_VERSIONS_PATH):
        try:
            with open(PLACEHOLDER_VERSIONS_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    return data
        except Exception:
            pass
    return {"variety": [], "ripeness": []}


def validate_version_id(version_id: str) -> bool:
    """Validates that a version ID matches ^[A-Za-z0-9_\\-]+$."""
    if not version_id or not isinstance(version_id, str):
        return False
    return bool(VERSION_ID_REGEX.match(version_id))


def set_pinned_version(version_id: str, pinned: bool = True, task: str = "variety") -> tuple[bool, str]:
    """Pins or unpins a model version atomically."""
    if not validate_version_id(version_id):
        return False, f"Invalid version ID '{version_id}'. Allowed characters: ^[A-Za-z0-9_\\-]+$"

    pinned_file = _get_pinned_file(task)
    with _pinned_lock:
        current_pins = set(get_pinned_versions(task))
        if pinned:
            current_pins.add(version_id)
        else:
            current_pins.discard(version_id)

        os.makedirs(DATA_DIR, exist_ok=True)
        tmp_path = f"{pinned_file}.tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(sorted(list(current_pins)), f, indent=2)
        os.replace(tmp_path, pinned_file)

    action = "pinned" if pinned else "unpinned"
    return True, f"Version '{version_id}' successfully {action}."


def _load_model_metadata(
    version_dir: str,
    default_status: str = "legacy",
    task: str = "variety",
    version_id: Optional[str] = None,
) -> dict[str, Any]:
    """Helper to inspect a version folder and read its config, metrics, and class names."""
    config_path = os.path.join(version_dir, "model_config.json")
    metrics_path = os.path.join(version_dir, "metrics.json")
    classes_path = os.path.join(version_dir, "class_names.txt")
    status_path = os.path.join(version_dir, "status.txt")

    architecture = "mobilenetv2"
    image_size: Any = [224, 224]

    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                architecture = cfg.get("architecture", architecture)
                image_size = cfg.get("image_size", image_size)
        except Exception:
            pass

    test_accuracy: Optional[float] = None
    macro_f1: Optional[float] = None
    created_date: Optional[str] = None

    is_legacy_confounded = False
    if os.path.exists(metrics_path):
        try:
            with open(metrics_path, "r", encoding="utf-8") as f:
                met = json.load(f)
                test_accuracy = met.get("test_accuracy")
                macro_f1 = met.get("macro_f1")
                created_date = met.get("training_start")

                # Addition A: compute is_legacy_confounded from real group counts regardless of split mode
                if "n_groups_per_class" in met:
                    n_groups = met.get("n_groups_per_class", {})
                    test_counts = met.get("split_metadata", {}).get("test_counts_by_class", {}) or met.get("classification_report", {})
                    test_classes = [c for c in test_counts.keys() if c in n_groups]
                    if test_classes:
                        is_legacy_confounded = any(n_groups.get(c, 0) < 3 for c in test_classes)
                    else:
                        is_legacy_confounded = any(cnt < 3 for cnt in n_groups.values())
                else:
                    # For older runs without n_groups_per_class:
                    # The test images come from classes with fewer than 3 groups (current raw data has 1 group per class)
                    is_legacy_confounded = True
        except Exception:
            pass

    if not created_date:
        try:
            created_date = datetime.datetime.fromtimestamp(os.path.getmtime(version_dir)).isoformat()
        except Exception:
            created_date = datetime.datetime.now().isoformat()

    class_names: list[str] = []
    if os.path.exists(classes_path):
        try:
            with open(classes_path, "r", encoding="utf-8") as f:
                class_names = [line.strip() for line in f if line.strip()]
        except Exception:
            pass

    # Precedence: tracked placeholder_versions.json wins; status.txt is informational only
    placeholders = get_placeholder_versions().get(task, [])
    vid = version_id or os.path.basename(version_dir)

    status = default_status
    if vid in placeholders:
        status = "placeholder"
    elif os.path.exists(status_path):
        try:
            with open(status_path, "r", encoding="utf-8") as f:
                st = f.read().strip()
                if st:
                    status = st
        except Exception:
            pass

    if status in ("placeholder", "synthetic_baseline"):
        test_accuracy = None
        macro_f1 = None

    return {
        "architecture": architecture,
        "image_size": image_size,
        "test_accuracy": test_accuracy,
        "macro_f1": macro_f1,
        "created_date": created_date,
        "class_names": class_names,
        "status": status,
        "is_legacy_confounded": is_legacy_confounded,
    }


def list_versions(include_experiments: bool = False, task: str = "variety") -> list[dict[str, Any]]:
    """
    Returns every usable model version for the given task:
    - 'active': the current model in active directory
    - 'initial': backup in versions directory initial/ (if exists)
    - Each folder in versions directory vNNNN
    - Optionally experiments in model_versions/experiments/ (variety only)
    """
    pinned_ids = set(get_pinned_versions(task))

    state_path = TRAINING_STATE_RIPENESS_PATH if task == "ripeness" else TRAINING_STATE_PATH
    active_dir = ACTIVE_RIPENESS_DIR if task == "ripeness" else ACTIVE_MODEL_DIR
    versions_dir = RIPENESS_VERSIONS_DIR if task == "ripeness" else MODEL_VERSIONS_DIR
    active_keras_candidates = (
        ["ripeness_classifier.keras", "model.keras"]
        if task == "ripeness"
        else ["variety_classifier.keras", "model.keras"]
    )

    # Get active version id from state if available
    active_version_id = "initial"
    if os.path.exists(state_path):
        try:
            with open(state_path, "r", encoding="utf-8") as f:
                st = json.load(f)
                active_version_id = st.get("active_version", "initial")
        except Exception:
            pass

    results: list[dict[str, Any]] = []

    # 1. Active model in active directory
    active_keras = None
    for cand in active_keras_candidates:
        cand_p = os.path.join(active_dir, cand)
        if os.path.exists(cand_p):
            active_keras = cand_p
            break

    if active_keras and os.path.exists(active_keras):
        meta = _load_model_metadata(active_dir, default_status="active", task=task, version_id="active")
        results.append({
            "id": "active",
            "is_active": True,
            "status": "active",
            "task": task,
            "architecture": meta["architecture"],
            "image_size": meta["image_size"],
            "class_names": meta["class_names"],
            "test_accuracy": meta["test_accuracy"],
            "macro_f1": meta["macro_f1"],
            "created_date": meta["created_date"],
            "pinned": "active" in pinned_ids,
            "available": True,
            "model_path": active_keras,
            "version_dir": active_dir,
            "underlying_version": active_version_id,
            "is_legacy_confounded": meta.get("is_legacy_confounded", False),
        })

    # 2. Initial model in versions_dir/initial/
    initial_dir = os.path.join(versions_dir, "initial")
    if os.path.isdir(initial_dir):
        keras_path = os.path.join(initial_dir, "model.keras")
        has_keras = os.path.isfile(keras_path)
        meta = _load_model_metadata(initial_dir, default_status="initial", task=task, version_id="initial")
        results.append({
            "id": "initial",
            "is_active": (active_version_id == "initial"),
            "status": "initial",
            "task": task,
            "architecture": meta["architecture"],
            "image_size": meta["image_size"],
            "class_names": meta["class_names"],
            "test_accuracy": meta["test_accuracy"],
            "macro_f1": meta["macro_f1"],
            "created_date": meta["created_date"],
            "pinned": "initial" in pinned_ids,
            "available": has_keras,
            "model_path": keras_path if has_keras else None,
            "version_dir": initial_dir,
            "is_legacy_confounded": meta.get("is_legacy_confounded", False),
        })

    # 3. Numbered versions: versions_dir/vNNNN
    if os.path.isdir(versions_dir):
        entries = sorted([
            d for d in os.listdir(versions_dir)
            if os.path.isdir(os.path.join(versions_dir, d)) and d.startswith("v")
        ], reverse=True)

        for v_name in entries:
            v_dir = os.path.join(versions_dir, v_name)
            keras_path = os.path.join(v_dir, "model.keras")
            has_keras = os.path.isfile(keras_path)
            meta = _load_model_metadata(v_dir, default_status="legacy", task=task, version_id=v_name)

            results.append({
                "id": v_name,
                "is_active": (active_version_id == v_name),
                "status": meta["status"],
                "task": task,
                "architecture": meta["architecture"],
                "image_size": meta["image_size"],
                "class_names": meta["class_names"],
                "test_accuracy": meta["test_accuracy"],
                "macro_f1": meta["macro_f1"],
                "created_date": meta["created_date"],
                "pinned": v_name in pinned_ids,
                "available": has_keras,
                "model_path": keras_path if has_keras else None,
                "version_dir": v_dir,
                "is_legacy_confounded": meta.get("is_legacy_confounded", False),
            })

    # 3b. Candidates: versions_dir/candidates/
    candidates_dir = os.path.join(versions_dir, "candidates")
    if os.path.isdir(candidates_dir):
        for c_name in sorted(os.listdir(candidates_dir)):
            c_dir = os.path.join(candidates_dir, c_name)
            if not os.path.isdir(c_dir):
                continue
            keras_path = os.path.join(c_dir, "model.keras")
            has_keras = os.path.isfile(keras_path)
            meta = _load_model_metadata(c_dir, default_status="candidate", task=task, version_id=c_name)
            # Avoid duplicate id if already present in results
            if not any(r["id"] == c_name for r in results):
                results.append({
                    "id": c_name,
                    "is_active": (active_version_id == c_name),
                    "status": "candidate",
                    "task": task,
                    "architecture": meta["architecture"],
                    "image_size": meta["image_size"],
                    "class_names": meta["class_names"],
                    "test_accuracy": meta["test_accuracy"],
                    "macro_f1": meta["macro_f1"],
                    "created_date": meta["created_date"],
                    "pinned": c_name in pinned_ids,
                    "available": has_keras,
                    "model_path": keras_path if has_keras else None,
                    "version_dir": c_dir,
                    "is_legacy_confounded": meta.get("is_legacy_confounded", False),
                })

    # 4. Optional experiments: versions_dir/experiments/ (variety only)
    experiments_dir = os.path.join(versions_dir, "experiments")
    if include_experiments and task == "variety" and os.path.isdir(experiments_dir):
        for exp_name in sorted(os.listdir(experiments_dir)):
            exp_dir = os.path.join(experiments_dir, exp_name)
            if not os.path.isdir(exp_dir):
                continue
            keras_files = []
            for root, _, files in os.walk(exp_dir):
                if "model.keras" in files:
                    keras_files.append(os.path.join(root, "model.keras"))

            for k_file in keras_files:
                parent_dir = os.path.dirname(k_file)
                try:
                    rel_id = os.path.relpath(parent_dir, versions_dir).replace("\\", "_").replace("/", "_")
                except ValueError:
                    rel_id = os.path.basename(parent_dir)
                meta = _load_model_metadata(parent_dir, default_status="experiment", task=task, version_id=exp_name)
                results.append({
                    "id": rel_id,
                    "is_active": False,
                    "status": "experiment",
                    "task": task,
                    "architecture": meta["architecture"],
                    "image_size": meta["image_size"],
                    "class_names": meta["class_names"],
                    "test_accuracy": meta["test_accuracy"],
                    "macro_f1": meta["macro_f1"],
                    "created_date": meta["created_date"],
                    "pinned": rel_id in pinned_ids,
                    "available": True,
                    "model_path": k_file,
                    "version_dir": parent_dir,
                    "is_legacy_confounded": meta.get("is_legacy_confounded", False),
                })

    return results


def resolve_version(
    version_id: Optional[str],
    include_experiments: bool = True,
    task: str = "variety",
) -> tuple[bool, Optional[dict[str, Any]], str]:
    """
    Validates and resolves a requested version ID against the registry for the given task.
    Returns: (is_valid, version_dict_or_None, error_message)
    """
    if not version_id or version_id == "active":
        # Resolve active
        versions = list_versions(task=task)
        active = next((v for v in versions if v["id"] == "active"), None)
        if active and active.get("available"):
            return True, active, ""
        return False, None, f"Active {task} model is not available."

    # Validate regex to reject any path traversal sequences
    if not VERSION_ID_REGEX.match(version_id):
        return False, None, f"Invalid version ID '{version_id}'. Format must match ^[A-Za-z0-9_\\-]+$"

    all_versions = list_versions(include_experiments=include_experiments, task=task)
    match = next((v for v in all_versions if v["id"] == version_id), None)

    if not match:
        return False, None, f"Model version '{version_id}' not found in {task} registry."

    if not match.get("available"):
        return False, None, f"Model version '{version_id}' is unavailable (weights .keras file was cleaned up)."

    return True, match, ""
