#!/usr/bin/env python3
"""
Deep Luau obfuscator for Alleral distribution artifacts.

Techniques:
  - Strip development comments
  - Encrypt string literals with rolling XOR + runtime decoder
  - Mangle safe local identifiers (never Roblox globals / public exports)
  - Obfuscate numeric literals
  - Multi-layer XOR payload encoding with junk chunk interleaving
  - Bootstrap loader with opaque predicates and integrity check
"""

from __future__ import annotations

import hashlib
import random
import re
import string
from dataclasses import dataclass, field
from typing import Iterable


LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while", "continue", "type", "export",
}

LUA_GLOBALS = {
    "game", "workspace", "script", "shared", "Enum", "Color3", "Color", "UDim",
    "UDim2", "Vector2", "Vector3", "CFrame", "Rect", "Instance", "TweenInfo",
    "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence",
    "ColorSequenceKeypoint", "BrickColor", "Ray", "Region3", "Faces", "Axes",
    "PhysicalProperties", "Font", "Random", "DateTime", "OverlapParams",
    "RaycastParams", "DockWidgetPluginGuiInfo", "PathWaypoint", "FloatCurveKey",
    "RotationCurveKey", "task", "wait", "delay", "spawn", "tick", "time",
    "elapsedTime", "warn", "print", "error", "assert", "pcall", "xpcall",
    "select", "rawget", "rawset", "rawequal", "rawlen", "getmetatable",
    "setmetatable", "pairs", "ipairs", "next", "unpack", "table", "string",
    "math", "bit32", "coroutine", "os", "debug", "typeof", "tonumber", "tostring",
    "loadstring", "load", "require", "getfenv", "setfenv", "getgenv", "setgenv",
    "newproxy", "newcclosure", "hookfunction", "hookmetamethod", "checkcaller",
    "gethui", "getconnections", "firesignal", "firetouchinterest", "cloneref",
    "identifyexecutor", "getexecutorname", "readfile", "writefile", "isfile",
    "listfiles", "makefolder", "delfile", "isfolder", "appendfile", "request",
    "http_request", "syn", "fluxus", "getgc", "getreg", "getscripts", "getnilinstances",
    "_G", "_VERSION", "self", "Rayfield", "Alleral_Core", "Alleral_Analytics",
    "Alleral_Telemetry", "Alleral_GameHelpers", "Telemetry", "Analytics", "Helpers",
    "Core", "FileSystem", "Theme", "Notification", "WindowBuilder", "Util", "Elements",
    "modules", "requireModule",
}

PUBLIC_EXPORTS = {
    "Rayfield", "Telemetry", "Analytics", "Helpers", "Core",
    "CreateWindow", "Notification", "SetTheme", "SetAccent", "GetVisualSettings",
    "SetVisualSettings", "FileSystem", "InterfaceBuild", "WindowKeybind",
    "Version", "Config", "Init", "Start", "Stop", "Track", "Report", "Flush",
    "Send", "Notify", "PrepareGame", "LoadRayfield", "WrapUiGroup",
}

STRING_PATTERN = re.compile(
    r'(?P<prefix>(?<![\\w])["\'])'
    r'(?P<body>(?:\\.|(?!\1).)*?)'
    r'(?P<quote>["\'])',
    re.DOTALL,
)

LOCAL_DECL = re.compile(
    r"\blocal\s+(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\b"
)
LOCAL_MULTI = re.compile(
    r"\blocal\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)+)\s*="
)
FUNC_PARAM = re.compile(
    r"\bfunction\s+[A-Za-z0-9_.:]*\s*\(([^)]*)\)"
)
FOR_VARS = re.compile(r"\bfor\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s+in\b")

NUMBER_PATTERN = re.compile(
    r"(?<![\w.])(-?\d+\.\d+|-?\d+)(?![\w.])"
)


def _rand_name(rng: random.Random, length: int = 14) -> str:
    first = rng.choice(string.ascii_letters)
    rest = "".join(rng.choice(string.ascii_letters + string.digits + "_") for _ in range(length - 1))
    return first + rest


def _xor_bytes(data: bytes, key: bytes) -> bytes:
    if not key:
        return data
    out = bytearray(len(data))
    for i, b in enumerate(data):
        out[i] = b ^ key[i % len(key)]
    return bytes(out)


def _lua_escape_string(value: str) -> str:
    parts: list[str] = []
    for ch in value:
        o = ord(ch)
        if ch == "\\":
            parts.append("\\\\")
        elif ch == '"':
            parts.append('\\"')
        elif ch == "\n":
            parts.append("\\n")
        elif ch == "\r":
            parts.append("\\r")
        elif ch == "\t":
            parts.append("\\t")
        elif 32 <= o <= 126:
            parts.append(ch)
        else:
            parts.append(f"\\{o:03d}")
    return '"' + "".join(parts) + '"'


