from typing import List, Optional
from pydantic import BaseModel


class VarietyResponse(BaseModel):
    id: str
    en: str
    si: str
    ta: Optional[str] = ""


class LocalizedText(BaseModel):
    en: str
    si: str
    ta: Optional[str] = ""


class SeverityContent(BaseModel):
    cause_factors: List[LocalizedText] = []
    recommendations: List[LocalizedText] = []


class ConditionDetailResponse(BaseModel):
    id: str
    label_id: int
    name_en: str
    name_si: str
    name_ta: Optional[str] = ""
    type: str  # Healthy, Disease, Defect
    description_si: Optional[str] = ""
    description_ta: Optional[str] = ""
    cause_factors: List[LocalizedText] = []
    recommendations: List[LocalizedText] = []
    severity_levels: Optional[dict[str, SeverityContent]] = None



class HealthResponse(BaseModel):
    status: str
    version: str
    mode: str  # demo | real
    model_loaded: bool
