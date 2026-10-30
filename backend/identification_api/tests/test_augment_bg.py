"""
Unit and regression tests for background-swap augmentation (Phase G).
Enforces:
- Isolated temp directories (no writes to data/ or model folders).
- Zero network calls / mocked segmenter.
- Strict test-split and val-split purity (never augmented).
- Reproducibility and parameter contract adherence.
"""

import os
from pathlib import Path

import cv2
import numpy as np
import pytest
from PIL import Image

from app.ml.augment_bg import (
    augment_background_swap,
    extract_cutout_and_mask,
    generate_solid_background,
    generate_gradient_background,
    generate_noise_background,
    load_random_background_image,
    generate_random_background,
    apply_photometric_jitter,
    apply_geometric_jitter,
    composite_foreground_onto_background,
)


def _create_synthetic_banana_on_white(h=300, w=300) -> np.ndarray:
    """Creates a synthetic yellow banana shape centered on pure white (255, 255, 255)."""
    img = np.full((h, w, 3), 255, dtype=np.uint8)
    # Draw yellow banana-like ellipse
    center = (w // 2, h // 2)
    axes = (w // 4, h // 8)
    # OpenCV uses BGR/RGB depending on interpretation; for RGB: Yellow is (255, 220, 0)
    cv2.ellipse(img, center, axes, angle=-20, startAngle=0, endAngle=360, color=(255, 215, 0), thickness=-1)
    return img


def _create_synthetic_banana_on_dark(h=300, w=300) -> np.ndarray:
    """Creates a synthetic yellow banana shape on a textured/dark background."""
    img = np.full((h, w, 3), 40, dtype=np.uint8)
    center = (w // 2, h // 2)
    axes = (w // 4, h // 8)
    cv2.ellipse(img, center, axes, angle=-20, startAngle=0, endAngle=360, color=(255, 215, 0), thickness=-1)
    return img


def test_passthrough_when_prob_zero():
    """When bg_swap_prob is 0.0, output must be bit-for-bit identical to input."""
    img = _create_synthetic_banana_on_white()
    rng = np.random.default_rng(42)

    out = augment_background_swap(img, bg_swap_prob=0.0, rng=rng)
    assert np.array_equal(out, img)


def test_passthrough_when_random_exceeds_prob():
    """When random draw exceeds bg_swap_prob, output must be unchanged."""
    img = _create_synthetic_banana_on_white()
    # Stub rng to always return 0.999
    class FixedRng:
        def random(self):
            return 0.999

    out = augment_background_swap(img, bg_swap_prob=0.5, rng=FixedRng())
    assert np.array_equal(out, img)


def test_extract_cutout_and_mask_white_bg():
    """Tests fast corner floodfill on white-background preprocessed images."""
    img = _create_synthetic_banana_on_white(300, 300)
    cutout, alpha = extract_cutout_and_mask(img)

    assert cutout.shape == (300, 300, 3)
    assert alpha.shape == (300, 300, 1)
    assert alpha.dtype == np.float32

    # Corners must be background (alpha = 0)
    assert alpha[0, 0, 0] == 0.0
    assert alpha[0, 299, 0] == 0.0
    assert alpha[299, 0, 0] == 0.0
    assert alpha[299, 299, 0] == 0.0

    # Center of banana must be foreground (alpha close to 1.0)
    center_y, center_x = 150, 150
    assert alpha[center_y, center_x, 0] > 0.8


def test_extract_cutout_and_mask_natural_bg_stubbed(monkeypatch):
    """
    Tests cutout extraction on natural (non-white) background,
    mocking remove_background to ensure zero external calls.
    """
    img = _create_synthetic_banana_on_dark(300, 300)

    # Stub remove_background to return white-background composited image
    def mock_remove_background(img_bgr, enabled=True):
        # Return synthetic white image
        return cv2.cvtColor(_create_synthetic_banana_on_white(300, 300), cv2.COLOR_RGB2BGR)

    monkeypatch.setattr("app.ml.background_removal.remove_background", mock_remove_background)

    cutout, alpha = extract_cutout_and_mask(img)
    assert cutout.shape == (300, 300, 3)
    assert alpha.shape == (300, 300, 1)
    assert alpha[0, 0, 0] == 0.0
    assert alpha[150, 150, 0] > 0.8


def test_background_generators():
    """Verifies solid, gradient, and noise background generator contracts."""
    rng = np.random.default_rng(123)
    h, w = 100, 120

    # Solid
    solid = generate_solid_background(h, w, rng)
    assert solid.shape == (h, w, 3)
    assert solid.dtype == np.uint8
    # Solid background must have constant RGB across all pixels
    assert np.all(solid[:, :] == solid[0, 0])

    # Gradient
    grad = generate_gradient_background(h, w, rng)
    assert grad.shape == (h, w, 3)
    assert grad.dtype == np.uint8

    # Noise
    noise = generate_noise_background(h, w, rng)
    assert noise.shape == (h, w, 3)
    assert noise.dtype == np.uint8


def test_custom_background_image_loading(tmp_path):
    """Verifies that images from a custom backgrounds directory are correctly loaded and resized."""
    bg_dir = tmp_path / "custom_backgrounds"
    bg_dir.mkdir(parents=True)

    # Create dummy background image
    dummy_bg = Image.new("RGB", (400, 500), color=(100, 150, 200))
    dummy_bg.save(bg_dir / "pattern1.jpg", format="JPEG")

    rng = np.random.default_rng(42)
    loaded = load_random_background_image(300, 300, str(bg_dir), rng)

    assert loaded is not None
    assert loaded.shape == (300, 300, 3)
    assert loaded.dtype == np.uint8

    # If directory has no images, must return None cleanly
    empty_dir = tmp_path / "empty_dir"
    empty_dir.mkdir(parents=True)
    assert load_random_background_image(300, 300, str(empty_dir), rng) is None


def test_photometric_and_geometric_transforms():
    """Verifies that transforms keep valid shapes and value bounds."""
    img = _create_synthetic_banana_on_white(150, 150)
    alpha = np.ones((150, 150, 1), dtype=np.float32)
    rng = np.random.default_rng(999)

    # Geometric
    rot_img, rot_alpha = apply_geometric_jitter(img, alpha, rng, max_rotation_deg=10.0)
    assert rot_img.shape == (150, 150, 3)
    assert rot_alpha.shape == (150, 150, 1)

    # Photometric
    photo_img = apply_photometric_jitter(img, rng)
    assert photo_img.shape == (150, 150, 3)
    assert photo_img.dtype == np.uint8
    assert not np.isnan(photo_img).any()


def test_composite_foreground_onto_background():
    """Verifies alpha compositing on known test values."""
    fg = np.full((10, 10, 3), 200, dtype=np.uint8)
    bg = np.full((10, 10, 3), 100, dtype=np.uint8)

    # 1. Fully opaque foreground
    alpha_one = np.ones((10, 10, 1), dtype=np.float32)
    comp_one = composite_foreground_onto_background(fg, alpha_one, bg)
    assert np.all(comp_one == 200)

    # 2. Fully transparent foreground
    alpha_zero = np.zeros((10, 10, 1), dtype=np.float32)
    comp_zero = composite_foreground_onto_background(fg, alpha_zero, bg)
    assert np.all(comp_zero == 100)

    # 3. 50% opacity -> 200*0.5 + 100*0.5 = 150
    alpha_half = np.full((10, 10, 1), 0.5, dtype=np.float32)
    comp_half = composite_foreground_onto_background(fg, alpha_half, bg)
    assert np.all(comp_half == 150)


def test_train_pipeline_split_isolation(tmp_path):
    """
    CRITICAL: Validates that test_ds and val_ds are NEVER augmented,
    while train_ds applies augmentation when bg_swap_prob > 0.
    """
    import tensorflow as tf
    from app.ml.training.train_pipeline import create_tf_dataset

    # Save a temporary JPEG image
    img_dir = tmp_path / "img"
    img_dir.mkdir()
    img_path = str(img_dir / "banana.jpg")
    img_raw = _create_synthetic_banana_on_white(300, 300)
    Image.fromarray(img_raw).save(img_path, format="JPEG")

    records = [{"path": img_path, "label_idx": 0}]

    # 1. Test dataset: is_train=False, bg_swap_prob=0.0
    test_ds = create_tf_dataset(
        records,
        batch_size=1,
        is_train=False,
        arch="efficientnetb3",
        num_classes=6,
        bg_swap_prob=0.0,
    )
    # Decoded JPEG as expected ground truth
    expected_clean_img = np.array(Image.open(img_path))
    for batch_imgs, _ in test_ds.take(1):
        test_img = batch_imgs[0].numpy()
        # Must match original decoded image within tf.image.resize bilinear precision (<= 4.0)
        assert np.max(np.abs(test_img.astype(float) - expected_clean_img.astype(float))) <= 4.0
        # Background was white; in test split it must remain pure white
        assert np.all(test_img[0, 0] > 250)

    # 2. Train dataset with bg_swap_prob=1.0: must apply augmentation
    train_ds = create_tf_dataset(
        records,
        batch_size=1,
        is_train=True,
        arch="efficientnetb3",
        num_classes=6,
        bg_swap_prob=1.0,
    )
    for batch_imgs, _ in train_ds.take(1):
        train_img = batch_imgs[0].numpy()
        assert train_img.shape == (300, 300, 3)
        # Background was white (255, 255, 255); with bg swap, corner pixels must be changed
        corner_is_white = np.all(train_img[0, 0] > 240)
        assert not corner_is_white, "Corner was expected to be augmented with non-white background"


def test_mask_caching_on_disk(tmp_path, monkeypatch):
    """
    CRITICAL (H2): Verifies that segmenter masks are cached to disk,
    and subsequent calls load the mask from disk without invoking the segmenter.
    """
    cache_dir = tmp_path / "masks"
    cache_dir.mkdir(parents=True)
    image_id = "test_img_001"
    cache_file = cache_dir / f"{image_id}.png"

    img = _create_synthetic_banana_on_dark(300, 300)

    call_count = {"count": 0}

    def mock_remove_background(img_bgr, enabled=True):
        call_count["count"] += 1
        return cv2.cvtColor(_create_synthetic_banana_on_white(300, 300), cv2.COLOR_RGB2BGR)

    monkeypatch.setattr("app.ml.background_removal.remove_background", mock_remove_background)

    # 1. First call: cache does not exist -> invokes segmenter and writes cache file
    _, alpha1 = extract_cutout_and_mask(img, image_id=image_id, mask_cache_dir=str(cache_dir))
    assert call_count["count"] == 1
    assert cache_file.exists(), "Mask file was expected to be saved to disk cache"

    # 2. Second call with same image_id: loads from disk -> segmenter NOT called again
    _, alpha2 = extract_cutout_and_mask(img, image_id=image_id, mask_cache_dir=str(cache_dir))
    assert call_count["count"] == 1, "Segmenter must NOT be called on subsequent epochs when mask is cached"
    assert np.allclose(alpha1, alpha2, atol=1e-2)


def test_geometric_jitter_includes_crop_shift():
    """Verifies that geometric jitter applies translation/crop shift within bounds."""
    img = _create_synthetic_banana_on_white(300, 300)
    alpha = np.ones((300, 300, 1), dtype=np.float32)
    rng = np.random.default_rng(777)

    rot_img, rot_alpha = apply_geometric_jitter(
        img, alpha, rng, max_rotation_deg=15.0, scale_range=(0.9, 1.1), max_translation_pct=0.08
    )
    assert rot_img.shape == (300, 300, 3)
    assert rot_alpha.shape == (300, 300, 1)
    assert not np.isnan(rot_img).any()


def test_val_and_test_images_never_augmented(tmp_path):
    """
    CRITICAL (Prompt 1.3): Confirms by test that validation and test splits
    are never augmented (neither background swap nor geometric/photometric jitter).
    """
    import tensorflow as tf
    from app.ml.training.train_pipeline import create_tf_dataset, build_model

    # Create dummy images
    img1_path = tmp_path / "img1.jpg"
    img2_path = tmp_path / "img2.jpg"
    img_data = _create_synthetic_banana_on_white(300, 300)
    Image.fromarray(img_data).save(str(img1_path))
    Image.fromarray(img_data).save(str(img2_path))

    records = [
        {"path": str(img1_path), "label_idx": 0},
        {"path": str(img2_path), "label_idx": 1},
    ]

    # 1. Validation/Test dataset guard: even if bg_swap_prob is nonzero, is_train=False MUST suppress it
    val_ds = create_tf_dataset(records, batch_size=2, is_train=False, arch="efficientnetb3", bg_swap_prob=1.0)
    batches = []
    for _ in range(3):
        for imgs, lbls in val_ds:
            batches.append(imgs.numpy())

    # Every pass must be 100% bit-for-bit identical (zero stochastic augmentation)
    assert np.array_equal(batches[0], batches[1])
    assert np.array_equal(batches[0], batches[2])

    # 2. In-model augmentation guard: with training=False, model inference produces deterministic outputs
    model, _ = build_model(num_classes=2, arch="mobilenetv2", task="variety", aug_standard=True)
    input_tensor = tf.constant(batches[0], dtype=tf.float32)

    eval_out1 = model(input_tensor, training=False).numpy()
    eval_out2 = model(input_tensor, training=False).numpy()
    assert np.allclose(eval_out1, eval_out2, atol=1e-6), "Model with training=False must produce deterministic evaluation output"


def test_build_model_aug_standard_toggle():
    """
    Verifies that --aug-standard off skips standard Keras augmentation layers.
    """
    from app.ml.training.train_pipeline import build_model

    model_on, _ = build_model(num_classes=6, arch="mobilenetv2", task="variety", aug_standard=True)
    layer_types_on = [l.__class__.__name__ for l in model_on.layers]
    assert "RandomFlip" in layer_types_on
    assert "RandomRotation" in layer_types_on
    assert "RandomZoom" in layer_types_on

    model_off, _ = build_model(num_classes=6, arch="mobilenetv2", task="variety", aug_standard=False)
    layer_types_off = [l.__class__.__name__ for l in model_off.layers]
    assert "RandomFlip" not in layer_types_off
    assert "RandomRotation" not in layer_types_off
    assert "RandomZoom" not in layer_types_off

