"""Roblox Web API helpers for username ↔ userId resolution."""

from __future__ import annotations

import time
from typing import Any

try:
    import requests
except ImportError:
    requests = None  # type: ignore

ROBLOX_USERS_URL = "https://users.roblox.com/v1/usernames/users"
ROBLOX_USER_URL = "https://users.roblox.com/v1/users/{user_id}"
ROBLOX_USER_SEARCH_URL = "https://users.roblox.com/v1/users/search"
_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
_CACHE_TTL_SEC = 300


def _cache_get(key: str) -> dict[str, Any] | None:
    entry = _CACHE.get(key)
    if not entry:
        return None
    expires, value = entry
    if time.time() > expires:
        _CACHE.pop(key, None)
        return None
    return value


def _cache_set(key: str, value: dict[str, Any]) -> None:
    _CACHE[key] = (time.time() + _CACHE_TTL_SEC, value)


def resolve_usernames(usernames: list[str]) -> list[dict[str, Any]]:
    if not usernames:
        return []
    if requests is None:
        raise RuntimeError("requests is not installed")

    cleaned = []
    seen: set[str] = set()
    for name in usernames:
        text = str(name or "").strip()
        if not text:
            continue
        key = text.lower()
        if key in seen:
            continue
        seen.add(key)
        cleaned.append(text)

    if not cleaned:
        return []

    cached: list[dict[str, Any]] = []
    pending: list[str] = []
    for name in cleaned:
        hit = _cache_get(f"user:{name.lower()}")
        if hit:
            cached.append(hit)
        else:
            pending.append(name)

    resolved: list[dict[str, Any]] = list(cached)
    if pending:
        response = requests.post(
            ROBLOX_USERS_URL,
            json={"usernames": pending, "excludeBannedUsers": False},
            timeout=10,
        )
        if response.status_code >= 400:
            raise RuntimeError(f"Roblox API HTTP {response.status_code}")
        payload = response.json()
        for item in payload.get("data") or []:
            if not isinstance(item, dict):
                continue
            profile = {
                "id": item.get("id"),
                "name": item.get("name") or "",
                "displayName": item.get("displayName") or item.get("name") or "",
            }
            if profile["id"]:
                _cache_set(f"user:{profile['name'].lower()}", profile)
                resolved.append(profile)

    return resolved


def resolve_username(username: str) -> dict[str, Any] | None:
    rows = resolve_usernames([username])
    return rows[0] if rows else None


def search_users(keyword: str, *, limit: int = 8) -> list[dict[str, Any]]:
    """Search Roblox users by partial username or display name."""
    if requests is None:
        raise RuntimeError("requests is not installed")
    text = str(keyword or "").strip()
    if len(text) < 2:
        return []
    capped = max(1, min(int(limit or 8), 25))
    cache_key = f"search:{text.lower()}:{capped}"
    hit = _cache_get(cache_key)
    if hit and isinstance(hit.get("users"), list):
        return hit["users"]

    response = requests.get(
        ROBLOX_USER_SEARCH_URL,
        params={"keyword": text, "limit": capped},
        timeout=10,
    )
    if response.status_code >= 400:
        raise RuntimeError(f"Roblox API HTTP {response.status_code}")
    payload = response.json()
    users: list[dict[str, Any]] = []
    for item in payload.get("data") or []:
        if not isinstance(item, dict) or not item.get("id"):
            continue
        users.append(
            {
                "id": item.get("id"),
                "name": item.get("name") or "",
                "displayName": item.get("displayName") or item.get("name") or "",
                "hasVerifiedBadge": bool(item.get("hasVerifiedBadge")),
            }
        )
    _cache_set(cache_key, {"users": users})
    return users


def fetch_user(user_id: int | str) -> dict[str, Any] | None:
    if requests is None:
        raise RuntimeError("requests is not installed")
    uid = str(user_id).strip()
    if not uid.isdigit():
        return None
    cache_key = f"id:{uid}"
    hit = _cache_get(cache_key)
    if hit:
        return hit
    response = requests.get(ROBLOX_USER_URL.format(user_id=uid), timeout=10)
    if response.status_code == 404:
        return None
    if response.status_code >= 400:
        raise RuntimeError(f"Roblox API HTTP {response.status_code}")
    data = response.json()
    if not isinstance(data, dict) or not data.get("id"):
        return None
    profile = {
        "id": data.get("id"),
        "name": data.get("name") or "",
        "displayName": data.get("displayName") or data.get("name") or "",
        "description": data.get("description") or "",
        "created": data.get("created") or "",
        "isBanned": bool(data.get("isBanned")),
    }
    _cache_set(cache_key, profile)
    if profile["name"]:
        _cache_set(f"user:{profile['name'].lower()}", profile)
    return profile


_AVATAR_CACHE: dict[str, tuple[float, dict[str, str]]] = {}
_AVATAR_CACHE_TTL = 3600


def _avatar_cache_get(key: str) -> dict[str, str] | None:
    entry = _AVATAR_CACHE.get(key)
    if not entry:
        return None
    expires, value = entry
    if time.time() > expires:
        _AVATAR_CACHE.pop(key, None)
        return None
    return value


def _avatar_cache_set(key: str, value: dict[str, str]) -> None:
    _AVATAR_CACHE[key] = (time.time() + _AVATAR_CACHE_TTL, value)


def fetch_avatar_renders(user_ids: list[int | str]) -> dict[str, dict[str, str]]:
    """Fetch headshot, bust, and full-body avatar URLs for Roblox user IDs."""
    if requests is None:
        raise RuntimeError("requests is not installed")

    ids: list[str] = []
    seen: set[str] = set()
    for raw in user_ids:
        uid = str(raw or "").strip()
        if not uid.isdigit() or uid in seen:
            continue
        seen.add(uid)
        ids.append(uid)

    if not ids:
        return {}

    renders: dict[str, dict[str, str]] = {}
    missing: list[str] = []
    for uid in ids:
        cached = _avatar_cache_get(uid)
        if cached:
            renders[uid] = cached
        else:
            missing.append(uid)

    if not missing:
        return renders

    batches = [missing[i : i + 100] for i in range(0, len(missing), 100)]
    endpoints = (
        ("avatar", "720x720", "body"),
        ("avatar-bust", "420x420", "bust"),
        ("avatar-headshot", "420x420", "headshot"),
    )

    for batch in batches:
        joined = ",".join(batch)
        for path, size, key in endpoints:
            url = (
                f"https://thumbnails.roblox.com/v1/users/{path}"
                f"?userIds={joined}&size={size}&format=Png&isCircular=false"
            )
            try:
                response = requests.get(url, timeout=12)
                response.raise_for_status()
                payload = response.json()
            except requests.RequestException:
                continue
            for row in payload.get("data") or []:
                if row.get("state") != "Completed" or not row.get("imageUrl"):
                    continue
                uid = str(row.get("targetId") or "")
                if not uid:
                    continue
                bucket = renders.setdefault(uid, {})
                bucket[key] = str(row["imageUrl"])

    for uid in missing:
        bucket = renders.get(uid) or {}
        if bucket:
            bucket.setdefault(
                "profile",
                f"https://www.roblox.com/users/{uid}/profile",
            )
            _avatar_cache_set(uid, bucket)

    return renders
