import pytest
from app.services.severity import calculate_severity, WEIGHTS


def test_severity_calculation_example():
    """Verify weighted severity index formula: [0.10, 0.70, 0.20] -> 54.0.
    Calculation: 0.10 * 20 + 0.70 * 50 + 0.20 * 85 = 2.0 + 35.0 + 17.0 = 54.0.
    """
    probs = [0.10, 0.70, 0.20]
    sev_output, conf, index = calculate_severity("anthracnose", probs)

    assert sev_output is not None
    assert sev_output.level == "Moderate"
    assert sev_output.en == "Moderate"
    assert sev_output.si == "මධ්යස්ථ"
    assert conf == 0.70
    assert index == 54.0


def test_severity_healthy_has_no_severity():
    """For healthy bananas, severity must be None, confidence None, and index 0.0."""
    sev_output, conf, index = calculate_severity("healthy", [0.33, 0.33, 0.34])
    assert sev_output is None
    assert conf is None
    assert index == 0.0


def test_severity_pure_mild():
    probs = [1.0, 0.0, 0.0]
    sev_output, conf, index = calculate_severity("bruising", probs)
    assert sev_output.level == "Mild"
    assert sev_output.en == "Mild"
    assert sev_output.si == "සුළු"
    assert conf == 1.0
    assert index == 20.0


def test_severity_pure_severe():
    probs = [0.0, 0.0, 1.0]
    sev_output, conf, index = calculate_severity("bacterial_soft_rot", probs)
    assert sev_output.level == "Severe"
    assert sev_output.en == "Severe"
    assert sev_output.si == "දැඩි"
    assert conf == 1.0
    assert index == 85.0
