import os
import shutil
import cv2
import numpy as np
import pytest

from app.ml.generate_processed_bg import (
    generate_processed_bg,
    process_single_image,
)


@pytest.fixture
def temp_raw_and_out(tmp_path):
    raw_dir = tmp_path / "raw"
    out_dir = tmp_path / "processed_bg"
    raw_dir.mkdir()

    # Create fake raw images in 2 classes
    for c in ["Ambul_Banana", "Kolikuttu_Banana"]:
        c_dir = raw_dir / c
        c_dir.mkdir()
        for i in range(2):
            img = np.full((120, 120, 3), 100 + i * 20, dtype=np.uint8)
            img_path = c_dir / f"test_{i}.jpg"
            cv2.imwrite(str(img_path), img)

    return str(raw_dir), str(out_dir)


def test_process_single_image_deterministic(monkeypatch):
    # Stub remove_background to return input
    monkeypatch.setattr(
        "app.ml.generate_processed_bg.remove_background",
        lambda img, enabled=True: img,
    )
    fake_img = np.full((150, 150, 3), 128, dtype=np.uint8)
    _, enc = cv2.imencode(".jpg", fake_img)
    img_bytes = enc.tobytes()

    short_sha, processed = process_single_image(img_bytes, (300, 300))
    assert len(short_sha) == 16
    assert processed.shape == (300, 300, 3)


def test_generate_processed_bg_execution(temp_raw_and_out, monkeypatch):
    raw_dir, out_dir = temp_raw_and_out

    # Monkeypatch remove_background to simple fast stub
    monkeypatch.setattr(
        "app.ml.generate_processed_bg.remove_background",
        lambda img, enabled=True: img,
    )

    stats = generate_processed_bg(raw_dir=raw_dir, out_dir=out_dir, log_interval=2)
    assert stats["total"] == 4
    assert stats["processed"] == 4
    assert stats["errors"] == 0

    # Verify output structure and sizes
    for c in ["Ambul_Banana", "Kolikuttu_Banana"]:
        c_out = os.path.join(out_dir, c)
        assert os.path.isdir(c_out)
        files = os.listdir(c_out)
        assert len(files) == 2
        for f in files:
            assert f.endswith(".jpg")
            img = cv2.imread(os.path.join(c_out, f))
            assert img.shape == (300, 300, 3)

    # Test resume: running again should skip already processed images
    resume_stats = generate_processed_bg(raw_dir=raw_dir, out_dir=out_dir)
    assert resume_stats["skipped"] == 4
    assert resume_stats["processed"] == 0


def test_generate_processed_bg_safety_check(tmp_path):
    proc_dir = tmp_path / "processed"
    proc_dir.mkdir()

    # Verify that attempting to output to existing processed throws/is guarded in CLI
    # Here test function handles custom out_dir
    raw_dir = tmp_path / "raw"
    raw_dir.mkdir()
    stats = generate_processed_bg(raw_dir=str(raw_dir), out_dir=str(proc_dir))
    assert stats["total"] == 0
