class_name ProgressManager
extends RefCounted

const DEFAULT_INVENTORY := {"hold": 3, "undo": 3, "refresh": 2}

var inventory: Dictionary = {}
var levels: Dictionary = {}
var unlocked_level: int = 1
var endless_best: int = 0
# Rounds cleared in the run that set endless_best.
var endless_best_rounds: int = 0

func _init() -> void:
	inventory = DEFAULT_INVENTORY.duplicate()
	levels = {}
	unlocked_level = 1
	endless_best = 0
	endless_best_rounds = 0

func get_inventory() -> Dictionary:
	return inventory.duplicate()

func is_level_completed(level_id) -> bool:
	return bool(levels.get(str(level_id), {}).get("completed", false))

func get_stars(level_id) -> int:
	return int(levels.get(str(level_id), {}).get("stars", 0))

func get_unlocked_level() -> int:
	return unlocked_level

func total_stars() -> int:
	var total := 0
	for key in levels:
		total += int(levels[key].get("stars", 0))
	return total

func is_level_unlocked(level_id) -> bool:
	return int(level_id) <= unlocked_level

# Rewards are granted on the first victory only, so replays improve stars but
# cannot farm powers. Returns the rewards actually granted.
func record_victory(level_id, stars: int, rewards: Array) -> Array:
	var key := str(level_id)
	var entry: Dictionary = levels.get(key, {})
	var first_win := not bool(entry.get("completed", false))
	entry["completed"] = true
	entry["stars"] = maxi(int(entry.get("stars", 0)), stars)
	levels[key] = entry
	var granted: Array = []
	if first_win:
		for r in rewards:
			var rtype := str(r.get("type", ""))
			var qty := int(r.get("quantity", 0))
			inventory[rtype] = int(inventory.get(rtype, 0)) + qty
			granted.append(r)
	var next := int(level_id) + 1
	if next > unlocked_level:
		unlocked_level = next
	return granted

# Endless Mode opens once the last campaign Level is beaten. Derived from the
# shipped level files, so adding a Level moves the requirement with it.
static func endless_unlock_level() -> int:
	var ids := LevelLoader.load_all_level_ids()
	return int(ids.back()) if not ids.is_empty() else 1

func is_endless_unlocked() -> bool:
	return is_level_completed(endless_unlock_level())

# Keeps the best score (and the rounds of that run). Returns true on a new best.
func record_endless_result(score: int, rounds: int) -> bool:
	if score <= endless_best:
		return false
	endless_best = score
	endless_best_rounds = rounds
	return true

func to_dict() -> Dictionary:
	return {
		"inventory": inventory.duplicate(),
		"levels": levels.duplicate(true),
		"unlocked_level": unlocked_level,
		"endless_best": endless_best,
		"endless_best_rounds": endless_best_rounds,
	}

func from_dict(data: Dictionary) -> void:
	inventory = (data.get("inventory", DEFAULT_INVENTORY)).duplicate()
	levels = (data.get("levels", {})).duplicate(true)
	unlocked_level = int(data.get("unlocked_level", 1))
	endless_best = int(data.get("endless_best", 0))
	endless_best_rounds = int(data.get("endless_best_rounds", 0))
