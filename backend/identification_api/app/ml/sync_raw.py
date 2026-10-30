"""
Sync Raw Dataset Pipeline.
Finds raw images copied into data/images/raw/<ClassName>/, validates and
processes them using app.ml.preprocessing, updates hashes and indices,
and updates training state with newly processed counts.
"""

import argparse
import datetime
import hashlib
import io
import json
import os
import re
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from multiprocessing import cpu_count
from typing import Any, Optional

import cv2
import numpy as np
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
RAW_INDEX_PATH = os.path.join(DATA_DIR, "raw_index.json")
STATE_PATH = os.path.join(DATA_DIR, "training_state.json")
PIPELINE_LOCK_PATH = os.path.join(DATA_DIR, ".pipeline.lock")
SYNC_STATUS_PATH = os.path.join(DATA_DIR, "sync_status.json")

CLASS_REGEX = re.compile(r"^[A-Za-z0-9]+_[A-Za-z0-9]+$")
ALLOWED_EXTS = {".jpg", ".jpeg", ".png", ".heic", ".heif"}
MAX_FILE_SIZE = 15 * 1024 * 1024  # 15 MB
MIN_IMAGE_DIM = 100
CHUNK_SIZE = 50


from app.ml.dataset import get_pipeline_lock
from app.ml.labels import (
    VALID_RIPENESS_STAGES,
    RIPENESS_STAGE_SET,
    extract_exif_capture_time,
    load_labels,
    set_label,
    parse_filename_bunch_id,
)


def _load_json_file(path: str, default: Any) -> Any:
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return default
    return default


def _atomic_save_json(path: str, data: Any):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    tmp_path = f"{path}.tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp_path, path)


def load_raw_index() -> dict[str, str]:
    return _load_json_file(RAW_INDEX_PATH, {})


def save_raw_index(index: dict[str, str]):
    _atomic_save_json(RAW_INDEX_PATH, index)


def load_hashes() -> set[str]:
    data = _load_json_file(HASH_INDEX_PATH, [])
    if isinstance(data, list):
        return set(data)
    elif isinstance(data, dict):
        return set(data.keys())
    return set()


def save_hashes(hashes: set[str]):
    _atomic_save_json(HASH_INDEX_PATH, sorted(list(hashes)))


def update_sync_status(
    status: str,
    progress: Optional[dict[str, Any]] = None,
    last_summary: Optional[dict[str, Any]] = None,
):
    try:
        current = _load_json_file(SYNC_STATUS_PATH, {})
        current["status"] = status
        current["updated_at"] = datetime.datetime.now().isoformat()
        if progress is not None:
            current["progress"] = progress
        if last_summary is not None:
            current["last_summary"] = last_summary
        _atomic_save_json(SYNC_STATUS_PATH, current)
    except Exception as e:
        print(f"[WARN] Failed to write sync status: {e}")


def is_training_active() -> bool:
    """
    Checks if a training run is marked as running.
    """
    try:
        state = _load_json_file(STATE_PATH, {})
        if state.get("training_active"):
            return True
        from app.ml.trainer import _current_run
        if _current_run.get("status") == "running":
            return True
    except Exception:
        pass
    return False


