import abc
import hashlib
import os
import random
from functools import lru_cache
from typing import Dict, List
import numpy as np
from PIL import Image
from app.core.config import settings
from app.core.logging import logger
from app.services.preprocessing import preprocess_image


def softmax(x: np.ndarray) -> np.ndarray:
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum(axis=-1, keepdims=True)

# The trained model uses this order. The adapter expands these seven classes
# into the backend's existing 17-class condition vector.
REAL_MODEL_CONDITION_IDS = (
    "black_spots",
    "bruising",
    "finger_rot",
    "healthy",
    "physical_damage",
    "scarring",
    "skin_splitting",
)
REAL_MODEL_SEVERITY_COUNT = 4  # Mild, Moderate, Severe, NA/None
BACKEND_CONDITION_INDEX = {
    "healthy": 0,
    "finger_rot": 3,
    "bruising": 7,
    "physical_damage": 8,
    "black_spots": 9,
    "scarring": 10,
    "skin_splitting": 11,
}


class BasePredictor(abc.ABC):
    @abc.abstractmethod
    def predict(self, image_rgb: Image.Image, raw_bytes: bytes) -> Dict[str, List[float]]:
        """Run prediction on input image.
        Returns:
            {
               "condition_probs": [float] * 17,
               "severity_probs": [float] * 4
            }
        """
        pass


class DemoPredictor(BasePredictor):
    """Deterministic Demo Predictor.
    Seeds pseudorandom generator from SHA-256 of image bytes so identical image
    always gives the exact same condition and severity.
    """
    def predict(self, image_rgb: Image.Image, raw_bytes: bytes) -> Dict[str, List[float]]:
        # SHA-256 hash
        sha256_hash = hashlib.sha256(raw_bytes).hexdigest()
        seed_int = int(sha256_hash[:8], 16)
        rng = random.Random(seed_int)

        # 17 conditions: 0: healthy, 1..6: disease, 7..16: defect
        # Pick dominant condition deterministically
        dominant_idx = rng.randint(0, 16)

        # Generate logits
        logits = [rng.uniform(0.1, 1.2) for _ in range(17)]
        # Boost dominant condition for realistic high-confidence prediction
        logits[dominant_idx] += rng.uniform(3.5, 6.0)

        # Softmax
        exp_logits = np.exp(np.array(logits) - np.max(logits))
        condition_probs = (exp_logits / np.sum(exp_logits)).tolist()

        # Severity logits (Mild, Moderate, Severe)
        if dominant_idx == 0:
            # Healthy: severity unused
            severity_probs = [0.3333, 0.3333, 0.3334]
        else:
            sev_logits = [rng.uniform(0.2, 1.0) for _ in range(3)]
            dominant_sev = rng.randint(0, 2)
            sev_logits[dominant_sev] += rng.uniform(2.0, 4.0)
            exp_sev = np.exp(np.array(sev_logits) - np.max(sev_logits))
            severity_probs = (exp_sev / np.sum(exp_sev)).tolist()

        return {
            "condition_probs": [round(float(p), 4) for p in condition_probs],
            "severity_probs": [round(float(p), 4) for p in severity_probs]
        }


class KerasPredictor(BasePredictor):
    """Real Model Predictor using TensorFlow/Keras 3."""
    def __init__(self, model_path: str):
        self.model_path = model_path
        self._model = None
        self._load_model()

    def _load_model(self):
        import tensorflow as tf
        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"Keras model not found at {self.model_path}")
        logger.info(f"Loading trained Keras model from {self.model_path}...")
        self._model = tf.keras.models.load_model(self.model_path)
        output_shapes = self._model.output_shape
        if not isinstance(output_shapes, (list, tuple)) or len(output_shapes) != 2:
            raise ValueError(
                "Expected a two-head Keras model with condition and severity outputs"
            )
        condition_shape, severity_shape = output_shapes
        if condition_shape[-1] != len(REAL_MODEL_CONDITION_IDS):
            raise ValueError(
                f"Expected {len(REAL_MODEL_CONDITION_IDS)} condition outputs, "
                f"got {condition_shape[-1]}"
            )
        if severity_shape[-1] != REAL_MODEL_SEVERITY_COUNT:
            raise ValueError(
                f"Expected {REAL_MODEL_SEVERITY_COUNT} severity outputs, "
                f"got {severity_shape[-1]}"
            )
        logger.info("Model loaded successfully.")

    @property
    def model(self):
        if self._model is None and os.path.exists(self.model_path):
            self._load_model()
        return self._model

    def model_condition_index(self, condition_id: str) -> int:
        try:
            return REAL_MODEL_CONDITION_IDS.index(condition_id)
        except ValueError as exc:
            raise ValueError(
                f"Condition '{condition_id}' is not represented by the real model"
            ) from exc

    def predict(self, image_rgb: Image.Image, raw_bytes: bytes) -> Dict[str, List[float]]:
        if self.model is None:
            raise RuntimeError("Real Keras model is unavailable")

        preprocessed = preprocess_image(image_rgb, model=self.model)
        preds = self.model.predict(preprocessed, verbose=0)

        # The multi-head model returns a list [condition_preds, severity_preds]
        # or a dict keyed by the output layer names.
        if isinstance(preds, dict):
            condition_key = next(
                (key for key in ("condition", "condition_output") if key in preds),
                None,
            )
            severity_key = next(
                (key for key in ("severity", "severity_output") if key in preds),
                None,
            )
            if condition_key is None or severity_key is None:
                raise ValueError(
                    f"Unexpected model output keys: {sorted(preds.keys())}"
                )
            cond_p = preds[condition_key][0]
            sev_p = preds[severity_key][0]
        elif isinstance(preds, (list, tuple)) and len(preds) == 2:
            cond_p = preds[0][0]
            sev_p = preds[1][0]
        else:
            raise ValueError("Unexpected model prediction output format")

        if len(cond_p) != len(REAL_MODEL_CONDITION_IDS):
            raise ValueError(
                f"Expected {len(REAL_MODEL_CONDITION_IDS)} condition probabilities, "
                f"got {len(cond_p)}"
            )
        if len(sev_p) != REAL_MODEL_SEVERITY_COUNT:
            raise ValueError(
                f"Expected {REAL_MODEL_SEVERITY_COUNT} severity probabilities, "
                f"got {len(sev_p)}"
            )

        backend_condition_probs = [0.0] * 17
        for model_index, condition_id in enumerate(REAL_MODEL_CONDITION_IDS):
            backend_index = BACKEND_CONDITION_INDEX[condition_id]
            backend_condition_probs[backend_index] = float(cond_p[model_index])

        return {
            "condition_probs": [round(p, 4) for p in backend_condition_probs],
            "severity_probs": [round(float(p), 4) for p in sev_p.tolist()]
        }


@lru_cache(maxsize=2)
def get_inference_predictor() -> BasePredictor:
    mode = settings.MODEL_MODE.lower().strip()
    if mode == "real":
        return KerasPredictor(settings.MODEL_PATH)
    return DemoPredictor()
