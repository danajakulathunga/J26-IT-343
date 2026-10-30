"""
Banana Identification & Ripeness Training Pipeline
Supports:
- Tasks: variety (default, 6 classes) and ripeness (4 ordered classes: Green < Turning < Ripe < Overripe)
- Architectures: mobilenetv2 (default), efficientnetb0, efficientnetb3
- Preprocessing: 300x300, MobileNetV2 preprocess_input vs raw 0-255 RGB for EfficientNet
- Split modes: hash (default) and group (preserves whole bunches, falls back with legacy-confounded flag)
- Cross-validation: StratifiedGroupKFold on train+val part
- Ripeness metrics: within-one-stage accuracy, quadratic Cohen's kappa, MASE, per-variety confusion
- Standalone execution with --data-dir and --labels-file
"""

import argparse
import csv
import datetime
import hashlib
import json
import os
import random
import sys
import time
from typing import Any, Dict, List, Optional, Tuple

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False

import numpy as np
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    cohen_kappa_score,
    confusion_matrix,
    f1_score,
)
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.utils.class_weight import compute_class_weight
import tensorflow as tf

layers = tf.keras.layers
models = tf.keras.models

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from app.ml.labels import VALID_RIPENESS_STAGES

IMG_SIZE = (300, 300)
RIPENESS_CLASSES = list(VALID_RIPENESS_STAGES)


def parse_args():
    parser = argparse.ArgumentParser(description="Banana Variety and Ripeness Training Pipeline")
    parser.add_argument("--out-dir", type=str, required=True, help="Directory to save artifacts")
    parser.add_argument("--task", type=str, choices=["variety", "ripeness"], default="variety", help="Task to train")
    parser.add_argument("--arch", type=str, choices=["mobilenetv2", "efficientnetb0", "efficientnetb3"], default="mobilenetv2", help="Model architecture")
    parser.add_argument("--split", type=str, choices=["hash", "group"], default="hash", help="Dataset split strategy")
    parser.add_argument("--cv", "--cv-folds", dest="cv_folds", type=int, default=0, help="Number of StratifiedGroupKFold CV folds (0=off)")
    parser.add_argument("--epochs-stage1", type=int, default=20, help="Epochs for Stage 1 (frozen base)")
    parser.add_argument("--epochs-stage2", type=int, default=10, help="Epochs for Stage 2 (fine-tuning)")
    parser.add_argument("--batch-size", type=int, default=16, help="Batch size")
    parser.add_argument("--lr-stage1", type=float, default=1e-3, help="Learning rate for Stage 1 (frozen base, default 1e-3)")
    parser.add_argument("--lr-stage2", type=float, default=1e-5, help="Learning rate for Stage 2 (fine-tuning, default 1e-5)")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for split and shuffling (default 42)")
    parser.add_argument("--run-name", type=str, default=None, help="Descriptive name identifier for this run")
    parser.add_argument("--unfreeze-fraction", type=float, default=None, help="Fraction of base layers to unfreeze in Stage 2 (default 0.2 for EfficientNet, 30 layers for MobileNetV2)")
    parser.add_argument("--label-smoothing", type=float, default=0.0, help="Label smoothing epsilon (default 0.0)")
    parser.add_argument("--ordinal-smoothing", action="store_true", help="Apply ordinal smoothing to adjacent ripeness stages")
    parser.add_argument("--data-dir", type=str, default=None, help="Processed images directory")
    parser.add_argument("--labels-file", type=str, default=None, help="Labels JSON file")
    parser.add_argument("--holdout-file", type=str, default=None, help="Holdout bunches JSON file")
    parser.add_argument("--img-size", type=int, default=300, help="Input image resolution (default 300)")
    parser.add_argument("--min-images-per-class", type=int, default=None, help="Minimum images required per class")
    parser.add_argument("--classes", nargs="*", default=None, help="Explicit list of classes to include")
    parser.add_argument("--aug-standard", type=str, choices=["on", "off"], default="on", help="Standard in-model data augmentations (flip, rotation, zoom, brightness, contrast) for train split: on|off (default: on)")
    parser.add_argument("--bg-swap-prob", type=float, default=0.0, help="Probability of background-swap augmentation (train split only, default 0.0)")
    parser.add_argument("--class-weight", type=str, choices=["off", "balanced"], default="off", help="Class weighting: off|balanced (default: off)")
    parser.add_argument("--bg-dir", "--backgrounds-dir", dest="bg_dir", type=str, default=None, help="Directory containing custom background images (default data/backgrounds)")
    parser.add_argument("--mask-cache-dir", type=str, default=None, help="Directory to cache computed segmentation masks (default data/diagnostics/masks)")
    return parser.parse_args()


def get_hash_split(filename: str) -> str:
    h = int(hashlib.sha256(filename.encode("utf-8")).hexdigest(), 16) % 100
    if h < 80:
        return "train"
    elif h < 90:
        return "val"
    else:
        return "test"


