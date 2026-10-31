import os
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator


class Settings(BaseSettings):
    PROJECT_NAME: str = "BananaGuard AI"
    VERSION: str = "1.0.0"
    API_V1_STR: str = ""

    # Mode: "demo" or "real"
    MODEL_MODE: str = "demo"
    MODEL_PATH: str = "ml/models/bananaguard_model.keras"

    # Security
    JWT_SECRET: str = "banana-guard-research-secret-key-32-chars-min!"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_MINUTES: int = 30
    REFRESH_TOKEN_DAYS: int = 14

    # Database & Storage
    DATABASE_URL: str = "sqlite:///./storage/bananaguard.db"
    STORAGE_DIR: str = "storage"
    MAX_UPLOAD_MB: int = 10

    # CORS
    CORS_ORIGINS: str = "http://localhost,http://127.0.0.1,http://10.0.2.2:8000,http://192.168.1.172,http://192.168.1.172:8000,http://192.168.8.172,http://192.168.8.172:8000"

    # SMTP for OTP / notifications
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = "no-reply@bananaguard.ai"

    # Rules
    OTP_EXPIRY_MINUTES: int = 10
    LOW_CONFIDENCE_THRESHOLD: float = 0.50

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @property
    def cors_origins_list(self) -> List[str]:
        if not self.CORS_ORIGINS:
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]


settings = Settings()
