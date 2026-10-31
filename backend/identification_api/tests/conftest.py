import os
import sys

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.session as session_module
from app.db.models import Base
from app.main import app

# Create in-memory SQLite database dedicated exclusively to tests
TEST_DATABASE_URL = "sqlite:///file:testdb?mode=memory&cache=shared&uri=true"

test_engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

# Patch immediately at module import so any test importing SessionLocal gets TestingSessionLocal
session_module.engine = test_engine
session_module.SessionLocal = TestingSessionLocal
Base.metadata.create_all(bind=test_engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[session_module.get_db] = override_get_db

