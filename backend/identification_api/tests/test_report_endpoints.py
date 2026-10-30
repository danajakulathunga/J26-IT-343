import json
import os
import pytest
from fastapi import HTTPException

from app.routers.dataset import verify_admin_key
from app.routers.models import (
    get_tuning_experiments,
    get_model_report,
    get_report_image,
    promote_model_version,
)
from app.routers.training import training_status

TEST_API_KEY = "test_admin_key_reports"


@pytest.fixture(autouse=True)
def setup_api_key(monkeypatch):
    monkeypatch.setenv("ADMIN_API_KEY", TEST_API_KEY)


@pytest.fixture
def mock_version(tmp_path, monkeypatch):
    """
    Creates a full mock model version directory inside an isolated versions folder,
    patching app.ml.registry and app.ml.trainer so resolve_version and list_versions find it.
    """
    import app.ml.registry as registry_mod
    import app.ml.trainer as trainer_mod

    versions_dir = tmp_path / "mock_versions"
    v_dir = versions_dir / "v9999"
    rep_dir = v_dir / "report"
    rep_dir.mkdir(parents=True, exist_ok=True)

    # 1. model.keras & class_names.txt
    (v_dir / "model.keras").write_bytes(b"mock_keras_weights")
    (v_dir / "class_names.txt").write_text("Ambul_Banana\nCavendish_Banana\nRed_Banana\n", encoding="utf-8")
    (v_dir / "status.txt").write_text("candidate\n", encoding="utf-8")

    # 2. config.json
    config_payload = {
        "run_name": "v9999",
        "task": "variety",
        "architecture": "efficientnetb3",
        "image_size": [300, 300],
        "preprocessing": "raw_0_255",
        "split_mode": "group",
        "aug_standard": "on",
        "lr_stage1": 0.001,
        "lr_stage2": 0.00001,
        "unfrozen_layers_count": 77,
        "batch_size": 32,
        "seed": 42,
        "label_smoothing": 0.0,
        "dropout": 0.2,
        "bg_swap_prob": 0.6,
        "augmentation_list": [
            "bg_swap_prob_0.6",
            "horizontal_flip",
            "rotation_0.15",
            "zoom_0.15",
            "brightness_0.15",
            "contrast_0.15"
        ],
        "tuning_pointers": {
            "winner_run": "T1",
            "table_csv": "data/diagnostics/tuning_table.csv",
            "table_md": "data/diagnostics/tuning_table.md",
            "criterion": "lowest validation loss (0.2153)"
        },
        "classes_used": ["Ambul_Banana", "Cavendish_Banana", "Red_Banana"]
    }
    (v_dir / "config.json").write_text(json.dumps(config_payload, indent=2), encoding="utf-8")

    # 3. metrics.json
    metrics_payload = {
        "task": "variety",
        "architecture": "efficientnetb3",
        "test_accuracy": 0.8500,
        "macro_f1": 0.8400,
        "generalisation_estimate_valid": True,
        "is_legacy_confounded": False,
        "n_groups_per_class": {
            "Ambul_Banana": 3,
            "Cavendish_Banana": 3,
            "Red_Banana": 3
        },
        "confusion_matrix": [
            [20, 2, 1],
            [1, 25, 0],
            [2, 1, 19]
        ],
        "class_names": ["Ambul_Banana", "Cavendish_Banana", "Red_Banana"],
        "classification_report": {
            "Ambul_Banana": {"precision": 0.87, "recall": 0.87, "f1-score": 0.87, "support": 23},
            "Cavendish_Banana": {"precision": 0.89, "recall": 0.96, "f1-score": 0.92, "support": 26},
            "Red_Banana": {"precision": 0.95, "recall": 0.86, "f1-score": 0.90, "support": 22},
            "macro avg": {"precision": 0.90, "recall": 0.90, "f1-score": 0.90, "support": 71}
        }
    }
    (v_dir / "metrics.json").write_text(json.dumps(metrics_payload, indent=2), encoding="utf-8")

    # 4. history.json
    history_payload = [
        {"global_epoch": 1, "stage": 1, "loss": 1.2, "val_loss": 0.9, "accuracy": 0.6, "val_accuracy": 0.7, "learning_rate": 0.001},
        {"global_epoch": 2, "stage": 1, "loss": 0.8, "val_loss": 0.6, "accuracy": 0.75, "val_accuracy": 0.8, "learning_rate": 0.001},
        {"global_epoch": 3, "stage": 2, "loss": 0.3, "val_loss": 0.4, "accuracy": 0.9, "val_accuracy": 0.85, "learning_rate": 0.00001}
    ]
    (v_dir / "history.json").write_text(json.dumps(history_payload, indent=2), encoding="utf-8")

    # 5. classification_report.json & bg_corner_logistic_regression.json & dummy images in report/
    (rep_dir / "classification_report.json").write_text(json.dumps(metrics_payload["classification_report"], indent=2), encoding="utf-8")
    bg_payload = {
        "test_accuracy": 0.1494,
        "random_chance": 0.1429,
        "factor_above_chance": 1.05
    }
    (rep_dir / "bg_corner_logistic_regression.json").write_text(json.dumps(bg_payload, indent=2), encoding="utf-8")
    (rep_dir / "summary.md").write_text("# Summary\nMock summary content.", encoding="utf-8")
    (rep_dir / "accuracy_curve.png").write_bytes(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDRmock_png")
    (rep_dir / "loss_curve.png").write_bytes(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDRmock_png")
    (rep_dir / "confusion_matrix.png").write_bytes(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDRmock_png")
    (rep_dir / "confusion_matrix_normalized.png").write_bytes(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDRmock_png")

    # Patch registry and trainer directories
    monkeypatch.setattr(registry_mod, "MODEL_VERSIONS_DIR", str(versions_dir))
    active_mock_dir = tmp_path / "mock_active"
    active_mock_dir.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(trainer_mod, "VARIETY_VERSIONS_DIR", str(versions_dir))
    monkeypatch.setattr(trainer_mod, "ACTIVE_VARIETY_DIR", str(active_mock_dir))
    monkeypatch.setattr(trainer_mod, "ACTIVE_VARIETY_MODEL_PATH", str(active_mock_dir / "variety_classifier.keras"))
    monkeypatch.setattr(trainer_mod, "ACTIVE_VARIETY_CLASSES_PATH", str(active_mock_dir / "class_names.txt"))
    monkeypatch.setattr(trainer_mod, "ACTIVE_VARIETY_CONFIG_PATH", str(active_mock_dir / "model_config.json"))

    # Also patch _get_task_paths in trainer
    orig_paths = trainer_mod._get_task_paths
    def mock_get_task_paths(task="variety"):
        if task == "variety":
            return (
                str(active_mock_dir),
                str(versions_dir),
                str(active_mock_dir / "variety_classifier.keras"),
                str(active_mock_dir / "class_names.txt"),
                str(active_mock_dir / "model_config.json"),
            )
        return orig_paths(task)
    monkeypatch.setattr(trainer_mod, "_get_task_paths", mock_get_task_paths)

    return {
        "version_id": "v9999",
        "version_dir": str(v_dir),
        "versions_dir": str(versions_dir),
        "active_dir": str(active_mock_dir),
    }


def test_tuning_endpoint_auth_and_data():
    # Calling verify_admin_key without key or with wrong key raises 401
    with pytest.raises(HTTPException) as exc1:
        verify_admin_key(x_api_key=None)
    assert exc1.value.status_code == 401

    with pytest.raises(HTTPException) as exc2:
        verify_admin_key(x_api_key="bad_key")
    assert exc2.value.status_code == 401

    # Call endpoint directly with valid admin auth
    data = get_tuning_experiments(task="variety", _=True)
    assert data["task"] == "variety"
    assert "source" in data
    assert "experiment_runs" in data
    assert len(data["experiment_runs"]) > 0

    first_run = data["experiment_runs"][0]
    assert "run_id" in first_run
    assert "what_changed" in first_run
    assert "best_val_acc" in first_run
    assert "best_val_loss" in first_run
    assert "is_winner" in first_run
    assert data["winner"] == "T1"


def test_model_report_endpoint(mock_version):
    v_id = mock_version["version_id"]

    # 1. Validation check (invalid regex)
    with pytest.raises(HTTPException) as exc_bad:
        get_model_report(version_id="invalid..id", task="variety", _=True)
    assert exc_bad.value.status_code == 400

    # 2. 404 on nonexistent version
    with pytest.raises(HTTPException) as exc_404:
        get_model_report(version_id="v0000", task="variety", _=True)
    assert exc_404.value.status_code == 404

    # 3. Valid response on mock version
    data = get_model_report(version_id=v_id, task="variety", _=True)

    assert data["version_id"] == v_id
    assert data["task"] == "variety"

    # Summary checks
    summary = data["summary"]
    assert summary["train_accuracy"] == 0.9
    assert summary["val_accuracy"] == 0.85
    assert summary["test_accuracy"] == 0.8500
    assert summary["macro_f1"] == 0.8400
    assert summary["macro_precision"] == 0.90

    # Classification report
    assert "Ambul_Banana" in data["classification_report"]
    assert data["classification_report"]["Ambul_Banana"]["precision"] == 0.87

    # Confusion matrix
    cm = data["confusion_matrix"]
    assert cm["class_names"] == ["Ambul_Banana", "Cavendish_Banana", "Red_Banana"]
    assert len(cm["counts"]) == 3
    assert len(cm["normalized"]) == 3
    # Check normalized row 0 sums close to 1.0
    assert round(sum(cm["normalized"][0]), 2) == 1.0

    # History
    assert len(data["history"]) == 3
    assert data["history"][0]["epoch"] == 1
    assert data["history"][0]["stage"] == 1
    assert data["history"][2]["stage"] == 2

    # Config
    cfg = data["config"]
    assert cfg["architecture"] == "efficientnetb3"
    assert cfg["image_size"] == [300, 300]
    assert cfg["stage_1_learning_rate"] == 0.001
    assert cfg["stage_2_learning_rate"] == 0.00001
    assert cfg["unfrozen_layers"] == 77
    assert cfg["batch_size"] == 32
    assert cfg["split_mode"] == "group"

    # Augmentation list
    assert "bg_swap_prob_0.6" in data["augmentation_list"]
    assert "horizontal_flip" in data["augmentation_list"]

    # Evaluation label (clean group split -> "held-out sessions")
    assert data["evaluation_label"] == "held-out sessions"

    # Verify that when is_legacy_confounded is True, it returns "same-session, not a generalisation estimate"
    import pathlib
    v_dir = pathlib.Path(mock_version["version_dir"])
    met = json.loads((v_dir / "metrics.json").read_text(encoding="utf-8"))
    met["is_legacy_confounded"] = True
    (v_dir / "metrics.json").write_text(json.dumps(met), encoding="utf-8")
    data_confounded = get_model_report(version_id=v_id, task="variety", _=True)
    assert data_confounded["evaluation_label"] == "same-session, not a generalisation estimate"

    # Background-only test result
    assert data["background_only_test"] is not None
    assert data["background_only_test"]["test_accuracy"] == 0.1494
    assert data["background_only_test"]["factor_above_chance"] == 1.05


def test_model_report_image_endpoint(mock_version):
    v_id = mock_version["version_id"]

    # 1. Whitelist rejection
    with pytest.raises(HTTPException) as exc_name:
        get_report_image(version_id=v_id, name="unauthorized.png", task="variety", _=True)
    assert exc_name.value.status_code == 400
    assert "not allowed" in exc_name.value.detail.lower()

    # 2. Path traversal rejection
    with pytest.raises(HTTPException) as exc_trav:
        get_report_image(version_id=v_id, name="../summary.md", task="variety", _=True)
    assert exc_trav.value.status_code == 400

    # 3. Missing file raises 404
    with pytest.raises(HTTPException) as exc_missing:
        # Request a whitelisted image for a nonexistent version
        get_report_image(version_id="v0000", name="accuracy_curve.png", task="variety", _=True)
    assert exc_missing.value.status_code == 404

    # 4. Valid whitelisted images return FileResponse
    for img_name in ["accuracy_curve.png", "loss_curve.png", "confusion_matrix.png", "confusion_matrix_normalized.png"]:
        resp = get_report_image(version_id=v_id, name=img_name, task="variety", _=True)
        assert resp.media_type == "image/png"
        assert os.path.exists(resp.path)


def test_promote_endpoint_explicit_call_only(mock_version):
    v_id = mock_version["version_id"]

    # 1. Nonexistent version raises 400 or 404
    with pytest.raises(HTTPException) as exc_404:
        promote_model_version(version_id="v0000", task="variety", _=True)
    assert exc_404.value.status_code in (400, 404)

    # 2. Promote valid mock version
    res = promote_model_version(version_id=v_id, task="variety", _=True)
    assert res["success"] is True
    assert res["promoted_version"] == v_id

    # Verify that files were copied to active_dir
    active_dir = mock_version["active_dir"]
    assert os.path.exists(os.path.join(active_dir, "variety_classifier.keras"))
    assert os.path.exists(os.path.join(active_dir, "class_names.txt"))


def test_training_status_phase_and_epoch(tmp_path, monkeypatch):
    # 1. Default status check
    st = training_status(task="variety", _=True)
    assert "phase" in st
    assert "epoch" in st
    assert "total" in st or "total_epochs" in st
    assert "version_id" in st or "new_version_id" in st
    assert "status" in st
    assert "active_version" in st

    # 2. Test progress reading from data/training_progress_variety.json
    prog_path = tmp_path / "data" / "training_progress_variety.json"
    prog_path.parent.mkdir(parents=True, exist_ok=True)
    prog_data = {
        "phase": "stage 1",
        "epoch": 3,
        "total_epochs": 15,
        "version_id": "v0010",
        "task": "variety"
    }
    prog_path.write_text(json.dumps(prog_data), encoding="utf-8")

    import app.ml.trainer as trainer_mod
    monkeypatch.setattr(trainer_mod, "BASE_DIR", str(tmp_path))
    monkeypatch.setitem(trainer_mod._current_runs["variety"], "status", "running")

    st_prog = training_status(task="variety", _=True)
    assert st_prog["phase"] == "stage 1"
    assert st_prog["epoch"] == 3
    assert st_prog["total"] == 15
    assert st_prog["version_id"] == "v0010"

    # 4. Test done phase when completed
    monkeypatch.setitem(trainer_mod._current_runs["variety"], "status", "idle")
    prog_data["phase"] = "done"
    prog_path.write_text(json.dumps(prog_data), encoding="utf-8")
    st_done = training_status(task="variety", _=True)
    assert st_done["phase"] == "done"
