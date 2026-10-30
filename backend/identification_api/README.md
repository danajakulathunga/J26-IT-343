# Identification API (FastAPI Backend)

FastAPI backend service for fruit variety identification (banana: Ambul, Ambun, Anamalu, Kolikuttu, Red, Seeni), export suitability recommendations, and continuous model retraining.

---

## 1. Environment & Setup

### Requirements
- Python 3.12 (virtual environment recommended)
- Optional: NVIDIA Dedicated GPU with CUDA support

### Virtual Environment Setup & Run
```powershell
# In d:\Y4S1\Research Project\app\research_project\backend\identification_api:

# 1. Activate venv
.\venv\Scripts\Activate.ps1

# 2. Install dependencies (if needed)
pip install -r requirements.txt

# 3. Run FastAPI with hot reload
.\venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

---

## 2. Configuration (`.env`)

Hardware limits and administration keys are controlled via `.env`:

```env
ADMIN_API_KEY=testkey
RETRAIN_THRESHOLD=10
MIN_IMAGES_PER_CLASS=30
MIN_PROMOTE_ACCURACY=0.80

# Hardware Resource Limits
CPU_USAGE_LIMIT_PERCENT=35
GPU_USAGE_LIMIT_PERCENT=60
MAX_SYNC_WORKERS=4
TF_INTRA_OP_THREADS=4
TF_INTER_OP_THREADS=2
CUDA_VISIBLE_DEVICES=0
GPU_MEMORY_LIMIT_MB=3686
```

- **CPU Throttling (35%):** Capped at 4 worker processes / threads on a 12-core CPU to prevent system freeze during batch preprocessing and training.
- **Dedicated GPU Throttling (60%):** Binds to NVIDIA GeForce GTX 1660 Ti (Device 0) with a memory cap of ~3.6 GB (3686 MB).

---

## 3. Dataset Directory Structure

Raw images are copied by hand into class folders under `data/images/raw/`. The sync engine processes and normalizes them into `data/images/processed/`.

```
data/
├── images/
│   ├── raw/
│   │   ├── Ambul_Banana/       # Hand-copied original images
│   │   ├── Ambun_Banana/
│   │   ├── Anamalu_Banana/
│   │   ├── Kolikuttu_Banana/
│   │   ├── Red_Banana/
│   │   └── Seeni_Banana/
│   └── processed/              # Normalized 224x224, CLAHE-enhanced JPGs
│       ├── Ambul_Banana/
│       └── ...
├── image_hashes.json           # SHA-256 deduplication registry
├── raw_index.json              # Mapping of raw file paths to hashes
├── training_state.json         # Active model metrics and image counters
└── sync_status.json            # Live progress of background sync
```

---

## 4. Raw Folder Sync Pipeline (`sync_raw.py`)

Scans `data/images/raw/`, validates dimensions and format, computes SHA-256 hashes to prevent duplicates, applies white-padding, CLAHE contrast enhancement, and noise reduction, then writes processed images to `data/images/processed/`.

- **Trigger via CLI:**
  ```powershell
  python -m app.ml.sync_raw [--class <ClassName>] [--dry-run]
  ```
- **Trigger via API:** `POST /dataset/sync`
- **Check Progress:** `GET /dataset/sync/status`
- **Mutual Exclusion:** Sync cannot run while model training is active, and vice versa (returns HTTP 409).

---

## 5. Model Training & Versioning

- **Active Production Model:**
  - Model weights: `app/ml/model/variety_classifier.keras`
  - Active classes: `app/ml/model/class_names.txt`
- **Model Versions & History:**
  - Archived runs: `app/ml/model_versions/<version_name>/` (e.g., `v0001`, `v0002`)
  - Each version directory stores:
    - `model.keras`: Candidate weights
    - `metrics.json`: Test accuracy, macro F1, confusion matrix, classification report
    - `status.txt`: `promoted` or `rejected`
    - `stage1_curves.png` & `stage2_curves.png`: Training plots
    - `train.log`: Training execution logs
- **Promotion Rule:**
  - If classes match: Candidate macro-F1 must be within 0.5% or exceed the current active model.
  - If new classes are introduced: Candidate accuracy must meet `MIN_PROMOTE_ACCURACY` (80%).
- **Rollback:** `POST /training/rollback` with `{ "version": "v0001" }` instantly hot-swaps the active model without server restarts.

---

## 6. Key API Endpoints

All administrative endpoints require the `X-API-Key: <ADMIN_API_KEY>` header.

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/predict/` | Predict variety & export recommendation from uploaded image |
| `GET` | `/dataset/stats` | Per-class counts (Raw, Processed, Unsynced) and new images count |
| `POST` | `/dataset/sync` | Starts background sync of hand-copied raw photos |
| `GET` | `/dataset/sync/status` | Live polling for sync progress (percentage, ETA, speed) |
| `POST` | `/dataset/upload` | Direct in-app multipart image upload |
| `POST` | `/training/start` | Starts model retraining background worker |
| `GET` | `/training/status` | Status of current training run and last 10 version history |
| `POST` | `/training/rollback` | Rolls back active model to a previous version |
