#!/usr/bin/env python3
"""Alleral telemetry relay — Discord webhook stays server-side only."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
import sys
import threading
import time
from collections import defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path
from queue import Empty, PriorityQueue
from typing import Any

try:
    from flask import Flask, jsonify, request, send_from_directory
except ImportError:
    print("Install dependencies: pip install -r relay/requirements.txt", file=sys.stderr)
    raise

try:
    import requests
except ImportError:
    print("Install dependencies: pip install -r relay/requirements.txt", file=sys.stderr)
    raise

try:
    import fcntl
except ImportError:
    fcntl = None  # type: ignore

APP_DIR = Path(__file__).resolve().parent
ROOT = APP_DIR.parent


def resolve_manifest_path() -> Path:
    override = os.environ.get("SCRIPTS_MANIFEST_PATH", "").strip()
    if override:
        return Path(override)
    for candidate in (
        APP_DIR / "scripts_manifest.json",
        ROOT / "cfg" / "scripts_manifest.json",
        ROOT / "config" / "scripts_manifest.json",
    ):
        if candidate.is_file():
            return candidate
    return APP_DIR / "scripts_manifest.json"


def resolve_site_path() -> Path:
    override = os.environ.get("SITE_CONFIG_PATH", "").strip()
    if override:
        return Path(override)
    for candidate in (
        APP_DIR / "site.json",
        ROOT / "cfg" / "site.json",
        ROOT / "config" / "site.json",
    ):
        if candidate.is_file():
            return candidate
    return APP_DIR / "site.json"


SITE_DIR = APP_DIR / "site"


def serve_html(name: str):
    path = SITE_DIR / name
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8"), 200, {"Content-Type": "text/html; charset=utf-8"}


def serve_asset(filename: str):
    path = (SITE_DIR / "assets" / filename).resolve()
    assets_root = (SITE_DIR / "assets").resolve()
    if not str(path).startswith(str(assets_root)) or not path.is_file():
        return None
    content_type = "application/octet-stream"
    if filename.endswith(".css"):
        content_type = "text/css; charset=utf-8"
    elif filename.endswith(".js"):
        content_type = "application/javascript; charset=utf-8"
    return path.read_text(encoding="utf-8"), 200, {"Content-Type": content_type}


def load_dotenv(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


load_dotenv(APP_DIR / ".env")
load_dotenv(ROOT / "relay" / ".env")
load_dotenv(ROOT / "backend" / ".env")
load_dotenv(ROOT / "cfg" / "telemetry.env")
load_dotenv(ROOT / "config" / "telemetry.env")

WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL", "").strip()
API_KEY = os.environ.get("TELEMETRY_API_KEY", "").strip()
BRAND = os.environ.get("TELEMETRY_BRAND", "Alleral Ops").strip()
HOST = os.environ.get("TELEMETRY_HOST", "0.0.0.0").strip()
PORT = int(os.environ.get("PORT", os.environ.get("TELEMETRY_PORT", "8787")))
MAX_QUEUE = int(os.environ.get("TELEMETRY_MAX_QUEUE", "5000"))
IP_RATE_PER_MIN = int(os.environ.get("TELEMETRY_IP_RATE_PER_MIN", "120"))
HEARTBEAT_BATCH_SEC = int(os.environ.get("TELEMETRY_HEARTBEAT_BATCH_SEC", "90"))
DISCORD_INTERVAL_SEC = float(os.environ.get("TELEMETRY_DISCORD_INTERVAL_SEC", "0.55"))
MAX_BODY_BYTES = int(os.environ.get("TELEMETRY_MAX_BODY_BYTES", "32768"))
REPLAY_CACHE_SEC = int(os.environ.get("TELEMETRY_REPLAY_CACHE_SEC", "300"))
MAX_EVENT_AGE_SEC = int(os.environ.get("TELEMETRY_MAX_EVENT_AGE_SEC", "600"))
ADMIN_API_KEY = os.environ.get("ADMIN_API_KEY", API_KEY).strip()
BAN_PARTNER_API_KEY = os.environ.get("BAN_PARTNER_API_KEY", ADMIN_API_KEY).strip()
DEV_ACCESS_KEY = os.environ.get("DEV_ACCESS_KEY", "").strip()
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").strip()
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()
SUPABASE_AUDIT_TABLE = os.environ.get("SUPABASE_AUDIT_TABLE", "alleral_audit").strip()
TURNSTILE_SITE_KEY = os.environ.get("TURNSTILE_SITE_KEY", "3x00000000000000000000FF").strip()
TURNSTILE_SECRET_KEY = os.environ.get("TURNSTILE_SECRET_KEY", "").strip()
SCRIPTS_MANIFEST_PATH = resolve_manifest_path()
MIN_API_KEY_LEN = 24

EVENT_COLORS = {
    "session_start": 10181046,
    "inject_start": 3447003,
    "inject_loaded": 3066993,
    "inject_failed": 15158332,
    "error": 15105570,
    "heartbeat": 9807270,
    "heartbeat_batch": 9807270,
    "session_end": 9936031,
    "milestone": 15844367,
    "log": 7506394,
    "hub_visit": 5793266,
    "games_sync": 5763719,
    "bug_report": 15105570,
    "feature_request": 3447003,
    "support_question": 10181046,
    "faq_feedback": 9807270,
}

TITLE_MAP = {
    "session_start": "Session started",
    "inject_start": "Inject started",
    "inject_loaded": "Inject succeeded",
    "inject_failed": "Inject failed",
    "error": "Runtime error",
    "heartbeat": "Session heartbeat",
    "heartbeat_batch": "Active sessions",
    "session_end": "Session ended",
    "milestone": "Milestone",
    "log": "Event log",
    "hub_visit": "Hub visit",
}

PRIORITY = {
    "inject_failed": 0,
    "error": 1,
    "inject_loaded": 2,
    "session_start": 3,
    "inject_start": 4,
    "session_end": 5,
    "milestone": 6,
    "log": 7,
    "heartbeat": 9,
}

from script_registry import ScriptRegistry, VALID_STATUSES
from ban_registry import BanRegistry, VALID_BAN_TYPES
from site_registry import SiteRegistry

try:
    from auto_sync import AutoSyncEngine
except ImportError:
    AutoSyncEngine = None  # type: ignore

try:
    from manage_backend import ManageBackend
except ImportError:
    ManageBackend = None  # type: ignore

try:
    from roblox_api import fetch_user, resolve_username, resolve_usernames, fetch_avatar_renders, search_users
except ImportError:
    def resolve_username(username: str):  # type: ignore
        raise RuntimeError("roblox_api unavailable")

    def resolve_usernames(usernames: list[str]):  # type: ignore
        raise RuntimeError("roblox_api unavailable")

    def fetch_user(user_id: int | str):  # type: ignore
        raise RuntimeError("roblox_api unavailable")

    def fetch_avatar_renders(user_ids: list[int | str]):  # type: ignore
        return {}

    def search_users(keyword: str, *, limit: int = 8):  # type: ignore
        raise RuntimeError("roblox_api unavailable")

_WEAO_UNAVAILABLE_META: dict[str, Any] = {"stale": False, "warning": "weao_api unavailable"}

try:
    from weao_api import fetch_all_exploits, fetch_exploit, summarize_exploits, recent_changes
except ImportError:
    def fetch_all_exploits(*, force_refresh: bool = False, live: bool = False):  # type: ignore
        return [], [], dict(_WEAO_UNAVAILABLE_META)

    def fetch_exploit(slug: str):  # type: ignore
        return None

    def summarize_exploits(exploits: list):  # type: ignore
        return {"total": 0}

    def recent_changes(limit: int = 20):  # type: ignore
        return []

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = MAX_BODY_BYTES


@app.after_request
def apply_cors(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, X-Alleral-Key, X-Admin-Key, X-Admin-Token, X-Dev-Token, X-Ban-Api-Key, X-Ban-Partner-Key, X-Alleral-Ban-Key, Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PATCH, DELETE, OPTIONS"
    return response


@app.route("/api/bootstrap", methods=["OPTIONS"])
@app.route("/api/site", methods=["OPTIONS"])
@app.route("/api/gate/config", methods=["OPTIONS"])
@app.route("/api/gate/verify", methods=["OPTIONS"])
@app.route("/api/sync/status", methods=["OPTIONS"])
@app.route("/api/support", methods=["OPTIONS"])
@app.route("/api/faq-feedback", methods=["OPTIONS"])
@app.route("/api/bug-report", methods=["OPTIONS"])
@app.route("/api/feature-request", methods=["OPTIONS"])
@app.route("/api/hub/visit", methods=["OPTIONS"])
@app.route("/api/games/thumbnails", methods=["OPTIONS"])
@app.route("/api/manage/status", methods=["OPTIONS"])
@app.route("/api/manage/audit", methods=["OPTIONS"])
@app.route("/api/manage/supabase/test", methods=["OPTIONS"])
@app.route("/api/manage/sync", methods=["OPTIONS"])
@app.route("/api/admin/login", methods=["OPTIONS"])
@app.route("/api/admin/status", methods=["OPTIONS"])
@app.route("/api/admin/logout", methods=["OPTIONS"])
@app.route("/api/dev/login", methods=["OPTIONS"])
@app.route("/api/dev/status", methods=["OPTIONS"])
@app.route("/api/dev/logout", methods=["OPTIONS"])
@app.route("/api/ban/check", methods=["OPTIONS"])
@app.route("/gate/check", methods=["OPTIONS"])
def cors_preflight():
    return "", 204


BAN_DB_PATH = Path(os.environ.get("BAN_DB_PATH", str(APP_DIR / "data" / "bans.db")))
DATA_DIR = Path(os.environ.get("ALLERAL_DATA_DIR", str(APP_DIR / "data")))


def claim_sync_webhook_notification(commit: str) -> bool:
    """Skip duplicate Discord posts when multiple workers/services sync the same commit."""
    commit = str(commit or "").strip()
    if not commit:
        return True
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    state_path = DATA_DIR / "sync_webhook_state.json"
    lock_path = DATA_DIR / "sync_webhook.lock"
    lock_fp = open(lock_path, "a+", encoding="utf-8")
    try:
        if fcntl is not None:
            fcntl.flock(lock_fp.fileno(), fcntl.LOCK_EX)
        state: dict[str, Any] = {}
        if state_path.is_file():
            try:
                raw = json.loads(state_path.read_text(encoding="utf-8"))
                if isinstance(raw, dict):
                    state = raw
            except (OSError, json.JSONDecodeError, TypeError):
                state = {}
        if state.get("lastCommit") == commit:
            return False
        state["lastCommit"] = commit
        state["lastAt"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
        state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        return True
    finally:
        if fcntl is not None:
            fcntl.flock(lock_fp.fileno(), fcntl.LOCK_UN)
        lock_fp.close()


def bootstrap_runtime_keys() -> dict[str, str]:
    """Ensure telemetry, admin, and partner REST keys exist — env overrides persisted file."""
    global API_KEY, ADMIN_API_KEY, BAN_PARTNER_API_KEY
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    path = DATA_DIR / "runtime_secrets.json"
    stored: dict[str, str] = {}
    if path.is_file():
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                stored = {str(k): str(v).strip() for k, v in raw.items() if str(v).strip()}
        except (OSError, json.JSONDecodeError, TypeError):
            stored = {}

    changed = False
    generated: list[str] = []

    def resolve(name: str, preferred: str) -> str:
        nonlocal changed
        preferred = (preferred or "").strip()
        if preferred and len(preferred) >= MIN_API_KEY_LEN:
            if stored.get(name) != preferred:
                stored[name] = preferred
                changed = True
            return preferred
        existing = (stored.get(name) or "").strip()
        if existing and len(existing) >= MIN_API_KEY_LEN:
            return existing
        new_key = secrets.token_urlsafe(36)
        stored[name] = new_key
        changed = True
        generated.append(name)
        return new_key

    telemetry_env = os.environ.get("TELEMETRY_API_KEY", "").strip()
    admin_env = os.environ.get("ADMIN_API_KEY", "").strip()
    partner_env = os.environ.get("BAN_PARTNER_API_KEY", "").strip()

    API_KEY = resolve("telemetryApiKey", telemetry_env or API_KEY)
    ADMIN_API_KEY = resolve("adminApiKey", admin_env or API_KEY)
    BAN_PARTNER_API_KEY = resolve("banPartnerApiKey", partner_env or ADMIN_API_KEY)

    if changed:
        try:
            path.write_text(json.dumps(stored, indent=2) + "\n", encoding="utf-8")
            try:
                os.chmod(path, 0o600)
            except OSError:
                pass
            if generated:
                print(
                    f"[bootstrap] Auto-provisioned API keys ({', '.join(generated)}) → {path}",
                    file=sys.stderr,
                )
        except OSError as exc:
            print(f"[bootstrap] could not persist runtime secrets: {exc}", file=sys.stderr)

    return stored


bootstrap_runtime_keys()

GITHUB_REPO = os.environ.get("GITHUB_REPO", "evanbackup1256-ship-it/kick").strip()
GITHUB_BRANCH = os.environ.get("GITHUB_BRANCH", "main").strip()
GITHUB_SYNC_SECONDS = int(os.environ.get("GITHUB_SYNC_SECONDS", "30"))
AUTO_SYNC_ENABLED = os.environ.get("AUTO_SYNC_ENABLED", "1").strip().lower() not in {"0", "false", "no"}
GATE_RATE_PER_MIN = int(os.environ.get("GATE_RATE_PER_MIN", "90"))
SCRIPT_REGISTRY = ScriptRegistry(SCRIPTS_MANIFEST_PATH)
BAN_REGISTRY = BanRegistry(BAN_DB_PATH)
SITE_REGISTRY = SiteRegistry(resolve_site_path())

MANAGE = None
if ManageBackend is not None:
    MANAGE = ManageBackend(
        DATA_DIR,
        supabase_url=SUPABASE_URL,
        supabase_service_key=SUPABASE_SERVICE_KEY,
        supabase_table=SUPABASE_AUDIT_TABLE,
        enabled=True,
    )

AUTO_SYNC = None
if AutoSyncEngine is not None:
    AUTO_SYNC = AutoSyncEngine(
        repo=GITHUB_REPO,
        branch=GITHUB_BRANCH,
        script_registry=SCRIPT_REGISTRY,
        site_registry=SITE_REGISTRY,
        data_dir=DATA_DIR,
        interval_sec=GITHUB_SYNC_SECONDS,
        enabled=AUTO_SYNC_ENABLED,
    )
GATE_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
BAN_DEMO_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
BUG_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
HUB_VISIT_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
THUMB_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
THUMB_CACHE: dict[str, tuple[str, float]] = {}
THUMB_CACHE_SEC = int(os.environ.get("THUMB_CACHE_SEC", "3600"))
BUG_RATE_PER_MIN = int(os.environ.get("BUG_RATE_PER_MIN", "6"))
HUB_VISIT_RATE_PER_MIN = int(os.environ.get("HUB_VISIT_RATE_PER_MIN", "30"))
DEV_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
DEV_SESSIONS: dict[str, float] = {}
DEV_SESSION_TTL_SEC = int(os.environ.get("DEV_SESSION_TTL_SEC", str(86400 * 7)))
DEV_RATE_PER_MIN = int(os.environ.get("DEV_RATE_PER_MIN", "12"))
ADMIN_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
ADMIN_SESSIONS: dict[str, float] = {}
ADMIN_SESSION_TTL_SEC = int(os.environ.get("ADMIN_SESSION_TTL_SEC", str(86400)))
ADMIN_REMEMBER_TTL_SEC = int(os.environ.get("ADMIN_REMEMBER_TTL_SEC", str(86400 * 365)))
ADMIN_RATE_PER_MIN = int(os.environ.get("ADMIN_RATE_PER_MIN", "20"))
THUMB_RATE_PER_MIN = int(os.environ.get("THUMB_RATE_PER_MIN", "60"))
PUBLIC_RATE_PER_MIN = int(os.environ.get("PUBLIC_RATE_PER_MIN", "120"))
BAN_DEMO_RATE_PER_MIN = int(os.environ.get("BAN_DEMO_RATE_PER_MIN", "12"))


def gate_allow_ip(ip: str) -> bool:
    now = time.time()
    window = GATE_IP_HITS[ip]
    while window and now - window[0] > 60:
        window.popleft()
    if len(window) >= GATE_RATE_PER_MIN:
        return False
    window.append(now)
    return True


def gate_authorized() -> bool:
    if not API_KEY or len(API_KEY) < MIN_API_KEY_LEN:
        return False
    provided = request.headers.get("X-Alleral-Key", "")
    return secure_compare(provided, API_KEY)


def public_allow_ip(ip: str, bucket: dict[str, deque[float]], limit: int) -> bool:
    now = time.time()
    window = bucket[ip]
    while window and now - window[0] > 60:
        window.popleft()
    if len(window) >= limit:
        return False
    window.append(now)
    return True


def parse_place_ids(raw: object) -> list[str]:
    ids: list[str] = []
    for part in str(raw or "").split(","):
        part = part.strip()
        if part.isdigit() and 1 <= len(part) <= 20:
            ids.append(part)
    return ids[:50]


def dev_enabled() -> bool:
    return bool(DEV_ACCESS_KEY) and len(DEV_ACCESS_KEY) >= MIN_API_KEY_LEN


def dev_issue_token() -> tuple[str, str]:
    token = secrets.token_urlsafe(48)
    expiry = time.time() + DEV_SESSION_TTL_SEC
    DEV_SESSIONS[token] = expiry
    return token, datetime.fromtimestamp(expiry, tz=timezone.utc).replace(microsecond=0).isoformat()


def dev_authorized() -> bool:
    token = (request.headers.get("X-Dev-Token") or "").strip()
    if not token:
        return False
    expiry = DEV_SESSIONS.get(token)
    if not expiry or time.time() > expiry:
        DEV_SESSIONS.pop(token, None)
        return False
    return True


def purge_dev_sessions() -> None:
    now = time.time()
    stale = [token for token, expiry in DEV_SESSIONS.items() if expiry <= now]
    for token in stale:
        DEV_SESSIONS.pop(token, None)


def admin_enabled() -> bool:
    return bool(ADMIN_API_KEY) and len(ADMIN_API_KEY) >= MIN_API_KEY_LEN


def admin_issue_token(*, remember: bool = False) -> tuple[str, str]:
    token = secrets.token_urlsafe(48)
    ttl = ADMIN_REMEMBER_TTL_SEC if remember else ADMIN_SESSION_TTL_SEC
    expiry = time.time() + ttl
    ADMIN_SESSIONS[token] = expiry
    return token, datetime.fromtimestamp(expiry, tz=timezone.utc).replace(microsecond=0).isoformat()


def admin_token_valid(token: str) -> bool:
    if not token:
        return False
    expiry = ADMIN_SESSIONS.get(token)
    if not expiry or time.time() > expiry:
        ADMIN_SESSIONS.pop(token, None)
        return False
    return True


def purge_admin_sessions() -> None:
    now = time.time()
    stale = [token for token, expiry in ADMIN_SESSIONS.items() if expiry <= now]
    for token in stale:
        ADMIN_SESSIONS.pop(token, None)


def build_public_site_payload() -> dict[str, Any]:
    if AUTO_SYNC is not None:
        try:
            AUTO_SYNC.request_refresh()
        except Exception as exc:
            print(f"[auto-sync] refresh trigger failed: {exc}", file=sys.stderr)
    site = SITE_REGISTRY.load()
    manifest = SCRIPT_REGISTRY.list_scripts()
    scripts = manifest.get("scripts", {})
    games_meta = site.get("games") if isinstance(site.get("games"), dict) else {}
    merged_games: dict[str, Any] = {}
    for script_id, entry in scripts.items():
        if not isinstance(entry, dict):
            continue
        meta = games_meta.get(script_id) if isinstance(games_meta.get(script_id), dict) else {}
        merged_games[script_id] = {
            **entry,
            "id": script_id,
            "placeIds": meta.get("placeIds") or [],
            "universeIds": meta.get("universeIds") or [],
            "robloxUrl": meta.get("robloxUrl") or "",
            "description": meta.get("description") or entry.get("message") or "",
            "uiTabs": meta.get("uiTabs") or [],
            "scriptFeatures": meta.get("scriptFeatures") or [],
        }
    sync_meta = AUTO_SYNC.status() if AUTO_SYNC is not None else {"autoStatus": False}
    return {
        "ok": True,
        "brand": site.get("brand") or BRAND,
        "tagline": site.get("tagline") or "",
        "announcement": site.get("announcement") or "",
        "loaderVersion": site.get("loaderVersion") or "",
        "coreVersion": site.get("coreVersion") or "",
        "uiLibrary": site.get("uiLibrary") or "",
        "uiVersion": site.get("uiVersion") or "",
        "sydePatch": site.get("sydePatch") or 0,
        "loadstring": site.get("loadstring") or "",
        "features": site.get("features") or [],
        "faq": site.get("faq") or [],
        "changelog": site.get("changelog") or [],
        "bugCategories": site.get("bugCategories") or [],
        "links": site.get("links") or {},
        "credits": site.get("credits") or {},
        "executors": site.get("executors") or [],
        "resources": site.get("resources") or [],
        "games": merged_games,
        "scriptsUpdatedAt": manifest.get("updatedAt"),
        "siteUpdatedAt": site.get("updatedAt"),
        "githubCommit": site.get("githubCommit") or sync_meta.get("commit") or "",
        "autoManaged": bool(site.get("autoManaged") or sync_meta.get("autoStatus")),
        "sync": sync_meta,
    }


def post_simple_discord_embed(title: str, color: int, fields: list[dict[str, Any]], footer: str) -> tuple[bool, str]:
    if not WEBHOOK_URL:
        return False, "webhook_unconfigured"
    embed = {
        "title": clip(title, 256),
        "color": color,
        "fields": [
            {"name": clip(field.get("name", "Field"), 256), "value": clip(field.get("value", "—"), 1024), "inline": bool(field.get("inline"))}
            for field in fields[:25]
        ],
        "footer": {"text": footer},
        "timestamp": utc_iso(),
    }
    body = json.dumps({"username": BRAND, "embeds": [embed]})
    headers = {"Content-Type": "application/json"}
    for attempt in range(2):
        try:
            response = requests.post(WEBHOOK_URL, data=body, headers=headers, timeout=12)
        except requests.RequestException as exc:
            if attempt == 0:
                time.sleep(1.5)
                continue
            return False, str(exc)
        if response.status_code == 429 and attempt == 0:
            retry = float(response.headers.get("Retry-After", "2") or 2)
            time.sleep(min(retry, 8))
            continue
        if response.status_code < 200 or response.status_code >= 300:
            return False, f"Discord HTTP {response.status_code}"
        return True, "ok"
    return False, "discord_retry_exhausted"


def submission_meta(body: dict[str, Any], client_ip: str) -> list[dict[str, Any]]:
    page = clip(body.get("pageUrl") or body.get("page") or "", 240)
    ua = clip(body.get("userAgent") or request.headers.get("User-Agent") or "", 220)
    fields: list[dict[str, Any]] = []
    if page:
        fields.append({"name": "Page", "value": page, "inline": False})
    if ua:
        fields.append({"name": "User agent", "value": ua, "inline": False})
    fields.append({"name": "Reporter IP", "value": client_ip or "unknown", "inline": False})
    return fields


def manage_audit(event: str, payload: dict[str, Any] | None = None, actor: str = "system") -> None:
    if MANAGE is None:
        return
    try:
        MANAGE.record(event, payload, actor=actor)
    except Exception as exc:
        print(f"[manage] audit failed: {exc}", file=sys.stderr)


def notify_games_sync(payload: dict[str, Any]) -> None:
    if not WEBHOOK_URL:
        return
    if os.environ.get("SYNC_GAME_WEBHOOK", "1").strip().lower() in {"0", "false", "no"}:
        return

    commit_raw = str(payload.get("commit") or "").strip()
    if not claim_sync_webhook_notification(commit_raw):
        return

    scripts = payload.get("scripts") if isinstance(payload.get("scripts"), dict) else {}
    added = scripts.get("added") or []
    removed = scripts.get("removed") or []
    version_changes = scripts.get("versionChanges") or []
    status_changes = scripts.get("statusChanges") or []
    meta_diff = payload.get("gamesMeta") or []
    commit = clip(str(payload.get("commit") or ""), 16)
    commit_msg = clip(str(payload.get("commitMessage") or ""), 200)
    total = payload.get("totalGames") or 0

    lines: list[str] = []
    if payload.get("loaderChanged"):
        lines.append(
            f"**Loader:** {payload.get('previousLoaderVersion') or '?'} → {payload.get('loaderVersion') or '?'}"
        )
    if added:
        lines.append("**New games:** " + ", ".join(f"`{g}`" for g in added[:12]))
    if removed:
        lines.append("**Removed:** " + ", ".join(f"`{g}`" for g in removed[:12]))
    for item in version_changes[:8]:
        lines.append(f"• **{item.get('name')}** v{item.get('from')} → v{item.get('to')}")
    for item in status_changes[:8]:
        lines.append(f"• **{item.get('name')}** status {item.get('from')} → {item.get('to')}")
    for item in meta_diff[:6]:
        lines.append(f"• `{item.get('id')}` {item.get('field')}: {item.get('from')} → {item.get('to')}")

    if payload.get("coreVersion") or payload.get("telemetryVersion"):
        hub_bits = []
        if payload.get("coreVersion"):
            hub_bits.append(f"core {payload.get('coreVersion')}")
        if payload.get("telemetryVersion"):
            hub_bits.append(f"telemetry {payload.get('telemetryVersion')}")
        if payload.get("analyticsVersion"):
            hub_bits.append(f"analytics {payload.get('analyticsVersion')}")
        if hub_bits:
            lines.append("**Hub:** " + ", ".join(hub_bits))

    if not lines:
        if payload.get("commitChanged"):
            lines.append(f"Hub synced · `{commit}`" + (f" — {commit_msg}" if commit_msg else ""))
        else:
            lines.append("Registry refreshed.")

    fields = [
        {"name": "Commit", "value": f"`{commit}` — {commit_msg or 'sync'}", "inline": False},
        {"name": "Supported games", "value": str(total), "inline": True},
        {"name": "Changes", "value": "\n".join(lines)[:1024], "inline": False},
    ]
    post_simple_discord_embed(
        "Hub updated" if payload.get("commitChanged") else "Games registry updated",
        EVENT_COLORS["games_sync"],
        fields,
        f"{BRAND} · auto-sync",
    )
    manage_audit("games.sync", {
        "commit": commit,
        "added": added,
        "removed": removed,
        "versionChanges": len(version_changes),
        "statusChanges": len(status_changes),
    })
    if MANAGE is not None and MANAGE.supabase_configured():
        try:
            manifest = SCRIPT_REGISTRY.list_scripts()
            scripts = manifest.get("scripts") if isinstance(manifest.get("scripts"), dict) else {}
            games_list = [{"id": sid, **entry} for sid, entry in scripts.items() if isinstance(entry, dict)]
            MANAGE.push_games_snapshot(commit, games_list)
        except Exception as exc:
            print(f"[supabase] games snapshot failed: {exc}", file=sys.stderr)


def bootstrap_auto_sync() -> None:
    global AUTO_SYNC
    if AUTO_SYNC is None:
        return
    AUTO_SYNC.notify_fn = notify_games_sync
    AUTO_SYNC.start()


bootstrap_auto_sync()


def ban_check_payload(body: dict, client_ip: str = "") -> dict[str, Any]:
    player = as_dict(body.get("player"))
    context = as_dict(body.get("context"))
    return BAN_REGISTRY.evaluate(
        user_id=player.get("userId") or body.get("userId"),
        player_name=str(player.get("name") or body.get("playerName") or ""),
        display_name=str(player.get("displayName") or body.get("displayName") or ""),
        hwid=str(body.get("hwid") or context.get("hwid") or ""),
        fingerprint=str(body.get("fingerprint") or context.get("fingerprint") or ""),
        client_ip=client_ip or str(context.get("clientIp") or ""),
        executor=str(body.get("executor") or context.get("executor") or context.get("executorSlug") or ""),
    )


def build_ban_response(body: dict, client_ip: str = "") -> dict[str, Any]:
    player = as_dict(body.get("player"))
    context = as_dict(body.get("context"))
    result = ban_check_payload(body, client_ip)
    identity = {
        "userId": player.get("userId") or body.get("userId"),
        "playerName": player.get("name") or body.get("playerName"),
        "displayName": player.get("displayName") or body.get("displayName"),
        "hwid": str(body.get("hwid") or context.get("hwid") or "") or None,
        "fingerprint": str(body.get("fingerprint") or context.get("fingerprint") or "") or None,
        "executor": str(body.get("executor") or context.get("executor") or context.get("executorSlug") or "") or None,
        "placeId": context.get("placeId") or body.get("placeId"),
        "universeId": context.get("universeId") or body.get("universeId"),
        "clientIp": client_ip or None,
    }
    if not result.get("allowed"):
        ban = result.get("ban") or {}
        return {
            "ok": True,
            "allowed": False,
            "reason": result.get("reason") or "banned",
            "banType": ban.get("ban_type") or result.get("matched"),
            "banId": ban.get("id"),
            "expiresAt": ban.get("expires_at"),
            "playerName": ban.get("player_name") or identity.get("playerName"),
            "robloxUserId": ban.get("roblox_user_id") or identity.get("userId"),
            "identity": identity,
        }
    return {"ok": True, "allowed": True, "identity": identity}


def secure_compare(provided: str, expected: str) -> bool:
    if not provided or not expected:
        return False
    return hmac.compare_digest(provided.encode("utf-8"), expected.encode("utf-8"))


def parse_event_time(value: object) -> datetime | None:
    if not value:
        return None
    text = str(value).strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except ValueError:
        return None


def event_is_fresh(payload: dict) -> bool:
    parsed = parse_event_time(payload.get("timestamp"))
    if not parsed:
        return True
    age = (datetime.now(timezone.utc) - parsed).total_seconds()
    return 0 <= age <= MAX_EVENT_AGE_SEC


def payload_fingerprint(payload: dict) -> str:
    blob = json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def clip(text: object, limit: int = 1000) -> str:
    value = str(text or "").strip()
    if len(value) <= limit:
        return value
    return value[: limit - 3] + "..."


def as_dict(value: object, string_key: str = "name") -> dict:
    if isinstance(value, dict):
        return value
    if isinstance(value, str) and value.strip():
        return {string_key: value.strip()}
    return {}


def normalize_payload(payload: dict) -> dict:
    normalized = dict(payload)
    normalized["player"] = as_dict(payload.get("player"))
    normalized["context"] = as_dict(payload.get("context"))
    error = payload.get("error")
    if isinstance(error, dict):
        normalized["error"] = error
    elif error is not None and str(error).strip():
        normalized["error"] = {"message": str(error).strip()}
    else:
        normalized["error"] = {}
    stats = normalized["context"].get("stats")
    if stats is not None and not isinstance(stats, dict):
        normalized["context"]["stats"] = {}
    exec_profile = normalized["context"].get("executorProfile")
    if exec_profile is not None and not isinstance(exec_profile, dict):
        normalized["context"]["executorProfile"] = {}
    caps = normalized["context"].get("capabilities")
    if caps is not None and not isinstance(caps, dict):
        normalized["context"]["capabilities"] = {}
    return normalized


def field(name: str, value: object, inline: bool = True) -> dict:
    text = clip(value, 1024)
    if not text:
        text = "—"
    return {"name": name, "value": f"```{text}```", "inline": inline}


def link_field(name: str, label: str, url: str, inline: bool = False) -> dict:
    url = str(url or "").strip()
    if not url:
        return field(name, "—", inline)
    return {"name": name, "value": f"[{label}]({url})", "inline": inline}


def join_url(place_id: object, job_id: object) -> str:
    return f"https://www.roblox.com/games/start?placeId={place_id}&gameInstanceId={job_id}"


def resolve_client_ip(req) -> str:
    for header in ("CF-Connecting-IP", "True-Client-IP", "X-Real-IP"):
        value = (req.headers.get(header) or "").strip()
        if value:
            return value.split(",")[0].strip()
    forwarded = (req.headers.get("X-Forwarded-For") or "").strip()
    if forwarded:
        return forwarded.split(",")[0].strip()
    return (req.remote_addr or "?").strip()


def public_base_url() -> str:
    host = (request.headers.get("X-Forwarded-Host") or request.host or "").strip()
    if not host:
        host = (request.host_url or "localhost").split("//", 1)[-1].rstrip("/")
    host = host.split(",")[0].strip()
    proto = (request.headers.get("X-Forwarded-Proto") or "").split(",")[0].strip().lower()
    if not proto:
        proto = request.scheme or "https"
    if host.endswith(".railway.app") or host.endswith(".up.railway.app"):
        proto = "https"
    return f"{proto}://{host}".rstrip("/")


def attach_client_ip(payload: dict, client_ip: str) -> dict:
    payload = normalize_payload(payload)
    context = payload.setdefault("context", {})
    if isinstance(context, dict):
        context["clientIp"] = client_ip or "?"
    return payload


def profile_url(user_id: object) -> str:
    return f"https://www.roblox.com/users/{user_id}/profile"


def avatar_url(user_id: object) -> str:
    return (
        f"https://www.roblox.com/headshot-thumbnail/image?"
        f"userId={user_id}&width=420&height=420&format=png"
    )


def format_event_log(event_log: object, limit: int = 10) -> str:
    if not isinstance(event_log, list) or not event_log:
        return "—"
    lines = []
    for entry in event_log[-limit:]:
        if not isinstance(entry, dict):
            continue
        lines.append(
            f"[{entry.get('kind', '?')}] {entry.get('at', '?')}: {entry.get('summary', '?')}"
        )
    return "\n".join(lines) if lines else "—"


def build_description(event: str, player: dict, context: dict) -> str | None:
    lines = []
    if event in {"inject_loaded", "session_start", "inject_start"}:
        join = context.get("joinUrl") or join_url(context.get("placeId"), context.get("jobId"))
        lines.append(f"**[Join this server]({join})**")
        rbx = context.get("robloxJoinUrl")
        if rbx:
            lines.append(f"[Open in Roblox app]({rbx})")
    profile = player.get("profileUrl") or profile_url(player.get("userId"))
    if profile:
        lines.append(f"[Player profile]({profile})")
    return "\n".join(lines) if lines else None


def build_embed(payload: dict) -> dict:
    payload = normalize_payload(payload)
    event = str(payload.get("event") or "unknown")
    player = payload.get("player") or {}
    context = payload.get("context") or {}
    error = payload.get("error") or {}
    exec_profile = context.get("executorProfile") or {}
    stats = context.get("stats") or {}

    executor = context.get("executor") or exec_profile.get("name")
    executor_version = context.get("executorVersion") or exec_profile.get("version")
    executor_label = f"{executor} v{executor_version}" if executor_version else executor

    fields = [
        field("Session", context.get("sessionId") or payload.get("sessionId"), True),
        field("Player", f"{player.get('name', '?')} ({player.get('userId', '?')})", False),
        field("Display", player.get("displayName") or player.get("name") or "?", True),
        field("Account age", f"{player.get('accountAge', '?')} days", True),
        field("Executor", executor_label, True),
        field(
            "HTTP / Files",
            f"http={exec_profile.get('http')} readfile={exec_profile.get('readfile')} "
            f"loadstring={exec_profile.get('loadstring')}",
            True,
        ),
        field("Loader", context.get("loaderVersion"), True),
        field("Game", context.get("gameName") or context.get("gameId"), True),
        field(
            "Script",
            f"{context.get('scriptName', '?')} v{context.get('scriptVersion', '?')}",
            True,
        ),
        link_field(
            "Join link",
            "Click to join server",
            context.get("joinUrl") or join_url(context.get("placeId"), context.get("jobId")),
            False,
        ),
        field(
            "PlaceId / Universe",
            f"{context.get('placeId')} / {context.get('universeId')}",
            True,
        ),
        field("JobId", context.get("jobId"), False),
        field("IP", context.get("clientIp"), True),
        field("Source", context.get("source"), True),
    ]

    if any(stats.get(k) is not None for k in ("pingMs", "fps", "players", "platform", "uptimeSec")):
        fields.append(
            field(
                "Live stats",
                f"ping={stats.get('pingMs', '?')}ms fps={stats.get('fps', '?')} "
                f"players={stats.get('players', '?')} platform={stats.get('platform', '?')} "
                f"uptime={stats.get('uptimeSec', '?')}s",
                False,
            )
        )

    if context.get("privateServer") is not None:
        fields.append(field("Private server", context.get("privateServer"), True))

    apis = exec_profile.get("apis")
    if isinstance(apis, list) and apis:
        fields.append(field("Executor APIs", ", ".join(str(a) for a in apis), False))

    caps = context.get("capabilities")
    if isinstance(caps, dict) and caps:
        cap_lines = ", ".join(f"{k}={v}" for k, v in sorted(caps.items()))
        fields.append(field("Loader caps", cap_lines, False))

    if context.get("durationMs"):
        fields.append(field("Inject duration", f"{context['durationMs']} ms", True))

    if error:
        fields.extend([
            field("Scope", error.get("scope"), True),
            field("Message", error.get("message"), False),
            field("Stack", error.get("stack"), False),
            field("Details", error.get("details"), False),
            field("Count", error.get("count"), True),
        ])

    if payload.get("notes"):
        fields.append(field("Notes", payload["notes"], False))

    if event in {"heartbeat", "error", "session_end"}:
        fields.append(field("Recent events", format_event_log(payload.get("eventLog")), False))

    user_id = player.get("userId")
    avatar = player.get("avatarUrl") or (avatar_url(user_id) if user_id else None)

    return {
        "title": TITLE_MAP.get(event, f"Event: {event}"),
        "description": build_description(event, player, context),
        "color": EVENT_COLORS.get(event, 16733440),
        "fields": fields[:25],
        "footer": {"text": f"{BRAND} · relay v3"},
        "timestamp": payload.get("timestamp") or utc_iso(),
        "thumbnail": {"url": avatar} if avatar else None,
        "author": {
            "name": f"{player.get('displayName') or player.get('name') or '?'} (@{player.get('name', '?')})",
            "url": player.get("profileUrl") or profile_url(user_id),
            "icon_url": avatar,
        },
    }


def build_heartbeat_batch_embed(entries: list[dict]) -> dict:
    lines = []
    games: dict[str, int] = defaultdict(int)
    for item in entries[:40]:
        item = normalize_payload(item)
        player = item.get("player") or {}
        context = item.get("context") or {}
        game = context.get("gameName") or context.get("gameId") or "?"
        games[str(game)] += 1
        ip = context.get("clientIp") or "?"
        lines.append(
            f"• {player.get('name', '?')} — {game} "
            f"({context.get('executor', '?')}, {ip}, "
            f"{context.get('uptimeSec', context.get('stats', {}).get('uptimeSec', '?'))}s)"
        )
    game_summary = ", ".join(f"{name}: {count}" for name, count in sorted(games.items(), key=lambda x: -x[1])[:8])
    return {
        "title": f"Active sessions ({len(entries)})",
        "description": f"**Games:** {game_summary or '—'}",
        "color": EVENT_COLORS["heartbeat_batch"],
        "fields": [
            field("Players online", "\n".join(lines) if lines else "—", False),
        ],
        "footer": {"text": f"{BRAND} · heartbeat batch"},
        "timestamp": utc_iso(),
    }


def build_components(player: dict, context: dict) -> list[dict] | None:
    components = []
    join = context.get("joinUrl") or join_url(context.get("placeId"), context.get("jobId"))
    profile = player.get("profileUrl") or profile_url(player.get("userId"))
    row = []
    if join:
        row.append({"type": 2, "style": 5, "label": "Join Server", "url": join})
    if profile:
        row.append({"type": 2, "style": 5, "label": "View Profile", "url": profile})
    if row:
        components.append({"type": 1, "components": row})
    return components or None


def post_discord(embed: dict, player: dict | None = None, context: dict | None = None) -> tuple[bool, str]:
    if not WEBHOOK_URL:
        return False, "DISCORD_WEBHOOK_URL is not configured"
    body: dict = {
        "username": BRAND,
        "embeds": [embed],
    }
    if player and player.get("avatarUrl"):
        body["avatar_url"] = player["avatarUrl"]
    components = build_components(player or {}, context or {})
    if components:
        body["components"] = components
    try:
        response = requests.post(
            WEBHOOK_URL,
            data=json.dumps(body),
            headers={"Content-Type": "application/json"},
            timeout=12,
        )
    except requests.RequestException as exc:
        return False, str(exc)
    if response.status_code == 429:
        retry = response.headers.get("Retry-After", "2")
        return False, f"rate_limited:{retry}"
    if response.status_code < 200 or response.status_code >= 300:
        return False, f"Discord HTTP {response.status_code}"
    return True, "ok"


class RelayEngine:
    def __init__(self) -> None:
        self.queue: PriorityQueue = PriorityQueue(maxsize=MAX_QUEUE)
        self.seq = 0
        self.lock = threading.Lock()
        self.heartbeat_buffer: list[dict] = []
        self.heartbeat_lock = threading.Lock()
        self.last_heartbeat_flush = time.time()
        self.ip_hits: dict[str, deque[float]] = defaultdict(deque)
        self.session_last: dict[str, float] = {}
        self.replay_hashes: dict[str, float] = {}
        self.stats = {
            "accepted": 0,
            "dropped": 0,
            "posted": 0,
            "failed": 0,
            "heartbeats_batched": 0,
            "rejected_replay": 0,
            "rejected_stale": 0,
        }
        self.worker = threading.Thread(target=self._worker_loop, daemon=True, name="relay-worker")
        self.worker.start()

    def _next_seq(self) -> int:
        with self.lock:
            self.seq += 1
            return self.seq

    def allow_ip(self, ip: str) -> bool:
        now = time.time()
        window = self.ip_hits[ip]
        while window and now - window[0] > 60:
            window.popleft()
        if len(window) >= IP_RATE_PER_MIN:
            return False
        window.append(now)
        return True

    def allow_session_event(self, payload: dict) -> bool:
        event = str(payload.get("event") or "")
        if event not in {"log", "heartbeat"}:
            return True
        session = str(as_dict(payload.get("context")).get("sessionId") or payload.get("sessionId") or "")
        if not session:
            return True
        now = time.time()
        key = f"{session}:{event}"
        last = self.session_last.get(key, 0)
        if event == "heartbeat" and now - last < 30:
            return False
        if event == "log" and now - last < 5:
            return False
        self.session_last[key] = now
        return True

    def allow_replay(self, payload: dict) -> bool:
        now = time.time()
        for key, seen_at in list(self.replay_hashes.items()):
            if now - seen_at > REPLAY_CACHE_SEC:
                self.replay_hashes.pop(key, None)
        digest = payload_fingerprint(payload)
        if digest in self.replay_hashes:
            self.stats["rejected_replay"] += 1
            return False
        self.replay_hashes[digest] = now
        return True

    def enqueue(self, payload: dict) -> tuple[bool, str]:
        if not event_is_fresh(payload):
            self.stats["rejected_stale"] += 1
            return False, "stale"
        if not self.allow_replay(payload):
            return True, "duplicate"
        event = str(payload.get("event") or "unknown")
        if event == "heartbeat":
            with self.heartbeat_lock:
                self.heartbeat_buffer.append(payload)
                if len(self.heartbeat_buffer) > 500:
                    self.heartbeat_buffer = self.heartbeat_buffer[-500:]
            self.stats["heartbeats_batched"] += 1
            return True, "batched"

        priority = PRIORITY.get(event, 8)
        item = (priority, self._next_seq(), payload)
        try:
            self.queue.put_nowait(item)
            self.stats["accepted"] += 1
            return True, "queued"
        except Exception:
            self.stats["dropped"] += 1
            return False, "queue_full"

    def _flush_heartbeats(self) -> None:
        with self.heartbeat_lock:
            batch = self.heartbeat_buffer
            self.heartbeat_buffer = []
        if not batch:
            return
        embed = build_heartbeat_batch_embed(batch)
        ok, detail = post_discord(embed)
        if ok:
            self.stats["posted"] += 1
        else:
            self.stats["failed"] += 1
            print(f"[relay] heartbeat batch failed: {detail}", file=sys.stderr)

    def _worker_loop(self) -> None:
        while True:
            if time.time() - self.last_heartbeat_flush >= HEARTBEAT_BATCH_SEC:
                self.last_heartbeat_flush = time.time()
                self._flush_heartbeats()

            try:
                item = self.queue.get(timeout=0.5)
            except Empty:
                continue

            _, _, payload = item
            payload = normalize_payload(payload)
            player = payload.get("player") or {}
            context = payload.get("context") or {}
            embed = build_embed(payload)

            ok = False
            detail = ""
            for attempt in range(4):
                ok, detail = post_discord(embed, player, context)
                if ok:
                    self.stats["posted"] += 1
                    break
                if detail.startswith("rate_limited:"):
                    wait = float(detail.split(":", 1)[1])
                    time.sleep(max(wait, DISCORD_INTERVAL_SEC))
                    continue
                self.stats["failed"] += 1
                print(f"[relay] post failed: {detail}", file=sys.stderr)
                break

            time.sleep(DISCORD_INTERVAL_SEC)
            self.queue.task_done()


ENGINE = RelayEngine()


def weao_module_ready() -> bool:
    try:
        from weao_api import fetch_all_exploits as _fetch  # noqa: F401
        return True
    except ImportError:
        return False


def start_weao_warm_loop() -> None:
    if not weao_module_ready():
        return

    def _loop() -> None:
        while True:
            try:
                fetch_all_exploits(live=True)
            except Exception as exc:
                print(f"[weao] warm cache failed: {exc}", file=sys.stderr)
            time.sleep(45)

    threading.Thread(target=_loop, name="weao-warm", daemon=True).start()


start_weao_warm_loop()


@app.get("/health")
def health():
    sync_meta = AUTO_SYNC.status() if AUTO_SYNC is not None else {}
    return jsonify({
        "ok": True,
        "version": "3.7.2",
        "gate": bool(API_KEY and len(API_KEY) >= MIN_API_KEY_LEN),
        "telemetry": bool(API_KEY and len(API_KEY) >= MIN_API_KEY_LEN),
        "banApi": True,
        "banApiV1": True,
        "partnerApi": ban_partner_enabled(),
        "weao": weao_module_ready(),
        "admin": admin_enabled(),
        "site": True,
        "autoSync": sync_meta.get("enabled", False),
        "githubCommit": sync_meta.get("commit") or "",
        "lastSyncAt": sync_meta.get("lastSyncAt"),
        "bans": len(BAN_REGISTRY.list_bans()),
        "endpoints": {
            "ingest": "/ingest",
            "banCheck": "/api/v1/bans/check",
            "banDocs": "/api/v1/bans/docs",
            "weao": "/api/weao/exploits",
        },
        "time": utc_iso(),
    })


@app.post("/ingest")
def ingest():
    if not API_KEY or len(API_KEY) < MIN_API_KEY_LEN:
        return jsonify({"ok": False, "error": "unavailable"}), 503

    provided = request.headers.get("X-Alleral-Key", "")
    if not secure_compare(provided, API_KEY):
        return jsonify({"ok": False, "error": "unauthorized"}), 401

    client_ip = resolve_client_ip(request)
    if not ENGINE.allow_ip(client_ip):
        return jsonify({"ok": False, "error": "rate_limited"}), 429

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400

    payload = attach_client_ip(payload, client_ip)

    ban_result = ban_check_payload(payload, client_ip)
    if not ban_result.get("allowed"):
        ban = ban_result.get("ban") or {}
        return jsonify({
            "ok": False,
            "error": "banned",
            "reason": ban_result.get("reason") or "banned",
            "banType": ban.get("ban_type"),
        }), 403

    if not payload.get("timestamp"):
        payload["timestamp"] = utc_iso()

    if not ENGINE.allow_session_event(payload):
        return jsonify({"ok": True, "status": "throttled"}), 202

    if AUTO_SYNC is not None:
        try:
            AUTO_SYNC.record_telemetry(payload)
        except Exception as exc:
            print(f"[auto-sync] telemetry record failed: {exc}", file=sys.stderr)

    ok, status = ENGINE.enqueue(payload)
    if not ok:
        if status == "stale":
            return jsonify({"ok": False, "error": "bad_request"}), 400
        return jsonify({"ok": False, "error": "unavailable"}), 503

    return jsonify({"ok": True, "status": status}), 202


def admin_authorized() -> bool:
    if not admin_enabled():
        return False
    token = (request.headers.get("X-Admin-Token") or "").strip()
    if admin_token_valid(token):
        return True
    auth = (request.headers.get("Authorization") or "").strip()
    if auth.lower().startswith("bearer "):
        bearer = auth[7:].strip()
        if admin_token_valid(bearer):
            return True
        if secure_compare(bearer, ADMIN_API_KEY):
            return True
    for header in ("X-Admin-Key", "X-Alleral-Key"):
        provided = (request.headers.get(header) or "").strip()
        if provided and secure_compare(provided, ADMIN_API_KEY):
            return True
    return False


def ban_partner_enabled() -> bool:
    return bool(BAN_PARTNER_API_KEY) and len(BAN_PARTNER_API_KEY) >= MIN_API_KEY_LEN


def ban_partner_authorized(*, write: bool = False) -> bool:
    if admin_authorized():
        return True
    if not ban_partner_enabled():
        return False
    auth = (request.headers.get("Authorization") or "").strip()
    if auth.lower().startswith("bearer "):
        bearer = auth[7:].strip()
        if secure_compare(bearer, BAN_PARTNER_API_KEY):
            return True
    for header in ("X-Ban-Api-Key", "X-Ban-Partner-Key", "X-Alleral-Ban-Key"):
        provided = (request.headers.get(header) or "").strip()
        if provided and secure_compare(provided, BAN_PARTNER_API_KEY):
            return True
    if not write and gate_authorized():
        return True
    return False


def build_ban_api_docs(base: str) -> dict[str, Any]:
    return {
        "version": "1",
        "title": "Alleral Ban API",
        "description": "Third-party REST API for checking and managing Alleral bans.",
        "authentication": {
            "headers": [
                "X-Ban-Api-Key: <BAN_PARTNER_API_KEY>",
                "Authorization: Bearer <BAN_PARTNER_API_KEY>",
                "X-Alleral-Key: <TELEMETRY_API_KEY> (check-only, loader compat)",
            ],
            "env": "Partner key auto-provisions on first boot (data/runtime_secrets.json). Override with BAN_PARTNER_API_KEY.",
            "auto": True,
        },
        "endpoints": [
            {"method": "GET", "path": "/api/v1/bans/docs", "auth": False, "desc": "This documentation JSON"},
            {"method": "GET", "path": "/api/v1/bans/status", "auth": False, "desc": "Public ban system stats"},
            {"method": "POST", "path": "/api/v1/bans/check", "auth": True, "desc": "Check if a player/hardware ID is banned"},
            {"method": "POST", "path": "/api/v1/bans/batch-check", "auth": True, "desc": "Check up to 25 players in one request"},
            {"method": "GET", "path": "/api/v1/bans/lookup", "auth": True, "desc": "Lookup by banType + value query params"},
            {"method": "GET", "path": "/api/v1/bans", "auth": True, "desc": "List active bans (optional ?q= search)"},
            {"method": "POST", "path": "/api/v1/bans", "auth": True, "desc": "Create a ban entry"},
            {"method": "DELETE", "path": "/api/v1/bans/{id}", "auth": True, "desc": "Remove a ban by ID"},
            {"method": "POST", "path": "/api/v1/bans/roblox", "auth": True, "desc": "Ban Roblox player with cascade"},
        ],
        "checkExample": {
            "url": f"{base}/api/v1/bans/check",
            "headers": {"Content-Type": "application/json", "X-Ban-Api-Key": "<key>"},
            "body": {
                "player": {"userId": 123456789, "name": "PlayerName"},
                "hwid": "optional-hwid",
                "fingerprint": "optional-fingerprint",
                "executor": "volt",
                "context": {"placeId": 89469502395769, "universeId": 10004244222},
            },
        },
    }


@app.get("/scripts")
def list_scripts():
    if AUTO_SYNC is not None:
        try:
            AUTO_SYNC.request_refresh()
        except Exception as exc:
            print(f"[auto-sync] scripts refresh trigger failed: {exc}", file=sys.stderr)
    data = SCRIPT_REGISTRY.list_scripts()
    return jsonify({"ok": True, "scripts": data.get("scripts", {}), "updatedAt": data.get("updatedAt"), "autoManaged": True})


@app.get("/scripts/<script_id>")
def get_script(script_id: str):
    entry = SCRIPT_REGISTRY.get_script(script_id)
    if not entry:
        return jsonify({"ok": False, "error": "not_found"}), 404
    return jsonify({"ok": True, "script": entry})


@app.patch("/scripts/<script_id>")
def patch_script(script_id: str):
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    try:
        updated = SCRIPT_REGISTRY.update_script(
            script_id,
            payload,
            updated_by=str(payload.get("updatedBy") or "admin"),
        )
    except KeyError:
        return jsonify({"ok": False, "error": "not_found"}), 404
    except ValueError as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    return jsonify({"ok": True, "script": updated, "validStatuses": sorted(VALID_STATUSES)})


@app.post("/gate/check")
def gate_check():
    if not gate_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401

    client_ip = resolve_client_ip(request)
    if not gate_allow_ip(client_ip):
        return jsonify({"ok": False, "error": "rate_limited"}), 429

    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400

    return jsonify(build_ban_response(body, client_ip))


@app.post("/api/ban/check")
def api_ban_check():
    return gate_check()


@app.get("/api/ban/status")
def api_ban_status():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    base = public_base_url()
    return jsonify({
        "ok": True,
        "activeBans": len(BAN_REGISTRY.list_bans()),
        "banTypes": sorted(VALID_BAN_TYPES),
        "partnerApi": ban_partner_enabled(),
        "endpoints": {
            "check": "/api/ban/check",
            "gate": "/gate/check",
            "robloxResolve": "/api/ban/roblox/resolve",
            "v1Docs": "/api/v1/bans/docs",
            "v1Check": "/api/v1/bans/check",
            "v1Lookup": "/api/v1/bans/lookup",
            "v1List": "/api/v1/bans",
        },
        "docs": build_ban_api_docs(base),
    })


@app.get("/api/v1/bans/docs")
def ban_api_v1_docs():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    base = public_base_url()
    payload = build_ban_api_docs(base)
    payload["ok"] = True
    payload["activeBans"] = len(BAN_REGISTRY.list_bans())
    payload["banTypes"] = sorted(VALID_BAN_TYPES)
    payload["partnerApi"] = ban_partner_enabled()
    payload["autoProvisioned"] = True
    payload["baseUrl"] = base
    return jsonify(payload)


@app.get("/api/v1/bans/status")
def ban_api_v1_status():
    return api_ban_status()


@app.post("/api/v1/bans/check")
def ban_api_v1_check():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    authorized = ban_partner_authorized()
    if not authorized:
        if not public_allow_ip(client_ip, BAN_DEMO_IP_HITS, BAN_DEMO_RATE_PER_MIN):
            return jsonify({
                "ok": False,
                "error": "unauthorized",
                "hint": "Use X-Ban-Api-Key or sign in on the admin panel to copy your auto-provisioned key",
            }), 401
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    return jsonify(build_ban_response(body, client_ip))


@app.post("/api/v1/bans/batch-check")
def ban_api_v1_batch_check():
    if not ban_partner_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    entries = body.get("players") or body.get("checks")
    if not isinstance(entries, list) or not entries:
        return jsonify({"ok": False, "error": "players_required"}), 400
    results = []
    for item in entries[:25]:
        if not isinstance(item, dict):
            continue
        results.append(build_ban_response(item, client_ip))
    return jsonify({"ok": True, "results": results, "count": len(results)})


@app.get("/api/v1/bans/lookup")
def ban_api_v1_lookup():
    if not ban_partner_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    ban_type = str(request.args.get("banType") or request.args.get("type") or "").strip().lower()
    value = str(request.args.get("value") or "").strip()
    if not ban_type or not value:
        return jsonify({"ok": False, "error": "banType_and_value_required"}), 400
    body = {"banType": ban_type, "value": value}
    if ban_type == "userid":
        body = {"userId": value, "player": {"userId": value}}
    elif ban_type == "username":
        body = {"playerName": value, "player": {"name": value}}
    elif ban_type == "hwid":
        body = {"hwid": value}
    elif ban_type == "fingerprint":
        body = {"fingerprint": value}
    elif ban_type == "ip":
        body = {"context": {"clientIp": value}}
    elif ban_type == "executor":
        body = {"executor": value}
    return jsonify(build_ban_response(body, client_ip))


@app.get("/api/v1/bans")
def ban_api_v1_list():
    if not ban_partner_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    query = request.args.get("q", "")
    bans = BAN_REGISTRY.list_bans(query=query)
    return jsonify({"ok": True, "bans": bans, "count": len(bans), "validBanTypes": sorted(VALID_BAN_TYPES)})


@app.post("/api/v1/bans")
def ban_api_v1_create():
    if not ban_partner_authorized(write=True):
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    try:
        created = BAN_REGISTRY.add_ban(
            str(payload.get("banType") or payload.get("ban_type") or ""),
            payload.get("value"),
            reason=str(payload.get("reason") or ""),
            player_name=str(payload.get("playerName") or payload.get("player_name") or ""),
            roblox_user_id=str(payload.get("robloxUserId") or payload.get("roblox_user_id") or ""),
            expires_at=str(payload.get("expiresAt") or payload.get("expires_at") or "") or None,
            created_by=str(payload.get("createdBy") or payload.get("created_by") or "partner-api"),
        )
    except (ValueError, RuntimeError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    manage_audit("ban.partner.add", {"ban": created}, actor="partner-api")
    return jsonify({"ok": True, "ban": created})


@app.delete("/api/v1/bans/<int:ban_id>")
def ban_api_v1_remove(ban_id: int):
    if not ban_partner_authorized(write=True):
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    if not BAN_REGISTRY.remove_ban(ban_id):
        return jsonify({"ok": False, "error": "not_found"}), 404
    manage_audit("ban.partner.remove", {"banId": ban_id}, actor="partner-api")
    return jsonify({"ok": True, "removed": ban_id})


@app.post("/api/v1/bans/roblox")
def ban_api_v1_roblox():
    if not ban_partner_authorized(write=True):
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    try:
        result = BAN_REGISTRY.ban_roblox_player(
            username=str(payload.get("username") or payload.get("playerName") or ""),
            user_id=payload.get("userId") or payload.get("user_id"),
            hwid=str(payload.get("hwid") or ""),
            fingerprint=str(payload.get("fingerprint") or ""),
            client_ip=str(payload.get("ip") or payload.get("clientIp") or ""),
            executor=str(payload.get("executor") or ""),
            reason=str(payload.get("reason") or ""),
            expires_at=str(payload.get("expiresAt") or payload.get("expires_at") or "") or None,
            created_by=str(payload.get("createdBy") or payload.get("created_by") or "partner-api"),
            cascade=bool(payload.get("cascade", True)),
            resolve_username=resolve_username,
        )
    except (ValueError, RuntimeError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    manage_audit("ban.partner.roblox", {"result": result}, actor="partner-api")
    return jsonify(result)


@app.post("/api/ban/roblox/resolve")
def api_ban_roblox_resolve():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    names = payload.get("usernames") or payload.get("username")
    if isinstance(names, str):
        names = [names]
    if not isinstance(names, list) or not names:
        return jsonify({"ok": False, "error": "usernames_required"}), 400
    try:
        profiles = resolve_usernames([str(n) for n in names if str(n).strip()])
    except RuntimeError as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502
    return jsonify({"ok": True, "profiles": profiles})


@app.get("/api/ban/roblox/<int:user_id>")
def api_ban_roblox_user(user_id: int):
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    try:
        profile = fetch_user(user_id)
    except RuntimeError as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502
    if not profile:
        return jsonify({"ok": False, "error": "not_found"}), 404
    active = [b for b in BAN_REGISTRY.list_bans() if str(b.get("roblox_user_id") or "") == str(user_id)]
    return jsonify({"ok": True, "profile": profile, "activeBans": active})


@app.get("/admin/bans")
def admin_list_bans():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    query = request.args.get("q", "")
    bans = BAN_REGISTRY.list_bans(query=query)
    return jsonify({"ok": True, "bans": bans, "validBanTypes": sorted(VALID_BAN_TYPES)})


@app.post("/admin/bans")
def admin_add_ban():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    try:
        created = BAN_REGISTRY.add_ban(
            str(payload.get("banType") or payload.get("ban_type") or ""),
            payload.get("value"),
            reason=str(payload.get("reason") or ""),
            player_name=str(payload.get("playerName") or payload.get("player_name") or ""),
            roblox_user_id=str(payload.get("robloxUserId") or payload.get("roblox_user_id") or ""),
            expires_at=str(payload.get("expiresAt") or payload.get("expires_at") or "") or None,
            created_by=str(payload.get("createdBy") or payload.get("created_by") or "admin"),
        )
    except (ValueError, RuntimeError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    manage_audit("ban.add", {"ban": created}, actor="admin")
    return jsonify({"ok": True, "ban": created})


@app.delete("/admin/bans/<int:ban_id>")
def admin_remove_ban(ban_id: int):
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    if not BAN_REGISTRY.remove_ban(ban_id):
        return jsonify({"ok": False, "error": "not_found"}), 404
    manage_audit("ban.remove", {"banId": ban_id}, actor="admin")
    return jsonify({"ok": True, "removed": ban_id})


@app.post("/admin/bans/roblox")
def admin_ban_roblox_player():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    try:
        result = BAN_REGISTRY.ban_roblox_player(
            username=str(payload.get("username") or payload.get("playerName") or ""),
            user_id=payload.get("userId") or payload.get("user_id"),
            hwid=str(payload.get("hwid") or ""),
            fingerprint=str(payload.get("fingerprint") or ""),
            client_ip=str(payload.get("ip") or payload.get("clientIp") or ""),
            executor=str(payload.get("executor") or ""),
            reason=str(payload.get("reason") or ""),
            expires_at=str(payload.get("expiresAt") or payload.get("expires_at") or "") or None,
            created_by=str(payload.get("createdBy") or payload.get("created_by") or "admin"),
            cascade=bool(payload.get("cascade", True)),
            resolve_username=resolve_username,
        )
    except (ValueError, RuntimeError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    manage_audit("ban.roblox", {"result": result}, actor="admin")
    return jsonify(result)


@app.post("/admin/bans/batch")
def admin_ban_batch():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    entries = payload.get("bans")
    if not isinstance(entries, list) or not entries:
        return jsonify({"ok": False, "error": "bans_required"}), 400
    try:
        created = BAN_REGISTRY.add_batch(entries, created_by=str(payload.get("createdBy") or "admin"))
    except (ValueError, RuntimeError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    return jsonify({"ok": True, "bans": created, "count": len(created)})


@app.get("/")
@app.get("/hub")
def site_home():
    rendered = serve_html("index.html")
    if rendered:
        return rendered
    return jsonify({"ok": True, "message": "Alleral relay online", "admin": "/admin", "siteDir": str(SITE_DIR), "siteExists": SITE_DIR.is_dir()}), 200


@app.get("/assets/<path:filename>")
def site_asset(filename: str):
    rendered = serve_asset(filename)
    if rendered:
        return rendered
    return "Asset not found", 404


@app.get("/api/bootstrap")
def client_bootstrap():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    if not API_KEY or len(API_KEY) < MIN_API_KEY_LEN:
        return jsonify({"ok": False, "error": "unavailable"}), 503
    base = public_base_url()
    return jsonify({
        "ok": True,
        "relayUrl": f"{base}/ingest",
        "gateUrl": f"{base}/gate/check",
        "banCheckUrl": f"{base}/api/ban/check",
        "banApiUrl": f"{base}/api/ban",
        "apiKey": API_KEY,
        "brand": BRAND,
    })


@app.get("/api/gate/config")
def gate_config():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    return jsonify({
        "ok": True,
        "siteKey": TURNSTILE_SITE_KEY,
        "provider": "cloudflare-turnstile",
        "required": True,
        "sessionHours": 4,
        "mode": "interactive",
        "serverVerify": bool(TURNSTILE_SECRET_KEY),
    })


@app.post("/api/gate/verify")
def gate_verify():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    token = str(body.get("token") or "").strip()
    if not token:
        return jsonify({"ok": False, "error": "missing_token"}), 400
    if not TURNSTILE_SECRET_KEY:
        return jsonify({"ok": True, "verified": True, "mode": "client_only"})
    try:
        resp = requests.post(
            "https://challenges.cloudflare.com/turnstile/v0/siteverify",
            data={"secret": TURNSTILE_SECRET_KEY, "response": token, "remoteip": client_ip},
            timeout=8,
        )
        data = resp.json()
        if data.get("success"):
            return jsonify({"ok": True, "verified": True, "mode": "server"})
        return jsonify({"ok": False, "error": "verification_failed", "codes": data.get("error-codes") or []}), 403
    except requests.RequestException as exc:
        print(f"[gate] turnstile verify failed: {exc}", file=sys.stderr)
        return jsonify({"ok": True, "verified": True, "mode": "degraded"})


def verify_form_turnstile(body: dict, client_ip: str) -> tuple[bool, str | None]:
    """Require a valid Turnstile token on form posts when secret key is configured."""
    if not TURNSTILE_SECRET_KEY:
        return True, None
    token = str(body.get("turnstileToken") or body.get("token") or "").strip()
    if not token:
        return False, "captcha_required"
    try:
        resp = requests.post(
            "https://challenges.cloudflare.com/turnstile/v0/siteverify",
            data={"secret": TURNSTILE_SECRET_KEY, "response": token, "remoteip": client_ip},
            timeout=8,
        )
        data = resp.json()
        if data.get("success"):
            return True, None
        return False, "captcha_failed"
    except requests.RequestException as exc:
        print(f"[gate] form turnstile verify failed: {exc}", file=sys.stderr)
        return False, "captcha_unavailable"


@app.get("/api/sync/status")
def sync_status():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    if AUTO_SYNC is None:
        return jsonify({"ok": True, "enabled": False, "autoStatus": False})
    return jsonify({"ok": True, **AUTO_SYNC.status()})


@app.get("/api/games/thumbnails")
def game_thumbnails():
    """Proxy Roblox game icons so the hub avoids browser CORS blocks."""
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, THUMB_IP_HITS, THUMB_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429

    place_ids = parse_place_ids(request.args.get("placeIds"))
    if not place_ids:
        return jsonify({"ok": True, "thumbnails": {}})

    now = time.time()
    thumbnails: dict[str, str] = {}
    missing: list[str] = []
    for pid in place_ids:
        cached = THUMB_CACHE.get(pid)
        if cached and now - cached[1] < THUMB_CACHE_SEC:
            thumbnails[pid] = cached[0]
        else:
            missing.append(pid)

    if missing:
        url = (
            "https://thumbnails.roblox.com/v1/places/gameicons"
            f"?placeIds={','.join(missing)}&returnPolicy=PlaceHolder"
            "&size=512x512&format=Png&isCircular=false"
        )
        try:
            resp = requests.get(url, timeout=12)
            resp.raise_for_status()
            payload = resp.json()
            for row in payload.get("data") or []:
                if row.get("state") == "Completed" and row.get("imageUrl"):
                    pid = str(row.get("targetId"))
                    image_url = str(row["imageUrl"])
                    thumbnails[pid] = image_url
                    THUMB_CACHE[pid] = (image_url, now)
        except requests.RequestException as exc:
            print(f"[thumbnails] roblox fetch failed: {exc}", file=sys.stderr)
            if thumbnails:
                return jsonify({"ok": True, "thumbnails": thumbnails, "partial": True})
            return jsonify({"ok": False, "error": "upstream_failed"}), 502

    return jsonify({"ok": True, "thumbnails": thumbnails})


def _collect_credit_members(credits: dict[str, Any]) -> list[dict[str, Any]]:
    members: list[dict[str, Any]] = []
    teams = credits.get("teams") if isinstance(credits.get("teams"), list) else []
    for team in teams:
        if not isinstance(team, dict):
            continue
        for member in team.get("members") or []:
            if isinstance(member, dict):
                members.append(member)
    return members


@app.get("/api/credits/renders")
def credits_renders():
    """Resolve Roblox avatars for credits team members (full-body + bust + headshot)."""
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, THUMB_IP_HITS, THUMB_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429

    site = SITE_REGISTRY.load()
    credits = site.get("credits") if isinstance(site.get("credits"), dict) else {}
    members = _collect_credit_members(credits)

    profiles: dict[str, dict[str, Any]] = {}
    user_ids: list[str] = []

    for member in members:
        mid = str(member.get("id") or member.get("displayName") or "").strip()
        uid = str(member.get("robloxUserId") or member.get("userId") or "").strip()
        uname = str(member.get("robloxUsername") or member.get("username") or "").strip()

        profile: dict[str, Any] | None = None
        if uid.isdigit():
            try:
                profile = fetch_user(uid)
            except Exception:
                profile = {"id": int(uid), "name": uname or uid, "displayName": member.get("displayName") or uname or uid}
        elif uname:
            try:
                profile = resolve_username(uname)
            except Exception:
                profile = None

        if not profile or not profile.get("id"):
            if mid:
                profiles[mid] = {
                    "id": mid,
                    "displayName": member.get("displayName") or uname or "Member",
                    "role": member.get("role") or "",
                    "renders": {},
                }
            continue

        uid_str = str(profile["id"])
        user_ids.append(uid_str)
        profiles[mid or uid_str] = {
            "id": mid or uid_str,
            "robloxUserId": uid_str,
            "robloxUsername": profile.get("name") or uname,
            "displayName": profile.get("displayName") or member.get("displayName") or profile.get("name"),
            "role": member.get("role") or "",
            "profileUrl": f"https://www.roblox.com/users/{uid_str}/profile",
        }

    renders: dict[str, dict[str, str]] = {}
    if user_ids:
        try:
            renders = fetch_avatar_renders(user_ids)
        except Exception as exc:
            print(f"[credits] avatar fetch failed: {exc}", file=sys.stderr)

    for entry in profiles.values():
        uid = str(entry.get("robloxUserId") or "")
        entry["renders"] = renders.get(uid, {})

    return jsonify({"ok": True, "members": profiles})


def _weao_exploits_body(
    exploits: list[Any],
    changes: list[Any],
    meta: dict[str, Any],
    *,
    live: bool,
    ok: bool = True,
) -> dict[str, Any]:
    body: dict[str, Any] = {
        "ok": ok,
        "exploits": exploits,
        "summary": summarize_exploits(exploits),
        "changes": changes,
        "recentChanges": recent_changes(20),
        "source": "weao",
        "docs": "https://docs.weao.xyz",
        "fetchedAt": utc_iso(),
        "live": live,
        "pollIntervalSec": 35 if live else 120,
        "stale": bool(meta.get("stale")),
        "warning": meta.get("warning"),
    }
    if not ok:
        body["error"] = str(meta.get("warning") or "weao_unavailable")
    return body


@app.get("/api/weao/exploits")
def weao_exploits():
    """Live executor statuses from WEAO (WhatExpsAre.Online)."""
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, THUMB_IP_HITS, THUMB_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    force = str(request.args.get("refresh") or "").lower() in {"1", "true", "yes"}
    live = force or str(request.args.get("live") or "").lower() in {"1", "true", "yes"}
    try:
        exploits, changes, meta = fetch_all_exploits(force_refresh=force, live=live)
    except RuntimeError as exc:
        meta = {"stale": False, "warning": str(exc)}
        return jsonify(_weao_exploits_body([], [], meta, live=live, ok=False)), 502

    warning = meta.get("warning")
    if not exploits and warning and not meta.get("stale"):
        return jsonify(_weao_exploits_body(exploits, changes, meta, live=live, ok=False)), 502

    return jsonify(_weao_exploits_body(exploits, changes, meta, live=live))


@app.get("/api/weao/exploits/<slug>")
def weao_exploit_detail(slug: str):
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, THUMB_IP_HITS, THUMB_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    try:
        entry = fetch_exploit(slug)
    except RuntimeError as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502
    if not entry:
        return jsonify({"ok": False, "error": "not_found"}), 404
    return jsonify({"ok": True, "exploit": entry, "source": "weao"})


@app.get("/api/site")
def public_site():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    try:
        return jsonify(build_public_site_payload())
    except Exception as exc:
        print(f"[site] /api/site failed: {exc}", file=sys.stderr)
        return jsonify({"ok": False, "error": "site_unavailable"}), 500


@app.patch("/api/site")
def admin_patch_site():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    try:
        updated = SITE_REGISTRY.patch(payload)
    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    manage_audit("site.patch", {"keys": list(payload.keys())}, actor="admin")
    return jsonify({"ok": True, "site": updated})


@app.post("/api/bug-report")
def public_bug_report():
    if not WEBHOOK_URL:
        return jsonify({"ok": False, "error": "unavailable"}), 503
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, BUG_IP_HITS, BUG_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429

    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400

    ok_captcha, captcha_err = verify_form_turnstile(body, client_ip)
    if not ok_captcha:
        return jsonify({"ok": False, "error": captcha_err or "captcha_failed"}), 403

    description = clip(body.get("description") or body.get("message"), 1800)
    if len(description) < 8:
        return jsonify({"ok": False, "error": "description_too_short"}), 400

    category = clip(body.get("category") or "Other", 64)
    game = clip(body.get("game") or body.get("gameId") or "Unknown", 120)
    roblox_user = clip(body.get("robloxUser") or body.get("username") or "Anonymous", 64)
    executor = clip(body.get("executor") or "Unknown", 64)
    contact = clip(body.get("contact") or "", 120)
    steps = clip(body.get("steps") or "", 1200)
    severity = clip(body.get("severity") or "normal", 32)

    fields = [
        {"name": "Category", "value": category, "inline": True},
        {"name": "Severity", "value": severity, "inline": True},
        {"name": "Game", "value": game, "inline": True},
        {"name": "Roblox user", "value": roblox_user, "inline": True},
        {"name": "Executor", "value": executor, "inline": True},
        {"name": "Contact", "value": contact or "—", "inline": True},
        {"name": "Description", "value": description, "inline": False},
    ]
    if steps:
        fields.append({"name": "Steps to reproduce", "value": steps, "inline": False})
    fields.extend(submission_meta(body, client_ip))

    ok, detail = post_simple_discord_embed(
        f"Bug Report — {game}",
        EVENT_COLORS["bug_report"],
        fields,
        f"{BRAND} · website bug report",
    )
    if not ok:
        return jsonify({"ok": False, "error": detail}), 503
    if MANAGE is not None:
        MANAGE.push_hub_event("bug.report", {"category": category, "game": game, "severity": severity})
    return jsonify({"ok": True, "status": "sent"})


@app.post("/api/hub/visit")
def hub_visit():
    """Log a website visit to Discord (once per browser session from the client)."""
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, HUB_VISIT_IP_HITS, HUB_VISIT_RATE_PER_MIN):
        return jsonify({"ok": True, "status": "rate_limited"}), 202

    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        body = {}

    path = clip(body.get("path") or request.path or "/", 200)
    referrer = clip(body.get("referrer") or request.headers.get("Referer") or "", 300)
    ua = clip(body.get("userAgent") or request.headers.get("User-Agent") or "", 220)
    source = clip(body.get("source") or "direct", 64)
    host = clip(body.get("host") or request.headers.get("Host") or "", 120)

    if AUTO_SYNC is not None:
        try:
            AUTO_SYNC.record_telemetry({
                "event": "hub_visit",
                "context": {"gameId": "hub", "source": source, "clientIp": client_ip},
            })
        except Exception as exc:
            print(f"[hub-visit] stats record failed: {exc}", file=sys.stderr)

    if not WEBHOOK_URL:
        return jsonify({"ok": True, "status": "accepted"}), 202

    fields = [
        {"name": "Host", "value": host or "—", "inline": True},
        {"name": "Path", "value": path or "—", "inline": True},
        {"name": "Source", "value": source, "inline": True},
        {"name": "Referrer", "value": referrer or "—", "inline": False},
        {"name": "User agent", "value": ua or "—", "inline": False},
        {"name": "IP", "value": client_ip or "unknown", "inline": False},
    ]
    ok, detail = post_simple_discord_embed(
        "Someone opened the hub",
        EVENT_COLORS["hub_visit"],
        fields,
        f"{BRAND} · website visit",
    )
    if not ok:
        print(f"[hub-visit] discord failed: {detail}", file=sys.stderr)
        return jsonify({"ok": True, "status": "queued_offline"}), 202
    if MANAGE is not None:
        MANAGE.push_hub_event("hub.visit", {"path": path, "source": source, "host": host, "ip": client_ip})
    return jsonify({"ok": True, "status": "sent"})


@app.post("/api/feature-request")
def public_feature_request():
    if not WEBHOOK_URL:
        return jsonify({"ok": False, "error": "unavailable"}), 503
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, BUG_IP_HITS, BUG_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429

    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400

    ok_captcha, captcha_err = verify_form_turnstile(body, client_ip)
    if not ok_captcha:
        return jsonify({"ok": False, "error": captcha_err or "captcha_failed"}), 403

    idea = clip(body.get("idea") or body.get("description"), 1800)
    if len(idea) < 8:
        return jsonify({"ok": False, "error": "idea_too_short"}), 400

    fields = [
        {"name": "Roblox user", "value": clip(body.get("robloxUser") or "Anonymous", 64), "inline": True},
        {"name": "Game", "value": clip(body.get("game") or "Any", 120), "inline": True},
        {"name": "Contact", "value": clip(body.get("contact") or "—", 120), "inline": True},
        {"name": "Idea", "value": idea, "inline": False},
    ]
    fields.extend(submission_meta(body, client_ip))
    ok, detail = post_simple_discord_embed(
        "Feature Request",
        EVENT_COLORS["feature_request"],
        fields,
        f"{BRAND} · website feature request",
    )
    if not ok:
        return jsonify({"ok": False, "error": detail}), 503
    if MANAGE is not None:
        MANAGE.push_hub_event("feature.request", {"game": clip(body.get("game") or "Any", 120)})
    return jsonify({"ok": True, "status": "sent"})


@app.post("/api/support")
def public_support_question():
    if not WEBHOOK_URL:
        return jsonify({"ok": False, "error": "unavailable"}), 503
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, BUG_IP_HITS, BUG_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429

    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400

    ok_captcha, captcha_err = verify_form_turnstile(body, client_ip)
    if not ok_captcha:
        return jsonify({"ok": False, "error": captcha_err or "captcha_failed"}), 403

    question = clip(body.get("question") or body.get("message"), 1800)
    if len(question) < 8:
        return jsonify({"ok": False, "error": "question_too_short"}), 400

    fields = [
        {"name": "Roblox user", "value": clip(body.get("robloxUser") or "Anonymous", 64), "inline": True},
        {"name": "Topic", "value": clip(body.get("topic") or "General", 64), "inline": True},
        {"name": "Contact", "value": clip(body.get("contact") or "—", 120), "inline": True},
        {"name": "Question", "value": question, "inline": False},
    ]
    fields.extend(submission_meta(body, client_ip))
    ok, detail = post_simple_discord_embed(
        "Support Question",
        EVENT_COLORS["support_question"],
        fields,
        f"{BRAND} · website support",
    )
    if not ok:
        return jsonify({"ok": False, "error": detail}), 503
    if MANAGE is not None:
        MANAGE.push_hub_event("support.question", {"topic": clip(body.get("topic") or "General", 64)})
    return jsonify({"ok": True, "status": "sent"})


@app.post("/api/faq-feedback")
def public_faq_feedback():
    if not WEBHOOK_URL:
        return jsonify({"ok": False, "error": "unavailable"}), 503
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, BUG_IP_HITS, BUG_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429

    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400

    helpful = body.get("helpful")
    if helpful not in {True, False, "yes", "no", 1, 0}:
        return jsonify({"ok": False, "error": "bad_request"}), 400
    is_helpful = helpful in {True, "yes", 1}

    question = clip(body.get("question") or body.get("faq") or "FAQ item", 400)
    comment = clip(body.get("comment") or "", 800)
    verdict = "Helpful" if is_helpful else "Not helpful"

    fields = [
        {"name": "Verdict", "value": verdict, "inline": True},
        {"name": "FAQ", "value": question, "inline": False},
    ]
    if comment:
        fields.append({"name": "Comment", "value": comment, "inline": False})
    fields.extend(submission_meta(body, client_ip))

    ok, detail = post_simple_discord_embed(
        f"FAQ feedback — {verdict}",
        EVENT_COLORS["faq_feedback"],
        fields,
        f"{BRAND} · FAQ feedback",
    )
    if not ok:
        return jsonify({"ok": False, "error": detail}), 503
    if MANAGE is not None:
        MANAGE.push_hub_event("faq.feedback", {"helpful": is_helpful, "question": question[:120]})
    return jsonify({"ok": True, "status": "sent"})


@app.get("/admin")
def admin_panel():
    rendered = serve_html("admin.html")
    if rendered:
        return rendered
    legacy = APP_DIR / "admin.html"
    if legacy.is_file():
        return legacy.read_text(encoding="utf-8"), 200, {"Content-Type": "text/html; charset=utf-8"}
    return "Admin UI missing", 404


@app.post("/api/admin/login")
def admin_login():
    purge_admin_sessions()
    if not admin_enabled():
        return jsonify({"ok": False, "error": "disabled", "hint": "Set ADMIN_API_KEY on Railway (24+ chars)"}), 503
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, ADMIN_IP_HITS, ADMIN_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    provided = str(body.get("key") or body.get("adminKey") or "").strip()
    if not provided or not secure_compare(provided, ADMIN_API_KEY):
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    remember = bool(body.get("remember"))
    token, expires_at = admin_issue_token(remember=remember)
    manage_audit("admin.login", {"ip": resolve_client_ip(request), "remember": remember}, actor="admin")
    return jsonify({"ok": True, "token": token, "expiresAt": expires_at, "remember": remember})


@app.get("/api/admin/users/search")
def admin_users_search():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    query = str(request.args.get("q") or request.args.get("keyword") or "").strip()
    if len(query) < 2:
        return jsonify({"ok": True, "users": []})
    try:
        limit = int(request.args.get("limit") or 8)
    except ValueError:
        limit = 8
    try:
        users = search_users(query, limit=max(1, min(limit, 25)))
    except RuntimeError as exc:
        message = str(exc)
        status = 429 if "HTTP 429" in message else 502
        return jsonify({"ok": False, "error": message}), status
    ids = [row.get("id") for row in users if row.get("id")]
    avatars = fetch_avatar_renders(ids) if ids else {}
    enriched: list[dict[str, Any]] = []
    for row in users:
        uid = str(row.get("id") or "")
        bucket = avatars.get(uid) or {}
        enriched.append(
            {
                **row,
                "headshot": bucket.get("headshot") or "",
                "profileUrl": bucket.get("profile") or f"https://www.roblox.com/users/{uid}/profile",
            }
        )
    return jsonify({"ok": True, "users": enriched, "query": query})


@app.get("/api/admin/status")
def admin_status():
    token = (request.headers.get("X-Admin-Token") or "").strip()
    if not admin_token_valid(token):
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    expiry = ADMIN_SESSIONS.get(token)
    base = public_base_url()
    return jsonify({
        "ok": True,
        "expiresAt": datetime.fromtimestamp(expiry, tz=timezone.utc).replace(microsecond=0).isoformat() if expiry else None,
        "time": utc_iso(),
        "banApi": {
            "partnerApi": ban_partner_enabled(),
            "docsUrl": f"{base}/api/v1/bans/docs",
            "checkUrl": f"{base}/api/v1/bans/check",
            "autoProvisioned": True,
        },
    })


@app.get("/api/admin/ban-api/key")
def admin_ban_api_key():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    key = BAN_PARTNER_API_KEY
    masked = f"{key[:6]}…{key[-4:]}" if len(key) > 12 else "••••"
    return jsonify({
        "ok": True,
        "partnerApi": ban_partner_enabled(),
        "key": key,
        "masked": masked,
        "header": "X-Ban-Api-Key",
        "autoProvisioned": True,
        "persistedAt": str(DATA_DIR / "runtime_secrets.json"),
    })


@app.post("/api/admin/logout")
def admin_logout():
    token = (request.headers.get("X-Admin-Token") or "").strip()
    if token:
        ADMIN_SESSIONS.pop(token, None)
    return jsonify({"ok": True})


@app.post("/api/dev/login")
def dev_login():
    purge_dev_sessions()
    if not dev_enabled():
        return jsonify({"ok": False, "error": "disabled"}), 503
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, DEV_IP_HITS, DEV_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400
    provided = str(body.get("key") or body.get("passphrase") or "").strip()
    if not provided or not secure_compare(provided, DEV_ACCESS_KEY):
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    token, expires_at = dev_issue_token()
    return jsonify({"ok": True, "token": token, "expiresAt": expires_at})


@app.get("/api/dev/status")
def dev_status():
    token = (request.headers.get("X-Dev-Token") or "").strip()
    if not dev_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    expiry = DEV_SESSIONS.get(token)
    sync_meta = AUTO_SYNC.status() if AUTO_SYNC is not None else {}
    return jsonify({
        "ok": True,
        "version": "3.7.1",
        "brand": BRAND,
        "autoSync": sync_meta.get("enabled", False),
        "githubCommit": sync_meta.get("commit") or "",
        "lastSyncAt": sync_meta.get("lastSyncAt"),
        "bans": len(BAN_REGISTRY.list_bans()),
        "devSessions": len(DEV_SESSIONS),
        "expiresAt": datetime.fromtimestamp(expiry, tz=timezone.utc).replace(microsecond=0).isoformat() if expiry else None,
        "time": utc_iso(),
    })


@app.post("/api/dev/logout")
def dev_logout():
    token = (request.headers.get("X-Dev-Token") or "").strip()
    if token:
        DEV_SESSIONS.pop(token, None)
    return jsonify({"ok": True})


@app.get("/dev")
def dev_panel():
    rendered = serve_html("dev.html")
    if rendered:
        return rendered
    return "Dev portal missing", 404


@app.get("/manage")
def manage_panel():
    rendered = serve_html("manage.html")
    if rendered:
        return rendered
    return "Manage portal missing", 404


@app.get("/api/manage/status")
def manage_status():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    meta = MANAGE.status() if MANAGE is not None else {"enabled": False, "provider": "none"}
    sync_meta = AUTO_SYNC.status() if AUTO_SYNC is not None else {}
    return jsonify({
        "ok": True,
        "brand": BRAND,
        "manage": meta,
        "sync": sync_meta,
        "bans": len(BAN_REGISTRY.list_bans()),
        "supabaseConfigured": bool(meta.get("supabaseConfigured")),
    })


@app.get("/api/manage/audit")
def manage_audit_list():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    if MANAGE is None:
        return jsonify({"ok": False, "error": "disabled"}), 503
    query = request.args.get("q", "")
    limit = int(request.args.get("limit", "50") or 50)
    events = MANAGE.list_events(limit=limit, query=query)
    return jsonify({"ok": True, "events": events, "status": MANAGE.status()})


@app.post("/api/manage/sync")
def manage_sync_push():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    if MANAGE is None:
        return jsonify({"ok": False, "error": "disabled"}), 503
    result = MANAGE.sync_pending()
    manage_audit("manage.sync", result, actor="admin")
    return jsonify(result)


@app.get("/api/manage/supabase/test")
def manage_supabase_test():
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    if MANAGE is None:
        return jsonify({"ok": False, "error": "disabled"}), 503
    result = MANAGE.test_connection()
    if result.get("ok"):
        manage_audit("supabase.test", {"status": "ok"}, actor="admin")
    return jsonify(result)


def main() -> None:
    if not WEBHOOK_URL:
        print("WARNING: DISCORD_WEBHOOK_URL is empty — set relay/.env", file=sys.stderr)
    if not API_KEY:
        print("WARNING: TELEMETRY_API_KEY is empty — ingest will reject all requests", file=sys.stderr)
    print(f"Alleral telemetry relay v3 on http://{HOST}:{PORT}")
    print(f"Queue max={MAX_QUEUE} | IP rate={IP_RATE_PER_MIN}/min | heartbeat batch={HEARTBEAT_BATCH_SEC}s")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)


if __name__ == "__main__":
    main()
