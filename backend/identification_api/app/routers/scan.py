import json
import os
import uuid
from datetime import datetime, timezone
from typing import Optional, Tuple
from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.db.session import get_db
from app.db.models import Scan, User
from app.schemas.scan import (
    ScanResponse,
    ConditionOutput,
    TopPrediction,
    ImagesOutput,
)
from app.services.image_utils import validate_and_load_image, run_quality_checks, run_banana_check
from app.services.inference import get_inference_predictor, DemoPredictor, KerasPredictor
from app.services.severity import calculate_severity
from app.services.knowledge import knowledge_service, DISCLAIMER
from app.services.gradcam import (
    generate_demo_saliency_heatmap,
    generate_keras_gradcam,
    create_gradcam_overlay,
)
from app.services.preprocessing import preprocess_image
from app.routers.deps import resolve_auth_or_guest, get_optional_user

from starlette.concurrency import run_in_threadpool

router = APIRouter(tags=["Scan & Predict"])


def _process_prediction_pipeline(contents: bytes, variety: Optional[str]) -> Tuple[ScanResponse, str, Optional[str], str, str, float, Optional[str], Optional[float], float, str, str]:
    # 1. Validate and load image
    try:
        image_rgb = validate_and_load_image(contents, max_mb=settings.MAX_UPLOAD_MB)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    # 1b. Banana subject-matter check (OpenAI CLIP ViT-B/32 Zero-Shot)
    if not run_banana_check(image_rgb):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "not_banana",
                "message_en": "This app only supports banana fruit images. Please scan a banana and try again.",
                "message_si": "මෙම app එකෙහි කෙසෙල් පළතුරු පමණක් scan කළ හැක. කරුණාකර කෙසෙල් ගෙඩියක ඡායාරූපයක් ගෙන නැවත උත්සාහ කරන්න.",
            },
        )

    # 2. Quality checks
    quality_warnings = run_quality_checks(image_rgb)

    # 3. Inference adapter
    predictor = get_inference_predictor()
    mode = "demo" if isinstance(predictor, DemoPredictor) else "real"
    preds = predictor.predict(image_rgb, contents)

    condition_probs = preds["condition_probs"]
    severity_probs = preds["severity_probs"]

    # 4. Determine condition and severity
    cond_idx = int(max(range(len(condition_probs)), key=lambda i: condition_probs[i]))
    cond_confidence = round(float(condition_probs[cond_idx]), 4)

    cond_meta = knowledge_service.get_condition_by_index(cond_idx)
    if not cond_meta:
        raise HTTPException(status_code=500, detail="Internal error loading condition metadata")

    cond_id = cond_meta["id"]
    cond_type = cond_meta["type"]  # Healthy | Disease | Defect

    severity_output, severity_conf, severity_idx = calculate_severity(cond_id, severity_probs)
    sev_level_name = severity_output.level if severity_output else None
    sev_causes, sev_recs = knowledge_service.get_severity_content(cond_id, sev_level_name)
    if not sev_causes:
        sev_causes = cond_meta.get("cause_factors", [])
    if not sev_recs:
        sev_recs = cond_meta.get("recommendations", [])

    # Top 3 predictions
    indexed_probs = list(enumerate(condition_probs))
    indexed_probs.sort(key=lambda x: x[1], reverse=True)
    top_3 = []
    for idx, prob in indexed_probs[:3]:
        c_meta = knowledge_service.get_condition_by_index(idx)
        if c_meta:
            top_3.append(
                TopPrediction(
                    id=c_meta["id"],
                    en=c_meta.get("name_en", c_meta["id"]),
                    si=c_meta.get("name_si", ""),
                    ta=c_meta.get("name_ta", ""),
                    confidence=round(float(prob), 4)
                )
            )

    low_conf = cond_confidence < settings.LOW_CONFIDENCE_THRESHOLD

    # 5. Grad-CAM / Saliency Heatmap
    if mode == "real" and isinstance(predictor, KerasPredictor) and predictor.model is not None:
        preprocessed = preprocess_image(image_rgb, model=predictor.model)
        model_cond_idx = predictor.model_condition_index(cond_id)
        heatmap = generate_keras_gradcam(predictor.model, preprocessed, model_cond_idx)
    else:
        import numpy as np
        heatmap = generate_demo_saliency_heatmap(np.array(image_rgb))

    # Create overlay on full image (never cropped)
    resized_orig, overlay_pil, highlight_box = create_gradcam_overlay(
        image_rgb,
        heatmap,
        is_healthy=(cond_id == "healthy")
    )

    # 6. Storage: save scan files
    scan_id = str(uuid.uuid4())
    scan_dir = os.path.join(settings.STORAGE_DIR, "scans", scan_id)
    os.makedirs(scan_dir, exist_ok=True)

    orig_path = os.path.join(scan_dir, "original.jpg")
    gradcam_path = os.path.join(scan_dir, "gradcam.jpg")

    resized_orig.save(orig_path, format="JPEG", quality=92)
    overlay_pil.save(gradcam_path, format="JPEG", quality=92)

    # Variety lookup
    variety_obj = knowledge_service.get_variety_by_id(variety)

    # 7. Build Response
    now_iso = datetime.now(timezone.utc).isoformat()
    response_obj = ScanResponse(
        scan_id=scan_id,
        mode=mode,
        created_at=now_iso,
        variety=variety_obj,
        condition=ConditionOutput(
            id=cond_id,
            type=cond_type,
            en=cond_meta.get("name_en", cond_id),
            si=cond_meta.get("name_si", ""),
            ta=cond_meta.get("name_ta", ""),
            description_si=cond_meta.get("description_si", ""),
            description_ta=cond_meta.get("description_ta", "")
        ),
        condition_confidence=cond_confidence,
        severity=severity_output,
        severity_confidence=severity_conf,
        severity_index=severity_idx,
        top_predictions=top_3,
        cause_factors=sev_causes,
        recommendations=sev_recs,
        images=ImagesOutput(

            original_url=f"/scans/{scan_id}/original",
            gradcam_url=f"/scans/{scan_id}/gradcam"
        ),
        highlight_box=highlight_box,
        quality_warnings=quality_warnings,
        low_confidence=low_conf,
        disclaimer=DISCLAIMER
    )

    return (
        response_obj,
        scan_id,
        variety_obj.id if variety_obj else None,
        cond_id,
        cond_type,
        cond_confidence,
        severity_output.level if severity_output else None,
        severity_conf,
        severity_idx,
        mode,
        response_obj.model_dump_json()
    )


