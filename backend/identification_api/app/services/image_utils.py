import io
import logging
import os
from typing import List, Optional
from PIL import Image, ImageOps
import cv2
import numpy as np
from app.schemas.scan import QualityWarning

logger = logging.getLogger(__name__)

ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}



def is_likely_banana(image_rgb: Image.Image) -> bool:
    """Return True if the image likely contains a banana fruit based on color analysis.

    Banana fruit colour ranges in OpenCV HSV (H: 0-179, S: 0-255, V: 0-255):
      - Ripe banana yellow      : H 15-35,  S 60-255, V 60-255
      - Unripe banana green     : H 36-85,  S 40-255, V 30-255
      - Overripe / brown-yellow : H 5-35,   S 35-255, V 25-150

    Bright/white background surfaces (e.g. paper/table with V > 185 and S < 35) are excluded.
    If at least BANANA_PIXEL_FRACTION of pixels match any range, returns True.
    """
    BANANA_PIXEL_FRACTION = 0.10  # 10% threshold

    # Resize to speed up the scan (max 256 px on longest side)
    img_small = image_rgb.copy()
    img_small.thumbnail((256, 256))
    cv_img = cv2.cvtColor(np.array(img_small), cv2.COLOR_RGB2BGR)
    hsv = cv2.cvtColor(cv_img, cv2.COLOR_BGR2HSV)

    total_pixels = hsv.shape[0] * hsv.shape[1]

    # Ripe banana – yellow
    mask_yellow = cv2.inRange(
        hsv,
        np.array([15, 60, 60]),
        np.array([35, 255, 255]),
    )
    # Unripe banana – green
    mask_green = cv2.inRange(
        hsv,
        np.array([36, 40, 30]),
        np.array([85, 255, 255]),
    )
    # Overripe / brown tissue
    mask_brown = cv2.inRange(
        hsv,
        np.array([5, 35, 25]),
        np.array([28, 255, 150]),
    )

    mask_all = cv2.bitwise_or(
        cv2.bitwise_or(mask_yellow, mask_green),
        mask_brown,
    )

    # Exclude bright white/pale background (paper, table)
    mask_bright_bg = cv2.inRange(
        hsv,
        np.array([0, 0, 185]),
        np.array([180, 35, 255]),
    )
    mask_banana = cv2.bitwise_and(mask_all, cv2.bitwise_not(mask_bright_bg))

    banana_pixels = cv2.countNonZero(mask_banana)
    fraction = banana_pixels / max(total_pixels, 1)
    return fraction >= BANANA_PIXEL_FRACTION


def validate_and_load_image(file_bytes: bytes, max_mb: int = 10) -> Image.Image:
    """Validate file size, format, verify integrity, fix EXIF orientation, convert to RGB."""
    size_mb = len(file_bytes) / (1024 * 1024)
    if size_mb > max_mb:
        raise ValueError(f"Image file size ({size_mb:.1f} MB) exceeds maximum allowed limit of {max_mb} MB")

    try:
        image = Image.open(io.BytesIO(file_bytes))
        image.verify()
    except Exception as e:
        raise ValueError(f"Invalid or corrupted image file: {str(e)}")

    # Re-open after verify() closes the stream
    image = Image.open(io.BytesIO(file_bytes))

    format_lower = (image.format or "").lower()
    if format_lower not in ALLOWED_EXTENSIONS and format_lower != "jpeg":
        raise ValueError(f"Unsupported image format: '{format_lower}'. Only JPEG, PNG, and WebP are supported.")

    # Fix EXIF orientation (common on mobile phone camera shots)
    try:
        image = ImageOps.exif_transpose(image)
    except Exception:
        pass

    # Ensure standard RGB 8-bit
    if image.mode != "RGB":
        image = image.convert("RGB")

    return image


