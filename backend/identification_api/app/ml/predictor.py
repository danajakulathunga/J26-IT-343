"""
Fruit Variety Predictor with multi-model support, LRU cache, and thread-safe hot-reloading.
"""

from collections import OrderedDict
import json
import os
import threading
from typing import Any, Optional

import cv2
import numpy as np
import tensorflow as tf

from app.ml.preprocessing import (
    load_image_from_bytes,
    process_bgr_image,
    to_mobilenet_input,
)
from app.ml.background_removal import remove_background
from app.ml.registry import resolve_version

MODEL_DIR = os.path.join(os.path.dirname(__file__), "model")
MODEL_PATH = os.path.join(MODEL_DIR, "variety_classifier.keras")
CLASS_NAMES_PATH = os.path.join(MODEL_DIR, "class_names.txt")
CONFIG_PATH = os.path.join(MODEL_DIR, "model_config.json")

RIPENESS_MODEL_DIR = os.path.join(os.path.dirname(__file__), "ripeness_model")
RIPENESS_MODEL_PATH = os.path.join(RIPENESS_MODEL_DIR, "ripeness_classifier.keras")
RIPENESS_CLASSES_PATH = os.path.join(RIPENESS_MODEL_DIR, "class_names.txt")
RIPENESS_CONFIG_PATH = os.path.join(RIPENESS_MODEL_DIR, "model_config.json")

# Active variety model reference (hot-reloaded)
_model = None
_class_names = []
_active_config = {"architecture": "mobilenetv2", "image_size": [224, 224]}
_model_lock = threading.Lock()

# Active ripeness model reference (hot-reloaded)
_ripeness_model = None
_ripeness_classes = []
_ripeness_config = {"architecture": "mobilenetv2", "image_size": [300, 300]}
_ripeness_lock = threading.Lock()

# LRU Cache for non-active models (at most MODEL_CACHE_SIZE extra models)
_extra_models_cache: OrderedDict[str, dict[str, Any]] = OrderedDict()
_cache_lock = threading.Lock()

_extra_ripeness_cache: OrderedDict[str, dict[str, Any]] = OrderedDict()
_ripeness_cache_lock = threading.Lock()


def get_cache_size_limit() -> int:
    try:
        return max(1, int(os.environ.get("MODEL_CACHE_SIZE", 3)))
    except Exception:
        return 3


def get_current_cached_version_ids() -> list[str]:
    """Returns list of currently cached non-active model version IDs."""
    with _cache_lock:
        return list(_extra_models_cache.keys())


def _resolve_paths():
    model_p = MODEL_PATH
    if not os.path.exists(model_p):
        fallback = os.path.join(os.path.dirname(__file__), "..", "..", "model", "variety_classifier.keras")
        if os.path.exists(fallback):
            model_p = fallback

    class_p = CLASS_NAMES_PATH
    if not os.path.exists(class_p):
        fallback = os.path.join(os.path.dirname(__file__), "..", "..", "model", "class_names.txt")
        if os.path.exists(fallback):
            class_p = fallback

    config_p = CONFIG_PATH
    if not os.path.exists(config_p):
        fallback = os.path.join(os.path.dirname(__file__), "..", "..", "model", "model_config.json")
        if os.path.exists(fallback):
            config_p = fallback

    return model_p, class_p, config_p


def _parse_size(size_val: Any) -> tuple[int, int]:
    if isinstance(size_val, (list, tuple)) and len(size_val) == 2:
        return (int(size_val[0]), int(size_val[1]))
    if isinstance(size_val, (int, float)):
        return (int(size_val), int(size_val))
    return (224, 224)


