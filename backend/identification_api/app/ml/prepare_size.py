"""
Script to prepare images resized and preprocessed to a specific target size (e.g., 300x300).
Maintains exact 1:1 filename correspondence with data/images/processed/ (224x224).
"""

import argparse
import hashlib
import io
import json
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from multiprocessing import cpu_count
from typing import Any, Optional

import cv2
from PIL import Image, ImageOps

from app.ml.preprocessing import (
    load_image_from_bytes,
    process_bgr_image,
)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = os.path.join(BASE_DIR, "data")
IMAGES_RAW_DIR = os.path.join(DATA_DIR, "images", "raw")
IMAGES_PROCESSED_224_DIR = os.path.join(DATA_DIR, "images", "processed")
RAW_INDEX_PATH = os.path.join(DATA_DIR, "raw_index.json")


def _get_worker_count(workers_arg: Optional[int]) -> int:
    if workers_arg is not None:
        return max(1, workers_arg)
    env_workers = os.environ.get("MAX_SYNC_WORKERS") or os.environ.get("SYNC_WORKERS")
    if env_workers:
        return max(1, int(env_workers))
    cpu_pct = float(os.environ.get("CPU_USAGE_LIMIT_PERCENT", 35))
    return max(1, int(cpu_count() * (cpu_pct / 100.0)))


def _process_single_image(raw_path: str, out_path: str, size: int) -> tuple[bool, str]:
    try:
        with open(raw_path, "rb") as f:
            file_bytes = f.read()
        bgr = load_image_from_bytes(file_bytes)
        processed = process_bgr_image(bgr, (size, size))
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        cv2.imwrite(out_path, processed)
        return True, ""
    except Exception as e:
        return False, str(e)


