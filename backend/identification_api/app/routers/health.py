import os
from fastapi import APIRouter
from app.core.config import settings
from app.schemas.meta import HealthResponse

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthResponse)
def get_health():
    mode = settings.MODEL_MODE.lower().strip()
    model_exists = os.path.exists(settings.MODEL_PATH) if mode == "real" else False
    return HealthResponse(
        status="ok",
        version=settings.VERSION,
        mode=mode,
        model_loaded=(mode == "real" and model_exists)
    )
