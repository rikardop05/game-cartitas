# LevelConfig / DifficultyProfile Schema

`LevelConfig` (`scripts/core/level_config.gd`) is the explicit, validated
configuration for one parametric level. `DifficultyProfile`
(`scripts/core/difficulty_profile.gd`) is the progression table: one row per
difficulty. Adding a level 12+ is just adding a row to `DifficultyProfile.LEVELS`.

Boards for every parametric Level and every Endless round are built by
`BoardPipeline` through `LevelBoardGenerator` (`scripts/core/level_board_generator.gd`):
full-card base, scattered quarter-card upper layers, pyramidal counts, one shared
blocking rule. `LayoutGenerator` is legacy and
only serves hand-written `layout` levels (no shipped level uses it).

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
  - `randomize_per_attempt` (bool, default `true`) — draw a fresh base seed on
    every load so each retry shows a new (still solvable) board. `false` keeps
    the profile's fixed `seed`. Tests and tools force the fixed seed for every
    level with `LevelLoader.deterministic = true`.
- `deck` — card types drawn from during play. Each type count is a multiple
  of 3 so totals stay valid with the board.

`LevelLoader.resolve` resolves `difficulty` via the profile (campaign JSONs and
`EndlessRun.build_round_level` both go through it) and attaches: `cards`,
`board_width`, `board_height` (the occupied size of the delivered board),
`card_size`, `deck_a`, `deck_b`, `generation_metrics` (see below). It never
returns an unsolvable level: if no solvable board is found within the budget it
retries (x1..x4) and then errors instead of falling back.

## DifficultyProfile row

Fields of one `DifficultyProfile.LEVELS` row (see the header comment of the file):

| field | meaning |
|---|---|
| `board_types` | distinct card types placed on the board |
| `board_cards` | board card total (multiple of 3); trios go to the types in turn, so some types hold one trio more and every type stays a multiple of 3. Without it the total is `board_types.size() × count_per_type` |
| `count_per_type` | board copies per type (multiple of 3); used only when `board_cards` is absent |
| `columns`, `rows` | largest base-layer grid, **in whole cards** (wide: about 2:1) |
| `layers` | pyramid height (stacking depth) |
| `layer_ratio` | optional, default 0.5: share each upper layer holds of the layer below; lower = more cards free at the start |
| `aspect_min` | optional, default 1.15: narrowest accepted base aspect (width / height); L3+ ask for 1.5-1.6 so the base stays wide |
| `aspect_target`, `aspect_max` | optional, defaults 2.0 / 2.4: aspect the base growth steers toward, widest accepted base |
| `free_ratio` | target share of free (not blocked) cards at the start |
| `free_ratio_min`, `free_ratio_max` | preferred band for `free_ratio` (default target ∓ 0.15) |
| `complexity` | informative 1..11 rating |
| `seed` | base seed |
| `card_size`, `max_attempts` | optional: card size (default 48) and attempt budget (default 60) |

Shipped progression (deterministic seeds; the base is the occupied layer-0 box, rendered
card = fitted to the envelope, never above `MAX_BOARD_CARD_PX = 40`):

| level | types | board cards | base (cols × rows) | cards per layer | free at start | rendered card px (landscape / portrait) |
|---|---|---|---|---|---|---|
| 1 | 3 | 9 | 4 × 2 | 7 / 2 | 5 | 40 / 40 |
| 2 | 5 | 15 | 4 × 3 | 10 / 5 | 7 | 40 / 40 |
| 3 | 7 | 21 | 5 × 3 | 12 / 6 / 3 | 9 | 40 / 40 |
| 4 | 8 | 27 | 5 × 3 | 15 / 8 / 4 | 9 | 40 / 40 |
| 5 | 8 | 33 | 6 × 3 | 18 / 10 / 5 | 11 | 40 / 40 |
| 6 | 9 | 39 | 7 × 3 | 21 / 12 / 6 | 13 | 40 / 40 |
| 7 | 9 | 45 | 7 × 4 | 25 / 13 / 7 | 14 | 40 / 40 |
| 8 | 9 | 48 | 7 × 4 | 26 / 13 / 6 / 3 | 14 | 40 / 40 |
| 9 | 10 | 54 | 8 × 4 | 29 / 14 / 7 / 4 | 16 | 40 / 40 |
| 10 | 10 | 57 | 8 × 4 | 30 / 15 / 8 / 4 | 16 | 40 / 40 |
| 11 | 10 | 63 | 9 × 4 | 34 / 17 / 8 / 4 | 20 | 40 / 36.9 |

