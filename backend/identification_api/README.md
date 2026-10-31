# BananaGuard AI - Identification API 🍌🔬

FastAPI backend service for automated banana cultivar recognition, disease/defect detection, severity assessment, and Grad-CAM explainable AI (XAI).

## Features

- **Cultivar Recognition**: 8 Sri Lankan banana cultivars (Cavendish, Ambul, Kolikuttu, Seeni Kesel, Rath Kesel, Anamalu, Suwandel, Puwalu).
- **Disease & Defect Classification**: 17 condition categories covering fungal, bacterial, physiological conditions, and healthy fruit.
- **Severity Assessment**: Continuous percentage severity calculation with tiered severity rating (Healthy, Mild, Moderate, Severe).
- **Explainable AI (Grad-CAM)**: Visual saliency map heatmaps highlighting regions decisive for classification.
- **Banana Validation**: OpenAI CLIP zero-shot rejection for non-banana imagery.
- **PDF Report Generation**: Agronomic recommendations and diagnostic reports.

## Getting Started

### 1. Prerequisites
- Python 3.10+
- Virtual environment (`.venv`)

### 2. Setup & Installation
```bash
# From backend/identification_api directory:
python -m venv .venv
.venv\Scripts\activate  # Windows
# source .venv/bin/activate  # Linux / macOS
pip install -r requirements.txt
```

### 3. Run Development Server
```bash
# Windows / Linux:
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

- API Base URL: `http://127.0.0.1:8000`
- Interactive OpenAPI Docs: `http://127.0.0.1:8000/docs`

> Note: `.env` configuration file is maintained at the project root directory.

### 4. Running Tests
```bash
pytest tests -v
```
