# Art Guide — Cartitas Infinity (EN)

Guide for the pixel artist to produce and deliver card and UI sprites.
The illustrated version to send to the artist is the PDF [`ART-DELIVERY-PT.pdf`](ART-DELIVERY-PT.pdf) (Portuguese; source: `docs/art-delivery/ART-DELIVERY-PT.html`).

## 1. Overview

- 2D **pixel art** game, primary logical resolution **640×360** (16:9 landscape). The development window is **1280×720** (integer 2×) with *nearest* filtering (no smoothing).
- Portrait mode remains available at **360×640**, but it is not the reference layout.
- Format: **32-bit PNG (RGBA, 8 bits per channel)**, sRGB, non-interlaced.
- All art is drawn at **1 art pixel = 1 logical game pixel**. The game scales by code; do not deliver upscaled files as production assets.

## 2. Sizes (card art standard)

Card faces are delivered at **high resolution** and the game scales them at draw time: **square PNG** (minimum 512; prefer multiples of 64). The current set is **882–957 px** — each card is cropped at the hard frame silhouette and kept at its native square size (e.g. 957 px from a 960 px source, 882 px when the source is smaller), never upscaled to a fixed number.

Why: the UI is laid out at 640×360 (landscape) / 360×640 (portrait) **logical** px but drawn at the **physical screen resolution** (`stretch mode = canvas_items`). A 40 px logical card is 80 real px in a 1280×720 window, 120 px in 1080p fullscreen, and more on bigger screens. The game builds **mipmaps** when it loads the art and draws it with **trilinear** filtering (`UiHelpers.card_texture` + `_make_card_art`), so the GPU scales straight from the original to the real size — sharp at any resolution, no re-export needed.

Sizes where a card appears (logical px; multiply by the window scale for real pixels):

| Where | Displayed size |
|-------|----------------|
| Board | up to 40 (`LevelConfig.MAX_BOARD_CARD_PX`), smaller on big boards |
| Clearing Zone | 40 (landscape) / 36 (portrait) |
| Reserve | 18–40, in a grid that fits the box |
| Support Decks | top card inside the 64 px slot |

Consequence for the art: the subject must read at **~30 logical px** (strong silhouette, dark outline, few very thin details).

## 3. Card anatomy

The PNG is drawn **as the whole card face** (no extra background or border from the game). Follow the current template (`assets/cards/card_mouse.png`):

- A painted **dark metal frame** with rivets and a carved ornament at each corner, around the edge.
- A **parchment inner area** with the **illustration centred**, dark outline, ~10% breathing room to the frame.
- **Transparent** outside the frame, with a clean cut silhouette: no white halo, no drop shadow, no glow and no stray specks. The game bleeds the edge colour into the transparent pixels, so a white matte would show as a rim.
- **The frame touches all four canvas edges**: crop at the hard alpha edge (alpha ≥ 240) and deliver a square with no transparent margin. Do not upscale a smaller source just to hit 960.
- Same framing and lighting on every card so the set reads as one family.
- Blocked cards are darkened by the game; do not deliver dark variants.

## 3b. Painted HUD art

Painted plaques and icons (stars, stopwatch, gear) live in `assets/ui/hud/` and follow the card standard: transparent high-resolution PNGs (icons >= 512 px; star plaques ~1024 px wide, one image per state `stars_1/2/3.png`), drawn with mipmaps and trilinear filtering.

## 3c. Painted heroes

Level heroes live in `assets/ui/heroes/` as `hero_<id>.png`: full-body painted PNGs, transparent background, no white halo, no drop shadow, cropped to the silhouette, high resolution (770-1220 px wide × 1260-1520 px tall). Drawn with mipmaps and trilinear filtering.

Level map (used by the level screen):

