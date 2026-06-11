import re
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "games" / "kick_a_lucky_block.luau"
text = path.read_text(encoding="utf-8")


def patch_create_toggle(src: str) -> str:
    pattern = re.compile(
        r"(\w+Group):CreateToggle\(\s*\n"
        r'(\s*)"([^"]+)",\s*\n'
        r"\s*state\.(\w+),\s*\n"
        r'(\s*)"([^"]*)",\s*\n'
        r"(\s*)function\(value\)\s*\n"
        r"([\s\S]*?)\n"
        r"\s*end\s*\n"
        r"\s*\)",
        re.M,
    )

    def repl(m):
        group, i1, name, key, i2, tip, i3, body = m.groups()
        if f'"{key}"' in m.group(0).split("end")[-1]:
            return m.group(0)
        return (
            f'{group}:CreateToggle(\n{i1}"{name}",\n\tstate.{key},\n{i2}"{tip}",\n'
            f"{i3}function(value)\n{body}\n\tend,\n\t\"{key}\"\n)"
        )

    return pattern.sub(repl, src)


def patch_create_slider(src: str) -> str:
    pattern = re.compile(
        r"(\w+Group):CreateSlider\(\s*\n"
        r'\s*"([^"]+)",\s*\n'
        r"\s*([\d.]+),\s*\n"
        r"\s*([\d.]+),\s*\n"
        r"\s*state\.(\w+),\s*\n"
        r"\s*function\(value\)\s*\n"
        r"([\s\S]*?)\n"
        r'\s*end,\s*\n'
        r'\s*"([^"]*)"\s*\n'
        r"\s*\)",
        re.M,
    )

    def repl(m):
        group, name, mn, mx, key, body, tip = m.groups()
        if f'"{key}"' in m.group(0):
            return m.group(0)
        return (
            f'{group}:CreateSlider(\n\t"{name}",\n\t{mn},\n\t{mx},\n\tstate.{key},\n'
            f"\tfunction(value)\n{body}\n\tend,\n\t\"{tip}\",\n\tnil,\n\t\"{key}\"\n)"
        )

    return pattern.sub(repl, src)


new_text = patch_create_slider(patch_create_toggle(text))
if new_text != text:
    path.write_text(new_text, encoding="utf-8", newline="\n")
    print("patched", path)
else:
    print("no changes")
