from fastapi import APIRouter
from typing import List
from ..schemas import MarketAlert
import datetime

router = APIRouter(prefix="/alerts", tags=["alerts"])

@router.get("/", response_model=List[MarketAlert])
def get_alerts():
    return [
        {
            "type": "PRICE_DROP",
            "message": "Sudden price drop in UAE markets for Ambul banana.",
            "country": "UAE",
            "createdAt": datetime.datetime.now().isoformat()
        }
    ]
