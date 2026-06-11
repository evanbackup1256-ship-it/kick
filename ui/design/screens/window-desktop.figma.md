# Screen: Hub Window (Desktop)

Blueprint for the main Alleral hub frame in Figma. Bind all values to variables from `figma-variables.json`.

## Frame

| Property | Token | Value |
|----------|-------|-------|
| Name | — | `Screen / Hub / Desktop` |
| Size | `size/window/*` | 860 × 560 |
| Fill | `color/bg/canvas` | #0f0f0f |
| Corner radius | `radius/window` | 10 |
| Stroke | `color/border/divider` | 1px @ 10% white |

## Layout (auto-layout horizontal)

```
┌─────────────────────────────────────────────────────────────┐
│ Sidebar (276px)          │ Content (fill)                   │
│ ┌─────────────────────┐  │ ┌─────────────────────────────┐ │
│ │ Title + subtitle    │  │ │ Topbar 63px + hairline       │ │
│ ├─────────────────────┤  │ ├─────────────────────────────┤ │
│ │ Tab 40px × N        │  │ │ Scroll: sections 15px gap    │ │
│ │ gap 6–17px          │  │ │ Section cards w/ 22px pad    │ │
│ └─────────────────────┘  │ └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Sidebar

- Width: **276px**
- Padding: top **31**, x **10**
- Divider: 1px white @ **90%** transparency (right edge)
- Tab row height: **40px**, left inset **24px**
- Active tab: rounded rect **8px** radius, white fill @ **10%**, stroke @ **8%**
- Inactive label opacity: **42%**

## Content area

- Horizontal padding: **20px**
- Section gap: **15px**
- Section internal padding: **22 / 20 / 20 / 18** (top/bottom/left/right)
- Row height: **38px**
- Scroll padding: **11 / 3 / 10 / 15** (L/R/T/B)

## Components to instance

1. `Window / Desktop` — outer shell
2. `Navigation / Tab` — sidebar items (variants: Default, Active, Hover)
3. `Layout / Section` — content groupboxes
4. `Control / Toggle`, `Control / Button`, `Control / Slider` — rows inside sections

## Motion annotations (FigJam note)

- Window open: spring `open` (f=5.6, d=0.88), scale 0.962 → 1
- Tab switch: spring `soft`
- Toggle: spring `toggle` with mint accent on ON
- Reduced motion profile: snap all transitions