# Top-level worker function for ProcessPoolExecutor (spawn-safe)
def _process_image_worker(task: dict[str, Any]) -> dict[str, Any]:
    raw_path = task["raw_path"]
    rel_raw_path = task["rel_raw_path"]
    variety_class = task["variety_class"]
    sha = task["sha"]
    short_sha = sha[:16]
    proc_path = task["proc_path"]

    try:
        with open(raw_path, "rb") as f:
            file_bytes = f.read()

        if len(file_bytes) > MAX_FILE_SIZE:
            return {
                "status": "rejected",
                "rel_path": rel_raw_path,
                "variety_class": variety_class,
                "sha": sha,
                "reason": f"File exceeds 15 MB limit ({len(file_bytes)} bytes).",
            }

        # Pillow validation & EXIF orientation
        try:
            pil_img = Image.open(io.BytesIO(file_bytes))
            pil_img = ImageOps.exif_transpose(pil_img)
            w, h = pil_img.size
            if w < MIN_IMAGE_DIM or h < MIN_IMAGE_DIM:
                return {
                    "status": "rejected",
                    "rel_path": rel_raw_path,
                    "variety_class": variety_class,
                    "sha": sha,
                    "reason": f"Image dimension too small ({w}x{h} < {MIN_IMAGE_DIM}x{MIN_IMAGE_DIM}).",
                }
        except Exception as e:
            return {
                "status": "rejected",
                "rel_path": rel_raw_path,
                "variety_class": variety_class,
                "sha": sha,
                "reason": f"Corrupted or non-decodable image: {e}",
            }

        # Preprocessing: white-padding, CLAHE on L channel, fastNlMeans denoise
        bgr = load_image_from_bytes(file_bytes)
        processed = process_bgr_image(bgr, TARGET_SIZE)

        os.makedirs(os.path.dirname(proc_path), exist_ok=True)
        cv2.imwrite(proc_path, processed)

        return {
            "status": "processed",
            "rel_path": rel_raw_path,
            "raw_path": raw_path,
            "variety_class": variety_class,
            "stage": task.get("stage"),
            "sha": sha,
            "proc_path": proc_path,
        }
    except Exception as e:
        return {
            "status": "rejected",
            "rel_path": rel_raw_path,
            "variety_class": variety_class,
            "sha": sha,
            "reason": f"Processing exception: {e}",
        }


