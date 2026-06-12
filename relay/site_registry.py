"""Editable public site content (FAQ, loadstring, announcements)."""

from __future__ import annotations

import json
import threading
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SITE = ROOT / "cfg" / "site.json"


def utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


class SiteRegistry:
    editable_keys = frozenset({
        "announcement",
        "tagline",
        "loadstring",
        "loaderVersion",
        "coreVersion",
        "uiLibrary",
        "uiVersion",
        "sydePatch",
        "features",
        "faq",
        "changelog",
        "bugCategories",
        "games",
        "links",
        "credits",
        "executors",
        "resources",
    })

    def __init__(self, path: Path | None = None) -> None:
        self.path = path or DEFAULT_SITE
        self._lock = threading.Lock()
        self._cache: dict[str, Any] | None = None

    def load(self) -> dict[str, Any]:
        with self._lock:
            if self._cache is not None:
                return deepcopy(self._cache)
            if not self.path.is_file():
                data = {"version": 1, "brand": "Alleral", "faq": [], "features": [], "games": {}}
                self._cache = data
                return deepcopy(data)
            raw = self.path.read_text(encoding="utf-8-sig")
            data = json.loads(raw)
            if not isinstance(data, dict):
                data = {"version": 1, "brand": "Alleral", "faq": [], "features": [], "games": {}}
            self._cache = data
            return deepcopy(data)

    def save(self, data: dict[str, Any]) -> None:
        with self._lock:
            payload = deepcopy(data)
            payload["updatedAt"] = utc_iso()
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
            self._cache = payload

    def patch(self, patch: dict[str, Any]) -> dict[str, Any]:
        data = self.load()
        for key, value in patch.items():
            if key in self.editable_keys:
                data[key] = value
        self.save(data)
        return self.load()
