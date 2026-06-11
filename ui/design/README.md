# Alleral UI — Design System

**Primary platform: [Design Lab](./lab/index.html)** — local, unlimited, version-controlled.  
No Figma accounts, page caps, or MCP rate limits.

| Platform | Best for | Limits |
|----------|----------|--------|
| **[Design Lab](./lab/)** | Day-to-day UI work, previews, QA | None — open `lab/index.html` in a browser |
| **`tokens.json`** | Source of truth for code + lab | Edit once, sync to lab CSS |
| Figma (optional) | Sharing with external designers | Starter: 3 pages, MCP caps |
| [Penpot](https://penpot.app) (optional) | Open-source Figma alternative | Free, self-hostable, no page cap |

## Quick start — Design Lab

```powershell
# From repo root — opens in default browser
start ui/design/lab/index.html
```

Or drag `ui/design/lab/index.html` into Chrome/Edge.

### What's inside

- **Foundations** — colors, spacing bars, motion notes
- **Components** — tabs, toggles, buttons, sections (MacLib-style)
- **Hub Screen** — full 860×560 hub mock with spring open animation, notifications, reduced-motion toggle

Lab reads the same tokens as `aller.luau` via `tokens.css` (mirrors `tokens.json`).

## Files

| Path | Purpose |
|------|---------|
| `tokens.json` | Single source of truth — colors, spacing, motion, components |
| `lab/index.html` | Interactive design system (unlimited) |
| `lab/tokens.css` | CSS custom properties from tokens |
| `lab/lab.css` | Component styles |
| `lab/lab.js` | Spring motion + interactions |
| `screens/window-desktop.figma.md` | Layout blueprint (platform-agnostic) |
| `figma-variables.json` | Optional Figma import |
| `code-connect/*.figma.ts` | Optional Figma Dev Mode (Enterprise) |

## Workflow (recommended)

1. Change **`tokens.json`** when updating palette or `MAC` spacing in `aller.luau`
2. Mirror key values in **`lab/tokens.css`**
3. Preview in **Design Lab** — iterate freely (infinite pages/variants)
4. Implement in **`aller.luau`**
5. *(Optional)* Export screenshots from the lab for docs or Penpot/Figma reference

## Optional: Penpot (Figma replacement)

If you want a **cloud canvas** without Figma's limits:

1. Sign up at [penpot.app](https://penpot.app) (free, open source)
2. Import colors/spacing from `tokens.json`
3. Use the lab screenshots as reference for frames

Penpot has no 3-page limit and no Cursor MCP rate cap for manual editing.

## Optional: Figma

Partial file (Starter limits): [Alleral UI Design System](https://www.figma.com/design/YiRgNhH8kJbA41vnerUCZK)

Use Figma only if you need team collaboration on a paid plan. For solo/all-agent workflow, **Design Lab is the default**.

## Sync checklist

When editing `aller.luau`:

1. Update `ui/design/tokens.json`
2. Update `ui/design/lab/tokens.css`
3. Reload Design Lab in browser
4. Verify Hub tab matches in-game feel
