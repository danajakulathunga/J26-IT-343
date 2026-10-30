"""
Run Report Generator (Phase H4).
Generates comprehensive visual and tabular performance reports for a trained model run directory.

CLI:
  python -m app.ml.report --run <run_dir> [--eval-dir data/eval_newbg] [--out-dir <out_dir>]

Outputs in <run_dir>/report/:
  - accuracy_curve.png (Train vs Val accuracy, dashed line at Stage 2 start)
  - loss_curve.png (Train vs Val loss, dashed line at Stage 2 start)
  - classification_report.txt & .json
  - confusion_matrix.png & confusion_matrix_normalized.png
  - summary.md (Labelled: "same-session, not a generalisation estimate" for test split)
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from app.ml.predictor import prepare_input_tensor

DEFAULT_EVAL_SPLIT_LABEL = "same-session, not a generalisation estimate"


def parse_args():
    parser = argparse.ArgumentParser(description="Generate comprehensive training and evaluation report")
    parser.add_argument("--run", "--run-dir", dest="run_dir", type=str, required=True, help="Path to run or model directory")
    parser.add_argument("--eval-dir", type=str, default=None, help="Optional external evaluation directory (e.g. data/eval_newbg)")
    parser.add_argument("--out-dir", type=str, default=None, help="Directory to save report artifacts (default: <run_dir>/report)")
    return parser.parse_args()


def load_history(run_dir: str) -> Optional[List[Dict[str, Any]]]:
    """Loads history.json or history.csv from run_dir."""
    hist_json_path = os.path.join(run_dir, "history.json")
    if os.path.isfile(hist_json_path):
        try:
            with open(hist_json_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"[WARN] Failed to load {hist_json_path}: {e}")

    hist_csv_path = os.path.join(run_dir, "history.csv")
    if os.path.isfile(hist_csv_path):
        import csv
        try:
            records = []
            with open(hist_csv_path, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    records.append({
                        "global_epoch": int(row["global_epoch"]),
                        "stage": int(row["stage"]),
                        "loss": float(row["loss"]),
                        "val_loss": float(row["val_loss"]),
                        "accuracy": float(row["accuracy"]),
                        "val_accuracy": float(row["val_accuracy"]),
                        "learning_rate": float(row["learning_rate"]) if row.get("learning_rate") else None,
                    })
            return records
        except Exception as e:
            print(f"[WARN] Failed to load {hist_csv_path}: {e}")

    return None


def plot_accuracy_curve(history: List[Dict[str, Any]], out_path: str, stage2_start: Optional[int] = None):
    epochs = [r["global_epoch"] for r in history]
    train_acc = [r["accuracy"] for r in history]
    val_acc = [r["val_accuracy"] for r in history]

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(epochs, train_acc, label="Train Accuracy", marker="o", color="#2563EB", linewidth=2)
    ax.plot(epochs, val_acc, label="Val Accuracy", marker="s", color="#059669", linewidth=2)

    if stage2_start is not None and stage2_start in epochs:
        ax.axvline(x=stage2_start, color="#DC2626", linestyle="--", linewidth=1.5, label=f"Stage 2 Start (Epoch {stage2_start})")

    ax.set_title("Training & Validation Accuracy", fontsize=14, fontweight="bold", pad=12)
    ax.set_xlabel("Global Epoch", fontsize=11)
    ax.set_ylabel("Accuracy", fontsize=11)
    ax.set_ylim([0.0, 1.02])
    ax.grid(True, linestyle=":", alpha=0.6)
    ax.legend(loc="lower right", framealpha=0.9)
    plt.tight_layout()
    plt.savefig(out_path, dpi=150)
    plt.close()


def plot_loss_curve(history: List[Dict[str, Any]], out_path: str, stage2_start: Optional[int] = None):
    epochs = [r["global_epoch"] for r in history]
    train_loss = [r["loss"] for r in history]
    val_loss = [r["val_loss"] for r in history]

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(epochs, train_loss, label="Train Loss", marker="o", color="#2563EB", linewidth=2)
    ax.plot(epochs, val_loss, label="Val Loss", marker="s", color="#059669", linewidth=2)

    if stage2_start is not None and stage2_start in epochs:
        ax.axvline(x=stage2_start, color="#DC2626", linestyle="--", linewidth=1.5, label=f"Stage 2 Start (Epoch {stage2_start})")

    ax.set_title("Training & Validation Loss", fontsize=14, fontweight="bold", pad=12)
    ax.set_xlabel("Global Epoch", fontsize=11)
    ax.set_ylabel("Loss", fontsize=11)
    ax.grid(True, linestyle=":", alpha=0.6)
    ax.legend(loc="upper right", framealpha=0.9)
    plt.tight_layout()
    plt.savefig(out_path, dpi=150)
    plt.close()


def plot_confusion_matrix_heatmap(cm: np.ndarray, class_names: List[str], out_path: str, normalize: bool = False):
    fig, ax = plt.subplots(figsize=(8, 7))

    if normalize:
        cm_sum = cm.sum(axis=1)[:, np.newaxis]
        cm_data = np.divide(cm.astype(float), cm_sum, out=np.zeros_like(cm, dtype=float), where=cm_sum != 0)
        im = ax.imshow(cm_data, interpolation="nearest", cmap="Blues", vmin=0.0, vmax=1.0)
        title = "Normalized Confusion Matrix (Recall / Row %)"
    else:
        cm_data = cm
        im = ax.imshow(cm_data, interpolation="nearest", cmap="Blues")
        title = "Confusion Matrix (Sample Counts)"

    ax.figure.colorbar(im, ax=ax, fraction=0.046, pad=0.04)

    tick_marks = np.arange(len(class_names))
    ax.set_xticks(tick_marks)
    ax.set_yticks(tick_marks)
    ax.set_xticklabels(class_names, rotation=45, ha="right", fontsize=9)
    ax.set_yticklabels(class_names, fontsize=9)

    thresh = cm_data.max() / 2.0 if cm_data.max() > 0 else 1.0
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            val = cm_data[i, j]
            text = f"{val:.2f}" if normalize else f"{int(val)}"
            color = "white" if val > thresh else "black"
            ax.text(j, i, text, ha="center", va="center", color=color, fontsize=10, fontweight="bold")

    ax.set_title(title, fontsize=13, fontweight="bold", pad=12)
    ax.set_ylabel("True Class", fontsize=11, fontweight="bold")
    ax.set_xlabel("Predicted Class", fontsize=11, fontweight="bold")
    plt.tight_layout()
    plt.savefig(out_path, dpi=150)
    plt.close()


def evaluate_with_model(
    model_path: str,
    test_recs: List[Dict[str, Any]],
    config: Dict[str, Any],
    class_names: List[str],
) -> Tuple[np.ndarray, np.ndarray]:
    """Runs inference on test_recs using prepare_input_tensor."""
    import tensorflow as tf

    print(f"Loading model for evaluation: {model_path}")
    model = tf.keras.models.load_model(model_path, compile=False)

    class_to_idx = {c: i for i, c in enumerate(class_names)}
    y_true: List[int] = []
    y_pred: List[int] = []

    print(f"Running inference on {len(test_recs)} test images via prepare_input_tensor...")
    batch_size = 32
    for start_idx in range(0, len(test_recs), batch_size):
        batch_recs = test_recs[start_idx : start_idx + batch_size]
        batch_tensors = []
        batch_labels = []

        for r in batch_recs:
            p = r["path"]
            # Determine if already processed
            already_processed = "processed" in p.replace("\\", "/").lower()
            with open(p, "rb") as f:
                raw_bytes = f.read()

            t = prepare_input_tensor(
                image_source=raw_bytes,
                config=config,
                already_processed=already_processed,
                remove_bg=None,
            )
            batch_tensors.append(t[0])
            batch_labels.append(class_to_idx[r["label_name"]])

        stacked_tensors = np.stack(batch_tensors, axis=0)
        preds = model.predict(stacked_tensors, verbose=0)
        pred_indices = np.argmax(preds, axis=1)

        y_true.extend(batch_labels)
        y_pred.extend(pred_indices.tolist())

    return np.array(y_true), np.array(y_pred)


def evaluate_external_dir(
    model_path: str,
    eval_dir: str,
    config: Dict[str, Any],
    class_names: List[str],
) -> Tuple[np.ndarray, np.ndarray]:
    """Runs inference on external evaluation directory using prepare_input_tensor."""
    import tensorflow as tf

    print(f"Loading model for evaluation: {model_path}")
    model = tf.keras.models.load_model(model_path, compile=False)

    class_to_idx = {c: i for i, c in enumerate(class_names)}
    valid_exts = {".jpg", ".jpeg", ".png", ".webp", ".heic"}

    samples: List[Tuple[str, int]] = []
    for c in class_names:
        c_dir = os.path.join(eval_dir, c)
        if os.path.isdir(c_dir):
            for fname in sorted(os.listdir(c_dir)):
                if os.path.splitext(fname)[1].lower() in valid_exts:
                    samples.append((os.path.join(c_dir, fname), class_to_idx[c]))

    if not samples:
        raise ValueError(f"No valid evaluation images found in {eval_dir}")

    print(f"Found {len(samples)} images in {eval_dir}. Running inference...")
    y_true: List[int] = []
    y_pred: List[int] = []

    for p, true_idx in samples:
        with open(p, "rb") as f:
            raw_bytes = f.read()
        tensor = prepare_input_tensor(
            image_source=raw_bytes,
            config=config,
            already_processed=False,
            remove_bg=None,
        )
        pred = model.predict(tensor, verbose=0)[0]
        y_true.append(true_idx)
        y_pred.append(int(np.argmax(pred)))

    return np.array(y_true), np.array(y_pred)


def generate_report(
    run_dir: str,
    eval_dir: Optional[str] = None,
    out_dir: Optional[str] = None,
) -> Dict[str, Any]:
    run_dir = os.path.abspath(run_dir)
    report_dir = os.path.abspath(out_dir) if out_dir else os.path.join(run_dir, "report")
    os.makedirs(report_dir, exist_ok=True)

    print(f"\n=======================================================")
    print(f" Generating Run Report")
    print(f" Run Directory   : {run_dir}")
    print(f" Report Directory: {report_dir}")
    if eval_dir:
        print(f" External Eval   : {eval_dir}")
    print(f"=======================================================\n")

    # 1. Load config and class names
    config_path = os.path.join(run_dir, "config.json")
    model_config_path = os.path.join(run_dir, "model_config.json")
    classes_path = os.path.join(run_dir, "class_names.txt")
    metrics_path = os.path.join(run_dir, "metrics.json")
    model_path = os.path.join(run_dir, "model.keras")

    config: Dict[str, Any] = {}
    if os.path.isfile(config_path):
        with open(config_path, "r", encoding="utf-8") as f:
            config = json.load(f)
    elif os.path.isfile(model_config_path):
        with open(model_config_path, "r", encoding="utf-8") as f:
            config = json.load(f)

    class_names: List[str] = []
    if os.path.isfile(classes_path):
        with open(classes_path, "r", encoding="utf-8") as f:
            class_names = [line.strip() for line in f if line.strip()]
    elif "classes_used" in config:
        class_names = config["classes_used"]
    else:
        class_names = [
            "Ambul_Banana",
            "Ambun_Banana",
            "Anamalu_Banana",
            "Cavendish_Banana",
            "Kolikuttu_Banana",
            "Red_Banana",
            "Seeni_Banana",
        ]

    # 2. History & Training Curves
    history = load_history(run_dir)
    stage2_start = None
    if history:
        for r in history:
            if r.get("stage") == 2:
                stage2_start = r.get("global_epoch")
                break

        acc_curve_path = os.path.join(report_dir, "accuracy_curve.png")
        loss_curve_path = os.path.join(report_dir, "loss_curve.png")
        plot_accuracy_curve(history, acc_curve_path, stage2_start)
        plot_loss_curve(history, loss_curve_path, stage2_start)
        print(f"Saved accuracy curve to: {acc_curve_path}")
        print(f"Saved loss curve to: {loss_curve_path}")
    else:
        print("[WARN] No history.json or history.csv found; curve plots skipped.")

    # 3. Evaluation & Metrics
    y_true: Optional[np.ndarray] = None
    y_pred: Optional[np.ndarray] = None
    eval_split_label = DEFAULT_EVAL_SPLIT_LABEL

    if eval_dir:
        eval_split_label = f"External Evaluation ({os.path.basename(eval_dir)})"
        if os.path.isfile(model_path):
            y_true, y_pred = evaluate_external_dir(model_path, eval_dir, config, class_names)
    elif os.path.isfile(model_path):
        # Evaluate on the dataset test split via prepare_input_tensor
        try:
            from app.ml.training.train_pipeline import load_dataset_records, partition_dataset

            data_dir = os.path.join(BASE_DIR, "data", "images", "processed")
            labels_file = os.path.join(BASE_DIR, "data", "labels.json")
            holdout_file = os.path.join(BASE_DIR, "data", "holdout.json")
            task = config.get("task", "variety")
            split_mode = config.get("split_mode", "group")

            records, _, _ = load_dataset_records(data_dir, labels_file, task, 30, classes=class_names)
            _, _, test_recs, _ = partition_dataset(records, split_mode, holdout_file)

            if test_recs:
                y_true, y_pred = evaluate_with_model(model_path, test_recs, config, class_names)
        except Exception as e:
            print(f"[WARN] Live evaluation on dataset failed ({e}); checking stored metrics...")

    # Fallback to metrics.json if live evaluation was not run or succeeded
    stored_metrics: Dict[str, Any] = {}
    if os.path.isfile(metrics_path):
        with open(metrics_path, "r", encoding="utf-8") as f:
            stored_metrics = json.load(f)

    if y_true is None or y_pred is None:
        if "confusion_matrix" in stored_metrics:
            cm = np.array(stored_metrics["confusion_matrix"])
            # Reconstruct y_true, y_pred
            y_t, y_p = [], []
            for i in range(cm.shape[0]):
                for j in range(cm.shape[1]):
                    cnt = int(cm[i, j])
                    y_t.extend([i] * cnt)
                    y_p.extend([j] * cnt)
            y_true = np.array(y_t)
            y_pred = np.array(y_p)
        else:
            raise RuntimeError(f"Unable to compute evaluation metrics: no test images evaluated and no confusion matrix in {metrics_path}")

    # Compute metrics
    acc = float(accuracy_score(y_true, y_pred)) if len(y_true) else 0.0
    macro_f1 = float(f1_score(y_true, y_pred, average="macro", zero_division=0)) if len(y_true) else 0.0
    cm = confusion_matrix(y_true, y_pred, labels=list(range(len(class_names))))
    report_dict = classification_report(
        y_true, y_pred, labels=list(range(len(class_names))), target_names=class_names, output_dict=True, zero_division=0
    )
    report_txt = classification_report(
        y_true, y_pred, labels=list(range(len(class_names))), target_names=class_names, zero_division=0
    )

    # 4. Save Classification Reports
    txt_report_path = os.path.join(report_dir, "classification_report.txt")
    with open(txt_report_path, "w", encoding="utf-8") as f:
        f.write(report_txt)

    json_report_path = os.path.join(report_dir, "classification_report.json")
    with open(json_report_path, "w", encoding="utf-8") as f:
        json.dump(report_dict, f, indent=2)

    # 5. Plot Confusion Matrices
    cm_path = os.path.join(report_dir, "confusion_matrix.png")
    cm_norm_path = os.path.join(report_dir, "confusion_matrix_normalized.png")
    plot_confusion_matrix_heatmap(cm, class_names, cm_path, normalize=False)
    plot_confusion_matrix_heatmap(cm, class_names, cm_norm_path, normalize=True)
    print(f"Saved confusion matrix to: {cm_path}")
    print(f"Saved normalized confusion matrix to: {cm_norm_path}")

    # 6. Generate summary.md
    summary_path = os.path.join(report_dir, "summary.md")
    run_name = config.get("run_name") or os.path.basename(run_dir)

    train_epochs_s1 = sum(1 for r in (history or []) if r.get("stage") == 1)
    train_epochs_s2 = sum(1 for r in (history or []) if r.get("stage") == 2)
    final_train_acc = history[-1]["accuracy"] if history else "N/A"
    final_val_acc = history[-1]["val_accuracy"] if history else "N/A"
    final_train_loss = history[-1]["loss"] if history else "N/A"
    final_val_loss = history[-1]["val_loss"] if history else "N/A"

    final_val_loss = history[-1]["val_loss"] if history else "N/A"

    # Held-out bunch classes vs same-session classes
    heldout_classes = [c for c in class_names if c in ("Ambul_Banana", "Anamalu_Banana", "Kolikuttu_Banana", "Red_Banana", "Seeni_Banana")]
    samesession_classes = [c for c in class_names if c in ("Ambun_Banana", "Cavendish_Banana")]

    def make_sub_report(target_classes: List[str]):
        indices = [class_names.index(c) for c in target_classes]
        # Filter samples where y_true is in target_classes
        mask = np.isin(y_true, indices)
        sub_yt = y_true[mask]
        sub_yp = y_pred[mask]
        if len(sub_yt) == 0:
            return "No samples evaluated.", "", 0.0, 0.0

        sub_acc = float(accuracy_score(sub_yt, sub_yp))
        sub_f1 = float(f1_score(sub_yt, sub_yp, average="macro", zero_division=0))

        # Per class stats
        rows = []
        for c in target_classes:
            idx = class_names.index(c)
            c_mask = (sub_yt == idx)
            sup = int(np.sum(c_mask))
            p = float(report_dict.get(c, {}).get("precision", 0.0))
            r = float(report_dict.get(c, {}).get("recall", 0.0))
            f = float(report_dict.get(c, {}).get("f1-score", 0.0))
            rows.append(f"| `{c}` | {p:.4f} | {r:.4f} | {f:.4f} | {sup} |")
        table_md = "\n".join(rows)

        # Sub-confusion matrix
        sub_cm = confusion_matrix(sub_yt, sub_yp, labels=indices)
        header_cols = " | ".join([f"`{c.replace('_Banana', '')}`" for c in target_classes])
        cm_md = f"| True \\ Pred | {header_cols} |\n"
        cm_md += "| :--- | " + " | ".join([":---:"] * len(target_classes)) + " |\n"
        for i, row in enumerate(sub_cm):
            row_str = " | ".join([str(v) for v in row])
            cm_md += f"| `{target_classes[i].replace('_Banana', '')}` | {row_str} |\n"

        return table_md, cm_md, sub_acc, sub_f1

    ho_table, ho_cm, ho_acc, ho_f1 = make_sub_report(heldout_classes)
    ss_table, ss_cm, ss_acc, ss_f1 = make_sub_report(samesession_classes)

    summary_content = f"""# Run Report: {run_name}

