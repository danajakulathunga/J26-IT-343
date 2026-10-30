"""
Model version importer CLI.
Registers an externally trained model as a candidate version, runs the promotion check,
and promotes if and only if promotion criteria are met.
"""

import argparse
import json
import os
import shutil
import sys
from typing import Any

from app.ml.trainer import (
    _get_next_version_name,
    _get_task_paths,
    _promote_candidate,
    check_promotion,
)
from app.ml.dataset import load_training_state, save_training_state
import datetime


REQUIRED_FILES = [
    "model.keras",
    "class_names.txt",
    "model_config.json",
    "metrics.json",
]


def import_version(task: str, source_dir: str) -> dict[str, Any]:
    """
    Imports a candidate model version directory for the specified task.
    Never overwrites existing versions.
    Runs the promotion check and only promotes if criteria pass.
    """
    if task not in ("variety", "ripeness"):
        raise ValueError(f"Invalid task '{task}'. Allowed: 'variety', 'ripeness'.")

    source_dir = os.path.abspath(source_dir)
    if not os.path.isdir(source_dir):
        raise FileNotFoundError(f"Source directory '{source_dir}' does not exist.")

    # 1. Validate required files
    for fname in REQUIRED_FILES:
        fpath = os.path.join(source_dir, fname)
        if not os.path.isfile(fpath):
            raise FileNotFoundError(
                f"Required artifact '{fname}' missing from source directory: {source_dir}"
            )

    # 2. Allocate next version name in task versions directory
    _, versions_dir, _, _, _ = _get_task_paths(task)
    os.makedirs(versions_dir, exist_ok=True)
    version_name = _get_next_version_name(task=task)
    target_dir = os.path.join(versions_dir, version_name)

    if os.path.exists(target_dir):
        raise FileExistsError(f"Target version directory already exists (refusing to overwrite): {target_dir}")

    os.makedirs(target_dir, exist_ok=False)

    # 3. Copy files into target_dir
    for fname in REQUIRED_FILES:
        shutil.copy2(os.path.join(source_dir, fname), os.path.join(target_dir, fname))

    # Also copy optional files if present
    for opt_fname in ["train.log", "history.png"]:
        src_opt = os.path.join(source_dir, opt_fname)
        if os.path.isfile(src_opt):
            shutil.copy2(src_opt, os.path.join(target_dir, opt_fname))

    # 4. Load candidate metrics
    with open(os.path.join(target_dir, "metrics.json"), "r", encoding="utf-8") as f:
        cand_metrics = json.load(f)

    cand_acc = float(cand_metrics.get("test_accuracy", 0.0))
    cand_f1 = float(cand_metrics.get("macro_f1", 0.0))

    # 5. Run promotion check
    promote, reason_msg = check_promotion(target_dir, cand_metrics, task=task)
    status = "promoted" if promote else "rejected"

    with open(os.path.join(target_dir, "status.txt"), "w", encoding="utf-8") as f:
        f.write(f"{status}\n")

    if promote:
        _promote_candidate(version_name, target_dir, cand_metrics, task=task)
        print(f"[IMPORT SUCCESS] Version '{version_name}' ({task}) PASSED check and PROMOTED to active model.")
        print(f"Reason: {reason_msg}")
    else:
        state = load_training_state(task=task)
        state.setdefault("history", []).append({
            "version": version_name,
            "status": "rejected",
            "accuracy": cand_acc,
            "macro_f1": cand_f1,
            "reason": "import_version",
            "promotion_note": reason_msg,
            "timestamp": datetime.datetime.now().isoformat(),
        })
        save_training_state(state, task=task)
        print(f"[IMPORT NOTICE] Version '{version_name}' ({task}) registered as candidate but REJECTED for promotion.")
        print(f"Reason: {reason_msg}")

    return {
        "task": task,
        "version": version_name,
        "status": status,
        "promoted": promote,
        "reason": reason_msg,
        "version_dir": target_dir,
    }


def main():
    parser = argparse.ArgumentParser(description="Import an externally trained model version")
    parser.add_argument("--task", type=str, choices=["variety", "ripeness"], default="variety", help="Model task")
    parser.add_argument("--dir", type=str, required=True, help="Directory containing model artifacts")
    args = parser.parse_args()

    try:
        res = import_version(args.task, args.dir)
        print(json.dumps(res, indent=2))
    except Exception as e:
        print(f"Error importing model: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
