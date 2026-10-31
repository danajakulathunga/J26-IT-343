import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def create_test_image_bytes(color=(255, 230, 0), size=(400, 400)) -> bytes:
    """Generate a clean synthetic test image in memory."""
    img = Image.new("RGB", size, color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_predict_demo_mode_full_schema():
    img_bytes = create_test_image_bytes()
    guest_uuid = "123e4567-e89b-12d3-a456-426614174000"

    response = client.post(
        "/predict",
        files={"file": ("test_banana.jpg", img_bytes, "image/jpeg")},
        data={"variety": "ambul", "language": "en"},
        headers={"X-Guest-Id": guest_uuid}
    )

    assert response.status_code == 200, response.text
    data = response.json()

    # 1. Assert Demo Mode flag
    assert data["mode"] == "demo"

    # 2. Assert Full Schema elements
    assert "scan_id" in data
    assert "created_at" in data
    assert "condition" in data
    assert "id" in data["condition"]
    assert "type" in data["condition"]
    assert "en" in data["condition"]
    assert "si" in data["condition"]

    assert "condition_confidence" in data
    assert isinstance(data["condition_confidence"], float)

    assert "severity_index" in data
    assert "top_predictions" in data
    assert len(data["top_predictions"]) <= 3

    assert "cause_factors" in data
    assert len(data["cause_factors"]) == 3
    assert "recommendations" in data
    assert len(data["recommendations"]) == 3

    assert "images" in data
    assert "original_url" in data["images"]
    assert "gradcam_url" in data["images"]

    assert "disclaimer" in data
    assert "en" in data["disclaimer"]
    assert "si" in data["disclaimer"]

    # Variety check
    assert data["variety"] is not None
    assert data["variety"]["id"] == "ambul"


def test_predict_demo_deterministic():
    """Ensure identical image bytes produce identical demo predictions."""
    img_bytes = create_test_image_bytes(color=(200, 180, 50))
    guest_uuid = "guest-deterministic-test"

    res1 = client.post(
        "/predict",
        files={"file": ("banana1.jpg", img_bytes, "image/jpeg")},
        headers={"X-Guest-Id": guest_uuid}
    )
    res2 = client.post(
        "/predict",
        files={"file": ("banana1.jpg", img_bytes, "image/jpeg")},
        headers={"X-Guest-Id": guest_uuid}
    )

    assert res1.status_code == 200
    assert res2.status_code == 200

    d1 = res1.json()
    d2 = res2.json()

    # Predictions must match deterministically
    assert d1["condition"]["id"] == d2["condition"]["id"]
    assert d1["condition_confidence"] == d2["condition_confidence"]
    assert d1["severity_index"] == d2["severity_index"]