@router.post("/check-banana")
async def check_banana_endpoint(
    file: UploadFile = File(...),
):
    """Fast, lightweight endpoint to verify if an image contains a banana fruit
    using OpenAI CLIP (ViT-B/32) Zero-Shot. Zero latency check before proceeding to analysis.
    """
    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty")

    def _eval(data: bytes) -> bool:
        img_rgb = validate_and_load_image(data, max_mb=settings.MAX_UPLOAD_MB)
        return run_banana_check(img_rgb)

    try:
        is_banana = await run_in_threadpool(_eval, contents)
    except Exception as exc:
        logger.warning(f"[check-banana] Validation failed or rejected: {exc}")
        is_banana = False

    return {
        "is_banana": is_banana,
        "code": "banana_verified" if is_banana else "not_banana",
        "message_en": "Banana fruit confirmed." if is_banana else "This app only supports banana fruit images. Please scan a banana and try again.",
        "message_si": "කෙසෙල් පළතුර තහවුරු විය." if is_banana else "මෙම app එකෙහි කෙසෙල් පළතුරු පමණක් scan කළ හැක. කරුණාකර කෙසෙල් ගෙඩියක ඡායාරූපයක් ගෙන නැවත උත්සාහ කරන්න.",
        "message_ta": "வாழைப்பழம் உறுதிப்படுத்தப்பட்டது." if is_banana else "இந்த app இல் வாழைப்பழ படங்கள் மட்டுமே ஸ்கேன் செய்யலாம். தயவுசெய்து வாழைப்பழத்தின் தெளிவான புகைப்படம் எடுத்து மீண்டும் முயற்சிக்கவும்."
    }


@router.post("/predict", response_model=ScanResponse)
async def predict_scan(
    file: UploadFile = File(...),
    variety: Optional[str] = Form(None),
    language: Optional[str] = Form("en"),
    auth_ids: tuple = Depends(resolve_auth_or_guest),
    db: Session = Depends(get_db)
):
    user_id, guest_id = auth_ids

    # Read bytes asynchronously
    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty")

    # Run heavy CPU pipeline in threadpool to prevent event loop blocking
    (
        response_obj,
        scan_id,
        variety_id,
        cond_id,
        cond_type,
        cond_confidence,
        severity_level,
        severity_conf,
        severity_idx,
        mode,
        raw_json
    ) = await run_in_threadpool(_process_prediction_pipeline, contents, variety)

    # Persist to DB
    scan_record = Scan(
        id=scan_id,
        user_id=user_id,
        guest_id=guest_id,
        variety_id=variety_id,
        condition_id=cond_id,
        condition_type=cond_type,
        condition_confidence=cond_confidence,
        severity_level=severity_level,
        severity_confidence=severity_conf,
        severity_index=severity_idx,
        mode=mode,
        raw_response_json=raw_json
    )
    db.add(scan_record)
    db.commit()

    return response_obj


@router.get("/scans/{scan_id}/original")
def get_original_image(
    scan_id: str,
    db: Session = Depends(get_db),
):
    scan = db.query(Scan).filter(Scan.id == scan_id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")

    file_path = os.path.join(settings.STORAGE_DIR, "scans", scan_id, "original.jpg")
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Original image file not found")
    return FileResponse(file_path, media_type="image/jpeg")


@router.get("/scans/{scan_id}/gradcam")
def get_gradcam_image(
    scan_id: str,
    db: Session = Depends(get_db),
):
    scan = db.query(Scan).filter(Scan.id == scan_id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")

    file_path = os.path.join(settings.STORAGE_DIR, "scans", scan_id, "gradcam.jpg")
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Grad-CAM image file not found")
    return FileResponse(file_path, media_type="image/jpeg")
