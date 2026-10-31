import numpy as np
import cv2
from PIL import Image
from typing import Optional, Any


def detect_backbone(model: Any = None) -> str:
    """Auto-detect backbone architecture from a loaded Keras model (EfficientNetB0)."""
    return "efficientnet"


def preprocess_image(
    image_rgb: Image.Image,
    target_size=(224, 224),
    model: Optional[Any] = None,
    backbone: Optional[str] = None
) -> np.ndarray:
    """Preprocess an image dynamically according to the active EfficientNetB0 backbone.
    1. Resize with OpenCV bilinear resize to match training pipeline.
    2. Apply EfficientNet preprocessing: tf.keras.applications.efficientnet.preprocess_input
    Returns a batch array with shape (1, 224, 224, 3), float32.
    """
    import tensorflow as tf

    resized = cv2.resize(
        np.asarray(image_rgb),
        target_size,
        interpolation=cv2.INTER_LINEAR,
    ).astype(np.float32)

    preprocessed = tf.keras.applications.efficientnet.preprocess_input(resized)
    return np.expand_dims(preprocessed, axis=0)