def load_model_and_classes():
    """
    Loads active model and class names in file order.
    """
    global _model, _class_names, _active_config
    with _model_lock:
        if _model is not None and _class_names:
            return _model, _class_names, _active_config

        model_path, class_names_path, config_path = _resolve_paths()
        if not os.path.exists(model_path):
            raise FileNotFoundError(
                f"Model file variety_classifier.keras not found. Please train or provide the model."
            )
        if not os.path.exists(class_names_path):
            raise FileNotFoundError(
                f"Class names file class_names.txt not found at {class_names_path}."
            )

        _model = tf.keras.models.load_model(model_path)
        with open(class_names_path, "r", encoding="utf-8") as f:
            _class_names = [line.strip() for line in f if line.strip()]

        _active_config = {"architecture": "mobilenetv2", "image_size": [224, 224]}
        if os.path.exists(config_path):
            try:
                with open(config_path, "r", encoding="utf-8") as f:
                    _active_config = json.load(f)
            except Exception:
                pass

        return _model, _class_names, _active_config


def reload():
    """
    Safely reloads the active model and class names.
    If loading fails, keeps the existing active model.
    """
    global _model, _class_names, _active_config
    model_path, class_names_path, config_path = _resolve_paths()

    if not os.path.exists(model_path) or not os.path.exists(class_names_path):
        raise FileNotFoundError("Cannot reload: active model or class_names.txt does not exist.")

    new_model = tf.keras.models.load_model(model_path)
    with open(class_names_path, "r", encoding="utf-8") as f:
        new_classes = [line.strip() for line in f if line.strip()]

    new_config = {"architecture": "mobilenetv2", "image_size": [224, 224]}
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                new_config = json.load(f)
        except Exception:
            pass

    with _model_lock:
        _model = new_model
        _class_names = new_classes
        _active_config = new_config
        print(f"Successfully reloaded active model: {len(_class_names)} classes.")


# Eagerly load active model on startup if available
try:
    load_model_and_classes()
except Exception:
    pass


def _resolve_ripeness_paths():
    model_p = RIPENESS_MODEL_PATH
    if not os.path.exists(model_p):
        fallback = os.path.join(RIPENESS_MODEL_DIR, "model.keras")
        if os.path.exists(fallback):
            model_p = fallback

    class_p = RIPENESS_CLASSES_PATH
    config_p = RIPENESS_CONFIG_PATH
    return model_p, class_p, config_p


def load_ripeness_model_and_classes():
    global _ripeness_model, _ripeness_classes, _ripeness_config
    with _ripeness_lock:
        if _ripeness_model is not None and _ripeness_classes:
            return _ripeness_model, _ripeness_classes, _ripeness_config

        model_path, class_names_path, config_path = _resolve_ripeness_paths()
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Active ripeness model not found at {model_path}.")
        if not os.path.exists(class_names_path):
            raise FileNotFoundError(f"Ripeness class names file not found at {class_names_path}.")

        _ripeness_model = tf.keras.models.load_model(model_path)
        with open(class_names_path, "r", encoding="utf-8") as f:
            _ripeness_classes = [l.strip() for l in f if l.strip()]

        _ripeness_config = {"architecture": "mobilenetv2", "image_size": [300, 300]}
        if os.path.exists(config_path):
            try:
                with open(config_path, "r", encoding="utf-8") as f:
                    _ripeness_config = json.load(f)
            except Exception:
                pass

        return _ripeness_model, _ripeness_classes, _ripeness_config


def reload_ripeness():
    global _ripeness_model, _ripeness_classes, _ripeness_config
    model_path, class_names_path, config_path = _resolve_ripeness_paths()
    if not os.path.exists(model_path) or not os.path.exists(class_names_path):
        raise FileNotFoundError("Cannot reload: active ripeness model or class_names.txt does not exist.")

    new_model = tf.keras.models.load_model(model_path)
    with open(class_names_path, "r", encoding="utf-8") as f:
        new_classes = [l.strip() for l in f if l.strip()]

    new_config = {"architecture": "mobilenetv2", "image_size": [300, 300]}
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                new_config = json.load(f)
        except Exception:
            pass

    with _ripeness_lock:
        _ripeness_model = new_model
        _ripeness_classes = new_classes
        _ripeness_config = new_config
        print(f"Successfully reloaded active ripeness model: {len(_ripeness_classes)} classes.")