L5+ bases are 1.75-2.33 wide (`aspect_min` 1.6). Generation stays under ~200 ms per level
at the fixed seeds (about 600 ms for all 11, budget 1500 ms in `tests/probe_generation.gd`);
a random seed costs a few solvability checks.

Obsolete keys of the scattered generator (`occupancy_h/v`, `overlap*`, `pitch_ratio`,
`slot_*`, `anchor_*`) were removed from `LevelConfig`; `LevelConfig.create` ignores
them if an old row still carries them.

Levels 1–11 ship in `DifficultyProfile.LEVELS` (12+ = add a row; see
`docs/adr/0001-post-l10-envelope-strategy.md`). Level 11 is config-only inside
the envelope, proving the extension path.

## LevelConfig fields

| field | meaning |
|---|---|
| `board_types` | distinct card types placed on the board |
| `board_cards` / `count_per_type` | board card total (multiple of 3, 0 = unset) / copies per type (multiple of 3, used when the total is unset); `board_count(type)` is the per-type board count |
| `columns`, `rows` | base grid in cards (`board_width() = columns × card_size`, `board_height() = rows × card_size`) |
| `layers` | stacking depth |
| `layer_ratio` | fraction of the lower layer held by each upper layer |
| `aspect_target`, `aspect_min`, `aspect_max` | base aspect steering and acceptance band (defaults 2.0, 1.15, 2.4) |
| `free_ratio` | target free cards; `free_ratio_min`/`free_ratio_max` = preferred band per profile |
| `complexity` | 1..11 difficulty rating |
| `card_size` | logical card size (48) |
| `seed`, `max_attempts` | base seed and attempt budget |
| `available_card_types` | the 12 registry types (read-only) |
| `types_used_in_level` | board ∪ deck types actually used |
| `deck_types` | deck multiset (set via `with_deck`) |

Derived helpers: `board_cards()`, `deck_card_count()`, `total_cards()`,
`layer_targets()` (cards per layer, base first), `envelope_card_size(envelope, size)`,
`fits_portrait()`, `fits_landscape()`, `build_spec(geometry_seed, symbol_seed)`,
`generate(board_size)` (delegates to `LevelBoardGenerator`), `metrics()`.

## Profile → BoardSpec mapping

`LevelConfig.build_spec(geometry_seed, symbol_seed)` turns a row into the
`BoardSpec` (`scripts/core/board_spec.gd`) consumed by `BoardPipeline`:

| BoardSpec | from |
|---|---|
| `card_count` | `board_cards()` = `board_cards` or `board_types.size() × count_per_type` |
| `card_size` | `card_size` |
| `board_width`, `board_height` | `columns × card_size`, `rows × card_size` (largest area the base may take) |
| `layers`, `layer_ratio` | same names |
| `aspect_target`, `aspect_min`, `aspect_max` | same names (base aspect steering and gate) |
| `geometry_seed` | `seed_used` of the attempt (`config.seed + attempt`) |
| `symbol_seed` | `LevelBoardGenerator.symbol_seed_for(seed_used)` |
| `card_types` | `board_types` |

`BoardSpec.validate()` rejects: `layer_ratio` outside (0, 1), `layers > card_count`,
a `card_count` below the triangular minimum `layers × (layers + 1) / 2`, non-unique or
empty `card_types`, a `card_count` that is not a multiple of 3 when types are given,
and a full-card lattice (`floor(board_width/card_size) × floor(board_height/card_size)`)
too small for the base layer.

## Layers and geometry

`BoardPipeline.layer_targets(card_count, layers, layer_ratio)` gives the cards per
layer: geometric weights `layer_ratio^k`, every layer non-empty and strictly smaller
than the one below, exact total (surplus goes to the base). Falls back to the
triangular staircase (`layers … 1`, surplus on the base) when the weights cannot
satisfy that.

