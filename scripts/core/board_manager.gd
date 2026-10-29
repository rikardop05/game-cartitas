class_name BoardManager
extends RefCounted

# The spatial blocking rule lives entirely in BoardSpatialRules, shared with
# BoardPipeline so generated boards and runtime availability always agree. This
# class only applies the state/location/layer guards and delegates the geometric
# decision (AABB, threshold, quantization) to BoardSpatialRules — zero spatial
# logic is duplicated here.

var cards: Array[Card] = []

func _init(p_cards: Array[Card] = []) -> void:
	cards = p_cards.duplicate()

func get_card(card_id: String) -> Card:
	for c in cards:
		if c.id == card_id:
			return c
	return null

func active_cards() -> Array[Card]:
	var out: Array[Card] = []
	for c in cards:
		if c.location == Card.Location.BOARD and not c.is_removed():
			out.append(c)
	return out

func remaining_count() -> int:
	return active_cards().size()

func is_blocked(card: Card) -> bool:
	if card.is_removed() or card.location != Card.Location.BOARD:
		return false
	for other in cards:
		if other == card:
			continue
		if other.location != Card.Location.BOARD or other.is_removed():
			continue
		if BoardSpatialRules.blocks_with_layers(card.get_display_rect(), other.get_display_rect(), card.layer, other.layer):
			return true
	return false

func recalculate_availability() -> void:
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
