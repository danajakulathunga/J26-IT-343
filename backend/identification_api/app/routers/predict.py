import os
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, UploadFile
from PIL import UnidentifiedImageError

from ..schemas import VarietyResult
from ..ml.predictor import compare, predict_variety, predict_all
from ..ml.registry import resolve_version, validate_version_id
from .dataset import verify_admin_key

router = APIRouter(prefix="/predict", tags=["prediction"])
analyze_router = APIRouter(tags=["analysis"])

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".heic", ".heif"}
ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/heic",
    "image/heif",
    "application/octet-stream",
}


def _validate_image_file(file: UploadFile) -> None:
    filename = file.filename or ""
    ext = os.path.splitext(filename)[1].lower()
    if ext and ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file format '{ext}'. Approved formats: JPG, PNG, HEIC, HEIF.",
        )


def _check_version_access_and_validity(
    model_version: Optional[str],
    x_api_key: Optional[str],
) -> None:
    """
    If a specific non-active model version is requested, verify API key
    and confirm the version exists and is available in the registry.
    """
    if not model_version or model_version.strip() == "" or model_version == "active":
        return

    # Non-active version requires admin authentication
    verify_admin_key(x_api_key)

    clean_version = model_version.strip()
    if not validate_version_id(clean_version):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid model version ID '{clean_version}'. Must match ^[A-Za-z0-9_\\-]+$.",
        )

    ok, meta, err = resolve_version(clean_version, include_experiments=True)
    if not ok or not meta:
        raise HTTPException(
            status_code=404,
            detail=f"Model version '{clean_version}' not found: {err}",
        )
    if not meta.get("available", False):
        raise HTTPException(
            status_code=404,
            detail=f"Model version '{clean_version}' is unavailable (model file cleaned up or missing).",
        )


@router.post("", response_model=VarietyResult, include_in_schema=False)
@router.post("/", response_model=VarietyResult)
async def predict_fruit(
    file: UploadFile = File(...),
    model_version: Optional[str] = Query(None),
    remove_bg: Optional[bool] = Query(None, description="A/B override for background removal (default from env)"),
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
):
    _validate_image_file(file)
    _check_version_access_and_validity(model_version, x_api_key)

    try:
        content = await file.read()
        target_version = model_version.strip() if model_version else None
        result = predict_variety(content, version=target_version, remove_bg=remove_bg)
        return result
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except (UnidentifiedImageError, ValueError) as e:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid or corrupted image file: {str(e)}",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/multi", response_model=List[VarietyResult])
async def predict_multi(
    files: List[UploadFile] = File(...),
    model_version: Optional[str] = Query(None),
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
):
    if not files:
        raise HTTPException(status_code=400, detail="No files provided.")

    _check_version_access_and_validity(model_version, x_api_key)
    target_version = model_version.strip() if model_version else None

    results = []
    for file in files:
        _validate_image_file(file)
        try:
            content = await file.read()
            res = predict_variety(content, version=target_version)
            results.append(res)
        except (UnidentifiedImageError, ValueError) as e:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid image file '{file.filename}': {str(e)}",
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    return results


@router.post("/compare")
async def compare_fruit_models(
    file: UploadFile = File(...),
    versions: str = Form(...),
    _: bool = Depends(verify_admin_key),
):
    _validate_image_file(file)

    version_list = [v.strip() for v in versions.split(",") if v.strip()]
    if len(version_list) < 2 or len(version_list) > 4:
        raise HTTPException(
            status_code=400,
            detail=f"Comparison requires between 2 and 4 versions (received {len(version_list)}).",
        )

    for v_id in version_list:
        if v_id == "active":
            continue
        if not validate_version_id(v_id):
            raise HTTPException(
                status_code=400,
                detail=f"Invalid version ID '{v_id}'. Must match ^[A-Za-z0-9_\\-]+$.",
            )
        ok, meta, err = resolve_version(v_id, include_experiments=True)
        if not ok or not meta:
            raise HTTPException(
                status_code=404,
                detail=f"Model version '{v_id}' not found: {err}",
            )
        if not meta.get("available", False):
            raise HTTPException(
                status_code=404,
                detail=f"Model version '{v_id}' is unavailable (model file cleaned up or missing).",
            )

    try:
        content = await file.read()
        return compare(content, version_list)
    except (UnidentifiedImageError, ValueError) as e:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid or corrupted image file: {str(e)}",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@analyze_router.post("/analyze")
async def analyze_fruit(
    file: UploadFile = File(...),
    variety_version: Optional[str] = Query(None),
    ripeness_version: Optional[str] = Query(None),
    tta: bool = Query(False),
    remove_bg: Optional[bool] = Query(None, description="A/B override for background removal (default from env)"),
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
):
    """
    Public analysis endpoint running variety and ripeness prediction on the same image.
    Returns {variety, ripeness, model_versions, image_size, notes}.
    """
    _validate_image_file(file)

    v_ver = variety_version if isinstance(variety_version, str) else None
    r_ver = ripeness_version if isinstance(ripeness_version, str) else None
    is_tta = tta if isinstance(tta, bool) else False
    api_k = x_api_key if isinstance(x_api_key, str) else None

    if v_ver and v_ver != "active":
        _check_version_access_and_validity(v_ver, api_k)
    if r_ver and r_ver != "active":
        verify_admin_key(api_k)

    try:
        content = await file.read()
        return predict_all(
            content,
            variety_version=v_ver,
            ripeness_version=r_ver,
            tta=is_tta,
            remove_bg=remove_bg,
        )
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except (UnidentifiedImageError, ValueError) as e:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid or corrupted image file: {str(e)}",
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/analyze")
async def analyze_fruit_alias(
    file: UploadFile = File(...),
    variety_version: Optional[str] = Query(None),
    ripeness_version: Optional[str] = Query(None),
    tta: bool = Query(False),
    remove_bg: Optional[bool] = Query(None, description="A/B override for background removal (default from env)"),
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
):
    return await analyze_fruit(file, variety_version, ripeness_version, tta, remove_bg, x_api_key)