> [!WARNING]
> **Evaluation Split Label**: `{eval_split_label}`
> Accuracy and F1 scores reported on this split are divided into true **held-out session bunches** (unseen physical bunches) and **same-session test** (classes with < 3 bunches where hash fallback was used).

---

## 1. Key Performance Indicators

| Metric | Score | Note |
| :--- | :--- | :--- |
| **Overall Test Accuracy** | **{acc * 100.0:.2f}%** ({acc:.4f}) | {eval_split_label} ({len(y_true)} images) |
| **Held-Out Bunch Test Accuracy** | **{ho_acc * 100.0:.2f}%** ({ho_acc:.4f}) | Held-out sessions only (Ambul, Anamalu, Kolikuttu, Red, Seeni) |
| **Same-Session Test Accuracy** | **{ss_acc * 100.0:.2f}%** ({ss_acc:.4f}) | Ambun and Cavendish (not a generalisation estimate) |
| **Overall Macro F1 Score** | **{macro_f1:.4f}** | Unweighted mean across {len(class_names)} classes |
| **Model Architecture** | `{config.get('architecture', 'unknown')}` | Preprocessing: `{config.get('preprocessing', 'raw_0_255')}` |

---

## 2A. Held-Out Bunch Test ("held-out sessions")
*Classes with $\ge 3$ bunches where full physical bunches were held out exclusively in test (Ambul, Anamalu, Kolikuttu, Red, Seeni).*

