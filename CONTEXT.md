# Cartitas Infinity

A card-matching puzzle game built in Godot. The player clears a board by selecting cards into a limited Clearing Zone, where three of the same type are removed automatically.

## Language

**Level**:
A playable stage with its own board layout, support decks, time thresholds, and first-win rewards. The campaign ships 15 Levels.
_Avoid_: Stage, Phase, "fase" (in code)

**Board**:
The physical layout of cards in a level: a grid-aligned layered pyramid (upper layers sit on quarter-card offsets over the layer below), so cards overlap across layers but never within one.

**Design Size**:
The logical UI coordinate space (360×640 portrait, 640×360 landscape) used for layout rects and control sizes; the `canvas_items` stretch scales it to the real window. Touch targets are checked in design px.
_Avoid_: screen size, resolution, window pixels

**Oversample**:
The factor (1–4, in half steps) between one design pixel and a real screen pixel. 9-slice panels are baked at design size × oversample and drawn back at 1/oversample so painted corners stay sharp on 2× windows.
_Avoid_: upscale factor (the old design-size bake), zoom, DPI

**Card**:
A single playable tile on the board. Has a unique id, a type, a position, a layer, a state, and a source (board or support deck).

**Card Type**:
The identity that determines matching. Two cards match if and only if they share the same Card Type. The game ships 15 Card Types (14 with painted art; `crystal` is still a placeholder).
_Avoid_: typeId (that is a field, not the concept)

**Card State**:
The lifecycle of a card: `HIDDEN`, `AVAILABLE`, `SELECTED`, `MATCHED`, `REMOVED`.

**Blocked**:
A card that cannot be selected because at least one active higher-layer card covers 10% or more of its area.

**Clearing Zone**:
The limited temporary area that holds selected cards. Three cards of the same type are removed automatically.
_Avoid_: hand, tray

**Support Deck**:
An auxiliary finite pile of cards the player can draw from into the Clearing Zone. Each level has two; a Card Type appears at most twice per deck, and every deck type also appears on the board.
_Avoid_: deck (alone)

**Power**:
A limited-use special ability: `Hold`, `Undo`, `Refresh`.

**Hold**:
A power that moves the 3 oldest cards (the leftmost) of the Clearing Zone into the Reserve, freeing space.
_Avoid_: Remove (misleading — cards are not removed from the game)

**Reserve**:
A temporary per-level area that holds cards moved out of the Clearing Zone. Cards here can be returned to the Clearing Zone.

**Inventory**:
The persistent stock of powers owned by the player.

**Endless Mode**:
A post-campaign mode, unlocked by winning the last campaign Level, made of consecutive Rounds with rising difficulty, a Score and a local best.

**Round**:
One generated board inside an Endless Mode run. Clearing it leads to the next Round; losing ends the run.
_Avoid_: Level (inside Endless Mode), stage

**Score**:
Endless Mode points: per matched card plus a bonus per cleared Round. The campaign has no Score, only stars.

**Hero**:
The character drawn beside the board who says the instruction, tips and reactions (it replaced the single mascot "Ace"). One Hero is fixed per Level or Endless Round; every Hero speaks with the same neutral "hero" line family.
_Avoid_: Mascot (the old single host), NPC

**Hero Portrait**:
The full-body painted image that represents a Hero (`assets/ui/heroes/hero_<id>.png`). Campaign Levels 1–9 have their own portrait; Levels 10–11 fall back to the menu wolf; Levels 12–14 use the new `cat_mage`, `rhino` and `sacer` portraits; Level 15 reuses the `wolf_knight` portrait. Endless Mode rotates the nine original heroes each Round (the three new portraits stay campaign-only).
_Avoid_: Mascot sprite, avatar

**Hero Expression**:
An alternate Hero Portrait used only by the Level 8 bunny, chosen by mood: thinking (idle), sequence (happy), bad choice (worried), defeat (sad). Other heroes keep one portrait and vary by tint and vertical offset.
_Avoid_: Frame (ambiguous with animation frames)

**Logo**:
The painted Claw & Crown wordmark (`assets/ui/branding/logo_claw_and_crown.png`) shown in the menu in place of the title text. "Cartitas Infinity" stays the internal project name.
_Avoid_: Title (the text fallback used when the logo art is missing)

**Action**:
A single player interaction: select a card, draw a deck card, or use a power.
