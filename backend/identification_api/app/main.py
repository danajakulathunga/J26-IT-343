import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from app.core.config import settings
from app.core.logging import setup_logging, logger
from app.db.session import engine, Base
from app.routers import auth, scan, history, report, meta, health

limiter = Limiter(key_func=get_remote_address)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    setup_logging()
    logger.info("Starting BananaGuard AI Backend Application...")
    logger.info(f"Operational Mode: {settings.MODEL_MODE.upper()}")

    # Ensure storage paths
    os.makedirs(os.path.join(settings.STORAGE_DIR, "scans"), exist_ok=True)
    os.makedirs("ml/models", exist_ok=True)

    # Initialize SQLite tables
    Base.metadata.create_all(bind=engine)
    logger.info("Database schemas initialized.")

    # Pre-warm OpenAI CLIP banana check model in background thread
    try:
        import threading
        from app.services.image_utils import _get_clip
        threading.Thread(target=_get_clip, daemon=True, name="clip_warmup").start()
        logger.info("OpenAI CLIP ViT-B/32 banana-check model pre-warming initiated.")
    except Exception as e:
        logger.warning(f"Could not warm up CLIP: {e}")

    # Ensure persistent seed user account dvk@gmail.com exists
    try:
        from app.db.session import SessionLocal
        from app.db.models import User, Scan
        db = SessionLocal()
        dvk_user = db.query(User).filter(User.email == "dvk@gmail.com").first()
        if not dvk_user:
            dvk_user = User(
                id="b40daecb-6f6e-4613-8ed0-d474e92a5c68",
                email="dvk@gmail.com",
                hashed_password="$2b$12$r6bO5DHDz9XR/84JmoCD9.B9lXBQWwqD06FDjOFvBGHmdiczK9Gtu",
                full_name="Dhanaja Kulathunga",
                preferred_language="en",
                is_active=True
            )
            db.add(dvk_user)
            db.commit()
            logger.info("Persistent user account dvk@gmail.com seeded successfully.")
        
        # Ensure any orphaned scans are linked to this user
        db.query(Scan).filter(Scan.user_id == "09a59f13-f376-4053-98e4-edd0e2138487").update(
            {"user_id": "b40daecb-6f6e-4613-8ed0-d474e92a5c68"}
        )
        db.commit()
        db.close()
    except Exception as e:
        logger.warning(f"Could not verify seed user: {e}")

    yield
    # Shutdown
    logger.info("Shutting down BananaGuard AI Backend Application.")


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="BananaGuard AI - Research Diagnostic API for Banana Defects, Diseases & Severity Estimation",
    lifespan=lifespan
)

# Attach rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS Middleware - allow localhost, local IPs, and tunnel domains
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://.*$",
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

# GZip compression for zero-latency transfer of heavy scan results and payload data
app.add_middleware(GZipMiddleware, minimum_size=1000)


# Global Custom Exception Handling for structured bilingual errors
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    if isinstance(exc.detail, dict):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "detail": exc.detail,
                "error": exc.detail,
            }
        )
    detail = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": f"HTTP_{exc.status_code}",
                "message_en": detail,
                "message_si": "ඉල්ලීම සැකසීමේදී දෝෂයක් සිදු විය. කරුණාකර නැවත උත්සාහ කරන්න."
            }
        }
    )



@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": {
                "code": "VALIDATION_ERROR",
                "message_en": str(exc.errors()),
                "message_si": "ඇතුළත් කළ දත්තවල ආකෘතිය වැරදිය. කරුණාකර නිවැරදි තොරතුරු සපයන්න."
            }
        }
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    logger.exception(f"Unhandled server error: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message_en": "An unexpected server error occurred. Please retry.",
                "message_si": "අභ්‍යන්තර සේවාදායක දෝෂයක් සිදු විය. කරුණාකර නැවත උත්සාහ කරන්න."
            }
        }
    )


# Include Routers
app.include_router(health.router)
app.include_router(auth.router)
app.include_router(scan.router)
app.include_router(history.router)
app.include_router(report.router)
app.include_router(meta.router)
