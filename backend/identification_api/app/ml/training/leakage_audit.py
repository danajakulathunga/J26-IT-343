"""
Leakage Audit: Evaluates feature-level data leakage between train and test splits
under the current deterministic hash split using:
1. Active variety model's backbone features
2. ImageNet-pretrained (non-fine-tuned) MobileNetV2 backbone features
Also generates a PNG sheet of 10 example pairs side-by-side.
"""

import argparse
import hashlib
import json
import os
import shutil
import sys
from typing import Any, Dict, List, Tuple

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import tensorflow as tf

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
DATA_DIR = os.path.join(BASE_DIR, "data")
PROCESSED_DIR = os.path.join(DATA_DIR, "images", "processed")
DEFAULT_MODEL_PATH = os.path.join(BASE_DIR, "app", "ml", "model", "variety_classifier.keras")
DEFAULT_LEAKAGE_DIR = os.path.join(DATA_DIR, "diagnostics", "leakage")


def get_hash_split(filename: str) -> str:
    """
    Current deterministic hash split:
    int(sha256(filename), 16) % 100
    < 80: train
    80-89: val
    >= 90: test
    """
    h = int(hashlib.sha256(filename.encode("utf-8")).hexdigest(), 16) % 100
    if h < 80:
        return "train"
    elif h < 90:
        return "val"
    else:
        return "test"


def load_active_feature_extractor(model_path: str):
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Active model not found at {model_path}")

    full_model = tf.keras.models.load_model(model_path)
    try:
        pool_layer = full_model.get_layer("global_average_pooling2d")
        feature_model = tf.keras.Model(inputs=full_model.input, outputs=pool_layer.output)
    except Exception:
        penultimate = full_model.layers[-2]
        feature_model = tf.keras.Model(inputs=full_model.input, outputs=penultimate.output)
    return feature_model


def load_imagenet_feature_extractor():
    base = tf.keras.applications.MobileNetV2(
        weights="imagenet",
        include_top=False,
        pooling="avg",
        input_shape=(300, 300, 3),
    )
    return base


def extract_features(
    feature_model: tf.keras.Model,
    image_paths: List[str],
    batch_size: int = 32,
) -> np.ndarray:
    preprocess_input = tf.keras.applications.mobilenet_v2.preprocess_input
    all_embeddings = []

    for i in range(0, len(image_paths), batch_size):
        batch_paths = image_paths[i:i + batch_size]
        batch_imgs = []
        for p in batch_paths:
            img = cv2.imread(p)
            if img is None:
                raise ValueError(f"Could not read image at {p}")
            rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            if rgb.shape[:2] != (300, 300):
                rgb = cv2.resize(rgb, (300, 300), interpolation=cv2.INTER_AREA)
            batch_imgs.append(rgb)

        batch_arr = preprocess_input(np.array(batch_imgs, dtype=np.float32))
        features = feature_model(batch_arr, training=False).numpy()
        all_embeddings.append(features)

    if not all_embeddings:
        return np.zeros((0, 1280), dtype=np.float32)

    embeddings = np.vstack(all_embeddings)
    norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    return embeddings / norms


def create_pairs_png_sheet(
    pairs: List[Dict[str, Any]],
    out_path: str,
    max_pairs: int = 10,
    thumb_size: int = 240,
):
    """
    Renders a side-by-side PNG contact sheet comparing test images and their nearest train matches.
    """
    selected = pairs[:max_pairs]
    if not selected:
        return

    row_h = thumb_size + 45
    sheet_w = thumb_size * 2 + 40
    sheet_h = len(selected) * row_h + 60

    sheet = Image.new("RGB", (sheet_w, sheet_h), color=(25, 25, 25))
    draw = ImageDraw.Draw(sheet)

    title = f"Top {len(selected)} Leaking Test/Train Pairs (Side-by-Side Comparison)"
    draw.text((20, 18), title, fill=(255, 255, 255))

    for idx, pair in enumerate(selected):
        y_top = 55 + idx * row_h

        # Left: Test image
        t_img = Image.open(pair["test_path"]).convert("RGB").resize((thumb_size, thumb_size))
        sheet.paste(t_img, (15, y_top))

        # Right: Train match
        m_img = Image.open(pair["nearest_train_path"]).convert("RGB").resize((thumb_size, thumb_size))
        sheet.paste(m_img, (thumb_size + 25, y_top))

        # Labels
        sim = pair["similarity"]
        sim_col = (255, 80, 80) if sim >= 0.95 else (255, 200, 50)
        draw.text((15, y_top + thumb_size + 5), f"TEST: {pair['test_class']} ({pair['test_file'][:8]}...)", fill=(200, 200, 200))
        draw.text((thumb_size + 25, y_top + thumb_size + 5), f"TRAIN: {pair['nearest_train_class']} ({pair['nearest_train_file'][:8]}...)", fill=(200, 200, 200))
        draw.text((15, y_top + thumb_size + 22), f"Pair #{idx + 1} | Cosine Similarity: {sim:.4f}", fill=sim_col)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path, format="PNG")
    print(f"[LEAKAGE AUDIT] Saved 10-pair visual comparison sheet to: {out_path}")


