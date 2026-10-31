from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel
from app.schemas.meta import LocalizedText, VarietyResponse


class ConditionOutput(BaseModel):
    id: str
    type: str  # Healthy | Disease | Defect
    en: str
    si: str
    ta: Optional[str] = ""
    description_si: Optional[str] = ""
    description_ta: Optional[str] = ""


class SeverityOutput(BaseModel):
    level: str  # Mild | Moderate | Severe
    en: str
    si: str
    ta: Optional[str] = ""


class TopPrediction(BaseModel):
    id: str
    en: str
    si: str
    ta: Optional[str] = ""
    confidence: float


class ImagesOutput(BaseModel):
    original_url: str
    gradcam_url: str


class HighlightBox(BaseModel):
    x: float
    y: float
    w: float
    h: float


class QualityWarning(BaseModel):
    code: str
    en: str
    si: str


class ScanResponse(BaseModel):
    scan_id: str
    mode: str  # demo | real
    created_at: str
    variety: Optional[VarietyResponse] = None
    condition: ConditionOutput
    condition_confidence: float
    severity: Optional[SeverityOutput] = None
    severity_confidence: Optional[float] = None
    severity_index: float
    top_predictions: List[TopPrediction]
    cause_factors: List[LocalizedText]
    recommendations: List[LocalizedText]
    images: ImagesOutput
    highlight_box: Optional[HighlightBox] = None
    quality_warnings: List[QualityWarning]
    low_confidence: bool
    disclaimer: LocalizedText


class ScanHistoryItem(BaseModel):
    id: str
    created_at: datetime
    variety_id: Optional[str] = None
    condition_id: str
    condition_type: str
    condition_confidence: float
    severity_level: Optional[str] = None
    severity_confidence: Optional[float] = None
    severity_index: float
    mode: str
    thumbnail_url: str

    class Config:
        from_attributes = True


class ScanHistoryPagination(BaseModel):
    total: int
    page: int
    limit: int
    items: List[ScanResponse]
