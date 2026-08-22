class_name LevelLoader
extends RefCounted

static func level_path(level_id) -> String:
	return "res://levels/level_%s.json" % str(level_id)

static func level_exists(level_id) -> bool:
	return FileAccess.file_exists(level_path(level_id))

static func load_level(level_id, board_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var path := level_path(level_id)
	if not FileAccess.file_exists(path):
		return {"error": "level not found: %s" % path}
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	var data = JSON.parse_string(text)
	if data == null:
		return {"error": "invalid JSON in %s" % path}
	return resolve(data, board_size)

static func resolve(level: Dictionary, board_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var deck_pool := _deck_pool(level)
	if level.has("difficulty"):
		return _resolve_from_difficulty(level, deck_pool, board_size)
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
	if board_size.x > 0.0 and board_size.y > 0.0:
		params["width"] = board_size.x
		params["height"] = board_size.y
	var base_seed := int(layout.get("seed", 1))
	if bool(layout.get("randomize_per_attempt", true)):
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		base_seed = seed_rng.randi()
	var max_attempts := maxi(1, int(layout.get("max_generation_attempts", 60)))
	for attempt in max_attempts:
		params["seed"] = base_seed + attempt
		var candidate := level.duplicate(true)
		candidate.erase("layout")
		candidate["cards"] = LayoutGenerator.generate(types, count, params)
		candidate["board_width"] = float(params.get("width", 240))
		candidate["board_height"] = float(params.get("height", 200))
		candidate["card_size"] = float(params.get("card_size", LayoutGenerator.CARD))
		_assign_shuffled_decks(candidate, deck_pool)
		if SolvabilityChecker.is_solvable(candidate):
			return candidate
	push_warning("level %s: no solvable layout after %d attempts" % [str(level.get("id", "")), max_attempts])
	return {"error": "no solvable layout for level %s after %d attempts" % [str(level.get("id", "")), max_attempts]}

static func _resolve_from_difficulty(level: Dictionary, deck_pool: Array, board_size: Vector2) -> Dictionary:
	var difficulty := int(level.get("difficulty", 0))
	var config := DifficultyProfile.for_level(difficulty)
	if config == null:
		return {"error": "no difficulty profile for level %d" % difficulty}
	config.with_deck(deck_pool)
	var validation := config.validate()
	if not validation["valid"]:
		return {"error": "difficulty config invalid: %s" % "; ".join(validation["errors"])}
	var base_attempts := maxi(1, int(level.get("max_generation_attempts", config.max_attempts)))
	var started := Time.get_ticks_msec()
	var result: Dictionary = {}
	for round in 4:
		config.max_attempts = base_attempts * (round + 1)
		result = config.generate(board_size)
		if result["ok"]:
			break
		push_warning("difficulty %d: round %d failed (%d attempts)" % [difficulty, round + 1, config.max_attempts])
	if not result["ok"]:
		push_error("difficulty %d: could not generate a solvable board after %d attempts" % [difficulty, config.max_attempts])
		return {"error": "could not generate a solvable board for difficulty %d after %d attempts" % [difficulty, config.max_attempts]}
	var elapsed_ms := Time.get_ticks_msec() - started
	var out := level.duplicate(true)
	out.erase("difficulty")
	out.erase("layout")
	out["cards"] = result["cards"]
	out["board_width"] = config.board_width()
	out["board_height"] = config.board_height()
	out["card_size"] = config.card_size
	var metrics: Dictionary = result["metrics"]
	metrics["generation_time_ms"] = elapsed_ms
	metrics["clearing_capacity"] = int(level.get("clearing_capacity", 7))
	out["generation_metrics"] = metrics
	_assign_deterministic_decks(out, deck_pool, int(metrics.get("seed_used", config.seed)))
	return out

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
	var half := int(ceil(p.size() / 2.0))
	level["deck_a"] = p.slice(0, half)
	level["deck_b"] = p.slice(half)

static func _assign_deterministic_decks(level: Dictionary, pool: Array, seed: int) -> void:
	# Mirrors the deck split used by the generation pipeline (LayoutGenerator
	# _instantiate_level) so the returned level matches the solvability check.
	var p := pool.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_shuffle_seeded(p, rng)
	var half := int(ceil(p.size() / 2.0))
	level["deck_a"] = p.slice(0, half)
	level["deck_b"] = p.slice(half)

static func _shuffle_seeded(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

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
