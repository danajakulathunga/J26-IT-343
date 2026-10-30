import io
import os
import cv2
import numpy as np
from PIL import Image, ImageOps

try:
    import pillow_heif
    pillow_heif.register_heif_opener()
except ImportError:
    pass

TARGET_SIZE = (300, 300)


def load_image_from_bytes(image_bytes: bytes) -> np.ndarray:
    """
    Decodes image bytes using Pillow (supporting JPG, PNG, HEIC/HEIF),
    corrects EXIF orientation, and returns an OpenCV BGR array.
    """
    pil_img = Image.open(io.BytesIO(image_bytes))
    pil_img = ImageOps.exif_transpose(pil_img)
    pil_img = pil_img.convert("RGB")
    return cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)


def load_image_from_path(image_path: str) -> np.ndarray:
    """
    Loads an image file path (including HEIC), corrects EXIF orientation,
    and returns an OpenCV BGR array.
    """
    with open(image_path, "rb") as f:
        return load_image_from_bytes(f.read())


def resize_with_padding(image: np.ndarray, target_size: tuple[int, int] = TARGET_SIZE) -> np.ndarray:
    """
    Maintains aspect ratio and pads remaining space with white (255) up to target_size.
    """
    h, w = image.shape[:2]
    target_w, target_h = target_size

    scale = min(target_w / w, target_h / h)
    new_w, new_h = max(1, int(w * scale)), max(1, int(h * scale))
    resized = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_AREA)

    canvas = np.full((target_h, target_w, 3), 255, dtype=np.uint8)
    y_off = (target_h - new_h) // 2
    x_off = (target_w - new_w) // 2
    canvas[y_off:y_off + new_h, x_off:x_off + new_w] = resized
    return canvas


def normalize_color(image: np.ndarray) -> np.ndarray:
    """
    Converts to LAB, applies CLAHE (clipLimit=1.5, tileGridSize=(8, 8)) on the L channel,
    and converts back to BGR.
    """
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=1.5, tileGridSize=(8, 8))
    l = clahe.apply(l)
    lab = cv2.merge((l, a, b))
    return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)


def denoise_image(image: np.ndarray) -> np.ndarray:
    """
    Applies Non-Local Means Denoising to the BGR image.
    """
    return cv2.fastNlMeansDenoisingColored(image, None, 3, 3, 7, 21)


def process_bgr_image(image_bgr: np.ndarray, target_size: tuple[int, int] = TARGET_SIZE) -> np.ndarray:
    """
    Runs the complete standard preprocessing:
    1. resize_with_padding to target_size with white padding
    2. normalize_color (CLAHE on L channel)
    3. fastNlMeansDenoisingColored
    Returns processed BGR uint8 image.
    """
    padded = resize_with_padding(image_bgr, target_size)
    norm = normalize_color(padded)
    return denoise_image(norm)


def process_image_bytes(image_bytes: bytes, target_size: tuple[int, int] = TARGET_SIZE) -> np.ndarray:
    """
    Decodes bytes and runs the full preprocessing pipeline, returning processed BGR array.
    """
    bgr = load_image_from_bytes(image_bytes)
    return process_bgr_image(bgr, target_size)


def to_mobilenet_input(processed_bgr: np.ndarray) -> np.ndarray:
    """
    Converts a processed BGR image to RGB and applies MobileNetV2 preprocess_input ONCE.
    Returns float32 array batch of shape (1, 224, 224, 3).
    """
    import tensorflow as tf

    preprocess_input = tf.keras.applications.mobilenet_v2.preprocess_input
    rgb = cv2.cvtColor(processed_bgr, cv2.COLOR_BGR2RGB)
    batch = np.expand_dims(rgb, axis=0).astype(np.float32)
    return preprocess_input(batch)

