import json
import os
from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response, status
from sqlalchemy.orm import Session
from app.core.config import settings
from app.db.session import get_db
from app.db.models import Scan, User
from app.services.report_pdf import generate_scan_pdf
from app.routers.deps import resolve_auth_or_guest, get_optional_user

router = APIRouter(tags=["Reports"])


@router.get("/scans/{scan_id}/report")
def get_scan_report_pdf(
    scan_id: str,
    lang: Optional[str] = Query("en_si"),
    user: Optional[User] = Depends(get_optional_user),
    x_guest_id: Optional[str] = Header(None, alias="X-Guest-Id"),
    x_guest_name: Optional[str] = Header(None, alias="X-Guest-Name"),
    db: Session = Depends(get_db)
):
    scan = db.query(Scan).filter(Scan.id == scan_id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")

    # Determine client name
    client_name = "Guest Grower"
    if user:
        client_name = user.full_name
    elif x_guest_name and x_guest_name.strip():
        client_name = x_guest_name.strip()

    scan_dir = os.path.join(settings.STORAGE_DIR, "scans", scan_id)
    orig_path = os.path.join(scan_dir, "original.jpg")
    gradcam_path = os.path.join(scan_dir, "gradcam.jpg")

    # If image files missing on disk, create blank placeholder so PDF generation never fails
    if not os.path.exists(orig_path) or not os.path.exists(gradcam_path):
        os.makedirs(scan_dir, exist_ok=True)
        from PIL import Image
        dummy = Image.new("RGB", (400, 400), color=(230, 230, 230))
        if not os.path.exists(orig_path):
            dummy.save(orig_path, "JPEG")
        if not os.path.exists(gradcam_path):
            dummy.save(gradcam_path, "JPEG")

    if scan.raw_response_json:
        try:
            scan_data = json.loads(scan.raw_response_json)
        except Exception:
            scan_data = None
    else:
        scan_data = None

    if not scan_data:
        from app.services.knowledge import knowledge_service
        cond_meta = knowledge_service.get_condition_by_id(scan.condition_id) or {}
        causes_raw, recs_raw = knowledge_service.get_severity_content(scan.condition_id, scan.severity_level)
        scan_data = {
            "scan_id": scan.id,
            "created_at": scan.created_at.isoformat() if scan.created_at else "",
            "condition": {
                "id": scan.condition_id,
                "type": scan.condition_type,
                "en": cond_meta.get("name_en", scan.condition_id.replace("_", " ").title()),
                "si": cond_meta.get("name_si", ""),
                "ta": cond_meta.get("name_ta", ""),
                "description_si": cond_meta.get("description_si", ""),
                "description_ta": cond_meta.get("description_ta", "")
            },
            "condition_confidence": scan.condition_confidence or 0.85,
            "severity": {
                "level": scan.severity_level or "Mild",
                "en": scan.severity_level or "Mild",
                "si": "දැඩි" if scan.severity_level == "Severe" else ("මධ්‍යස්ථ" if scan.severity_level == "Moderate" else "සුළු"),
                "ta": "கடுமையான" if scan.severity_level == "Severe" else ("மிதமான" if scan.severity_level == "Moderate" else "லேசான")
            } if scan.severity_level else None,
            "severity_confidence": scan.severity_confidence,
            "severity_index": scan.severity_index or 0.0,
            "cause_factors": causes_raw or cond_meta.get("cause_factors", []),
            "recommendations": recs_raw or cond_meta.get("recommendations", []),
            "images": {
                "original_url": f"/scans/{scan.id}/original",
                "gradcam_url": f"/scans/{scan.id}/gradcam"
            },
            "low_confidence": False,
            "disclaimer": {
                "en": "Decision-support information only. Consult an agricultural expert before applying treatments.",
                "si": "තීරණ සහායක තොරතුරු පමණි. ප්‍රතිකාර යෙදීමට පෙර කෘෂිකාර්මික විශේෂඥයෙකුගෙන් උපදෙස් ලබා ගන්න."
            }
        }

    try:
        pdf_bytes = generate_scan_pdf(
            scan_data=scan_data,
            client_name=client_name,
            original_img_path=orig_path,
            gradcam_img_path=gradcam_path
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Report rendering error: {str(e)}"
        )

    headers = {
        "Content-Disposition": f"attachment; filename=BananaGuard_Report_{scan_id[:8]}.pdf",
        "Content-Type": "application/pdf"
    }

    return Response(content=pdf_bytes, media_type="application/pdf", headers=headers)
