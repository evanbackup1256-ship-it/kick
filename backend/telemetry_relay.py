#!/usr/bin/env python3
"""Alleral telemetry relay v3 — Discord webhook stays server-side only.

Handles hundreds of concurrent players via:
  - Async ingest (202 Accepted, work queued)
  - Token-bucket rate limiting for Discord (~4 posts / 2s)
  - Heartbeat batching into periodic summary embeds
  - Per-IP and per-session spam guards

Setup:
  cp backend/.env.example backend/.env
  pip install -r backend/requirements.txt
  python backend/telemetry_relay.py
"""

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
    from flask import Flask, jsonify, request
except ImportError:
    print("Install dependencies: pip install -r backend/requirements.txt", file=sys.stderr)
    raise

try:
    import requests
except ImportError:
    print("Install dependencies: pip install -r backend/requirements.txt", file=sys.stderr)
    raise

ROOT = Path(__file__).resolve().parents[1]


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


load_dotenv(ROOT / "backend" / ".env")
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

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = MAX_BODY_BYTES


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
        player = item.get("player") or {}
        context = item.get("context") or {}
        game = context.get("gameName") or context.get("gameId") or "?"
        games[str(game)] += 1
        lines.append(
            f"• {player.get('name', '?')} — {game} "
            f"({context.get('executor', '?')}, {context.get('uptimeSec', context.get('stats', {}).get('uptimeSec', '?'))}s)"
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
        session = str((payload.get("context") or {}).get("sessionId") or payload.get("sessionId") or "")
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
    return jsonify({
        "ok": True,
        "version": "3.1",
        "time": utc_iso(),
    })


@app.post("/ingest")
def ingest():
    if not API_KEY or len(API_KEY) < MIN_API_KEY_LEN or not WEBHOOK_URL:
        return jsonify({"ok": False, "error": "unavailable"}), 503

    provided = request.headers.get("X-Alleral-Key", "")
    if not secure_compare(provided, API_KEY):
        return jsonify({"ok": False, "error": "unauthorized"}), 401

    client_ip = request.headers.get("X-Forwarded-For", request.remote_addr or "?").split(",")[0].strip()
    if not ENGINE.allow_ip(client_ip):
        return jsonify({"ok": False, "error": "rate_limited"}), 429

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "bad_request"}), 400

    if not payload.get("timestamp"):
        payload["timestamp"] = utc_iso()

    if not ENGINE.allow_session_event(payload):
        return jsonify({"ok": True, "status": "throttled"}), 202

    ok, status = ENGINE.enqueue(payload)
    if not ok:
        if status == "stale":
            return jsonify({"ok": False, "error": "bad_request"}), 400
        return jsonify({"ok": False, "error": "unavailable"}), 503

    return jsonify({"ok": True, "status": status}), 202


def main() -> None:
    if not WEBHOOK_URL:
        print("WARNING: DISCORD_WEBHOOK_URL is empty — set backend/.env", file=sys.stderr)
    if not API_KEY:
        print("WARNING: TELEMETRY_API_KEY is empty — ingest will reject all requests", file=sys.stderr)
    print(f"Alleral telemetry relay v3 on http://{HOST}:{PORT}")
    print(f"Queue max={MAX_QUEUE} | IP rate={IP_RATE_PER_MIN}/min | heartbeat batch={HEARTBEAT_BATCH_SEC}s")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)


if __name__ == "__main__":
    main()
