"""Security helpers for the Alleral telemetry relay."""

from __future__ import annotations

import logging
import os
import re
import secrets
import time
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import urlparse

import bleach
import bcrypt
import jwt
from pydantic import BaseModel, Field, ValidationError, field_validator

logger = logging.getLogger("alleral.security")

JWT_ALG = "HS256"
JWT_ISSUER = "alleral-relay"
MIN_API_KEY_LEN = 24
_TEXT_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")
_jwt_secret_cache: str | None = None


def _jwt_secret() -> str:
    global _jwt_secret_cache
    if _jwt_secret_cache is not None:
        return _jwt_secret_cache

    secret = (
        os.environ.get("JWT_SECRET", "").strip()
        or os.environ.get("ADMIN_API_KEY", "").strip()
        or os.environ.get("API_KEY", "").strip()
    )
    if len(secret) < MIN_API_KEY_LEN:
        secret = secrets.token_urlsafe(48)
        logger.warning(
            "JWT_SECRET not configured — using ephemeral process secret; "
            "set JWT_SECRET (24+ chars) for stable admin tokens across restarts"
        )

    _jwt_secret_cache = secret
    return secret


def configure_logging() -> None:
    level = os.environ.get("LOG_LEVEL", "INFO").upper()
    logging.basicConfig(
        level=getattr(logging, level, logging.INFO),
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    )


class EnvReport(BaseModel):
    warnings: list[str] = Field(default_factory=list)
    errors: list[str] = Field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors


def validate_env() -> EnvReport:
    report = EnvReport()
    admin = os.environ.get("ADMIN_API_KEY", "").strip()
    api = os.environ.get("API_KEY", "").strip()
    if admin and len(admin) < MIN_API_KEY_LEN:
        report.warnings.append("ADMIN_API_KEY should be at least 24 characters")
    if api and len(api) < MIN_API_KEY_LEN:
        report.warnings.append("API_KEY should be at least 24 characters")
    if not os.environ.get("JWT_SECRET", "").strip():
        report.warnings.append("JWT_SECRET not set — falling back to API key material")
    turnstile = os.environ.get("TURNSTILE_SECRET_KEY", "").strip()
    site_verify = os.environ.get("TURNSTILE_SITE_VERIFY", "1").strip().lower() not in {"0", "false", "no"}
    if site_verify and not turnstile:
        report.warnings.append("TURNSTILE_SITE_VERIFY enabled but TURNSTILE_SECRET_KEY is missing")
    return report


def sanitize_text(value: object, *, max_len: int = 1800) -> str:
    raw = _TEXT_RE.sub("", str(value or "")).strip()
    cleaned = bleach.clean(raw, tags=[], attributes={}, strip=True)
    if len(cleaned) <= max_len:
        return cleaned
    return cleaned[: max_len - 3] + "..."


def hash_password(password: str) -> str:
    pwd = password.encode("utf-8")
    if len(pwd) < 8:
        raise ValueError("password_too_short")
    return bcrypt.hashpw(pwd, bcrypt.gensalt(rounds=12)).decode("utf-8")


def verify_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))
    except ValueError:
        return False


def issue_jwt(subject: str, *, ttl_sec: int, claims: dict[str, Any] | None = None) -> str:
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": subject,
        "iss": JWT_ISSUER,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=max(60, ttl_sec))).timestamp()),
        "jti": secrets.token_urlsafe(16),
    }
    if claims:
        payload.update(claims)
    return jwt.encode(payload, _jwt_secret(), algorithm=JWT_ALG)


def verify_jwt(token: str, *, subject: str | None = None) -> dict[str, Any] | None:
    if not token:
        return None
    try:
        payload = jwt.decode(
            token,
            _jwt_secret(),
            algorithms=[JWT_ALG],
            issuer=JWT_ISSUER,
            options={"require": ["exp", "iat", "sub"]},
        )
    except jwt.PyJWTError as exc:
        logger.info("jwt_invalid", extra={"reason": str(exc)})
        return None
    if subject and payload.get("sub") != subject:
        return None
    return payload


class AdminLoginInput(BaseModel):
    key: str = Field(min_length=8, max_length=256)
    remember: bool = False

    @classmethod
    def from_body(cls, body: dict[str, Any]) -> AdminLoginInput:
        return cls(
            key=str(body.get("key") or body.get("adminKey") or "").strip(),
            remember=bool(body.get("remember")),
        )


