class_name BoardManager
extends RefCounted

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
	for other in cards:
		if other == card:
			continue
		if other.location != Card.Location.BOARD or other.is_removed():
			continue
		if other.layer <= card.layer:
			continue
		if card.get_rect().intersects(other.get_rect()):
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
