"""Automatic GitHub sync + telemetry-driven script status for zero-maintenance hub."""

from __future__ import annotations

import json
import os
import re
import sqlite3
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

try:
    import requests
except ImportError:
    requests = None  # type: ignore

try:
    import fcntl
except ImportError:
    fcntl = None  # type: ignore

SyncNotifyFn = Callable[[dict[str, Any]], None]

VALID_STATUSES = frozenset({"working", "detected", "broken", "maintenance", "testing"})
VERSION_RE = re.compile(r'local\s+VERSION\s*=\s*"([^"]+)"', re.IGNORECASE)
SUBTITLE_RE = re.compile(r'Subtitle\s*=\s*"([^"·]+)', re.IGNORECASE)
FETCH_TIMEOUT = 5


def utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def script_snapshot(scripts: dict[str, Any]) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for script_id, entry in scripts.items():
        if not isinstance(entry, dict):
            continue
        out[str(script_id)] = {
            "name": str(entry.get("name") or humanize_id(script_id)),
            "status": str(entry.get("status") or "testing").lower(),
            "version": str(entry.get("version") or "?"),
            "message": str(entry.get("message") or "")[:200],
        }
    return out


def games_meta_snapshot(games: dict[str, Any]) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for game_id, entry in games.items():
        if not isinstance(entry, dict):
            continue
        place_ids = entry.get("placeIds") if isinstance(entry.get("placeIds"), list) else []
        out[str(game_id)] = {
            "placeIds": ",".join(str(p) for p in place_ids[:5]),
            "robloxUrl": str(entry.get("robloxUrl") or "")[:200],
            "description": str(entry.get("description") or "")[:200],
        }
    return out


def diff_script_snapshots(
    previous: dict[str, dict[str, str]],
    current: dict[str, dict[str, str]],
) -> dict[str, Any]:
    prev_ids = set(previous.keys())
    curr_ids = set(current.keys())
    added = sorted(curr_ids - prev_ids)
    removed = sorted(prev_ids - curr_ids)
    version_changes: list[dict[str, str]] = []
    status_changes: list[dict[str, str]] = []
    for script_id in sorted(curr_ids & prev_ids):
        before = previous[script_id]
        after = current[script_id]
        if before.get("version") != after.get("version"):
            version_changes.append({
                "id": script_id,
                "name": after.get("name") or script_id,
                "from": before.get("version") or "?",
                "to": after.get("version") or "?",
            })
        if before.get("status") != after.get("status"):
            status_changes.append({
                "id": script_id,
                "name": after.get("name") or script_id,
                "from": before.get("status") or "?",
                "to": after.get("status") or "?",
            })
    return {
        "added": added,
        "removed": removed,
        "versionChanges": version_changes,
        "statusChanges": status_changes,
        "totalGames": len(current),
    }


