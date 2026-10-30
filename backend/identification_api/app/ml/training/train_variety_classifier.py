"""
Banana Variety Classification - MobileNetV2 Transfer Learning
-----------------------------------------------------------------
Sinhala note:
Meya obage 'Banana_processed' folder eke thiyena variety images
(Ambul, Ambun, Anamalu, Kolikuttu, Red, Seeni) MobileNetV2 pretrained
model ekak use karala train karanawa.

STAGE 1 (Transfer Learning): MobileNetV2 base eka freeze karala,
uda alutin layers witharak train karanawa - meka ikman, dataset
kuda una thawath hondin wada karanawa.

STAGE 2 (Fine-Tuning, optional): Stage 1 hodhin train una passe,
base model eke antima layers tika unfreeze karala, itamath podi
learning rate ekakin thawa tikak train karanawa - accuracy ekak
tawa tikak wadi karanna puluwan.

USAGE:
    1. pip install tensorflow pillow numpy matplotlib scikit-learn
    2. DATA_DIR variable eka obage 'Banana_processed' folder path
       ekata edit karanna.
    3. python train_variety_classifier.py
"""

import os
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt

# ---------------------------------------------------------
# 1. SETTINGS - meka witharak edit karanna one
# ---------------------------------------------------------
DATA_DIR = "Banana_processed"     # obage processed images thiyena folder eka
IMG_SIZE = (224, 224)             # MobileNetV2 ekata one size eka
BATCH_SIZE = 16                   # dataset kuda nisa podi batch size ekak
EPOCHS_STAGE1 = 20                # transfer learning stage eke epochs ganana
EPOCHS_STAGE2 = 10                # fine-tuning stage eke epochs ganana
LEARNING_RATE_STAGE1 = 1e-3       # stage 1 learning rate
LEARNING_RATE_STAGE2 = 1e-5       # stage 2 - metharam podi wenna one
                                   # (fine-tune karaddi loku LR ekak use
                                   # kalot, ImageNet eken igenagath
                                   # dana dinuma naati wenna puluwan)


# ---------------------------------------------------------
# 2. LOAD DATASET - train/validation split ekakata welakaranawa
# ---------------------------------------------------------
def load_datasets():
    train_ds = tf.keras.utils.image_dataset_from_directory(
        DATA_DIR,
        validation_split=0.2,
        subset="training",
        seed=42,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
    )

    val_ds = tf.keras.utils.image_dataset_from_directory(
        DATA_DIR,
        validation_split=0.2,
        subset="validation",
        seed=42,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
    )

    class_names = train_ds.class_names
    print(f"\nClasses found: {class_names}")

    train_ds = train_ds.map(lambda x, y: (preprocess_input(x), y))
    val_ds = val_ds.map(lambda x, y: (preprocess_input(x), y))

    train_ds = train_ds.prefetch(tf.data.AUTOTUNE)
    val_ds = val_ds.prefetch(tf.data.AUTOTUNE)

    return train_ds, val_ds, class_names


# ---------------------------------------------------------
# 3. DATA AUGMENTATION
# ---------------------------------------------------------
def build_augmentation():
    return models.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.15),
        layers.RandomZoom(0.15),
        layers.RandomBrightness(0.15),
        layers.RandomContrast(0.15),
    ], name="augmentation")


# ---------------------------------------------------------
# 4. BUILD MODEL
# ---------------------------------------------------------
def build_model(num_classes):
    base_model = MobileNetV2(
        input_shape=IMG_SIZE + (3,),
        include_top=False,
        weights="imagenet",
    )
    base_model.trainable = False

    inputs = tf.keras.Input(shape=IMG_SIZE + (3,))
    x = build_augmentation()(inputs)
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation="relu")(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = models.Model(inputs, outputs)
    return model, base_model


# ---------------------------------------------------------
# 5. PLOT TRAINING HISTORY
# ---------------------------------------------------------
def plot_history(history, title, filename):
    fig, axes = plt.subplots(1, 2, figsize=(12, 4))

    axes[0].plot(history.history["accuracy"], label="train")
    axes[0].plot(history.history["val_accuracy"], label="val")
    axes[0].set_title(f"{title} - Accuracy")
    axes[0].set_xlabel("Epoch")
    axes[0].legend()

    axes[1].plot(history.history["loss"], label="train")
    axes[1].plot(history.history["val_loss"], label="val")
    axes[1].set_title(f"{title} - Loss")
    axes[1].set_xlabel("Epoch")
    axes[1].legend()

    plt.tight_layout()
    plt.savefig(filename)
    print(f"Saved training curves to: {filename}")


# ---------------------------------------------------------
# 6. MAIN
# ---------------------------------------------------------
def main():
    if not os.path.isdir(DATA_DIR):
        print(f"ERROR: Data folder not found: {DATA_DIR}")
        print("DATA_DIR variable eka obage actual folder path ekata edit karanna.")
        return

    train_ds, val_ds, class_names = load_datasets()
    num_classes = len(class_names)

    model, base_model = build_model(num_classes)

    print("\n" + "=" * 60)
    print("STAGE 1: Transfer Learning (base model frozen)")
    print("=" * 60)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE_STAGE1),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_loss", patience=5, restore_best_weights=True
    )

    history_stage1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS_STAGE1,
        callbacks=[early_stop],
    )

    plot_history(history_stage1, "Stage 1", "stage1_training_curves.png")

    print("\n" + "=" * 60)
    print("STAGE 2: Fine-Tuning (unfreezing top layers of base model)")
    print("=" * 60)

    base_model.trainable = True

    fine_tune_at = len(base_model.layers) - 30
    for layer in base_model.layers[:fine_tune_at]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE_STAGE2),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    history_stage2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS_STAGE2,
        callbacks=[early_stop],
    )

    plot_history(history_stage2, "Stage 2 (Fine-Tune)", "stage2_training_curves.png")

    print("\n" + "=" * 60)
    print("EVALUATION")
    print("=" * 60)

    y_true = []
    y_pred = []
    for images, labels in val_ds:
        preds = model.predict(images, verbose=0)
        y_pred.extend(np.argmax(preds, axis=1))
        y_true.extend(labels.numpy())

    print("\nClassification Report:")
    print(classification_report(y_true, y_pred, target_names=class_names))

    print("\nConfusion Matrix:")
    print(confusion_matrix(y_true, y_pred))

    model.save("banana_variety_classifier.keras")
    print("\nModel saved to: banana_variety_classifier.keras")

    with open("class_names.txt", "w") as f:
        f.write("\n".join(class_names))
    print("Class names saved to: class_names.txt")


if __name__ == "__main__":
    main()
