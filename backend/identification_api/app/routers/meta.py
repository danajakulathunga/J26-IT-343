from typing import List
from fastapi import APIRouter, HTTPException
from app.services.knowledge import knowledge_service
from app.schemas.meta import VarietyResponse, ConditionDetailResponse

router = APIRouter(prefix="/meta", tags=["Metadata"])


@router.get("/varieties", response_model=List[VarietyResponse])
def get_varieties():
    return knowledge_service.get_varieties()


@router.get("/conditions", response_model=List[ConditionDetailResponse])
def get_conditions():
    return knowledge_service.get_all_conditions()


@router.get("/conditions/{condition_id}", response_model=ConditionDetailResponse)
def get_condition_detail(condition_id: str):
    cond = knowledge_service.get_condition_by_id(condition_id)
    if not cond:
        raise HTTPException(status_code=404, detail="Condition not found in knowledge base")

    from app.schemas.meta import LocalizedText, SeverityContent
    parsed_sev_levels = None
    if "severity_levels" in cond and isinstance(cond["severity_levels"], dict):
        parsed_sev_levels = {}
        for lvl, data in cond["severity_levels"].items():
            parsed_sev_levels[lvl] = SeverityContent(
                cause_factors=[LocalizedText(**item) for item in data.get("cause_factors", [])],
                recommendations=[LocalizedText(**item) for item in data.get("recommendations", [])]
            )

    return ConditionDetailResponse(
        id=cond["id"],
        label_id=cond.get("label_id", 0),
        name_en=cond.get("name_en", ""),
        name_si=cond.get("name_si", ""),
        name_ta=cond.get("name_ta", ""),
        type=cond.get("type", "Disease"),
        description_si=cond.get("description_si", ""),
        description_ta=cond.get("description_ta", ""),
        cause_factors=[LocalizedText(**item) for item in cond.get("cause_factors", [])],
        recommendations=[LocalizedText(**item) for item in cond.get("recommendations", [])],
        severity_levels=parsed_sev_levels
    )

