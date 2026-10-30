"""
Background removal utility using rembg.
Reversible and disabled by default via BACKGROUND_REMOVAL_ENABLED env flag.
Provides plain white background compositing with safe exception and empty-mask fallbacks.
"""

import logging
import os
import threading
from typing import Optional

import cv2
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# Flag read from environment (default: "false")
DEFAULT_BACKGROUND_REMOVAL_ENABLED = os.environ.get(
    "BACKGROUND_REMOVAL_ENABLED", "false"
).strip().lower() in ("true", "1", "yes")

_rembg_session = None
_session_lock = threading.Lock()


def is_background_removal_enabled(override: Optional[bool] = None) -> bool:
    """
    Returns whether background removal is active.
    If override is provided (e.g. from an API query parameter), it takes precedence.
    Otherwise, falls back to the current BACKGROUND_REMOVAL_ENABLED environment variable.
    """
    if override is not None:
        return bool(override)
    val = os.environ.get("BACKGROUND_REMOVAL_ENABLED", "false").strip().lower()
    return val in ("true", "1", "yes")


def _get_rembg_session():
    """Lazily initializes and caches a rembg session."""
    global _rembg_session
    if _rembg_session is None:
        with _session_lock:
            if _rembg_session is None:
                try:
                    import rembg
                    _rembg_session = rembg.new_session()
                except Exception as exc:
                    logger.warning("Failed to initialize rembg session: %s", exc)
                    return None
    return _rembg_session


def remove_background(
    img_bgr: np.ndarray,
    enabled: Optional[bool] = None,
) -> np.ndarray:
    """
    Removes background from an input BGR image, returning the segmented fruit
    composited onto a plain white background (RGB 255, 255, 255).

    Safety guarantees:
    - If enabled is False / flag is off: returns original img_bgr unchanged immediately.
    - If segmenter raises an error: logs warning, returns original img_bgr unchanged.
    - If segmenter returns an empty mask (<1% foreground): logs warning, returns original img_bgr unchanged.
    - Never raises an unhandled exception or crashes inference.
    """
    if not is_background_removal_enabled(enabled):
        return img_bgr

    if not isinstance(img_bgr, np.ndarray) or img_bgr.size == 0:
        return img_bgr

    try:
        import rembg
    except ImportError:
        logger.warning("rembg is not installed. Returning original image.")
        return img_bgr

    try:
        session = _get_rembg_session()

        # Convert input BGR to RGB PIL image for rembg
        rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        pil_in = Image.fromarray(rgb)

        # Run segmentation
        if session is not None:
            pil_out = rembg.remove(pil_in, session=session)
        else:
            pil_out = rembg.remove(pil_in)

        rgba = np.array(pil_out)
        if rgba.ndim != 3 or rgba.shape[2] != 4:
            logger.warning("rembg did not return RGBA array (shape=%s). Returning original.", rgba.shape)
            return img_bgr

        alpha = rgba[:, :, 3].astype(np.float32) / 255.0
        total_pixels = alpha.size

        # Check for empty mask: if virtually no foreground is detected
        fg_pixels = np.sum(alpha > 0.1)
        if total_pixels == 0 or (fg_pixels / total_pixels) < 0.005:
            logger.warning(
                "Background removal produced an empty or near-empty mask (fg_ratio=%.4f). Falling back to original image.",
                fg_pixels / max(total_pixels, 1),
            )
            return img_bgr

        # Alpha composite onto pure white background
        fg_rgb = rgba[:, :, :3].astype(np.float32)
        white_bg = np.ones_like(fg_rgb) * 255.0
        alpha_3d = np.expand_dims(alpha, axis=-1)

        composited_rgb = fg_rgb * alpha_3d + white_bg * (1.0 - alpha_3d)
        composited_rgb = np.clip(composited_rgb, 0.0, 255.0).astype(np.uint8)

        # Return as BGR
        return cv2.cvtColor(composited_rgb, cv2.COLOR_RGB2BGR)

    except Exception as exc:
        logger.warning("Background removal failed with exception: %s. Returning original image.", exc)
        return img_bgr