| Level | File |
|-------|------|
| 1 | `hero_cat.png` |
| 2 | `hero_wolf_ranger.png` |
| 3 | `hero_boar.png` |
| 4 | `hero_mouse.png` |
| 5 | `hero_owl.png` |
| 6 | `hero_frog.png` |
| 7 | `hero_knight.png` |
| 8 | `hero_bunny.png` |
| 9 | `hero_wolf_knight.png` |
| 10 / 11 | fallback (`hero_menu_wolf.png` keeps the menu hero) |

Level 8 (bunny) also has four expression variants, same size and framing as `hero_bunny.png`:

| File | Use |
|------|-----|
| `hero_bunny_thinking.png` | thinking / waiting |
| `hero_bunny_sequence.png` | showing the sequence |
| `hero_bunny_bad_choice.png` | wrong choice |
| `hero_bunny_defeat.png` | loss |

The menu hero is `assets/ui/heroes/hero_menu_wolf.png` (rear-view wolf knight). The game logo is `assets/ui/branding/logo_claw_and_crown.png` (transparent, 1748×866).

The bunny also has a rigged idle: `assets/ui/heroes/bunny_rig/bunny_rig.tscn` (2D skeleton + `AnimationPlayer`, autoplay `Idle`, 4 s, layered `Polygon2D` body parts in `bunny_rig/`). It plays where the bunny is the mascot (L8 idle and the Endless rounds) and hides while one of the four painted expression frames is showing.

## 3d. Match FX

Card-match effects live in `assets/ui/fx/`: `match_burst.png` (blue burst, plays on a triple) and `match_smoke.png` (blue smoke puffs + droplets). Both are RGBA PNGs with a transparent background and keep their soft glow (do not crop the alpha, only the empty border).

## 3e. Level backgrounds

Full-bleed painted backgrounds, one per level range. No alpha, no cropping: the art already covers the whole frame and is drawn stretched to the screen with linear filtering.

| Levels | Set | Landscape | Portrait |
|--------|-----|-----------|----------|
| 1–3 | meadow | `assets/ui/background.png` (640×360) | `assets/ui/background_portrait.png` (360×640) |
| 4–7 | autumn town | `assets/ui/background_autumn.png` (1672×941) | reuses the landscape art |
| 8–11 | castle | `assets/ui/background_castle.png` (1280×720) | `assets/ui/background_castle_portrait.png` (532×720) |

Keep contrast low and detail out of the centre: dark semi-transparent panels and the cards sit on top.

## 3f. Painted panels (UI kit)

Stretchable panels live in `assets/ui/kit/`. All are cropped to the silhouette (transparent margins removed, no outer shadow) and are drawn as `NinePatchRect`, so the patch margins must keep the carved corners whole:

| File | Size | Use | 9-slice margin |
|------|------|-----|----------------|
| `bar_zone.png` | 2162×314 | Clearing Zone bar (clear area x 56–2105, y 44–257) | 72 px (end caps) |
| `panel_powers_board.png` | 751×1453 | Powers board, vertical (clear area x 78–690, y 76–1368) | 96 px |
| `panel_reserve_field.png` | 1829×741 | Reserve field — stone interior is part of the art (cards are drawn on top) | 192 px |
| `card_available_frame.png` | 1160×1077 | Available-card frame (clear area x 75–1086, y 72–1004) | 96 px |

## 3g. Menu assets

| File | Size | Notes |
|------|------|-------|
| `assets/ui/background_menu.png` | 640×360 | Menu background, landscape only (no portrait variant) |
| `assets/ui/branding/btn_menu_jogar.png` | 64×32 | Pixel-art "JOGAR" button |
| `assets/ui/branding/btn_menu_opcoes.png` | 64×32 | Pixel-art "OPÇÕES" button |
| `assets/ui/branding/btn_menu_sair.png` | 64×32 | Pixel-art "SAIR" button |

The buttons are pixel art: draw them at 1× or whole multiples with Nearest filtering, mipmaps off and lossless compression (already the project import defaults). Keep the game logo (`assets/ui/branding/logo_claw_and_crown.png`) separate from the buttons.