try:
    load_ripeness_model_and_classes()
except Exception:
    pass


def get_ripeness_version_model(version_id: str) -> dict[str, Any]:
    with _ripeness_cache_lock:
        if version_id in _extra_ripeness_cache:
            _extra_ripeness_cache.move_to_end(version_id)
            return _extra_ripeness_cache[version_id]

    ok, v_meta, err = resolve_version(version_id, include_experiments=True, task="ripeness")
    if not ok or not v_meta:
        raise ValueError(f"Cannot resolve ripeness model version '{version_id}': {err}")

    v_dir = v_meta["version_dir"]
    keras_path = v_meta.get("model_path") or os.path.join(v_dir, "model.keras")
    classes_path = os.path.join(v_dir, "class_names.txt")
    config_path = os.path.join(v_dir, "model_config.json")

    if not os.path.exists(keras_path):
        raise FileNotFoundError(f"Model file model.keras missing for ripeness version '{version_id}'.")
    if not os.path.exists(classes_path):
        raise FileNotFoundError(f"Class names file class_names.txt missing for ripeness version '{version_id}'.")

    new_model = tf.keras.models.load_model(keras_path)
    with open(classes_path, "r", encoding="utf-8") as f:
        class_names = [line.strip() for line in f if line.strip()]

    config = {"architecture": "mobilenetv2", "image_size": [300, 300]}
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                config = json.load(f)
        except Exception:
            pass

    cached_entry = {
        "model": new_model,
        "class_names": class_names,
        "config": config,
        "version_id": version_id,
        "meta": v_meta,
    }

    limit = get_cache_size_limit()
    with _ripeness_cache_lock:
        if version_id in _extra_ripeness_cache:
            _extra_ripeness_cache.move_to_end(version_id)
            return _extra_ripeness_cache[version_id]

        while len(_extra_ripeness_cache) >= limit:
            evicted_id, _ = _extra_ripeness_cache.popitem(last=False)
            print(f"[CACHE] Evicted least recently used ripeness model version: '{evicted_id}'")

        _extra_ripeness_cache[version_id] = cached_entry

    return cached_entry


def get_version_model(version_id: str) -> dict[str, Any]:
    """
    Retrieves or loads a non-active version model using an LRU cache.
    Evicts the least recently used model when exceeding MODEL_CACHE_SIZE.
    """
    ok, v_meta, err = resolve_version(version_id, include_experiments=True)
    if not ok or not v_meta:
        raise ValueError(err)

    if not v_meta.get("available") or not v_meta.get("model_path"):
        raise ValueError(f"Version '{version_id}' weights (.keras) are not available.")

    model_path = v_meta["model_path"]
    version_dir = v_meta["version_dir"]

    with _cache_lock:
        if version_id in _extra_models_cache:
            _extra_models_cache.move_to_end(version_id)
            return _extra_models_cache[version_id]

    # Load outside lock to prevent blocking
    new_model = tf.keras.models.load_model(model_path)

    # Class names
    classes_path = os.path.join(version_dir, "class_names.txt")
    class_names = v_meta.get("class_names") or []
    if os.path.exists(classes_path):
        try:
            with open(classes_path, "r", encoding="utf-8") as f:
                class_names = [line.strip() for line in f if line.strip()]
        except Exception:
            pass

    if not class_names:
        # Fallback to active classes if missing
        _, active_classes, _ = load_model_and_classes()
        class_names = active_classes

    # Config
    config_path = os.path.join(version_dir, "model_config.json")
    config = {"architecture": v_meta.get("architecture", "mobilenetv2"), "image_size": v_meta.get("image_size", [224, 224])}
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                config.update(json.load(f))
        except Exception:
            pass

    cached_entry = {
        "model": new_model,
        "class_names": class_names,
        "config": config,
        "version_id": version_id,
        "meta": v_meta,
    }

    limit = get_cache_size_limit()
    with _cache_lock:
        if version_id in _extra_models_cache:
            _extra_models_cache.move_to_end(version_id)
            return _extra_models_cache[version_id]

        while len(_extra_models_cache) >= limit:
            evicted_id, _ = _extra_models_cache.popitem(last=False)
            print(f"[CACHE] Evicted least recently used model version: '{evicted_id}'")

        _extra_models_cache[version_id] = cached_entry

    return cached_entry


