#!/usr/bin/env python3
"""Alleral telemetry relay — Discord webhook stays server-side only."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
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
    from roblox_api import fetch_user, resolve_username, resolve_usernames
except ImportError:
    def resolve_username(username: str):  # type: ignore
        raise RuntimeError("roblox_api unavailable")

    def resolve_usernames(usernames: list[str]):  # type: ignore
        raise RuntimeError("roblox_api unavailable")

    def fetch_user(user_id: int | str):  # type: ignore
        raise RuntimeError("roblox_api unavailable")

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = MAX_BODY_BYTES


@app.after_request
def apply_cors(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, X-Alleral-Key, X-Admin-Key"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PATCH, DELETE, OPTIONS"
    return response


@app.route("/api/bootstrap", methods=["OPTIONS"])
@app.route("/api/site", methods=["OPTIONS"])
@app.route("/api/gate/config", methods=["OPTIONS"])
@app.route("/api/gate/verify", methods=["OPTIONS"])
@app.route("/api/sync/status", methods=["OPTIONS"])
@app.route("/api/bug-report", methods=["OPTIONS"])
@app.route("/api/feature-request", methods=["OPTIONS"])
@app.route("/api/hub/visit", methods=["OPTIONS"])
@app.route("/api/games/thumbnails", methods=["OPTIONS"])
@app.route("/api/ban/check", methods=["OPTIONS"])
@app.route("/gate/check", methods=["OPTIONS"])
def cors_preflight():
    return "", 204


BAN_DB_PATH = Path(os.environ.get("BAN_DB_PATH", str(APP_DIR / "data" / "bans.db")))
DATA_DIR = Path(os.environ.get("ALLERAL_DATA_DIR", str(APP_DIR / "data")))
GITHUB_REPO = os.environ.get("GITHUB_REPO", "evanbackup1256-ship-it/kick").strip()
GITHUB_BRANCH = os.environ.get("GITHUB_BRANCH", "main").strip()
GITHUB_SYNC_SECONDS = int(os.environ.get("GITHUB_SYNC_SECONDS", "30"))
AUTO_SYNC_ENABLED = os.environ.get("AUTO_SYNC_ENABLED", "1").strip().lower() not in {"0", "false", "no"}
GATE_RATE_PER_MIN = int(os.environ.get("GATE_RATE_PER_MIN", "90"))
SCRIPT_REGISTRY = ScriptRegistry(SCRIPTS_MANIFEST_PATH)
BAN_REGISTRY = BanRegistry(BAN_DB_PATH)
SITE_REGISTRY = SiteRegistry(resolve_site_path())

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
    AUTO_SYNC.start()
GATE_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
BUG_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
HUB_VISIT_IP_HITS: dict[str, deque[float]] = defaultdict(deque)
BUG_RATE_PER_MIN = int(os.environ.get("BUG_RATE_PER_MIN", "6"))
HUB_VISIT_RATE_PER_MIN = int(os.environ.get("HUB_VISIT_RATE_PER_MIN", "30"))
PUBLIC_RATE_PER_MIN = int(os.environ.get("PUBLIC_RATE_PER_MIN", "120"))


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
        }
    sync_meta = AUTO_SYNC.status() if AUTO_SYNC is not None else {"autoStatus": False}
    return {
        "ok": True,
        "brand": site.get("brand") or BRAND,
        "tagline": site.get("tagline") or "",
        "announcement": site.get("announcement") or "",
        "loaderVersion": site.get("loaderVersion") or "",
        "loadstring": site.get("loadstring") or "",
        "features": site.get("features") or [],
        "faq": site.get("faq") or [],
        "changelog": site.get("changelog") or [],
        "bugCategories": site.get("bugCategories") or [],
        "links": site.get("links") or {},
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
    try:
        response = requests.post(
            WEBHOOK_URL,
            data=json.dumps({"username": BRAND, "embeds": [embed]}),
            headers={"Content-Type": "application/json"},
            timeout=12,
        )
    except requests.RequestException as exc:
        return False, str(exc)
    if response.status_code < 200 or response.status_code >= 300:
        return False, f"Discord HTTP {response.status_code}"
    return True, "ok"


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


@app.get("/health")
def health():
    sync_meta = AUTO_SYNC.status() if AUTO_SYNC is not None else {}
    return jsonify({
        "ok": True,
        "version": "3.7.1",
        "gate": True,
        "banApi": True,
        "site": True,
        "autoSync": sync_meta.get("enabled", False),
        "githubCommit": sync_meta.get("commit") or "",
        "lastSyncAt": sync_meta.get("lastSyncAt"),
        "bans": len(BAN_REGISTRY.list_bans()),
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
    if not ADMIN_API_KEY or len(ADMIN_API_KEY) < MIN_API_KEY_LEN:
        return False
    provided = request.headers.get("X-Admin-Key", "")
    return secure_compare(provided, ADMIN_API_KEY)


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
    return jsonify({
        "ok": True,
        "activeBans": len(BAN_REGISTRY.list_bans()),
        "banTypes": sorted(VALID_BAN_TYPES),
        "endpoints": {
            "check": "/api/ban/check",
            "gate": "/gate/check",
            "robloxResolve": "/api/ban/roblox/resolve",
        },
    })


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
    return jsonify({"ok": True, "ban": created})


@app.delete("/admin/bans/<int:ban_id>")
def admin_remove_ban(ban_id: int):
    if not admin_authorized():
        return jsonify({"ok": False, "error": "unauthorized"}), 401
    if not BAN_REGISTRY.remove_ban(ban_id):
        return jsonify({"ok": False, "error": "not_found"}), 404
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


@app.get("/api/sync/status")
def sync_status():
    client_ip = resolve_client_ip(request)
    if not public_allow_ip(client_ip, GATE_IP_HITS, PUBLIC_RATE_PER_MIN):
        return jsonify({"ok": False, "error": "rate_limited"}), 429
    if AUTO_SYNC is None:
        return jsonify({"ok": True, "enabled": False, "autoStatus": False})
    return jsonify({"ok": True, **AUTO_SYNC.status()})


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
    fields.append({"name": "Reporter IP", "value": client_ip or "unknown", "inline": False})

    ok, detail = post_simple_discord_embed(
        f"Bug Report — {game}",
        15105570,
        fields,
        f"{BRAND} · website bug report",
    )
    if not ok:
        return jsonify({"ok": False, "error": detail}), 503
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

    idea = clip(body.get("idea") or body.get("description"), 1800)
    if len(idea) < 8:
        return jsonify({"ok": False, "error": "idea_too_short"}), 400

    fields = [
        {"name": "Roblox user", "value": clip(body.get("robloxUser") or "Anonymous", 64), "inline": True},
        {"name": "Game", "value": clip(body.get("game") or "Any", 120), "inline": True},
        {"name": "Idea", "value": idea, "inline": False},
    ]
    ok, detail = post_simple_discord_embed(
        "Feature Request",
        3447003,
        fields,
        f"{BRAND} · website feature request",
    )
    if not ok:
        return jsonify({"ok": False, "error": detail}), 503
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
