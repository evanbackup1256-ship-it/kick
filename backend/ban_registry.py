"""SQLite-backed ban registry — HWID, Roblox userId, username, fingerprint, IP, executor."""

from __future__ import annotations

import sqlite3
import threading
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

VALID_BAN_TYPES = frozenset({"hwid", "userid", "username", "fingerprint", "ip", "executor"})


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
    if ban_type in {"hwid", "fingerprint", "executor", "username"}:
        return text.lower()
    if ban_type == "ip":
        return text
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
                    roblox_user_id TEXT NOT NULL DEFAULT '',
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
            cols = {row[1] for row in conn.execute("PRAGMA table_info(bans)").fetchall()}
            if "roblox_user_id" not in cols:
                conn.execute("ALTER TABLE bans ADD COLUMN roblox_user_id TEXT NOT NULL DEFAULT ''")
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_bans_roblox ON bans(roblox_user_id, active)"
            )

    def _row_to_dict(self, row: sqlite3.Row | None) -> dict[str, Any] | None:
        if row is None:
            return None
        data = dict(row)
        data["active"] = bool(data.get("active"))
        return data

    def list_bans(self, include_inactive: bool = False, query: str = "") -> list[dict[str, Any]]:
        sql = "SELECT * FROM bans"
        clauses: list[str] = []
        params: list[Any] = []
        if not include_inactive:
            clauses.append("active = 1")
        if query.strip():
            like = f"%{query.strip()}%"
            clauses.append(
                "(value LIKE ? OR player_name LIKE ? OR reason LIKE ? OR roblox_user_id LIKE ? OR ban_type LIKE ?)"
            )
            params.extend([like, like, like, like, like])
        if clauses:
            sql += " WHERE " + " AND ".join(clauses)
        sql += " ORDER BY id DESC"
        with self._lock, self._connect() as conn:
            rows = conn.execute(sql, params).fetchall()
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
        roblox_user_id: str = "",
        expires_at: str | None = None,
        created_by: str = "admin",
    ) -> dict[str, Any]:
        ban_type = normalize_ban_type(ban_type)
        normalized = normalize_ban_value(ban_type, value)
        if ban_type == "userid" and not roblox_user_id:
            roblox_user_id = normalized
        now = utc_iso()
        with self._lock, self._connect() as conn:
            conn.execute(
                """
                INSERT INTO bans (ban_type, value, reason, player_name, roblox_user_id, created_at, expires_at, created_by, active)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
                ON CONFLICT(ban_type, value) DO UPDATE SET
                    reason = excluded.reason,
                    player_name = excluded.player_name,
                    roblox_user_id = excluded.roblox_user_id,
                    expires_at = excluded.expires_at,
                    created_by = excluded.created_by,
                    active = 1,
                    created_at = excluded.created_at
                """,
                (
                    ban_type,
                    normalized,
                    reason or "",
                    player_name or "",
                    str(roblox_user_id or ""),
                    now,
                    expires_at,
                    created_by or "admin",
                ),
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
        player_name: str = "",
        display_name: str = "",
        hwid: str = "",
        fingerprint: str = "",
        client_ip: str = "",
        executor: str = "",
    ) -> dict[str, Any]:
        checks: list[tuple[str, str]] = []
        if user_id is not None and str(user_id).strip().isdigit():
            checks.append(("userid", str(user_id).strip()))
        for name in {player_name, display_name}:
            text = str(name or "").strip().lower()
            if text:
                checks.append(("username", text))
        if hwid and str(hwid).strip():
            checks.append(("hwid", normalize_ban_value("hwid", hwid)))
        if fingerprint and str(fingerprint).strip():
            checks.append(("fingerprint", normalize_ban_value("fingerprint", fingerprint)))
        if client_ip and str(client_ip).strip():
            checks.append(("ip", str(client_ip).strip()))
        if executor and str(executor).strip():
            checks.append(("executor", normalize_ban_value("executor", executor)))

        if not checks:
            return {"allowed": True, "ban": None, "matched": None}

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
            matched = entry.get("ban_type")
            return {
                "allowed": False,
                "ban": deepcopy(entry),
                "matched": matched,
                "reason": entry.get("reason") or matched or "banned",
            }

        return {"allowed": True, "ban": None, "matched": None}

    def ban_roblox_player(
        self,
        *,
        username: str = "",
        user_id: object = None,
        hwid: str = "",
        fingerprint: str = "",
        client_ip: str = "",
        executor: str = "",
        reason: str = "",
        expires_at: str | None = None,
        created_by: str = "admin",
        cascade: bool = True,
        resolve_username: Callable[[str], dict[str, Any] | None] | None = None,
    ) -> dict[str, Any]:
        profile: dict[str, Any] | None = None
        uid = str(user_id).strip() if user_id is not None else ""
        uname = str(username or "").strip()

        if not uid.isdigit() and uname and resolve_username:
            profile = resolve_username(uname)
            if profile and profile.get("id"):
                uid = str(profile["id"])
                uname = profile.get("name") or uname

        label = (profile or {}).get("displayName") or (profile or {}).get("name") or uname or uid
        created: list[dict[str, Any]] = []

        def push(ban_type: str, value: object) -> None:
            if value is None or str(value).strip() == "":
                return
            created.append(
                self.add_ban(
                    ban_type,
                    value,
                    reason=reason,
                    player_name=label,
                    roblox_user_id=uid if uid.isdigit() else "",
                    expires_at=expires_at,
                    created_by=created_by,
                )
            )

        if uid.isdigit():
            push("userid", uid)
        if uname:
            push("username", uname)
        if cascade:
            push("hwid", hwid)
            push("fingerprint", fingerprint)
            push("ip", client_ip)
            push("executor", executor)

        if not created:
            raise ValueError("Provide a Roblox username, userId, or hardware identifier to ban")

        return {
            "ok": True,
            "roblox": profile or {"id": int(uid) if uid.isdigit() else None, "name": uname or None},
            "bans": created,
            "cascade": cascade,
        }

    def add_batch(
        self,
        entries: list[dict[str, Any]],
        *,
        created_by: str = "admin",
    ) -> list[dict[str, Any]]:
        created: list[dict[str, Any]] = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            created.append(
                self.add_ban(
                    str(entry.get("banType") or entry.get("ban_type") or ""),
                    entry.get("value"),
                    reason=str(entry.get("reason") or ""),
                    player_name=str(entry.get("playerName") or entry.get("player_name") or ""),
                    roblox_user_id=str(entry.get("robloxUserId") or entry.get("roblox_user_id") or ""),
                    expires_at=str(entry.get("expiresAt") or entry.get("expires_at") or "") or None,
                    created_by=str(entry.get("createdBy") or entry.get("created_by") or created_by),
                )
            )
        return created
