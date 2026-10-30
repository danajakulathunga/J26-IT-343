import io
import os
import json
import pytest
from fastapi import HTTPException, UploadFile
from PIL import Image

from app.routers.dataset import (
    verify_admin_key,
    upload_images,
    update_labels_batch,
    get_unlabeled,
    get_dataset_image,
    LabelUpdateItem,
)
from app.routers.predict import analyze_fruit, predict_fruit
from app.routers.training import trigger_training, training_status, rollback_model, RollbackRequest
from app.routers.models import get_models

TEST_API_KEY = "test_admin_key_phase_d"


@pytest.fixture(autouse=True)
def setup_api_key(monkeypatch):
    monkeypatch.setenv("ADMIN_API_KEY", TEST_API_KEY)


import uuid
from PIL import Image, ImageDraw


def _make_dummy_jpeg(tag: str = None) -> bytes:
    if tag is None:
        tag = str(uuid.uuid4())
    img = Image.new("RGB", (120, 120), color=(100, 150, 200))
    d = ImageDraw.Draw(img)
    d.text((10, 10), tag, fill=(255, 255, 255))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


@pytest.mark.anyio
async def test_analyze_endpoint():
    jpeg_bytes = _make_dummy_jpeg()
    upload = UploadFile(filename="test_analyze.jpg", file=io.BytesIO(jpeg_bytes))

    data = await analyze_fruit(file=upload)
    assert "variety" in data
    assert "ripeness" in data
    assert "model_versions" in data
    assert "image_size" in data
    assert "notes" in data
    assert data["variety"]["fruit_type"] == "Banana"
    if data["ripeness"] is not None:
        assert data["ripeness"]["stage"] in ["Green", "Turning", "Ripe", "Overripe"]


def test_401_without_key_on_admin_endpoints():
    # Calling verify_admin_key without key or with wrong key must raise 401
    with pytest.raises(HTTPException) as exc1:
        verify_admin_key(x_api_key=None)
    assert exc1.value.status_code == 401

    with pytest.raises(HTTPException) as exc2:
        verify_admin_key(x_api_key="wrong_key")
    assert exc2.value.status_code == 401

    # With valid key, it returns True
    assert verify_admin_key(x_api_key=TEST_API_KEY) is True


@pytest.mark.anyio
async def test_upload_with_and_without_ripeness():
    # 1. Upload WITHOUT ripeness
    img1 = _make_dummy_jpeg()
    f1 = UploadFile(filename="sample_no_rip.jpg", file=io.BytesIO(img1))
    res1 = await upload_images(
        variety_class="Ambul_Banana",
        files=[f1],
        ripeness=None,
        bunch_id=None,
        _=True,
    )
    assert res1["added"] == 1
    sha1 = res1["results"][0]["hash"]

    # 2. Upload WITH valid ripeness "Green" (unique sha)
    img2 = _make_dummy_jpeg()
    f2 = UploadFile(filename="sample_green.jpg", file=io.BytesIO(img2))
    res2 = await upload_images(
        variety_class="Ambul_Banana",
        files=[f2],
        ripeness="Green",
        bunch_id=None,
        _=True,
    )
    assert res2["added"] == 1
    assert res2["results"][0]["ripeness"] == "Green"
    sha2 = res2["results"][0]["hash"]

    # Verify saved under raw/<Class>/Green/
    raw_green_path = os.path.join("data", "images", "raw", "Ambul_Banana", "Green", f"{sha2}.jpg")
    assert os.path.isfile(raw_green_path), f"File was not saved under {raw_green_path}"


@pytest.mark.anyio
async def test_upload_invalid_stage_name():
    img = _make_dummy_jpeg()
    f = UploadFile(filename="bad_stage.jpg", file=io.BytesIO(img))

    # Reject "underripe" specifically with 400
    with pytest.raises(HTTPException) as exc_under:
        await upload_images(
            variety_class="Ambul_Banana",
            files=[f],
            ripeness="underripe",
            bunch_id=None,
            _=True,
        )
    assert exc_under.value.status_code == 400
    assert "Invalid ripeness stage 'underripe'" in exc_under.value.detail

    f2 = UploadFile(filename="bad_stage2.jpg", file=io.BytesIO(img))
    with pytest.raises(HTTPException) as exc:
        await upload_images(
            variety_class="Ambul_Banana",
            files=[f2],
            ripeness="SuperYellow",
            bunch_id=None,
            _=True,
        )
    assert exc.value.status_code == 400
    assert "Invalid ripeness stage" in exc.value.detail


def test_path_traversal_attempt_rejected():
    # Directory traversal or bad characters in image endpoint must raise 400
    with pytest.raises(HTTPException) as exc1:
        get_dataset_image(sha16="../../etc/passwd", _=True)
    assert exc1.value.status_code == 400
    assert "Path traversal or invalid characters" in exc1.value.detail

    with pytest.raises(HTTPException) as exc2:
        get_dataset_image(sha16="not_16_hex_chars!", _=True)
    assert exc2.value.status_code == 400


