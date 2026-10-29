extends RefCounted

const PORTRAIT_AVAIL := LevelConfig.PORTRAIT_BOARD_ENVELOPE
const LANDSCAPE_AVAIL := LevelConfig.LANDSCAPE_BOARD_ENVELOPE
# Smallest board card that is still a comfortable touch target.
const TOUCH_MIN_CARD_PX := 30.0

# Rendered card size (px) of a board of the given logical size in an envelope: fitted, never above the UI cap.
func _rendered_card(card_size: float, board: Vector2, avail: Vector2) -> float:
	return minf(card_size * clampf(minf(avail.x / board.x, avail.y / board.y), 0.01, 2.5), LevelConfig.MAX_BOARD_CARD_PX)

func test_envelope_metrics_per_orientation() -> void:
	LevelLoader.deterministic = true
	print("ENVELOPE REPORT (portrait avail %s, landscape avail %s, min card %.0fpx)" % [str(PORTRAIT_AVAIL), str(LANDSCAPE_AVAIL), LevelConfig.MIN_CARD_SIZE_PX])
	print("id | board (px)  | portrait card px | landscape card px")
	for id in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(id)
		var level := LevelLoader.load_level(str(id))
		Assert.is_false(level.has("error"), "level %d loads" % id)
		var board := Vector2(float(level["board_width"]), float(level["board_height"]))
		var p := _rendered_card(cfg.card_size, board, PORTRAIT_AVAIL)
		var l := _rendered_card(cfg.card_size, board, LANDSCAPE_AVAIL)
		print("%2d | %4.0fx%-4.0f   | %6.1f           | %6.1f" % [id, board.x, board.y, p, l])
		Assert.is_true(p >= TOUCH_MIN_CARD_PX and p <= LevelConfig.MAX_BOARD_CARD_PX + 0.01, "level %d portrait card %.1fpx within [%.0f, %.0f]" % [id, p, TOUCH_MIN_CARD_PX, LevelConfig.MAX_BOARD_CARD_PX])
		Assert.is_true(l >= TOUCH_MIN_CARD_PX and l <= LevelConfig.MAX_BOARD_CARD_PX + 0.01, "level %d landscape card %.1fpx within [%.0f, %.0f]" % [id, l, TOUCH_MIN_CARD_PX, LevelConfig.MAX_BOARD_CARD_PX])
		Assert.is_true(board.x <= cfg.board_width() and board.y <= cfg.board_height(), "level %d board stays inside its base grid" % id)
		var m: Dictionary = level["generation_metrics"]
		Assert.is_true(bool(m["fits_portrait"]), "level %d metrics: fits_portrait" % id)
		Assert.is_true(bool(m["fits_landscape"]), "level %d metrics: fits_landscape" % id)
		Assert.is_true(absf(float(m["min_card_px_portrait"]) - p) < 0.01, "level %d portrait metric matches the board actually delivered" % id)
	LevelLoader.deterministic = false

func test_envelope_rejects_out_of_envelope_with_diagnostics() -> void:
	var base := DifficultyProfile.for_level(1)
	Assert.is_true(base.validate()["valid"], "baseline L1 validates")
	# oversized base grid
	var big := LevelConfig.create({
		"difficulty": 11, "board_types": ["cat", "dog", "bird"], "count_per_type": 3,
		"columns": 10, "rows": 8, "layers": 2, "seed": 1,
	})
	Assert.is_true(_errors_mention(big.validate()["errors"], "base grid"), "diagnostic names the base grid")
	# too many layers
	var deep := LevelConfig.create({
		"difficulty": 11, "board_types": ["cat", "dog", "bird"], "count_per_type": 3,
		"columns": 5, "rows": 5, "layers": 6, "seed": 1,
	})
	Assert.is_true(_errors_mention(deep.validate()["errors"], "layers"), "diagnostic names layers")
	# too many board cards
	var tall := LevelConfig.create({
		"difficulty": 11, "board_types": ["cat", "dog", "bird", "fish", "flower", "moon", "star", "sun", "leaf", "heart", "gem", "crystal"], "board_cards": 75,
		"columns": 9, "rows": 5, "layers": 4, "seed": 1,
	})
	Assert.is_true(_errors_mention(tall.validate()["errors"], "board cards"), "diagnostic names board cards")
	# a base layer the grid cannot hold
	var cramped := LevelConfig.create({
		"difficulty": 11, "board_types": ["cat", "dog", "bird", "fish", "flower", "moon"], "count_per_type": 3,
		"columns": 3, "rows": 2, "layers": 2, "seed": 1,
	})
	Assert.is_true(_errors_mention(cramped.validate()["errors"], "lattice"), "diagnostic names the card lattice")

