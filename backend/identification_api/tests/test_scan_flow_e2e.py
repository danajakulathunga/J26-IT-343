import io
import json
import pytest
from PIL import Image
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_complete_scan_flow_end_to_end():
    """Integration Test:
    1. OPTIONS Preflight from Flutter Web origin
    2. Upload image and analyze (/predict)
    3. Verify full diagnostic results (condition, severity, predictions, recommendations)
    4. Fetch original and gradcam image bytes
    5. Fetch scan by ID (browser refresh / deep link)
    6. Fetch PDF diagnostic report
    """
    web_origin = "http://localhost:5000"
    guest_id = "integration-test-guest-uuid"

    # Step 1: CORS Preflight
    options_res = client.options(
        "/predict",
        headers={
            "Origin": web_origin,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "Authorization, X-Guest-Id, Content-Type, Accept",
        }
    )
    assert options_res.status_code == 200
    assert options_res.headers.get("access-control-allow-origin") == web_origin

    # Step 2: Pick / create synthetic banana image and Analyze
    img = Image.new("RGB", (300, 300), color=(255, 230, 0))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()

    predict_res = client.post(
        "/predict",
        files={"file": ("banana.jpg", img_bytes, "image/jpeg")},
        data={"variety": "cavendish", "language": "en"},
        headers={
            "Origin": web_origin,
            "X-Guest-Id": guest_id,
        }
    )

    assert predict_res.status_code == 200, predict_res.text
    assert predict_res.headers.get("access-control-allow-origin") == web_origin

    data = predict_res.json()
    scan_id = data["scan_id"]
    assert scan_id is not None
    assert data["condition"]["en"] != ""
    assert data["condition_confidence"] > 0.0
    assert "severity_index" in data
    assert len(data["top_predictions"]) > 0
    assert len(data["recommendations"]) > 0

    # Step 3: Fetch Original and Grad-CAM image bytes
    orig_url = data["images"]["original_url"]
    gradcam_url = data["images"]["gradcam_url"]

    orig_res = client.get(orig_url, headers={"Origin": web_origin, "X-Guest-Id": guest_id})
    assert orig_res.status_code == 200
    assert orig_res.headers.get("content-type") == "image/jpeg"
    assert len(orig_res.content) > 0

    gradcam_res = client.get(gradcam_url, headers={"Origin": web_origin, "X-Guest-Id": guest_id})
    assert gradcam_res.status_code == 200
    assert gradcam_res.headers.get("content-type") == "image/jpeg"
    assert len(gradcam_res.content) > 0

    # Step 4: Verify deep-link / browser reload via GET /scans/{scan_id}
    detail_res = client.get(f"/scans/{scan_id}", headers={"Origin": web_origin, "X-Guest-Id": guest_id})
    assert detail_res.status_code == 200
    detail_data = detail_res.json()
    assert detail_data["scan_id"] == scan_id
    assert detail_data["condition"]["id"] == data["condition"]["id"]

    # Step 5: Verify PDF Report Generation and Download
    report_res = client.get(f"/scans/{scan_id}/report", headers={"Origin": web_origin, "X-Guest-Id": guest_id})
    assert report_res.status_code == 200
    assert report_res.headers.get("content-type") == "application/pdf"
    assert len(report_res.content) > 100

    # Step 6: Verify Scan History list contains scan details and image URLs
    history_res = client.get("/scans", headers={"Origin": web_origin, "X-Guest-Id": guest_id})
    assert history_res.status_code == 200
    history_data = history_res.json()
    assert history_data["total"] >= 1
    assert len(history_data["items"]) >= 1
    matched = next((item for item in history_data["items"] if item["scan_id"] == scan_id), None)
    assert matched is not None
    assert matched["images"]["original_url"] == orig_url
    assert matched["condition"]["en"] != ""