- **Base layer (0):** connected, on a full-card lattice (coordinates flush with the
  board's left/top edge), grown compactly inside `columns × rows`.
- **Upper layers (k > 0):** scattered, like the front cards of a shuffled pile. Every
  card of the board stores its position in **quarter-card steps** (`grid_x` / `grid_y`;
  base cards sit on multiples of 4, so `x = grid_x × card_size / 4`; at the 40 px render
  cap a quarter card is exactly 10 px). Candidates are all quarter-card positions inside
  the base footprint (its bounding box) where the card
  - overlaps **at least two** cards of layer k-1 at or above the shared blocking threshold
    (it rests on the pile; `support_ids` lists every card it rests on), and
  - hides no card of layer k-1 by more than 75% (`LevelValidator.MAX_OVERLAP`).

  Cards of one layer never overlap. A seeded greedy scatter takes the cheapest candidate
  `layer_targets` times (pyramid counts are unchanged; higher layers may be sparser). Cost
  grows with: a same-layer card exactly side by side on the same row/column (strong) or
  merely in line within three cards; crowding by same-layer neighbours; the fractional x /
  y offset (relative to the base grid) and the left/centre/right x top/bottom region
  the layer already uses; and burying lower cards that are still free (a stack on cards the
  layer already covers is cheaper, so starts stay fair). A layer too dense for the full
  spacing relaxes the spread costs step by step (`SCATTER_RELAX`). Ten percent of every
  big layer (8+ cards, below the top) is **reserved**: no card above may block those cards,
  which are spread over the layer by farthest-point sampling, so no layer starts buried.
- **No same-layer overlap:** cards of one layer never overlap (hard gate). No random
  coordinates anywhere.

## Guardrails (explicit, enforced by `LevelConfig.validate`)

> Envelope policy for levels 11+ is governed by `docs/adr/0001-post-l10-envelope-strategy.md`.
> Configs stay inside these guardrails; structural expansion requires an explicit
> `BoardEnvelopeProfile`, never a per-level conditional.

Canonical mode is **portrait** (360x640, board area 338x173 inside the 352x192 kit board
window). Landscape (640x360) leaves a 450x189 board area inside the 464x208 window, a 450x189 board
area.

- `MAX_COLUMNS = 9`, `MAX_ROWS = 6` — base grid in cards.
- `MAX_LAYERS = 4`
- `MAX_BOARD_CARDS = 72`
- `MAX_BOARD_CARD_PX = 40` — the renderer never draws a board card larger than this (both orientations); small boards stay centered at that size and `envelope_card_size` reports the capped size.
- `MIN_CARD_SIZE_PX = 24` — minimum rendered card size in an envelope (the renderer floors the board scale at `MIN_CARD_SCALE`, i.e. 30 px).
- `PORTRAIT_BOARD_ENVELOPE = (332, 264)`, `LANDSCAPE_BOARD_ENVELOPE = (466, 214)`
- `free_ratio_min ≤ free_ratio ≤ free_ratio_max`, all inside [0, 1].

`validate()` **rejects** configs that: have no board types or counts that are not
multiples of 3 (per type, board and total); exceed the grid/layer/card guardrails;
produce an invalid `BoardSpec`; need a base layer (`layer_targets()[0]`) larger than
`columns × rows`; do not fit the canonical portrait envelope; or declare an
inconsistent `free_ratio` band. Configs that do not fit the landscape board envelope
are **marked** (`fits_landscape = false`) and surfaced as a visible layout warning in
the level screen — they are not silently hidden. All shipped levels (1–11) fit both
envelopes.

## Generation pipeline

`LevelBoardGenerator.generate(config, board_size)` runs, for attempt *i* (geometry
seed `config.seed + i`, up to `max_attempts`):

1. **Spec** — `build_spec` → `BoardSpec.validate()`.
2. **Base layer** — compact growth on the full-card lattice; gates: no large holes
   (≤ 4 half-cells), no narrow bridges, density ≥ 0.55, aspect within the spec's
   `[aspect_min, aspect_max]` (pipeline defaults 1.15..2.25; shipped rows steer toward 2.0 and
   ask L3+ for 1.5-1.6 up to 2.4) (the shape
   gates are waived for tiny bases and for the triangular-minimum pyramid).
3. **Upper layers** — scattered on the quarter-card lattice over supports (above).
4. **Layer and scatter gates** — no same-layer overlap, every upper card supported by at
   least 2 cards below, blocking graph computed with `BoardSpatialRules`; and, for
   layered boards, no tidy rows (at most 50% of the upper cards with a same-layer card
   exactly side by side, no run of more than 3; layers of 5+ cards), varied offsets (a
   layer of 5+ cards uses at least 2 distinct fractional x and y offsets, 8+ cards at
   least 3), spread (a layer of 6+ cards has cards in all three horizontal thirds and both
   vertical halves of the base footprint) and no starved layer (a reserved layer keeps at
   least 7% of its cards free). `BoardPipeline` itself tries up to `MAX_ATTEMPTS = 64`
   internal variants per geometry seed and fails with `SPEC_INVALID`,
   `BUDGET_EXHAUSTED`, `COMPACTNESS_REJECTED` or `UPPER_LAYER_REJECTED`.
5. **Symbols** — assigned only after all geometry gates pass (shuffled trios, seeded by
   `symbol_seed`).
6. **Export** — cards cropped so the occupied box touches (0, 0) (whole-card shift, the
   quarter-card lattice is kept); `board_width`/`board_height` = occupied size.
7. **Free-ratio band** — boards whose free share is inside
   `[free_ratio_min, free_ratio_max]` are returned immediately; otherwise the closest
   solvable board to `free_ratio` is kept as fallback (`free_ratio_ok = false`).
8. **Solvability** — `SolvabilityChecker.is_solvable` with the level's Support Decks
   (`LevelBoardGenerator.split_decks`, seeded by `seed_used`) and a power stock. An
   unsolvable board is never returned.

Failures propagate to `LevelLoader`, which logs and retries with a larger budget
(x1..x4), then errors. `board_size` (the UI's available area) never changes the
geometry — one seed gives the same board in every orientation — it only feeds the
fit metrics.

## One blocking rule

`BoardSpatialRules` (`scripts/core/board_spatial_rules.gd`) is the single
implementation of blocking: a card on a higher layer blocks a card below it when it
covers 10% or more of its area (`BLOCK_THRESHOLD = 0.10`); cards of the same layer
never block each other. It is used by `BoardManager` at runtime, `BoardPipeline` and
`LevelBoardGenerator` during generation and metrics, and `LevelValidator`.

`LevelValidator` additionally checks: unique ids, bounds, no stacked layer-0 cards, an
**error on same-layer overlap**, `MAX_OVERLAP = 0.75` (a single card of the layer
**directly above** may not hide more than 75% of a card; layers two or more apart may
line up exactly), at least one free card (`LevelValidator.free_card_count`), and deck
and time-threshold consistency.

## generation_metrics

Built from `LevelConfig.metrics()`, then extended by `LevelBoardGenerator` and
`LevelLoader`.

- **Profile** (`LevelConfig.metrics`): `difficulty`, `board_cards`, `deck_cards`,
  `types`, `types_used_in_level`, `available_card_types`, `columns`, `rows`, `layers`,
  `layer_ratio`, `layer_targets`, `free_ratio_target`, `free_ratio_min`,
  `free_ratio_max`, `complexity`, `card_size`, `seed`.
- **Result** (`LevelBoardGenerator`): `status` (`"ok"`), `solvable`, `generator`
  (`"board_pipeline"`), `attempts`, `seed_used`, `geometry_seed_used`,
  `symbol_seed_used`, `pipeline_attempts`, `free_ratio` (actual), `free_ratio_ok`,
  `free_cards`, `blocked_cards`, `cards_per_layer`, `layer_count`, `base_card_count`,
  `max_coverage`, `same_layer_overlaps`, `support_edge_count`, `blocking_edge_count`,
  `free_per_layer` (free cards per layer at the start, base first), `run_ratio` and
  `longest_run` (straightness of the upper layers), `occupied_width`, `occupied_height`.
- **Fit** (for the occupied board, not the largest allowed one): `fits_portrait`,
  `fits_landscape`, `min_card_px_portrait`, `min_card_px_landscape`; and, when a
  `board_size` is given, `available_board_size` and `fit_scale`.
- **Loader** (`LevelLoader`): `generation_time_ms`, `clearing_capacity`.

On failure the generator returns only `{status: "failed", attempts, difficulty}`.

## Central visual metrics

`LevelConfig` consts used by the renderer: `CARD_LOGICAL_SIZE=48`,
`MIN_CARD_SCALE=0.625` (30 px), `MAX_BOARD_CARD_PX=40`, `RESERVE_CARD_SCALE=0.80`, `BOARD_PADDING=8`,
`HEADER_HEIGHT=40`, `INSTRUCTION_HEIGHT=18`, `BOARD_MIN_HEIGHT=200`,
`MAX_VISIBLE_LAYERS=4`. The level screen consumes the level's `card_size` and
clamps the board scale between `MIN_CARD_SCALE` and the `MAX_BOARD_CARD_PX` cap (`BoardLayout.compute`
`scale_limited`). The board frames are 344x272 (portrait) and 478x222 (landscape),
which leave the 338x173 and 450x189 envelopes above.

## Render scale (single source)

Positions are generated in **logical space** (`LevelBoardGenerator` ignores the
container). `BoardLayout.compute` (`scripts/core/board_layout.gd`) maps logical
positions onto the container with one uniform scale; the renderer
(`level_screen._board_layout`) applies it exactly — no snapping to a fixed pitch and
no per-layer visual offset. Deck split is deterministic from the layout seed actually
used (`seed_used`).