def sync_raw(
    target_class: Optional[str] = None,
    dry_run: bool = False,
    workers: Optional[int] = None,
) -> dict[str, Any]:
    """
    Main sync logic.
    """
    start_time = time.time()
    os.makedirs(IMAGES_RAW_DIR, exist_ok=True)
    os.makedirs(IMAGES_PROCESSED_DIR, exist_ok=True)

    # 1. Mutual exclusion check
    if is_training_active():
        err_msg = "Cannot start sync: training is currently running."
        print(f"[ERROR] {err_msg}")
        return {"error": err_msg, "status": "refused"}

    update_sync_status("running", progress={"done": 0, "total": 0, "eta_seconds": 0})

    # 2. Walk raw folders
    invalid_class_folders = []
    classes_to_scan = []

    for entry in sorted(os.listdir(IMAGES_RAW_DIR)):
        entry_path = os.path.join(IMAGES_RAW_DIR, entry)
        if not os.path.isdir(entry_path):
            continue
        if not CLASS_REGEX.match(entry):
            invalid_class_folders.append(entry)
            print(f"[SKIP] Invalid class folder name: '{entry}' (must match ^[A-Za-z0-9]+_[A-Za-z0-9]+$)")
            continue
        if target_class and entry != target_class:
            continue
        classes_to_scan.append(entry)

    # Load existing state and indices
    with get_pipeline_lock():
        known_hashes = load_hashes()
        raw_index = load_raw_index()

    seen_in_walk_hashes: dict[str, str] = {}  # sha -> first rel_raw_path
    seen_hash_stages: dict[str, Optional[str]] = {}  # sha -> stage
    class_stats: dict[str, dict[str, Any]] = {}
    tasks_to_process: list[dict[str, Any]] = []
    invalid_stage_folders: list[str] = []
    conflict_reports: list[dict[str, Any]] = []
    relabelled_count = 0

    for c in classes_to_scan:
        class_stats[c] = {
            "new": 0,
            "already_synced": 0,
            "duplicate": 0,
            "relabelled": 0,
            "rejected": [],
            "ignored": 0,
        }

    # Inspect images in raw directories (supports flat files and Stage subfolders)
    for c in classes_to_scan:
        c_dir = os.path.join(IMAGES_RAW_DIR, c)
        proc_c_dir = os.path.join(IMAGES_PROCESSED_DIR, c)
        os.makedirs(proc_c_dir, exist_ok=True)

        # Build list of items to scan: (relative_folder, stage, filename)
        items_to_check: list[tuple[str, Optional[str], str]] = []

        for entry_name in sorted(os.listdir(c_dir)):
            entry_path = os.path.join(c_dir, entry_name)
            if os.path.isfile(entry_path):
                # Flat file in raw/<Class>/ -> ripeness is None
                items_to_check.append(("", None, entry_name))
            elif os.path.isdir(entry_path):
                # Subfolder: must match one of VALID_RIPENESS_STAGES exactly
                if entry_name in RIPENESS_STAGE_SET:
                    stage = entry_name
                    for sub_fname in sorted(os.listdir(entry_path)):
                        sub_fpath = os.path.join(entry_path, sub_fname)
                        if os.path.isfile(sub_fpath):
                            items_to_check.append((stage, stage, sub_fname))
                else:
                    invalid_stage_folders.append(f"{c}/{entry_name}")
                    print(f"[INVALID STAGE] Subfolder '{c}/{entry_name}' is not one of {VALID_RIPENESS_STAGES}. Ignored.")

        for sub_dir, stage, fname in items_to_check:
            if sub_dir:
                fpath = os.path.join(c_dir, sub_dir, fname)
                rel_path = f"{c}/{sub_dir}/{fname}".replace("\\", "/")
            else:
                fpath = os.path.join(c_dir, fname)
                rel_path = f"{c}/{fname}".replace("\\", "/")

            ext = os.path.splitext(fname)[1].lower()
            if ext not in ALLOWED_EXTS:
                class_stats[c]["ignored"] += 1
                continue

            # Compute sha256
            try:
                with open(fpath, "rb") as f:
                    file_bytes = f.read()
                sha = hashlib.sha256(file_bytes).hexdigest()
            except Exception as e:
                class_stats[c]["rejected"].append({"file": rel_path, "reason": f"Read error: {e}"})
                continue

            # Check if same hash was already seen in a different stage during this walk
            if sha in seen_hash_stages:
                prev_stage = seen_hash_stages[sha]
                if stage != prev_stage:
                    conflict_reports.append({
                        "file": rel_path,
                        "sha": sha[:16],
                        "first_stage": prev_stage,
                        "conflicting_stage": stage,
                    })
                    print(f"[CONFLICT] Image {rel_path} (sha: {sha[:16]}) is in two stage folders ('{prev_stage}' and '{stage}'). First stage wins.")
                    continue

            # Duplicate check in raw walk
            if sha in seen_in_walk_hashes:
                first_rel = seen_in_walk_hashes[sha]
                class_stats[c]["duplicate"] += 1
                raw_index[rel_path] = sha
                print(f"[DUPLICATE] {rel_path} has same content as {first_rel} (sha: {sha[:8]}...). Leaving raw file untouched.")
                continue

            seen_in_walk_hashes[sha] = rel_path
            seen_hash_stages[sha] = stage
            raw_index[rel_path] = sha
            short_sha = sha[:16]
            proc_path = os.path.join(proc_c_dir, f"{short_sha}.jpg")

            # Check if already synced and processed file exists
            file_bunch = parse_filename_bunch_id(fname)
            if sha in known_hashes and os.path.exists(proc_path):
                # Check for relabelling or bunch update
                labels = load_labels()
                existing_rec = labels.get(short_sha, {})
                current_ripeness = existing_rec.get("ripeness")
                current_bunch = existing_rec.get("bunch_id")
                
                needs_update = False
                if stage is not None and current_ripeness != stage:
                    needs_update = True
                if file_bunch is not None and current_bunch != file_bunch:
                    needs_update = True

                if needs_update:
                    set_label(
                        short_sha,
                        variety=c,
                        ripeness=stage if stage is not None else current_ripeness,
                        bunch_id=file_bunch if file_bunch is not None else current_bunch,
                        label_source="sync_relabelled",
                    )
                    class_stats[c]["relabelled"] += 1
                    relabelled_count += 1
                    print(f"[RELABELLED] {rel_path} ({short_sha}) updated (ripeness: '{current_ripeness}' -> '{stage}', bunch: '{current_bunch}' -> '{file_bunch}') without reprocessing.")
                else:
                    class_stats[c]["already_synced"] += 1
            else:
                tasks_to_process.append({
                    "raw_path": fpath,
                    "rel_raw_path": rel_path,
                    "variety_class": c,
                    "stage": stage,
                    "sha": sha,
                    "proc_path": proc_path,
                })

    # 3. Detect processed files whose raw source no longer exists (Report only)
    orphan_processed_files: list[str] = []
    for c in classes_to_scan:
        proc_c_dir = os.path.join(IMAGES_PROCESSED_DIR, c)
        if not os.path.isdir(proc_c_dir):
            continue
        for fname in sorted(os.listdir(proc_c_dir)):
            if not fname.endswith(".jpg"):
                continue
            short_sha = os.path.splitext(fname)[0]
            # Check if this short sha exists in seen_in_walk_hashes
            matched = any(sha.startswith(short_sha) for sha in seen_in_walk_hashes.keys())
            if not matched:
                rel_proc = os.path.join(c, fname).replace("\\", "/")
                orphan_processed_files.append(rel_proc)
                print(f"[ORPHAN NOTICE] Processed file '{rel_proc}' has no corresponding raw file in raw/{c}/. (Preserved, not deleted).")

    total_tasks = len(tasks_to_process)
    print(f"\n[SYNC SUMMARY PLAN] Found {total_tasks} images to process (dry_run={dry_run}).")

    if dry_run:
        elapsed = time.time() - start_time
        for t in tasks_to_process:
            class_stats[t["variety_class"]]["new"] += 1

        labels = load_labels()
        coverage_grid: dict[str, dict[str, int]] = {c: {s: 0 for s in VALID_RIPENESS_STAGES} for c in classes_to_scan}
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

        summary = {
            "status": "dry_run",
            "total_time_seconds": round(elapsed, 2),
            "images_per_second": 0.0,
            "total_to_process": total_tasks,
            "classes": class_stats,
            "invalid_class_folders": invalid_class_folders,
            "invalid_stage_folders": invalid_stage_folders,
            "conflict_reports": conflict_reports,
            "orphan_processed_files": orphan_processed_files,
            "coverage_grid": coverage_grid,
            "stage_totals": stage_totals,
            "unlabeled_count": unlabeled_count,
        }
        _print_summary(summary)
        update_sync_status("idle", last_summary=summary)
        return summary

    if workers is None:
        env_workers = os.environ.get("MAX_SYNC_WORKERS") or os.environ.get("SYNC_WORKERS")
        if env_workers:
            workers = max(1, int(env_workers))
        else:
            cpu_pct = float(os.environ.get("CPU_USAGE_LIMIT_PERCENT", 50))
            workers = max(1, int(cpu_count() * (cpu_pct / 100.0)))

    print(f"[SYNC] Processing with {workers} worker processes in chunks of {CHUNK_SIZE}...")
    done_count = 0
    newly_processed_count = 0
    newly_processed_by_class: dict[str, int] = {c: 0 for c in classes_to_scan}

    chunk_start_idx = 0
    while chunk_start_idx < total_tasks:
        chunk = tasks_to_process[chunk_start_idx:chunk_start_idx + CHUNK_SIZE]
        chunk_results = []

        with ProcessPoolExecutor(max_workers=workers) as executor:
            future_to_task = {executor.submit(_process_image_worker, t): t for t in chunk}
            for future in as_completed(future_to_task):
                try:
                    res = future.result()
                    chunk_results.append(res)
                except Exception as e:
                    task = future_to_task[future]
                    chunk_results.append({
                        "status": "rejected",
                        "rel_path": task["rel_raw_path"],
                        "variety_class": task["variety_class"],
                        "sha": task["sha"],
                        "reason": f"Worker crashed: {e}",
                    })

        # Process chunk results & update state atomically under FileLock
        with get_pipeline_lock():
            current_hashes = load_hashes()
            current_raw_index = load_raw_index()

            for res in chunk_results:
                done_count += 1
                c = res["variety_class"]
                sha = res["sha"]
                rel_path = res["rel_path"]

                current_raw_index[rel_path] = sha

                if res["status"] == "processed":
                    current_hashes.add(sha)
                    class_stats[c]["new"] += 1
                    newly_processed_count += 1
                    newly_processed_by_class[c] = newly_processed_by_class.get(c, 0) + 1

                    short_sha = sha[:16]
                    stage = res.get("stage")
                    raw_p = res.get("raw_path")
                    ctime = extract_exif_capture_time(raw_p) if raw_p else None
                    bunch_id = parse_filename_bunch_id(raw_p) if raw_p else None
                    set_label(short_sha, variety=c, ripeness=stage, bunch_id=bunch_id, capture_time=ctime, label_source="sync")
                elif res["status"] == "rejected":
                    class_stats[c]["rejected"].append({
                        "file": rel_path,
                        "reason": res.get("reason", "Unknown"),
                    })

            # Save state after each chunk for resume capability
            save_hashes(current_hashes)
            save_raw_index(current_raw_index)

            # Update training state
            if newly_processed_count > 0:
                from app.ml.dataset import load_training_state, save_training_state
                state = load_training_state()
                state["new_images_since_last_train"] = state.get("new_images_since_last_train", 0) + sum(
                    newly_processed_by_class.values()
                )
                classes_info = state.get("classes", {})
                for c in classes_to_scan:
                    r_dir = os.path.join(IMAGES_RAW_DIR, c)
                    p_dir = os.path.join(IMAGES_PROCESSED_DIR, c)
                    classes_info[c] = {
                        "raw_count": len([f for f in os.listdir(r_dir) if not f.startswith(".")]) if os.path.isdir(r_dir) else 0,
                        "processed_count": len([f for f in os.listdir(p_dir) if not f.startswith(".")]) if os.path.isdir(p_dir) else 0,
                    }
                state["classes"] = classes_info
                state["known_classes"] = sorted(list(set(state.get("known_classes", []) + classes_to_scan)))
                save_training_state(state)
                # Reset chunk counter
                for c in classes_to_scan:
                    newly_processed_by_class[c] = 0

        # Calculate progress & ETA
        elapsed_now = max(0.001, time.time() - start_time)
        rate = done_count / elapsed_now
        remaining_tasks = total_tasks - done_count
        eta_seconds = int(remaining_tasks / rate) if rate > 0 else 0

        progress_info = {
            "done": done_count,
            "total": total_tasks,
            "speed_ips": round(rate, 2),
            "eta_seconds": eta_seconds,
        }
        update_sync_status("running", progress=progress_info)

        pct = (done_count / total_tasks) * 100 if total_tasks > 0 else 100.0
        print(f"[SYNC] Progress: {done_count}/{total_tasks} ({pct:.1f}%) - Speed: {rate:.2f} img/s - ETA: {eta_seconds}s")

        chunk_start_idx += CHUNK_SIZE

    # Final summary calculation
    elapsed_total = max(0.001, time.time() - start_time)
    speed = done_count / elapsed_total

    # Compute coverage grid and stage totals
    labels = load_labels()
    coverage_grid: dict[str, dict[str, int]] = {c: {s: 0 for s in VALID_RIPENESS_STAGES} for c in classes_to_scan}
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

    summary = {
        "status": "completed",
        "total_time_seconds": round(elapsed_total, 2),
        "images_per_second": round(speed, 2),
        "total_new": sum(s["new"] for s in class_stats.values()),
        "total_already_synced": sum(s["already_synced"] for s in class_stats.values()),
        "total_duplicate": sum(s["duplicate"] for s in class_stats.values()),
        "total_relabelled": relabelled_count,
        "total_rejected": sum(len(s["rejected"]) for s in class_stats.values()),
        "total_ignored": sum(s["ignored"] for s in class_stats.values()),
        "classes": class_stats,
        "invalid_class_folders": invalid_class_folders,
        "invalid_stage_folders": invalid_stage_folders,
        "conflict_reports": conflict_reports,
        "orphan_processed_files": orphan_processed_files,
        "coverage_grid": coverage_grid,
        "stage_totals": stage_totals,
        "unlabeled_count": unlabeled_count,
    }

    _print_summary(summary)
    update_sync_status("idle", progress={"done": total_tasks, "total": total_tasks, "eta_seconds": 0}, last_summary=summary)
    return summary


