class_name ClearingZoneManager
extends RefCounted

var cards: Array[Card] = []
var capacity: int = 7

var _add_seq: Dictionary = {}
var _next_add_seq: int = 0

func _init(p_capacity: int = 7) -> void:
	capacity = p_capacity

func size() -> int:
	return cards.size()

func is_full() -> bool:
	return cards.size() >= capacity

func insertion_index_for(card_type: String) -> int:
	var index := cards.size()
	for i in cards.size():
		if cards[i].type == card_type:
			index = i + 1
	return index

func add(card: Card) -> int:
	var index := insertion_index_for(card.type)
	cards.insert(index, card)
	card.location = Card.Location.CLEARING_ZONE
	card.state = Card.State.SELECTED
	_next_add_seq += 1
	_add_seq[card.id] = _next_add_seq
	return index

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

func remove_most_recent() -> Card:
	if cards.is_empty():
		return null
	var newest: Card = cards[0]
	var best := int(_add_seq.get(newest.id, -1))
	for i in range(1, cards.size()):
		var seq := int(_add_seq.get(cards[i].id, -1))
		if seq > best:
			best = seq
			newest = cards[i]
	cards.erase(newest)
	_add_seq.erase(newest.id)
	return newest
