import os
import sys
from pathlib import Path

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf
from PIL import Image

from app.ml.training.train_pipeline import load_dataset_records, partition_dataset
from app.ml.augment_bg import augment_background_swap

data_dir = os.path.join(BASE_DIR, "data", "images", "processed")
labels_file = os.path.join(BASE_DIR, "data", "labels.json")
holdout_file = os.path.join(BASE_DIR, "data", "holdout.json")

records, class_names, _ = load_dataset_records(data_dir, labels_file, "variety", 30)
train_recs, _, _, _ = partition_dataset(records, "group", holdout_file)

# Select 16 diverse training images across classes
selected_recs = []
classes_cycle = list(class_names)
recs_by_class = {c: [r for r in train_recs if r["label_name"] == c] for c in class_names}

idx = 0
while len(selected_recs) < 16:
    c = classes_cycle[idx % len(classes_cycle)]
    if recs_by_class[c]:
        selected_recs.append(recs_by_class[c].pop(0))
    idx += 1

print(f"Selected 16 training images across {len(set(r['label_name'] for r in selected_recs))} classes.")

# Standard variety augmentation layers
aug_layers = tf.keras.Sequential([
    tf.keras.layers.RandomFlip("horizontal"),
    tf.keras.layers.RandomRotation(0.15),
    tf.keras.layers.RandomZoom(0.15),
    tf.keras.layers.RandomBrightness(0.15),
    tf.keras.layers.RandomContrast(0.15),
])

# 1. Generate 16 WITHOUT bg-swap (standard augmentations only)
imgs_no_bg = []
for r in selected_recs:
    raw = Image.open(r["path"]).convert("RGB").resize((300, 300))
    arr = np.array(raw, dtype=np.float32)
    t = tf.convert_to_tensor(arr[None, ...])
    t_aug = aug_layers(t, training=True)[0].numpy()
    imgs_no_bg.append((np.clip(t_aug, 0, 255).astype(np.uint8), r["label_name"]))

# 2. Generate 16 WITH bg-swap (bg-swap + standard augmentations)
imgs_with_bg = []
for r in selected_recs:
    raw = Image.open(r["path"]).convert("RGB").resize((300, 300))
    arr = np.array(raw, dtype=np.uint8)
    stem = Path(r["path"]).stem
    swapped = augment_background_swap(
        arr,
        bg_swap_prob=1.0,
        backgrounds_dir=os.path.join(BASE_DIR, "data", "backgrounds"),
        mask_cache_dir=os.path.join(BASE_DIR, "data", "diagnostics", "masks"),
        image_id=stem,
    )
    t = tf.convert_to_tensor(swapped.astype(np.float32)[None, ...])
    t_aug = aug_layers(t, training=True)[0].numpy()
    imgs_with_bg.append((np.clip(t_aug, 0, 255).astype(np.uint8), r["label_name"]))

# Create figure: 4 rows x 8 columns
# Left half: Cols 0-3 (Standard Augmentation, WITHOUT bg-swap)
# Right half: Cols 4-7 (Background Swap + Standard Augmentation)
fig, axes = plt.subplots(4, 8, figsize=(22, 12))
fig.suptitle(
    "Data Augmentation Comparison: Standard (WITHOUT bg-swap) vs. Synthetic Compositing (WITH bg-swap)",
    fontsize=16,
    fontweight="bold",
    y=0.98,
)

for i in range(16):
    r = i // 4
    short_cls = selected_recs[i]["label_name"].replace("_Banana", "")

    # Left: without bg-swap
    c_left = i % 4
    ax_left = axes[r, c_left]
    img_nb, _ = imgs_no_bg[i]
    ax_left.imshow(img_nb)
    ax_left.set_title(f"#{i+1}: {short_cls}\n[Std Aug]", fontsize=9, fontweight="semibold")
    ax_left.axis("off")

    # Right: with bg-swap
    c_right = 4 + (i % 4)
    ax_right = axes[r, c_right]
    img_wb, _ = imgs_with_bg[i]
    ax_right.imshow(img_wb)
    ax_right.set_title(f"#{i+1}: {short_cls}\n[+BG Swap]", fontsize=9, fontweight="semibold")
    ax_right.axis("off")

# Section headings
plt.figtext(
    0.27, 0.935,
    "Part A: Standard In-Model Augmentations (WITHOUT bg-swap)",
    ha="center", fontsize=12, fontweight="bold", color="#1E40AF",
    bbox=dict(boxstyle="round,pad=0.4", facecolor="#DBEAFE", edgecolor="#93C5FD")
)
plt.figtext(
    0.73, 0.935,
    "Part B: Background-Swap + Standard Augmentations (WITH bg-swap)",
    ha="center", fontsize=12, fontweight="bold", color="#065F46",
    bbox=dict(boxstyle="round,pad=0.4", facecolor="#D1FAE5", edgecolor="#6EE7B7")
)

out_dir = os.path.join(BASE_DIR, "data", "diagnostics")
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "aug_samples.png")

plt.tight_layout(rect=[0, 0.01, 1, 0.92])
plt.savefig(out_path, dpi=180)
plt.close()

size = os.path.getsize(out_path)
print(f"Successfully saved: {out_path} ({size} bytes).")
