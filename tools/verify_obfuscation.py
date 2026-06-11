#!/usr/bin/env python3
"""Verify Alleral protected Luau payloads decode to valid-looking source."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def bxor(a: int, b: int) -> int:
    r, m = 0, 1
    while a > 0 or b > 0:
        ra, rb = a % 2, b % 2
        if ra != rb:
            r += m
        a, b, m = a // 2, b // 2, m * 2
    return r


def _lua_unescape(value: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(value):
        if value[i] == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            if nxt.isdigit():
                j = i + 1
                digits = ""
                while j < len(value) and value[j].isdigit() and len(digits) < 3:
                    digits += value[j]
                    j += 1
                out.append(chr(int(digits) % 256))
                i = j
                continue
            if nxt == "n":
                out.append("\n")
                i += 2
                continue
            if nxt == "r":
                out.append("\r")
                i += 2
                continue
            if nxt == "t":
                out.append("\t")
                i += 2
                continue
            if nxt == "\\":
                out.append("\\")
                i += 2
                continue
            if nxt == '"':
                out.append('"')
                i += 2
                continue
            out.append(nxt)
            i += 2
            continue
        out.append(value[i])
        i += 1
    return "".join(out)


def decode_protected(text: str) -> str | None:
    lens_match = re.search(r"local __lens = \{([0-9,\s]+)\}", text)
    sum_match = re.search(r"if \w+ ~= (\d+) or", text)
    if not (lens_match and sum_match):
        return None

    keys_match = re.search(
        r"local \w+ = \{(?:\"(?:\\.|[^\"\\])*\"(?:\s*,\s*\"(?:\\.|[^\"\\])*\")*)\}\s*\n\tlocal __lens",
        text,
    )
    if not keys_match:
        return None
    keys = [_lua_unescape(k) for k in re.findall(r'"((?:\\.|[^"\\])*)"', keys_match.group(0))]

    data_match = re.search(
        r"local \w+ = \{\s*((?:\d+\s*,\s*)+)\s*\}\s*\n\tlocal \w+ = \{",
        text,
        re.DOTALL,
    )
    if not data_match:
        return None
    bytes_raw = [int(n) for n in re.findall(r"\d+", data_match.group(1))]

    lens = [int(x.strip()) for x in lens_match.group(1).split(",") if x.strip()]
    expected_sum = int(sum_match.group(1))

    buf: list[int] = []
    pos = 1
    for length in lens:
        for i in range(length):
            buf.append(bytes_raw[pos + i - 1])
        pos += length

    if pos - 1 != len(bytes_raw):
        return None

    for key in reversed(keys):
        key_bytes = key.encode("latin1", errors="surrogateescape")
        decoded: list[int] = []
        for i, value in enumerate(buf):
            ki = i % len(key_bytes)
            decoded.append(bxor(value, key_bytes[ki]))
        buf = decoded

    if sum(buf) % 65521 != expected_sum:
        return None

    try:
        return bytes(buf).decode("utf-8")
    except UnicodeDecodeError:
        return None


def verify(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "Alleral Protected" not in text:
        print(f"SKIP {path} (not protected)")
        return True
    decoded = decode_protected(text)
    if not decoded:
        print(f"FAIL {path}: could not decode payload")
        return False
    if "function" not in decoded:
        print(f"FAIL {path}: decoded payload is not valid Luau")
        return False
    print(f"OK   {path} ({len(decoded)} bytes decoded)")
    return True


def main() -> None:
    targets = [
        ROOT / "core/alleral_core.luau",
        ROOT / "core/telemetry.luau",
        ROOT / "core/analytics.luau",
    ]
    ok = all(verify(path) for path in targets if path.is_file())
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