class SupportInput(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    topic: str = Field(default="General", max_length=64)
    contact: str = Field(default="", max_length=120)
    question: str = Field(min_length=8, max_length=1800)
    pageUrl: str = Field(default="", max_length=512)
    userAgent: str = Field(default="", max_length=512)
    turnstileToken: str = Field(default="", max_length=4096)

    @field_validator("username", "topic", "contact", "question", "pageUrl", "userAgent", mode="before")
    @classmethod
    def _clean(cls, value: object) -> str:
        return sanitize_text(value, max_len=1800)


class FeatureRequestInput(BaseModel):
    username: str = Field(default="Anonymous", max_length=64)
    game: str = Field(default="Any", max_length=120)
    contact: str = Field(default="", max_length=120)
    idea: str = Field(min_length=8, max_length=1800)
    pageUrl: str = Field(default="", max_length=512)
    userAgent: str = Field(default="", max_length=512)
    turnstileToken: str = Field(default="", max_length=4096)

    @field_validator("username", "game", "contact", "idea", "pageUrl", "userAgent", mode="before")
    @classmethod
    def _clean(cls, value: object) -> str:
        return sanitize_text(value, max_len=1800)


class BugReportInput(BaseModel):
    category: str = Field(min_length=1, max_length=64)
    severity: str = Field(default="normal", max_length=32)
    game: str = Field(default="", max_length=120)
    username: str = Field(min_length=1, max_length=64)
    executor: str = Field(default="", max_length=120)
    contact: str = Field(default="", max_length=120)
    description: str = Field(min_length=8, max_length=1800)
    steps: str = Field(default="", max_length=1800)
    pageUrl: str = Field(default="", max_length=512)
    userAgent: str = Field(default="", max_length=512)
    turnstileToken: str = Field(default="", max_length=4096)

    @field_validator(
        "category",
        "severity",
        "game",
        "username",
        "executor",
        "contact",
        "description",
        "steps",
        "pageUrl",
        "userAgent",
        mode="before",
    )
    @classmethod
    def _clean(cls, value: object) -> str:
        return sanitize_text(value, max_len=1800)


class FaqFeedbackInput(BaseModel):
    helpful: bool
    question: str = Field(default="", max_length=400)
    comment: str = Field(default="", max_length=800)
    pageUrl: str = Field(default="", max_length=512)

    @field_validator("helpful", mode="before")
    @classmethod
    def _normalize_helpful(cls, value: object) -> bool:
        if value in {True, "yes", 1, "true", "True"}:
            return True
        if value in {False, "no", 0, "false", "False"}:
            return False
        raise ValueError("invalid_helpful")

    @field_validator("question", "comment", "pageUrl", mode="before")
    @classmethod
    def _clean(cls, value: object) -> str:
        return sanitize_text(value, max_len=800)

    @classmethod
    def from_body(cls, body: dict[str, Any]) -> FaqFeedbackInput:
        data = dict(body)
        if "question" not in data and "faq" in data:
            data["question"] = data["faq"]
        return cls.model_validate(data)


def parse_model(model: type[BaseModel], body: object) -> tuple[BaseModel | None, dict[str, Any] | None, int | None]:
    if not isinstance(body, dict):
        return None, {"ok": False, "error": "bad_request"}, 400
    try:
        return model.model_validate(body), None, None
    except ValidationError as exc:
        logger.info("validation_failed", extra={"model": model.__name__, "errors": exc.errors()})
        return None, {"ok": False, "error": "validation_failed"}, 400


def assert_browser_origin(request, *, allowed_hosts: list[str] | None = None) -> tuple[bool, str | None]:
    """Light CSRF guard for browser form POSTs."""
    origin = (request.headers.get("Origin") or "").strip()
    referer = (request.headers.get("Referer") or "").strip()
    host = (request.headers.get("Host") or "").split(",")[0].strip().lower()
    hosts = {host}
    if allowed_hosts:
        hosts.update(h.lower() for h in allowed_hosts if h)
    if origin:
        parsed = urlparse(origin)
        if parsed.netloc.lower() not in hosts:
            return False, "invalid_origin"
    elif referer:
        parsed = urlparse(referer)
        if parsed.netloc.lower() not in hosts:
            return False, "invalid_referer"
    return True, None


def apply_security_headers(response, *, api_only: bool = False) -> Any:
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
    response.headers["Cross-Origin-Resource-Policy"] = "same-site"
    if api_only:
        response.headers["Cache-Control"] = "no-store"
    return response


def safe_error(message: str = "bad_request", *, status: int = 400, log: Exception | None = None) -> tuple[dict[str, Any], int]:
    if log is not None:
        logger.warning("api_error", exc_info=log)
    return {"ok": False, "error": message}, status
