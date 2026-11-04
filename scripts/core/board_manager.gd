class_name BoardManager
extends RefCounted

# The spatial blocking rule lives entirely in BoardSpatialRules, shared with
# BoardPipeline so generated boards and runtime availability always agree. This
# class only applies the state/location/layer guards and delegates the geometric
# decision (AABB, threshold, quantization) to BoardSpatialRules — zero spatial
# logic is duplicated here.

var cards: Array[Card] = []

# O(1) id lookup and a cached per-card blocker list. A card can only be blocked by a
# card of a higher layer that overlaps its rect, so the list is the AABB-intersecting
# superset of BoardSpatialRules.blocks(); is_blocked() still applies the shared rule.
var _by_id: Dictionary = {}
var _blocking_candidates: Dictionary = {}
var _duplicate_ids := false

func _init(p_cards: Array[Card] = []) -> void:
	cards = p_cards.duplicate()
	_rebuild_index()

func _rebuild_index() -> void:
	_by_id.clear()
	_blocking_candidates.clear()
	_duplicate_ids = false
	for i in cards.size():
		var card: Card = cards[i]
		if _by_id.has(card.id):
			_duplicate_ids = true
		_by_id[card.id] = card
		_blocking_candidates[card.id] = []
	for i in cards.size():
		var covered: Card = cards[i]
		var covered_rect := covered.get_display_rect()
		var candidates: Array = _blocking_candidates[covered.id]
		for j in cards.size():
			if i == j:
				continue
			var covering: Card = cards[j]
			if covering.layer <= covered.layer:
				continue
			if covered_rect.intersects(covering.get_display_rect()):
				candidates.append(covering)

func get_card(card_id: String) -> Card:
	if _duplicate_ids:
		for c in cards:
			if c.id == card_id:
				return c
		return null
	return _by_id.get(card_id, null)

func active_cards() -> Array[Card]:
	var out: Array[Card] = []
	for c in cards:
		if c.location == Card.Location.BOARD and not c.is_removed():
			out.append(c)
	return out

func remaining_count() -> int:
	var n := 0
	for c in cards:
		if c.location == Card.Location.BOARD and not c.is_removed():
			n += 1
	return n

func is_blocked(card: Card) -> bool:
	if card.is_removed() or card.location != Card.Location.BOARD:
		return false
	if _duplicate_ids:
		return _is_blocked_full_scan(card)
	var candidates = _blocking_candidates.get(card.id, null)
	if candidates == null:
		return _is_blocked_full_scan(card)
	var card_rect := card.get_display_rect()
	for other in candidates:
		var covering: Card = other
		if covering.location != Card.Location.BOARD or covering.is_removed():
			continue
		if BoardSpatialRules.blocks_with_layers(card_rect, covering.get_display_rect(), card.layer, covering.layer):
			return true
	return false

# Defensive fallback for a card that is not in the cached index (never happens with the
# board the game builds, but keeps the old exact behaviour if an index is stale).
func _is_blocked_full_scan(card: Card) -> bool:
	for other in cards:
		if other == card:
			continue
		if other.location != Card.Location.BOARD or other.is_removed():
			continue
		if other.layer <= card.layer:
			continue
		if BoardSpatialRules.blocks_with_layers(card.get_display_rect(), other.get_display_rect(), card.layer, other.layer):
			return true
	return false

# Full pass by default. When a board card has just left (selected into the zone)
# only the hidden cards it covered can turn available, so the pass is limited to
# those candidates - the solver makes thousands of these calls on the big boards.
func recalculate_availability(removed: Card = null) -> void:
	if removed != null:
		var removed_rect := removed.get_display_rect()
		for c in cards:
			if c.location != Card.Location.BOARD or c.is_removed() or c.state != Card.State.HIDDEN:
				continue
			if c.layer >= removed.layer:
				continue
			if not removed_rect.intersects(c.get_display_rect()):
				continue
			c.state = Card.State.HIDDEN if is_blocked(c) else Card.State.AVAILABLE
		return
	for c in cards:
		if c.location != Card.Location.BOARD or c.is_removed():
			continue
		c.state = Card.State.HIDDEN if is_blocked(c) else Card.State.AVAILABLE