def _print_summary(summary: dict[str, Any]):
    print("\n" + "=" * 75)
    print("                    RAW DATASET SYNC SUMMARY")
    print("=" * 75)
    print(f"Status:            {summary.get('status')}")
    print(f"Total Time:        {summary.get('total_time_seconds')}s")
    print(f"Throughput:        {summary.get('images_per_second')} img/s")
    if "total_new" in summary:
        print(f"Total New:         {summary.get('total_new')}")
        print(f"Already Synced:    {summary.get('total_already_synced')}")
        print(f"Relabelled:        {summary.get('total_relabelled', 0)}")
        print(f"Duplicates:        {summary.get('total_duplicate')}")
        print(f"Rejected:          {summary.get('total_rejected')}")
        print(f"Ignored:           {summary.get('total_ignored')}")
    print("-" * 75)
    print(f"{'Class Name':<20} {'New':<6} {'Synced':<8} {'Relab':<6} {'Dup':<6} {'Rej':<6} {'Ign':<6}")
    print("-" * 75)
    for c, stats in summary.get("classes", {}).items():
        print(f"{c:<20} {stats.get('new', 0):<6} {stats.get('already_synced', 0):<8} {stats.get('relabelled', 0):<6} {stats.get('duplicate', 0):<6} {len(stats.get('rejected', [])):<6} {stats.get('ignored', 0):<6}")
    print("=" * 75)

    cov = summary.get("coverage_grid", {})
    if cov:
        print("\n6x4 RIPENESS COVERAGE GRID (Variety x Stage):")
        print(f"{'Variety':<20} {'Green':<10} {'Turning':<10} {'Ripe':<10} {'Overripe':<10}")
        print("-" * 65)
        for c, st_counts in cov.items():
            print(f"{c:<20} {st_counts.get('Green', 0):<10} {st_counts.get('Turning', 0):<10} {st_counts.get('Ripe', 0):<10} {st_counts.get('Overripe', 0):<10}")
        print("-" * 65)
        st_tot = summary.get("stage_totals", {})
        print(f"{'TOTAL LABELED':<20} {st_tot.get('Green', 0):<10} {st_tot.get('Turning', 0):<10} {st_tot.get('Ripe', 0):<10} {st_tot.get('Overripe', 0):<10}")
        print(f"Unlabeled Images:  {summary.get('unlabeled_count', 0)}")
        print("=" * 75)

    if summary.get("invalid_class_folders"):
        print(f"Invalid Class Folders Skipped: {summary['invalid_class_folders']}")
    if summary.get("invalid_stage_folders"):
        print(f"Invalid Stage Folders Skipped: {summary['invalid_stage_folders']}")
    if summary.get("conflict_reports"):
        print(f"Stage Conflict Reports ({len(summary['conflict_reports'])}): {summary['conflict_reports']}")
    if summary.get("orphan_processed_files"):
        print(f"Reported Orphan Processed Files: {len(summary['orphan_processed_files'])} file(s)")
    print()


def main():
    parser = argparse.ArgumentParser(description="Sync raw banana variety images into processed training set.")
    parser.add_argument("--class", dest="variety_class", type=str, default=None, help="Sync specific class folder only")
    parser.add_argument("--dry-run", action="store_true", help="Report what would be processed without altering data")
    parser.add_argument("--workers", type=int, default=None, help="Number of worker processes")
    args = parser.parse_args()

    sync_raw(target_class=args.variety_class, dry_run=args.dry_run, workers=args.workers)


if __name__ == "__main__":
    main()
