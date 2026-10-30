import json
import os
import tempfile
import numpy as np
import pytest
from sklearn.metrics import accuracy_score, cohen_kappa_score, confusion_matrix

from app.ml.training.train_pipeline import (
    partition_dataset,
    get_hash_split,
    check_cv_feasibility,
    compute_ripeness_metrics,
    confusion_matrix_to_y_true_y_pred,
    RIPENESS_CLASSES,
)


def test_group_split_assignment_deterministic():
    # Construct 10 groups of 5 images each for class "Ambul_Banana"
    records = []
    for g in range(10):
        gid = f"bunch_{g:02d}"
        for i in range(5):
            fname = f"{gid}__img_{i}.jpg"
            records.append({
                "sha16": f"sha_{g}_{i}",
                "filename": fname,
                "path": f"/dummy/{fname}",
                "variety": "Ambul_Banana",
                "label_name": "Ambul_Banana",
                "label_idx": 0,
                "bunch_id": gid,
                "group_id": gid,
            })

    tr1, va1, te1, meta1 = partition_dataset(records, split_mode="group")
    tr2, va2, te2, meta2 = partition_dataset(records, split_mode="group")

    assert [r["sha16"] for r in tr1] == [r["sha16"] for r in tr2]
    assert [r["sha16"] for r in va1] == [r["sha16"] for r in va2]
    assert [r["sha16"] for r in te1] == [r["sha16"] for r in te2]


def test_group_split_keeps_whole_groups_together():
    records = []
    for g in range(5):
        gid = f"bunch_{g:02d}"
        for i in range(10):
            fname = f"{gid}__img_{i}.jpg"
            records.append({
                "sha16": f"sha_{g}_{i}",
                "filename": fname,
                "path": f"/dummy/{fname}",
                "variety": "Kolikuttu_Banana",
                "label_name": "Kolikuttu_Banana",
                "label_idx": 0,
                "bunch_id": gid,
                "group_id": gid,
            })

    tr, va, te, meta = partition_dataset(records, split_mode="group")

    tr_groups = set(r["group_id"] for r in tr)
    va_groups = set(r["group_id"] for r in va)
    te_groups = set(r["group_id"] for r in te)

    # Whole groups stay together: zero intersection between splits
    assert len(tr_groups.intersection(va_groups)) == 0
    assert len(tr_groups.intersection(te_groups)) == 0
    assert len(va_groups.intersection(te_groups)) == 0

    # At least 1 test group and 1 val group when class has >= 3 groups
    assert len(te_groups) >= 1
    assert len(va_groups) >= 1
    assert len(tr_groups) >= 1


def test_holdout_file_forces_bunches_into_test(tmp_path):
    holdout_path = str(tmp_path / "holdout.json")
    with open(holdout_path, "w", encoding="utf-8") as f:
        json.dump({"test_bunches": ["bunch_special"]}, f)

    records = [
        {
            "sha16": "sha_normal_1",
            "filename": "normal__1.jpg",
            "path": "/dummy/normal__1.jpg",
            "variety": "Ambul_Banana",
            "label_name": "Ambul_Banana",
            "label_idx": 0,
            "bunch_id": "bunch_normal",
            "group_id": "bunch_normal",
        },
        {
            "sha16": "sha_special_1",
            "filename": "special__1.jpg",
            "path": "/dummy/special__1.jpg",
            "variety": "Ambul_Banana",
            "label_name": "Ambul_Banana",
            "label_idx": 0,
            "bunch_id": "bunch_special",
            "group_id": "bunch_special",
        },
    ]

    tr, va, te, meta = partition_dataset(records, split_mode="hash", holdout_file=holdout_path)

    # bunch_special must be in test split
    special_splits = [r["split"] for r in te if r["bunch_id"] == "bunch_special"]
    assert len(special_splits) == 1
    assert special_splits[0] == "test"
    # Never in train or val
    assert not any(r["bunch_id"] == "bunch_special" for r in tr)
    assert not any(r["bunch_id"] == "bunch_special" for r in va)