func _errors_mention(errors: Array, needle: String) -> bool:
	for r in errors:
		if str(r).contains(needle):
			return true
	return false

func _level_from_generate(cfg: LevelConfig, cards: Array, seed: int) -> Dictionary:
	return LevelBoardGenerator.instantiate_level(cfg, cards, seed)

func test_same_seed_reproduces_board_and_decks() -> void:
	LevelLoader.deterministic = true
	for id in LevelLoader.load_all_level_ids():
		var a := LevelLoader.load_level(id)
		var b := LevelLoader.load_level(id)
		Assert.is_false(a.has("error"), "level %s loads" % id)
		Assert.equals(_cards_sig(a), _cards_sig(b), "level %s same seed -> same board" % id)
		Assert.equals(str(a["deck_a"]), str(b["deck_a"]), "level %s same seed -> same deck_a" % id)
		Assert.equals(str(a["deck_b"]), str(b["deck_b"]), "level %s same seed -> same deck_b" % id)
	LevelLoader.deterministic = false

func test_each_attempt_gets_a_new_solvable_board() -> void:
	LevelLoader.deterministic = false
	for id in ["1", "6", "11"]:
		var a := LevelLoader.load_level(id)
		var b := LevelLoader.load_level(id)
		Assert.is_false(a.has("error") or b.has("error"), "level %s loads with a random seed" % id)
		Assert.not_equals(int(a["generation_metrics"]["seed_used"]), int(b["generation_metrics"]["seed_used"]), "level %s draws a new seed per attempt" % id)
		Assert.not_equals(_cards_sig(a), _cards_sig(b), "level %s retry shows a different board" % id)
		Assert.is_true(SolvabilityChecker.is_solvable(a) and SolvabilityChecker.is_solvable(b), "level %s random boards stay solvable" % id)

func _cards_sig(level: Dictionary) -> Array:
	var sig := []
	for c in level["cards"]:
		sig.append([str(c["type"]), int(c["x"]), int(c["y"]), int(c["layer"])])
	return sig

func test_no_level_returned_unsolvable() -> void:
	for id in LevelLoader.load_all_level_ids():
		var level := LevelLoader.load_level(id)
		Assert.is_false(level.has("error"), "level %s loads" % id)
		var m: Dictionary = level["generation_metrics"]
		Assert.is_true(bool(m["solvable"]), "level %s generation marked solvable" % id)
		Assert.is_true(SolvabilityChecker.is_solvable(level), "level %s actually solvable" % id)

func test_no_silent_fallback_as_success() -> void:
	for id in range(1, 11):
		var cfg := DifficultyProfile.for_level(id)
		var res := cfg.generate()
		Assert.is_true(res["ok"], "level %d generates" % id)
		var status := str(res["metrics"]["status"])
		Assert.is_false(status == "fallback", "level %d must not use flat fallback as success (got '%s')" % [id, status])
		Assert.is_true(status == "ok", "level %d generation status 'ok' (got '%s')" % [id, status])

func test_safe_config_50_loads_no_fallback_all_solvable() -> void:
	var cfg := LevelConfig.create({
		"difficulty": 11, "board_types": ["cat", "dog", "bird", "fish", "flower", "moon", "star", "sun", "leaf", "heart", "gem", "crystal"],
		"count_per_type": 3, "columns": 7, "rows": 5, "layers": 4,
		"free_ratio": 0.35, "free_ratio_min": 0.20, "free_ratio_max": 0.50, "seed": 11001, "max_attempts": 80,
	})
	Assert.is_true(cfg.validate()["valid"], "safe config validates")
	cfg.with_deck(["cat", "cat", "cat", "dog", "dog", "dog", "bird", "bird", "bird"])
	Assert.is_true(cfg.validate()["valid"], "safe config with deck validates")
	Assert.is_true(cfg.fits_portrait(), "safe config fits portrait envelope")
	var solved := 0
	for i in 50:
		cfg.seed = 11001 + i
		var res := cfg.generate()
		Assert.is_true(res["ok"], "safe config load %d generated" % i)
		var status := str(res["metrics"]["status"])
		Assert.is_true(status == "ok", "safe config load %d without fallback (got '%s')" % [i, status])
		var level := _level_from_generate(cfg, res["cards"], int(res["metrics"]["seed_used"]))
		if SolvabilityChecker.is_solvable(level):
			solved += 1
	Assert.equals(solved, 50, "all 50 safe-config loads solvable (got %d)" % solved)

