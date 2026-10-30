"""
Ripeness Presort Helper: Generates SUGGESTIONS ONLY for banana ripeness stages
based on color histogram / HSV pixel fractions.

Outputs:
- data/diagnostics/ripeness_suggestions.csv
- data/diagnostics/contact_sheets/<Class>_contact_sheet.png

NOTE: Suggestions only. Never moves, deletes, or relabels files.
IMPORTANT: Red and Ambun banana varieties cannot be accurately judged by color thresholds alone.
"""

import argparse
import csv
import math
import os
import sys
from typing import Dict, List, Tuple

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_DIR = os.path.join(BASE_DIR, "data")
PROCESSED_DIR = os.path.join(DATA_DIR, "images", "processed")
DIAGNOSTICS_DIR = os.path.join(DATA_DIR, "diagnostics")
CONTACT_SHEETS_DIR = os.path.join(DIAGNOSTICS_DIR, "contact_sheets")
SUGGESTIONS_CSV = os.path.join(DIAGNOSTICS_DIR, "ripeness_suggestions.csv")

STAGE_ORDER = ["Green", "Turning", "Ripe", "Overripe"]
STAGE_RANK = {s: i for i, s in enumerate(STAGE_ORDER)}


def analyze_pixel_fractions(image_bgr: np.ndarray) -> Tuple[float, float, float, float, str]:
    """
    Analyzes non-background pixels in HSV color space to estimate:
    (green_frac, yellow_frac, red_frac, brown_frac, suggested_stage)
    """
    # 1. Segment foreground (processed images have white padding > 240 on all channels)
    b, g, r = cv2.split(image_bgr)
    fg_mask = (b < 240) | (g < 240) | (r < 240)
    total_fg_pixels = np.count_nonzero(fg_mask)

    if total_fg_pixels < 100:
        return 0.0, 0.0, 0.0, 0.0, "Unknown"

    hsv = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv)

    # 2. Define HSV color masks on foreground
    # Green: Hue 35 to 85, Saturation >= 40, Value >= 40
    green_mask = fg_mask & (h >= 35) & (h <= 85) & (s >= 40) & (v >= 40)

    # Yellow: Hue 20 to 35, Saturation >= 50, Value >= 80
    yellow_mask = fg_mask & (h >= 20) & (h < 35) & (s >= 50) & (v >= 80)

    # Red: Hue 0 to 12 or 170 to 180, Saturation >= 50, Value >= 50
    red_mask = fg_mask & ((h < 12) | (h >= 170)) & (s >= 50) & (v >= 50)

    # Brown: Hue 8 to 25, Saturation >= 30, Low/Medium Value (25 <= v < 110)
    brown_mask = fg_mask & (h >= 8) & (h <= 25) & (s >= 30) & (v >= 25) & (v < 110)
    # Dark spots on peel also count toward brown/overripe
    dark_spots_mask = fg_mask & (v < 45)
    brown_combined = brown_mask | dark_spots_mask

    g_frac = float(np.count_nonzero(green_mask) / total_fg_pixels)
    y_frac = float(np.count_nonzero(yellow_mask) / total_fg_pixels)
    r_frac = float(np.count_nonzero(red_mask) / total_fg_pixels)
    b_frac = float(np.count_nonzero(brown_combined) / total_fg_pixels)

    # 3. Stage suggestion heuristics
    # Green < Turning < Ripe < Overripe
    if b_frac >= 0.18:
        stage = "Overripe"
    elif g_frac >= 0.35 and y_frac < 0.20:
        stage = "Green"
    elif g_frac >= 0.12 and y_frac >= 0.15:
        stage = "Turning"
    elif y_frac >= 0.25 or (y_frac > g_frac):
        stage = "Ripe"
    elif g_frac > y_frac:
        stage = "Green"
    else:
        stage = "Turning"

    return round(g_frac, 4), round(y_frac, 4), round(r_frac, 4), round(b_frac, 4), stage


