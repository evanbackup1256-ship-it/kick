"""WEAO (WhatExpsAre.Online) API — live Roblox executor statuses."""

from __future__ import annotations

import re
import time
from typing import Any

try:
    import requests
except ImportError:
    requests = None  # type: ignore

WEAO_USER_AGENT = "WEAO-3PService"
WEAO_BASES = (
    "https://weao.xyz",
    "https://api.weao.xyz",
    "https://whatexpsare.online",
    "https://api.whatexpsare.online",
)
WEAO_PATH = "/api/status/exploits"
_CACHE: dict[str, tuple[float, list[dict[str, Any]]]] = {}
_CACHE_TTL_SEC = 300
_LIVE_CACHE_TTL_SEC = 30
_PREVIOUS: dict[str, dict[str, Any]] = {}
_CHANGE_LOG: list[dict[str, Any]] = []
_CHANGE_LOG_MAX = 40


def _slug_from_title(title: str) -> str:
    text = re.sub(r"[^a-z0-9]+", "", str(title or "").lower())
    text = text.replace("synapsez", "synapse")
    return text or "unknown"


def _derive_live_status(entry: dict[str, Any]) -> tuple[str, str, str]:
    """Return (liveStatus, liveLabel, liveDetail) for UI."""
    updated = entry.get("updateStatus") is not False
    detected = entry.get("detected") is True
    if not updated:
        return (
            "not_working",
            "Not working",
            "Waiting for executor update after Roblox patch",
        )
    if detected:
        return (
            "detected",
            "Detected",
            "Updated but flagged by Hyperion — use at your own risk",
        )
    return (
        "working",
        "Working",
        "Updated and undetected — good to inject Alleral",
    )


def _classify_alleral(entry: dict[str, Any]) -> str:
    live_status, _, _ = _derive_live_status(entry)
    if live_status == "not_working":
        return "outdated"
    if live_status == "detected":
        return "detected"
    sunc = entry.get("suncPercentage")
    if isinstance(sunc, (int, float)) and sunc >= 85:
        return "recommended"
    return "supported"


def entry_fingerprint(entry: dict[str, Any]) -> str:
    parts = [
        str(entry.get("version") or ""),
        "1" if entry.get("detected") else "0",
        "1" if entry.get("updateStatus") is not False else "0",
        str(entry.get("rbxversion") or ""),
        str(entry.get("suncPercentage") or ""),
        str(entry.get("updatedDate") or ""),
    ]
    return "|".join(parts)


def _change_message(title: str, prev: dict[str, Any], curr: dict[str, Any]) -> str:
    messages: list[str] = []
    prev_version = str(prev.get("version") or "")
    curr_version = str(curr.get("version") or "")
    if prev_version and curr_version and prev_version != curr_version:
        messages.append(f"Patched to v{curr_version}")

    prev_updated = prev.get("updateStatus") is not False
    curr_updated = curr.get("updateStatus") is not False
    if prev_updated and not curr_updated:
        messages.append("Broken after Roblox update — not working until patched")
    elif not prev_updated and curr_updated:
        messages.append("Working again — executor updated")

    prev_detected = prev.get("detected") is True
    curr_detected = curr.get("detected") is True
    if not prev_detected and curr_detected:
        messages.append("Now detected by Hyperion")
    elif prev_detected and not curr_detected:
        messages.append("Undetected again")

    prev_live = prev.get("liveStatus") or _derive_live_status(prev)[0]
    curr_live = curr.get("liveStatus") or _derive_live_status(curr)[0]
    if not messages and prev_live != curr_live:
        label = _derive_live_status(curr)[1]
        messages.append(f"Status → {label}")

    if not messages:
        messages.append("Status updated on WEAO")
    return f"{title}: {' · '.join(messages)}"