## 4. Palette

Use a **shared limited palette** (~32 colors). Base colors per type live in `scripts/core/card_type_registry.gd`:

| Type | Base color |
|------|------------|
| mouse | `#b8a46a` |
| cat | `#c9564f` |
| boar | `#b0713c` |
| owl | `#7a6bc9` |
| wolf | `#8fa3b8` |
| duck | `#d9a441` |
| frog | `#7fae4a` |
| whale | `#4f7fc9` |
| leaf | `#6bc98a` |
| heart | `#e06a6a` |
| gem | `#6ac9d9` |
| crystal | `#9a7ae0` |

UI colors already in use: level screen background `#c78454`, panel border `#f3d28d`, text `#fff1d2`, stars `#ffe36e`, placeholder frame `#fff2d5`.

Card subjects (current art): `mouse` hooded scholar with a book; `cat` hooded archer in a red cloak; `boar` armoured bruiser with a mace; `owl` mage with a staff; `wolf` plate knight; `duck` gunslinger with a hat; `frog` leaf-cloaked ranger; `whale` pirate captain; `leaf` green ranger (elf archer); `heart` golden paladin bunny; `gem` blue bunny knight (silver armour, blue scarf and cape); `crystal` still the placeholder. `heart` and `gem` are different characters — never reuse one for the other. `heart` (`#e06a6a`) and `cat` are both warm reds: tell them apart by silhouette and symbol, not color.

Deliver a `palette/palette.png` with every color used (one 8×8 square per color).

## 5. Files

### Phase 1 — required (already loaded by the game)

| File | Size | Description |
|------|------|-------------|
| `assets/cards/card_<type>.png` | native square (min. 512) | 12 card faces, one per type (frame included, cropped to the hard frame edge) |

`UiHelpers.card_texture()` looks for `res://assets/cards/card_<type>.png`; without the file, the game uses the placeholder (color + emoji). The 12 types: `mouse, cat, boar, owl, wolf, duck, frog, whale, leaf, heart, gem, crystal`. Eleven have painted art; `crystal` still uses the placeholder.

### Phase 2 — optional (not wired in code yet; the UI uses text/emoji today)

| File | Size | Description |
|------|------|-------------|
| `assets/cards/back.png` | 48×48 | Card back (reserved for future use) |
| `assets/ui/power_hold.png` | 16×16 | Hold power icon (moves 3 cards from the Clearing Zone to the Reserve) |
| `assets/ui/power_undo.png` | 16×16 | Undo power icon (returns the last Clearing Zone card) |
| `assets/ui/power_refresh.png` | 16×16 | Refresh power icon (reshuffles the board and Support Decks) |
| `assets/ui/star_filled.png` | 16×16 | Filled star (HUD) |
| `assets/ui/star_empty.png` | 16×16 | Empty star (HUD) |

Level backgrounds are listed in section 3e.

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
│   ├── cards/   card_mouse.png … card_crystal.png (12; crystal may still be a placeholder)  [+ back.png]
│   └── ui/      (phase 2, if delivered)
├── palette/     palette.png
├── source/      editable files (.aseprite, .psd, …)
├── preview/     (optional) same art upscaled 4× — for review only
└── LEIAME.txt   version, date, change list, notes
```

## 9. Godot import (done by the integrator)

- **Cards** (`assets/cards/`): just copy the PNG as `card_<type>.png`. The game builds the mipmaps and uses trilinear filtering on its own; no *Import* panel changes needed. Older art lives in `assets/cards/legacy/` (a folder Godot ignores).
- **Pixel-art UI kit and icons** (`assets/ui/kit/`): Filter **Nearest** (project default), Mipmaps **off**, Compress **Lossless**, drawn at 1x or whole multiples.
- **Painted backgrounds** (`assets/ui/`): the game applies linear filtering and the softening shader.

No game rule depends on the art; art is presentation only.