func shuffle_positions(rng: RandomNumberGenerator) -> void:
	var by_layer := {}
	for c in active_cards():
		if not by_layer.has(c.layer):
			by_layer[c.layer] = []
		by_layer[c.layer].append(c)
	for layer in by_layer:
		var group: Array = by_layer[layer]
		var positions: Array = []
		for c in group:
			positions.append(c.position)
		for i in range(positions.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = positions[i]
			positions[i] = positions[j]
			positions[j] = tmp
		for k in group.size():
			group[k].position = positions[k]
	# Positions changed: the cached blocker lists are no longer valid.
	_rebuild_index()

# --- Phase S1: Refresh redistributes the board and both Support Decks ----------------------
#
# The board keeps its shape (the same set of position+layer slots) but not who sits where: the
# active cards keep their ids and get another slot - so a card can change LAYER - and another
# type drawn from the pool of every card still in play (the board plus the remaining cards of
# deck_a and deck_b). The decks are refilled with exactly their previous counts, the zone and the
# Reserve are never touched, so the counts and the overall type multiset are invariant.
#
# Everything is driven by the controller's rng, so the same state + seed redistributes the same
# way. Up to REDISTRIBUTE_ATTEMPTS candidates are tried: one that actually changes the
# arrangement and that `accept` (the controller: at least one available card and a reachable
# triple) likes. When none is accepted the first changed candidate is used, so the refresh never
# silently does nothing.
const REDISTRIBUTE_ATTEMPTS := 16

func redistribute(rng: RandomNumberGenerator, deck_a: DeckManager, deck_b: DeckManager, accept: Callable = Callable()) -> void:
	var active := active_cards()
	var slots: Array = []
	for c in active:
		slots.append({"position": c.position, "layer": c.layer})
	var pool: Array = []
	for c in active:
		pool.append(c.type)
	for t in deck_a.card_types.slice(deck_a.current_index):
		pool.append(str(t))
	for t in deck_b.card_types.slice(deck_b.current_index):
		pool.append(str(t))
	var deck_a_count := deck_a.remaining_count()
	var deck_b_count := deck_b.remaining_count()
	var signature := _arrangement_signature(active, deck_a, deck_b)
	var have_fallback := false
	var fallback_pool: Array = []
	var fallback_slots: Array = []
	for attempt in REDISTRIBUTE_ATTEMPTS:
		_shuffle_in_place(pool, rng)
		_shuffle_in_place(slots, rng)
		_apply_arrangement(active, slots, pool, deck_a, deck_b, deck_a_count, deck_b_count)
		_rebuild_index()
		recalculate_availability()
		if _arrangement_signature(active, deck_a, deck_b) == signature:
			continue   # an identical layout is not a refresh: try again
		if not have_fallback:
			have_fallback = true
			fallback_pool = pool.duplicate()
			fallback_slots = slots.duplicate(true)
		if not accept.is_valid() or bool(accept.call()):
			return
	if have_fallback:
		# Nobody satisfied the playability preference: keep the first arrangement that at least
		# changed something (deterministic, because the rng draws above are deterministic too).
		_apply_arrangement(active, fallback_slots, fallback_pool, deck_a, deck_b, deck_a_count, deck_b_count)
		_rebuild_index()
		recalculate_availability()

func _apply_arrangement(active: Array, slots: Array, pool: Array, deck_a: DeckManager, deck_b: DeckManager, deck_a_count: int, deck_b_count: int) -> void:
	for i in active.size():
		var card: Card = active[i]
		card.position = slots[i]["position"]
		card.layer = int(slots[i]["layer"])
		card.type = str(pool[i])
	var cursor := active.size()
	_fill_remaining(deck_a, pool, cursor, deck_a_count)
	cursor += deck_a_count
	_fill_remaining(deck_b, pool, cursor, deck_b_count)

# Overwrites only the cards still to be drawn, so the drawn history (needed by return_type) and
# the deck length stay exactly as they were.
func _fill_remaining(deck: DeckManager, pool: Array, start: int, count: int) -> void:
	for i in count:
		deck.card_types[deck.current_index + i] = str(pool[start + i])

# Identifies who sits where: any candidate that reproduces it did not move anything.
func _arrangement_signature(active: Array, deck_a: DeckManager, deck_b: DeckManager) -> String:
	var parts := PackedStringArray()
	for c in active:
		parts.append("%s|%.3f|%.3f|%d|%s" % [c.id, c.position.x, c.position.y, c.layer, c.type])
	parts.append(",".join(deck_a.card_types.slice(deck_a.current_index)))
	parts.append(",".join(deck_b.card_types.slice(deck_b.current_index)))
	return "\n".join(parts)

func _shuffle_in_place(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
