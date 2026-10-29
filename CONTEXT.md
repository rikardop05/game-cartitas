# Cartitas Infinity

A card-matching puzzle game built in Godot. The player clears a board by selecting cards into a limited Clearing Zone, where three of the same type are removed automatically.

## Language

**Level**:
A playable stage with its own board layout, support decks, time thresholds, and first-win rewards.
_Avoid_: Stage, Phase, "fase" (in code)

**Board**:
The physical layout of cards in a level: a grid-aligned layered pyramid (upper layers sit on half-card offsets over the layer below), so cards overlap across layers but never within one.

**Card**:
A single playable tile on the board. Has a unique id, a type, a position, a layer, a state, and a source (board or support deck).

**Card Type**:
The identity that determines matching. Two cards match if and only if they share the same Card Type.
_Avoid_: typeId (that is a field, not the concept)

**Card State**:
The lifecycle of a card: `HIDDEN`, `AVAILABLE`, `SELECTED`, `MATCHED`, `REMOVED`.

**Blocked**:
A card that cannot be selected because at least one active higher-layer card covers 10% or more of its area.

**Clearing Zone**:
The limited temporary area that holds selected cards. Three cards of the same type are removed automatically.
_Avoid_: hand, tray

**Support Deck**:
An auxiliary finite pile of cards the player can draw from into the Clearing Zone. Each level has two.
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

**Action**:
A single player interaction: select a card, draw a deck card, or use a power.
