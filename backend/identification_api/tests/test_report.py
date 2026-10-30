"""
Tests for app.ml.report (Phase H4).
Verifies report generation, training curve plotting, confusion matrix visualization,
and summary markdown generation using isolated temp directories (tmp_path).
"""

import json
import os
from unittest.mock import MagicMock, patch

import numpy as np
import pytest

from app.ml.report import (
    DEFAULT_EVAL_SPLIT_LABEL,
    generate_report,
    load_history,
    plot_accuracy_curve,
    plot_confusion_matrix_heatmap,
    plot_loss_curve,
)


@pytest.fixture
def sample_history():
    return [
        {
            "global_epoch": 1,
            "stage": 1,
            "loss": 1.25,
            "val_loss": 0.95,
            "accuracy": 0.65,
            "val_accuracy": 0.70,
            "learning_rate": 0.001,
        },
        {
            "global_epoch": 2,
            "stage": 1,
            "loss": 0.85,
            "val_loss": 0.75,
            "accuracy": 0.78,
            "val_accuracy": 0.82,
            "learning_rate": 0.001,
        },
        {
            "global_epoch": 3,
            "stage": 2,
            "loss": 0.45,
            "val_loss": 0.50,
            "accuracy": 0.88,
            "val_accuracy": 0.89,
            "learning_rate": 0.00001,
        },
        {
            "global_epoch": 4,
            "stage": 2,
            "loss": 0.25,
            "val_loss": 0.35,
            "accuracy": 0.94,
            "val_accuracy": 0.93,
            "learning_rate": 0.00001,
        },
    ]


@pytest.fixture
def sample_config():
    return {
        "run_name": "test_variety_run",
        "task": "variety",
        "architecture": "efficientnetb3",
        "preprocessing": "raw_0_255",
        "split_mode": "group",
        "lr_stage1": 0.001,
        "lr_stage2": 1e-05,
        "reduce_lr_factor": 0.5,
        "reduce_lr_min_lr": 1e-06,
        "reduce_lr_patience": 2,
        "early_stopping_patience": 5,
        "unfreeze_fraction": 0.2,
        "unfrozen_layers_count": 76,
        "total_base_layers": 384,
        "batch_size": 32,
        "seed": 42,
        "label_smoothing": 0.0,
        "dropout": 0.2,
        "bg_swap_prob": 0.6,
        "classes_used": ["Ambul_Banana", "Kolikuttu_Banana", "Red_Banana"],
    }


def test_plot_curves(tmp_path, sample_history):
    acc_path = tmp_path / "acc.png"
    loss_path = tmp_path / "loss.png"

    plot_accuracy_curve(sample_history, str(acc_path), stage2_start=3)
    plot_loss_curve(sample_history, str(loss_path), stage2_start=3)

    assert acc_path.is_file()
    assert acc_path.stat().st_size > 1000
    assert loss_path.is_file()
    assert loss_path.stat().st_size > 1000


def test_plot_confusion_matrices(tmp_path):
    cm = np.array([[10, 2], [1, 15]])
    class_names = ["ClassA", "ClassB"]

    cm_raw = tmp_path / "cm.png"
    cm_norm = tmp_path / "cm_norm.png"

    plot_confusion_matrix_heatmap(cm, class_names, str(cm_raw), normalize=False)
    plot_confusion_matrix_heatmap(cm, class_names, str(cm_norm), normalize=True)

    assert cm_raw.is_file()
    assert cm_raw.stat().st_size > 1000
    assert cm_norm.is_file()
    assert cm_norm.stat().st_size > 1000


def test_load_history(tmp_path, sample_history):
    # Test JSON history loading
    hist_json = tmp_path / "history.json"
    with open(hist_json, "w", encoding="utf-8") as f:
        json.dump(sample_history, f)

    loaded = load_history(str(tmp_path))
    assert loaded is not None
    assert len(loaded) == 4
    assert loaded[0]["global_epoch"] == 1


def test_generate_report_end_to_end(tmp_path, sample_history, sample_config):
    # Setup mock run dir
    run_dir = tmp_path / "mock_run"
    run_dir.mkdir()

    with open(run_dir / "history.json", "w", encoding="utf-8") as f:
        json.dump(sample_history, f)

    with open(run_dir / "config.json", "w", encoding="utf-8") as f:
        json.dump(sample_config, f)

    with open(run_dir / "class_names.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(sample_config["classes_used"]))

    # Synthetic confusion matrix (3 classes: 10 of each, mostly correct)
    mock_cm = [
        [9, 1, 0],
        [0, 10, 0],
        [1, 0, 9],
    ]
    with open(run_dir / "metrics.json", "w", encoding="utf-8") as f:
        json.dump({"confusion_matrix": mock_cm}, f)

    # Generate report
    result = generate_report(run_dir=str(run_dir))

    report_dir = run_dir / "report"
    assert report_dir.is_dir()

    # Verify all required files
    assert (report_dir / "accuracy_curve.png").is_file()
    assert (report_dir / "loss_curve.png").is_file()
    assert (report_dir / "classification_report.txt").is_file()
    assert (report_dir / "classification_report.json").is_file()
    assert (report_dir / "confusion_matrix.png").is_file()
    assert (report_dir / "confusion_matrix_normalized.png").is_file()
    assert (report_dir / "summary.md").is_file()

    # Verify summary contents and label
    summary_text = (report_dir / "summary.md").read_text(encoding="utf-8")
    assert "same-session, not a generalisation estimate" in summary_text
    assert "test_variety_run" in summary_text
    assert "Ambul_Banana" in summary_text
    assert "Kolikuttu_Banana" in summary_text

    # Verify classification report JSON
    with open(report_dir / "classification_report.json", "r", encoding="utf-8") as f:
        cr_data = json.load(f)
    assert "accuracy" in cr_data
    assert "macro avg" in cr_data
    assert cr_data["accuracy"] == pytest.approx(28 / 30, rel=1e-3)