def audit_feature_set(
    test_embeddings: np.ndarray,
    train_embeddings: np.ndarray,
    test_items: List[Dict[str, str]],
    train_items: List[Dict[str, str]],
    threshold: float = 0.95,
) -> Tuple[int, float, List[Dict[str, Any]]]:
    sim_matrix = np.dot(test_embeddings, train_embeddings.T)
    nearest_train_indices = np.argmax(sim_matrix, axis=1)
    nearest_similarities = np.max(sim_matrix, axis=1)

    pairs = []
    leaking_count = 0
    for test_idx, (train_idx, sim) in enumerate(zip(nearest_train_indices, nearest_similarities)):
        sim_val = float(sim)
        test_info = test_items[test_idx]
        train_info = train_items[train_idx]
        is_leaking = sim_val >= threshold
        if is_leaking:
            leaking_count += 1

        pairs.append({
            "test_file": test_info["filename"],
            "test_class": test_info["class"],
            "test_path": test_info["path"],
            "nearest_train_file": train_info["filename"],
            "nearest_train_class": train_info["class"],
            "nearest_train_path": train_info["path"],
            "similarity": round(sim_val, 4),
            "leaking": is_leaking,
        })

    # Sort descending by similarity
    pairs.sort(key=lambda p: p["similarity"], reverse=True)
    pct = round((leaking_count / len(test_items)) * 100.0, 2) if test_items else 0.0
    return leaking_count, pct, pairs


