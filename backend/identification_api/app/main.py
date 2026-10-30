import os
from dotenv import load_dotenv

# Load environment variables from .env if present
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routers import predict, recommend, alerts, dataset, training, models

app = FastAPI(title="Fruit Identification API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(predict.analyze_router)
app.include_router(predict.router)
app.include_router(recommend.router)
app.include_router(alerts.router)
app.include_router(dataset.router)
app.include_router(training.router)
app.include_router(models.router)


@app.get("/health")
def health_check():
    return {"status": "healthy"}
