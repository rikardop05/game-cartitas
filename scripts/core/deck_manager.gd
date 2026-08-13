class_name DeckManager
extends RefCounted

var card_types: Array = []
var current_index: int = 0

func _init(p_types: Array = []) -> void:
	card_types = []
	for t in p_types:
		card_types.append(str(t))

func remaining_count() -> int:
	return maxi(0, card_types.size() - current_index)

func is_empty() -> bool:
	return current_index >= card_types.size()

func current_type() -> String:
	if is_empty():
		return ""
	return str(card_types[current_index])

func draw_type() -> String:
	if is_empty():
		return ""
	var t: String = str(card_types[current_index])
	current_index += 1
	return t

func return_type() -> void:
	if current_index > 0:
		current_index -= 1

func shuffle_remaining(rng: RandomNumberGenerator) -> void:
	var n := card_types.size()
	for i in range(n - 1, current_index, -1):
		var j := rng.randi_range(current_index, i)
		var tmp = card_types[i]
		card_types[i] = card_types[j]
		card_types[j] = tmp
