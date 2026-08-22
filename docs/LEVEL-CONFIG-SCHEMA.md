# LevelConfig / DifficultyProfile Schema

`LevelConfig` (`scripts/core/level_config.gd`) is the explicit, validated
configuration for one parametric level. `DifficultyProfile`
(`scripts/core/difficulty_profile.gd`) is the progression table: one row per
difficulty. Adding a level 11+ is just adding a row to `DifficultyProfile.LEVELS`.

## Level JSON format (shipped levels)

```json
{
  "id": "1",
  "difficulty": 1,
  "clearing_capacity": 7,
  "deck": ["cat", "cat", "cat", "dog", "dog", "dog"],
  "time_thresholds": { "three_stars": 60, "two_stars": 120 },
  "rewards": [{ "type": "hold", "quantity": 1 }]
}
```

- `difficulty` — row index into `DifficultyProfile.LEVELS`; the board is
  generated from the profile. Optional overrides:
  - `max_generation_attempts` (int) — attempt budget (default 60).
- `deck` — card types drawn from during play. Each type count is a multiple
  of 3 so totals stay valid with the board.

`LevelLoader.resolve` resolves `difficulty` via the profile and attaches:
`cards`, `board_width`, `board_height`, `card_size`, `deck_a`, `deck_b`,
`generation_metrics` (see below). It never returns an unsolvable level: if no
solvable board is found within the budget it retries (x1..x4) and then errors
instead of falling back.

## LevelConfig fields

| field | meaning |
|---|---|
| `board_types` | distinct card types placed on the board |
| `count_per_type` | board copies per type (must be multiple of 3) |
| `columns`, `rows` | logical grid dimensions |
| `occupancy_h`, `occupancy_v` | fraction of grid cells used per layer |
| `layers` | stacking depth |
| `overlap` | mean covered fraction; per-axis `overlap_h`/`overlap_v` derived, clamped to H [0.35,0.60] / V [0.35,0.55] |
| `free_ratio` | target free cards; `free_ratio_min`/`free_ratio_max` = verifiable band per profile |
| `complexity` | 1..11 difficulty rating |
| `card_size`, `pitch_ratio` | card size (48) and reference pitch (0.86); the anchor pitch is derived from occupancy |
| `seed`, `max_attempts` | generation seed and attempt budget |
| `available_card_types` | the 12 registry types (read-only) |
| `types_used_in_level` | board ∪ deck types actually used |
| `deck_types` | deck multiset (set via `with_deck`) |

Levels 1–11 ship in `DifficultyProfile.LEVELS` (11+ = add a row; see
`docs/adr/0001-post-l10-envelope-strategy.md`). Level 11 is config-only inside
the envelope, proving the extension path.

## Guardrails (explicit, enforced by `LevelConfig.validate`)

> Envelope policy for levels 11+ is governed by `docs/adr/0001-post-l10-envelope-strategy.md`.
> Configs stay inside these guardrails; structural expansion requires an explicit
> `BoardEnvelopeProfile`, never a per-level conditional.

Canonical mode is **portrait** (360x640, board ~332x264 after the responsive
layout). Landscape has a dedicated responsive UI (640x360) leaving a ~546x240
board area.

- `MAX_SLOT_COLUMNS = 7`, `MAX_SLOT_ROWS = 6` — slot grid size.
- `MAX_LAYERS = 4`
- `MAX_BOARD_CARDS = 36`
- `MIN_CARD_SIZE_PX = 24` — minimum rendered card size in an envelope.
- `PORTRAIT_BOARD_ENVELOPE = (332, 264)`, `LANDSCAPE_BOARD_ENVELOPE = (546, 240)`
- Per-axis overlap: H ∈ [0.35, 0.60], V ∈ [0.35, 0.55]; same-layer anchor
  distance ≥ 0.35 × card.
- `free_ratio` target inside its declared `free_ratio_min/max`.

`validate()` **rejects** configs that exceed the slot/layer/card guardrails,
violate the overlap ranges, or that do not fit the canonical portrait
envelope. Configs that do not fit the landscape board envelope are **marked**
(`fits_landscape = false`) and surfaced as a visible layout warning in the
level screen — they are not silently hidden. All shipped levels (1–11) fit
both envelopes.

## Central visual metrics

`LevelConfig` consts used by the renderer: `CARD_LOGICAL_SIZE=48`,
`MIN_CARD_SCALE=0.85`, `RESERVE_CARD_SCALE=0.80`, `BOARD_PADDING=8`,
`HEADER_HEIGHT=40`, `INSTRUCTION_HEIGHT=18`, `BOARD_MIN_HEIGHT=200`,
`MAX_VISIBLE_LAYERS=4`. The level screen consumes the level's `card_size` and
clamps the board scale at `MIN_CARD_SCALE` (`BoardLayout.compute`
`scale_limited`); support decks/reserve render at `RESERVE_CARD_SCALE`.

## Generation pipeline

`LayoutGenerator.generate_level(config)` runs:
geometry → slots → layers → trios → distribution → spatial validation →
blocking (free ratio) → solvability → instantiation. It never returns an
unsolvable board; failures propagate up to `LevelLoader`, which logs and
retries with a larger budget, then errors.

## generation_metrics

Per-generation: `difficulty`, `board_cards`, `deck_cards`, `types`,
`types_used_in_level`, `available_card_types`, `columns`, `rows`,
`slot_columns`, `slot_rows`, `occupancy_h/v`, `layers`, `overlap`,
`overlap_h/v`, `free_ratio`, `free_ratio_target`, `free_ratio_min/max`,
`free_ratio_ok`, `free_cards`, `blocked_cards`, `max_coverage`, `min_exposure`,
`anchor_occupancy_h/v`, `min_same_layer_distance`, `complexity`, `card_size`,
`seed`, `seed_used`, `attempts`, `status`, `solvable`, `clearing_capacity`,
`generation_time_ms`, `fits_portrait`, `fits_landscape`, `min_card_px_portrait`,
`min_card_px_landscape`.

## Render scale (single source)

Positions are generated in **logical space** (`LayoutGenerator._geometry`
ignores the container). `BoardLayout.compute` (`scripts/core/board_layout.gd`)
maps logical positions onto the container with one uniform scale; the renderer
(`level_screen._board_layout`) applies it without snapping to a fixed pitch.
Deck split is deterministic from the layout seed actually used (`seed_used`).