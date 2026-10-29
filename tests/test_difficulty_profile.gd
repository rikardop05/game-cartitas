extends RefCounted

const Checks = preload("res://tests/board_checks.gd")

func test_profile_supports_levels_1_to_max_and_beyond() -> void:
	for n in range(1, DifficultyProfile.max_level() + 3):
		var cfg := DifficultyProfile.for_level(n)
		if n <= DifficultyProfile.max_level():
			Assert.is_true(cfg != null, "level %d has a profile row" % n)
			var v := cfg.validate()
			Assert.is_true(v["valid"], "level %d config valid: %s" % [n, str(v["errors"])])
		else:
			Assert.is_true(cfg == null, "level %d has no profile row yet" % n)

func test_board_cards_and_type_counts_are_multiple_of_three() -> void:
	for n in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(n)
		Assert.equals(cfg.board_cards() % 3, 0, "level %d board cards multiple of 3" % n)
		Assert.equals(cfg.total_cards() % 3, 0, "level %d total cards multiple of 3" % n)
		var counts := {}
		for t in cfg.types_used_in_level:
			counts[t] = cfg.board_count(t) + cfg.deck_count(t)
		for t in counts:
			Assert.equals(counts[t] % 3, 0, "level %d type '%s' multiple of 3 (got %d)" % [n, t, counts[t]])

func test_available_types_separated_from_used_types() -> void:
	var cfg := DifficultyProfile.for_level(10)
	Assert.equals(cfg.available_card_types.size(), 12, "all 12 registry types available")
	Assert.is_true(cfg.available_card_types.size() >= cfg.types_used_in_level.size(), "used is a subset of available")
	for t in cfg.types_used_in_level:
		Assert.is_true(cfg.available_card_types.has(t), "'%s' is an available card type" % t)

func test_profile_levels_load_valid_and_solvable() -> void:
	for id in LevelLoader.load_all_level_ids():
		var level: Dictionary = LevelLoader.load_level(id)
		Assert.is_false(level.has("error"), "level %s loads" % id)
		Assert.is_false(level.has("layout"), "level %s resolved from difficulty profile" % id)
		var v := LevelValidator.validate(level)
		Assert.is_true(v["valid"], "level %s valid: %s" % [id, str(v["errors"])])
		Assert.is_true(level.has("generation_metrics"), "level %s has generation metrics" % id)
		Assert.is_true(SolvabilityChecker.is_solvable(level), "level %s solvable" % id)

func test_generation_metrics_are_populated() -> void:
	var level := LevelLoader.load_level("5")
	var m: Dictionary = level["generation_metrics"]
	for key in ["difficulty", "board_cards", "types", "layers", "columns", "rows", "layer_targets", "cards_per_layer",
			"free_ratio", "free_ratio_target", "free_ratio_ok", "free_cards", "blocked_cards", "max_coverage",
			"complexity", "attempts", "seed_used", "solvable", "status", "fits_portrait", "fits_landscape"]:
		Assert.is_true(m.has(key), "metric '%s' present" % key)
	Assert.equals(int(m["board_cards"]), 33, "level 5 board has 33 cards")
	Assert.equals(int(m["same_layer_overlaps"]), 0, "level 5 has no same-layer overlap")

func test_generated_board_cards_within_bounds_and_unique() -> void:
	var cfg := DifficultyProfile.for_level(6)
	var result := cfg.generate()
	Assert.is_true(result["ok"], "level 6 board generated")
	var cards: Array = result["cards"]
	Assert.equals(cards.size(), cfg.board_cards(), "board card count matches config")
	var ids := {}
	for c in cards:
		Assert.is_false(ids.has(c["id"]), "unique id")
		ids[c["id"]] = true
		Assert.is_true(c["x"] >= 0 and float(c["x"]) + cfg.card_size <= float(result["board_width"]) + 0.01, "x in bounds")
		Assert.is_true(c["y"] >= 0 and float(c["y"]) + cfg.card_size <= float(result["board_height"]) + 0.01, "y in bounds")
	Assert.is_true(float(result["board_width"]) <= cfg.board_width() and float(result["board_height"]) <= cfg.board_height(),
		"the board never exceeds the profile's base grid")

func test_free_ratio_recorded_within_band() -> void:
	LevelLoader.deterministic = true
	for id in ["1", "3", "5", "7", "10"]:
		var level := LevelLoader.load_level(id)
		var m: Dictionary = level["generation_metrics"]
		var cfg := DifficultyProfile.for_level(int(id))
		var free_ratio := float(m["free_ratio"])
		Assert.is_true(free_ratio >= cfg.free_ratio_min and free_ratio <= cfg.free_ratio_max,
			"level %s free ratio %.2f within the profile band" % [id, free_ratio])
		Assert.is_true(float(m["max_coverage"]) <= 1.0, "level %s max coverage %.2f" % [id, float(m["max_coverage"])])
	LevelLoader.deterministic = false

func test_levels_have_blocking_depth() -> void:
	for id in ["1", "2", "3", "10"]:
		var level := LevelLoader.load_level(id)
		var g := GameController.new()
		g.start_level(level, {"hold": 5, "undo": 5, "refresh": 5})
		var has_available := false
		var has_hidden := false
		for c in g.board.cards:
			if g.board.is_blocked(c):
				has_hidden = true
			else:
				has_available = true
		Assert.is_true(has_available, "level %s has free cards" % id)
		Assert.is_true(has_hidden, "level %s has blocking depth" % id)