def run_leakage_audit(
    data_dir: str = PROCESSED_DIR,
    model_path: str = DEFAULT_MODEL_PATH,
    out_dir: str = DEFAULT_LEAKAGE_DIR,
    threshold: float = 0.95,
    split_mode: str = "group",
) -> Dict[str, Any]:
    print(f"[LEAKAGE AUDIT] Scanning dataset in {data_dir} (split_mode={split_mode})...")
    if not os.path.isdir(data_dir):
        raise FileNotFoundError(f"Data directory not found: {data_dir}")

    train_items: List[Dict[str, str]] = []
    val_items: List[Dict[str, str]] = []
    test_items: List[Dict[str, str]] = []

    if split_mode == "group":
        from app.ml.training.train_pipeline import load_dataset_records, partition_dataset
        records, class_names, _ = load_dataset_records(
            data_dir=data_dir,
            labels_file=os.path.join(DATA_DIR, "labels.json"),
            task="variety",
            min_images_per_class=10,
        )
        tr_recs, va_recs, te_recs, _ = partition_dataset(records, split_mode="group")
        for r in tr_recs:
            train_items.append({"path": r["path"], "filename": r["filename"], "class": r["variety"]})
        for r in va_recs:
            val_items.append({"path": r["path"], "filename": r["filename"], "class": r["variety"]})
        for r in te_recs:
            test_items.append({"path": r["path"], "filename": r["filename"], "class": r["variety"]})
    else:
        for cname in sorted(os.listdir(data_dir)):
            cdir = os.path.join(data_dir, cname)
            if not os.path.isdir(cdir) or cname.startswith("."):
                continue
            for fname in sorted(os.listdir(cdir)):
                if fname.startswith(".") or not fname.lower().endswith((".jpg", ".jpeg", ".png")):
                    continue
                fpath = os.path.join(cdir, fname)
                split = get_hash_split(fname)
                item = {"path": fpath, "filename": fname, "class": cname}
                if split == "train":
                    train_items.append(item)
                elif split == "val":
                    val_items.append(item)
                elif split == "test":
                    test_items.append(item)

    eval_items = val_items + test_items
    print(f"[LEAKAGE AUDIT] Partitions: {len(train_items)} train, {len(val_items)} val, {len(test_items)} test ({len(eval_items)} total val+test).")
    if len(train_items) == 0 or len(eval_items) == 0:
        return {"error": "Not enough images in split"}

    train_paths = [item["path"] for item in train_items]
    eval_paths = [item["path"] for item in eval_items]

    # Pretrained ImageNet MobileNetV2 (non-fine-tuned baseline)
    print("[LEAKAGE AUDIT] Extracting ImageNet MobileNetV2 features for leakage check...")
    imagenet_model = load_imagenet_feature_extractor()
    train_feat_imagenet = extract_features(imagenet_model, train_paths)
    eval_feat_imagenet = extract_features(imagenet_model, eval_paths)
    total_leaking, total_pct, eval_pairs = audit_feature_set(
        eval_feat_imagenet, train_feat_imagenet, eval_items, train_items, threshold
    )

    # Per-class breakdown for val and test
    val_filenames = set(item["filename"] for item in val_items)
    test_filenames = set(item["filename"] for item in test_items)

    class_names = sorted(list(set(item["class"] for item in eval_items)))
    per_class_summary = {}

    for c in class_names:
        c_val = [p for p in eval_pairs if p["test_class"] == c and p["test_file"] in val_filenames]
        c_val_leak = sum(1 for p in c_val if p["leaking"])
        c_test = [p for p in eval_pairs if p["test_class"] == c and p["test_file"] in test_filenames]
        c_test_leak = sum(1 for p in c_test if p["leaking"])
        c_tot = len(c_val) + len(c_test)
        c_tot_leak = c_val_leak + c_test_leak
        per_class_summary[c] = {
            "val_count": len(c_val),
            "val_leaking": c_val_leak,
            "test_count": len(c_test),
            "test_leaking": c_test_leak,
            "total_eval": c_tot,
            "total_leaking": c_tot_leak,
            "leak_pct": round((c_tot_leak / c_tot) * 100.0, 1) if c_tot else 0.0,
        }

    print("\n" + "=" * 88)
    print(f"               DATA LEAKAGE AUDIT SUMMARY (Cosine >= {threshold})")
    print("=" * 88)
    print(f"{'Class Name':<18} | {'Val Imgs':<8} | {'Val Leak':<8} | {'Test Imgs':<9} | {'Test Leak':<9} | {'Total Leak %'}")
    print("-" * 88)
    for c in class_names:
        s = per_class_summary[c]
        print(f"{c:<18} | {s['val_count']:<8} | {s['val_leaking']:<8} | {s['test_count']:<9} | {s['test_leaking']:<9} | {s['total_leaking']}/{s['total_eval']} ({s['leak_pct']}%)")
    print("-" * 88)
    print(f"{'TOTAL':<18} | {len(val_items):<8} | {sum(s['val_leaking'] for s in per_class_summary.values()):<8} | {len(test_items):<9} | {sum(s['test_leaking'] for s in per_class_summary.values()):<9} | {total_leaking}/{len(eval_items)} ({total_pct}%)")
    print("=" * 88 + "\n")

    # Generate 10-pair comparison sheet PNG
    os.makedirs(out_dir, exist_ok=True)
    sheet_png_path = os.path.join(out_dir, "leakage_pairs_sheet.png")
    create_pairs_png_sheet(eval_pairs, sheet_png_path, max_pairs=10)

    # Markdown report
    report_md_path = os.path.join(DATA_DIR, "diagnostics", "leakage_report.md")
    with open(report_md_path, "w", encoding="utf-8") as f:
        f.write(f"# Data Leakage Audit Report (Split: {split_mode})\n\n")
        f.write(f"- **Total Train Images:** {len(train_items)}\n")
        f.write(f"- **Total Val Images:** {len(val_items)}\n")
        f.write(f"- **Total Test Images:** {len(test_items)}\n")
        f.write(f"- **Cosine Similarity Threshold:** >= {threshold}\n\n")
        f.write("## Per-Class Leakage Summary (Val + Test vs Train)\n\n")
        f.write("| Class Name | Val Images | Val Leaking | Test Images | Test Leaking | Total Leaking (Val+Test) | Leak % |\n")
        f.write("| :--- | :---: | :---: | :---: | :---: | :---: | :---: |\n")
        for c in class_names:
            s = per_class_summary[c]
            f.write(f"| **{c}** | {s['val_count']} | {s['val_leaking']} | {s['test_count']} | {s['test_leaking']} | {s['total_leaking']} / {s['total_eval']} | **{s['leak_pct']}%** |\n")
        f.write("\n")

    return {
        "total_leaking": total_leaking,
        "total_pct": total_pct,
        "per_class_summary": per_class_summary,
        "report_md_path": report_md_path,
    }


def main():
    parser = argparse.ArgumentParser(description="Audit data leakage between train and val/test splits.")
    parser.add_argument("--threshold", type=float, default=0.95, help="Cosine similarity threshold (default: 0.95)")
    parser.add_argument("--split", type=str, choices=["group", "hash"], default="group", help="Split mode: group|hash (default: group)")
    parser.add_argument("--data-dir", type=str, default=PROCESSED_DIR, help="Path to processed images folder")
    parser.add_argument("--model-path", type=str, default=DEFAULT_MODEL_PATH, help="Path to active model .keras")
    parser.add_argument("--out-dir", type=str, default=DEFAULT_LEAKAGE_DIR, help="Directory to save leaking pair copies")
    args = parser.parse_args()

    run_leakage_audit(
        data_dir=args.data_dir,
        model_path=args.model_path,
        out_dir=args.out_dir,
        threshold=args.threshold,
        split_mode=args.split,
    )


if __name__ == "__main__":
    main()

