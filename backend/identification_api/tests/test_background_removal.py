import io
import numpy as np
import pytest
from PIL import Image

from app.ml.background_removal import (
    is_background_removal_enabled,
    remove_background,
)
from app.ml.predictor import prepare_input_tensor
from app.routers.predict import analyze_fruit
from fastapi import UploadFile


def _create_sample_bgr(height=100, width=100) -> np.ndarray:
    """Creates a simple test image: blue square fruit with black background."""
    img = np.zeros((height, width, 3), dtype=np.uint8)
    # Put a colored box in the middle
    img[25:75, 25:75] = [20, 180, 50]  # Greenish in BGR
    return img


def test_background_removal_disabled_by_default(monkeypatch):
    monkeypatch.delenv("BACKGROUND_REMOVAL_ENABLED", raising=False)
    assert not is_background_removal_enabled()

    img = _create_sample_bgr()
    out = remove_background(img)
    # Output must be byte-identical and same reference/array
    assert np.array_equal(out, img)


def test_background_removal_override_parameter(monkeypatch):
    monkeypatch.setenv("BACKGROUND_REMOVAL_ENABLED", "false")
    img = _create_sample_bgr()

    # Explicit override False -> unchanged
    out_disabled = remove_background(img, enabled=False)
    assert np.array_equal(out_disabled, img)


def test_background_removal_enabled_composites_white_background(monkeypatch):
    """
    Stubs rembg.remove to simulate successful fruit segmentation,
    confirming compositing onto a plain white background without model downloads.
    """
    img_bgr = _create_sample_bgr(100, 100)

    # Fake rembg.remove that masks out the center square
    def fake_rembg_remove(pil_img, *args, **kwargs):
        arr = np.array(pil_img)
        h, w = arr.shape[:2]
        rgba = np.zeros((h, w, 4), dtype=np.uint8)
        # Foreground in the center
        rgba[25:75, 25:75, :3] = arr[25:75, 25:75]
        rgba[25:75, 25:75, 3] = 255  # alpha = 1.0
        # Background is alpha = 0
        return Image.fromarray(rgba)

    import rembg
    monkeypatch.setattr(rembg, "remove", fake_rembg_remove)

    out_bgr = remove_background(img_bgr, enabled=True)

    # Background corner (0, 0) should be pure white in BGR (255, 255, 255)
    assert out_bgr.shape == img_bgr.shape
    assert tuple(out_bgr[0, 0]) == (255, 255, 255)
    assert tuple(out_bgr[99, 99]) == (255, 255, 255)

    # Center fruit region should preserve the green color [20, 180, 50]
    assert tuple(out_bgr[50, 50]) == (20, 180, 50)


def test_background_removal_safe_fallback_on_segmenter_exception(monkeypatch):
    """If segmenter raises an error, returns the original image unchanged."""
    img_bgr = _create_sample_bgr()

    def fake_failing_remove(*args, **kwargs):
        raise RuntimeError("Simulated segmentation engine crash")

    import rembg
    monkeypatch.setattr(rembg, "remove", fake_failing_remove)

    out = remove_background(img_bgr, enabled=True)
    assert np.array_equal(out, img_bgr)


def test_background_removal_safe_fallback_on_empty_mask(monkeypatch):
    """If segmenter detects zero foreground (<0.5%), returns original image unchanged."""
    img_bgr = _create_sample_bgr(100, 100)

    # All-alpha=0 output (empty mask)
    def fake_empty_mask_remove(pil_img, *args, **kwargs):
        return Image.new("RGBA", pil_img.size, (0, 0, 0, 0))

    import rembg
    monkeypatch.setattr(rembg, "remove", fake_empty_mask_remove)

    out = remove_background(img_bgr, enabled=True)
    assert np.array_equal(out, img_bgr)


def test_prepare_input_tensor_already_processed_bypasses_bg_removal(monkeypatch):
    """
    Ensures already_processed=True branch NEVER invokes background removal,
    preserving zero-reprocessing on preprocessed dataset images.
    """
    called = []

    def tracking_remove_bg(*args, **kwargs):
        called.append(True)
        return args[0]

    import app.ml.predictor as pred_mod
    monkeypatch.setattr(pred_mod, "remove_background", tracking_remove_bg)
    monkeypatch.setenv("BACKGROUND_REMOVAL_ENABLED", "true")

    config = {"architecture": "mobilenetv2", "image_size": [224, 224]}
    fake_bgr = _create_sample_bgr(224, 224)

    # 1. already_processed=True -> remove_background MUST NOT be called
    prepare_input_tensor(fake_bgr, config, already_processed=True)
    assert len(called) == 0

    # 2. already_processed=False -> remove_background MUST be called
    prepare_input_tensor(fake_bgr, config, already_processed=False)
    assert len(called) == 1


@pytest.mark.anyio
async def test_analyze_query_param_remove_bg(monkeypatch):
    """Verifies that ?remove_bg=false / true query param is passed through to predict_all."""
    passed_args = {}

    def fake_predict_all(image_bytes, **kwargs):
        passed_args.update(kwargs)
        return {
            "variety": {"variety": "Ambul_Banana", "confidence": 0.99},
            "ripeness": None,
            "model_versions": {"variety": "v0007", "ripeness": None},
            "image_size": [224, 224],
            "notes": [],
        }

    import app.routers.predict as router_pred
    monkeypatch.setattr(router_pred, "predict_all", fake_predict_all)

    # Create dummy image file for upload
    img = Image.new("RGB", (64, 64), color=(100, 150, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    upload_file = UploadFile(filename="test.jpg", file=buf)
    res = await analyze_fruit(upload_file, remove_bg=True)
    assert res is not None
    assert passed_args.get("remove_bg") is True

    buf.seek(0)
    upload_file_2 = UploadFile(filename="test.jpg", file=buf)
    res2 = await analyze_fruit(upload_file_2, remove_bg=False)
    assert res2 is not None
    assert passed_args.get("remove_bg") is False