def parse_class_name(raw_name: str) -> tuple[str, str]:
    """
    Splits each class name on the first "_" into variety and fruit.
    E.g. "Kolikuttu_Banana" -> variety="Kolikuttu", fruit="Banana".
    """
    parts = raw_name.split("_", 1)
    if len(parts) == 2:
        return parts[0], parts[1]
    return raw_name, "Banana"


def prepare_input_tensor(
    image_source: Any,
    config: dict[str, Any],
    already_processed: bool = False,
    remove_bg: Optional[bool] = None,
) -> np.ndarray:
    """
    Standard loader & preprocessor for model inference.
    Shared by predictor and promotion evaluator to guarantee identical behavior.
    - If already_processed is True (e.g. dataset processed files), decodes RGB and resizes
      without repeating CLAHE or denoising.
    - If already_processed is False (e.g. raw user upload), runs process_bgr_image.
    - Formats to model architecture: raw [0, 255] for EfficientNet, mobilenet_v2.preprocess_input for MobileNet.
    Returns batched array of shape (1, H, W, 3).
    """
    arch = config.get("architecture", "mobilenetv2")
    img_size = _parse_size(config.get("image_size", (224, 224)))
    prep_mode = config.get("preprocessing")
    is_effnet = prep_mode == "raw_0_255" or "efficientnet" in arch.lower()

    if already_processed:
        if isinstance(image_source, str):
            img_bytes = tf.io.read_file(image_source)
            img = tf.image.decode_jpeg(img_bytes, channels=3)
            img = tf.image.resize(img, img_size)
            if not is_effnet:
                img = tf.keras.applications.mobilenet_v2.preprocess_input(img)
            return tf.expand_dims(img, 0).numpy()
        elif isinstance(image_source, bytes):
            img = tf.image.decode_jpeg(image_source, channels=3)
            img = tf.image.resize(img, img_size)
            if not is_effnet:
                img = tf.keras.applications.mobilenet_v2.preprocess_input(img)
            return tf.expand_dims(img, 0).numpy()
        else:
            # Already processed numpy BGR array (e.g. flipped BGR in TTA)
            proc_bgr = image_source
    else:
        if isinstance(image_source, bytes):
            bgr = load_image_from_bytes(image_source)
        else:
            bgr = image_source
        bgr = remove_background(bgr, enabled=remove_bg)
        proc_bgr = process_bgr_image(bgr, target_size=img_size)

    if is_effnet:
        rgb = cv2.cvtColor(proc_bgr, cv2.COLOR_BGR2RGB)
        return np.expand_dims(rgb, axis=0).astype(np.float32)
    else:
        return to_mobilenet_input(proc_bgr)


