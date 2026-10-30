"""
Evaluation script for Task 2 & Task 3:
1. Compares v0004 and v0008 on the exact same 6 MVP class test split images.
2. Identifies all misclassified test images for v0008 across all 7 classes.
3. Counts Cavendish -> Ambun errors.
"""

import os
import json
import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, f1_score, classification_report, confusion_matrix

from app.ml.training.train_pipeline import load_dataset_records, partition_dataset
from app.ml.predictor import prepare_input_tensor

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

DATA_DIR = os.path.join(BASE_DIR, "data", "images", "processed")
LABELS_FILE = os.path.join(BASE_DIR, "data", "labels.json")
HOLDOUT_FILE = os.path.join(BASE_DIR, "data", "holdout.json")

V0004_DIR = os.path.join(BASE_DIR, "app", "ml", "model_versions", "v0004")
V0008_DIR = os.path.join(BASE_DIR, "app", "ml", "model_versions", "v0008")

# 1. Load partition test records
records, class_names_7, class_counts = load_dataset_records(DATA_DIR, LABELS_FILE, "variety", 30)
train_recs, val_recs, test_recs, split_meta = partition_dataset(records, "group", HOLDOUT_FILE)

# Class names
with open(os.path.join(V0004_DIR, "class_names.txt"), "r", encoding="utf-8") as f:
    v0004_classes = [l.strip() for l in f if l.strip()]

with open(os.path.join(V0008_DIR, "class_names.txt"), "r", encoding="utf-8") as f:
    v0008_classes = [l.strip() for l in f if l.strip()]

with open(os.path.join(V0004_DIR, "model_config.json"), "r", encoding="utf-8") as f:
    v0004_cfg = json.load(f)

with open(os.path.join(V0008_DIR, "model_config.json"), "r", encoding="utf-8") as f:
    v0008_cfg = json.load(f)

print(f"Loaded v0004 classes ({len(v0004_classes)}): {v0004_classes}", flush=True)
print(f"Loaded v0008 classes ({len(v0008_classes)}): {v0008_classes}", flush=True)

# Load models
print("Loading models...", flush=True)
model_v0004 = tf.keras.models.load_model(os.path.join(V0004_DIR, "model.keras"), compile=False)
model_v0008 = tf.keras.models.load_model(os.path.join(V0008_DIR, "model.keras"), compile=False)

# Preload tensors using shared prepare_input_tensor(already_processed=True)
print(f"Processing {len(test_recs)} test images via shared prepare_input_tensor...", flush=True)
tensors_v0004 = []
tensors_v0008 = []

for r in test_recs:
    t4 = prepare_input_tensor(r["path"], v0004_cfg, already_processed=True)[0]
    t8 = prepare_input_tensor(r["path"], v0008_cfg, already_processed=True)[0]
    tensors_v0004.append(t4)
    tensors_v0008.append(t8)

arr_v0004 = np.array(tensors_v0004, dtype=np.float32)
arr_v0008 = np.array(tensors_v0008, dtype=np.float32)

print("Running batch predictions...", flush=True)
preds_v0004 = model_v0004.predict(arr_v0004, batch_size=32, verbose=0)
preds_v0008 = model_v0008.predict(arr_v0008, batch_size=32, verbose=0)

y_pred_idx_v0004 = np.argmax(preds_v0004, axis=1)
y_pred_idx_v0008 = np.argmax(preds_v0008, axis=1)

y_pred_cls_v0004 = [v0004_classes[i] for i in y_pred_idx_v0004]
y_pred_cls_v0008 = [v0008_classes[i] for i in y_pred_idx_v0008]

y_true_cls = [r["variety"] for r in test_recs]

# -------------------------------------------------------------
# TASK 3: v0008 on all 7 classes - misclassified test images & Cavendish -> Ambun
# -------------------------------------------------------------
print("\n" + "="*70, flush=True)
print("TASK 3: v0008 Misclassified Test Images Across All 7 Classes", flush=True)
print("="*70, flush=True)

misclassified_v0008 = []
cav_to_ambun_count = 0

for idx, r in enumerate(test_recs):
    true_label = y_true_cls[idx]
    pred_label = y_pred_cls_v0008[idx]
    if true_label != pred_label:
        conf = float(preds_v0008[idx][y_pred_idx_v0008[idx]])
        misclassified_v0008.append({
            "index": idx,
            "filename": os.path.basename(r["path"]),
            "true_label": true_label,
            "pred_label": pred_label,
            "confidence": conf,
            "path": r["path"]
        })
        if true_label == "Cavendish_Banana" and pred_label == "Ambun_Banana":
            cav_to_ambun_count += 1

print(f"Total test images (7 classes): {len(test_recs)}", flush=True)
print(f"Total misclassifications in v0008: {len(misclassified_v0008)}", flush=True)
print(f"Cavendish -> Ambun misclassifications: {cav_to_ambun_count}", flush=True)
print("\nDetailed list of misclassified images:", flush=True)
for m in misclassified_v0008:
    print(f"  [{m['filename']}] True: {m['true_label']:<18} | Pred: {m['pred_label']:<18} | Conf: {m['confidence']:.4f}", flush=True)

