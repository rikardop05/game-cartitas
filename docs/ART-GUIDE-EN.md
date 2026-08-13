# Art Guide — Cartitas Infinity (EN)

Guide for the pixel artist to add card, effects, and UI sprites to the Godot project.

## 1. Overview

- 2D **pixel art** game, base logical resolution **360×640** (9:16 portrait), integer upscale, *nearest* filtering (no smoothing).
- File format: **PNG**.
- Sizes:
  - **Card (face and back): 32×32 px**
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
| `assets/cards/cat.png` … `crystal.png` | 32×32 | 12 card faces (one file per type) |
| `assets/cards/back.png` | 32×32 | Card back (top of the Support Decks) |
| `assets/ui/power_hold.png` | 16×16 | Hold power icon |
| `assets/ui/power_undo.png` | 16×16 | Undo power icon |
| `assets/ui/power_refresh.png` | 16×16 | Refresh power icon |
| `assets/ui/star_filled.png` | 16×16 | Filled star |
| `assets/ui/star_empty.png` | 16×16 | Empty star |
| `assets/ui/background.png` | 360×640 | Screen background |

**Naming convention:** `card_<type>.png` (e.g. `card_cat.png`), all lowercase. The 12 types are: `cat, dog, bird, fish, flower, moon, star, sun, leaf, heart, gem, crystal`.

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
2. (Integration step) Point sprite loading to the `assets/` files — game logic **does not change**, only the visual layer.

No game rule depends on art; art is purely presentation.
