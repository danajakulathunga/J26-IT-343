from pydantic import BaseModel
from typing import List, Optional, Any, Dict

class VarietyResult(BaseModel):
    fruit_type: str
    variety: str
    confidence: float
    model_version: Optional[str] = None
    image_size: Optional[Any] = None
    architecture: Optional[str] = None
    top3: Optional[List[Dict[str, Any]]] = None
    low_confidence: Optional[bool] = None

class CountryRecommendation(BaseModel):
    country: str
    exportScore: float
    demand: str
    avgUnitValueUsdKg: float
    bestWindow: str
    qualityRequirement: str

class MarketAlert(BaseModel):
    type: str
    message: str
    country: str
    createdAt: str
