import io
import time
import pytest
from PIL import Image
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def create_test_image(size=(400, 400), color=(255, 220, 0)) -> bytes:
    img = Image.new("RGB", size, color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_predict_demo_mode_within_5_seconds():
    """Verify /predict returns 200 with full schema within 5 seconds in demo mode."""
    img_bytes = create_test_image()
    start_time = time.time()

    response = client.post(
        "/predict",
        files={"file": ("banana.jpg", img_bytes, "image/jpeg")},
        data={"variety": "cavendish", "language": "en"},
        headers={"X-Guest-Id": "test-guest-id-123"}
    )
    elapsed = time.time() - start_time

    assert response.status_code == 200, response.text
    assert elapsed < 5.0, f"Predict took {elapsed:.2f}s, exceeding 5s limit"

    data = response.json()
    assert data["mode"] == "demo"
    assert "scan_id" in data
    assert "condition" in data
    assert "id" in data["condition"]
    assert "type" in data["condition"]
    assert "en" in data["condition"]
    assert "si" in data["condition"]
    assert "images" in data
    assert "original_url" in data["images"]
    assert "gradcam_url" in data["images"]
    assert "disclaimer" in data


def test_cors_preflight_options():
    """Verify CORS preflight (OPTIONS) from http://localhost:6569 succeeds with required headers."""
    response = client.options(
        "/predict",
        headers={
            "Origin": "http://localhost:6569",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "Authorization, X-Guest-Id, Content-Type, Accept",
        }
    )

    assert response.status_code == 200
    allow_origin = response.headers.get("access-control-allow-origin")
    assert allow_origin == "http://localhost:6569"
    assert "access-control-allow-methods" in response.headers


def test_error_retains_cors_headers_and_standard_json():
    """Verify a client/server error retains CORS headers and standard JSON error format."""
    # Sending invalid/empty image to trigger 400 validation error
    response = client.post(
        "/predict",
        files={"file": ("corrupt.jpg", b"not-a-valid-image", "image/jpeg")},
        headers={
            "Origin": "http://localhost:6569",
            "X-Guest-Id": "test-guest-id",
        }
    )

    assert response.status_code == 400
    # Must retain CORS headers
    assert response.headers.get("access-control-allow-origin") == "http://localhost:6569"

    # Must follow standard JSON error schema
    data = response.json()
    assert "error" in data
    assert "code" in data["error"]
    assert "message_en" in data["error"]
    assert "message_si" in data["error"]