func test_clearing_capacity_and_solver() -> void:
	for id in LevelLoader.load_all_level_ids():
		var level := LevelLoader.load_level(id)
		Assert.is_false(level.has("error"), "level %s loads" % id)
		Assert.equals(int(level.get("clearing_capacity", 0)), 7, "level %s clearing capacity 7" % id)
		Assert.equals(int(level["generation_metrics"]["clearing_capacity"]), 7, "level %s metrics clearing capacity 7" % id)

func test_level_validator_rejects_bad_layouts() -> void:
	var good := LevelLoader.load_level("1")
	Assert.is_true(LevelValidator.validate(good)["valid"], "generated level 1 is valid")
	# out of bounds
	var oob := _base_bad()
	oob["cards"][0]["x"] = -10
	var v1 := LevelValidator.validate(oob)
	Assert.is_false(v1["valid"], "out-of-bounds card rejected")
	Assert.is_true(_errors_mention(v1["errors"], "out of bounds"), "bounds diagnostic")
	# layer-0 stacked
	var stacked := _base_bad()
	stacked["cards"][0]["layer"] = 0
	stacked["cards"][1]["x"] = stacked["cards"][0]["x"]
	stacked["cards"][1]["y"] = stacked["cards"][0]["y"]
	stacked["cards"][1]["layer"] = 0
	var v2 := LevelValidator.validate(stacked)
	Assert.is_false(v2["valid"], "stacked layer-0 rejected")
	Assert.is_true(_errors_mention(v2["errors"], "layer-0"), "layer-0 diagnostic")
	# overlap > 75%
	var overlap := _base_bad()
	overlap["cards"][1]["x"] = overlap["cards"][0]["x"]
	overlap["cards"][1]["y"] = overlap["cards"][0]["y"]
	overlap["cards"][1]["layer"] = 1
	var v3 := LevelValidator.validate(overlap)
	Assert.is_false(v3["valid"], "overlap > 75%% rejected")
	Assert.is_true(_errors_mention(v3["errors"], "overlaps"), "overlap diagnostic")
	# zero free cards: empty board (every card covered is impossible by
	# construction, so the validator's free-card check rejects empty boards)
	var covered := _base_bad()
	covered["cards"] = []
	var v4 := LevelValidator.validate(covered)
	Assert.is_false(v4["valid"], "zero free cards rejected")
	Assert.is_true(_errors_mention(v4["errors"], "no available"), "free-cards diagnostic")

func _base_bad() -> Dictionary:
	return {
		"id": "bad",
		"clearing_capacity": 7,
		"card_size": 48.0,
		"board_width": 200.0,
		"board_height": 200.0,
		"cards": [
			{"id": "a", "type": "cat", "x": 0, "y": 0, "layer": 0},
			{"id": "b", "type": "cat", "x": 60, "y": 0, "layer": 0},
			{"id": "c", "type": "cat", "x": 0, "y": 60, "layer": 0},
		],
		"deck_a": ["dog", "dog", "dog"],
		"deck_b": ["dog", "dog", "dog"],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
	}

func test_load_time_report_per_level() -> void:
	print("LOAD-TIME REPORT (avg ms over 5 loads per level)")
	print("id | generation_time_ms (pipeline) | wall-clock avg ms")
	for id in LevelLoader.load_all_level_ids():
		var times: Array[float] = []
		var gen_ms := -1.0
		for i in 5:
			var t0 := Time.get_ticks_msec()
			var level := LevelLoader.load_level(id)
			var dt := Time.get_ticks_msec() - t0
			Assert.is_false(level.has("error"), "level %s loads (load %d)" % [id, i])
			times.append(float(dt))
			if level.has("generation_metrics"):
				gen_ms = float(level["generation_metrics"].get("generation_time_ms", -1.0))
		var avg := 0.0
		for t in times:
			avg += t
		avg /= float(times.size())
		print("%2s | %.1f                          | %.1f" % [id, gen_ms, avg])