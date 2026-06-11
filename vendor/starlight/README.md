# Starlight — Alleral UI (Maclib-inspired)

Programmatic UI library for Alleral game scripts. Visual design inspired by [Maclib UI Library](https://github.com/biggaboy212/Maclib) — macOS traffic lights, sidebar tabs, glass sections, Inter typography.

## Layout

```
vendor/starlight/
  lib/           Source modules (edit these)
  init.luau      Studio require entry
  Source.lua     Bundled output for executors
  bundle.py      Rebuild Source.lua after lib changes
```

## Rebuild

```bash
python vendor/starlight/bundle.py
```

## Usage

Loaded via `Alleral_Core.loadStarlight()` → `vendor/starlight/Source.lua`.

Press **K** to toggle the window. Use `Core.wrapStarlightGroup(groupbox, callbackWrapper)` for shorthand helpers in game scripts.
