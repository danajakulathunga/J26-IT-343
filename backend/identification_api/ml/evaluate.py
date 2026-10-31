"""BananaGuard AI - Model Evaluation & Performance Analytics
Computes precision, recall, F1-score, accuracy, and confusion matrices
for both Condition (17 classes) and Severity (3 classes) heads.
"""

import argparse
import os
import numpy as np
import pandas as pd
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score, precision_recall_fscore_support
import tensorflow as tf
from keras.preprocessing.image import load_img, img_to_array
from keras.applications.efficientnet import preprocess_input

from train import CONDITION_MAP, SEVERITY_MAP, IMG_SIZE, masked_severity_loss

REV_COND_MAP = {v: k for k, v in CONDITION_MAP.items()}
REV_SEV_MAP = {v: k for k, v in SEVERITY_MAP.items()}


def evaluate_model(model_path: str, test_csv: str, image_dir: str = ""):
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Trained model not found at {model_path}")
    if not os.path.exists(test_csv):
        raise FileNotFoundError(f"Test split dataset not found at {test_csv}")

    print(f"Loading model from {model_path}...")
    model = tf.keras.models.load_model(
        model_path,
        custom_objects={"masked_severity_loss": masked_severity_loss}
    )

    df_test = pd.read_csv(test_csv)
    print(f"Loaded {len(df_test)} test samples.")

    y_cond_true = []
    y_cond_pred = []
    y_sev_true = []
    y_sev_pred = []

    for _, row in df_test.iterrows():
        img_path = os.path.join(image_dir, str(row["image_path"])) if image_dir else str(row["image_path"])
        if not os.path.exists(img_path):
            continue

        img = load_img(img_path, target_size=IMG_SIZE)
        arr = img_to_array(img)
        batch = np.expand_dims(preprocess_input(arr), axis=0)

        preds = model.predict(batch, verbose=0)
        cond_probs = preds[0][0]
        sev_probs = preds[1][0]

        pred_cond_idx = int(np.argmax(cond_probs))
        true_cond_str = str(row["condition"]).lower().strip().replace(" ", "_")
        true_cond_idx = CONDITION_MAP.get(true_cond_str, -1)

        if true_cond_idx >= 0:
            y_cond_true.append(true_cond_idx)
            y_cond_pred.append(pred_cond_idx)

        # Severity evaluation (exclude healthy)
        true_sev_str = str(row["severity"]).lower().strip()
        if true_sev_str in SEVERITY_MAP:
            true_sev_idx = SEVERITY_MAP[true_sev_str]
            pred_sev_idx = int(np.argmax(sev_probs))
            y_sev_true.append(true_sev_idx)
            y_sev_pred.append(pred_sev_idx)

    # Metrics: Condition Head
    print("\n" + "=" * 60)
    print("CONDITION CLASSIFICATION EVALUATION (17 CLASSES)")
    print("=" * 60)
    print(f"Overall Accuracy: {accuracy_score(y_cond_true, y_cond_pred):.4f}")
    target_names = [REV_COND_MAP[i] for i in range(len(CONDITION_MAP))]
    print("\nClassification Report:")
    print(classification_report(y_cond_true, y_cond_pred, target_names=target_names, zero_division=0))
    print("\nConfusion Matrix:")
    print(confusion_matrix(y_cond_true, y_cond_pred))

    # Metrics: Severity Head
    if y_sev_true:
        print("\n" + "=" * 60)
        print("SEVERITY CLASSIFICATION EVALUATION (3 CLASSES: MILD, MODERATE, SEVERE)")
        print("=" * 60)
        print(f"Overall Accuracy: {accuracy_score(y_sev_true, y_sev_pred):.4f}")
        sev_target_names = [REV_SEV_MAP[i] for i in range(len(SEVERITY_MAP))]
        print("\nClassification Report:")
        print(classification_report(y_sev_true, y_sev_pred, target_names=sev_target_names, zero_division=0))
        print("\nConfusion Matrix:")
        print(confusion_matrix(y_sev_true, y_sev_pred))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluate BananaGuard AI multi-head model.")
    parser.add_argument("--model", type=str, default="ml/models/bananaguard_model.keras")
    parser.add_argument("--test-csv", type=str, default="ml/models/test_split.csv")
    parser.add_argument("--image-dir", type=str, default="")
    args = parser.parse_args()

    evaluate_model(args.model, args.test_csv, args.image_dir)
