"""
Independent Dataset Evaluation Utility (Phase H3).
Evaluates a variety classifier on an arbitrary evaluation directory (e.g. data/eval_newbg/<Class>/)
using the EXACT SAME shared prepare_input_tensor path as the live predictor.
Guarantees zero divergent or parallel preprocessing.

Reports:
- Overall Accuracy
- Macro F1
- Per-class precision, recall, F1, support
- Confusion matrix
- Most frequent prediction for each true class
Saves structured report to data/diagnostics/.
"""

import argparse
import json
import os
from collections import Counter
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score

from app.ml.predictor import prepare_input_tensor

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
DEFAULT_EVAL_DIR = os.path.join(BASE_DIR, "data", "eval_newbg")
DEFAULT_DIAGNOSTICS_DIR = os.path.join(BASE_DIR, "data", "diagnostics")

MVP_CLASSES = [
    "Ambul_Banana",
    "Ambun_Banana",
    "Anamalu_Banana",
    "Kolikuttu_Banana",
    "Red_Banana",
    "Seeni_Banana",
]


def evaluate_dataset(
    model_path: str,
    eval_dir: str = DEFAULT_EVAL_DIR,
    config: Optional[Dict[str, Any]] = None,
    class_names: Optional[List[str]] = None,
    out_json: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Evaluates model on eval_dir using shared prepare_input_tensor.
    """
    if not os.path.isfile(model_path):
        raise FileNotFoundError(f"Model file not found: {model_path}")

    if not os.path.isdir(eval_dir):
        raise FileNotFoundError(f"Evaluation directory not found: {eval_dir}")

    # Determine model directory and locate config & classes if not provided
    model_dir = os.path.dirname(model_path)
    if config is None:
        cfg_path = os.path.join(model_dir, "model_config.json")
        if os.path.isfile(cfg_path):
            with open(cfg_path, "r", encoding="utf-8") as f:
                config = json.load(f)
        else:
            config = {"architecture": "efficientnetb3", "image_size": [300, 300]}

    if class_names is None:
        classes_path = os.path.join(model_dir, "class_names.txt")
        if os.path.isfile(classes_path):
            with open(classes_path, "r", encoding="utf-8") as f:
                class_names = [line.strip() for line in f if line.strip()]
        else:
            class_names = MVP_CLASSES

    class_to_idx = {c: i for i, c in enumerate(class_names)}

    # Scan eval_dir: expects class subfolders
    samples: List[tuple[str, int, str]] = []
    valid_exts = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp"}

    for c in class_names:
        c_dir = os.path.join(eval_dir, c)
        if os.path.isdir(c_dir):
            for fname in sorted(os.listdir(c_dir)):
                ext = os.path.splitext(fname)[1].lower()
                if ext in valid_exts:
                    samples.append((os.path.join(c_dir, fname), class_to_idx[c], c))

    if not samples:
        print(f"[WARN] No evaluation images found in {eval_dir}.")
        return {
            "status": "empty",
            "eval_dir": eval_dir,
            "total_images": 0,
            "accuracy": None,
            "macro_f1": None,
        }

    print(f"\nEvaluating on {len(samples)} images across {len(class_names)} classes from: {eval_dir}")
    for c in class_names:
        cnt = sum(1 for s in samples if s[2] == c)
        print(f"  {c:<20}: {cnt} images")

    # Load model
    print(f"Loading model: {model_path}")
    model = tf.keras.models.load_model(model_path, compile=False)

    y_true: List[int] = []
    y_pred: List[int] = []
    predictions_per_class: Dict[str, List[str]] = {c: [] for c in class_names}

    for fpath, true_idx, true_cls in samples:
        with open(fpath, "rb") as f:
            raw_bytes = f.read()

        # Shared live predictor input tensor function (already_processed=False)
        tensor = prepare_input_tensor(
            image_source=raw_bytes,
            config=config,
            already_processed=False,
            remove_bg=None,
        )

        preds = model.predict(tensor, verbose=0)[0]
        pred_idx = int(np.argmax(preds))
        pred_cls = class_names[pred_idx] if pred_idx < len(class_names) else f"Class_{pred_idx}"

        y_true.append(true_idx)
        y_pred.append(pred_idx)
        predictions_per_class[true_cls].append(pred_cls)

    # Metrics
    num_classes = len(class_names)
    acc = float(accuracy_score(y_true, y_pred))
    macro_f1 = float(f1_score(y_true, y_pred, average="macro", zero_division=0))
    report = classification_report(
        y_true,
        y_pred,
        labels=list(range(num_classes)),
        target_names=class_names,
        output_dict=True,
        zero_division=0,
    )
    cm = confusion_matrix(y_true, y_pred, labels=list(range(num_classes))).tolist()

    # Determine what the model predicted most often for each class
    most_frequent_predictions: Dict[str, Dict[str, Any]] = {}
    for c in class_names:
        preds_list = predictions_per_class[c]
        if preds_list:
            counts = Counter(preds_list)
            top_pred, top_count = counts.most_common(1)[0]
            most_frequent_predictions[c] = {
                "most_frequent_prediction": top_pred,
                "count": top_count,
                "total": len(preds_list),
                "frequency_pct": round(top_count / len(preds_list) * 100.0, 2),
                "is_correct": top_pred == c,
                "distribution": dict(counts),
            }
        else:
            most_frequent_predictions[c] = {
                "most_frequent_prediction": None,
                "count": 0,
                "total": 0,
                "frequency_pct": 0.0,
                "is_correct": False,
                "distribution": {},
            }

    results = {
        "status": "completed",
        "model_path": model_path,
        "eval_dir": eval_dir,
        "total_images": len(samples),
        "overall_accuracy": round(acc, 4),
        "macro_f1": round(macro_f1, 4),
        "per_class_report": report,
        "confusion_matrix": cm,
        "class_names": class_names,
        "most_frequent_predictions": most_frequent_predictions,
    }

    # Save to diagnostics
    if out_json:
        os.makedirs(os.path.dirname(out_json), exist_ok=True)
        with open(out_json, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=2)
        print(f"\nSaved evaluation report to: {out_json}")

    return results


def main():
    parser = argparse.ArgumentParser(description="Evaluate variety model on independent dataset")
    parser.add_argument("--eval-dir", type=str, default=DEFAULT_EVAL_DIR, help="Evaluation images directory")
    parser.add_argument("--model-path", type=str, default=None, help="Path to .keras model file")
    parser.add_argument("--version-id", type=str, default=None, help="Model version ID (e.g. v0004)")
    parser.add_argument("--out-json", type=str, default=None, help="Output JSON report path")
    args = parser.parse_args()

    # Determine model path
    if args.model_path:
        m_path = args.model_path
    elif args.version_id:
        m_path = os.path.join(BASE_DIR, "app", "ml", "model_versions", args.version_id, "model.keras")
    else:
        # Default to v0004
        m_path = os.path.join(BASE_DIR, "app", "ml", "model_versions", "v0004", "model.keras")
        if not os.path.isfile(m_path):
            m_path = os.path.join(BASE_DIR, "app", "ml", "model", "variety_classifier.keras")

    vid = args.version_id or os.path.basename(os.path.dirname(m_path))
    out_json = args.out_json or os.path.join(DEFAULT_DIAGNOSTICS_DIR, f"eval_newbg_baseline_{vid}.json")

    results = evaluate_dataset(
        model_path=m_path,
        eval_dir=args.eval_dir,
        out_json=out_json,
    )

    if results.get("status") == "completed":
        print("\n================== EVALUATION RESULTS ==================")
        print(f"Model: {m_path}")
        print(f"Overall Accuracy: {results['overall_accuracy']*100:.2f}% | Macro F1: {results['macro_f1']:.4f}")
        print("\nMost Frequent Predictions by True Class:")
        for c, info in results["most_frequent_predictions"].items():
            if info["total"] > 0:
                mark = "[CORRECT]" if info["is_correct"] else "[MISCLASSIFIED]"
                print(f"  {c:<20} -> {info['most_frequent_prediction']:<20} ({info['frequency_pct']}%) {mark}")


if __name__ == "__main__":
    main()
