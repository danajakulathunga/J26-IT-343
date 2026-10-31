@echo off
title BananaGuard AI - FastAPI Backend Server
cd /d "%~dp0backend\identification_api"
echo ========================================================
echo   BananaGuard AI - Starting FastAPI Backend Server
echo ========================================================
echo.
".venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause

