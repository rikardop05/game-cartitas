class_name LevelLoader
extends RefCounted

static func level_path(level_id) -> String:
	return "res://levels/level_%s.json" % str(level_id)

static func level_exists(level_id) -> bool:
	return FileAccess.file_exists(level_path(level_id))

static func load_level(level_id) -> Dictionary:
	var path := level_path(level_id)
	if not FileAccess.file_exists(path):
		return {"error": "level not found: %s" % path}
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	var data = JSON.parse_string(text)
	if data == null:
		return {"error": "invalid JSON in %s" % path}
	return resolve(data)

static func resolve(level: Dictionary) -> Dictionary:
	var deck_pool := _deck_pool(level)
	if not level.has("layout"):
		var out := level.duplicate(true)
		_assign_shuffled_decks(out, deck_pool)
		return out
	var layout: Dictionary = level["layout"]
	var types: Array = []
	for t in layout.get("types", []):
		types.append(str(t))
	var count := int(layout.get("count", 3))
	var params := layout.duplicate()
	var base_seed := int(layout.get("seed", 1))
	for attempt in 60:
		params["seed"] = base_seed + attempt
		var candidate := level.duplicate(true)
		candidate.erase("layout")
		candidate["cards"] = LayoutGenerator.generate(types, count, params)
		_assign_shuffled_decks(candidate, deck_pool)
		if SolvabilityChecker.is_solvable(candidate):
			return candidate
	params["seed"] = base_seed
	params["layers"] = 1
	var candidate := level.duplicate(true)
	candidate.erase("layout")
	candidate["cards"] = LayoutGenerator.generate(types, count, params)
	_assign_shuffled_decks(candidate, deck_pool)
	return candidate

static func _deck_pool(level: Dictionary) -> Array:
	var pool: Array = []
	if level.has("deck"):
		for t in level["deck"]:
			pool.append(str(t))
	else:
		for t in level.get("deck_a", []):
			pool.append(str(t))
		for t in level.get("deck_b", []):
			pool.append(str(t))
	return pool

static func _assign_shuffled_decks(level: Dictionary, pool: Array) -> void:
	var p := pool.duplicate()
	_shuffle(p)
	var half := (p.size() + 1) / 2
	level["deck_a"] = p.slice(0, half)
	level["deck_b"] = p.slice(half)

static func _shuffle(arr: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func load_all_level_ids() -> Array:
	var dir := DirAccess.open("res://levels")
	var ids: Array = []
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.begins_with("level_") and fname.ends_with(".json"):
				ids.append(fname.trim_prefix("level_").trim_suffix(".json"))
			fname = dir.get_next()
		dir.list_dir_end()
	ids.sort_custom(func(a, b): return int(a) < int(b))
	return ids