def diff_games_meta(
    previous: dict[str, dict[str, str]],
    current: dict[str, dict[str, str]],
) -> list[dict[str, str]]:
    changes: list[dict[str, str]] = []
    for game_id in sorted(set(previous.keys()) | set(current.keys())):
        before = previous.get(game_id) or {}
        after = current.get(game_id) or {}
        if before.get("placeIds") != after.get("placeIds"):
            changes.append({
                "id": game_id,
                "field": "placeIds",
                "from": before.get("placeIds") or "—",
                "to": after.get("placeIds") or "—",
            })
        if before.get("robloxUrl") != after.get("robloxUrl") and (before or after):
            changes.append({
                "id": game_id,
                "field": "robloxUrl",
                "from": before.get("robloxUrl") or "—",
                "to": after.get("robloxUrl") or "—",
            })
    return changes


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
                    """
                    CREATE TABLE IF NOT EXISTS telemetry_feed (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        ts REAL NOT NULL,
                        event TEXT NOT NULL,
                        game_id TEXT,
                        player_name TEXT,
                        player_id TEXT,
                        executor TEXT,
                        loader_version TEXT,
                        place_version TEXT,
                        previous_place_version TEXT,
                        message TEXT,
                        details TEXT
                    )
                    """
                )
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_telemetry_game_ts ON telemetry_events(game_id, ts)"
                )
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_telemetry_feed_ts ON telemetry_feed(ts DESC)"
                )
                conn.commit()
            finally:
                conn.close()

    def record(self, game_id: str, event: str) -> None:
        if not game_id or event not in {
            "inject_loaded",
            "inject_failed",
            "error",
            "place_updated",
            "milestone",
        }:
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

    def record_feed(self, payload: dict[str, Any]) -> None:
        event = str(payload.get("event") or "")
        if event not in {
            "inject_loaded",
            "inject_failed",
            "error",
            "place_updated",
            "milestone",
            "session_start",
        }:
            return
        context = payload.get("context") if isinstance(payload.get("context"), dict) else {}
        player = payload.get("player") if isinstance(payload.get("player"), dict) else {}
        error = payload.get("error") if isinstance(payload.get("error"), dict) else {}
        game_id = str(
            context.get("gameId")
            or context.get("gameName")
            or payload.get("gameId")
            or payload.get("gameName")
            or ""
        ).strip()
        message = str(error.get("message") or payload.get("notes") or event)
        details_parts = [
            error.get("details"),
            error.get("stack"),
            error.get("recentActions"),
        ]
        details = "\n".join(str(part) for part in details_parts if part)
        with self._lock:
            conn = self._connect()
            try:
                conn.execute(
                    """
                    INSERT INTO telemetry_feed (
                        ts, event, game_id, player_name, player_id, executor,
                        loader_version, place_version, previous_place_version, message, details
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        time.time(),
                        event,
                        game_id.lower() if game_id else None,
                        str(player.get("name") or ""),
                        str(player.get("userId") or ""),
                        str(context.get("executor") or ""),
                        str(context.get("loaderVersion") or ""),
                        str(context.get("placeVersion") or ""),
                        str(context.get("previousPlaceVersion") or ""),
                        message[:900],
                        details[:4000] if details else None,
                    ),
                )
                cutoff = time.time() - (7 * 86400)
                conn.execute("DELETE FROM telemetry_feed WHERE ts < ?", (cutoff,))
                # Nested subquery materializes ORDER BY + LIMIT (SQLite ignores ORDER BY in flat NOT IN subqueries).
                conn.execute(
                    """
                    DELETE FROM telemetry_feed
                    WHERE id NOT IN (
                        SELECT id FROM (
                            SELECT id FROM telemetry_feed ORDER BY ts DESC LIMIT 500
                        )
                    )
                    """
                )
                conn.commit()
            finally:
                conn.close()

    def recent_feed(self, limit: int = 40) -> list[dict[str, Any]]:
        with self._lock:
            conn = self._connect()
            try:
                rows = conn.execute(
                    """
                    SELECT ts, event, game_id, player_name, player_id, executor,
                           loader_version, place_version, previous_place_version, message, details
                    FROM telemetry_feed
                    ORDER BY ts DESC
                    LIMIT ?
                    """,
                    (max(1, min(limit, 100)),),
                ).fetchall()
            finally:
                conn.close()
        items: list[dict[str, Any]] = []
        for row in rows:
            items.append(
                {
                    "at": datetime.fromtimestamp(float(row["ts"]), timezone.utc).isoformat(),
                    "event": row["event"],
                    "gameId": row["game_id"],
                    "playerName": row["player_name"],
                    "playerId": row["player_id"],
                    "executor": row["executor"],
                    "loaderVersion": row["loader_version"],
                    "placeVersion": row["place_version"],
                    "previousPlaceVersion": row["previous_place_version"],
                    "message": row["message"],
                    "details": row["details"],
                }
            )
        return items

    def global_summary(self, window_hours: int = 48) -> dict[str, Any]:
        cutoff = time.time() - (window_hours * 3600)
        with self._lock:
            conn = self._connect()
            try:
                rows = conn.execute(
                    """
                    SELECT event, COUNT(*) AS c
                    FROM telemetry_events
                    WHERE ts >= ?
                    GROUP BY event
                    """,
                    (cutoff,),
                ).fetchall()
                place_updates = conn.execute(
                    """
                    SELECT COUNT(*) AS c
                    FROM telemetry_feed
                    WHERE ts >= ? AND event = 'place_updated'
                    """,
                    (cutoff,),
                ).fetchone()
                recent_errors = conn.execute(
                    """
                    SELECT COUNT(*) AS c
                    FROM telemetry_feed
                    WHERE ts >= ? AND event IN ('error', 'inject_failed')
                    """,
                    (cutoff,),
                ).fetchone()
            finally:
                conn.close()
        counts = {row["event"]: int(row["c"]) for row in rows}
        loaded = counts.get("inject_loaded", 0)
        failed = counts.get("inject_failed", 0)
        total = loaded + failed
        return {
            "windowHours": window_hours,
            "inject_loaded": loaded,
            "inject_failed": failed,
            "errors": counts.get("error", 0),
            "place_updated": int(place_updates["c"]) if place_updates else 0,
            "feed_errors": int(recent_errors["c"]) if recent_errors else 0,
            "success_rate": (loaded / total) if total else None,
        }

    def timeseries(self, window_hours: int = 48, bucket_hours: int = 1) -> dict[str, Any]:
        window_hours = max(1, min(window_hours, 168))
        bucket_hours = max(1, min(bucket_hours, 24))
        now = time.time()
        cutoff = now - (window_hours * 3600)
        bucket_sec = bucket_hours * 3600
        with self._lock:
            conn = self._connect()
            try:
                rows = conn.execute(
                    """
                    SELECT
                        CAST((ts - ?) / ? AS INTEGER) AS bucket_idx,
                        event,
                        COUNT(*) AS c
                    FROM telemetry_events
                    WHERE ts >= ?
                    GROUP BY bucket_idx, event
                    ORDER BY bucket_idx
                    """,
                    (cutoff, bucket_sec, cutoff),
                ).fetchall()
            finally:
                conn.close()

        bucket_count = max(1, int((window_hours + bucket_hours - 1) / bucket_hours))
        buckets: list[dict[str, Any]] = []
        for idx in range(bucket_count):
            start = cutoff + (idx * bucket_sec)
            end = min(start + bucket_sec, now)
            buckets.append(
                {
                    "at": datetime.fromtimestamp(start, timezone.utc).replace(microsecond=0).isoformat(),
                    "endAt": datetime.fromtimestamp(end, timezone.utc).replace(microsecond=0).isoformat(),
                    "inject_loaded": 0,
                    "inject_failed": 0,
                    "error": 0,
                    "place_updated": 0,
                    "milestone": 0,
                }
            )

        for row in rows:
            idx = int(row["bucket_idx"])
            if idx < 0 or idx >= len(buckets):
                continue
            event = str(row["event"])
            if event in buckets[idx]:
                buckets[idx][event] = int(row["c"])

        totals = {
            "inject_loaded": sum(b["inject_loaded"] for b in buckets),
            "inject_failed": sum(b["inject_failed"] for b in buckets),
            "error": sum(b["error"] for b in buckets),
        }
        inject_total = totals["inject_loaded"] + totals["inject_failed"]
        return {
            "windowHours": window_hours,
            "bucketHours": bucket_hours,
            "buckets": buckets,
            "totals": totals,
            "success_rate": (totals["inject_loaded"] / inject_total) if inject_total else None,
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
        notify_fn: SyncNotifyFn | None = None,
    ) -> None:
        self.repo = repo.strip() or "evanbackup1256-ship-it/-kick-loader"
        self.branch = branch.strip() or "main"
        self.script_registry = script_registry
        self.site_registry = site_registry
        self.interval_sec = max(15, interval_sec)
        self.enabled = enabled
        self.notify_fn = notify_fn
        self.data_dir = data_dir
        self.stats = TelemetryStatsStore(data_dir / "telemetry_stats.db")
        self._lock = threading.Lock()
        self._sync_in_progress = threading.Event()
        self._state_path = data_dir / "sync_state.json"
        self._state: dict[str, Any] = self._load_state()
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()
        self._started = False
        self._leader_handle = None

    def _try_become_sync_leader(self) -> bool:
        """Only one gunicorn worker should run the sync loop (shared data dir)."""
        self.data_dir.mkdir(parents=True, exist_ok=True)
        path = self.data_dir / "auto_sync.leader.lock"
        handle = open(path, "a+", encoding="utf-8")
        if fcntl is None:
            self._leader_handle = handle
            return True
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            handle.close()
            return False
        handle.seek(0)
        handle.truncate()
        handle.write(str(os.getpid()))
        handle.flush()
        self._leader_handle = handle
        return True

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
            persisted = self._load_state()
            commit = persisted.get("commit") or self._state.get("commit") or ""
            last_sync = persisted.get("lastSyncAt") or self._state.get("lastSyncAt")
            last_error = persisted.get("lastError")
            if last_error is None:
                last_error = self._state.get("lastError")
            sync_count = persisted.get("syncCount")
            if sync_count is None:
                sync_count = self._state.get("syncCount") or 0
            return {
                "enabled": self.enabled,
                "repo": self.repo,
                "branch": self.branch,
                "intervalSec": self.interval_sec,
                "commit": commit,
                "lastSyncAt": last_sync,
                "lastError": last_error,
                "syncCount": int(sync_count or 0),
                "autoStatus": True,
                "syncing": self._sync_in_progress.is_set(),
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
        self.stats.record_feed(payload)

    def start(self) -> None:
        if not self.enabled or self._started:
            return
        if not self._try_become_sync_leader():
            return
        self._started = True

        def runner() -> None:
            try:
                self.sync(force=True)
            except Exception as exc:
                self._note_error(exc)
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
                self._note_error(exc)
            self._stop.wait(self.interval_sec)

    def _note_error(self, exc: Exception) -> None:
        with self._lock:
            self._state["lastError"] = str(exc)
            self._save_state()

    def request_refresh(self) -> None:
        """Non-blocking refresh trigger for hot API paths — never stalls HTTP handlers."""
        if not self.enabled:
            return
        if self._sync_in_progress.is_set():
            return
        if not self._is_stale():
            return
        threading.Thread(target=self._safe_sync, name="alleral-auto-sync-request", daemon=True).start()

    def _is_stale(self) -> bool:
        last = self._state.get("lastSyncAt")
        if not last:
            return True
        try:
            last_dt = datetime.fromisoformat(str(last).replace("Z", "+00:00"))
            age = (datetime.now(timezone.utc) - last_dt).total_seconds()
            return age >= self.interval_sec
        except ValueError:
            return True

    def _safe_sync(self) -> None:
        try:
            self.sync(force=False)
        except Exception as exc:
            self._note_error(exc)

    def sync_if_stale(self, force: bool = False) -> dict[str, Any]:
        if not self.enabled:
            return self.status()
        if not force and not self._is_stale():
            return self.status()
        return self.sync(force=force)

    def sync(self, force: bool = False) -> dict[str, Any]:
        if not self.enabled:
            return self.status()
        if requests is None:
            raise RuntimeError("requests not installed")
        if self._sync_in_progress.is_set():
            return self.status()
        self._sync_in_progress.set()
        try:
            return self._run_sync(force=force)
        finally:
            self._sync_in_progress.clear()

    def _run_sync(self, force: bool = False) -> dict[str, Any]:
        with self._lock:
            known_commit = self._state.get("commit") or ""

        commit_sha, commit_msg = self._fetch_head_commit()
        commit_changed = bool(commit_sha and commit_sha != known_commit)
        if not force and commit_sha and commit_sha == known_commit:
            with self._lock:
                self._state["lastSyncAt"] = utc_iso()
                self._save_state()
            return self.status()

        release = self._fetch_json("cfg/release.json") or {}
        manifest = self._fetch_json("cfg/scripts_manifest.json") or {}
        site = self._fetch_json("cfg/site.json") or {}
        github_scripts = manifest.get("scripts") if isinstance(manifest.get("scripts"), dict) else {}

        discovered = self._discover_games(list(github_scripts.keys()))
        merged_scripts = self._build_scripts(github_scripts, discovered)
        manifest_payload = {
            "version": manifest.get("version") or 1,
            "updatedAt": utc_iso(),
            "syncedFrom": commit_sha or known_commit or "",
            "autoManaged": True,
            "scripts": merged_scripts,
        }
        self.script_registry.save(manifest_payload)

        site_data = self.site_registry.load()
        site_data["loaderVersion"] = release.get("loader") or site.get("loaderVersion") or site_data.get("loaderVersion") or ""
        site_data["coreVersion"] = release.get("core") or site.get("coreVersion") or site_data.get("coreVersion") or ""
        site_data["uiLibrary"] = release.get("ui") or site.get("uiLibrary") or site_data.get("uiLibrary") or ""
        site_data["uiVersion"] = release.get("alleral") or release.get("windui") or site.get("uiVersion") or site_data.get("uiVersion") or ""
        if release.get("sydePatch") is not None:
            site_data["sydePatch"] = int(release.get("sydePatch") or 0)
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
        site_data["githubCommit"] = commit_sha or release.get("commit") or known_commit or ""
        self.site_registry.save(site_data)

        current_scripts = script_snapshot(merged_scripts)
        current_games_meta = games_meta_snapshot(site_data["games"] if isinstance(site_data.get("games"), dict) else {})
        loader_version = str(site_data.get("loaderVersion") or "")

        with self._lock:
            prev_scripts = self._state.get("scriptSnapshot") if isinstance(self._state.get("scriptSnapshot"), dict) else {}
            prev_games_meta = self._state.get("gamesMetaSnapshot") if isinstance(self._state.get("gamesMetaSnapshot"), dict) else {}
            prev_loader = str(self._state.get("loaderVersion") or "")
            initialized = bool(self._state.get("notifyInitialized"))

            script_diff = diff_script_snapshots(prev_scripts, current_scripts)
            meta_diff = diff_games_meta(prev_games_meta, current_games_meta)
            loader_changed = bool(prev_loader and loader_version and prev_loader != loader_version)

            has_changes = any([
                script_diff["added"],
                script_diff["removed"],
                script_diff["versionChanges"],
                script_diff["statusChanges"],
                meta_diff,
                loader_changed,
            ])

            self._state["scriptSnapshot"] = current_scripts
            self._state["gamesMetaSnapshot"] = current_games_meta
            self._state["loaderVersion"] = loader_version
            self._state["commit"] = commit_sha or release.get("commit") or known_commit or ""
            self._state["lastSyncAt"] = utc_iso()
            self._state["lastError"] = None
            self._state["syncCount"] = int(self._state.get("syncCount") or 0) + 1
            self._state["notifyInitialized"] = True
            self._save_state()

        if self.notify_fn and initialized and (commit_changed or has_changes):
            try:
                self.notify_fn({
                    "type": "games_sync",
                    "commit": commit_sha or "",
                    "commitMessage": commit_msg or "",
                    "commitChanged": commit_changed,
                    "coreVersion": str(release.get("core") or ""),
                    "telemetryVersion": str(release.get("telemetry") or ""),
                    "analyticsVersion": str(release.get("analytics") or ""),
                    "loaderVersion": loader_version,
                    "loaderChanged": loader_changed,
                    "previousLoaderVersion": prev_loader,
                    "scripts": script_diff,
                    "gamesMeta": meta_diff,
                    "totalGames": script_diff.get("totalGames") or len(current_scripts),
                })
            except Exception:
                pass

        return self.status()

    def _raw_url(self, path: str) -> str:
        clean = path.lstrip("/")
        return f"https://raw.githubusercontent.com/{self.repo}/{self.branch}/{clean}"

    def _fetch_text(self, path: str) -> str | None:
        url = self._raw_url(path)
        try:
            resp = requests.get(
                url,
                timeout=FETCH_TIMEOUT,
                headers={"Cache-Control": "no-cache", "Pragma": "no-cache"},
                params={"t": int(time.time())},
            )
            if resp.status_code == 404:
                return None
            resp.raise_for_status()
            return resp.text
        except requests.RequestException:
            return None

    def _fetch_json(self, path: str) -> dict[str, Any] | None:
        text = self._fetch_text(path)
        if not text:
            return None
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            return None
        return data if isinstance(data, dict) else None

    def _fetch_head_commit(self) -> tuple[str, str]:
        url = f"https://api.github.com/repos/{self.repo}/commits/{self.branch}"
        headers = {"Accept": "application/vnd.github+json"}
        token = os.environ.get("GITHUB_TOKEN", "").strip()
        if token:
            headers["Authorization"] = f"Bearer {token}"
        try:
            resp = requests.get(url, timeout=FETCH_TIMEOUT, headers=headers)
            if resp.status_code >= 400:
                release = self._fetch_json("cfg/release.json") or {}
                return str(release.get("commit") or ""), ""
            data = resp.json()
            sha = str(data.get("sha") or "")[:12]
            msg = str((data.get("commit") or {}).get("message") or "").split("\n")[0][:160]
            return sha, msg
        except requests.RequestException:
            release = self._fetch_json("cfg/release.json") or {}
            return str(release.get("commit") or "")[:12], ""

    def _discover_games(self, known_ids: list[str]) -> dict[str, dict[str, Any]]:
        out: dict[str, dict[str, Any]] = {}
        ids = list(dict.fromkeys(i.strip().lower() for i in known_ids if i))
        for script_id in ids[:20]:
            parsed = self._parse_game_file(script_id)
            if parsed:
                out[script_id] = parsed
        return out

    def _parse_game_file(self, script_id: str) -> dict[str, Any] | None:
        text = self._fetch_text(f"games/{script_id}.luau")
        if not text:
            return {"name": humanize_id(script_id), "version": "?", "existsOnGitHub": False}
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
        if info and info.get("existsOnGitHub") is False:
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
