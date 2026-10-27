# Art Guide — Cartitas Infinity (EN)

Guide for the pixel artist to produce and deliver card and UI sprites.
The illustrated version to send to the artist is the PDF [`ART-DELIVERY-PT.pdf`](ART-DELIVERY-PT.pdf) (Portuguese; source: `docs/art-delivery/ART-DELIVERY-PT.html`).

## 1. Overview

- 2D **pixel art** game, primary logical resolution **640×360** (16:9 landscape). The development window is **1280×720** (integer 2×) with *nearest* filtering (no smoothing).
- Portrait mode remains available at **360×640**, but it is not the reference layout.
- Format: **32-bit PNG (RGBA, 8 bits per channel)**, sRGB, non-interlaced.
- All art is drawn at **1 art pixel = 1 logical game pixel**. The game scales by code; do not deliver upscaled files as production assets.

## 2. Sizes

The displayed card size is `Card.DISPLAY_SIZE` = **48×48 logical px** (`scripts/core/card.gd`). The card face is therefore drawn at **48×48**: at the default board size it shows at exactly 2× in the 1280×720 window, with no distorted pixels.

Where the same image currently appears (the code resizes the PNG to fit):

| Where | Displayed size (logical px) | Source in code |
|-------|-----------------------------|----------------|
| Board (default) | 48×48 | `LevelConfig.DEFAULT_CARD_SIZE` |
| Board (fit to space) | 41–120 (scale 0.85–2.5) | `BoardLayout.compute`, `MIN_CARD_SCALE` |
| Support Decks | ~38×38 (48 × 0.8) | `LevelConfig.RESERVE_CARD_SCALE` |
| Clearing Zone — landscape | 31×31 | `LANDSCAPE_ZONE_CARD_SIZE` |
| Clearing Zone — portrait | 48×48 | `CARD_DISPLAY_SIZE` |
| Reserve — landscape | 28–30, two columns | `LANDSCAPE_RESERVE_CARD_SIZE` |
| Reserve — portrait | 28–38, two columns | `_reserve_card_size()` |

Consequence: the symbol must be **readable at ~30 px** (strong silhouette, few thin 1 px details), because the image is shrunk in the small areas.

## 3. Card anatomy

The card PNG is drawn **over the whole card** (a card-sized `TextureRect`, see `_make_card_art` in `scripts/ui/level_screen.gd`). The placeholder frame and background color only show where the PNG is transparent. Therefore:

- Deliver the **complete face**: frame + background + symbol, within 48×48.
- Corners may be rounded using **fully transparent** pixels (the placeholder uses a ~5 px radius).
- Use the type's base color (table below) as the dominant background or symbol color so players recognize the type.
- Alpha **0 or 255 only** (no semi-transparency or anti-aliased edges).

## 4. Palette

Use a **shared limited palette** (~32 colors). Base colors per type live in `scripts/core/card_type_registry.gd`:

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

UI colors already in use: level screen background `#c78454`, panel border `#f3d28d`, text `#fff1d2`, stars `#ffe36e`, placeholder frame `#fff2d5`.

Note: `heart` (`#e06a6a`) and `cat` (`#e07a7a`) are nearly identical — tell them apart by symbol and silhouette, not color.

Deliver a `palette/palette.png` with every color used (one 8×8 square per color).

## 5. Files

### Phase 1 — required (already loaded by the game)

| File | Size | Description |
|------|------|-------------|
| `assets/cards/card_<type>.png` | 48×48 | 12 card faces, one per type |

`UiHelpers.card_texture()` looks for `res://assets/cards/card_<type>.png`; without the file, the game uses the placeholder (color + emoji). The 12 types: `cat, dog, bird, fish, flower, moon, star, sun, leaf, heart, gem, crystal`.

### Phase 2 — optional (not wired in code yet; the UI uses text/emoji today)

| File | Size | Description |
|------|------|-------------|
| `assets/cards/back.png` | 48×48 | Card back (reserved for future use) |
| `assets/ui/power_hold.png` | 16×16 | Hold power icon (moves 3 cards from the Clearing Zone to the Reserve) |
| `assets/ui/power_undo.png` | 16×16 | Undo power icon (returns the last Clearing Zone card) |
| `assets/ui/power_refresh.png` | 16×16 | Refresh power icon (reshuffles the board and Support Decks) |
| `assets/ui/star_filled.png` | 16×16 | Filled star (HUD) |
| `assets/ui/star_empty.png` | 16×16 | Empty star (HUD) |
| `assets/ui/background.png` | 640×360 | Screen background, landscape |
| `assets/ui/background_portrait.png` | 360×640 | Screen background, portrait |

The background sits behind dark semi-transparent panels and the cards: keep contrast low and avoid detail in the center.

**Naming:** all lowercase, no spaces or accents, exactly as in the tables.

> Do not use the 1920×1020 reference screenshot as a production size. It is a presentation image.

## 6. Visual states

Logic drives state; the art needs no variants.

- **Available (AVAILABLE):** full color.
- **Blocked (HIDDEN):** the code multiplies the card by 62% gray (`modulate = Color(0.62, 0.62, 0.62)`). Art must stay readable when darkened — avoid details that rely on dark tones.
- **Selected / match:** the card flies to the Clearing Zone and, on a triple, disappears with scale + fade. All tweens; no outline or frame is drawn.

## 7. Animations

Flying to the Clearing Zone, matching, unlocking and shuffling are **code tweens**. Only static art is needed.

## 8. Delivery

A single `.zip` whose root mirrors the project (it can be unzipped straight into the repository root):

```
cartitas_arte_v01_YYYY-MM-DD.zip
├── assets/
│   ├── cards/   card_cat.png … card_crystal.png (12)  [+ back.png]
│   └── ui/      (phase 2, if delivered)
├── palette/     palette.png
├── source/      editable files (.aseprite, .psd, …)
├── preview/     (optional) same art upscaled 4× — for review only
└── LEIAME.txt   version, date, change list, notes
```

## 9. Godot import (done by the integrator)

Once in the project, each PNG under `assets/` should have in the *Import* panel:

- **Filter:** Nearest (the project default is already nearest — `default_texture_filter=0`)
- **Mipmaps:** off
- **Compress:** Lossless

No game rule depends on the art; art is presentation only.
