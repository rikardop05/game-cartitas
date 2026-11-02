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