def _predict_on_bgr(
    bgr_img: np.ndarray,
    model: Any,
    class_names: list[str],
    config: dict[str, Any],
    version_label: str,
    tta: bool = False,
    is_ripeness: bool = False,
    remove_bg: Optional[bool] = None,
) -> dict[str, Any]:
    arch = config.get("architecture", "mobilenetv2")
    img_size = _parse_size(config.get("image_size", (224, 224)))

    batch = prepare_input_tensor(bgr_img, config, already_processed=False, remove_bg=remove_bg)
    predictions = model.predict(batch, verbose=0)[0]

    if tta:
        bg_bgr = remove_background(bgr_img, enabled=remove_bg)
        processed_bgr = process_bgr_image(bg_bgr, target_size=img_size)
        flipped_bgr = cv2.flip(processed_bgr, 1)
        batch_f = prepare_input_tensor(flipped_bgr, config, already_processed=True)
        preds_f = model.predict(batch_f, verbose=0)[0]
        predictions = (predictions + preds_f) / 2.0

    top_idx = int(np.argmax(predictions))
    top_confidence = float(predictions[top_idx])

    if is_ripeness:
        stage = class_names[top_idx] if top_idx < len(class_names) else "Unknown"
        stages_list = []
        for i, cname in enumerate(class_names):
            prob = float(predictions[i]) if i < len(predictions) else 0.0
            stages_list.append({
                "stage": cname,
                "confidence": round(prob, 4),
            })
        top3 = sorted(stages_list, key=lambda x: x["confidence"], reverse=True)[:3]
        return {
            "stage": stage,
            "confidence": round(top_confidence, 4),
            "model_version": version_label,
            "image_size": [img_size[0], img_size[1]],
            "architecture": arch,
            "top3": top3,
            "stages": stages_list,
            "low_confidence": top_confidence < 0.60,
        }
    else:
        raw_class = class_names[top_idx] if top_idx < len(class_names) else "Unknown_Banana"
        variety, fruit = parse_class_name(raw_class)

        # Top-3 predictions
        sorted_indices = np.argsort(predictions)[::-1]
        top3 = []
        for idx in sorted_indices[:3]:
            cname = class_names[idx] if idx < len(class_names) else f"Class_{idx}"
            v_sub, f_sub = parse_class_name(cname)
            top3.append({
                "variety": v_sub,
                "fruit_type": f_sub,
                "raw_class": cname,
                "confidence": round(float(predictions[idx]), 4),
            })

        return {
            "fruit_type": fruit,
            "variety": variety,
            "confidence": round(top_confidence, 4),
            "model_version": version_label,
            "image_size": [img_size[0], img_size[1]],
            "architecture": arch,
            "top3": top3,
            "low_confidence": top_confidence < 0.60,
        }


def predict_variety(
    image_bytes: bytes,
    version: Optional[str] = None,
    tta: bool = False,
    remove_bg: Optional[bool] = None,
) -> dict[str, Any]:
    """
    Predicts fruit variety using the specified model version.
    If version is None or 'active', uses the active model hot-reloaded in memory.
    Otherwise, loads the requested version via LRU cache.
    """
    # 1. Decode raw image bytes ONCE
    bgr_img = load_image_from_bytes(image_bytes)

    # 2. Resolve model
    if not version or version == "active":
        model, class_names, config = load_model_and_classes()
        version_label = "active"
        with _model_lock:
            return _predict_on_bgr(bgr_img, model, class_names, config, version_label, tta=tta, is_ripeness=False, remove_bg=remove_bg)
    else:
        entry = get_version_model(version)
        return _predict_on_bgr(
            bgr_img,
            entry["model"],
            entry["class_names"],
            entry["config"],
            version_label=entry["version_id"],
            tta=tta,
            is_ripeness=False,
            remove_bg=remove_bg,
        )


def predict_ripeness(
    image_bytes: bytes,
    version: Optional[str] = None,
    tta: bool = False,
    remove_bg: Optional[bool] = None,
) -> Optional[dict[str, Any]]:
    """
    Predicts fruit ripeness stage using the specified model version.
    Returns None if active ripeness model is not found and version is None.
    """
    bgr_img = load_image_from_bytes(image_bytes)

    if not version or version == "active":
        try:
            model, class_names, config = load_ripeness_model_and_classes()
        except FileNotFoundError:
            return None
        with _ripeness_lock:
            return _predict_on_bgr(bgr_img, model, class_names, config, "active", tta=tta, is_ripeness=True, remove_bg=remove_bg)
    else:
        entry = get_ripeness_version_model(version)
        return _predict_on_bgr(
            bgr_img,
            entry["model"],
            entry["class_names"],
            entry["config"],
            version_label=entry["version_id"],
            tta=tta,
            is_ripeness=True,
            remove_bg=remove_bg,
        )


