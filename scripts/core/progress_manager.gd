class_name ProgressManager
extends RefCounted

const DEFAULT_INVENTORY := {"hold": 3, "undo": 3, "refresh": 2}

var inventory: Dictionary = {}
var levels: Dictionary = {}
var unlocked_level: int = 1

func _init() -> void:
	inventory = DEFAULT_INVENTORY.duplicate()
	levels = {}
	unlocked_level = 1

func get_inventory() -> Dictionary:
	return inventory.duplicate()

func is_level_completed(level_id) -> bool:
	return bool(levels.get(str(level_id), {}).get("completed", false))

func get_stars(level_id) -> int:
	return int(levels.get(str(level_id), {}).get("stars", 0))

func get_unlocked_level() -> int:
	return unlocked_level

func is_level_unlocked(level_id) -> bool:
	return int(level_id) <= unlocked_level

func record_victory(level_id, stars: int, rewards: Array) -> void:
	var key := str(level_id)
	var entry: Dictionary = levels.get(key, {})
	entry["completed"] = true
	entry["stars"] = maxi(int(entry.get("stars", 0)), stars)
	levels[key] = entry
	for r in rewards:
		var rtype := str(r.get("type", ""))
		var qty := int(r.get("quantity", 0))
		inventory[rtype] = int(inventory.get(rtype, 0)) + qty
	var next := int(level_id) + 1
	if next > unlocked_level:
		unlocked_level = next

func to_dict() -> Dictionary:
	return {
		"inventory": inventory.duplicate(),
		"levels": levels.duplicate(true),
		"unlocked_level": unlocked_level,
	}

func from_dict(data: Dictionary) -> void:
	inventory = (data.get("inventory", DEFAULT_INVENTORY)).duplicate()
	levels = (data.get("levels", {})).duplicate(true)
	unlocked_level = int(data.get("unlocked_level", 1))