def run_quality_checks(image_rgb: Image.Image) -> List[QualityWarning]:
    """Check image for blur, extreme brightness/darkness, and low resolution.
    Returns advisory quality warnings (non-blocking).
    """
    warnings: List[QualityWarning] = []
    width, height = image_rgb.size

    # 1. Low resolution check
    if min(width, height) < 300:
        warnings.append(
            QualityWarning(
                code="low_resolution",
                en="Low image resolution. Higher resolution provides more accurate analysis.",
                si="ඡායාරූපයේ විභේදනය (Resolution) අඩුයි. පැහැදිලි විශාල ඡායාරූපයක් වඩාත් නිවැරදි ප්‍රතිඵල ලබාදේ."
            )
        )

    # Convert PIL Image to OpenCV BGR for cv2 analytics
    cv_img = cv2.cvtColor(np.array(image_rgb), cv2.COLOR_RGB2BGR)
    gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)

    # 2. Blur detection using Laplacian variance
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    if laplacian_var < 35.0:
        warnings.append(
            QualityWarning(
                code="blurry_image",
                en="Image appears blurry or out of focus. Hold the camera steady and refocus.",
                si="ඡායාරූපය නොපැහැදිලි හෝ අපැහැදිලි විය හැක. කැමරාව සෙලවීමෙන් තොරව තබා නැවත ඡායාරූපයක් ගන්න."
            )
        )

    # 3. Brightness evaluation
    mean_brightness = float(np.mean(gray))
    if mean_brightness < 45.0:
        warnings.append(
            QualityWarning(
                code="too_dark",
                en="Lighting is too dark. Capture under good natural sunlight or bright lighting.",
                si="ආලෝකය ඉතා අඩුයි. හොඳ ස්වභාවික හිරු එළිය හෝ දීප්තිමත් ආලෝකය ඇති ස්ථානයක ඡායාරූපය ගන්න."
            )
        )
    elif mean_brightness > 225.0:
        warnings.append(
            QualityWarning(
                code="too_bright",
                en="Image is overexposed or washed out by harsh glare.",
                si="අධික ආලෝකය හෝ හිරු එළියේ දැඩි පරාවර්තනයක් නිසා ඡායාරූපය මැකී ගොස් ඇත."
            )
        )

    return warnings

1
# ---------------------------------------------------------------------------
# Zero-Shot Banana Validation (OpenAI CLIP ViT-B/32)
# ---------------------------------------------------------------------------
_clip_model = None
_clip_processor = None
_clip_initialized = False

_CLIP_SNAPSHOT_PATH = os.path.expanduser(
    r"~/.cache/huggingface/hub/models--openai--clip-vit-base-patch32/snapshots/3d74acf9a28c67741b2f4f2ea7635f0aaf6f0268"
)

_BANANA_PROMPTS = [
    "a photo of a banana fruit",
    "a photo of yellow ripe bananas or green bananas",
    "a photo of a rotted diseased black banana",
    "a photo of a bunch of bananas on a tree or stalk",
]

_NON_BANANA_PROMPTS = [
    "a photo of an eggplant, brinjal, or aubergine vegetable with a green leafy calyx stem",
    "a photo of a mango fruit or slice",
    "a photo of a pineapple fruit with spiked skin or crown leaves",
    "a photo of a papaya, melon, or watermelon",
    "a photo of an apple, pear, orange, lemon, or citrus fruit",
    "a photo of avocado, guava, or other non-banana fruit",
    "a photo of vegetables, cucumber, zucchini, green chili, or tomato",
    "a photo of cooked food, curry, rice, or prepared meal",
    "a photo of a flower, daisy, or floral blossom",
    "a photo of a temple, stupa, pagoda or religious monument",
    "a photo of a building, house, or outdoor landscape",
    "a photo of a person or human face",
    "a photo of an animal, dog, or cat",
    "a photo of a car or vehicle",
    "a photo of a computer screen or mobile phone display",
    "a photo of furniture, room, or everyday household item",
]

_ALL_CLIP_PROMPTS = _BANANA_PROMPTS + _NON_BANANA_PROMPTS



