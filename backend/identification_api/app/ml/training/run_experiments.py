"""
Resumable Experiment Runner for 224px vs 300px Banana Variety Classification.
Runs:
  1. combo_224: MobileNetV2 at 224x224 (baseline)
  2. res300_combo: MobileNetV2 at 300x300
  3. effb3_300: EfficientNetB3 at 300x300

Saves results only under app/ml/model_versions/experiments/
Outputs summary to data/diagnostics/experiments_summary.md and .csv
"""

import argparse
import csv
import datetime
import hashlib
import json
import os
import sys
import time
from typing import Any

import numpy as np
from sklearn.metrics import classification_report, confusion_matrix, f1_score, accuracy_score
from sklearn.utils.class_weight import compute_class_weight
import tensorflow as tf

layers = tf.keras.layers
models = tf.keras.models

from app.ml.training.train_pipeline import configure_hardware_limits, load_dataset_splits

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
DATA_DIR = os.path.join(BASE_DIR, "data")
EXPERIMENTS_DIR = os.path.join(BASE_DIR, "app", "ml", "model_versions", "experiments")
DIAGNOSTICS_DIR = os.path.join(DATA_DIR, "diagnostics")


def build_tf_dataset(paths, labels, img_size: tuple[int, int], model_type: str, batch_size: int = 16, is_train: bool = False, seed: int = 42):
    if model_type == "efficientnetb3":
        preprocess_fn = tf.keras.applications.efficientnet.preprocess_input
    else:
        preprocess_fn = tf.keras.applications.mobilenet_v2.preprocess_input

    def _parse(path, label):
        img_bytes = tf.io.read_file(path)
        img = tf.image.decode_jpeg(img_bytes, channels=3)
        img = tf.image.resize(img, img_size)
        img = preprocess_fn(img)
        return img, label

    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if is_train:
        ds = ds.shuffle(buffer_size=max(len(paths), 100), seed=seed)
    ds = ds.map(_parse, num_parallel_calls=tf.data.AUTOTUNE)
    ds = ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)
    return ds


def build_model_architecture(model_type: str, img_size: tuple[int, int], num_classes: int):
    inputs = tf.keras.Input(shape=img_size + (3,))
    # Combo augmentation
    x = layers.RandomFlip("horizontal")(inputs)
    x = layers.RandomRotation(0.15)(x)
    x = layers.RandomZoom(0.15)(x)
    x = layers.RandomBrightness(0.15)(x)
    x = layers.RandomContrast(0.15)(x)

    if model_type == "efficientnetb3":
        base_model = tf.keras.applications.EfficientNetB3(
            input_shape=img_size + (3,),
            include_top=False,
            weights="imagenet",
        )
    else:
        base_model = tf.keras.applications.MobileNetV2(
            input_shape=img_size + (3,),
            include_top=False,
            weights="imagenet",
        )

    base_model.trainable = False
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation="relu")(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = models.Model(inputs, outputs)
    return model, base_model


def run_single_seed(
    exp_name: str,
    model_type: str,
    img_size: int,
    data_dir: str,
    seed: int,
    epochs1: int = 20,
    epochs2: int = 10,
    batch_size: int = 16,
) -> dict[str, Any]:
    out_dir = os.path.join(EXPERIMENTS_DIR, exp_name, f"seed_{seed}")
    os.makedirs(out_dir, exist_ok=True)
    metrics_path = os.path.join(out_dir, "metrics.json")

    # Resume check: if already completed, load and return
    if os.path.exists(metrics_path):
        print(f"[{exp_name} | Seed {seed}] Already completed. Resuming from {metrics_path}...")
        with open(metrics_path, "r", encoding="utf-8") as f:
            return json.load(f)

    print(f"\n=======================================================")
    print(f" RUNNING: {exp_name} | Seed: {seed} | Size: {img_size}x{img_size} | Model: {model_type}")
    print(f" Output: {out_dir}")
    print(f"=======================================================")

    # Set seeds
    tf.keras.utils.set_random_seed(seed)
    np.random.seed(seed)

    splits, val_splits, test_splits, class_names, class_counts = load_dataset_splits(data_dir, 30)
    train_paths, train_labels = splits
    val_paths, val_labels = val_splits
    test_paths, test_labels = test_splits
    num_classes = len(class_names)

    # Class weights
    classes_arr = np.array(train_labels)
    unique_classes = np.unique(classes_arr)
    weights = compute_class_weight(class_weight="balanced", classes=unique_classes, y=classes_arr)
    class_weights_dict = {cls: float(w) for cls, w in zip(unique_classes, weights)}

    # Datasets
    size_tuple = (img_size, img_size)
    train_ds = build_tf_dataset(train_paths, train_labels, size_tuple, model_type, batch_size, is_train=True, seed=seed)
    val_ds = build_tf_dataset(val_paths, val_labels, size_tuple, model_type, batch_size, is_train=False)
    test_ds = build_tf_dataset(test_paths, test_labels, size_tuple, model_type, batch_size, is_train=False)

    model, base_model = build_model_architecture(model_type, size_tuple, num_classes)

    # Stage 1: Transfer learning
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_loss", patience=5, restore_best_weights=True
    )

    t0 = time.time()
    hist1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=epochs1,
        class_weight=class_weights_dict,
        callbacks=[early_stop],
        verbose=1,
    )
    stage1_time = time.time() - t0
    stage1_epochs = len(hist1.history["loss"])

    # Stage 2: Fine-tuning last 30 layers
    base_model.trainable = True
    fine_tune_at = max(0, len(base_model.layers) - 30)
    for layer in base_model.layers[:fine_tune_at]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    t1 = time.time()
    hist2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=epochs2,
        class_weight=class_weights_dict,
        callbacks=[early_stop],
        verbose=1,
    )
    stage2_time = time.time() - t1
    stage2_epochs = len(hist2.history["loss"])

    total_time = stage1_time + stage2_time
    total_epochs = stage1_epochs + stage2_epochs
    time_per_epoch = round(total_time / max(1, total_epochs), 2)

    # Evaluate on test set
    y_true, y_pred = [], []
    for imgs, lbls in test_ds:
        preds = model.predict(imgs, verbose=0)
        y_pred.extend(np.argmax(preds, axis=1))
        y_true.extend(lbls.numpy())

    test_acc = float(accuracy_score(y_true, y_pred))
    macro_f1 = float(f1_score(y_true, y_pred, average="macro", zero_division=0))
    report = classification_report(y_true, y_pred, labels=list(range(num_classes)), target_names=class_names, output_dict=True, zero_division=0)
    cm = confusion_matrix(y_true, y_pred, labels=list(range(num_classes))).tolist()

    # Save candidate model & metrics
    model_path = os.path.join(out_dir, "model.keras")
    model.save(model_path)

    metrics = {
        "experiment": exp_name,
        "seed": seed,
        "model_type": model_type,
        "image_size": img_size,
        "test_accuracy": test_acc,
        "macro_f1": macro_f1,
        "per_class_f1": {c: report[c]["f1-score"] for c in class_names if c in report},
        "time_per_epoch_sec": time_per_epoch,
        "total_time_sec": round(total_time, 2),
        "total_epochs": total_epochs,
        "test_image_count": len(y_true),
        "classification_report": report,
        "confusion_matrix": cm,
        "class_names": class_names,
    }

    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(metrics, f, indent=2)

    return metrics