def test_legacy_confounded_fallback_with_fewer_than_3_groups():
    # Only 1 group: legacy_Ambul_Banana
    records = []
    for i in range(20):
        fname = f"img_{i:02d}.jpg"
        records.append({
            "sha16": f"sha_{i}",
            "filename": fname,
            "path": f"/dummy/{fname}",
            "variety": "Ambul_Banana",
            "label_name": "Ambul_Banana",
            "label_idx": 0,
            "bunch_id": None,
            "group_id": "legacy_Ambul_Banana",
        })

    tr, va, te, meta = partition_dataset(records, split_mode="group")

    assert meta["is_legacy_confounded"] is True
    assert "Ambul_Banana" in meta["legacy_confounded_classes"]

    # In fallback mode, each file is partitioned by hash split
    for r in records:
        expected_split = get_hash_split(r["filename"])
        assert r["split"] == expected_split


def test_ripeness_metrics_from_known_confusion_matrix():
    # Known 4x4 confusion matrix for 4 ripeness stages:
    # rows: true [0=Green, 1=Turning, 2=Ripe, 3=Overripe]
    # cols: pred [0=Green, 1=Turning, 2=Ripe, 3=Overripe]
    cm = np.array([
        [10,  2,  0,  0],  # 10 correct, 2 off-by-one (pred 1)
        [ 1,  8,  1,  0],  # 8 correct, 1 off-by-one (pred 0), 1 off-by-one (pred 2)
        [ 0,  2,  9,  1],  # 9 correct, 2 off-by-one (pred 1), 1 off-by-one (pred 3)
        [ 0,  0,  1,  5],  # 5 correct, 1 off-by-one (pred 2)
    ])
    total = np.sum(cm)  # 40
    correct = np.trace(cm)  # 10 + 8 + 9 + 5 = 32
    expected_acc = 32.0 / 40.0  # 0.80

    y_true, y_pred = confusion_matrix_to_y_true_y_pred(cm)
    assert len(y_true) == 40
    assert len(y_pred) == 40

    metrics = compute_ripeness_metrics(y_true, y_pred)

    # 1. Expected accuracy
    assert np.isclose(metrics["accuracy"], expected_acc, atol=1e-4)

    # 2. All errors in this matrix are off by at most 1 stage (diff <= 1)
    # So within_one_stage_accuracy must be exactly 1.0 (100%)
    assert np.isclose(metrics["within_one_stage_accuracy"], 1.0, atol=1e-4)

    # 3. Quadratic kappa must be high positive and close to ground-truth Cohen kappa
    expected_kappa = float(cohen_kappa_score(y_true, y_pred, weights="quadratic"))
    assert np.isclose(metrics["quadratic_weighted_cohen_kappa"], expected_kappa, atol=1e-4)
    assert 0.80 < metrics["quadratic_weighted_cohen_kappa"] < 1.0

    # 4. MASE: 8 off-by-one errors out of 40 = 8/40 = 0.2
    assert np.isclose(metrics["mean_absolute_stage_error"], 0.2, atol=1e-4)


def test_cv_skipped_when_not_enough_groups():
    # Class A has 2 groups, Class B has 1 group. Requested folds = 5.
    train_val_recs = []
    # Class A: 2 bunches
    for b in ["bunch_A1", "bunch_A2"]:
        for i in range(10):
            train_val_recs.append({
                "label_name": "Ambul_Banana",
                "group_id": b,
            })
    # Class B: 1 bunch
    for i in range(15):
        train_val_recs.append({
            "label_name": "Kolikuttu_Banana",
            "group_id": "legacy_Kolikuttu_Banana",
        })

    # Should report "CV skipped: not enough groups" because both classes have < 5 groups
    feasible, msg = check_cv_feasibility(train_val_recs, k_folds=5)
    assert feasible is False
    assert msg == "CV skipped: not enough groups"

    # Also test when each class has sufficient groups (e.g. 5 groups each for 5 folds)
    ample_recs = []
    for c in ["Ambul_Banana", "Kolikuttu_Banana"]:
        for g in range(5):
            for i in range(5):
                ample_recs.append({
                    "label_name": c,
                    "group_id": f"{c}_bunch_{g}",
                })
    feasible_ok, msg_ok = check_cv_feasibility(ample_recs, k_folds=5)
    assert feasible_ok is True
    assert msg_ok == "OK"

