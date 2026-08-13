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
	return process_layout(data)

static func process_layout(level: Dictionary) -> Dictionary:
	if not level.has("layout"):
		return level
	var layout: Dictionary = level["layout"]
	var types: Array = []
	for t in layout.get("types", []):
		types.append(str(t))
	var count := int(layout.get("count", 3))
	var params := layout.duplicate()
	var base_seed := int(layout.get("seed", 1))
	for attempt in 60:
		params["seed"] = base_seed + attempt
		var candidate := _with_cards(level, LayoutGenerator.generate(types, count, params))
		if SolvabilityChecker.is_solvable(candidate):
			return candidate
	params["seed"] = base_seed
	params["layers"] = 1
	return _with_cards(level, LayoutGenerator.generate(types, count, params))

static func _with_cards(level: Dictionary, cards: Array) -> Dictionary:
	var out := level.duplicate(true)
	out.erase("layout")
	out["cards"] = cards
	return out

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