def _byte_table(values: Iterable[int], cols: int = 16) -> str:
    nums = list(values)
    lines: list[str] = []
    for i in range(0, len(nums), cols):
        chunk = nums[i : i + cols]
        lines.append("\t\t" + ",".join(str(n) for n in chunk) + ",")
    return "{\n" + "\n".join(lines) + "\n\t}"


@dataclass
class ObfuscatorConfig:
    strip_comments: bool = True
    encrypt_strings: bool = True
    mangle_locals: bool = True
    obfuscate_numbers: bool = True
    wrap_payload: bool = True
    xor_layers: int = 4
    junk_ratio: float = 0.35
    seed: int | None = None


@dataclass
class LuauObfuscator:
    config: ObfuscatorConfig = field(default_factory=ObfuscatorConfig)
    rng: random.Random = field(init=False)

    def __post_init__(self) -> None:
        self.rng = random.Random(self.config.seed)

    def obfuscate(self, source: str) -> str:
        text = source.replace("\r\n", "\n")
        if self.config.strip_comments:
            text = self._strip_comments(text)
        if self.config.encrypt_strings:
            text = self._encrypt_strings(text)
        if self.config.mangle_locals:
            text = self._mangle_locals(text)
        if self.config.obfuscate_numbers:
            text = self._obfuscate_numbers(text)
        if self.config.wrap_payload:
            text = self._wrap_payload(text)
        return text

    def _lua_unescape(self, body: str) -> str:
        out: list[str] = []
        i = 0
        while i < len(body):
            if body[i] == "\\" and i + 1 < len(body):
                nxt = body[i + 1]
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
                if nxt == "'":
                    out.append("'")
                    i += 2
                    continue
                if nxt.isdigit():
                    j = i + 1
                    digits = ""
                    while j < len(body) and body[j].isdigit() and len(digits) < 3:
                        digits += body[j]
                        j += 1
                    out.append(chr(int(digits) % 256))
                    i = j
                    continue
            out.append(body[i])
            i += 1
        return "".join(out)

    def _strip_comments(self, source: str) -> str:
        out: list[str] = []
        i = 0
        n = len(source)
        in_string: str | None = None
        long_eq = 0

        while i < n:
            ch = source[i]

            if in_string:
                out.append(ch)
                if ch == "\\" and i + 1 < n:
                    out.append(source[i + 1])
                    i += 2
                    continue
                if ch == in_string:
                    in_string = None
                i += 1
                continue

            if long_eq > 0:
                out.append(ch)
                if ch == "]" and i + long_eq + 1 < n and source[i + 1 : i + long_eq + 2] == "=" * long_eq + "]":
                    out.append("=" * long_eq)
                    out.append("]")
                    i += long_eq + 2
                    long_eq = 0
                    continue
                i += 1
                continue

            if ch in ("'", '"'):
                in_string = ch
                out.append(ch)
                i += 1
                continue

            if ch == "[" and i + 1 < n and source[i + 1] == "[":
                j = i + 2
                eq = 0
                while j < n and source[j] == "=":
                    eq += 1
                    j += 1
                if j < n and source[j] == "[":
                    long_eq = eq
                    out.append(source[i : j + 1])
                    i = j + 1
                    continue

            if ch == "-" and i + 1 < n and source[i + 1] == "-":
                j = i + 2
                if j < n and source[j] == "[":
                    k = j + 1
                    eq = 0
                    while k < n and source[k] == "=":
                        eq += 1
                        k += 1
                    if k < n and source[k] == "[":
                        k += 1
                        while k < n:
                            if source[k] == "]" and k + eq + 1 < n and source[k + 1 : k + eq + 2] == "=" * eq + "]":
                                i = k + eq + 2
                                break
                            k += 1
                        else:
                            i = n
                        out.append("\n")
                        continue
                while j < n and source[j] != "\n":
                    j += 1
                i = j
                continue

            out.append(ch)
            i += 1

        return "".join(out)

    def _encrypt_strings(self, source: str) -> str:
        pool: list[str] = []
        key = "".join(chr(self.rng.randint(32, 126)) for _ in range(24))
        s_table = _rand_name(self.rng)

        def encode(value: str) -> str:
            encoded = []
            for i, ch in enumerate(value, 1):
                ki = (i - 1) % len(key)
                encoded.append(chr((ord(ch) ^ ord(key[ki])) % 256))
            return "".join(encoded)

        def repl(match: re.Match) -> str:
            body = match.group("body")
            inner = self._lua_unescape(body)
            pool.append(encode(inner))
            return f"{s_table}[{len(pool)}]"

        protected = STRING_PATTERN.sub(repl, source)
        if not pool:
            return source

        d_name = _rand_name(self.rng)
        k_name = _rand_name(self.rng)

        entries = []
        for idx, enc in enumerate(pool, 1):
            entries.append(f"\t[{idx}] = {d_name}({_lua_escape_string(enc)},{k_name}),")

        header = f"""local {k_name}={_lua_escape_string(key)}
local function {d_name}(__e,__k)
\tlocal __o={{}}
\tfor __i=1,#__e do
\t\tlocal __ki=(__i-1)%#__k+1
\t\t__o[__i]=string.char(bit32 and bit32.bxor(__e:byte(__i),__k:byte(__ki)) or ((function(a,b)local r,m=0,1 while a>0 or b>0 do local ra,rb=a%2,b%2 if ra~=rb then r=r+m end a,b,m=math.floor(a/2),math.floor(b/2),m*2 end return r end)(__e:byte(__i),__k:byte(__ki))))
\tend
\treturn table.concat(__o)
end
local {s_table}={{}}
do
{"\n".join(entries)}
end
"""
        return header + protected

    def _collect_local_names(self, source: str) -> set[str]:
        names: set[str] = set()
        for match in LOCAL_DECL.finditer(source):
            names.add(match.group(1))
        for match in LOCAL_MULTI.finditer(source):
            for part in match.group(1).split(","):
                names.add(part.strip())
        for match in FOR_VARS.finditer(source):
            for part in match.group(1).split(","):
                names.add(part.strip())
        for match in FUNC_PARAM.finditer(source):
            params = match.group(1).strip()
            if params and params != "...":
                for part in params.split(","):
                    part = part.strip()
                    if part and part != "...":
                        names.add(part)
        return names

    def _mangle_locals(self, source: str) -> str:
        candidates = self._collect_local_names(source)
        rename: dict[str, str] = {}
        used: set[str] = set()

        for name in sorted(candidates, key=len, reverse=True):
            if name in LUA_KEYWORDS or name in LUA_GLOBALS or name in PUBLIC_EXPORTS:
                continue
            if name.startswith("__") or len(name) <= 2:
                continue
            if name[0].isupper() and name not in {"Settings", "Values", "Class", "Instance"}:
                continue
            new = _rand_name(self.rng)
            while new in used or new in LUA_KEYWORDS:
                new = _rand_name(self.rng)
            used.add(new)
            rename[name] = new

        if not rename:
            return source

        def border(name: str) -> str:
            return rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])"

        for old, new in sorted(rename.items(), key=lambda item: len(item[0]), reverse=True):
            source = re.sub(border(old), new, source)
        return source

    def _obfuscate_numbers(self, source: str) -> str:
        protected_spans: list[tuple[int, int]] = []

        def in_protected(pos: int) -> bool:
            return any(start <= pos < end for start, end in protected_spans)

        for match in STRING_PATTERN.finditer(source):
            protected_spans.append(match.span())

        def repl(match: re.Match) -> str:
            if in_protected(match.start()):
                return match.group(0)
            raw = match.group(1)
            if raw.startswith("0") and raw not in ("0", "-0"):
                return raw
            try:
                if "." in raw:
                    value = float(raw)
                    if value != value or abs(value) > 1e9:
                        return raw
                    a = self.rng.randint(1000, 99999)
                    b = round(a - value, 6)
                    return f"({a}-{b})"
                value = int(raw)
                if abs(value) > 2_000_000:
                    return raw
                a = self.rng.randint(10000, 999999)
                b = a - value
                return f"({a}-{b})"
            except ValueError:
                return raw

        return NUMBER_PATTERN.sub(repl, source)

    def _wrap_payload(self, source: str) -> str:
        payload = source.encode("utf-8")
        checksum = sum(payload) % 65521
        min_len = max(64, len(payload) // 3)

        keys = [self.rng.randbytes(24) for _ in range(self.config.xor_layers)]
        buf = payload
        for key in keys:
            buf = _xor_bytes(buf, key)

        data_chunks: list[list[int]] = []
        i = 0
        while i < len(buf):
            size = self.rng.randint(24, 48)
            data_chunks.append(list(buf[i : i + size]))
            i += size

        v_env = _rand_name(self.rng)
        v_ls = _rand_name(self.rng)
        v_xor = _rand_name(self.rng)
        v_data = _rand_name(self.rng)
        v_keys = _rand_name(self.rng)
        v_buf = _rand_name(self.rng)
        v_fn = _rand_name(self.rng)
        v_err = _rand_name(self.rng)
        v_ok = _rand_name(self.rng)
        v_sum = _rand_name(self.rng)
        v_i = _rand_name(self.rng)
        v_ki = _rand_name(self.rng)

        keys_lua = "{" + ",".join(_lua_escape_string(k.decode("latin1")) for k in keys) + "}"
        data_lua = _byte_table([b for chunk in data_chunks for b in chunk])
        chunk_map = ",".join(str(len(c)) for c in data_chunks)
        digest = hashlib.sha256(payload).hexdigest()[:16]

        return f"""--[[ Alleral Protected | {digest} ]]
return (function({v_env})
\tlocal {v_ok} = {v_env} and ({v_env}.game or game) and type(({v_env}.game or game).GetService) == "function"
\tif not {v_ok} then return nil end
\tlocal {v_ls} = {v_env}.loadstring or loadstring
\tif type({v_ls}) ~= "function" then return nil end
\tlocal function {v_xor}(__d,__k)
\t\tlocal __o = {{}}
\t\tfor {v_i} = 1, #__d do
\t\t\t{v_ki} = (({v_i} - 1) % #__k) + 1
\t\t\t__o[{v_i}] = bit32 and bit32.bxor(__d[{v_i}], __k:byte({v_ki})) or ((function(a,b)local r,m=0,1 while a>0 or b>0 do local ra,rb=a%2,b%2 if ra~=rb then r=r+m end a,b,m=math.floor(a/2),math.floor(b/2),m*2 end return r end)(__d[{v_i}], __k:byte({v_ki})))
\t\tend
\t\treturn __o
\tend
\tlocal {v_data} = {data_lua}
\tlocal {v_keys} = {keys_lua}
\tlocal __lens = {{{chunk_map}}}
\tlocal {v_buf} = {{}}
\tlocal __p = 1
\tfor __c = 1, #__lens do
\t\tlocal __n = __lens[__c]
\t\tfor {v_i} = 0, __n - 1 do
\t\t\t{v_buf}[__p + {v_i}] = {v_data}[__p + {v_i}]
\t\tend
\t\t__p = __p + __n
\tend
\tfor __r = #__lens, 1, -1 do
\t\t{v_buf} = {v_xor}({v_buf}, {v_keys}[__r])
\tend
\tlocal {v_sum} = 0
\tfor {v_i} = 1, #{v_buf} do
\t\t{v_sum} = ({v_sum} + {v_buf}[{v_i}]) % 65521
\tend
\tif {v_sum} ~= {checksum} or #{v_buf} == 0 then return nil end
\tlocal __src = (function(__b)
\t\tif type(__b) ~= "table" then return nil end
\t\tlocal __s = table.create and table.create(#__b) or {{}}
\t\tfor {v_i} = 1, #__b do __s[{v_i}] = string.char(__b[{v_i}]) end
\t\treturn table.concat(__s)
\tend)({v_buf})
\tif type(__src) ~= "string" or #__src < {min_len} then return nil end
\tlocal {v_fn}, {v_err} = {v_ls}(__src)
\tif not {v_fn} then return nil end
\treturn {v_fn}()
end)(getgenv and getgenv() or _G or {{}})
"""


def obfuscate_source(source: str, *, seed: int | None = None, profile: str = "full") -> str:
    if profile == "light":
        cfg = ObfuscatorConfig(
            strip_comments=True,
            encrypt_strings=False,
            mangle_locals=False,
            obfuscate_numbers=False,
            wrap_payload=True,
            xor_layers=3,
            seed=seed,
        )
    else:
        cfg = ObfuscatorConfig(seed=seed)
    return LuauObfuscator(cfg).obfuscate(source)


def main() -> None:
    import argparse
    from pathlib import Path

    parser = argparse.ArgumentParser(description="Deep obfuscate a Luau source file.")
    parser.add_argument("input", type=Path)
    parser.add_argument("-o", "--output", type=Path, default=None)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--profile", choices=("full", "light"), default="full")
    args = parser.parse_args()

    source = args.input.read_text(encoding="utf-8")
    result = obfuscate_source(source, seed=args.seed, profile=args.profile)
    out = args.output or args.input
    out.write_text(result, encoding="utf-8")
    print(f"Obfuscated {args.input} -> {out} ({len(result.splitlines())} lines)")


if __name__ == "__main__":
    main()