def run_prepare_size(
    target_size: int = 300,
    dry_run: bool = False,
    allow_subset: bool = False,
    workers: Optional[int] = None,
    out_dir: Optional[str] = None,
) -> dict[str, Any]:
    if out_dir is None:
        out_dir = os.path.join(DATA_DIR, "images", f"processed_{target_size}")

    # 1. Load raw index mapping (rel_raw_path -> full sha256)
    raw_index: dict[str, str] = {}
    if os.path.exists(RAW_INDEX_PATH):
        try:
            with open(RAW_INDEX_PATH, "r", encoding="utf-8") as f:
                raw_index = json.load(f)
        except Exception as e:
            print(f"[WARN] Could not load raw_index.json: {e}")

    # Build reverse map: (variety_class, short_sha) -> abs_raw_path
    # Also verify that the raw file actually exists on disk
    sha_to_raw_path: dict[tuple[str, str], str] = {}
    for rel_path, full_sha in raw_index.items():
        rel_norm = rel_path.replace("\\", "/")
        parts = rel_norm.split("/", 1)
        if len(parts) == 2:
            cls_name, _ = parts
            abs_raw = os.path.join(IMAGES_RAW_DIR, rel_norm.replace("/", os.sep))
            if os.path.isfile(abs_raw):
                short_sha = full_sha[:16]
                sha_to_raw_path[(cls_name, short_sha)] = abs_raw

    # 2. Inspect 224 processed folder
    classes_224 = sorted([
        d for d in os.listdir(IMAGES_PROCESSED_224_DIR)
        if os.path.isdir(os.path.join(IMAGES_PROCESSED_224_DIR, d)) and not d.startswith(".")
    ])

    report: dict[str, dict[str, Any]] = {}
    tasks: list[dict[str, Any]] = []
    missing_by_class: dict[str, list[str]] = {}
    total_224_count = 0
    total_missing_count = 0
    total_build_count = 0

    for c in classes_224:
        c_224_dir = os.path.join(IMAGES_PROCESSED_224_DIR, c)
        fnames = sorted([
            f for f in os.listdir(c_224_dir)
            if not f.startswith(".") and f.endswith(".jpg")
        ])
        total_224_count += len(fnames)

        build_for_class = 0
        missing_for_class: list[str] = []

        for fname in fnames:
            short_sha = os.path.splitext(fname)[0]
            raw_path = sha_to_raw_path.get((c, short_sha))

            if raw_path and os.path.isfile(raw_path):
                build_for_class += 1
                out_path = os.path.join(out_dir, c, fname)
                tasks.append({
                    "class": c,
                    "filename": fname,
                    "raw_path": raw_path,
                    "out_path": out_path,
                })
            else:
                missing_for_class.append(fname)

        report[c] = {
            "224_count": len(fnames),
            "will_build": build_for_class,
            "missing_raw": len(missing_for_class),
            "missing_files": missing_for_class,
        }
        missing_by_class[c] = missing_for_class
        total_missing_count += len(missing_for_class)
        total_build_count += build_for_class

    # Print Report
    print(f"\n=======================================================")
    print(f" REPORT: prepare_size --size {target_size} (dry_run={dry_run})")
    print(f" Output Target Directory: {out_dir}")
    print(f"=======================================================")
    print(f"{'Class Name':<20} | {'224 Count':<10} | {'Will Build':<10} | {'Missing Raw':<11}")
    print("-" * 60)
    for c, info in report.items():
        print(f"{c:<20} | {info['224_count']:<10} | {info['will_build']:<10} | {info['missing_raw']:<11}")
    print("-" * 60)
    print(f"{'TOTAL':<20} | {total_224_count:<10} | {total_build_count:<10} | {total_missing_count:<11}")
    print(f"=======================================================\n")

    if total_missing_count > 0:
        print(f"[ALERT] Found {total_missing_count} processed 224 image(s) with NO raw original on disk!")
        for c, m_files in missing_by_class.items():
            if m_files:
                print(f"  - {c}: {m_files[:5]}{'...' if len(m_files) > 5 else ''}")
        if not allow_subset and not dry_run:
            print("[ERROR] Aborting because missing originals exist and --allow-subset was not passed.")
            sys.exit(1)

    if dry_run:
        print("[DRY-RUN] No images were created or modified.")
        return {
            "status": "dry_run_complete",
            "report": report,
            "total_224": total_224_count,
            "total_build": total_build_count,
            "total_missing": total_missing_count,
        }

    # Check already built images
    already_built_count = 0
    tasks_to_run = []
    for t in tasks:
        if os.path.isfile(t["out_path"]) and os.path.getsize(t["out_path"]) > 0:
            already_built_count += 1
        else:
            tasks_to_run.append(t)

    num_workers = _get_worker_count(workers)
    print(f"[BUILD] {already_built_count} images already built. Building {len(tasks_to_run)} images at {target_size}x{target_size} using {num_workers} workers...")
    start_time = time.time()
    success_count = already_built_count
    fail_count = 0

    failed_tasks = []
    if tasks_to_run:
        with ProcessPoolExecutor(max_workers=num_workers) as executor:
            future_map = {
                executor.submit(_process_single_image, t["raw_path"], t["out_path"], target_size): t
                for t in tasks_to_run
            }
            for idx, fut in enumerate(as_completed(future_map), 1):
                t = future_map[fut]
                ok, err = fut.result()
                if ok:
                    success_count += 1
                else:
                    failed_tasks.append(t)
                if idx % 100 == 0 or idx == len(tasks_to_run):
                    print(f"  Processed {idx}/{len(tasks_to_run)} images...")

    if failed_tasks:
        print(f"[RETRY] Retrying {len(failed_tasks)} images sequentially to prevent memory peaks...")
        for t in failed_tasks:
            ok, err = _process_single_image(t["raw_path"], t["out_path"], target_size)
            if ok:
                success_count += 1
            else:
                fail_count += 1
                print(f"[FAIL] {t['class']}/{t['filename']}: {err}")

    elapsed = round(time.time() - start_time, 2)

    # Calculate disk usage
    total_bytes = 0
    created_files_count = 0
    for root, _, files in os.walk(out_dir):
        for f in files:
            if not f.startswith("."):
                fpath = os.path.join(root, f)
                total_bytes += os.path.getsize(fpath)
                created_files_count += 1

    disk_mb = round(total_bytes / (1024 * 1024), 2)

    # Confirm filenames match 224 set exactly
    all_matched = True
    mismatches = []
    for c in classes_224:
        c_224 = set(os.listdir(os.path.join(IMAGES_PROCESSED_224_DIR, c)))
        c_out_dir = os.path.join(out_dir, c)
        c_out = set(os.listdir(c_out_dir)) if os.path.isdir(c_out_dir) else set()
        if c_224 != c_out:
            all_matched = False
            mismatches.append(f"{c}: diff={len(c_224 ^ c_out)}")

    print(f"\n=======================================================")
    print(f" BUILD COMPLETE: {out_dir}")
    print(f"=======================================================")
    print(f" Total Images Built : {created_files_count} (Success: {success_count}, Failed: {fail_count})")
    print(f" Total Time Taken   : {elapsed} seconds ({round(created_files_count / max(0.01, elapsed), 1)} img/s)")
    print(f" Total Disk Used    : {disk_mb} MB ({total_bytes:,} bytes)")
    print(f" 1:1 Filename Match : {'CONFIRMED (100% exact match)' if all_matched else f'MISMATCH: {mismatches}'}")
    print(f"=======================================================\n")

    return {
        "status": "completed",
        "total_built": created_files_count,
        "elapsed_seconds": elapsed,
        "disk_mb": disk_mb,
        "exact_match": all_matched,
    }


def parse_args():
    parser = argparse.ArgumentParser(description="Prepare dataset at a specific target resolution.")
    parser.add_argument("--size", type=int, default=300, help="Target image size (e.g. 300)")
    parser.add_argument("--dry-run", action="store_true", help="Report counts without writing files")
    parser.add_argument("--allow-subset", action="store_true", help="Proceed even if some raw originals are missing")
    parser.add_argument("--workers", type=int, default=None, help="Worker processes for multiprocessing")
    parser.add_argument("--out-dir", type=str, default=None, help="Custom output directory")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run_prepare_size(
        target_size=args.size,
        dry_run=args.dry_run,
        allow_subset=args.allow_subset,
        workers=args.workers,
        out_dir=args.out_dir,
    )