func test_fixed_seed_is_deterministic() -> void:
	var cfg := DifficultyProfile.for_level(3)
	var a := cfg.generate()
	var b := cfg.generate()
	Assert.equals(_signature(a["cards"]), _signature(b["cards"]), "same config produces identical board")

func test_max_attempts_limits_generation_work() -> void:
	var cfg := DifficultyProfile.for_level(2)
	cfg.max_attempts = 2
	var result := cfg.generate()
	Assert.is_true(result["ok"], "low attempt budget still yields a board")
	Assert.is_true(int(result["metrics"]["attempts"]) <= 2, "attempts respect budget")

func _signature(cards: Array) -> Array:
	var sig := []
	for c in cards:
		sig.append([str(c["type"]), int(c["x"]), int(c["y"]), int(c["layer"])])
	return sig

func test_l6_is_a_three_layer_pyramid_inside_its_free_band() -> void:
	var cfg := DifficultyProfile.for_level(6)
	var result := cfg.generate()
	var m: Dictionary = result["metrics"]
	Assert.equals(cfg.layers, 3, "L6 has 3 layers")
	Assert.equals(m["cards_per_layer"], cfg.layer_targets(), "L6 cards follow the profile's pyramid")
	Assert.is_true(float(m["free_ratio"]) >= cfg.free_ratio_min and float(m["free_ratio"]) <= cfg.free_ratio_max,
		"L6 free ratio %.2f within %.2f-%.2f" % [float(m["free_ratio"]), cfg.free_ratio_min, cfg.free_ratio_max])
	Assert.is_true(bool(m["free_ratio_ok"]), "L6 free_ratio_ok reported")

func test_every_level_board_is_grid_aligned_and_supported() -> void:
	for n in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(n)
		var result := cfg.generate()
		Assert.is_true(result["ok"], "level %d generates" % n)
		var level := {"cards": result["cards"], "card_size": cfg.card_size, "board_width": result["board_width"], "board_height": result["board_height"]}
		var problems := Checks.problems(level)
		Assert.is_true(problems.is_empty(), "level %d board structure: %s" % [n, str(problems)])
		Assert.equals(Checks.layer_counts(result["cards"]), cfg.layer_targets(), "level %d cards per layer" % n)

func test_same_layer_cards_are_a_full_card_apart() -> void:
	for n in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(n)
		var cards: Array = cfg.generate()["cards"]
		for i in cards.size():
			for j in range(i + 1, cards.size()):
				if int(cards[i]["layer"]) != int(cards[j]["layer"]):
					continue
				var dx := absf(float(cards[i]["x"]) - float(cards[j]["x"]))
				var dy := absf(float(cards[i]["y"]) - float(cards[j]["y"]))
				Assert.is_true(dx >= cfg.card_size - 0.01 or dy >= cfg.card_size - 0.01,
					"level %d layer %d cards %s/%s do not overlap" % [n, int(cards[i]["layer"]), str(cards[i]["id"]), str(cards[j]["id"])])

func test_explicit_board_cards_are_dealt_as_whole_trios() -> void:
	# A board total that is not types x 3 gives some types one trio more.
	var cfg := LevelConfig.create({"board_types": ["cat", "dog", "bird", "fish"], "board_cards": 18, "columns": 5, "rows": 3, "layers": 2})
	Assert.equals(cfg.board_cards(), 18, "explicit board card total")
	var total := 0
	for t in cfg.board_types:
		Assert.equals(cfg.board_count(t) % 3, 0, "%s count is a multiple of 3" % t)
		total += cfg.board_count(t)
	Assert.equals(total, 18, "per-type counts add up to the board total")
	Assert.equals([cfg.board_count("cat"), cfg.board_count("fish")], [6, 3], "the first types take the extra trios")
	var generated := cfg.generate()
	Assert.is_true(generated["ok"], "explicit board total generates")
	var counts := {}
	for c in generated["cards"]:
		counts[str(c["type"])] = int(counts.get(str(c["type"]), 0)) + 1
	for t in cfg.board_types:
		Assert.equals(int(counts.get(t, 0)), cfg.board_count(t), "%s on the board matches board_count" % t)

func test_profile_rows_ask_for_wide_bases_with_a_wide_ramp() -> void:
	var first := DifficultyProfile.for_level(1)
	var last := DifficultyProfile.for_level(DifficultyProfile.max_level())
	Assert.equals([first.columns, first.rows], [4, 2], "level 1 starts with a 4x2 base")
	Assert.is_true(last.columns >= 8 and last.columns <= LevelConfig.MAX_COLUMNS, "the last level has an 8-9 column base (got %d)" % last.columns)
	Assert.is_true(last.rows >= 4, "the last level has at least 4 rows")
	Assert.is_true(last.board_cards() >= 60 and last.board_cards() <= LevelConfig.MAX_BOARD_CARDS, "the last level fills the wide base (%d cards)" % last.board_cards())
	for n in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(n)
		var aspect := float(cfg.columns) / float(cfg.rows)
		Assert.is_true(aspect >= 1.4, "level %d grid %dx%d is wider than tall" % [n, cfg.columns, cfg.rows])
		Assert.is_true(cfg.aspect_target >= 1.8 and cfg.aspect_target <= 2.2, "level %d steers toward a ~2:1 base" % n)
