"""
Background-swap and photometric/geometric augmentation module.
Provides realistic foreground extraction, mask caching in data/diagnostics/masks/,
compositing onto real background photos (tables, floors, hands, shelves, outdoors)
or synthetic fallbacks (solids, gradients, noise), and photometric/geometric jitter.

Safe-by-default: bg_swap_prob defaults to 0.0 (no changes applied unless enabled).
"""

import logging
import os
from pathlib import Path
from typing import Optional, Tuple

import cv2
import numpy as np

logger = logging.getLogger(__name__)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_BACKGROUNDS_DIR = os.path.join(BASE_DIR, "data", "backgrounds")
DEFAULT_MASK_CACHE_DIR = os.path.join(BASE_DIR, "data", "diagnostics", "masks")


_CACHE_STATS = {"hits": 0, "misses": 0}


def get_cache_stats() -> dict[str, int]:
    """Returns a copy of current mask cache hits and misses."""
    return dict(_CACHE_STATS)


def reset_cache_stats() -> None:
    """Resets cache hits and misses counters."""
    _CACHE_STATS["hits"] = 0
    _CACHE_STATS["misses"] = 0


def extract_cutout_and_mask(
    img_rgb: np.ndarray,
    image_id: Optional[str] = None,
    mask_cache_dir: Optional[str] = None,
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Extracts the fruit foreground and alpha mask (float32 in [0.0, 1.0], shape (H, W, 1)).
    Caches masks on disk in mask_cache_dir (data/diagnostics/masks/) so rembg only runs once per image.

    If cached mask exists on disk:
      Loads the cached mask directly (fast disk read, ~1 ms).
    If not cached:
      1. Checks if image corners are white (processed_bg convention): uses fast boundary flood-fill.
      2. If natural background: extracts mask using rembg via background_removal.
      3. Saves mask as uint8 PNG into mask_cache_dir for instant reuse in subsequent epochs.
    """
    h, w, c = img_rgb.shape
    assert c == 3, f"Expected 3 channels RGB, got shape {img_rgb.shape}"

    cache_dir = mask_cache_dir or DEFAULT_MASK_CACHE_DIR
    cache_path = None
    if image_id:
        cache_path = os.path.join(cache_dir, f"{image_id}.png")
        if os.path.isfile(cache_path):
            try:
                cached_mask = cv2.imread(cache_path, cv2.IMREAD_GRAYSCALE)
                if cached_mask is not None and cached_mask.shape == (h, w):
                    _CACHE_STATS["hits"] += 1
                    alpha = (cached_mask.astype(np.float32) / 255.0)[:, :, None]
                    return img_rgb.copy(), alpha
            except Exception as exc:
                logger.warning("Failed reading cached mask %s: %s", cache_path, exc)

        _CACHE_STATS["misses"] += 1

    # Check if image corners are white (preprocessed white-padding convention: RGB > 240)
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    corner_pixels = np.array([img_rgb[y, x] for (x, y) in corners])
    is_mostly_white_corners = np.mean(corner_pixels > 240) > 0.75

    if is_mostly_white_corners:
        # Fast flood fill from corners
        is_white = np.all(img_rgb > 245, axis=-1).astype(np.uint8)
        flood_mask = np.zeros((h + 2, w + 2), np.uint8)
        for (x, y) in corners:
            if is_white[y, x] == 1:
                cv2.floodFill(is_white.copy(), flood_mask, (x, y), 2)
        bg_connected = flood_mask[1:-1, 1:-1] == 1
        fg_mask = (~bg_connected).astype(np.float32)
        fg_smooth = cv2.GaussianBlur(fg_mask, (3, 3), 0.5)
        alpha = np.clip(fg_smooth, 0.0, 1.0)[:, :, None]
    else:
        # Natural background: delegate to rembg
        try:
            from app.ml.background_removal import remove_background
            bgr = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2BGR)
            rem_bgr = remove_background(bgr, enabled=True)
            rem_rgb = cv2.cvtColor(rem_bgr, cv2.COLOR_BGR2RGB)
            diff = 255.0 - np.min(rem_rgb, axis=-1)
            alpha = np.clip(diff / 15.0, 0.0, 1.0)[:, :, None]
        except Exception as exc:
            logger.warning("Cutout extraction fallback failed: %s. Using whole image.", exc)
            alpha = np.ones((h, w, 1), dtype=np.float32)

    # Save to disk cache if cache_path is configured
    if cache_path:
        try:
            os.makedirs(cache_dir, exist_ok=True)
            mask_uint8 = np.clip(alpha.squeeze() * 255.0, 0, 255).astype(np.uint8)
            cv2.imwrite(cache_path, mask_uint8)
        except Exception as exc:
            logger.warning("Failed saving mask cache to %s: %s", cache_path, exc)

    return img_rgb.copy(), alpha


def generate_solid_background(
    h: int,
    w: int,
    rng: np.random.Generator,
) -> np.ndarray:
    """Generates a solid RGB background with varied luminance."""
    color = rng.integers(25, 235, size=3, dtype=np.uint8)
    return np.full((h, w, 3), color, dtype=np.uint8)


def generate_gradient_background(
    h: int,
    w: int,
    rng: np.random.Generator,
) -> np.ndarray:
    """Generates a linear (horizontal, vertical, diagonal) or radial smooth 2-color gradient."""
    c1 = rng.uniform(20, 230, size=3).astype(np.float32)
    c2 = rng.uniform(20, 230, size=3).astype(np.float32)

    grad_type = rng.choice(["linear_h", "linear_v", "linear_diag", "radial"])

    if grad_type == "linear_h":
        t = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :, None]
        grad = c1 * (1.0 - t) + c2 * t
        return np.clip(np.tile(grad, (h, 1, 1)), 0, 255).astype(np.uint8)

    elif grad_type == "linear_v":
        t = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None, None]
        grad = c1 * (1.0 - t) + c2 * t
        return np.clip(np.tile(grad, (1, w, 1)), 0, 255).astype(np.uint8)

    elif grad_type == "linear_diag":
        x = np.linspace(0.0, 1.0, w, dtype=np.float32)
        y = np.linspace(0.0, 1.0, h, dtype=np.float32)
        xx, yy = np.meshgrid(x, y)
        t = np.clip((xx + yy) / 2.0, 0.0, 1.0)[:, :, None]
        grad = c1 * (1.0 - t) + c2 * t
        return np.clip(grad, 0, 255).astype(np.uint8)

    else:  # radial
        cx, cy = rng.uniform(0.3 * w, 0.7 * w), rng.uniform(0.3 * h, 0.7 * h)
        max_r = max(h, w) * rng.uniform(0.5, 0.9)
        y_coords, x_coords = np.ogrid[:h, :w]
        dist = np.sqrt((x_coords - cx) ** 2 + (y_coords - cy) ** 2) / max_r
        t = np.clip(dist, 0.0, 1.0)[:, :, None].astype(np.float32)
        grad = c1 * (1.0 - t) + c2 * t
        return np.clip(grad, 0, 255).astype(np.uint8)


def generate_noise_background(
    h: int,
    w: int,
    rng: np.random.Generator,
) -> np.ndarray:
    """Generates a natural multi-scale noise background texture."""
    low_res = rng.uniform(30, 225, size=(h // 8 + 1, w // 8 + 1, 3)).astype(np.float32)
    noise_smooth = cv2.resize(low_res, (w, h), interpolation=cv2.INTER_CUBIC)
    fine_noise = rng.normal(0, 10.0, size=(h, w, 3)).astype(np.float32)
    composite_noise = np.clip(noise_smooth + fine_noise, 0.0, 255.0).astype(np.uint8)
    return composite_noise


def load_random_background_image(
    h: int,
    w: int,
    backgrounds_dir: str,
    rng: np.random.Generator,
) -> Optional[np.ndarray]:
    """
    Attempts to randomly select an image from backgrounds_dir,
    and crops/resizes it to (h, w, 3) in RGB format.
    Returns None if backgrounds_dir is empty or has no images.
    """
    if not backgrounds_dir or not os.path.isdir(backgrounds_dir):
        return None

    valid_exts = {".jpg", ".jpeg", ".png", ".webp"}
    candidates = [
        os.path.join(backgrounds_dir, f)
        for f in os.listdir(backgrounds_dir)
        if os.path.splitext(f)[1].lower() in valid_exts
    ]

    if not candidates:
        return None

    chosen_file = rng.choice(candidates)
    try:
        bgr = cv2.imread(chosen_file)
        if bgr is None or bgr.size == 0:
            return None
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        img_h, img_w, _ = rgb.shape
        if img_h >= h and img_w >= w:
            top = rng.integers(0, img_h - h + 1)
            left = rng.integers(0, img_w - w + 1)
            cropped = rgb[top : top + h, left : left + w]
            return cropped
        return cv2.resize(rgb, (w, h), interpolation=cv2.INTER_LINEAR)
    except Exception as exc:
        logger.warning("Failed to load background image %s: %s", chosen_file, exc)
        return None


def generate_random_background(
    h: int,
    w: int,
    backgrounds_dir: Optional[str],
    rng: np.random.Generator,
) -> np.ndarray:
    """Chooses among real background images (tables, floors, etc.) or fallbacks."""
    b_dir = backgrounds_dir or DEFAULT_BACKGROUNDS_DIR
    if b_dir and os.path.isdir(b_dir):
        img_bg = load_random_background_image(h, w, b_dir, rng)
        if img_bg is not None and rng.random() < 0.7:
            return img_bg

    choice = rng.choice(["gradient", "solid", "noise"])
    if choice == "gradient":
        return generate_gradient_background(h, w, rng)
    elif choice == "noise":
        return generate_noise_background(h, w, rng)
    else:
        return generate_solid_background(h, w, rng)


def apply_geometric_jitter(
    fruit_rgb: np.ndarray,
    alpha_mask: np.ndarray,
    rng: np.random.Generator,
    max_rotation_deg: float = 15.0,
    scale_range: Tuple[float, float] = (0.9, 1.1),
    max_translation_pct: float = 0.08,
) -> Tuple[np.ndarray, np.ndarray]:
    """Applies random rotation, scaling, and translation/crop shift centered on canvas."""
    h, w, _ = fruit_rgb.shape
    angle = rng.uniform(-max_rotation_deg, max_rotation_deg)
    scale = rng.uniform(scale_range[0], scale_range[1])

    center = (w / 2.0, h / 2.0)
    matrix = cv2.getRotationMatrix2D(center, angle, scale)

    # Random translation / crop shift
    dx = rng.uniform(-max_translation_pct * w, max_translation_pct * w)
    dy = rng.uniform(-max_translation_pct * h, max_translation_pct * h)
    matrix[0, 2] += dx
    matrix[1, 2] += dy

    rot_fruit = cv2.warpAffine(
        fruit_rgb,
        matrix,
        (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(255, 255, 255),
    )
    rot_alpha = cv2.warpAffine(
        alpha_mask,
        matrix,
        (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0.0,
    )
    if rot_alpha.ndim == 2:
        rot_alpha = rot_alpha[:, :, None]

    return rot_fruit, rot_alpha


def apply_photometric_jitter(
    fruit_rgb: np.ndarray,
    rng: np.random.Generator,
    brightness_range: Tuple[float, float] = (0.85, 1.15),
    contrast_range: Tuple[float, float] = (0.85, 1.15),
    wb_range: Tuple[float, float] = (0.9, 1.1),
) -> np.ndarray:
    """Applies brightness, contrast, and white-balance (color temperature) shifts."""
    fruit_fl = fruit_rgb.astype(np.float32)

    # White-balance / channel scaling
    wb_gains = rng.uniform(wb_range[0], wb_range[1], size=(1, 1, 3)).astype(np.float32)
    fruit_fl = fruit_fl * wb_gains

    # Contrast adjustment around channel mean
    contrast = rng.uniform(contrast_range[0], contrast_range[1])
    channel_mean = np.mean(fruit_fl, axis=(0, 1), keepdims=True)
    fruit_fl = (fruit_fl - channel_mean) * contrast + channel_mean

    # Brightness adjustment
    brightness = rng.uniform(brightness_range[0], brightness_range[1])
    fruit_fl = fruit_fl * brightness

    return np.clip(fruit_fl, 0.0, 255.0).astype(np.uint8)


def composite_foreground_onto_background(
    fruit_rgb: np.ndarray,
    alpha_mask: np.ndarray,
    bg_rgb: np.ndarray,
) -> np.ndarray:
    """Alpha composites fruit onto background array."""
    fg = fruit_rgb.astype(np.float32)
    bg = bg_rgb.astype(np.float32)
    alpha = np.clip(alpha_mask.astype(np.float32), 0.0, 1.0)
    if alpha.ndim == 2:
        alpha = alpha[:, :, None]

    composited = fg * alpha + bg * (1.0 - alpha)
    return np.clip(composited, 0.0, 255.0).astype(np.uint8)


def augment_background_swap(
    img_rgb: np.ndarray,
    bg_swap_prob: float = 0.0,
    backgrounds_dir: Optional[str] = None,
    mask_cache_dir: Optional[str] = None,
    image_id: Optional[str] = None,
    rng: Optional[np.random.Generator] = None,
) -> np.ndarray:
    """
    Main entry point for background swap augmentation.
    If bg_swap_prob <= 0.0 or random draw >= bg_swap_prob, returns img_rgb untouched.
    Otherwise:
    1. Extracts cutout and alpha mask (using disk cache in data/diagnostics/masks/)
    2. Applies geometric jitter (rotation, scaling, crop shift)
    3. Applies photometric jitter (brightness, contrast, white balance)
    4. Generates background from data/backgrounds/ (or solid, gradient, noise fallbacks)
    5. Alpha composites fruit onto background
    """
    if bg_swap_prob <= 0.0:
        return img_rgb

    if rng is None:
        rng = np.random.default_rng()

    if rng.random() >= bg_swap_prob:
        return img_rgb

    h, w, c = img_rgb.shape
    b_dir = backgrounds_dir or DEFAULT_BACKGROUNDS_DIR

    # 1. Cutout & alpha (using disk mask cache)
    fruit_rgb, alpha_mask = extract_cutout_and_mask(
        img_rgb, image_id=image_id, mask_cache_dir=mask_cache_dir
    )

    # 2. Geometric jitter (rotation, scaling, crop shift)
    fruit_rgb, alpha_mask = apply_geometric_jitter(fruit_rgb, alpha_mask, rng)

    # 3. Photometric jitter
    fruit_rgb = apply_photometric_jitter(fruit_rgb, rng)

    # 4. Generate background
    bg_rgb = generate_random_background(h, w, b_dir, rng)

    # 5. Composite
    return composite_foreground_onto_background(fruit_rgb, alpha_mask, bg_rgb)
