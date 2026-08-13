class_name PowerManager
extends RefCounted

const POWERS := ["hold", "undo", "refresh"]

var counts: Dictionary = {}

func _init(p_counts: Dictionary = {}) -> void:
	counts = p_counts
	for p in POWERS:
		if not counts.has(p):
			counts[p] = 0

func get_count(power: String) -> int:
	return int(counts.get(power, 0))

func has(power: String) -> bool:
	return get_count(power) > 0

func consume(power: String) -> void:
	if has(power):
		counts[power] = get_count(power) - 1

func add(power: String, amount: int) -> void:
	counts[power] = get_count(power) + amount
