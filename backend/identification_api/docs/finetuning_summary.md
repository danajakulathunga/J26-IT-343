# Fine-Tuning Summary: Model Version v0008

This document summarizes the two-stage training and fine-tuning results for model version `v0008` (`variety_b3_bg_swap`), compiled directly from `app/ml/model_versions/v0008/config.json` and `app/ml/model_versions/v0008/history.json`.

---

## 1. Stage 1 (Frozen Backbone Base)

| Parameter / Metric | Value | Reference / Notes |
| :--- | :--- | :--- |
| **Base Model Status** | **Frozen** (`base_model.trainable = False`) | Top classification head trained only |
| **Initial Learning Rate** | `0.001` (`1e-3`) | Reduced by ReduceLROnPlateau to `0.0005` (Epoch 10) and `0.00025` (Epoch 12) |
| **Epochs Run** | **12 epochs** | Global epochs 1 to 12 (configured limit: 20, stopped early on schedule) |
| **Best Validation Loss** | **0.1992** | Achieved at Global Epoch 7 (`loss = 0.1212`, `accuracy = 0.9335`) |
| **Best Validation Accuracy** | **0.9107** (91.07%) | Achieved at Global Epoch 7 |
| **Final Epoch (Epoch 12)** | Val Loss: `0.2335`, Val Acc: `0.8988` | Train Loss: `0.0821`, Train Acc: `0.9507` |

---

## 2. Stage 2 (Fine-Tuning Top Backbone Layers)

| Parameter / Metric | Value | Reference / Notes |
| :--- | :--- | :--- |
| **Unfrozen Fraction** | **0.20** (20% of base layers) | From `config.json` (`"unfreeze_fraction": 0.2`) |
| **Unfrozen Layers Count** | **76 layers** | Top 20% of 384 EfficientNetB3 base layers (`int(384 * 0.2) = 76`) |
| **Batch Normalization Status** | **FROZEN** (`trainable = False`) | Explicitly frozen in `train_pipeline.py` to prevent running mean/variance drift |
| **Initial Learning Rate** | `0.00001` (`1e-05`) | Reduced by ReduceLROnPlateau to `5e-06` (Epoch 16), `2.5e-06` (Epoch 19), `1.25e-06` (Epoch 21) |
| **Epochs Run** | **9 epochs** | Global epochs 13 to 21 (stopped by EarlyStopping at patience 5) |
| **Best Validation Loss** | **0.1617** | Achieved at Global Epoch 16 (`loss = 0.0633`, `accuracy = 0.9648`) |
| **Best Validation Accuracy** | **0.9286** (92.86%) | Achieved at Global Epochs 16, 17, and 18 |
| **Final Epoch (Epoch 21)** | Val Loss: `0.1866`, Val Acc: `0.9226` | Train Loss: `0.0521`, Train Acc: `0.9703` |

---

## 3. Comparison & Saved Weights

### Validation Loss & Accuracy Comparison

- **Stage 1 Best Validation Loss**: `0.1992` (Epoch 7)
- **Stage 2 Best Validation Loss**: **0.1617** (Epoch 16)
- **Difference**: **-0.0375** (Validation loss **improved** by 18.82% relative reduction)
- **Validation Accuracy**: Improved from `0.9107` (91.07%) in Stage 1 to **`0.9286` (92.86%)** in Stage 2 (+1.79% absolute gain).

### Saved Model Weights Selection

- **Saved Model Uses**: **Stage 2 Weights (from Global Epoch 16)**.
- **Mechanism**: The training pipeline uses `tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True)`.
- The minimum validation loss of the entire run (`0.1617`) occurred at **Epoch 16** (within Stage 2).
- After Epoch 16, validation loss did not improve for 5 consecutive epochs (Epochs 17: `0.1731`, 18: `0.1728`, 19: `0.1853`, 20: `0.1972`, 21: `0.1866`), triggering EarlyStopping.
- Upon stopping, `restore_best_weights=True` restored the model weights to the optimal checkpoint at **Epoch 16 of Stage 2**.