def predict_all(
    image_bytes: bytes,
    variety_version: Optional[str] = None,
    ripeness_version: Optional[str] = None,
    tta: bool = False,
    remove_bg: Optional[bool] = None,
) -> dict[str, Any]:
    """
    Decodes image ONCE and runs variety and ripeness models on the shared decoded image.
    If no ripeness model exists, returns ripeness=None without error.
    """
    bgr_img = load_image_from_bytes(image_bytes)

    # Variety prediction
    if not variety_version or variety_version == "active":
        v_model, v_classes, v_cfg = load_model_and_classes()
        with _model_lock:
            variety_res = _predict_on_bgr(bgr_img, v_model, v_classes, v_cfg, "active", tta=tta, is_ripeness=False, remove_bg=remove_bg)
    else:
        v_entry = get_version_model(variety_version)
        variety_res = _predict_on_bgr(
            bgr_img,
            v_entry["model"],
            v_entry["class_names"],
            v_entry["config"],
            version_label=v_entry["version_id"],
            tta=tta,
            is_ripeness=False,
            remove_bg=remove_bg,
        )

    # Ripeness prediction
    ripeness_res = None
    try:
        if not ripeness_version or ripeness_version == "active":
            r_model, r_classes, r_cfg = load_ripeness_model_and_classes()
            with _ripeness_lock:
                ripeness_res = _predict_on_bgr(bgr_img, r_model, r_classes, r_cfg, "active", tta=tta, is_ripeness=True, remove_bg=remove_bg)
        else:
            r_entry = get_ripeness_version_model(ripeness_version)
            ripeness_res = _predict_on_bgr(
                bgr_img,
                r_entry["model"],
                r_entry["class_names"],
                r_entry["config"],
                version_label=r_entry["version_id"],
                tta=tta,
                is_ripeness=True,
                remove_bg=remove_bg,
            )
    except FileNotFoundError:
        ripeness_res = None
    except Exception as e:
        print(f"Warning: Ripeness prediction failed: {e}")
        ripeness_res = None

    notes = []
    if variety_res and variety_res.get("low_confidence"):
        notes.append("Low confidence in variety prediction.")
    if ripeness_res and ripeness_res.get("low_confidence"):
        notes.append("Low confidence in ripeness prediction.")
    if ripeness_res is None:
        notes.append("Ripeness model not available.")

    model_versions = {
        "variety": variety_res.get("model_version") if variety_res else None,
        "ripeness": ripeness_res.get("model_version") if ripeness_res else None,
    }
    img_size = variety_res.get("image_size", [300, 300]) if variety_res else [300, 300]

    return {
        "variety": variety_res,
        "ripeness": ripeness_res,
        "model_versions": model_versions,
        "image_size": img_size,
        "notes": notes,
    }


def compare(image_bytes: bytes, versions: list[str], remove_bg: Optional[bool] = None) -> dict[str, Any]:
    """
    Runs the same image through up to 4 model versions in a SINGLE decode.
    Returns per-version prediction results.
    """
    if not versions:
        raise ValueError("At least one model version must be specified for comparison.")
    if len(versions) > 4:
        raise ValueError(f"A maximum of 4 model versions can be compared simultaneously (requested {len(versions)}).")

    # Decode upload ONCE
    bgr_img = load_image_from_bytes(image_bytes)

    results: dict[str, Any] = {}
    for v_id in versions:
        v_id_clean = v_id.strip()
        if not v_id_clean:
            continue
        try:
            if v_id_clean == "active":
                model, class_names, config = load_model_and_classes()
                with _model_lock:
                    res = _predict_on_bgr(bgr_img, model, class_names, config, "active", remove_bg=remove_bg)
            else:
                entry = get_version_model(v_id_clean)
                res = _predict_on_bgr(bgr_img, entry["model"], entry["class_names"], entry["config"], entry["version_id"], remove_bg=remove_bg)
            results[v_id_clean] = res
        except Exception as e:
            results[v_id_clean] = {"error": str(e), "success": False}

    return {"results": results, "total_compared": len(results)}