def generate_contact_sheet(
    class_name: str,
    images_info: List[Dict],
    out_path: str,
    thumb_size: int = 150,
    cols: int = 8,
):
    """
    Renders a contact sheet sorted by suggested ripeness stage.
    """
    if not images_info:
        return

    # Sort by stage order, then by filename
    sorted_items = sorted(
        images_info,
        key=lambda item: (STAGE_RANK.get(item["suggested_stage"], 99), item["sha16"]),
    )

    rows = math.ceil(len(sorted_items) / cols)
    cell_w = thumb_size
    cell_h = thumb_size + 30  # 30px for label banner
    sheet_w = cols * cell_w
    sheet_h = rows * cell_h + 50  # 50px for header title

    sheet = Image.new("RGB", (sheet_w, sheet_h), color=(30, 30, 30))
    draw = ImageDraw.Draw(sheet)

    # Title
    title = f"{class_name} - Ripeness Suggestions (Sorted by Stage: Green -> Turning -> Ripe -> Overripe)"
    draw.text((15, 15), title, fill=(255, 255, 255))

    for idx, item in enumerate(sorted_items):
        r_idx = idx // cols
        c_idx = idx % cols
        x = c_idx * cell_w
        y = 50 + r_idx * cell_h

        img_bgr = cv2.imread(item["path"])
        if img_bgr is not None:
            rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
            pil_thumb = Image.fromarray(rgb).resize((thumb_size, thumb_size), Image.Resampling.BILINEAR)
            sheet.paste(pil_thumb, (x, y))

        stage_colors = {
            "Green": (46, 125, 50),
            "Turning": (230, 160, 20),
            "Ripe": (245, 197, 24),
            "Overripe": (121, 85, 72),
        }
        bg_col = stage_colors.get(item["suggested_stage"], (70, 70, 70))
        draw.rectangle([x, y + thumb_size, x + thumb_size, y + cell_h], fill=bg_col)
        label_text = f"{item['sha16'][:6]} | {item['suggested_stage']}"
        draw.text((x + 5, y + thumb_size + 7), label_text, fill=(255, 255, 255))

    sheet.save(out_path, format="PNG")


def run_presort(
    data_dir: str = PROCESSED_DIR,
    csv_out: str = SUGGESTIONS_CSV,
    contact_sheets_dir: str = CONTACT_SHEETS_DIR,
):
    print(f"[RIPENESS PRESORT] Scanning images in {data_dir}...")
    if not os.path.isdir(data_dir):
        raise FileNotFoundError(f"Processed images directory not found at {data_dir}")

    os.makedirs(os.path.dirname(csv_out), exist_ok=True)
    os.makedirs(contact_sheets_dir, exist_ok=True)

    records = []
    by_class: Dict[str, List[Dict]] = {}

    for cname in sorted(os.listdir(data_dir)):
        cdir = os.path.join(data_dir, cname)
        if not os.path.isdir(cdir) or cname.startswith("."):
            continue
        by_class[cname] = []
        for fname in sorted(os.listdir(cdir)):
            if fname.startswith(".") or not fname.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            sha16 = os.path.splitext(fname)[0]
            fpath = os.path.join(cdir, fname)

            img = cv2.imread(fpath)
            if img is None:
                continue

            g_frac, y_frac, r_frac, b_frac, stage = analyze_pixel_fractions(img)
            rec = {
                "sha16": sha16,
                "class": cname,
                "suggested_stage": stage,
                "green_frac": g_frac,
                "yellow_frac": y_frac,
                "red_frac": r_frac,
                "brown_frac": b_frac,
                "path": fpath,
            }
            records.append(rec)
            by_class[cname].append(rec)

    # Write CSV
    with open(csv_out, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["sha16", "class", "suggested_stage", "green_frac", "yellow_frac", "red_frac", "brown_frac"])
        for r in records:
            writer.writerow([
                r["sha16"],
                r["class"],
                r["suggested_stage"],
                r["green_frac"],
                r["yellow_frac"],
                r["red_frac"],
                r["brown_frac"],
            ])

    print(f"[RIPENESS PRESORT] Saved {len(records)} suggestions to {csv_out}")

    # Generate Contact Sheets
    for cname, items in by_class.items():
        sheet_path = os.path.join(contact_sheets_dir, f"{cname}_contact_sheet.png")
        generate_contact_sheet(cname, items, sheet_path)
        print(f"[RIPENESS PRESORT] Generated contact sheet for {cname} -> {sheet_path}")

    print("\n" + "=" * 70)
    print("                 RIPENESS PRESORT SUMMARY (SUGGESTIONS ONLY)")
    print("=" * 70)
    print("NOTE: This script generates SUGGESTIONS only. It never moves or labels anything.")
    print("IMPORTANT CAVEAT:")
    print("  Red_Banana and Ambun_Banana cannot be judged by colour thresholds alone.")
    print("  - Red_Banana has a red/maroon peel even when ripe/unripe.")
    print("  - Ambun_Banana often remains predominantly green even when fully ripe.")
    print(f"Suggestions CSV:  {csv_out}")
    print(f"Contact Sheets:   {contact_sheets_dir}")
    print("=" * 70 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Ripeness presort helper tool (suggestions only).")
    parser.add_argument("--data-dir", type=str, default=PROCESSED_DIR, help="Path to processed images folder")
    parser.add_argument("--csv-out", type=str, default=SUGGESTIONS_CSV, help="Path to output suggestions CSV")
    parser.add_argument("--contact-sheets-dir", type=str, default=CONTACT_SHEETS_DIR, help="Path to contact sheets folder")
    args = parser.parse_args()

    run_presort(
        data_dir=args.data_dir,
        csv_out=args.csv_out,
        contact_sheets_dir=args.contact_sheets_dir,
    )


if __name__ == "__main__":
    main()