def diff_exploits(
    previous: dict[str, dict[str, Any]],
    current: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    changes: list[dict[str, Any]] = []
    now = time.time()
    current_map = {str(entry.get("slug") or ""): entry for entry in current if entry.get("slug")}

    for slug, curr in current_map.items():
        prev = previous.get(slug)
        if not prev:
            continue
        if entry_fingerprint(prev) == entry_fingerprint(curr):
            continue
        change_type = "patched" if str(prev.get("version") or "") != str(curr.get("version") or "") else "status"
        severity = "warning"
        if curr.get("liveStatus") == "working" and prev.get("liveStatus") != "working":
            severity = "good"
        elif curr.get("liveStatus") == "not_working":
            severity = "bad"
        changes.append(
            {
                "slug": slug,
                "title": curr.get("title") or slug,
                "type": change_type,
                "severity": severity,
                "message": _change_message(str(curr.get("title") or slug), prev, curr),
                "from": {
                    "liveStatus": prev.get("liveStatus"),
                    "liveLabel": prev.get("liveLabel"),
                    "version": prev.get("version"),
                    "detected": prev.get("detected"),
                    "updateStatus": prev.get("updateStatus"),
                },
                "to": {
                    "liveStatus": curr.get("liveStatus"),
                    "liveLabel": curr.get("liveLabel"),
                    "version": curr.get("version"),
                    "detected": curr.get("detected"),
                    "updateStatus": curr.get("updateStatus"),
                },
                "at": now,
            }
        )

    return changes


def _remember_changes(changes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    global _CHANGE_LOG
    if changes:
        _CHANGE_LOG = (changes + _CHANGE_LOG)[:_CHANGE_LOG_MAX]
    return list(_CHANGE_LOG)


def _format_entry(raw: dict[str, Any]) -> dict[str, Any]:
    title = str(raw.get("title") or "").strip()
    slug_obj = raw.get("slug")
    logo = ""
    if isinstance(slug_obj, dict):
        logo = str(slug_obj.get("logo") or "")
    live_status, live_label, live_detail = _derive_live_status(raw)
    entry = {
        "title": title,
        "slug": _slug_from_title(title),
        "version": str(raw.get("version") or ""),
        "updatedDate": str(raw.get("updatedDate") or ""),
        "detected": raw.get("detected") is True,
        "updateStatus": raw.get("updateStatus") is not False,
        "uncStatus": raw.get("uncStatus") is True,
        "free": raw.get("free") is True,
        "platform": str(raw.get("platform") or raw.get("extype") or ""),
        "cost": str(raw.get("cost") or ("Free" if raw.get("free") else "")),
        "suncPercentage": raw.get("suncPercentage"),
        "uncPercentage": raw.get("uncPercentage"),
        "rbxversion": str(raw.get("rbxversion") or ""),
        "websitelink": str(raw.get("websitelink") or ""),
        "discordlink": str(raw.get("discordlink") or ""),
        "purchaselink": str(raw.get("purchaselink") or ""),
        "logo": logo,
        "liveStatus": live_status,
        "liveLabel": live_label,
        "liveDetail": live_detail,
        "hidden": raw.get("hidden") is True,
    }
    entry["alleralStatus"] = _classify_alleral(entry)
    entry["fingerprint"] = entry_fingerprint(entry)
    return entry


def fetch_all_exploits(*, force_refresh: bool = False, live: bool = False) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    if requests is None:
        raise RuntimeError("requests is not installed")

    cache_key = "live" if live else "all"
    ttl = _LIVE_CACHE_TTL_SEC if live else _CACHE_TTL_SEC
    if not force_refresh:
        hit = _CACHE.get(cache_key)
        if hit and time.time() < hit[0]:
            formatted = hit[1]
            changes = diff_exploits(_PREVIOUS, formatted) if _PREVIOUS else []
            return formatted, changes

    headers = {
        "User-Agent": WEAO_USER_AGENT,
        "Accept": "application/json",
        "Cache-Control": "no-cache, no-store, must-revalidate",
        "Pragma": "no-cache",
    }
    last_err = "WEAO exploit list unavailable"
    for base in WEAO_BASES:
        url = f"{base.rstrip('/')}{WEAO_PATH}"
        try:
            response = requests.get(url, headers=headers, timeout=12)
            if response.status_code >= 400:
                last_err = f"WEAO HTTP {response.status_code}"
                continue
            payload = response.json()
        except requests.RequestException as exc:
            last_err = str(exc)
            continue

        rows: list[Any]
        if isinstance(payload, list):
            rows = payload
        elif isinstance(payload, dict):
            rows = payload.get("data") or payload.get("exploits") or []
        else:
            continue

        formatted: list[dict[str, Any]] = []
        for row in rows:
            if not isinstance(row, dict):
                continue
            if row.get("hidden") is True:
                continue
            title = str(row.get("title") or "").strip()
            if not title:
                continue
            formatted.append(_format_entry(row))

        formatted.sort(key=lambda item: (item.get("title") or "").lower())
        changes = diff_exploits(_PREVIOUS, formatted) if _PREVIOUS else []
        _PREVIOUS.clear()
        for entry in formatted:
            slug = str(entry.get("slug") or "")
            if slug:
                _PREVIOUS[slug] = dict(entry)
        _remember_changes(changes)
        _CACHE[cache_key] = (time.time() + ttl, formatted)
        if live:
            _CACHE["all"] = (time.time() + min(ttl, 60), formatted)
        return formatted, changes

    cached = _CACHE.get(cache_key) or _CACHE.get("all")
    if cached:
        formatted = cached[1]
        changes = diff_exploits(_PREVIOUS, formatted) if _PREVIOUS else []
        return formatted, changes
    raise RuntimeError(last_err)


def fetch_exploit(slug: str) -> dict[str, Any] | None:
    needle = _slug_from_title(slug)
    exploits, _ = fetch_all_exploits()
    for entry in exploits:
        if entry.get("slug") == needle or _slug_from_title(entry.get("title", "")) == needle:
            return entry
    return None


def summarize_exploits(exploits: list[dict[str, Any]]) -> dict[str, int]:
    summary = {
        "total": len(exploits),
        "recommended": 0,
        "supported": 0,
        "detected": 0,
        "outdated": 0,
        "working": 0,
        "notWorking": 0,
        "free": 0,
        "updated": 0,
        "undetected": 0,
    }
    for entry in exploits:
        status = entry.get("alleralStatus") or "supported"
        if status in summary:
            summary[status] += 1
        live = entry.get("liveStatus") or ""
        if live == "working":
            summary["working"] += 1
        elif live == "not_working":
            summary["notWorking"] += 1
        if entry.get("free"):
            summary["free"] += 1
        if entry.get("updateStatus"):
            summary["updated"] += 1
        if not entry.get("detected"):
            summary["undetected"] += 1
    return summary


def recent_changes(limit: int = 20) -> list[dict[str, Any]]:
    capped = max(1, min(int(limit or 20), _CHANGE_LOG_MAX))
    return list(_CHANGE_LOG[:capped])
