import os
import tempfile
import json
import pytest
import numpy as np
import cv2
from PIL import Image

from app.ml.labels import (
    load_labels,
    save_labels,
    set_label,
    VALID_RIPENESS_STAGES,
    parse_exif_date,
)
from app.ml.dataset import (
    ingest,
    get_dataset_stats,
    VALID_RIPENESS_STAGES as DATASET_STAGES,
)
from app.ml.groups import (
    compute_dhash,
    hamming_distance,
    UnionFind,
)
from app.ml.training.leakage_audit import (
    get_hash_split,
)
from app.ml.ripeness_presort import (
    analyze_pixel_fractions,
)


def test_valid_ripeness_stages():
    expected = ["Green", "Turning", "Ripe", "Overripe"]
    assert list(VALID_RIPENESS_STAGES) == expected
    assert list(DATASET_STAGES) == expected


def test_exif_timestamp_parsing():
    valid_exif = "2026:08:22 16:45:17"
    parsed = parse_exif_date(valid_exif)
    assert parsed == "2026-08-22T16:45:17"

    assert parse_exif_date(None) is None
    assert parse_exif_date("invalid-date") is None


def test_labels_atomic_store(tmp_path):
    labels_file = str(tmp_path / "labels.json")
    lock_file = str(tmp_path / ".labels.lock")

    initial = {
        "abc1234567890def": {
            "variety": "Ambul_Banana",
            "ripeness": None,
            "group_id": "abc1234567890def",
            "capture_time": None,
            "label_source": "test",
            "updated_at": "2026-10-13T00:00:00",
        }
    }
    save_labels(initial, labels_file=labels_file, lock_file=lock_file)
    loaded = load_labels(labels_file=labels_file, lock_file=lock_file)
    assert "abc1234567890def" in loaded
    assert loaded["abc1234567890def"]["variety"] == "Ambul_Banana"

    # Update with set_label
    set_label(
        "abc1234567890def",
        ripeness="Green",
        label_source="manual",
        labels_file=labels_file,
        lock_file=lock_file,
    )
    loaded2 = load_labels(labels_file=labels_file, lock_file=lock_file)
    assert loaded2["abc1234567890def"]["ripeness"] == "Green"
    assert loaded2["abc1234567890def"]["label_source"] == "manual"


def test_dhash_and_hamming():
    # Create two identical test images and one different
    img1 = np.zeros((100, 100, 3), dtype=np.uint8)
    img2 = np.zeros((100, 100, 3), dtype=np.uint8)
    img3 = np.full((100, 100, 3), 255, dtype=np.uint8)

    with tempfile.TemporaryDirectory() as tmpdir:
        p1 = os.path.join(tmpdir, "img1.jpg")
        p2 = os.path.join(tmpdir, "img2.jpg")
        p3 = os.path.join(tmpdir, "img3.jpg")
        cv2.imwrite(p1, img1)
        cv2.imwrite(p2, img2)
        cv2.imwrite(p3, img3)

        h1 = compute_dhash(p1)
        h2 = compute_dhash(p2)
        h3 = compute_dhash(p3)

        assert h1 == h2
        assert hamming_distance(h1, h2) == 0


def test_union_find():
    elements = ["a", "b", "c", "d"]
    uf = UnionFind(elements)
    assert uf.find("a") != uf.find("b")
    uf.union("a", "b")
    assert uf.find("a") == uf.find("b")
    assert uf.find("a") != uf.find("c")
    uf.union("b", "c")
    assert uf.find("a") == uf.find("c")


def test_hash_split_deterministic():
    test_file_1 = "01dcb88ea67d9b10.jpg"
    split1 = get_hash_split(test_file_1)
    split2 = get_hash_split(test_file_1)
    assert split1 == split2
    assert split1 in {"train", "val", "test"}


def test_ripeness_color_analysis():
    # Green image on white canvas
    canvas = np.full((300, 300, 3), 255, dtype=np.uint8)
    # BGR for strong green: B=20, G=180, R=40
    canvas[50:250, 50:250] = [20, 180, 40]

    g_frac, y_frac, r_frac, b_frac, stage = analyze_pixel_fractions(canvas)
    assert g_frac > 0.5
    assert stage == "Green"

    # Yellow image on white canvas: BGR = 20, 220, 240
    canvas_yellow = np.full((300, 300, 3), 255, dtype=np.uint8)
    canvas_yellow[50:250, 50:250] = [20, 220, 240]
    g_frac_y, y_frac_y, r_frac_y, b_frac_y, stage_y = analyze_pixel_fractions(canvas_yellow)
    assert y_frac_y > 0.5
    assert stage_y in {"Ripe", "Turning"}


def test_dataset_ingest_stage_validation():
    # Invalid stage rejected
    result = ingest("Ambul_Banana", b"fakebytes", "banana.jpg", stage="Yellow")
    assert result["status"] == "rejected"
    assert "Invalid stage" in result["reason"]


def test_bunch_id_filename_parsing():
    from app.ml.labels import parse_filename_bunch_id
    assert parse_filename_bunch_id("bunch-01__photo.jpg") == "bunch-01"
    assert parse_filename_bunch_id("B123__test.jpeg") == "B123"
    assert parse_filename_bunch_id("nobunch.jpg") is None
    assert parse_filename_bunch_id("invalid bunch!__test.jpg") is None


def test_bunch_id_ingest_validation():
    # Invalid bunch_id rejected
    result = ingest("Ambul_Banana", b"fakebytes", "banana.jpg", bunch_id="invalid bunch!")
    assert result["status"] == "rejected"
    assert "Invalid bunch_id" in result["reason"]


def test_labels_import_validation(tmp_path):
    from app.ml.labels_import import import_labels_from_csv
    csv_file = str(tmp_path / "test_import.csv")
    with open(csv_file, "w", encoding="utf-8") as f:
        f.write("path_or_sha16,bunch_id,ripeness\n")
        f.write("nonexistent_sha,bunch-1,Ripe\n")

    res = import_labels_from_csv(csv_file, dry_run=True)
    assert res["valid_count"] == 0
    assert res["invalid_count"] == 1