def _get_clip():
    """Lazy-load OpenAI CLIP ViT-B/32 processor and model once and cache in memory."""
    global _clip_model, _clip_processor, _clip_initialized
    if _clip_initialized:
        return _clip_processor, _clip_model

    _clip_initialized = True
    try:
        from transformers import CLIPProcessor, CLIPModel
        import torch

        # Priority 1: Direct local cached snapshot (zero-network, offline)
        if os.path.isdir(_CLIP_SNAPSHOT_PATH):
            logger.info(f"[CLIP] Loading CLIP from local snapshot: {_CLIP_SNAPSHOT_PATH}")
            _clip_processor = CLIPProcessor.from_pretrained(_CLIP_SNAPSHOT_PATH)
            _clip_model = CLIPModel.from_pretrained(_CLIP_SNAPSHOT_PATH)
        else:
            logger.info("[CLIP] Loading CLIP from pretrained identifier...")
            _clip_processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
            _clip_model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")

        if _clip_model is not None:
            _clip_model.eval()
            logger.info("[CLIP] CLIP Zero-Shot Banana Classifier loaded successfully.")
    except Exception as exc:
        logger.warning(f"[CLIP] Could not load CLIP model: {exc}.")
        _clip_processor = None
        _clip_model = None

    return _clip_processor, _clip_model


def run_clip_banana_check(image_rgb: Image.Image) -> Optional[bool]:
    """Zero-shot banana classification using OpenAI CLIP.

    Returns:
        True: Confirmed banana fruit (fresh, green, spotted, rotted, etc.).
        False: Confirmed non-banana object or scene (flower, temple, building, etc.).
        None: Borderline / uncertain or CLIP unavailable (triggers fallback).
    """
    processor, model = _get_clip()
    if processor is None or model is None:
        return None

    try:
        import torch

        inputs = processor(
            text=_ALL_CLIP_PROMPTS,
            images=image_rgb,
            return_tensors="pt",
            padding=True,
        )
        with torch.no_grad():
            outputs = model(**inputs)
            probs = outputs.logits_per_image.softmax(dim=1).squeeze()

        num_banana = len(_BANANA_PROMPTS)
        total_banana_prob = float(probs[:num_banana].sum())
        total_non_banana_prob = float(probs[num_banana:].sum())
        top_idx = int(torch.argmax(probs))
        top_label = _ALL_CLIP_PROMPTS[top_idx]
        top_prob = float(probs[top_idx])

        is_top_banana = top_idx < num_banana

        logger.info(
            f"[CLIP] Zero-Shot: banana_prob={total_banana_prob:.3f}, "
            f"non_banana_prob={total_non_banana_prob:.3f}, top='{top_label}' ({top_prob:.3f})"
        )

        # Clear banana match: Top match is banana and banana prob >= 50%
        if is_top_banana and total_banana_prob >= 0.50:
            return True

        # Clear non-banana match: Top match is non-banana and non-banana prob >= 50%
        if (not is_top_banana) and total_non_banana_prob >= 0.50:
            return False

        # Strong dominance conditions
        if total_banana_prob >= 0.70:
            return True
        if total_non_banana_prob >= 0.60:
            return False


        return None
    except Exception as exc:
        logger.warning(f"[CLIP] Zero-shot inference error: {exc}")
        return None


# ---------------------------------------------------------------------------
# Banana subject-matter validation (OpenAI CLIP ViT-B/32 Zero-Shot)
# ---------------------------------------------------------------------------

def run_banana_check(image_rgb: Image.Image) -> bool:
    """Return True if the image is likely a banana fruit in any condition
    (ripe yellow, unripe green, overripe, spotted, diseased, severely rotted, or blackened).

    Validation is powered by OpenAI CLIP (ViT-B/32) Zero-Shot Classifier.
    """
    clip_result = run_clip_banana_check(image_rgb)
    if clip_result is not None:
        if clip_result is True:
            logger.info("[BananaCheck] Verified as BANANA via OpenAI CLIP Zero-Shot.")
            return True
        else:
            logger.info("[BananaCheck] Rejected as NON-BANANA via OpenAI CLIP Zero-Shot.")
            return False

    # Heuristic fallback if CLIP is uncertain
    return is_likely_banana(image_rgb)


