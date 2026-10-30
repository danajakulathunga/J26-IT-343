from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from app.routers.dataset import verify_admin_key
from app.ml.trainer import (
    get_training_status,
    rollback_to_version,
    start_training,
)

router = APIRouter(prefix="/training", tags=["training"])


class StartTrainingRequest(BaseModel):
    task: Optional[str] = "variety"
    epochs_stage1: Optional[int] = 10
    epochs_stage2: Optional[int] = 5
    reason: Optional[str] = "manual"
    arch: Optional[str] = None
    split: Optional[str] = "hash"
    bg_swap_prob: Optional[float] = 0.6


class RollbackRequest(BaseModel):
    version: str
    task: Optional[str] = "variety"


@router.post("/start")
def trigger_training(
    task: str = Query("variety"),
    req: Optional[StartTrainingRequest] = None,
    _: bool = Depends(verify_admin_key),
):
    effective_task = req.task if (req and req.task and req.task != "variety") else task
    epochs1 = req.epochs_stage1 if req else 10
    epochs2 = req.epochs_stage2 if req else 5
    reason = req.reason if req else "manual"
    arch = req.arch if req else None
    split = req.split if req else "hash"
    bg_swap_prob = req.bg_swap_prob if (req and req.bg_swap_prob is not None) else 0.6

    success, msg = start_training(
        reason=reason,
        epochs1=epochs1,
        epochs2=epochs2,
        task=effective_task,
        arch=arch,
        split=split,
        bg_swap_prob=bg_swap_prob,
    )
    if not success:
        raise HTTPException(status_code=409, detail=msg)
    return {"success": True, "task": effective_task, "message": msg}


@router.get("/status")
def training_status(
    task: str = Query("variety"),
    _: bool = Depends(verify_admin_key),
):
    return get_training_status(task=task)


@router.post("/rollback")
def rollback_model(
    req: RollbackRequest,
    _: bool = Depends(verify_admin_key),
):
    if not req.version:
        raise HTTPException(status_code=400, detail="Target version name is required.")

    effective_task = req.task or "variety"
    success, msg = rollback_to_version(req.version, task=effective_task)
    if not success:
        raise HTTPException(status_code=400, detail=msg)
    return {"success": True, "task": effective_task, "message": msg}

