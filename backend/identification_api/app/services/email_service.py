import asyncio
from email.message import EmailMessage
from app.core.config import settings
from app.core.logging import logger


async def send_otp_email(to_email: str, otp: str):
    """Send 6-digit OTP via SMTP. Falls back to console log in dev if SMTP not configured."""
    subject = "BananaGuard AI - Password Reset Code"
    body = f"""Hello,

You requested a password reset code for your BananaGuard AI account.
Your 6-digit verification code is:

    {otp}

This code expires in {settings.OTP_EXPIRY_MINUTES} minutes.
If you did not request this, please ignore this email.

Best regards,
BananaGuard AI Research Team
"""
    if not settings.SMTP_HOST:
        logger.info("=" * 60)
        logger.info(f"[DEV EMAIL FALLBACK] Password Reset OTP for {to_email}: {otp}")
        logger.info("=" * 60)
        return

    try:
        import aiosmtplib

        msg = EmailMessage()
        msg["From"] = settings.SMTP_FROM
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.set_content(body)

        await aiosmtplib.send(
            msg,
            hostname=settings.SMTP_HOST,
            port=settings.SMTP_PORT,
            username=settings.SMTP_USER if settings.SMTP_USER else None,
            password=settings.SMTP_PASSWORD if settings.SMTP_PASSWORD else None,
            start_tls=True if settings.SMTP_PORT == 587 else False
        )
        logger.info(f"Successfully sent OTP email to {to_email}")
    except Exception as e:
        logger.error(f"Failed to send email via SMTP ({e}). Falling back to console output.")
        logger.info(f"[DEV FALLBACK] OTP for {to_email}: {otp}")
