"""
Generate Parallel Processed Dataset with Background Removal.

Processes raw images from data/images/raw/<Class>/ into
data/images/processed_bg/<Class>/<short_sha>.jpg
by applying remove_background(enabled=True) followed by the standard
process_bgr_image(TARGET_SIZE) pipeline.

Never touches or overwrites data/images/processed/.
"""

import argparse
import hashlib
import os
import sys
import time
from typing import Any, Optional

import cv2

from app.ml.background_removal import remove_background
from app.ml.preprocessing import (
    TARGET_SIZE,
    load_image_from_bytes,
    process_bgr_image,
)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_RAW_DIR = os.path.join(BASE_DIR, "data", "images", "raw")
DEFAULT_OUT_DIR = os.path.join(BASE_DIR, "data", "images", "processed_bg")
ALLOWED_EXTS = {".jpg", ".jpeg", ".png", ".heic", ".heif"}


def process_single_image(
    file_bytes: bytes,
    target_size: tuple[int, int] = TARGET_SIZE,
) -> tuple[str, Any]:
    """
    Computes short sha256 (16 chars), applies background removal on white background,
    and runs the standard preprocessing pipeline (aspect resize + white pad, CLAHE, denoise).
    Returns (short_sha, processed_bgr).
    """
    sha = hashlib.sha256(file_bytes).hexdigest()
    short_sha = sha[:16]

    bgr = load_image_from_bytes(file_bytes)
    bg_removed = remove_background(bgr, enabled=True)
    processed = process_bgr_image(bg_removed, target_size)
    return short_sha, processed


def generate_processed_bg(
    raw_dir: str = DEFAULT_RAW_DIR,
    out_dir: str = DEFAULT_OUT_DIR,
    target_classes: Optional[list[str]] = None,
    log_interval: int = 50,
) -> dict[str, Any]:
    """
    Iterates through raw images, applies background removal + preprocessing,
    and writes to out_dir/<Class>/<short_sha>.jpg.
    Never touches data/images/processed/.
    """
    os.makedirs(out_dir, exist_ok=True)

    # 1. Discover all raw images
    raw_files: list[tuple[str, str, str]] = []  # (class_name, full_path, rel_path)
    for c in sorted(os.listdir(raw_dir)):
        c_path = os.path.join(raw_dir, c)
        if not os.path.isdir(c_path):
            continue
        if target_classes and c not in target_classes:
            continue

        for root, _, files in os.walk(c_path):
            for f in sorted(files):
                ext = os.path.splitext(f)[1].lower()
                if ext in ALLOWED_EXTS:
                    full_path = os.path.join(root, f)
                    rel_path = os.path.relpath(full_path, raw_dir).replace("\\", "/")
                    raw_files.append((c, full_path, rel_path))

    total = len(raw_files)
    print(f"Discovered {total} raw images across {len(set(c for c, _, _ in raw_files))} classes.")
    print(f"Output directory: {out_dir}")

    # Track stats
    processed_count = 0
    skipped_count = 0
    error_count = 0
    start_time = time.time()
    class_counts: dict[str, int] = {}

    for idx, (c, full_path, rel_path) in enumerate(raw_files, start=1):
        class_out_dir = os.path.join(out_dir, c)
        os.makedirs(class_out_dir, exist_ok=True)

        try:
            with open(full_path, "rb") as fp:
                file_bytes = fp.read()

            sha = hashlib.sha256(file_bytes).hexdigest()
            short_sha = sha[:16]
            dest_path = os.path.join(class_out_dir, f"{short_sha}.jpg")

            # Resume capability: skip if already generated
            if os.path.exists(dest_path) and os.path.getsize(dest_path) > 0:
                skipped_count += 1
                class_counts[c] = class_counts.get(c, 0) + 1
            else:
                bgr = load_image_from_bytes(file_bytes)
                bg_removed = remove_background(bgr, enabled=True)
                processed = process_bgr_image(bg_removed, TARGET_SIZE)
                cv2.imwrite(dest_path, processed)
                processed_count += 1
                class_counts[c] = class_counts.get(c, 0) + 1

        except Exception as e:
            error_count += 1
            print(f"[ERROR] Failed processing {rel_path}: {e}")

        # Progress reporting
        if idx % log_interval == 0 or idx == total:
            elapsed = time.time() - start_time
            rate = idx / max(1.0, elapsed)
            remaining = (total - idx) / max(0.01, rate)
            pct = (idx / total) * 100
            print(
                f"[{idx:4d}/{total}] ({pct:5.1f}%) | "
                f"Processed: {processed_count}, Cached: {skipped_count}, Errors: {error_count} | "
                f"Speed: {rate:.2f} img/s | Elapsed: {elapsed:.1f}s | ETA: {remaining/60:.1f}m"
            )

    total_time = time.time() - start_time
    print(f"\nCompleted in {total_time:.2f} seconds ({total_time/60:.2f} minutes).")
    print(f"Total images: {total} | Processed: {processed_count} | Existing/Cached: {skipped_count} | Errors: {error_count}")

    return {
        "total": total,
        "processed": processed_count,
        "skipped": skipped_count,
        "errors": error_count,
        "duration_seconds": total_time,
        "class_counts": class_counts,
    }


def main():
    parser = argparse.ArgumentParser(description="Generate parallel dataset with background removal")
    parser.add_argument("--raw-dir", type=str, default=DEFAULT_RAW_DIR, help="Path to raw images directory")
    parser.add_argument("--out-dir", type=str, default=DEFAULT_OUT_DIR, help="Path to output processed_bg directory")
    parser.add_argument("--classes", nargs="*", default=None, help="Specific classes to process (optional)")
    parser.add_argument("--log-interval", type=int, default=50, help="Progress log interval")
    args = parser.parse_args()

    # Safety check: ensure out_dir is not processed/
    raw_norm = os.path.normpath(os.path.abspath(args.raw_dir))
    out_norm = os.path.normpath(os.path.abspath(args.out_dir))
    proc_norm = os.path.normpath(os.path.abspath(os.path.join(BASE_DIR, "data", "images", "processed")))

    if out_norm == proc_norm:
        print("[CRITICAL ERROR] Target output directory is data/images/processed! Aborting to prevent overwriting.")
        sys.exit(1)

    print(f"Starting background-removed dataset generation...")
    print(f"Source: {raw_norm}")
    print(f"Destination: {out_norm}")
    res = generate_processed_bg(
        raw_dir=raw_norm,
        out_dir=out_norm,
        target_classes=args.classes,
        log_interval=args.log_interval,
    )
    print("\nClass summary:")
    for c, cnt in sorted(res["class_counts"].items()):
        print(f"  {c}: {cnt}")


if __name__ == "__main__":
    main()
