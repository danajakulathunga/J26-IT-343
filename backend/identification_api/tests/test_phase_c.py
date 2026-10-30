import json
import os
import shutil
import tempfile
import pytest

from app.ml.trainer import (
    get_training_status,
    _get_task_paths,
    _cleanup_old_versions,
    check_promotion,
    ACTIVE_VARIETY_DIR,
    VARIETY_VERSIONS_DIR,
    ACTIVE_RIPENESS_DIR,
    RIPENESS_VERSIONS_DIR,
)
from app.ml.registry import list_versions, resolve_version
from app.ml.predictor import predict_all


def test_variety_paths_regression():
    # Variety active dir and versions dir must match legacy paths
    act_dir, ver_dir, act_model, act_classes, _ = _get_task_paths("variety")
    assert act_dir == ACTIVE_VARIETY_DIR
    assert ver_dir == VARIETY_VERSIONS_DIR
    assert act_model.endswith("variety_classifier.keras")
    assert act_classes.endswith("class_names.txt")

    # Default get_training_status must be variety
    st_default = get_training_status()
    st_variety = get_training_status(task="variety")
    assert st_default["task"] == "variety"
    assert st_default["status"] == st_variety["status"]
    assert st_default["active_version"] == st_variety["active_version"]


def test_ripeness_paths():
    act_dir, ver_dir, act_model, act_classes, _ = _get_task_paths("ripeness")
    assert act_dir == ACTIVE_RIPENESS_DIR
    assert ver_dir == RIPENESS_VERSIONS_DIR
    assert act_model.endswith("ripeness_classifier.keras")
    assert act_classes.endswith("class_names.txt")

    st_ripeness = get_training_status(task="ripeness")
    assert st_ripeness["task"] == "ripeness"


def test_ripeness_promotion_without_active_model(monkeypatch):
    # Ripeness rule: no active model -> promote if acc >= 0.70 (MIN_PROMOTE_ACCURACY_RIPENESS)
    monkeypatch.setenv("MIN_PROMOTE_ACCURACY_RIPENESS", "0.70")

    # If active ripeness model does not exist:
    cand_metrics_pass = {
        "task": "ripeness",
        "test_accuracy": 0.74,
        "macro_f1": 0.72,
        "ripeness_metrics": {"quadratic_weighted_cohen_kappa": 0.81},
    }
    cand_metrics_fail = {
        "task": "ripeness",
        "test_accuracy": 0.65,
        "macro_f1": 0.60,
        "ripeness_metrics": {"quadratic_weighted_cohen_kappa": 0.65},
    }

    # Use dummy folder
    with tempfile.TemporaryDirectory() as tmp_dir:
        prom_pass, msg_pass = check_promotion(tmp_dir, cand_metrics_pass, task="ripeness")
        assert prom_pass is True
        assert "0.74" in msg_pass

        prom_fail, msg_fail = check_promotion(tmp_dir, cand_metrics_fail, task="ripeness")
        assert prom_fail is False
        assert "0.65" in msg_fail


def test_cleanup_old_versions_never_deletes(tmp_path, monkeypatch):
    # Test that _cleanup_old_versions reports candidate files that WOULD be removed
    # but does NOT call os.remove
    dummy_versions = tmp_path / "model_versions"
    dummy_versions.mkdir()

    # Create 8 dummy version directories with model.keras
    for i in range(1, 9):
        v_dir = dummy_versions / f"v{i:04d}"
        v_dir.mkdir()
        k_file = v_dir / "model.keras"
        k_file.write_text("dummy_weights")

    monkeypatch.setattr("app.ml.trainer.VARIETY_VERSIONS_DIR", str(dummy_versions))

    # Run cleanup check
    would_remove = _cleanup_old_versions(active_version="v0008", task="variety")
    assert len(would_remove) > 0

    # Ensure none of the files were actually deleted
    for i in range(1, 9):
        k_path = dummy_versions / f"v{i:04d}" / "model.keras"
        assert k_path.exists(), f"File {k_path} was deleted when it should have been kept!"


def test_predict_all_returns_none_ripeness_without_error():
    # If ripeness model is not present, predict_all returns ripeness=None without throwing
    # Generate dummy 100x100 RGB image
    import cv2
    import numpy as np

    img = np.zeros((100, 100, 3), dtype=np.uint8)
    _, buf = cv2.imencode(".jpg", img)
    img_bytes = buf.tobytes()

    res = predict_all(img_bytes)
    assert "variety" in res
    assert "ripeness" in res
    # If active ripeness model is missing in repo, ripeness is None
    if not os.path.exists(os.path.join(ACTIVE_RIPENESS_DIR, "ripeness_classifier.keras")):
        assert res["ripeness"] is None
        assert any("Ripeness model not available" in n for n in res["notes"])


def test_import_version_fake_folder(tmp_path, monkeypatch):
    from app.ml.import_version import import_version, REQUIRED_FILES

    # Create dummy versions target folder
    dummy_target = tmp_path / "mock_versions"
    dummy_target.mkdir()
    mock_paths = (str(dummy_target), str(dummy_target), os.path.join(str(dummy_target), "active.keras"), "", "")
    monkeypatch.setattr("app.ml.import_version._get_task_paths", lambda t: mock_paths)
    monkeypatch.setattr("app.ml.trainer._get_task_paths", lambda t: mock_paths)

    fake_source = tmp_path / "fake_model_dir"
    fake_source.mkdir()

    # 1. Missing files -> raises FileNotFoundError
    with pytest.raises(FileNotFoundError) as exc_info:
        import_version("variety", str(fake_source))
    assert "missing from source directory" in str(exc_info.value)

    # 2. Add all 4 required files: model.keras, class_names.txt, model_config.json, metrics.json
    (fake_source / "model.keras").write_text("dummy_model_bytes")
    (fake_source / "class_names.txt").write_text("Ambul_Banana\nKolikuttu_Banana\n")
    (fake_source / "model_config.json").write_text(json.dumps({"architecture": "mobilenetv2", "image_size": [300, 300]}))
    (fake_source / "metrics.json").write_text(json.dumps({"test_accuracy": 0.85, "macro_f1": 0.82}))

    # Mock promotion check and promotion runner to avoid touching production model
    monkeypatch.setattr("app.ml.import_version.check_promotion", lambda t_dir, m, task: (False, "mock_test_reason"))

    res = import_version("variety", str(fake_source))
    assert res["status"] == "rejected"
    assert "v0001" in res["version_dir"] or "v" in res["version"]
    # Check that required files were copied
    for rf in REQUIRED_FILES:
        assert os.path.isfile(os.path.join(res["version_dir"], rf))
