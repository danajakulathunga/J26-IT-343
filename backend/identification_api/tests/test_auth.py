import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db.session import SessionLocal
from app.db.models import User, PasswordResetOTP

client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_db():
    db = SessionLocal()
    db.query(PasswordResetOTP).delete()
    db.query(User).delete()
    db.commit()
    db.close()
    yield


def test_auth_signup_and_login_flow():
    # 1. Signup with valid payload
    signup_payload = {
        "full_name": "Kasun Perera",
        "email": "kasun@example.com",
        "password": "Password123"
    }
    res = client.post("/auth/signup", json=signup_payload)
    assert res.status_code == 201, res.text
    data = res.json()
    assert "tokens" in data
    assert "access_token" in data["tokens"]
    assert "refresh_token" in data["tokens"]
    assert data["user"]["email"] == "kasun@example.com"
    assert data["user"]["full_name"] == "Kasun Perera"

    # 2. Duplicate signup rejection
    res_dup = client.post("/auth/signup", json=signup_payload)
    assert res_dup.status_code == 400

    # 3. Invalid password (too short or missing number)
    bad_pass_payload = {
        "full_name": "Kasun Perera",
        "email": "kasun2@example.com",
        "password": "short"
    }
    res_bad = client.post("/auth/signup", json=bad_pass_payload)
    assert res_bad.status_code == 422

    # 4. Login with correct credentials
    login_payload = {
        "email": "kasun@example.com",
        "password": "Password123"
    }
    res_login = client.post("/auth/login", json=login_payload)
    assert res_login.status_code == 200
    login_data = res_login.json()
    access_token = login_data["tokens"]["access_token"]
    refresh_token = login_data["tokens"]["refresh_token"]

    # 5. Access protected route GET /users/me
    headers = {"Authorization": f"Bearer {access_token}"}
    res_me = client.get("/users/me", headers=headers)
    assert res_me.status_code == 200
    assert res_me.json()["email"] == "kasun@example.com"

    # 6. Refresh token
    res_ref = client.post("/auth/refresh", json={"refresh_token": refresh_token})
    assert res_ref.status_code == 200
    assert "access_token" in res_ref.json()


def test_forgot_and_reset_password_flow():
    # Register user first
    client.post("/auth/signup", json={
        "full_name": "Nimal Silva",
        "email": "nimal@example.com",
        "password": "InitialPass1"
    })

    # Trigger forgot-password
    res_forgot = client.post("/auth/forgot-password", json={"email": "nimal@example.com"})
    assert res_forgot.status_code == 200

    # Retrieve OTP directly from DB to simulate user receiving email
    db = SessionLocal()
    otp_record = db.query(PasswordResetOTP).filter(PasswordResetOTP.email == "nimal@example.com").first()
    assert otp_record is not None
    db.close()

    # In our implementation we can test invalid OTP
    res_wrong_otp = client.post("/auth/reset-password", json={
        "email": "nimal@example.com",
        "otp": "000000",
        "new_password": "NewSecretPass2"
    })
    assert res_wrong_otp.status_code == 400
