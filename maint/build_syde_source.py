#!/usr/bin/env python3
"""Merge upstream Syde with Alleral compat fixes into ui/syde/source.luau."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "ui" / "syde" / "upstream.luau"
COMPAT = ROOT / "ui" / "syde" / "compat.luau"
PATCHES = ROOT / "ui" / "syde" / "patches"
OUT = ROOT / "ui" / "syde" / "source.luau"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_block(text: str, start: str, end: str) -> str:
    i = text.index(start)
    j = text.index(end, i)
    return text[i:j]


def replace_from(text: str, start: str, new_tail: str) -> str:
    i = text.index(start)
    return text[:i] + new_tail


def replace_between(text: str, start: str, end: str, new_body: str) -> str:
    i = text.index(start)
    j = text.index(end, i)
    return text[:i] + new_body + text[j:]


def convert_dropdown_block(block: str, page_expr: str, return_name: str) -> str:
    block = re.sub(
        r"local dropdown = sydeClonePageTemplate\([^)]+\)",
        f'local dropdown = sydeClonePageTemplate({page_expr}, "Dropdown")',
        block,
        count=1,
    )
    block = re.sub(
        r"local dropdown = .*?:Clone\(\)",
        f'local dropdown = sydeClonePageTemplate({page_expr}, "Dropdown")',
        block,
        count=1,
    )
    insert = (
        f'\t\t\tlocal drop = sydePrepareDropdownDrop(dropdown)\n'
        f'\t\t\tif not drop or not drop.Container then\n'
        f'\t\t\t\twarn("[Syde] Skipping dropdown: " .. tostring(data.Title))\n'
        f"\t\t\t\treturn {return_name}\n"
        f"\t\t\tend\n"
    )
    anchor = "dropdown.Name = data.Title\n"
    if anchor in block and "sydePrepareDropdownDrop(dropdown)" not in block:
        block = block.replace(anchor, anchor + insert, 1)
    block = block.replace("dropdown.dropholder.drop.selected.Text = data.PlaceHolder", "sydeSetDropSelectedText(drop, data.PlaceHolder)")
    block = block.replace("dropdown.dropholder.drop", "drop")
    return block


def adapt_modal(block: str) -> str:
    block = block.replace(
        "local ModalInstance = modalTemplate and modalTemplate:Clone()",
        "local ModalInstance = ui.main and ui.main.modal and ui.main.modal:Clone()",
    )
    block = block.replace("if not ModalInstance or not window then", "if not ModalInstance or not ui.main then")
    block = block.replace("ModalInstance.Parent = window", "ModalInstance.Parent = ui.main")
    block = block.replace(
        "if activeModals == 1 and dimOverlay then",
        "if activeModals == 1 and ui.main and ui.main.dim then",
    )
    block = block.replace("dimOverlay.Visible = true", "ui.main.dim.Visible = true")
    block = block.replace(
        "tweenservice:Create(dimOverlay, TweenInfo.new(0.73, Enum.EasingStyle.Exponential), {",
        "tweenservice:Create(ui.main.dim, TweenInfo.new(0.73, Enum.EasingStyle.Exponential), {",
    )
    block = block.replace(
        "if activeModals == 0 and dimOverlay then",
        "if activeModals == 0 and ui.main and ui.main.dim then",
    )
    block = block.replace("dimOverlay.Visible = false", "ui.main.dim.Visible = false")
    block = block.replace("if dimOverlay then", "if ui.main and ui.main.dim then")
    if "sydeSanitizeUiClone(ModalInstance)" not in block:
        block = block.replace(
            "ModalInstance.Visible = true\n",
            "ModalInstance.Visible = true\n\t\tsydeSanitizeUiClone(ModalInstance)\n",
            1,
        )
    if "sydeResolveModal(ModalInstance)" not in block:
        block = block.replace(
            "ModalInstance.Parent = ui.main\n",
            "ModalInstance.Parent = ui.main\n\t\tlocal modalParts = sydeResolveModal(ModalInstance)\n",
            1,
        )
    return block


def silence_syde_logging(text: str) -> str:
    """Route Syde print/warn through silent Alleral compat stubs."""
    text = re.sub(r"\bprint\s*\(", "sydeLog(", text)
    text = re.sub(r"\bwarn\s*\(", "sydeWarn(", text)
    return text


def main() -> None:
    upstream = read(UPSTREAM)
    compat = read(COMPAT)
    modal_block = adapt_modal(read(PATCHES / "modal.luau"))

    loader_match = re.search(
        r"(local Loader\s*=.*?110221114597158.*?\[1\]\s*\n)",
        upstream,
        re.DOTALL,
    )
    if not loader_match:
        raise RuntimeError("Could not find Loader assignment in upstream Syde")
    insert_at = loader_match.end()
    body = upstream[:insert_at] + "\n" + compat + "\n" + upstream[insert_at:]

    body = re.sub(
        r"window\.settings\.pages\.page\.(\w+):Clone\(\)",
        r'sydeClonePageTemplate(window.settings.pages.page, "\1")',
        body,
    )
    body = re.sub(
        r'window\.settings\.pages\.page\["3DView"\]:Clone\(\)',
        r'sydeClonePageTemplate(window.settings.pages.page, "3DView")',
        body,
    )
    body = re.sub(
        r"pages\.page\.(\w+):Clone\(\)",
        r'sydeClonePageTemplate(pages.page, "\1")',
        body,
    )
    body = re.sub(
        r'pages\.page\["3DView"\]:Clone\(\)',
        r'sydeClonePageTemplate(pages.page, "3DView")',
        body,
    )

    body = body.replace(
        "function tbdata:InitTab(tab)\n",
        "function tbdata:InitTab(tab)\n\t\tif type(tab) == \"string\" then\n\t\t\ttab = { Title = tab }\n\t\tend\n",
        1,
    )

    keybind_patch = "\n\tif library.Keybind then\n\t\tuitoggle = library.Keybind\n\tend\n"
    anchor = "\tData.Home.profileImage = Data.Home.profileImage or Data.profileImage"
    if anchor in body and keybind_patch.strip() not in body:
        body = body.replace(anchor, anchor + keybind_patch, 1)

    body = replace_between(body, "function syde:Modal(Modal)", "--@@Toast", modal_block)

    settings_dropdown = convert_dropdown_block(
        extract_block(upstream, "function telement:Dropdown(Dropdown)", "\n\t\t\tfunction telement:Slider"),
        "window.settings.pages.page",
        "telement",
    )
    body = replace_between(
        body,
        "function telement:Dropdown(Dropdown)",
        "\n\t\t\tfunction telement:Slider",
        settings_dropdown,
    )

    page_dropdown = convert_dropdown_block(
        extract_block(upstream, "function initelement:Dropdown(Dropdown)", "\n\t\t--@@Colorpicker"),
        "pages.page",
        "initelement",
    )
    body = replace_between(
        body,
        "function initelement:Dropdown(Dropdown)",
        "\n\t\t--@@Colorpicker",
        page_dropdown,
    )

    footer_start = "\t\treturn initelement\n\n\n\tend\n\treturn tbdata"
    end_patch = """
\t\tfunction initelement:Select()
\t\t\tSwitchToTab(tdata.Title)
\t\tend

\t\treturn initelement


\tend

\tfunction tbdata:Toggle()
\t\tToggleUI()
\tend

\tfunction tbdata:GetState()
\t\treturn not uiclosed
\tend

\tfunction tbdata:SetState(state)
\t\tlocal want = state == true
\t\tif want and uiclosed then
\t\t\tToggleUI()
\t\telseif not want and not uiclosed then
\t\t\tToggleUI()
\t\tend
\tend

\treturn tbdata


end

syde.__AlleralPatch = ALLERAL_SYDE_PATCH

return syde
"""
    if footer_start not in body:
        raise RuntimeError("Syde Init footer anchor missing — upstream layout changed")
    body = replace_from(body, footer_start, end_patch)

    body = silence_syde_logging(body)
    OUT.write_text(body, encoding="utf-8")
    print(f"Wrote {OUT} ({len(body)} bytes, {body.count(chr(10)) + 1} lines)")


if __name__ == "__main__":
    main()
