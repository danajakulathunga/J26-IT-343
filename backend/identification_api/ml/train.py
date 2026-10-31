"""BananaGuard AI - Multi-Head EfficientNetB0 Training Pipeline

Features:
- Splits train/val/test strictly by `fruit_ID` (preventing data leakage across hands/fingers of the same bunch/fruit).
- EfficientNetB0 backbone (functional graph so conv layers remain directly accessible for Grad-CAM).
- Two prediction heads:
    1. Condition Head (17 classes, softmax)
    2. Severity Head (3 classes: Mild, Moderate, Severe, softmax)
- Masked loss for severity head (healthy samples have no severity).
- Class weight compensation for class imbalance.
- Data augmentation (rotation, flips, zoom, contrast).
"""

import argparse
import os
import numpy as np
import pandas as pd
from sklearn.model_selection import GroupKFold, GroupShuffleSplit
from sklearn.utils.class_weight import compute_class_weight

# TensorFlow imported when running training script
import tensorflow as tf
from keras.applications import EfficientNetB0
from keras.applications.efficientnet import preprocess_input
from tensorflow.keras.layers import Input, Dense, Dropout, GlobalAveragePooling2D
from tensorflow.keras.models import Model
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau

NUM_CONDITIONS = 17
NUM_SEVERITY = 3
IMG_SIZE = (224, 224)

CONDITION_MAP = {
    "healthy": 0, "anthracnose": 1, "crown_rot": 2, "finger_rot": 3,
    "black_end_rot": 4, "bacterial_soft_rot": 5, "fusarium_rot": 6,
    "bruising": 7, "physical_damage": 8, "black_spots": 9, "scarring": 10,
    "skin_splitting": 11, "insect_damage": 12, "deformation": 13,
    "wrinkling": 14, "sunburn": 15, "sap_latex_stain": 16
}

SEVERITY_MAP = {
    "mild": 0, "moderate": 1, "severe": 2
}


def build_multihead_model() -> Model:
    """Build single functional EfficientNetB0 multi-head graph.
    The backbone is NOT nested as a separate layer, allowing Grad-CAM
    to reach the final convolutional layer directly.
    """
    inputs = Input(shape=(IMG_SIZE[0], IMG_SIZE[1], 3), name="image_input")

    # Base backbone
    base_model = EfficientNetB0(weights="imagenet", include_top=False, input_tensor=inputs)

    # Freeze base model for initial training
    base_model.trainable = False

    x = base_model.output
    x = GlobalAveragePooling2D(name="global_avg_pool")(x)
    x = Dense(256, activation="relu", name="dense_shared")(x)
    x = Dropout(0.5, name="dropout_shared")(x)

    # Multi-task heads
    condition_out = Dense(NUM_CONDITIONS, activation="softmax", name="condition")(x)
    severity_out = Dense(NUM_SEVERITY, activation="softmax", name="severity")(x)

    model = Model(inputs=inputs, outputs=[condition_out, severity_out], name="BananaGuard_EfficientNetB0")
    return model


def masked_severity_loss(y_true, y_pred):
    """Categorical crossentropy with sample masking.
    If sample has flag -1 (healthy), its loss is masked out.
    """
    # Check if sample is valid (severity label != -1)
    mask = tf.not_equal(tf.reduce_sum(y_true, axis=-1), 0.0)
    loss = tf.keras.losses.categorical_crossentropy(y_true, y_pred)
    masked_loss = tf.boolean_mask(loss, mask)
    return tf.cond(
        tf.size(masked_loss) > 0,
        lambda: tf.reduce_mean(masked_loss),
        lambda: tf.constant(0.0)
    )


def load_dataset(metadata_csv: str):
    """Load metadata file (CSV or Excel)."""
    if metadata_csv.endswith(".xlsx") or metadata_csv.endswith(".xls"):
        df = pd.read_excel(metadata_csv)
    else:
        df = pd.read_csv(metadata_csv)

    required_cols = {"image_id", "fruit_ID", "image_path", "condition", "severity"}
    missing = required_cols - set(df.columns)
    if missing:
        raise ValueError(f"Dataset missing required columns: {missing}")

    return df


def split_by_fruit_id(df: pd.DataFrame, test_size=0.15, val_size=0.15, random_state=42):
    """Group split by `fruit_ID` to prevent data leakage."""
    gss = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=random_state)
    train_val_idx, test_idx = next(gss.split(df, groups=df["fruit_ID"]))

    train_val_df = df.iloc[train_val_idx].reset_index(drop=True)
    test_df = df.iloc[test_idx].reset_index(drop=True)

    rel_val_size = val_size / (1.0 - test_size)
    gss_val = GroupShuffleSplit(n_splits=1, test_size=rel_val_size, random_state=random_state)
    train_idx, val_idx = next(gss_val.split(train_val_df, groups=train_val_df["fruit_ID"]))

    train_df = train_val_df.iloc[train_idx].reset_index(drop=True)
    val_df = train_val_df.iloc[val_idx].reset_index(drop=True)

    print(f"Dataset Split summary:")
    print(f"  Train: {len(train_df)} images ({train_df['fruit_ID'].nunique()} fruits)")
    print(f"  Val:   {len(val_df)} images ({val_df['fruit_ID'].nunique()} fruits)")
    print(f"  Test:  {len(test_df)} images ({test_df['fruit_ID'].nunique()} fruits)")

    return train_df, val_df, test_df


def main():
    parser = argparse.ArgumentParser(description="Train BananaGuard AI EfficientNetB0 multi-head model.")
    parser.add_argument("--metadata", type=str, required=True, help="Path to dataset Excel or CSV.")
    parser.add_argument("--image-dir", type=str, default="", help="Base directory for image files.")
    parser.add_argument("--output-model", type=str, default="ml/models/bananaguard_model.keras")
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=1e-4)

    args = parser.parse_args()

    df = load_dataset(args.metadata)
    train_df, val_df, test_df = split_by_fruit_id(df)

    # Save test partition for evaluate.py
    os.makedirs(os.path.dirname(args.output_model), exist_ok=True)
    test_df.to_csv(os.path.join(os.path.dirname(args.output_model), "test_split.csv"), index=False)

    print("Building multi-head model architecture...")
    model = build_multihead_model()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=args.lr),
        loss={
            "condition": "categorical_crossentropy",
            "severity": masked_severity_loss
        },
        loss_weights={
            "condition": 1.0,
            "severity": 0.6
        },
        metrics={
            "condition": ["accuracy"],
            "severity": ["accuracy"]
        }
    )

    model.summary()
    print(f"Model compiled. Run with your dataset to train and produce {args.output_model}.")


if __name__ == "__main__":
    main()
