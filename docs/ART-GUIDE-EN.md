# Art Guide — Cartitas Infinity (EN)

Guide for the pixel artist to add card, effects, and UI sprites to the Godot project.

## 1. Overview

- 2D **pixel art** game, primary logical resolution **640×360** (16:9 landscape), with a **1280×720** development window, integer upscale, *nearest* filtering (no smoothing).
- Portrait mode remains available at **360×640**, but it is not the current reference layout.
- File format: **PNG**.
- The sizes below are source-art sizes. The rendered size can change with the available layout area.
- Current size units:
  - **Card (face and back): 64×64 px**
  - **Cards on the board, Support Decks and Clearing Zone: 48×48 px rendered**
  - **Reserve cards: 24–48×24–48 px**, reduced and stacked in two columns according to the count
  - **Power and star icons: 16×16 px**
  - Base UI grid: **8 px** (use multiples of 8 for alignment).

## 2. Palette

Use a **shared limited palette** (~32 colors) for cohesion. Each card type's base color is already defined in `scripts/core/card_type_registry.gd`:

| Type | Base color |
|------|------------|
| cat | `#e07a7a` |
| dog | `#d9a05b` |
| bird | `#e0c95b` |
| fish | `#6bb5e0` |
| flower | `#e08ac9` |
| moon | `#c9b8e0` |
| star | `#f0e060` |
| sun | `#f0b060` |
| leaf | `#6bc98a` |
| heart | `#e06a6a` |
| gem | `#6ac9d9` |
| crystal | `#9a7ae0` |

Providing a reference PNG of the full palette (cards + UI + background) in `assets/` is recommended.

## 3. Required files

| File (suggested) | Size | Description |
|------------------|------|-------------|
| `assets/cards/card_cat.png` … `card_crystal.png` | 64×64 | 12 card faces (one file per type) |
| `assets/cards/back.png` | 64×64 | Back reserved for future use; Support Decks currently show the top face |
| `assets/ui/power_hold.png` | 16×16 | Hold power icon |
| `assets/ui/power_undo.png` | 16×16 | Undo power icon |
| `assets/ui/power_refresh.png` | 16×16 | Refresh power icon |
| `assets/ui/star_filled.png` | 16×16 | Filled star |
| `assets/ui/star_empty.png` | 16×16 | Empty star |
| `assets/ui/background.png` | 640×360 | Landscape screen background; portrait variant should be 360×640 |

**Naming convention:** `card_<type>.png` (e.g. `card_cat.png`), all lowercase. The 12 types are: `cat, dog, bird, fish, flower, moon, star, sun, leaf, heart, gem, crystal`.

> Do not use the reference screenshot (1920×1020) as the production size. It is a presentation image; create art against the 640×360 logical resolution.

## 4. Card visual states

Logic already drives state; art/overlay only represents it. In v1, the project uses **code-applied overlays** (tint/darken) — no drawn variants needed:

- **Blocked (HIDDEN):** darkened/desaturated (gray overlay).
- **Available (AVAILABLE):** full color.
- **Selected (SELECTED):** white outline (optional glow).
- **Match (MATCHED):** scale + fade animation (done in code).

## 5. Animations

Animations (flying to the Clearing Zone, match, unlock, shuffle) are **code tweens**, not frame-by-frame art. Only the static art above is required.

## 6. Godot import

When adding a PNG to `assets/`, set in the *Import* panel:

- **Filter:** Nearest
- **Mipmaps:** off
- **Compress:** Lossless (for pixel art)

The project already sets nearest as the default filter; check new files only.

## 7. Replacing placeholders

The game currently uses **placeholders** (background color + emoji per type), defined in `scripts/core/card_type_registry.gd`. To switch to real art:

1. Create the PNGs at the paths above.
2. Optional loading already looks for `assets/cards/card_<type>.png`; without the file, the placeholder remains active.
3. Power, star, back and background art are references for the next visual integration; the current UI still uses text, emoji and a color background for these elements.

No game rule depends on art; art is purely presentation.
