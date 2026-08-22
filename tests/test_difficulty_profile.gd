extends RefCounted

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
	for key in ["difficulty", "board_cards", "types", "layers", "columns", "rows",
			"occupancy_h", "occupancy_v", "overlap_h", "overlap_v", "free_ratio", "free_ratio_target",
			"max_coverage", "complexity", "attempts", "solvable", "status"]:
		Assert.is_true(m.has(key), "metric '%s' present" % key)
	Assert.equals(int(m["board_cards"]), 24, "level 5 board has 24 cards")

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
		Assert.is_true(c["x"] >= 0 and float(c["x"]) + cfg.card_size <= cfg.board_width() + 0.01, "x in bounds")
		Assert.is_true(c["y"] >= 0 and float(c["y"]) + cfg.card_size <= cfg.board_height() + 0.01, "y in bounds")

func test_free_ratio_recorded_within_band() -> void:
	for id in ["1", "3", "5", "7", "10"]:
		var level := LevelLoader.load_level(id)
		var m: Dictionary = level["generation_metrics"]
		var free_ratio := float(m["free_ratio"])
		Assert.is_true(free_ratio >= 0.08 and free_ratio <= 0.85,
			"level %s free ratio %.2f within band" % [id, free_ratio])
		Assert.is_true(float(m["max_coverage"]) <= 0.85,
			"level %s max coverage %.2f within cap" % [id, float(m["max_coverage"])])

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

func test_l6_free_ratio_within_30_45_percent() -> void:
	var cfg := DifficultyProfile.for_level(6)
	var m: Dictionary = cfg.generate()["metrics"]
	Assert.is_true(float(m["free_ratio"]) >= 0.30 and float(m["free_ratio"]) <= 0.45,
		"L6 free ratio %.2f within 30-45%%" % float(m["free_ratio"]))

func test_l6_anchor_occupancy_h80_v70() -> void:
	var cfg := DifficultyProfile.for_level(6)
	var m: Dictionary = cfg.generate()["metrics"]
	Assert.is_true(float(m["anchor_occupancy_h"]) >= 0.80 - 0.01,
		"L6 horizontal occupancy %.2f >= 80%%" % float(m["anchor_occupancy_h"]))
	Assert.is_true(float(m["anchor_occupancy_v"]) >= 0.70 - 0.01,
		"L6 vertical occupancy %.2f >= 70%%" % float(m["anchor_occupancy_v"]))

func test_overlap_within_axial_ranges() -> void:
	for n in range(1, DifficultyProfile.max_level() + 1):
		var m: Dictionary = DifficultyProfile.for_level(n).generate()["metrics"]
		Assert.is_true(float(m["overlap_h"]) >= LevelConfig.OVERLAP_H_MIN - 0.001 and float(m["overlap_h"]) <= LevelConfig.OVERLAP_H_MAX + 0.001,
			"level %d overlap_h %.2f within H range" % [n, float(m["overlap_h"])])
		Assert.is_true(float(m["overlap_v"]) >= LevelConfig.OVERLAP_V_MIN - 0.001 and float(m["overlap_v"]) <= LevelConfig.OVERLAP_V_MAX + 0.001,
			"level %d overlap_v %.2f within V range" % [n, float(m["overlap_v"])])

func test_same_layer_min_distance_above_floor() -> void:
	for n in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(n)
		var result := cfg.generate()
		var cards: Array = result["cards"]
		var by_layer := {}
		for c in cards:
			if not by_layer.has(int(c["layer"])):
				by_layer[int(c["layer"])] = []
			by_layer[int(c["layer"])].append(Vector2(c["x"], c["y"]))
		for layer in by_layer:
			var pts: Array = by_layer[layer]
			for i in pts.size():
				for j in range(i + 1, pts.size()):
					Assert.is_true((pts[i] as Vector2).distance_to(pts[j]) >= cfg.min_same_layer_distance() - 0.01,
						"level %d layer %d same-layer distance %.1f below %.1f" % [n, layer, (pts[i] as Vector2).distance_to(pts[j]), cfg.min_same_layer_distance()])