"""SQLite-backed HWID / user ban registry for the Alleral gate."""

from __future__ import annotations

import sqlite3
import threading
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

VALID_BAN_TYPES = frozenset({"hwid", "userid", "fingerprint", "ip", "executor"})


def utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def normalize_ban_type(value: str) -> str:
    text = str(value or "").strip().lower()
    if text in VALID_BAN_TYPES:
        return text
    raise ValueError(f"Invalid ban type: {value}")


def normalize_ban_value(ban_type: str, value: object) -> str:
    text = str(value or "").strip()
    if not text:
        raise ValueError("Ban value is required")
    if ban_type == "userid":
        if not text.isdigit():
            raise ValueError("userid bans must be numeric")
        return text
    if ban_type == "hwid":
        return text.lower()
    if ban_type == "fingerprint":
        return text.lower()
    if ban_type == "ip":
        return text
    if ban_type == "executor":
        return text.lower()
    return text


class BanRegistry:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path, timeout=30, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA foreign_keys=ON")
        return conn

    def _init_db(self) -> None:
        with self._connect() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS bans (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ban_type TEXT NOT NULL,
                    value TEXT NOT NULL,
                    reason TEXT NOT NULL DEFAULT '',
                    player_name TEXT NOT NULL DEFAULT '',
                    created_at TEXT NOT NULL,
                    expires_at TEXT,
                    created_by TEXT NOT NULL DEFAULT 'admin',
                    active INTEGER NOT NULL DEFAULT 1,
                    UNIQUE(ban_type, value)
                );
                CREATE INDEX IF NOT EXISTS idx_bans_lookup ON bans(ban_type, value, active);
                CREATE INDEX IF NOT EXISTS idx_bans_active ON bans(active, expires_at);
                """
            )

    def _row_to_dict(self, row: sqlite3.Row | None) -> dict[str, Any] | None:
        if row is None:
            return None
        data = dict(row)
        data["active"] = bool(data.get("active"))
        return data

    def list_bans(self, include_inactive: bool = False) -> list[dict[str, Any]]:
        query = "SELECT * FROM bans"
        params: tuple[Any, ...] = ()
        if not include_inactive:
            query += " WHERE active = 1"
        query += " ORDER BY id DESC"
        with self._lock, self._connect() as conn:
            rows = conn.execute(query, params).fetchall()
        return [self._row_to_dict(row) for row in rows if row is not None]

    def get_ban(self, ban_id: int) -> dict[str, Any] | None:
        with self._lock, self._connect() as conn:
            row = conn.execute("SELECT * FROM bans WHERE id = ?", (ban_id,)).fetchone()
        return self._row_to_dict(row)

    def add_ban(
        self,
        ban_type: str,
        value: object,
        *,
        reason: str = "",
        player_name: str = "",
        expires_at: str | None = None,
        created_by: str = "admin",
    ) -> dict[str, Any]:
        ban_type = normalize_ban_type(ban_type)
        normalized = normalize_ban_value(ban_type, value)
        now = utc_iso()
        with self._lock, self._connect() as conn:
            conn.execute(
                """
                INSERT INTO bans (ban_type, value, reason, player_name, created_at, expires_at, created_by, active)
                VALUES (?, ?, ?, ?, ?, ?, ?, 1)
                ON CONFLICT(ban_type, value) DO UPDATE SET
                    reason = excluded.reason,
                    player_name = excluded.player_name,
                    expires_at = excluded.expires_at,
                    created_by = excluded.created_by,
                    active = 1,
                    created_at = excluded.created_at
                """,
                (ban_type, normalized, reason or "", player_name or "", now, expires_at, created_by or "admin"),
            )
            row = conn.execute(
                "SELECT * FROM bans WHERE ban_type = ? AND value = ?",
                (ban_type, normalized),
            ).fetchone()
        result = self._row_to_dict(row)
        if result is None:
            raise RuntimeError("Failed to persist ban")
        return result

    def remove_ban(self, ban_id: int) -> bool:
        with self._lock, self._connect() as conn:
            cur = conn.execute("UPDATE bans SET active = 0 WHERE id = ?", (ban_id,))
            return cur.rowcount > 0

    def _is_expired(self, expires_at: str | None) -> bool:
        if not expires_at:
            return False
        text = str(expires_at).strip()
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        try:
            parsed = datetime.fromisoformat(text)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            return parsed.astimezone(timezone.utc) <= datetime.now(timezone.utc)
        except ValueError:
            return False

    def evaluate(
        self,
        *,
        user_id: object = None,
        hwid: str = "",
        fingerprint: str = "",
        client_ip: str = "",
        executor: str = "",
    ) -> dict[str, Any]:
        checks: list[tuple[str, str]] = []
        if user_id is not None and str(user_id).strip().isdigit():
            checks.append(("userid", str(user_id).strip()))
        if hwid and str(hwid).strip():
            checks.append(("hwid", normalize_ban_value("hwid", hwid)))
        if fingerprint and str(fingerprint).strip():
            checks.append(("fingerprint", normalize_ban_value("fingerprint", fingerprint)))
        if client_ip and str(client_ip).strip():
            checks.append(("ip", str(client_ip).strip()))
        if executor and str(executor).strip():
            checks.append(("executor", normalize_ban_value("executor", executor)))

        if not checks:
            return {"allowed": True, "ban": None}

        clauses = " OR ".join(["(ban_type = ? AND value = ?)"] * len(checks))
        params: list[str] = []
        for ban_type, value in checks:
            params.extend([ban_type, value])

        with self._lock, self._connect() as conn:
            rows = conn.execute(
                f"SELECT * FROM bans WHERE active = 1 AND ({clauses})",
                params,
            ).fetchall()

        for row in rows:
            entry = self._row_to_dict(row)
            if not entry:
                continue
            if self._is_expired(entry.get("expires_at")):
                continue
            return {
                "allowed": False,
                "ban": deepcopy(entry),
                "reason": entry.get("reason") or entry.get("ban_type") or "banned",
            }

        return {"allowed": True, "ban": None}
