"""
Tests for app.ml.training.evaluate_dataset (Phase H3).
"""

import json
import os
from unittest.mock import MagicMock, patch

import numpy as np
import pytest
from PIL import Image

from app.ml.training.evaluate_dataset import DEFAULT_EVAL_DIR, MVP_CLASSES, evaluate_dataset


def test_evaluate_dataset_empty_dir(tmp_path):
    empty_dir = tmp_path / "empty_eval"
    empty_dir.mkdir()
    for c in MVP_CLASSES:
        (empty_dir / c).mkdir()

    # Create a dummy model file
    dummy_model_file = tmp_path / "dummy.keras"
    dummy_model_file.write_text("dummy")

    res = evaluate_dataset(
        model_path=str(dummy_model_file),
        eval_dir=str(empty_dir),
    )
    assert res["status"] == "empty"
    assert res["total_images"] == 0
    assert res["accuracy"] is None


def test_evaluate_dataset_computes_metrics(tmp_path):
    eval_dir = tmp_path / "eval_set"
    eval_dir.mkdir()

    # Create 2 classes with 2 images each
    test_classes = ["Ambul_Banana", "Seeni_Banana"]
    for c in test_classes:
        c_dir = eval_dir / c
        c_dir.mkdir()
        for i in range(2):
            img_path = c_dir / f"img_{i}.jpg"
            img = Image.new("RGB", (100, 100), color=(100, 150, 200))
            img.save(str(img_path))

    dummy_model_file = tmp_path / "dummy.keras"
    dummy_model_file.write_text("dummy")

    # Mock tf.keras.models.load_model and prepare_input_tensor
    mock_model = MagicMock()
    # Mock predictions:
    # 2 Ambul images -> predict class 0 (Ambul) and class 1 (Seeni)
    # 2 Seeni images -> predict class 1 (Seeni) and class 1 (Seeni)
    mock_model.predict.side_effect = [
        np.array([[0.9, 0.1]]),  # Ambul -> Ambul (correct)
        np.array([[0.2, 0.8]]),  # Ambul -> Seeni (wrong)
        np.array([[0.1, 0.9]]),  # Seeni -> Seeni (correct)
        np.array([[0.3, 0.7]]),  # Seeni -> Seeni (correct)
    ]

    out_json = tmp_path / "report.json"

    with patch("tensorflow.keras.models.load_model", return_value=mock_model), \
         patch("app.ml.training.evaluate_dataset.prepare_input_tensor", return_value=np.zeros((1, 300, 300, 3), dtype=np.float32)) as mock_prep:

        res = evaluate_dataset(
            model_path=str(dummy_model_file),
            eval_dir=str(eval_dir),
            class_names=test_classes,
            out_json=str(out_json),
        )

        assert mock_prep.call_count == 4
        # Verify already_processed is explicitly False
        for call_args in mock_prep.call_args_list:
            assert call_args.kwargs.get("already_processed") is False

    assert res["status"] == "completed"
    assert res["total_images"] == 4
    # 3 out of 4 correct -> 0.75 accuracy
    assert res["overall_accuracy"] == 0.75
    assert "macro_f1" in res
    assert "confusion_matrix" in res
    assert os.path.isfile(str(out_json))

    # Verify most frequent predictions
    mfp = res["most_frequent_predictions"]
    assert "Ambul_Banana" in mfp
    assert "Seeni_Banana" in mfp
    assert mfp["Seeni_Banana"]["is_correct"] is True
    assert mfp["Seeni_Banana"]["most_frequent_prediction"] == "Seeni_Banana"