def configure_hardware_limits():
    """Limits CPU/GPU usage per environment configuration."""
    import multiprocessing
    total_cores = multiprocessing.cpu_count()
    cpu_pct = float(os.environ.get("CPU_USAGE_LIMIT_PERCENT", 50))
    cpu_threads = max(1, int(total_cores * (cpu_pct / 100.0)))

    try:
        tf.config.threading.set_intra_op_parallelism_threads(cpu_threads)
        tf.config.threading.set_inter_op_parallelism_threads(max(1, cpu_threads // 2))
    except Exception:
        pass

    try:
        gpus = tf.config.list_physical_devices("GPU")
        if gpus:
            for g in gpus:
                tf.config.experimental.set_memory_growth(g, True)
    except Exception:
        pass


def load_dataset_records(
    data_dir: str,
    labels_file: str,
    task: str,
    min_images_per_class: int,
    classes: Optional[List[str]] = None,
) -> Tuple[List[Dict[str, Any]], List[str], Dict[str, int]]:
    """
    Scans dataset and pairs each image with its labels record.
    Filters and orders classes according to task.
    """
    if not os.path.isdir(data_dir):
        raise FileNotFoundError(f"Processed images directory '{data_dir}' not found.")

    labels: Dict[str, Any] = {}
    if os.path.isfile(labels_file):
        try:
            with open(labels_file, "r", encoding="utf-8") as f:
                labels = json.load(f)
        except Exception as e:
            print(f"[WARN] Could not load labels file {labels_file}: {e}")

    records = []
    # Scan processed images directory
    for cname in sorted(os.listdir(data_dir)):
        cdir = os.path.join(data_dir, cname)
        if not os.path.isdir(cdir) or cname.startswith("."):
            continue
        if classes is not None and cname not in classes:
            continue
        for fname in sorted(os.listdir(cdir)):
            if fname.startswith(".") or not fname.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            sha16 = os.path.splitext(fname)[0]
            fpath = os.path.join(cdir, fname)
            lbl_rec = labels.get(sha16, {})

            variety = lbl_rec.get("variety") or cname
            ripeness = lbl_rec.get("ripeness")
            bunch_id = lbl_rec.get("bunch_id")
            group_id = lbl_rec.get("group_id") or (bunch_id if bunch_id else f"legacy_{variety}")

            rec = {
                "sha16": sha16,
                "filename": fname,
                "path": fpath,
                "variety": variety,
                "ripeness": ripeness,
                "bunch_id": bunch_id,
                "group_id": group_id,
            }
            records.append(rec)

    if task == "ripeness":
        # Only photos that have a valid ripeness label
        filtered = [r for r in records if r["ripeness"] in RIPENESS_CLASSES]
        class_names = list(RIPENESS_CLASSES)  # Fixed order: Green, Turning, Ripe, Overripe
        class_counts = {c: 0 for c in class_names}
        for r in filtered:
            class_counts[r["ripeness"]] += 1
            r["label_name"] = r["ripeness"]
            r["label_idx"] = class_names.index(r["ripeness"])

        print("\nRipeness Stage Counts:")
        for c in class_names:
            print(f"  {c:<12}: {class_counts[c]}")

        # Check threshold
        for c in class_names:
            if class_counts[c] < min_images_per_class:
                raise ValueError(
                    f"Ripeness stage '{c}' has {class_counts[c]} images, which is below the minimum required "
                    f"threshold of {min_images_per_class} (MIN_IMAGES_PER_CLASS). Refusing to train."
                )
        return filtered, class_names, class_counts

    else:
        # Variety task: all photos
        class_names = sorted(list(set(r["variety"] for r in records)))
        if len(class_names) < 2:
            raise ValueError(f"Need at least 2 variety classes to train. Found: {class_names}")

        class_counts = {c: 0 for c in class_names}
        for r in records:
            class_counts[r["variety"]] += 1
            r["label_name"] = r["variety"]
            r["label_idx"] = class_names.index(r["variety"])

        print("\nVariety Class Counts:")
        for c in class_names:
            print(f"  {c:<20}: {class_counts[c]}")

        for c in class_names:
            if class_counts[c] < min_images_per_class:
                raise ValueError(
                    f"Class '{c}' has {class_counts[c]} images, which is below the minimum required "
                    f"threshold of {min_images_per_class} (MIN_IMAGES_PER_CLASS). Refusing to train."
                )
        return records, class_names, class_counts


def partition_dataset(
    records: List[Dict[str, Any]],
    split_mode: str,
    holdout_file: Optional[str] = None,
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], List[Dict[str, Any]], Dict[str, Any]]:
    """
    Splits records into train, val, and test partitions according to split_mode ('hash' or 'group').
    Honors test_bunches from holdout_file.
    Returns (train_recs, val_recs, test_recs, split_metadata).
    """
    test_bunches: set[str] = set()
    if holdout_file and os.path.isfile(holdout_file):
        try:
            with open(holdout_file, "r", encoding="utf-8") as f:
                h_data = json.load(f)
                test_bunches = set(h_data.get("test_bunches", []))
                print(f"[HOLDOUT] Loaded {len(test_bunches)} holdout bunches for test split: {test_bunches}")
        except Exception as e:
            print(f"[WARN] Could not read holdout file: {e}")

    train_recs: List[Dict[str, Any]] = []
    val_recs: List[Dict[str, Any]] = []
    test_recs: List[Dict[str, Any]] = []

    legacy_confounded_classes = []
    groups_per_class_split: Dict[str, Dict[str, int]] = {}

    # Separate holdout items first
    remaining_by_class: Dict[str, List[Dict[str, Any]]] = {}
    for r in records:
        c = r["label_name"]
        if c not in remaining_by_class:
            remaining_by_class[c] = []

        if r.get("bunch_id") and r["bunch_id"] in test_bunches:
            r["split"] = "test"
            r["split_reason"] = "held_out_bunch"
            test_recs.append(r)
        else:
            remaining_by_class[c].append(r)

    n_groups_per_class: Dict[str, int] = {}
    for c, items in remaining_by_class.items():
        groups_per_class_split[c] = {"train": 0, "val": 0, "test": 0}
        group_to_items: Dict[str, List[Dict[str, Any]]] = {}
        for item in items:
            gid = item["group_id"]
            if gid not in group_to_items:
                group_to_items[gid] = []
            group_to_items[gid].append(item)

        num_groups = len(group_to_items)
        n_groups_per_class[c] = num_groups

        # Addition A: is_legacy_confounded must be computed from real group counts
        # (true when test images come from classes with fewer than 3 groups), regardless of --split mode
        if num_groups < 3:
            legacy_confounded_classes.append(c)

        if split_mode == "group" and num_groups >= 3:
            # Deterministic group split sorted by sha256(group_id)
            sorted_groups = sorted(
                group_to_items.keys(),
                key=lambda g: hashlib.sha256(g.encode("utf-8")).hexdigest(),
            )
            # Allocate groups to target roughly 70/15/15 image distribution
            # Ensure at least 1 test group and 1 val group
            total_imgs = len(items)
            c_train_g, c_val_g, c_test_g = [], [], []
            c_train_cnt, c_val_cnt, c_test_cnt = 0, 0, 0

            # Last group to test, second to last to val
            c_test_g.append(sorted_groups[-1])
            c_test_cnt += len(group_to_items[sorted_groups[-1]])
            c_val_g.append(sorted_groups[-2])
            c_val_cnt += len(group_to_items[sorted_groups[-2]])

            for gid in sorted_groups[:-2]:
                cnt = len(group_to_items[gid])
                if (c_val_cnt + cnt) / total_imgs <= 0.20 and len(c_train_g) >= 1:
                    c_val_g.append(gid)
                    c_val_cnt += cnt
                elif (c_test_cnt + cnt) / total_imgs <= 0.20 and len(c_train_g) >= 1:
                    c_test_g.append(gid)
                    c_test_cnt += cnt
                else:
                    c_train_g.append(gid)
                    c_train_cnt += cnt

            if not c_train_g:
                # Edge case: move from val or test to train
                c_train_g.append(c_val_g.pop(0))

            for gid in c_train_g:
                for item in group_to_items[gid]:
                    item["split"] = "train"
                    item["split_reason"] = "group_split"
                    train_recs.append(item)
                groups_per_class_split[c]["train"] += 1

            for gid in c_val_g:
                for item in group_to_items[gid]:
                    item["split"] = "val"
                    item["split_reason"] = "group_split"
                    val_recs.append(item)
                groups_per_class_split[c]["val"] += 1

            for gid in c_test_g:
                for item in group_to_items[gid]:
                    item["split"] = "test"
                    item["split_reason"] = "group_split"
                    test_recs.append(item)
                groups_per_class_split[c]["test"] += 1

        else:
            # Hash split (default or fallback for < 3 groups)
            if split_mode == "group" and num_groups < 3:
                print(f"[SPLIT NOTICE] Class '{c}' has {num_groups} group(s) (< 3). Falling back to hash split (legacy-confounded).")
            elif num_groups < 3:
                print(f"[SPLIT NOTICE] Class '{c}' has {num_groups} group(s) (< 3). Marked as legacy-confounded.")

            c_g_assigned: Dict[str, set] = {"train": set(), "val": set(), "test": set()}
            for item in items:
                sp = get_hash_split(item["filename"])
                item["split"] = sp
                item["split_reason"] = "hash_split"
                if sp == "train":
                    train_recs.append(item)
                elif sp == "val":
                    val_recs.append(item)
                else:
                    test_recs.append(item)
                c_g_assigned[sp].add(item["group_id"])

            for sp in ("train", "val", "test"):
                groups_per_class_split[c][sp] = len(c_g_assigned[sp])

    # Count test split sizes per class and warn if < 5
    print("\nSplit Sizes per Class:")
    test_counts_by_class: Dict[str, int] = {}
    for r in test_recs:
        c = r["label_name"]
        test_counts_by_class[c] = test_counts_by_class.get(c, 0) + 1

    for c in remaining_by_class.keys():
        t_cnt = test_counts_by_class.get(c, 0)
        print(f"  {c:<20}: Test Images = {t_cnt}")
        if t_cnt < 5:
            print(f"[WARNING] Class '{c}' has only {t_cnt} test images (< 5)!")

    metadata = {
        "split_mode": split_mode,
        "legacy_confounded_classes": legacy_confounded_classes,
        "is_legacy_confounded": len(legacy_confounded_classes) > 0,
        "groups_per_class_split": groups_per_class_split,
        "n_groups_per_class": n_groups_per_class,
        "total_train": len(train_recs),
        "total_val": len(val_recs),
        "total_test": len(test_recs),
        "test_counts_by_class": test_counts_by_class,
    }
    return train_recs, val_recs, test_recs, metadata


def create_tf_dataset(
    records: List[Dict[str, Any]],
    batch_size: int,
    is_train: bool,
    arch: str,
    label_smoothing: float = 0.0,
    ordinal_smoothing: bool = False,
    num_classes: int = 6,
    bg_swap_prob: float = 0.0,
    backgrounds_dir: Optional[str] = None,
    mask_cache_dir: Optional[str] = None,
    use_one_hot: Optional[bool] = None,
) -> tf.data.Dataset:
    paths = [r["path"] for r in records]
    labels_raw = [r["label_idx"] for r in records]

    # Target representation
    if use_one_hot is None:
        use_one_hot = (label_smoothing > 0.0) or ordinal_smoothing
    if use_one_hot:
        target_vectors = []
        for l in labels_raw:
            vec = np.zeros((num_classes,), dtype=np.float32)
            if ordinal_smoothing and num_classes == 4:
                # Spread 0.1 to adjacent stages
                if l == 0:
                    vec[0], vec[1] = 0.9, 0.1
                elif l == 1:
                    vec[0], vec[1], vec[2] = 0.05, 0.9, 0.05
                elif l == 2:
                    vec[1], vec[2], vec[3] = 0.05, 0.9, 0.05
                elif l == 3:
                    vec[2], vec[3] = 0.1, 0.9
            else:
                vec[l] = 1.0
            target_vectors.append(vec)
        targets = np.array(target_vectors, dtype=np.float32)
    else:
        targets = np.array(labels_raw, dtype=np.int32)

    is_efficientnet = "efficientnet" in arch.lower()

    def _parse_fn(path, target):
        img_bytes = tf.io.read_file(path)
        img = tf.image.decode_jpeg(img_bytes, channels=3)
        img = tf.image.resize(img, IMG_SIZE)
        img = tf.cast(img, tf.uint8)

        if is_train and bg_swap_prob > 0.0:
            def _apply_aug(img_tensor, path_tensor):
                from app.ml.augment_bg import augment_background_swap
                from pathlib import Path
                p_str = path_tensor.numpy().decode("utf-8") if hasattr(path_tensor, "numpy") else str(path_tensor)
                stem = Path(p_str).stem
                aug_img = augment_background_swap(
                    img_tensor.numpy(),
                    bg_swap_prob=bg_swap_prob,
                    backgrounds_dir=backgrounds_dir,
                    mask_cache_dir=mask_cache_dir,
                    image_id=stem,
                )
                return aug_img.astype(np.float32)

            img = tf.py_function(func=_apply_aug, inp=[img, path], Tout=tf.float32)
            img.set_shape(IMG_SIZE + (3,))
        else:
            img = tf.cast(img, tf.float32)

        if not is_efficientnet:
            # MobileNetV2 uses preprocess_input
            img = tf.keras.applications.mobilenet_v2.preprocess_input(img)
        # EfficientNet receives raw 0-255 RGB
        return img, target

    ds = tf.data.Dataset.from_tensor_slices((paths, targets))
    if is_train:
        ds = ds.shuffle(buffer_size=max(len(paths), 100), seed=42)
    ds = ds.map(_parse_fn, num_parallel_calls=tf.data.AUTOTUNE)
    if not is_train:
        ds = ds.cache()
    ds = ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)
    return ds