def test_put_labels_validation():
    # Invalid stage name must raise 400
    with pytest.raises(HTTPException) as exc1:
        update_labels_batch(
            updates=[LabelUpdateItem(sha16="0123456789abcdef", ripeness="InvalidStage")],
            _=True,
        )
    assert exc1.value.status_code == 400
    assert "Invalid ripeness stage" in exc1.value.detail

    # Invalid sha16 format must raise 400
    with pytest.raises(HTTPException) as exc2:
        update_labels_batch(
            updates=[LabelUpdateItem(sha16="../hack", ripeness="Ripe")],
            _=True,
        )
    assert exc2.value.status_code == 400


def test_get_unlabeled_endpoint():
    # 1. Default limit 50, offset 0
    res = get_unlabeled(limit=50, offset=0, _=True)
    assert "unlabeled" in res
    assert "total_unlabeled" in res
    assert res["limit"] == 50
    assert res["offset"] == 0
    assert isinstance(res["unlabeled"], list)
    # Check stable sort
    assert res["unlabeled"] == sorted(res["unlabeled"])

    # 2. Offset paging
    if res["total_unlabeled"] >= 4:
        page1 = get_unlabeled(limit=2, offset=0, _=True)
        page2 = get_unlabeled(limit=2, offset=2, _=True)
        assert len(page1["unlabeled"]) == 2
        assert len(page2["unlabeled"]) == 2
        assert page1["unlabeled"][0] != page2["unlabeled"][0]

    # 3. Class filter
    res_ambul = get_unlabeled(limit=50, offset=0, variety_class="Ambul_Banana", _=True)
    assert res_ambul["class"] == "Ambul_Banana"

    # 4. Invalid class regex raises 400
    with pytest.raises(HTTPException) as exc:
        get_unlabeled(limit=50, offset=0, variety_class="Invalid Class Name!", _=True)
    assert exc.value.status_code == 400
    assert "Invalid class format" in exc.value.detail


def test_models_registry_task_query():
    # GET /models with task=variety and task=ripeness
    models_var = get_models(include_experiments=False, task="variety", _=True)
    assert isinstance(models_var, list)

    models_rip = get_models(include_experiments=False, task="ripeness", _=True)
    assert isinstance(models_rip, list)


def test_placeholder_version_suppresses_metrics(tmp_path, monkeypatch):
    """
    G3: Self-contained test asserting that a placeholder version does not expose
    accuracy/F1 in list_versions() or API response, and that tracked placeholder JSON
    takes precedence over local status.txt ('ready').
    """
    import app.ml.registry as reg_mod

    fake_versions_dir = tmp_path / "model_versions"
    v_fake = fake_versions_dir / "v9999"
    v_fake.mkdir(parents=True)
    (v_fake / "model_config.json").write_text(
        json.dumps({"architecture": "efficientnetb3", "image_size": [240, 240]}),
        encoding="utf-8",
    )
    (v_fake / "metrics.json").write_text(
        json.dumps({"test_accuracy": 0.985, "macro_f1": 0.981}),
        encoding="utf-8",
    )
    (v_fake / "model.keras").write_text("dummy weights", encoding="utf-8")
    (v_fake / "status.txt").write_text("ready", encoding="utf-8")

    fake_placeholders = tmp_path / "placeholder_versions.json"
    fake_placeholders.write_text(
        json.dumps({"variety": ["v9999"], "ripeness": []}),
        encoding="utf-8",
    )

    monkeypatch.setattr(reg_mod, "MODEL_VERSIONS_DIR", str(fake_versions_dir))
    monkeypatch.setattr(reg_mod, "PLACEHOLDER_VERSIONS_PATH", str(fake_placeholders))

    # Assert list_versions suppresses accuracy and overrides status.txt
    versions = reg_mod.list_versions(include_experiments=False, task="variety")
    v_match = next((v for v in versions if v["id"] == "v9999"), None)
    assert v_match is not None
    assert v_match["status"] == "placeholder"
    assert v_match.get("test_accuracy") is None
    assert v_match.get("macro_f1") is None
    assert v_match.get("architecture") == "efficientnetb3"

    # Assert API endpoint also surfaces status placeholder and suppresses metrics
    api_models = get_models(include_experiments=False, task="variety", _=True)
    api_v_match = next((m for m in api_models if m.get("id") == "v9999"), None)
    assert api_v_match is not None
    assert api_v_match["status"] == "placeholder"
    assert api_v_match.get("test_accuracy") is None
    assert api_v_match.get("macro_f1") is None


def test_training_task_support():
    st_var = training_status(task="variety", _=True)
    assert st_var["task"] == "variety"

    st_rip = training_status(task="ripeness", _=True)
    assert st_rip["task"] == "ripeness"


@pytest.mark.anyio
async def test_legacy_predict_endpoint_unchanged():
    jpeg_bytes = _make_dummy_jpeg()
    upload = UploadFile(filename="legacy.jpg", file=io.BytesIO(jpeg_bytes))
    res = await predict_fruit(file=upload, model_version=None, x_api_key=None)
    assert res["fruit_type"] == "Banana"
    assert res["variety"] is not None
    assert res["confidence"] is not None
    assert len(res["top3"]) > 0
