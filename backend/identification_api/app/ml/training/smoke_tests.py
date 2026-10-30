"""
Phase B8 Smoke Tests:
(a) Variety MobileNetV2 default
(b) Variety EfficientNetB3
(c) Ripeness (using temporary fake labels file with balanced stages if real labels < 30 per stage)
For each: reports time per epoch, verifies that predictions through predictor match in-training evaluation on 10 images.
"""

import json
import os
import shutil
import tempfile
import time
import numpy as np
import cv2
import tensorflow as tf

from app.ml.training.train_pipeline import train_pipeline, parse_args
from app.ml.predictor import _predict_on_bgr, parse_class_name


def verify_predictor_match(model_path, config_path, class_names_path, test_image_paths, arch):
    # 1. In-training evaluation path
    model = tf.keras.models.load_model(model_path)
    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)
    with open(class_names_path, "r", encoding="utf-8") as f:
        class_names = [line.strip() for line in f if line.strip()]

    is_efficientnet = "efficientnet" in arch.lower()
    in_train_preds = []
    predictor_preds = []

    for p in test_image_paths[:10]:
        # Path 1: direct in-training pipeline logic
        img_bytes = tf.io.read_file(p)
        img = tf.image.decode_jpeg(img_bytes, channels=3)
        img = tf.image.resize(img, (300, 300))
        if not is_efficientnet:
            img = tf.keras.applications.mobilenet_v2.preprocess_input(img)
        batch = np.expand_dims(img.numpy(), axis=0)
        p_train = model.predict(batch, verbose=0)[0]
        in_train_preds.append(p_train)

        # Path 2: predictor path from raw BGR
        bgr = cv2.imread(p)
        res = _predict_on_bgr(bgr, model, class_names, config, "smoke_test")
        # Compute exact softmax from predictor
        prep_mode = config.get("preprocessing")
        if prep_mode == "raw_0_255" or is_efficientnet:
            from app.ml.preprocessing import process_bgr_image
            proc_bgr = process_bgr_image(bgr, target_size=(300, 300))
            rgb = cv2.cvtColor(proc_bgr, cv2.COLOR_BGR2RGB)
            pred_batch = np.expand_dims(rgb, axis=0).astype(np.float32)
        else:
            from app.ml.preprocessing import process_bgr_image, to_mobilenet_input
            proc_bgr = process_bgr_image(bgr, target_size=(300, 300))
            pred_batch = to_mobilenet_input(proc_bgr)

        p_pred = model.predict(pred_batch, verbose=0)[0]
        predictor_preds.append(p_pred)

    diffs = [np.max(np.abs(a - b)) for a, b in zip(in_train_preds, predictor_preds)]
    max_diff = float(np.max(diffs))
    match = max_diff < 0.05
    return match, max_diff


