from typing import Dict, List, Optional, Tuple
from app.schemas.scan import SeverityOutput

SEVERITY_LEVELS = [
    {"level": "Mild", "en": "Mild", "si": "සුළු", "ta": "லேசான", "weight": 20.0},
    {"level": "Moderate", "en": "Moderate", "si": "මධ්යස්ථ", "ta": "மிதமான", "weight": 50.0},
    {"level": "Severe", "en": "Severe", "si": "දැඩි", "ta": "கடுமையான", "weight": 85.0},
]

WEIGHTS = [item["weight"] for item in SEVERITY_LEVELS]
NA_SEVERITY_INDEX = 3


def calculate_severity(
    condition_id: str,
    severity_probs: Optional[List[float]]
) -> Tuple[Optional[SeverityOutput], Optional[float], float]:
    """Calculate severity output, severity confidence, and weighted severity index.
    If condition is 'healthy', severity is None, severity_confidence is None, severity_index is 0.0.
    Otherwise:
      - severity level is argmax(severity_probs)
      - severity_confidence is max(severity_probs)
      - severity_index = round(sum(prob * weight), 1)
    """
    if condition_id == "healthy" or not severity_probs:
        return None, None, 0.0

    # The real model has an additional NA/None class for healthy samples.
    if len(severity_probs) not in (3, 4):
        raise ValueError(f"Expected 3 or 4 severity probabilities, got {len(severity_probs)}")

    # Normalize if necessary
    total = sum(severity_probs)
    if total > 0:
        norm_probs = [p / total for p in severity_probs]
    else:
        norm_probs = [1 / 3, 1 / 3, 1 / 3]

    max_idx = int(max(range(len(norm_probs)), key=lambda i: norm_probs[i]))
    if max_idx == NA_SEVERITY_INDEX:
        return None, None, 0.0
    chosen_meta = SEVERITY_LEVELS[max_idx]

    severity_output = SeverityOutput(
        level=chosen_meta["level"],
        en=chosen_meta["en"],
        si=chosen_meta["si"],
        ta=chosen_meta["ta"]
    )
    confidence = round(float(norm_probs[max_idx]), 4)
    severity_index = round(sum(p * w for p, w in zip(norm_probs, WEIGHTS)), 1)
    # Clamp to [0, 100]
    severity_index = max(0.0, min(100.0, severity_index))

    return severity_output, confidence, severity_index
