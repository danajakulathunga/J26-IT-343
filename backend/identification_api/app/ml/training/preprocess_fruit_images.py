"""
Fruit Variety Dataset - OpenCV Preprocessing Script (Wrapper)
Uses app.ml.preprocessing shared pipeline.
"""

import os
import cv2
from app.ml.preprocessing import (
    load_image_from_path,
    process_bgr_image,
    TARGET_SIZE,
)

INPUT_DIR = "."
OUTPUT_DIR = "../Banana_processed"


def preprocess_image(image_path: str):
    try:
        bgr = load_image_from_path(image_path)
        return process_bgr_image(bgr, TARGET_SIZE)
    except Exception as e:
        print(f"  [SKIP] Error processing {image_path}: {e}")
        return None


def main():
    if not os.path.isdir(INPUT_DIR):
        print(f"ERROR: Input folder not found: {INPUT_DIR}")
        return

    output_abs = os.path.abspath(OUTPUT_DIR)
    variety_folders = [
        f for f in os.listdir(INPUT_DIR)
        if os.path.isdir(os.path.join(INPUT_DIR, f))
        and os.path.abspath(os.path.join(INPUT_DIR, f)) != output_abs
    ]

    if not variety_folders:
        print(f"No variety folders found inside {INPUT_DIR}")
        return

    total_processed = 0
    total_skipped = 0

    for variety in variety_folders:
        input_variety_dir = os.path.join(INPUT_DIR, variety)
        output_variety_dir = os.path.join(OUTPUT_DIR, variety)
        os.makedirs(output_variety_dir, exist_ok=True)

        image_files = [
            f for f in os.listdir(input_variety_dir)
            if f.lower().endswith((".jpg", ".jpeg", ".png", ".heic", ".heif"))
        ]

        print(f"\nProcessing '{variety}' ({len(image_files)} images)...")

        for idx, filename in enumerate(image_files, start=1):
            input_path = os.path.join(input_variety_dir, filename)
            processed = preprocess_image(input_path)

            if processed is None:
                total_skipped += 1
                continue

            out_name = f"{variety}_{idx:04d}.jpg"
            output_path = os.path.join(output_variety_dir, out_name)
            cv2.imwrite(output_path, processed)
            total_processed += 1

        print(f"  -> Saved to: {output_variety_dir}")

    print(f"\nDONE. Total processed: {total_processed}, skipped: {total_skipped}")
    print(f"Processed dataset location: {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()