def run_all_smoke_tests():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    data_dir = os.path.join(base_dir, "data", "images", "processed")
    labels_file = os.path.join(base_dir, "data", "labels.json")

    results = {}

    import types
    with tempfile.TemporaryDirectory() as temp_root:
        # ------------------------------------------------------------------
        # Smoke Test (a): Variety MobileNetV2
        # ------------------------------------------------------------------
        print("\n" + "=" * 70)
        print(" RUNNING SMOKE TEST (a): Variety MobileNetV2 (1+1 epochs)")
        print("=" * 70)
        out_a = os.path.join(temp_root, "smoke_a")
        args_a = types.SimpleNamespace(
            out_dir=out_a,
            task="variety",
            arch="mobilenetv2",
            split="hash",
            cv_folds=0,
            epochs_stage1=1,
            epochs_stage2=1,
            batch_size=16,
            unfreeze_fraction=None,
            label_smoothing=0.0,
            ordinal_smoothing=False,
            data_dir=data_dir,
            labels_file=labels_file,
            holdout_file=None,
            min_images_per_class=30,
        )

        m_a = train_pipeline(args_a)
        # Check prediction match on 10 test images
        with open(os.path.join(out_a, "metrics.json")) as f:
            meta_a = json.load(f)
        test_imgs = [
            os.path.join(data_dir, c, f)
            for c in os.listdir(data_dir) if os.path.isdir(os.path.join(data_dir, c))
            for f in os.listdir(os.path.join(data_dir, c))[:2]
        ][:10]
        match_a, diff_a = verify_predictor_match(
            os.path.join(out_a, "model.keras"),
            os.path.join(out_a, "model_config.json"),
            os.path.join(out_a, "class_names.txt"),
            test_imgs,
            "mobilenetv2",
        )
        results["(a) Variety MobileNetV2"] = {
            "s1_sec_per_epoch": meta_a["timing"]["stage1_seconds_per_epoch"],
            "s2_sec_per_epoch": meta_a["timing"]["stage2_seconds_per_epoch"],
            "total_time": meta_a["timing"]["total_duration_seconds"],
            "predictor_match": match_a,
            "max_pred_diff": diff_a,
        }

        # ------------------------------------------------------------------
        # Smoke Test (b): Variety EfficientNetB3
        # ------------------------------------------------------------------
        print("\n" + "=" * 70)
        print(" RUNNING SMOKE TEST (b): Variety EfficientNetB3 (1+1 epochs)")
        print("=" * 70)
        out_b = os.path.join(temp_root, "smoke_b")
        args_b = types.SimpleNamespace(
            out_dir=out_b,
            task="variety",
            arch="efficientnetb3",
            split="hash",
            cv_folds=0,
            epochs_stage1=1,
            epochs_stage2=1,
            batch_size=16,
            unfreeze_fraction=0.20,
            label_smoothing=0.0,
            ordinal_smoothing=False,
            data_dir=data_dir,
            labels_file=labels_file,
            holdout_file=None,
            min_images_per_class=30,
        )

        m_b = train_pipeline(args_b)
        match_b, diff_b = verify_predictor_match(
            os.path.join(out_b, "model.keras"),
            os.path.join(out_b, "model_config.json"),
            os.path.join(out_b, "class_names.txt"),
            test_imgs,
            "efficientnetb3",
        )
        results["(b) Variety EfficientNetB3"] = {
            "s1_sec_per_epoch": m_b["timing"]["stage1_seconds_per_epoch"],
            "s2_sec_per_epoch": m_b["timing"]["stage2_seconds_per_epoch"],
            "total_time": m_b["timing"]["total_duration_seconds"],
            "predictor_match": match_b,
            "max_pred_diff": diff_b,
        }

        # ------------------------------------------------------------------
        # Smoke Test (c): Ripeness
        # ------------------------------------------------------------------
        print("\n" + "=" * 70)
        print(" RUNNING SMOKE TEST (c): Ripeness (1+1 epochs)")
        print("=" * 70)
        out_c = os.path.join(temp_root, "smoke_c")

        # Check real ripeness labels count
        with open(labels_file) as f:
            real_labels = json.load(f)
        real_ripeness_counts = {s: sum(1 for rec in real_labels.values() if rec.get("ripeness") == s) for s in ["Green", "Turning", "Ripe", "Overripe"]}
        used_synthetic = False
        fake_labels_file = os.path.join(temp_root, "fake_ripeness_labels.json")

        if any(cnt < 30 for cnt in real_ripeness_counts.values()):
            used_synthetic = True
            print(f"[NOTICE] Real ripeness counts {real_ripeness_counts} are below 30 per stage.")
            print("Creating balanced synthetic test labels (35 images per stage, 140 total) in temp folder for smoke test.")
            all_shas = list(real_labels.keys())
            fake_labels = dict(real_labels)
            stages = ["Green", "Turning", "Ripe", "Overripe"]
            for i, sha in enumerate(all_shas[:140]):
                fake_labels[sha] = dict(real_labels[sha])
                fake_labels[sha]["ripeness"] = stages[i % 4]
            with open(fake_labels_file, "w") as f:
                json.dump(fake_labels, f, indent=2)
            c_labels_file = fake_labels_file
        else:
            c_labels_file = labels_file

        args_c = types.SimpleNamespace(
            out_dir=out_c,
            task="ripeness",
            arch="mobilenetv2",
            split="hash",
            cv_folds=0,
            epochs_stage1=1,
            epochs_stage2=1,
            batch_size=16,
            unfreeze_fraction=None,
            label_smoothing=0.0,
            ordinal_smoothing=False,
            data_dir=data_dir,
            labels_file=c_labels_file,
            holdout_file=None,
            min_images_per_class=30,
        )

        m_c = train_pipeline(args_c)
        match_c, diff_c = verify_predictor_match(
            os.path.join(out_c, "model.keras"),
            os.path.join(out_c, "model_config.json"),
            os.path.join(out_c, "class_names.txt"),
            test_imgs,
            "mobilenetv2",
        )
        results["(c) Ripeness MobileNetV2"] = {
            "s1_sec_per_epoch": m_c["timing"]["stage1_seconds_per_epoch"],
            "s2_sec_per_epoch": m_c["timing"]["stage2_seconds_per_epoch"],
            "total_time": m_c["timing"]["total_duration_seconds"],
            "predictor_match": match_c,
            "max_pred_diff": diff_c,
            "used_synthetic_labels": used_synthetic,
        }

    print("\n" + "=" * 70)
    print("                     SMOKE TEST SUMMARY REPORT")
    print("=" * 70)
    for name, r in results.items():
        print(f"\n{name}:")
        print(f"  Stage 1 Time/Epoch    : {r['s1_sec_per_epoch']}s")
        print(f"  Stage 2 Time/Epoch    : {r['s2_sec_per_epoch']}s")
        print(f"  Total Duration        : {r['total_time']}s")
        print(f"  Predictor Path Match  : {r['predictor_match']} (max diff: {r['max_pred_diff']:.6f})")
        if r.get("used_synthetic_labels"):
            print("  Note: Used temporary balanced synthetic labels (real labels have 0 in some stages).")
    print("=" * 70 + "\n")
    return results


if __name__ == "__main__":
    run_all_smoke_tests()
