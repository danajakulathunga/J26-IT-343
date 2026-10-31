import json
import os
import shutil
from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy.orm import Session
from app.core.config import settings
from app.db.session import get_db
from app.db.models import Scan, User
from app.schemas.scan import (
    ScanResponse,
    ScanHistoryPagination,
    ScanHistoryItem,
    ConditionOutput,
    SeverityOutput,
    ImagesOutput,
    LocalizedText,
)
from app.routers.deps import resolve_auth_or_guest, get_optional_user
from app.services.knowledge import knowledge_service

router = APIRouter(tags=["History"])


@router.get("/scans", response_model=ScanHistoryPagination)
def get_scan_history(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    condition_type: Optional[str] = Query(None),
    auth_ids: tuple = Depends(resolve_auth_or_guest),
    db: Session = Depends(get_db)
):
    user_id, guest_id = auth_ids
    query = db.query(Scan)

    if user_id:
        query = query.filter(Scan.user_id == user_id)
    else:
        if guest_id:
            query = query.filter((Scan.guest_id == guest_id) | (Scan.user_id.is_(None)))
        else:
            query = query.filter(Scan.user_id.is_(None))

    if condition_type:
        query = query.filter(Scan.condition_type.ilike(condition_type.strip()))

    total = query.count()
    items_db = (
        query.order_by(Scan.created_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )

    items = []
    for s in items_db:
        if s.raw_response_json:
            try:
                data = json.loads(s.raw_response_json)
                c_info = data.get("condition")
                if c_info and isinstance(c_info, dict):
                    cid = c_info.get("id")
                    meta = knowledge_service.get_condition_by_id(cid) if cid else None
                    if meta:
                        if not c_info.get("ta"):
                            c_info["ta"] = meta.get("name_ta", "")
                        if not c_info.get("description_ta"):
                            c_info["description_ta"] = meta.get("description_ta", "")
                items.append(ScanResponse(**data))
                continue
            except Exception:
                pass

        cond_meta = knowledge_service.get_condition_by_id(s.condition_id) or {}
        causes_raw, recs_raw = knowledge_service.get_severity_content(s.condition_id, s.severity_level)
        sev_causes = [LocalizedText(**c) for c in (causes_raw or cond_meta.get("cause_factors", []))]
        sev_recs = [LocalizedText(**r) for r in (recs_raw or cond_meta.get("recommendations", []))]
        var_obj = knowledge_service.get_variety_by_id(s.variety_id) if s.variety_id else None

        items.append(
            ScanResponse(
                scan_id=s.id,
                mode=s.mode or "demo",
                created_at=s.created_at.isoformat() if s.created_at else "",
                variety=var_obj,
                condition=ConditionOutput(
                    id=s.condition_id,
                    type=s.condition_type,
                    en=cond_meta.get("name_en", s.condition_id.replace("_", " ").title()),
                    si=cond_meta.get("name_si", ""),
                    ta=cond_meta.get("name_ta", ""),
                    description_si=cond_meta.get("description_si", ""),
                    description_ta=cond_meta.get("description_ta", "")
                ),
                condition_confidence=s.condition_confidence or 0.0,
                severity=SeverityOutput(
                    level=s.severity_level or "Mild",
                    en=s.severity_level or "Mild",
                    si="දැඩි" if s.severity_level == "Severe" else ("මධ්‍යස්ථ" if s.severity_level == "Moderate" else "සුළු"),
                    ta="கடுமையான" if s.severity_level == "Severe" else ("மிதமான" if s.severity_level == "Moderate" else "லேசான")
                ) if s.severity_level else None,
                severity_confidence=s.severity_confidence,
                severity_index=s.severity_index or 0.0,
                top_predictions=[],
                cause_factors=sev_causes,
                recommendations=sev_recs,
                images=ImagesOutput(
                    original_url=f"/scans/{s.id}/original",
                    gradcam_url=f"/scans/{s.id}/gradcam"
                ),
                highlight_box=None,
                quality_warnings=[],
                low_confidence=False,
                disclaimer=LocalizedText(
                    en="AI diagnostic tool for screening. Verify with agricultural experts.",
                    si="කෘෂිකාර්මික විශේෂඥයින් සමඟ තහවුරු කරගන්න.",
                    ta="விவசாய நிபுணர்களுடன் சரிபார்க்கவும்."
                )
            )
        )

    return ScanHistoryPagination(
        total=total,
        page=page,
        limit=limit,
        items=items
    )


@router.get("/scans/{scan_id}", response_model=ScanResponse)
def get_scan_by_id(
    scan_id: str,
    auth_ids: tuple = Depends(resolve_auth_or_guest),
    db: Session = Depends(get_db)
):
    user_id, guest_id = auth_ids
    scan = db.query(Scan).filter(Scan.id == scan_id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")

    if user_id and scan.user_id and scan.user_id != user_id:
        raise HTTPException(status_code=403, detail="Forbidden")

    data = json.loads(scan.raw_response_json)
    return ScanResponse(**data)


@router.delete("/scans/{scan_id}")
def delete_scan(
    scan_id: str,
    auth_ids: tuple = Depends(resolve_auth_or_guest),
    db: Session = Depends(get_db)
):
    user_id, guest_id = auth_ids
    scan = db.query(Scan).filter(Scan.id == scan_id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")

    if user_id and scan.user_id != user_id:
        raise HTTPException(status_code=403, detail="Forbidden")
    if guest_id and scan.guest_id != guest_id and scan.user_id != user_id:
        raise HTTPException(status_code=403, detail="Forbidden")

    # Delete storage files
    scan_dir = os.path.join(settings.STORAGE_DIR, "scans", scan_id)
    if os.path.exists(scan_dir):
        shutil.rmtree(scan_dir, ignore_errors=True)

    db.delete(scan)
    db.commit()

    return {"message": "Scan deleted successfully", "scan_id": scan_id}
