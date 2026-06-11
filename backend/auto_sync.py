"""Automatic GitHub sync + telemetry-driven script status for zero-maintenance hub."""

from __future__ import annotations

import json
import os
import re
import sqlite3
import threading
import time
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import requests
except ImportError:
    requests = None  # type: ignore

VALID_STATUSES = frozenset({"working", "detected", "broken", "maintenance", "testing"})
VERSION_RE = re.compile(r'local\s+VERSION\s*=\s*"([^"]+)"', re.IGNORECASE)
SUBTITLE_RE = re.compile(r'Subtitle\s*=\s*"([^"·]+)', re.IGNORECASE)


def utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def humanize_id(script_id: str) -> str:
    return script_id.replace("_", " ").title()


class TelemetryStatsStore:
    """Shared SQLite store for inject outcomes (works across gunicorn workers)."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self.path), timeout=10)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        with self._lock:
            conn = self._connect()
            try:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS telemetry_events (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        game_id TEXT NOT NULL,
                        event TEXT NOT NULL,
                        ts REAL NOT NULL
                    )
                    """
                )
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_telemetry_game_ts ON telemetry_events(game_id, ts)"
                )
                conn.commit()
            finally:
                conn.close()

    def record(self, game_id: str, event: str) -> None:
        if not game_id or event not in {"inject_loaded", "inject_failed", "error"}:
            return
        with self._lock:
            conn = self._connect()
            try:
                conn.execute(
                    "INSERT INTO telemetry_events (game_id, event, ts) VALUES (?, ?, ?)",
                    (game_id.strip().lower(), event, time.time()),
                )
                cutoff = time.time() - (7 * 86400)
                conn.execute("DELETE FROM telemetry_events WHERE ts < ?", (cutoff,))
                conn.commit()
            finally:
                conn.close()

    def snapshot(self, game_id: str, window_hours: int = 48) -> dict[str, Any]:
        gid = game_id.strip().lower()
        cutoff = time.time() - (window_hours * 3600)
        with self._lock:
            conn = self._connect()
            try:
                rows = conn.execute(
                    """
                    SELECT event, COUNT(*) AS c, MAX(ts) AS last_ts
                    FROM telemetry_events
                    WHERE game_id = ? AND ts >= ?
                    GROUP BY event
                    """,
                    (gid, cutoff),
                ).fetchall()
            finally:
                conn.close()
        counts = {row["event"]: int(row["c"]) for row in rows}
        last_ts = max((float(row["last_ts"]) for row in rows), default=0.0)
        loaded = counts.get("inject_loaded", 0)
        failed = counts.get("inject_failed", 0)
        errors = counts.get("error", 0)
        total = loaded + failed
        return {
            "inject_loaded": loaded,
            "inject_failed": failed,
            "errors": errors,
            "total_injects": total,
            "success_rate": (loaded / total) if total else None,
            "last_event_at": datetime.fromtimestamp(last_ts, timezone.utc).isoformat() if last_ts else None,
        }


