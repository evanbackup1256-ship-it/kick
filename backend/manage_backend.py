"""Optional third-party management backend (Supabase) + local audit store."""

from __future__ import annotations

import json
import sqlite3
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import requests
except ImportError:
    requests = None  # type: ignore


def utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


class ManageBackend:
    """Local audit log with optional Supabase sync for hub management."""

    def __init__(
        self,
        data_dir: Path,
        *,
        supabase_url: str = "",
        supabase_service_key: str = "",
        supabase_table: str = "alleral_audit",
        enabled: bool = True,
    ) -> None:
        self.data_dir = data_dir
        self.supabase_url = supabase_url.rstrip("/")
        self.supabase_service_key = supabase_service_key.strip()
        self.supabase_table = supabase_table.strip() or "alleral_audit"
        self.enabled = enabled
        self._lock = threading.Lock()
        self._path = data_dir / "manage_audit.db"
        self._init_db()

    def _init_db(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        with self._lock:
            conn = sqlite3.connect(str(self._path), timeout=10)
            try:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS audit_events (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        event TEXT NOT NULL,
                        actor TEXT,
                        payload TEXT NOT NULL,
                        ts REAL NOT NULL,
                        synced INTEGER NOT NULL DEFAULT 0
                    )
                    """
                )
                conn.execute("CREATE INDEX IF NOT EXISTS idx_audit_ts ON audit_events(ts DESC)")
                conn.commit()
            finally:
                conn.close()

    def supabase_configured(self) -> bool:
        return bool(self.supabase_url and self.supabase_service_key and requests is not None)

    def status(self) -> dict[str, Any]:
        with self._lock:
            conn = sqlite3.connect(str(self._path), timeout=10)
            try:
                total = conn.execute("SELECT COUNT(*) FROM audit_events").fetchone()[0]
                pending = conn.execute("SELECT COUNT(*) FROM audit_events WHERE synced = 0").fetchone()[0]
            finally:
                conn.close()
        return {
            "enabled": self.enabled,
            "provider": "supabase" if self.supabase_configured() else "local",
            "supabaseConfigured": self.supabase_configured(),
            "localEvents": int(total),
            "pendingSync": int(pending),
            "table": self.supabase_table,
        }

    def record(self, event: str, payload: dict[str, Any] | None = None, actor: str = "system") -> dict[str, Any]:
        if not self.enabled:
            return {"ok": False, "error": "disabled"}
        row = {
            "event": str(event or "event")[:120],
            "actor": str(actor or "system")[:120],
            "payload": payload if isinstance(payload, dict) else {},
            "ts": time.time(),
        }
        with self._lock:
            conn = sqlite3.connect(str(self._path), timeout=10)
            try:
                cur = conn.execute(
                    "INSERT INTO audit_events (event, actor, payload, ts, synced) VALUES (?, ?, ?, ?, 0)",
                    (row["event"], row["actor"], json.dumps(row["payload"]), row["ts"]),
                )
                conn.commit()
                row_id = int(cur.lastrowid or 0)
            finally:
                conn.close()
        row["id"] = row_id
        row["createdAt"] = utc_iso()
        if self.supabase_configured():
            synced = self._push_supabase(row)
            if synced:
                self._mark_synced(row_id)
                row["synced"] = True
        return {"ok": True, "entry": row}

    def list_events(self, limit: int = 50, query: str = "") -> list[dict[str, Any]]:
        limit = max(1, min(limit, 200))
        q = f"%{query.strip()}%" if query.strip() else None
        with self._lock:
            conn = sqlite3.connect(str(self._path), timeout=10)
            conn.row_factory = sqlite3.Row
            try:
                if q:
                    rows = conn.execute(
                        """
                        SELECT id, event, actor, payload, ts, synced
                        FROM audit_events
                        WHERE event LIKE ? OR actor LIKE ? OR payload LIKE ?
                        ORDER BY ts DESC LIMIT ?
                        """,
                        (q, q, q, limit),
                    ).fetchall()
                else:
                    rows = conn.execute(
                        """
                        SELECT id, event, actor, payload, ts, synced
                        FROM audit_events ORDER BY ts DESC LIMIT ?
                        """,
                        (limit,),
                    ).fetchall()
            finally:
                conn.close()
        out: list[dict[str, Any]] = []
        for row in rows:
            try:
                payload = json.loads(row["payload"])
            except json.JSONDecodeError:
                payload = {}
            out.append({
                "id": row["id"],
                "event": row["event"],
                "actor": row["actor"],
                "payload": payload,
                "synced": bool(row["synced"]),
                "createdAt": datetime.fromtimestamp(float(row["ts"]), timezone.utc).replace(microsecond=0).isoformat(),
            })
        return out

    def _mark_synced(self, row_id: int) -> None:
        with self._lock:
            conn = sqlite3.connect(str(self._path), timeout=10)
            try:
                conn.execute("UPDATE audit_events SET synced = 1 WHERE id = ?", (row_id,))
                conn.commit()
            finally:
                conn.close()

    def _push_supabase(self, row: dict[str, Any]) -> bool:
        if not self.supabase_configured():
            return False
        url = f"{self.supabase_url}/rest/v1/{self.supabase_table}"
        headers = {
            "apikey": self.supabase_service_key,
            "Authorization": f"Bearer {self.supabase_service_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
        body = {
            "event": row["event"],
            "actor": row["actor"],
            "payload": row["payload"],
            "created_at": row["createdAt"],
        }
        try:
            resp = requests.post(url, headers=headers, data=json.dumps(body), timeout=8)
            return 200 <= resp.status_code < 300
        except requests.RequestException:
            return False

    def sync_pending(self) -> dict[str, Any]:
        if not self.supabase_configured():
            return {"ok": False, "error": "supabase_not_configured"}
        with self._lock:
            conn = sqlite3.connect(str(self._path), timeout=10)
            conn.row_factory = sqlite3.Row
            try:
                rows = conn.execute(
                    "SELECT id, event, actor, payload, ts FROM audit_events WHERE synced = 0 ORDER BY ts ASC LIMIT 40"
                ).fetchall()
            finally:
                conn.close()
        synced = 0
        for row in rows:
            payload = json.loads(row["payload"])
            entry = {
                "event": row["event"],
                "actor": row["actor"],
                "payload": payload,
                "createdAt": datetime.fromtimestamp(float(row["ts"]), timezone.utc).replace(microsecond=0).isoformat(),
            }
            if self._push_supabase(entry):
                self._mark_synced(int(row["id"]))
                synced += 1
        return {"ok": True, "synced": synced, "remaining": max(0, len(rows) - synced)}
