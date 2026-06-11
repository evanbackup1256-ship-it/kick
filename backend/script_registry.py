"""Script status registry — persisted manifest for loader + admin UI."""

from __future__ import annotations

import json
import os
import threading
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
APP_DIR = Path(__file__).resolve().parent


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


DEFAULT_MANIFEST = resolve_manifest_path()

VALID_STATUSES = frozenset({"working", "detected", "broken", "maintenance", "testing"})

STATUS_LABELS = {
    "working": "Working",
    "detected": "Detected / unstable",
    "broken": "Broken",
    "maintenance": "Maintenance",
    "testing": "Testing",
}


def utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


class ScriptRegistry:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or DEFAULT_MANIFEST
        self._lock = threading.Lock()
        self._cache: dict[str, Any] | None = None

    def _default(self) -> dict[str, Any]:
        return {"version": 1, "updatedAt": utc_iso(), "scripts": {}}

    def load(self) -> dict[str, Any]:
        with self._lock:
            if self._cache is not None:
                return deepcopy(self._cache)
            if not self.path.is_file():
                data = self._default()
                self._cache = data
                return deepcopy(data)
            raw = self.path.read_text(encoding="utf-8-sig")
            data = json.loads(raw)
            if not isinstance(data, dict) or not isinstance(data.get("scripts"), dict):
                data = self._default()
            self._cache = data
            return deepcopy(data)

    def save(self, data: dict[str, Any]) -> None:
        with self._lock:
            data = deepcopy(data)
            data["updatedAt"] = utc_iso()
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            self._cache = data

    def list_scripts(self) -> dict[str, Any]:
        return self.load()

    def get_script(self, script_id: str) -> dict[str, Any] | None:
        data = self.load()
        entry = data.get("scripts", {}).get(script_id)
        if not isinstance(entry, dict):
            return None
        return deepcopy(entry)

    def update_script(self, script_id: str, patch: dict[str, Any], updated_by: str = "admin") -> dict[str, Any]:
        data = self.load()
        scripts = data.setdefault("scripts", {})
        current = scripts.get(script_id)
        if not isinstance(current, dict):
            raise KeyError(f"Unknown script: {script_id}")

        if "status" in patch:
            status = str(patch["status"]).strip().lower()
            if status not in VALID_STATUSES:
                raise ValueError(f"Invalid status: {status}")
            current["status"] = status

        if "message" in patch:
            current["message"] = str(patch.get("message") or "")

        if "version" in patch and patch["version"] is not None:
            current["version"] = str(patch["version"])

        if "name" in patch and patch["name"]:
            current["name"] = str(patch["name"])

        current["updatedAt"] = utc_iso()
        current["updatedBy"] = updated_by or "admin"
        scripts[script_id] = current
        self.save(data)
        return deepcopy(current)