def generate_summary(all_results: dict[str, list[dict[str, Any]]]):
    os.makedirs(DIAGNOSTICS_DIR, exist_ok=True)
    summary_md_path = os.path.join(DIAGNOSTICS_DIR, "experiments_summary.md")
    summary_csv_path = os.path.join(DIAGNOSTICS_DIR, "experiments_summary.csv")

    summary_rows = []

    for exp_name, runs in all_results.items():
        accs = [r["test_accuracy"] for r in runs]
        f1s = [r["macro_f1"] for r in runs]
        epoch_times = [r["time_per_epoch_sec"] for r in runs]
        test_counts = [r["test_image_count"] for r in runs]
        img_size = runs[0]["image_size"]
        model_type = runs[0]["model_type"]

        mean_acc, std_acc = np.mean(accs), np.std(accs)
        mean_f1, std_f1 = np.mean(f1s), np.std(f1s)
        mean_time = np.mean(epoch_times)

        # Average per-class F1
        all_classes = runs[0]["class_names"]
        per_class_avg = {}
        for c in all_classes:
            c_f1s = [r["per_class_f1"].get(c, 0.0) for r in runs]
            per_class_avg[c] = np.mean(c_f1s)

        summary_rows.append({
            "Experiment": exp_name,
            "Architecture": model_type,
            "Image Size": f"{img_size}x{img_size}",
            "Mean Accuracy": round(mean_acc, 4),
            "Std Accuracy": round(std_acc, 4),
            "Mean Macro-F1": round(mean_f1, 4),
            "Std Macro-F1": round(std_f1, 4),
            "Avg Time/Epoch (s)": round(mean_time, 2),
            "Test Images": test_counts[0],
            "Per-Class F1": per_class_avg,
        })

    # CSV output
    with open(summary_csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Experiment", "Architecture", "ImageSize", "MeanAccuracy", "StdAccuracy", "MeanMacroF1", "StdMacroF1", "AvgTimePerEpochSec", "TestImages"])
        for r in summary_rows:
            writer.writerow([r["Experiment"], r["Architecture"], r["Image Size"], r["Mean Accuracy"], r["Std Accuracy"], r["Mean Macro-F1"], r["Std Macro-F1"], r["Avg Time/Epoch (s)"], r["Test Images"]])

    # Markdown output
    # Compare 300 vs 224
    baseline = next(r for r in summary_rows if r["Experiment"] == "combo_224")
    res300 = next(r for r in summary_rows if r["Experiment"] == "res300_combo")
    eff300 = next(r for r in summary_rows if r["Experiment"] == "effb3_300")

    f1_diff_res300 = res300["Mean Macro-F1"] - baseline["Mean Macro-F1"]
    acc_diff_res300 = res300["Mean Accuracy"] - baseline["Mean Accuracy"]
    std_combined_f1 = np.sqrt(baseline["Std Macro-F1"]**2 + res300["Std Macro-F1"]**2)

    is_res300_better = f1_diff_res300 > std_combined_f1

    md_content = f"""# Resolution & Architecture Experiments Summary

**Generated:** {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Evaluation Protocol:** 2 Seeds (42, 123), Deterministic Hash Splits, Class-Weighted Adam, Two-Stage Fine-Tuning.

---

## 1. Overall Performance Comparison

| Experiment | Architecture | Image Size | Test Accuracy (mean ± std) | Macro-F1 (mean ± std) | Time/Epoch | Test Images |
|---|---|---|---|---|---|---|
"""
    for r in summary_rows:
        md_content += f"| **{r['Experiment']}** | {r['Architecture']} | {r['Image Size']} | {r['Mean Accuracy']:.4f} ± {r['Std Accuracy']:.4f} | {r['Mean Macro-F1']:.4f} ± {r['Std Macro-F1']:.4f} | {r['Avg Time/Epoch (s)']}s | {r['Test Images']} |\n"

    md_content += f"""
---

## 2. Per-Class F1 Breakdown

| Variety Class | combo_224 (224px) | res300_combo (300px) | effb3_300 (300px) |
|---|---|---|---|
"""
    for c in baseline["Per-Class F1"].keys():
        f1_224 = baseline["Per-Class F1"].get(c, 0.0)
        f1_300 = res300["Per-Class F1"].get(c, 0.0)
        f1_eff = eff300["Per-Class F1"].get(c, 0.0)
        md_content += f"| **{c}** | {f1_224:.4f} | {f1_300:.4f} | {f1_eff:.4f} |\n"

    md_content += f"""
---

## 3. Findings & Conclusion

- **Baseline (`combo_224`):** Macro-F1 = {baseline['Mean Macro-F1']:.4f} ± {baseline['Std Macro-F1']:.4f}, Accuracy = {baseline['Mean Accuracy']:.4f} ± {baseline['Std Accuracy']:.4f}.
- **MobileNetV2 @ 300px (`res300_combo`):** Macro-F1 = {res300['Mean Macro-F1']:.4f} ± {res300['Std Macro-F1']:.4f}, Accuracy = {res300['Mean Accuracy']:.4f} ± {res300['Std Accuracy']:.4f}.
  * Difference vs 224px: ΔMacro-F1 = {f1_diff_res300:+.4f}, ΔAccuracy = {acc_diff_res300:+.4f}.
- **Is 300px better than 224px by more than the seed standard deviation?**
  * **{'YES' if is_res300_better else 'NO'}**: The Macro-F1 delta ({f1_diff_res300:+.4f}) {'exceeds' if is_res300_better else 'does not exceed'} the seed pooled standard deviation (±{std_combined_f1:.4f}).
- **EfficientNetB3 @ 300px (`effb3_300`):** Macro-F1 = {eff300['Mean Macro-F1']:.4f} ± {eff300['Std Macro-F1']:.4f}, Accuracy = {eff300['Mean Accuracy']:.4f} ± {eff300['Std Accuracy']:.4f}.
  * Average epoch duration: {eff300['Avg Time/Epoch (s)']}s vs {res300['Avg Time/Epoch (s)']}s for MobileNetV2.

---
*Note: Active production model in `app/ml/model/` was preserved and unmodified.*
"""

    with open(summary_md_path, "w", encoding="utf-8") as f:
        f.write(md_content)

    print(f"\n[SUMMARY] Saved experiment diagnostics:")
    print(f"  Markdown: {summary_md_path}")
    print(f"  CSV:      {summary_csv_path}")


def main():
    parser = argparse.ArgumentParser(description="Run 224px vs 300px resolution experiments")
    parser.add_argument("--seeds", type=int, default=2, help="Number of random seeds (default 2)")
    args = parser.parse_args()

    configure_hardware_limits()

    seed_list = [42, 123][:args.seeds]
    experiments = [
        ("combo_224", "mobilenetv2", 224, os.path.join(DATA_DIR, "images", "processed")),
        ("res300_combo", "mobilenetv2", 300, os.path.join(DATA_DIR, "images", "processed_300")),
        ("effb3_300", "efficientnetb3", 300, os.path.join(DATA_DIR, "images", "processed_300")),
    ]

    all_results = {}
    for exp_name, model_type, img_size, data_dir in experiments:
        all_results[exp_name] = []
        for seed in seed_list:
            res = run_single_seed(exp_name, model_type, img_size, data_dir, seed)
            all_results[exp_name].append(res)

    generate_summary(all_results)


if __name__ == "__main__":
    main()