class AutoSyncEngine:
    def __init__(
        self,
        *,
        repo: str,
        branch: str,
        script_registry: Any,
        site_registry: Any,
        data_dir: Path,
        interval_sec: int = 30,
        enabled: bool = True,
    ) -> None:
        self.repo = repo.strip() or "evanbackup1256-ship-it/kick"
        self.branch = branch.strip() or "main"
        self.script_registry = script_registry
        self.site_registry = site_registry
        self.interval_sec = max(15, interval_sec)
        self.enabled = enabled
        self.data_dir = data_dir
        self.stats = TelemetryStatsStore(data_dir / "telemetry_stats.db")
        self._lock = threading.Lock()
        self._state_path = data_dir / "sync_state.json"
        self._state: dict[str, Any] = self._load_state()
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()

    def _load_state(self) -> dict[str, Any]:
        if not self._state_path.is_file():
            return {"commit": "", "lastSyncAt": None, "lastError": None, "syncCount": 0}
        try:
            data = json.loads(self._state_path.read_text(encoding="utf-8"))
            return data if isinstance(data, dict) else {}
        except (json.JSONDecodeError, OSError):
            return {"commit": "", "lastSyncAt": None, "lastError": None, "syncCount": 0}

    def _save_state(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self._state_path.write_text(json.dumps(self._state, indent=2) + "\n", encoding="utf-8")

    def status(self) -> dict[str, Any]:
        with self._lock:
            return {
                "enabled": self.enabled,
                "repo": self.repo,
                "branch": self.branch,
                "intervalSec": self.interval_sec,
                "commit": self._state.get("commit") or "",
                "lastSyncAt": self._state.get("lastSyncAt"),
                "lastError": self._state.get("lastError"),
                "syncCount": self._state.get("syncCount") or 0,
                "autoStatus": True,
            }

    def record_telemetry(self, payload: dict[str, Any]) -> None:
        if not self.enabled:
            return
        event = str(payload.get("event") or "")
        context = payload.get("context") if isinstance(payload.get("context"), dict) else {}
        game_id = (
            context.get("gameId")
            or context.get("gameName")
            or payload.get("gameId")
            or payload.get("gameName")
        )
        if game_id:
            self.stats.record(str(game_id), event)

    def start(self) -> None:
        if not self.enabled or self._thread is not None:
            return

        def runner() -> None:
            try:
                self.sync(force=True)
            except Exception as exc:
                with self._lock:
                    self._state["lastError"] = str(exc)
                    self._save_state()
            self._loop()

        self._thread = threading.Thread(target=runner, name="alleral-auto-sync", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                self.sync_if_stale(force=False)
            except Exception as exc:
                with self._lock:
                    self._state["lastError"] = str(exc)
                    self._save_state()
            self._stop.wait(self.interval_sec)

    def sync_if_stale(self, force: bool = False) -> dict[str, Any]:
        if not self.enabled:
            return self.status()
        last = self._state.get("lastSyncAt")
        if not force and last:
            try:
                last_dt = datetime.fromisoformat(str(last).replace("Z", "+00:00"))
                age = (datetime.now(timezone.utc) - last_dt).total_seconds()
                if age < self.interval_sec:
                    return self.status()
            except ValueError:
                pass
        return self.sync(force=force)

    def sync(self, force: bool = False) -> dict[str, Any]:
        if not self.enabled:
            return self.status()
        if requests is None:
            raise RuntimeError("requests not installed")

        with self._lock:
            commit_sha, commit_msg = self._fetch_head_commit()
            if not force and commit_sha and commit_sha == self._state.get("commit"):
                self._state["lastSyncAt"] = utc_iso()
                self._save_state()
                return self.status()

            release = self._fetch_json(f"cfg/release.json") or {}
            manifest = self._fetch_json("cfg/scripts_manifest.json") or {}
            site = self._fetch_json("cfg/site.json") or {}
            github_scripts = manifest.get("scripts") if isinstance(manifest.get("scripts"), dict) else {}

            discovered = self._discover_games(list(github_scripts.keys()))
            merged_scripts = self._build_scripts(github_scripts, discovered)
            manifest_payload = {
                "version": manifest.get("version") or 1,
                "updatedAt": utc_iso(),
                "syncedFrom": commit_sha or self._state.get("commit") or "",
                "autoManaged": True,
                "scripts": merged_scripts,
            }
            self.script_registry.save(manifest_payload)

            site_data = self.site_registry.load()
            site_data["loaderVersion"] = release.get("loader") or site.get("loaderVersion") or site_data.get("loaderVersion") or ""
            site_data["loadstring"] = site.get("loadstring") or site_data.get("loadstring") or ""
            site_data["tagline"] = site.get("tagline") or site_data.get("tagline") or ""
            site_data["features"] = site.get("features") or site_data.get("features") or []
            site_data["faq"] = site.get("faq") or site_data.get("faq") or []
            site_data["bugCategories"] = site.get("bugCategories") or site_data.get("bugCategories") or []
            site_data["links"] = site.get("links") or site_data.get("links") or {}
            github_games = site.get("games") if isinstance(site.get("games"), dict) else {}
            local_games = site_data.get("games") if isinstance(site_data.get("games"), dict) else {}
            site_data["games"] = {**local_games, **github_games}
            site_data["changelog"] = self._build_changelog(site.get("changelog") or [], commit_sha, commit_msg)
            site_data["autoManaged"] = True
            site_data["githubCommit"] = commit_sha or ""
            self.site_registry.save(site_data)

            self._state["commit"] = commit_sha or self._state.get("commit") or ""
            self._state["lastSyncAt"] = utc_iso()
            self._state["lastError"] = None
            self._state["syncCount"] = int(self._state.get("syncCount") or 0) + 1
            self._save_state()
            return self.status()

    def _raw_url(self, path: str) -> str:
        clean = path.lstrip("/")
        return f"https://raw.githubusercontent.com/{self.repo}/{self.branch}/{clean}"

    def _fetch_text(self, path: str, timeout: int = 12) -> str | None:
        url = self._raw_url(path)
        resp = requests.get(url, timeout=timeout, headers={"Cache-Control": "no-cache"})
        if resp.status_code == 404:
            return None
        resp.raise_for_status()
        return resp.text

    def _fetch_json(self, path: str) -> dict[str, Any] | None:
        text = self._fetch_text(path)
        if not text:
            return None
        data = json.loads(text)
        return data if isinstance(data, dict) else None

    def _fetch_head_commit(self) -> tuple[str, str]:
        url = f"https://api.github.com/repos/{self.repo}/commits/{self.branch}"
        headers = {"Accept": "application/vnd.github+json"}
        token = os.environ.get("GITHUB_TOKEN", "").strip()
        if token:
            headers["Authorization"] = f"Bearer {token}"
        resp = requests.get(url, timeout=12, headers=headers)
        if resp.status_code >= 400:
            release = self._fetch_json("cfg/release.json") or {}
            return str(release.get("commit") or ""), ""
        data = resp.json()
        sha = str(data.get("sha") or "")[:12]
        msg = str((data.get("commit") or {}).get("message") or "").split("\n")[0][:160]
        return sha, msg

    def _discover_games(self, known_ids: list[str]) -> dict[str, dict[str, Any]]:
        out: dict[str, dict[str, Any]] = {}
        ids = list(dict.fromkeys(known_ids))
        api_url = f"https://api.github.com/repos/{self.repo}/contents/games"
        headers = {"Accept": "application/vnd.github+json"}
        token = os.environ.get("GITHUB_TOKEN", "").strip()
        if token:
            headers["Authorization"] = f"Bearer {token}"
        try:
            resp = requests.get(api_url, params={"ref": self.branch}, timeout=12, headers=headers)
            if resp.status_code == 200:
                for item in resp.json():
                    if not isinstance(item, dict):
                        continue
                    name = str(item.get("name") or "")
                    if name.endswith(".luau"):
                        ids.append(name[:-5])
        except requests.RequestException:
            pass
        ids = list(dict.fromkeys(i.strip().lower() for i in ids if i))
        for script_id in ids:
            parsed = self._parse_game_file(script_id)
            if parsed:
                out[script_id] = parsed
        return out

    def _parse_game_file(self, script_id: str) -> dict[str, Any] | None:
        text = self._fetch_text(f"games/{script_id}.luau")
        if not text:
            return None
        version = "?"
        subtitle = humanize_id(script_id)
        match = VERSION_RE.search(text)
        if match:
            version = match.group(1)
        sub = SUBTITLE_RE.search(text)
        if sub:
            subtitle = sub.group(1).strip()
        return {"name": subtitle, "version": version, "existsOnGitHub": True}

    def _compute_status(self, script_id: str, base: dict[str, Any], discovered: dict[str, Any]) -> tuple[str, str]:
        info = discovered.get(script_id) or {}
        if info and not info.get("existsOnGitHub", True):
            return "maintenance", "Script file missing on GitHub."
        stats = self.stats.snapshot(script_id)
        loaded = stats["inject_loaded"]
        failed = stats["inject_failed"]
        total = stats["total_injects"]
        rate = stats["success_rate"]

        if total >= 10 and rate is not None and rate < 0.35:
            return "broken", f"Auto: low success rate ({loaded}/{total} loads, 48h)."
        if total >= 6 and rate is not None and rate < 0.55:
            return "detected", f"Auto: unstable ({loaded}/{total} loads, 48h)."
        if total >= 3 and rate is not None and rate >= 0.7:
            return "working", f"Auto: healthy ({loaded}/{total} loads, 48h)."
        if total == 0:
            manual = str(base.get("status") or "").lower()
            if manual in VALID_STATUSES:
                return manual, str(base.get("message") or "Synced from GitHub.")
            return "testing", "Auto: awaiting live telemetry."
        if total < 3:
            return "testing", f"Auto: gathering data ({loaded}/{total} loads, 48h)."
        return "working", f"Auto: OK ({loaded}/{total} loads, 48h)."

    def _build_scripts(
        self,
        github_scripts: dict[str, Any],
        discovered: dict[str, dict[str, Any]],
    ) -> dict[str, Any]:
        all_ids = set(github_scripts.keys()) | set(discovered.keys())
        merged: dict[str, Any] = {}
        for script_id in sorted(all_ids):
            base = github_scripts.get(script_id) if isinstance(github_scripts.get(script_id), dict) else {}
            info = discovered.get(script_id) or {}
            status, message = self._compute_status(script_id, base, discovered)
            merged[script_id] = {
                "name": info.get("name") or base.get("name") or humanize_id(script_id),
                "status": status,
                "version": info.get("version") or base.get("version") or "?",
                "message": message,
                "updatedAt": utc_iso(),
                "updatedBy": "auto-sync",
            }
        return merged

    def _build_changelog(
        self,
        existing: list[Any],
        commit_sha: str,
        commit_msg: str,
    ) -> list[Any]:
        entries = [e for e in existing if isinstance(e, dict)]
        if not commit_sha or not commit_msg:
            return entries
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        head_title = commit_msg[:80]
        if entries and entries[0].get("date") == today and entries[0].get("title") == head_title:
            return entries
        auto_entry = {
            "date": today,
            "title": head_title,
            "items": [f"GitHub sync · {commit_sha}"],
            "auto": True,
        }
        return [auto_entry, *entries[:12]]