| Class | Precision | Recall | F1-Score | Support (Images) |
| :--- | :---: | :---: | :---: | :---: |
{ho_table}

#### Confusion Matrix (Held-Out Sessions):
{ho_cm}

---

## 2B. Same-Session Test ("same-session, not a generalisation estimate")
*Classes with $< 3$ bunches that fell back to hash splitting (Ambun and Cavendish).*

| Class | Precision | Recall | F1-Score | Support (Images) |
| :--- | :---: | :---: | :---: | :---: |
{ss_table}

#### Confusion Matrix (Same-Session):
{ss_cm}

---


## 3. Training & Convergence Summary

- **Total Epochs Trained**: {len(history) if history else 'N/A'} (Stage 1: {train_epochs_s1}, Stage 2: {train_epochs_s2})
- **Stage 1 Learning Rate**: `{config.get('lr_stage1', 1e-3)}`
- **Stage 2 Learning Rate**: `{config.get('lr_stage2', 1e-5)}`
- **Final Training Accuracy / Loss**: `{final_train_acc}` / `{final_train_loss}`
- **Final Validation Accuracy / Loss**: `{final_val_acc}` / `{final_val_loss}`
- **ReduceLROnPlateau**: factor={config.get('reduce_lr_factor', 0.5)}, min_lr={config.get('reduce_lr_min_lr', 1e-6)}, patience={config.get('reduce_lr_patience', 2)}
- **EarlyStopping Patience**: {config.get('early_stopping_patience', 5)}
- **Unfrozen Fraction**: {config.get('unfreeze_fraction', 'N/A')} ({config.get('unfrozen_layers_count', 'N/A')} layers)
- **Batch Size / Seed**: {config.get('batch_size', 32)} / {config.get('seed', 42)}
- **Label Smoothing**: {config.get('label_smoothing', 0.0)}
- **Background-Swap Augmentation Prob**: `{config.get('bg_swap_prob', 0.0)}`

---

## 4. Visual Artifacts

The following visual artifacts were generated in `report/`:
- **[accuracy_curve.png](accuracy_curve.png)**: Train vs Validation accuracy with dashed vertical line at Stage 2 start.
- **[loss_curve.png](loss_curve.png)**: Train vs Validation loss curve across all epochs.
- **[confusion_matrix.png](confusion_matrix.png)**: Sample counts matrix.
- **[confusion_matrix_normalized.png](confusion_matrix_normalized.png)**: Row-normalized recall matrix.
"""

    with open(summary_path, "w", encoding="utf-8") as f:
        f.write(summary_content)

    print(f"Saved summary report to: {summary_path}")

    return {
        "accuracy": acc,
        "macro_f1": macro_f1,
        "total_samples": len(y_true),
        "report_dir": report_dir,
    }


def main():
    args = parse_args()
    generate_report(run_dir=args.run_dir, eval_dir=args.eval_dir, out_dir=args.out_dir)


if __name__ == "__main__":
    main()
