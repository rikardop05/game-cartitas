class_name ClearingZoneManager
extends RefCounted

var cards: Array[Card] = []
var capacity: int = 7

func _init(p_capacity: int = 7) -> void:
	capacity = p_capacity

func size() -> int:
	return cards.size()

func is_full() -> bool:
	return cards.size() >= capacity

func add(card: Card) -> void:
	cards.append(card)
	card.location = Card.Location.CLEARING_ZONE
	card.state = Card.State.SELECTED

func count_of_type(card_type: String) -> int:
	var n := 0
	for c in cards:
		if c.type == card_type:
			n += 1
	return n

func resolve_matches(card_type: String) -> Array[Card]:
	var matched: Array[Card] = []
	var kept: Array[Card] = []
	for c in cards:
		if c.type == card_type and matched.size() < 3:
			matched.append(c)
		else:
			kept.append(c)
	if matched.size() < 3:
		return []
	cards = kept
	for c in matched:
		c.state = Card.State.REMOVED
	return matched

func take_last(count: int) -> Array[Card]:
	count = mini(count, cards.size())
	if count <= 0:
		return []
	var start: int = cards.size() - count
	var taken: Array[Card] = cards.slice(start)
	cards = cards.slice(0, start)
	return taken

func take_first(count: int) -> Array[Card]:
	count = mini(count, cards.size())
	if count <= 0:
		return []
	var taken: Array[Card] = cards.slice(0, count)
	cards = cards.slice(count)
	return taken

func remove_last() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_back()
