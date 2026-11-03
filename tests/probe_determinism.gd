extends SceneTree

# Determinism probe for board generation (Phase E safety net).
#
# It runs the SAME entry points the game uses:
#   - campaign: LevelLoader.load_level(id) with LevelLoader.deterministic = true
#   - endless:  EndlessRun.build_round_level()
#   - per-seed: DifficultyProfile -> with_deck -> seed -> config.generate(), which is the
#     exact sequence LevelLoader._resolve_from_difficulty uses internally (including the
#     4 retry rounds and the deterministic deck split), but with the seed overridden.
#
# For every case it hashes the generated board (card ids, types, positions, layers) plus
# the support deck contents and saves it to user://determinism_baseline.json.
#
# Usage:
#   godot --headless --path . -s res://tests/probe_determinism.gd            # write baseline
#   godot --headless --path . -s res://tests/probe_determinism.gd -- --compare  # compare
#
# Compare mode never overwrites the baseline; it writes user://determinism_after.json
# with the new hashes and fails (quit 1) on the first mismatched/missing/extra case.

const BASELINE_PATH := "user://determinism_baseline.json"
const AFTER_PATH := "user://determinism_after.json"
const LEVELS := 15
const SEED_MIN := 1
const SEED_MAX := 20
const ENDLESS_ROUNDS := 5
const BOARD_SIZE := Vector2.ZERO

func _init() -> void:
	var compare := OS.get_cmdline_user_args().has("--compare")
	LevelLoader.deterministic = true
	var cases := _collect_cases()
	var file_path := AFTER_PATH if compare else BASELINE_PATH
	_write_json(file_path, cases)
	print("PROBE DETERMINISM: %d cases -> %s" % [cases.size(), ProjectSettings.globalize_path(file_path)])

	if not compare:
		print("BASELINE WRITTEN: %s" % ProjectSettings.globalize_path(BASELINE_PATH))
		quit(0)
		return

	var baseline := _read_json(BASELINE_PATH)
	var total := maxi(baseline.size(), cases.size())
	var equal := 0
	var mismatches: Array[String] = []
	for key in baseline:
		if not cases.has(key):
			mismatches.append("%s MISSING in after" % key)
			continue
		if str(baseline[key].get("hash", "")) == str(cases[key].get("hash", "")):
			equal += 1
		else:
			mismatches.append("%s DIFF baseline=%s after=%s" % [
				key, str(baseline[key].get("hash", "")).substr(0, 12),
				str(cases[key].get("hash", "")).substr(0, 12)])
	for key in cases:
		if not baseline.has(key):
			mismatches.append("%s EXTRA in after" % key)

	print("COMPARE: %d/%d hashes equal, %d mismatches (baseline cases %d, after cases %d)" % [
		equal, total, mismatches.size(), baseline.size(), cases.size()])
	for line in mismatches:
		print("MISMATCH: " + line)
	if mismatches.is_empty() and equal == total:
		print("PROBE DETERMINISM OK")
		quit(0)
		return
	printerr("PROBE DETERMINISM FAILED")
	quit(1)

func _collect_cases() -> Dictionary:
	var out := {}

	# 1) The exact campaign entry point the game calls (profile seed).
	for n in range(1, LEVELS + 1):
		var level: Dictionary = LevelLoader.load_level(str(n), BOARD_SIZE)
		out["level:%d:loader" % n] = _hash_level(level)

	# 2) Every level with seeds 1..20, mirroring LevelLoader._resolve_from_difficulty.
	for n in range(1, LEVELS + 1):
		var pool := _deck_pool_for_level(n)
		for s in range(SEED_MIN, SEED_MAX + 1):
			out["level:%d:seed:%d" % [n, s]] = _hash_generated(n, pool, s)

	# 3) The exact Endless entry point the game calls, rounds 1..5.
	for round_number in range(1, ENDLESS_ROUNDS + 1):
		var run := EndlessRun.new()
		run.current_round = round_number
		var level := run.build_round_level(BOARD_SIZE)
		out["endless:%d" % round_number] = _hash_level(level)
	return out

func _hash_generated(difficulty: int, pool: Array, seed_value: int) -> Dictionary:
	var config := DifficultyProfile.for_level(difficulty)
	if config == null:
		return {"hash": "no-profile-%d" % difficulty, "seed_used": seed_value}
	config.with_deck(pool)
	config.seed = seed_value
	var result: Dictionary = {}
	for retry_round in 4:
		config.max_attempts = 60 * (retry_round + 1)
		result = config.generate(BOARD_SIZE)
		if result["ok"]:
			break
	if not bool(result.get("ok", false)):
		return {"hash": "generation-failed-%d-%d" % [difficulty, seed_value], "seed_used": seed_value}
	var seed_used := int(result["metrics"].get("seed_used", seed_value))
	var decks := LevelBoardGenerator.split_decks(pool, seed_used)
	return _hash_parts(
		result["cards"], decks["deck_a"], decks["deck_b"],
		float(result["board_width"]), float(result["board_height"]),
		float(config.card_size), seed_used)

func _hash_level(level: Dictionary) -> Dictionary:
	if level.has("error"):
		return {"hash": "error:%s" % str(level["error"]), "seed_used": -1}
	var seed_used := int(level.get("generation_metrics", {}).get("seed_used", -1))
	return _hash_parts(
		level.get("cards", []), level.get("deck_a", []), level.get("deck_b", []),
		float(level.get("board_width", 0.0)), float(level.get("board_height", 0.0)),
		float(level.get("card_size", 0.0)), seed_used)

func _hash_parts(cards: Array, deck_a: Array, deck_b: Array, width: float, height: float, card_size: float, seed_used: int) -> Dictionary:
	var canonical := PackedStringArray()
	canonical.append("seed=%d" % seed_used)
	canonical.append("width=%.6f" % width)
	canonical.append("height=%.6f" % height)
	canonical.append("card_size=%.6f" % card_size)
	for card in cards:
		var c: Dictionary = card
		canonical.append("%s|%s|%.6f|%.6f|%d" % [
			str(c.get("id", "")), str(c.get("type", "")),
			float(c.get("x", 0.0)), float(c.get("y", 0.0)), int(c.get("layer", 0))])
	canonical.append("deck_a=" + ",".join(deck_a.map(func(t): return str(t))))
	canonical.append("deck_b=" + ",".join(deck_b.map(func(t): return str(t))))
	var text := "\n".join(canonical)
	return {
		"hash": text.sha256_text(),
		"seed_used": seed_used,
		"cards": cards.size(),
		"deck_a": deck_a.size(),
		"deck_b": deck_b.size(),
	}

func _deck_pool_for_level(level_id: int) -> Array:
	var path := LevelLoader.level_path(str(level_id))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		return []
	return LevelLoader._deck_pool(data)

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("PROBE: cannot write " + path)
		return
	file.store_string(JSON.stringify(data, "  ", true))
	file.close()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		printerr("PROBE: baseline not found: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}
