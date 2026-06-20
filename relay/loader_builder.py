#!/usr/bin/env python3
"""Build and serve Alleral loader module manifests (UTF-8 without BOM)."""

from __future__ import annotations

import hashlib
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

BOM = b"\xef\xbb\xbf"

# Core boot chain + Rayfield UI runtime
LOADER_MODULES = (
    "bootstrap.luau",
    "loader.luau",
    "hub/core_base.luau",
    "hub/core_ui.luau",
    "hub/alleral_ui.luau",
    "hub/core_hub_ui.luau",
    "ui/rayfield/source.luau",
    "cfg/release.json",
)


def resolve_root(root: Path | None = None) -> Path:
    if root is not None:
        return root
    override = os.environ.get("LOADER_MODULES_ROOT", "").strip()
    if override:
        return Path(override)
    here = Path(__file__).resolve().parent
    for candidate in (here / "loader_src", here.parent, here):
        if (candidate / "loader.luau").is_file():
            return candidate
    return here.parent


def strip_utf8_bom(text: str) -> str:
    if text.startswith("\ufeff"):
        return text[1:]
    return text


def read_luau(path: Path) -> str:
    raw = path.read_bytes()
    if raw.startswith(BOM):
        raw = raw[len(BOM) :]
    return raw.decode("utf-8")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def parse_release(root: Path | None = None) -> dict[str, Any]:
    base = resolve_root(root)
    candidates: list[Path] = [base / "cfg" / "release.json"]
    env_release = os.environ.get("RELEASE_CONFIG_PATH", "").strip()
    if env_release:
        candidates.append(Path(env_release))
    for release_path in candidates:
        if release_path.is_file():
            return json.loads(release_path.read_text(encoding="utf-8-sig"))
    return {}


def module_version_marker(text: str) -> int | None:
    for pattern in (
        r"local\s+ALLERAL_RAYFIELD_VERSION\s*=\s*(\d+)",
        r"Version\s*=\s*(\d+)",
    ):
        match = re.search(pattern, text)
        if match:
            return int(match.group(1))
    loader = re.search(r'local\s+LOADER_VERSION\s*=\s*"([^"]+)"', text)
    if loader:
        return None
    return None


def build_manifest(root: Path | None = None) -> dict[str, Any]:
    base = resolve_root(root)
    release = parse_release(base)
    modules: list[dict[str, Any]] = []
    for rel in LOADER_MODULES:
        path = base / rel
        if not path.is_file():
            continue
        text = read_luau(path)
        modules.append(
            {
                "path": rel.replace("\\", "/"),
                "bytes": len(text.encode("utf-8")),
                "sha256": sha256_text(text),
                "versionMarker": module_version_marker(text),
            }
        )
    return {
        "ok": True,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "release": release,
        "loader": release.get("loader"),
        "ui": release.get("ui", "Rayfield"),
        "uiVersion": release.get("uiVersion"),
        "rayfieldVersion": release.get("rayfieldVersion"),
        "commit": release.get("commit"),
        "modules": modules,
    }


def read_module(rel_path: str, root: Path | None = None) -> tuple[str | None, str | None]:
    base = resolve_root(root)
    clean = rel_path.replace("\\", "/").lstrip("/")
    if ".." in clean.split("/"):
        return None, "invalid_path"
    path = base / clean
    if not path.is_file():
        return None, "not_found"
    if path.suffix.lower() not in {".luau", ".json"}:
        return None, "unsupported_type"
    try:
        return read_luau(path), None
    except OSError as exc:
        return None, str(exc)


def write_manifest_cache(out_path: Path | None = None) -> Path:
    repo = resolve_root()
    out_path = out_path or repo / "relay" / "data" / "loader_manifest.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = build_manifest()
    out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return out_path


if __name__ == "__main__":
    target = write_manifest_cache()
    print(f"loader manifest -> {target}")