def build_model(
    num_classes: int,
    arch: str,
    task: str,
    aug_standard: bool = True,
) -> Tuple[tf.keras.Model, tf.keras.Model]:
    """
    Constructs model with backbone and task-specific augmentations.
    """
    arch_lower = arch.lower()
    if arch_lower == "efficientnetb0":
        base_model = tf.keras.applications.EfficientNetB0(
            input_shape=IMG_SIZE + (3,),
            include_top=False,
            weights="imagenet",
        )
    elif arch_lower == "efficientnetb3":
        base_model = tf.keras.applications.EfficientNetB3(
            input_shape=IMG_SIZE + (3,),
            include_top=False,
            weights="imagenet",
        )
    else:
        base_model = tf.keras.applications.MobileNetV2(
            input_shape=IMG_SIZE + (3,),
            include_top=False,
            weights="imagenet",
        )

    base_model.trainable = False

    inputs = tf.keras.Input(shape=IMG_SIZE + (3,))

    # Task-specific standard augmentations (active during training only)
    if not aug_standard:
        x = inputs
    elif task == "ripeness":
        # NO hue or saturation shifts! Flip, small rotation, zoom, small brightness/contrast only
        x = layers.RandomFlip("horizontal")(inputs)
        x = layers.RandomRotation(0.10)(x)
        x = layers.RandomZoom(0.10)(x)
        x = layers.RandomBrightness(0.05)(x)
        x = layers.RandomContrast(0.05)(x)
    else:
        # Variety augmentations
        x = layers.RandomFlip("horizontal")(inputs)
        x = layers.RandomRotation(0.15)(x)
        x = layers.RandomZoom(0.15)(x)
        x = layers.RandomBrightness(0.15)(x)
        x = layers.RandomContrast(0.15)(x)

    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation="relu")(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = models.Model(inputs, outputs)
    return model, base_model


def plot_curves(history, title: str, out_path: str):
    if not HAS_MATPLOTLIB:
        return
    fig, axes = plt.subplots(1, 2, figsize=(10, 4))
    axes[0].plot(history.history.get("accuracy", []), label="Train Acc")
    axes[0].plot(history.history.get("val_accuracy", []), label="Val Acc")
    axes[0].set_title(f"{title} - Accuracy")
    axes[0].set_xlabel("Epoch")
    axes[0].legend()

    axes[1].plot(history.history.get("loss", []), label="Train Loss")
    axes[1].plot(history.history.get("val_loss", []), label="Val Loss")
    axes[1].set_title(f"{title} - Loss")
    axes[1].set_xlabel("Epoch")
    axes[1].legend()

    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


def check_cv_feasibility(train_val_recs: List[Dict[str, Any]], k_folds: int) -> Tuple[bool, str]:
    """
    Checks whether each class has at least k_folds distinct groups in train+val records.
    Returns (True, "OK") or (False, "CV skipped: not enough groups").
    """
    if k_folds <= 1:
        return False, "CV disabled"
    class_groups: Dict[str, set] = {}
    for r in train_val_recs:
        c = r["label_name"]
        gid = r.get("group_id") or r.get("bunch_id") or f"legacy_{c}"
        class_groups.setdefault(c, set()).add(gid)
    for c, gset in class_groups.items():
        if len(gset) < k_folds:
            return False, "CV skipped: not enough groups"
    return True, "OK"


def compute_ripeness_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> Dict[str, float]:
    """
    Computes accuracy, within-one-stage accuracy, quadratic Cohen's kappa, and MASE for ripeness.
    """
    if len(y_true) == 0:
        return {
            "accuracy": 0.0,
            "within_one_stage_accuracy": 0.0,
            "quadratic_weighted_cohen_kappa": 0.0,
            "mean_absolute_stage_error": 0.0,
        }
    acc = float(accuracy_score(y_true, y_pred))
    within_one = float(np.mean(np.abs(y_true - y_pred) <= 1))
    quad_kappa = float(cohen_kappa_score(y_true, y_pred, weights="quadratic"))
    mase = float(np.mean(np.abs(y_true - y_pred)))
    return {
        "accuracy": acc,
        "within_one_stage_accuracy": within_one,
        "quadratic_weighted_cohen_kappa": quad_kappa,
        "mean_absolute_stage_error": mase,
    }


def confusion_matrix_to_y_true_y_pred(cm: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """
    Converts a 2D confusion matrix into y_true and y_pred arrays.
    """
    y_true = []
    y_pred = []
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            count = int(cm[i, j])
            y_true.extend([i] * count)
            y_pred.extend([j] * count)
    return np.array(y_true), np.array(y_pred)


def train_pipeline(args) -> Dict[str, Any]:
    configure_hardware_limits()
    start_time = time.time()
    start_dt = datetime.datetime.now().isoformat()

    os.makedirs(args.out_dir, exist_ok=True)

    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    if args.data_dir:
        data_dir = args.data_dir
    else:
        if args.img_size == 300:
            data_dir = os.path.join(base_dir, "data", "images", "processed")
        else:
            data_dir = os.path.join(base_dir, "data", "images", f"processed_{args.img_size}")

    if not os.path.isdir(data_dir):
        sys.exit(
            f"Error: Processed images directory for image size {args.img_size} does not exist: {data_dir}. "
            f"All training currently requires 300px (data/images/processed)."
        )

    labels_file = args.labels_file or os.path.join(base_dir, "data", "labels.json")
    holdout_file = args.holdout_file or os.path.join(base_dir, "data", "holdout.json")

    min_images = args.min_images_per_class
    if min_images is None:
        min_images = int(os.environ.get("MIN_IMAGES_PER_CLASS", 30))

    prep_mode = "raw_0_255" if "efficientnet" in args.arch.lower() else "mobilenet_v2"

    try:
        tf.config.threading.set_intra_op_parallelism_threads(12)
        tf.config.threading.set_inter_op_parallelism_threads(2)
    except Exception:
        pass

    print(f"\n=======================================================")
    print(f" Training Pipeline Configuration")
    print(f" Task              : {args.task}")
    print(f" Architecture      : {args.arch} (prep: {prep_mode})")
    print(f" Split Strategy    : {args.split}")
    print(f" CV Folds          : {args.cv_folds}")
    print(f" Label Smoothing   : {args.label_smoothing}")
    print(f" Ordinal Smoothing : {args.ordinal_smoothing}")
    print(f" Output Directory  : {args.out_dir}")
    print(f" Stage 1 Epochs    : {args.epochs_stage1}")
    print(f" Stage 2 Epochs    : {args.epochs_stage2}")
    print(f"=======================================================\n")

    # 1. Load records and filter
    records, class_names, class_counts = load_dataset_records(
        data_dir, labels_file, args.task, min_images, classes=args.classes
    )
    num_classes = len(class_names)

    # 2. Partition dataset
    train_recs, val_recs, test_recs, split_meta = partition_dataset(
        records, args.split, holdout_file
    )

    print(f"\nPartitions: Train={len(train_recs)}, Val={len(val_recs)}, Test={len(test_recs)}")

    if args.cv_folds > 1:
        can_run_cv, cv_msg = check_cv_feasibility(train_recs + val_recs, args.cv_folds)
        if not can_run_cv:
            print(f"[CV NOTICE] {cv_msg}. Falling back to single split.")
        else:
            print(f"[CV] StratifiedGroupKFold with {args.cv_folds} folds enabled.")

    # 3. Class weights (optional)
    if args.class_weight == "balanced":
        train_labels = [r["label_idx"] for r in train_recs]
        class_weights_arr = compute_class_weight(
            "balanced", classes=np.arange(num_classes), y=np.array(train_labels)
        )
        class_weights_dict = {i: float(w) for i, w in enumerate(class_weights_arr)}
        print(f"Balanced Class Weights: {class_weights_dict}")
    else:
        class_weights_dict = None
        print("Class Weights: None (off)")

    # Build datasets
    use_one_hot = (args.label_smoothing > 0.0) or args.ordinal_smoothing
    train_ds = create_tf_dataset(
        train_recs, args.batch_size, is_train=True, arch=args.arch,
        label_smoothing=args.label_smoothing, ordinal_smoothing=args.ordinal_smoothing,
        num_classes=num_classes,
        bg_swap_prob=args.bg_swap_prob,
        backgrounds_dir=args.bg_dir,
        mask_cache_dir=args.mask_cache_dir,
    )
    val_ds = create_tf_dataset(
        val_recs, args.batch_size, is_train=False, arch=args.arch,
        label_smoothing=0.0, ordinal_smoothing=False, num_classes=num_classes,
        bg_swap_prob=0.0, use_one_hot=use_one_hot,
    )
    test_ds = create_tf_dataset(
        test_recs, args.batch_size, is_train=False, arch=args.arch,
        label_smoothing=0.0, ordinal_smoothing=False, num_classes=num_classes,
        bg_swap_prob=0.0, use_one_hot=use_one_hot,
    )

    # Loss function
    if use_one_hot:
        loss_fn = tf.keras.losses.CategoricalCrossentropy(label_smoothing=args.label_smoothing)
    else:
        loss_fn = tf.keras.losses.SparseCategoricalCrossentropy()

    # 4. Optional Cross-Validation
    if args.cv_folds > 1:
        cv_eligible = not split_meta["is_legacy_confounded"]
        if cv_eligible:
            print(f"\n--- Running {args.cv_folds}-Fold StratifiedGroupKFold on Train+Val ---")
            train_val_recs = train_recs + val_recs
            tv_X = [r["path"] for r in train_val_recs]
            tv_y = [r["label_idx"] for r in train_val_recs]
            tv_groups = [r["group_id"] for r in train_val_recs]

            sgkf = StratifiedGroupKFold(n_splits=args.cv_folds, shuffle=True, random_state=42)
            cv_scores = []
            cv_f1s = []

            for fold_idx, (f_tr_idx, f_va_idx) in enumerate(sgkf.split(tv_X, tv_y, tv_groups), 1):
                f_tr = [train_val_recs[i] for i in f_tr_idx]
                f_va = [train_val_recs[i] for i in f_va_idx]
                f_tr_ds = create_tf_dataset(
                    f_tr, args.batch_size, is_train=True, arch=args.arch, num_classes=num_classes,
                    bg_swap_prob=args.bg_swap_prob, backgrounds_dir=args.bg_dir,
                    mask_cache_dir=args.mask_cache_dir, use_one_hot=use_one_hot,
                )
                f_va_ds = create_tf_dataset(
                    f_va, args.batch_size, is_train=False, arch=args.arch, num_classes=num_classes,
                    bg_swap_prob=0.0, use_one_hot=use_one_hot,
                )

                m_fold, _ = build_model(
                    num_classes, args.arch, args.task, aug_standard=(args.aug_standard == "on")
                )
                m_fold.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss=loss_fn, metrics=["accuracy"])
                m_fold.fit(f_tr_ds, validation_data=f_va_ds, epochs=max(1, args.epochs_stage1), verbose=0)

                y_va_preds = np.argmax(m_fold.predict(f_va_ds, verbose=0), axis=1)
                y_va_true = [r["label_idx"] for r in f_va]
                acc_f = accuracy_score(y_va_true, y_va_preds)
                f1_f = f1_score(y_va_true, y_va_preds, average="macro", zero_division=0)
                cv_scores.append(float(acc_f))
                cv_f1s.append(float(f1_f))
                print(f"  Fold {fold_idx}: Val Acc = {acc_f:.4f}, Macro-F1 = {f1_f:.4f}")

            cv_payload = {
                "folds": args.cv_folds,
                "fold_accuracies": cv_scores,
                "fold_macro_f1s": cv_f1s,
                "mean_accuracy": float(np.mean(cv_scores)),
                "std_accuracy": float(np.std(cv_scores)),
                "mean_macro_f1": float(np.mean(cv_f1s)),
                "std_macro_f1": float(np.std(cv_f1s)),
            }
            with open(os.path.join(args.out_dir, "cv_metrics.json"), "w", encoding="utf-8") as f:
                json.dump(cv_payload, f, indent=2)
            print(f"[CV RESULTS] Mean Accuracy: {cv_payload['mean_accuracy']:.4f} +/- {cv_payload['std_accuracy']:.4f}")
        else:
            print("CV skipped: not enough groups (legacy classes have < 3 groups)")

    if args.seed is not None:
        random.seed(args.seed)
        np.random.seed(args.seed)
        tf.random.set_seed(args.seed)

    # 5. Build full candidate model
    model, base_model = build_model(
        num_classes, args.arch, args.task, aug_standard=(args.aug_standard == "on")
    )

    total_layers = len(base_model.layers)
    if args.unfreeze_fraction is not None:
        unfreeze_fraction_used = args.unfreeze_fraction
        unfreeze_count = int(total_layers * args.unfreeze_fraction)
    elif "efficientnet" in args.arch.lower():
        unfreeze_fraction_used = 0.20
        unfreeze_count = int(total_layers * 0.20)
    else:
        unfreeze_count = min(30, total_layers)
        unfreeze_fraction_used = round(unfreeze_count / total_layers, 4) if total_layers > 0 else 0.0

    # Callbacks
    early_stop = tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True)
    reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=2, min_lr=1e-6, verbose=1)

    class MaskCacheStatsCallback(tf.keras.callbacks.Callback):
        def on_epoch_end(self, epoch, logs=None):
            if args.bg_swap_prob > 0.0:
                from app.ml.augment_bg import get_cache_stats
                stats = get_cache_stats()
                tot = stats["hits"] + stats["misses"]
                pct = (stats["hits"] / tot * 100.0) if tot > 0 else 0.0
                print(f"[MASK CACHE Epoch {epoch + 1}] Cumulative Hits: {stats['hits']}, Misses: {stats['misses']} (Hit Rate: {pct:.1f}%)")

    class HistoryTrackerCallback(tf.keras.callbacks.Callback):
        def __init__(self, stage: int, start_epoch: int = 1):
            super().__init__()
            self.stage = stage
            self.current_epoch = start_epoch
            self.records = []

        def on_epoch_end(self, epoch, logs=None):
            logs = logs or {}
            lr = None
            try:
                if hasattr(self.model.optimizer, "learning_rate"):
                    lr_val = self.model.optimizer.learning_rate
                    if callable(lr_val):
                        lr = float(lr_val(self.model.optimizer.iterations))
                    elif hasattr(lr_val, "numpy"):
                        lr = float(lr_val.numpy())
                    else:
                        lr = float(lr_val)
            except Exception:
                pass
            if lr is None:
                lr = float(logs.get("lr", 0.0))

            self.records.append({
                "global_epoch": self.current_epoch,
                "stage": self.stage,
                "loss": round(float(logs.get("loss", 0.0)), 6),
                "val_loss": round(float(logs.get("val_loss", 0.0)), 6),
                "accuracy": round(float(logs.get("accuracy", 0.0)), 6),
                "val_accuracy": round(float(logs.get("val_accuracy", 0.0)), 6),
                "learning_rate": lr,
            })
            self.current_epoch += 1

    version_name = os.path.basename(os.path.normpath(args.out_dir)) if args.out_dir else "candidate"

    def update_progress(phase: str, epoch: Optional[int] = None):
        total_eps = args.epochs_stage1 + args.epochs_stage2
        payload = {
            "phase": phase,
            "epoch": epoch,
            "total_epochs": total_eps,
            "version_id": version_name,
            "task": args.task,
            "updated_at": datetime.datetime.now().isoformat(),
        }
        if args.out_dir:
            try:
                os.makedirs(args.out_dir, exist_ok=True)
                with open(os.path.join(args.out_dir, "progress.json"), "w", encoding="utf-8") as f:
                    json.dump(payload, f, indent=2)
            except Exception:
                pass
        try:
            base_d = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
            p_path = os.path.join(base_d, "data", f"training_progress_{args.task}.json")
            os.makedirs(os.path.dirname(p_path), exist_ok=True)
            with open(p_path, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2)
        except Exception:
            pass

    class ProgressTrackingCallback(tf.keras.callbacks.Callback):
        def __init__(self, stage_name: str, start_epoch: int):
            super().__init__()
            self.stage_name = stage_name
            self.start_epoch = start_epoch

        def on_epoch_begin(self, epoch, logs=None):
            update_progress(self.stage_name, self.start_epoch + epoch)

    update_progress("caching masks" if args.bg_swap_prob > 0 else "stage 1", 0)

    callbacks_list = [early_stop, reduce_lr, MaskCacheStatsCallback()]
    tracker_s1 = HistoryTrackerCallback(stage=1, start_epoch=1)
    progress_s1 = ProgressTrackingCallback(stage_name="stage 1", start_epoch=1)

    # Stage 1: Frozen base
    print("\n--- STAGE 1: Training top layers (base frozen) ---")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=args.lr_stage1),
        loss=loss_fn,
        metrics=["accuracy"],
    )

    t0_s1 = time.time()
    hist1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs_stage1,
        class_weight=class_weights_dict,
        callbacks=callbacks_list + [tracker_s1, progress_s1],
        verbose=1,
    )
    s1_time = time.time() - t0_s1
    plot_curves(hist1, "Stage 1", os.path.join(args.out_dir, "stage1_curves.png"))

    # Stage 2: Fine-tuning
    tracker_s2 = None
    if args.epochs_stage2 > 0:
        print("\n--- STAGE 2: Fine-tuning unfreezing top layers ---")
        base_model.trainable = True
        cutoff_idx = max(0, total_layers - unfreeze_count)

        # Freeze BatchNormalization and layers below cutoff
        for idx, layer in enumerate(base_model.layers):
            if idx < cutoff_idx or isinstance(layer, tf.keras.layers.BatchNormalization):
                layer.trainable = False
            else:
                layer.trainable = True

        model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=args.lr_stage2),
            loss=loss_fn,
            metrics=["accuracy"],
        )

        tracker_s2 = HistoryTrackerCallback(stage=2, start_epoch=len(tracker_s1.records) + 1)
        progress_s2 = ProgressTrackingCallback(stage_name="stage 2", start_epoch=len(tracker_s1.records) + 1)
        t0_s2 = time.time()
        hist2 = model.fit(
            train_ds,
            validation_data=val_ds,
            epochs=args.epochs_stage2,
            class_weight=class_weights_dict,
            callbacks=callbacks_list + [tracker_s2, progress_s2],
            verbose=1,
        )
        s2_time = time.time() - t0_s2
        plot_curves(hist2, "Stage 2", os.path.join(args.out_dir, "stage2_curves.png"))
    else:
        hist2 = None
        s2_time = 0.0

    # 6. Evaluation on Test Split
    update_progress("evaluating", len(tracker_s1.records) + (len(tracker_s2.records) if tracker_s2 is not None else 0))
    print("\n--- EVALUATION on Test Split ---")
    y_true = []
    y_pred = []
    y_probs = []

    for imgs, lbls in test_ds:
        preds = model.predict(imgs, verbose=0)
        y_probs.extend(preds)
        y_pred.extend(np.argmax(preds, axis=1))
        if use_one_hot:
            y_true.extend(np.argmax(lbls.numpy(), axis=1))
        else:
            y_true.extend(lbls.numpy())

    y_true = np.array(y_true)
    y_pred = np.array(y_pred)

    test_acc = float(accuracy_score(y_true, y_pred)) if len(y_true) else 0.0
    macro_f1 = float(f1_score(y_true, y_pred, average="macro", zero_division=0)) if len(y_true) else 0.0
    report = classification_report(
        y_true, y_pred, labels=list(range(num_classes)), target_names=class_names, output_dict=True, zero_division=0
    )
    cm = confusion_matrix(y_true, y_pred, labels=list(range(num_classes))).tolist()

    # Split accuracy breakdown: legacy hash-split vs held-out bunches
    legacy_test_mask = np.array([r.get("split_reason") not in ("held_out_bunch", "group_split") for r in test_recs])
    holdout_test_mask = np.array([r.get("split_reason") in ("held_out_bunch", "group_split") for r in test_recs])

    legacy_test_acc = float(accuracy_score(y_true[legacy_test_mask], y_pred[legacy_test_mask])) if np.any(legacy_test_mask) else None
    holdout_test_acc = float(accuracy_score(y_true[holdout_test_mask], y_pred[holdout_test_mask])) if np.any(holdout_test_mask) else None

    # Ripeness Specific Metrics
    ripeness_specifics = {}
    if args.task == "ripeness":
        r_metrics = compute_ripeness_metrics(y_true, y_pred)
        within_one_acc = r_metrics["within_one_stage_accuracy"]
        quad_kappa = r_metrics["quadratic_weighted_cohen_kappa"]
        mase = r_metrics["mean_absolute_stage_error"]

        # Per-variety accuracy and confusion matrix
        per_variety_results = {}
        all_test_varieties = sorted(list(set(r["variety"] for r in test_recs)))
        for v_name in all_test_varieties:
            v_mask = np.array([r["variety"] == v_name for r in test_recs])
            if np.any(v_mask):
                v_true = y_true[v_mask]
                v_pred = y_pred[v_mask]
                v_acc = float(accuracy_score(v_true, v_pred))
                v_cm = confusion_matrix(v_true, v_pred, labels=list(range(num_classes))).tolist()
                per_variety_results[v_name] = {
                    "count": int(np.sum(v_mask)),
                    "accuracy": v_acc,
                    "confusion_matrix": v_cm,
                }

        ripeness_specifics = {
            "within_one_stage_accuracy": within_one_acc,
            "quadratic_weighted_cohen_kappa": quad_kappa,
            "mean_absolute_stage_error": mase,
            "per_variety_results": per_variety_results,
        }

    total_duration = round(time.time() - start_time, 2)
    s1_per_epoch = round(s1_time / max(1, len(hist1.history.get("loss", [1]))), 3)
    s2_per_epoch = round(s2_time / max(1, len(hist2.history.get("loss", [1]))), 3) if hist2 is not None else 0.0

    print(f"\n=======================================================")
    print(f" Test Evaluation Results")
    print(f" Overall Test Accuracy      : {test_acc:.4f}")
    print(f" Macro F1 Score             : {macro_f1:.4f}")
    print(f" Legacy Hash-Split Test Acc : {legacy_test_acc}")
    print(f" Held-Out Bunch Test Acc    : {holdout_test_acc}")
    if holdout_test_acc is None:
        print(" [NOTE] Held-out bunch test split is empty; accuracy on legacy test images is not an independent generalisation estimate.")
    if args.task == "ripeness":
        print(f" Within-One-Stage Accuracy  : {ripeness_specifics['within_one_stage_accuracy']:.4f}")
        print(f" Quadratic Cohen's Kappa    : {ripeness_specifics['quadratic_weighted_cohen_kappa']:.4f}")
        print(f" Mean Absolute Stage Error  : {ripeness_specifics['mean_absolute_stage_error']:.4f}")
    print(f" Total Duration             : {total_duration}s (S1: {s1_per_epoch}s/epoch, S2: {s2_per_epoch}s/epoch)")
    print(f"=======================================================\n")

    # 7. Save candidate artifacts
    model_save_path = os.path.join(args.out_dir, "model.keras")
    model.save(model_save_path)
    print(f"Saved candidate model to: {model_save_path}")

    class_names_path = os.path.join(args.out_dir, "class_names.txt")
    with open(class_names_path, "w", encoding="utf-8") as f:
        f.write("\n".join(class_names))

    model_config = {
        "architecture": args.arch,
        "image_size": [args.img_size, args.img_size],
        "preprocessing": prep_mode,
        "task": args.task,
        "bg_swap_prob": args.bg_swap_prob,
    }
    config_path = os.path.join(args.out_dir, "model_config.json")
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(model_config, f, indent=2)

    # Save full config.json with actual run parameters
    train_counts_per_class = {c: sum(1 for r in train_recs if r["label_name"] == c) for c in class_names}
    val_counts_per_class = {c: sum(1 for r in val_recs if r["label_name"] == c) for c in class_names}
    test_counts_per_class = {c: sum(1 for r in test_recs if r["label_name"] == c) for c in class_names}

    if args.aug_standard == "off":
        aug_bounds = {
            "aug_standard": False,
            "bg_swap_prob": args.bg_swap_prob,
        }
    elif args.task == "ripeness":
        aug_bounds = {
            "aug_standard": True,
            "horizontal_flip": True,
            "rotation": 0.10,
            "zoom": 0.10,
            "brightness": 0.05,
            "contrast": 0.05,
            "bg_swap_prob": args.bg_swap_prob,
        }
    else:
        aug_bounds = {
            "aug_standard": True,
            "horizontal_flip": True,
            "rotation": 0.15,
            "zoom": 0.15,
            "brightness": 0.15,
            "contrast": 0.15,
            "bg_swap_prob": args.bg_swap_prob,
        }

    full_config_payload = {
        "run_name": args.run_name,
        "task": args.task,
        "architecture": args.arch,
        "image_size": [args.img_size, args.img_size],
        "preprocessing": prep_mode,
        "split_mode": args.split,
        "aug_standard": args.aug_standard,
        "lr_stage1": args.lr_stage1,
        "lr_stage2": args.lr_stage2,
        "reduce_lr_factor": 0.5,
        "reduce_lr_min_lr": 1e-06,
        "reduce_lr_patience": 2,
        "early_stopping_patience": 5,
        "unfreeze_fraction": unfreeze_fraction_used if args.epochs_stage2 > 0 else 0.0,
        "unfrozen_layers_count": unfreeze_count if args.epochs_stage2 > 0 else 0,
        "total_base_layers": total_layers,
        "batch_size": args.batch_size,
        "seed": args.seed,
        "label_smoothing": args.label_smoothing,
        "ordinal_smoothing": args.ordinal_smoothing,
        "dropout": 0.2,
        "class_weight": args.class_weight,
        "bg_swap_prob": args.bg_swap_prob,
        "augmentation": aug_bounds,
        "augmentation_list": [
            f"bg_swap_prob_{args.bg_swap_prob}",
            "horizontal_flip",
            "rotation_0.15" if args.task != "ripeness" else "rotation_0.10",
            "zoom_0.15" if args.task != "ripeness" else "zoom_0.10",
            "brightness_0.15" if args.task != "ripeness" else "brightness_0.05",
            "contrast_0.15" if args.task != "ripeness" else "contrast_0.05",
        ] if args.aug_standard != "off" else [f"bg_swap_prob_{args.bg_swap_prob}"],
        "tuning_pointers": {
            "winner_run": "T1",
            "table_csv": "data/diagnostics/tuning_table.csv",
            "table_md": "data/diagnostics/tuning_table.md",
            "criterion": "lowest validation loss (0.2153)"
        },
        "classes_used": class_names,
        "split_counts": {
            "train": len(train_recs),
            "val": len(val_recs),
            "test": len(test_recs),
        },
        "train_counts_per_class": train_counts_per_class,
        "val_counts_per_class": val_counts_per_class,
        "test_counts_per_class": test_counts_per_class,
    }
    with open(os.path.join(args.out_dir, "config.json"), "w", encoding="utf-8") as f:
        json.dump(full_config_payload, f, indent=2)

    # Save history.json and history.csv
    all_history = tracker_s1.records + (tracker_s2.records if tracker_s2 is not None else [])
    with open(os.path.join(args.out_dir, "history.json"), "w", encoding="utf-8") as f:
        json.dump(all_history, f, indent=2)

    with open(os.path.join(args.out_dir, "history.csv"), "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["global_epoch", "stage", "loss", "val_loss", "accuracy", "val_accuracy", "learning_rate"]
        )
        writer.writeheader()
        writer.writerows(all_history)

    metrics_payload = {
        "task": args.task,
        "architecture": args.arch,
        "preprocessing": prep_mode,
        "bg_swap_prob": args.bg_swap_prob,
        "test_accuracy": round(test_acc, 4),
        "macro_f1": round(macro_f1, 4),
        "legacy_test_accuracy": round(legacy_test_acc, 4) if legacy_test_acc is not None else None,
        "holdout_test_accuracy": round(holdout_test_acc, 4) if holdout_test_acc is not None else None,
        "generalisation_estimate_valid": (not split_meta.get("is_legacy_confounded", False)) and (holdout_test_acc is not None),
        "is_legacy_confounded": split_meta.get("is_legacy_confounded", False),
        "n_groups_per_class": split_meta.get("n_groups_per_class", {}),
        "classification_report": report,
        "confusion_matrix": cm,
        "class_names": class_names,
        "split_counts": {
            "train": len(train_recs),
            "val": len(val_recs),
            "test": len(test_recs),
        },
        "split_metadata": split_meta,
        "ripeness_metrics": ripeness_specifics,
        "timing": {
            "total_duration_seconds": total_duration,
            "stage1_seconds_per_epoch": s1_per_epoch,
            "stage2_seconds_per_epoch": s2_per_epoch,
        },
        "training_start": start_dt,
    }

    metrics_path = os.path.join(args.out_dir, "metrics.json")
    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(metrics_payload, f, indent=2)

    # 8. Automatically generate report into <out_dir>/report/
    update_progress("reporting", len(tracker_s1.records) + (len(tracker_s2.records) if tracker_s2 is not None else 0))
    try:
        from app.ml.report import generate_report
        generate_report(run_dir=args.out_dir)
    except Exception as e:
        print(f"[WARN] Failed to automatically generate report: {e}")

    update_progress("done", len(tracker_s1.records) + (len(tracker_s2.records) if tracker_s2 is not None else 0))

    return metrics_payload


def main():
    args = parse_args()
    train_pipeline(args)


if __name__ == "__main__":
    main()