# -------------------------------------------------------------
# TASK 2: Fair comparison on the SAME 6 MVP classes (exclude Cavendish)
# -------------------------------------------------------------
print("\n" + "="*70, flush=True)
print("TASK 2: Fair Comparison: v0004 vs v0008 on SAME 6 MVP Classes (Exclude Cavendish)", flush=True)
print("="*70, flush=True)

mvp_6_classes = sorted([c for c in v0004_classes if c != "Cavendish_Banana"])
mvp_indices = [i for i, r in enumerate(test_recs) if r["variety"] in mvp_6_classes]

print(f"Total test images in 6 MVP classes: {len(mvp_indices)}", flush=True)
from collections import Counter
counts_6 = Counter(y_true_cls[i] for i in mvp_indices)
print("\nTest image counts per class:", flush=True)
for c in mvp_6_classes:
    print(f"  {c:<20}: {counts_6[c]} images", flush=True)

# Ground truth indices for 6 classes
class_to_idx_6 = {c: i for i, c in enumerate(mvp_6_classes)}
y_true_6 = [class_to_idx_6[y_true_cls[i]] for i in mvp_indices]

# Predictions for v0004 (v0004 was trained on these 6 classes)
y_pred_6_v0004 = [class_to_idx_6[y_pred_cls_v0004[i]] if y_pred_cls_v0004[i] in class_to_idx_6 else -1 for i in mvp_indices]

# Predictions for v0008 (if predicted Cavendish on a 6-class image, maps to -1)
y_pred_6_v0008 = [class_to_idx_6[y_pred_cls_v0008[i]] if y_pred_cls_v0008[i] in class_to_idx_6 else -1 for i in mvp_indices]

# Metrics
acc_v0004 = float(accuracy_score(y_true_6, y_pred_6_v0004))
acc_v0008 = float(accuracy_score(y_true_6, y_pred_6_v0008))

macro_f1_v0004 = float(f1_score(y_true_6, y_pred_6_v0004, average="macro", zero_division=0))
macro_f1_v0008 = float(f1_score(y_true_6, y_pred_6_v0008, average="macro", zero_division=0))

rep_v0004 = classification_report(y_true_6, y_pred_6_v0004, labels=list(range(6)), target_names=mvp_6_classes, output_dict=True, zero_division=0)
rep_v0008 = classification_report(y_true_6, y_pred_6_v0008, labels=list(range(6)), target_names=mvp_6_classes, output_dict=True, zero_division=0)

cm_v0004 = confusion_matrix(y_true_6, y_pred_6_v0004, labels=list(range(6)))
cm_v0008 = confusion_matrix(y_true_6, y_pred_6_v0008, labels=list(range(6)))

print(f"\n--- Accuracy ---", flush=True)
print(f"v0004 Accuracy : {acc_v0004*100:.2f}% ({int(acc_v0004*len(mvp_indices))}/{len(mvp_indices)})", flush=True)
print(f"v0008 Accuracy : {acc_v0008*100:.2f}% ({int(acc_v0008*len(mvp_indices))}/{len(mvp_indices)})", flush=True)

print(f"\n--- Macro F1 ---", flush=True)
print(f"v0004 Macro F1 : {macro_f1_v0004:.4f}", flush=True)
print(f"v0008 Macro F1 : {macro_f1_v0008:.4f}", flush=True)

print(f"\n--- Per-Class F1 Score ---", flush=True)
print(f"{'Class':<20} | {'v0004 F1':<10} | {'v0008 F1':<10} | {'Count'}", flush=True)
print("-" * 52, flush=True)
for c in mvp_6_classes:
    f4 = rep_v0004[c]['f1-score']
    f8 = rep_v0008[c]['f1-score']
    cnt = counts_6[c]
    print(f"{c:<20} | {f4:<10.4f} | {f8:<10.4f} | {cnt}", flush=True)

print("\n--- Confusion Matrix (v0004) ---", flush=True)
print(cm_v0004, flush=True)

print("\n--- Confusion Matrix (v0008) ---", flush=True)
print(cm_v0008, flush=True)

comparison = {
    "test_counts_per_class": {c: counts_6[c] for c in mvp_6_classes},
    "total_test_images": len(mvp_indices),
    "v0004": {
        "accuracy": acc_v0004,
        "macro_f1": macro_f1_v0004,
        "per_class": {c: rep_v0004[c] for c in mvp_6_classes},
        "confusion_matrix": cm_v0004.tolist(),
    },
    "v0008": {
        "accuracy": acc_v0008,
        "macro_f1": macro_f1_v0008,
        "per_class": {c: rep_v0008[c] for c in mvp_6_classes},
        "confusion_matrix": cm_v0008.tolist(),
    },
    "misclassified_v0008_all_7": misclassified_v0008,
    "cavendish_to_ambun_count": cav_to_ambun_count
}

out_path = os.path.join(BASE_DIR, "data", "diagnostics", "v0004_v0008_comparison.json")
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(comparison, f, indent=2)

print(f"\nSaved structured comparison to: {out_path}", flush=True)
