extends RefCounted

# Boards of every Level and Endless round come from BoardPipeline (through
# LevelBoardGenerator): classic tile-stacking boards that are grid-aligned,
# pyramidal, solvable with their Support Decks and powers, and blocked by one rule.

const Checks = preload("res://tests/board_checks.gd")
const BOARD_SIZE := Vector2(332, 264)
const METRIC_KEYS := ["seed_used", "attempts", "fits_landscape", "fits_portrait", "free_cards", "blocked_cards",
		"free_ratio", "free_ratio_ok", "cards_per_layer", "solvable", "status", "generation_time_ms", "clearing_capacity"]

func _reset() -> void:
	LevelLoader.deterministic = false

func _check_resolved(label: String, level: Dictionary, profile: LevelConfig, require_in_band: bool) -> void:
	Assert.is_false(level.has("error"), "%s resolves: %s" % [label, str(level.get("error", ""))])
	if level.has("error"):
		return
	var v := LevelValidator.validate(level)
	Assert.is_true(v["valid"], "%s passes LevelValidator: %s" % [label, str(v["errors"])])
	Assert.is_true(SolvabilityChecker.is_solvable(level), "%s is solvable with its decks and powers" % label)
	var problems := Checks.problems(level)
	Assert.is_true(problems.is_empty(), "%s board structure: %s" % [label, str(problems)])
	var cards: Array = level["cards"]
	Assert.equals(cards.size(), profile.board_cards(), "%s has the profile's board card count" % label)
	var counts := Checks.layer_counts(cards)
	Assert.equals(counts.size(), profile.layers, "%s uses exactly the profile's layers" % label)
	Assert.equals(counts, profile.layer_targets(), "%s splits the cards as the profile's pyramid" % label)
	var type_counts := {}
	for c in cards:
		type_counts[str(c["type"])] = int(type_counts.get(str(c["type"]), 0)) + 1
	for t in profile.board_types:
		Assert.equals(int(type_counts.get(t, 0)), profile.board_count(t), "%s has %d '%s' cards on the board" % [label, profile.board_count(t), t])
		Assert.equals(int(type_counts.get(t, 0)) % 3, 0, "%s has a multiple of 3 '%s' cards on the board" % [label, t])
	var m: Dictionary = level["generation_metrics"]
	for key in METRIC_KEYS:
		Assert.is_true(m.has(key), "%s metrics expose '%s'" % [label, key])
	var free := Checks.free_cards(cards, float(level["card_size"]))
	Assert.equals(int(m["free_cards"]), free, "%s generator and the shared blocking rule agree on free cards" % label)
	Assert.equals(LevelValidator.free_card_count(level), free, "%s validator and the shared blocking rule agree on free cards" % label)
	var free_ratio := float(free) / float(cards.size())
	Assert.is_true(free >= 3, "%s has at least 3 free cards at the start (got %d)" % [label, free])
	Assert.is_true(free_ratio >= 0.15 and free_ratio <= 0.80, "%s free ratio %.2f is sane" % [label, free_ratio])
	if require_in_band:
		Assert.is_true(free_ratio >= profile.free_ratio_min and free_ratio <= profile.free_ratio_max,
			"%s free ratio %.2f inside the profile band %.2f-%.2f" % [label, free_ratio, profile.free_ratio_min, profile.free_ratio_max])
		Assert.is_true(bool(m["free_ratio_ok"]), "%s reports free_ratio_ok" % label)

func test_every_shipped_level_is_a_valid_solvable_pyramid() -> void:
	LevelLoader.deterministic = true
	for id in LevelLoader.load_all_level_ids():
		var level := LevelLoader.load_level(id, BOARD_SIZE)
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%s.json" % id))
		_check_resolved("level %s" % id, level, DifficultyProfile.for_level(int(raw["difficulty"])), true)
	_reset()

func test_every_shipped_level_is_valid_with_random_seeds() -> void:
	LevelLoader.deterministic = false
	for id in LevelLoader.load_all_level_ids():
		for i in 3:
			var level := LevelLoader.load_level(id, BOARD_SIZE)
			var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%s.json" % id))
			_check_resolved("level %s (random %d)" % [id, i], level, DifficultyProfile.for_level(int(raw["difficulty"])), false)

func test_endless_rounds_1_5_15_are_valid_solvable_pyramids() -> void:
	LevelLoader.deterministic = true
	for round_number in [1, 5, 15]:
		var run := EndlessRun.new()
		run.current_round = round_number
		var level := run.build_round_level(BOARD_SIZE)
		_check_resolved("endless round %d" % round_number, level, DifficultyProfile.for_level(EndlessRun.difficulty_for_round(round_number)), true)
	_reset()

func test_fixed_seed_levels_are_deterministic() -> void:
	LevelLoader.deterministic = true
	for id in LevelLoader.load_all_level_ids():
		var a := LevelLoader.load_level(id, BOARD_SIZE)
		var b := LevelLoader.load_level(id, Vector2(466, 214))
		Assert.equals(Checks.signature(a), Checks.signature(b), "level %s: same seed gives the same board whatever the board area" % id)
		Assert.equals(a["deck_a"], b["deck_a"], "level %s: same deck_a" % id)
		Assert.equals(a["deck_b"], b["deck_b"], "level %s: same deck_b" % id)
		Assert.equals(float(a["board_width"]), float(b["board_width"]), "level %s: same board width" % id)
	_reset()

func test_each_attempt_builds_a_different_board() -> void:
	LevelLoader.deterministic = false
	for id in ["1", "4", "8", "11"]:
		var a := LevelLoader.load_level(id, BOARD_SIZE)
		var b := LevelLoader.load_level(id, BOARD_SIZE)
		Assert.not_equals(int(a["generation_metrics"]["seed_used"]), int(b["generation_metrics"]["seed_used"]), "level %s draws a new seed per attempt" % id)
		Assert.not_equals(Checks.signature(a), Checks.signature(b), "level %s shows a different board on retry" % id)

func test_board_geometry_varies_between_seeds() -> void:
	# Different seeds must change the arrangement itself, not only the symbols.
	var cfg := DifficultyProfile.for_level(8)
	var shapes := {}
	for i in 12:
		var result := BoardPipeline.generate(cfg.build_spec(cfg.seed + i, i))
		Assert.is_true(result.ok, "seed %d builds" % i)
		var cells: Array = []
		for c in result.cards:
			cells.append("%d:%d,%d" % [int(c["layer"]), int(c["grid_x"]), int(c["grid_y"])])
		cells.sort()
		shapes[str(cells)] = true
	Assert.is_true(shapes.size() >= 6, "12 seeds give at least 6 distinct arrangements (got %d)" % shapes.size())

func test_free_cards_start_healthy_and_fall_with_depth() -> void:
	LevelLoader.deterministic = true
	var first_ratio := 0.0
	var last_ratio := 0.0
	for id in LevelLoader.load_all_level_ids():
		var level := LevelLoader.load_level(id, BOARD_SIZE)
		var ratio := float(Checks.free_cards(level["cards"], 48.0)) / float(level["cards"].size())
		if str(id) == "1":
			first_ratio = ratio
		last_ratio = ratio
	Assert.is_true(first_ratio >= 0.5, "level 1 starts with at least half the cards free (%.2f)" % first_ratio)
	Assert.is_true(last_ratio < first_ratio, "the last level is more buried than the first (%.2f < %.2f)" % [last_ratio, first_ratio])
	_reset()

func test_difficulty_progression_is_perceivable() -> void:
	var prev_cards := 0
	var prev_types := 0
	var prev_layers := 0
	var prev_free := 1.0
	for n in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(n)
		Assert.is_true(cfg.board_cards() >= prev_cards, "level %d cards do not shrink" % n)
		Assert.is_true(cfg.board_types.size() >= prev_types, "level %d types do not shrink" % n)
		Assert.is_true(cfg.layers >= prev_layers, "level %d layers do not shrink" % n)
		Assert.is_true(cfg.free_ratio <= prev_free + 0.021, "level %d does not start much freer than level %d" % [n, n - 1])
		prev_cards = cfg.board_cards()
		prev_types = cfg.board_types.size()
		prev_layers = cfg.layers
		prev_free = cfg.free_ratio
	var first := DifficultyProfile.for_level(1)
	var last := DifficultyProfile.for_level(DifficultyProfile.max_level())
	Assert.is_true(last.board_cards() >= first.board_cards() * 3, "the last level has at least 3x the cards of level 1")
	Assert.is_true(last.layers > first.layers, "the last level is stacked higher than level 1")

func test_validator_and_runtime_share_the_ten_percent_blocking_rule() -> void:
	# An upper card covering under 10% of a lower card must NOT block it; one
	# covering 10% or more must. The validator, the runtime board and the
	# generation metrics all count free cards this way.
	var grazing := {
		"id": "x", "card_size": 48.0, "board_width": 200.0, "board_height": 100.0, "clearing_capacity": 7,
		"cards": [
			{"id": "a", "type": "cat", "x": 0, "y": 0, "layer": 0},
			{"id": "b", "type": "cat", "x": 44, "y": 0, "layer": 1},
			{"id": "c", "type": "cat", "x": 100, "y": 0, "layer": 0},
		],
		"deck_a": [], "deck_b": [], "time_thresholds": {"three_stars": 60, "two_stars": 120},
	}
	Assert.equals(LevelValidator.free_card_count(grazing), 3, "a card touched by 8% is still free")
	var g := GameController.new()
	g.start_level(grazing, {})
	Assert.equals(g.board.get_card("a").state, Card.State.AVAILABLE, "runtime agrees: grazed card available")
	grazing["cards"][1]["x"] = 38
	Assert.equals(LevelValidator.free_card_count(grazing), 2, "a card covered by 21% is blocked")
	g.start_level(grazing, {})
	Assert.equals(g.board.get_card("a").state, Card.State.HIDDEN, "runtime agrees: covered card hidden")

func test_validator_rejects_same_layer_overlap() -> void:
	var level := LevelLoader.load_level("2", BOARD_SIZE)
	Assert.is_true(LevelValidator.validate(level)["valid"], "generated level is valid")
	var broken: Dictionary = level.duplicate(true)
	var first: Dictionary = broken["cards"][0]
	var other: Dictionary = {}
	for c in broken["cards"]:
		if int(c["layer"]) == int(first["layer"]) and str(c["id"]) != str(first["id"]):
			other = c
			break
	other["x"] = int(first["x"]) + 24
	other["y"] = int(first["y"])
	var v := LevelValidator.validate(broken)
	Assert.is_false(v["valid"], "two overlapping cards of one layer are invalid")
	var mentioned := false
	for e in v["errors"]:
		if str(e).contains("overlap on layer"):
			mentioned = true
	Assert.is_true(mentioned, "the diagnostic names the same-layer overlap")

# Layer-0 aspect (width / height) of a resolved level.
func _base_aspect(level: Dictionary) -> float:
	var card_size := float(level["card_size"])
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for c in level["cards"]:
		if int(c["layer"]) != 0:
			continue
		min_x = minf(min_x, float(c["x"]))
		max_x = maxf(max_x, float(c["x"]))
		min_y = minf(min_y, float(c["y"]))
		max_y = maxf(max_y, float(c["y"]))
	return (max_x - min_x + card_size) / (max_y - min_y + card_size)

func test_boards_are_wide_with_many_small_cards() -> void:
	LevelLoader.deterministic = true
	var min_px := 30.0
	var prev_cols := 0
	for id in LevelLoader.load_all_level_ids():
		var level := LevelLoader.load_level(id, BOARD_SIZE)
		var cfg := DifficultyProfile.for_level(int(id))
		var card_size := float(level["card_size"])
		var board := Vector2(float(level["board_width"]), float(level["board_height"]))
		var columns := roundi(board.x / card_size)
		# Rendered card = fitted to each envelope, never above the UI cap.
		for envelope in [LevelConfig.PORTRAIT_BOARD_ENVELOPE, LevelConfig.LANDSCAPE_BOARD_ENVELOPE]:
			var px := cfg.envelope_card_size(envelope, board)
			Assert.is_true(px <= LevelConfig.MAX_BOARD_CARD_PX + 0.01, "level %s card %.1fpx stays within the %.0fpx cap in %s" % [id, px, LevelConfig.MAX_BOARD_CARD_PX, str(envelope)])
			Assert.is_true(px >= min_px, "level %s card %.1fpx stays a usable touch target in %s" % [id, px, str(envelope)])
		Assert.is_true(columns >= prev_cols, "level %s is not narrower than the level before (%d columns)" % [id, columns])
		prev_cols = columns
		if int(id) >= 5:
			var aspect := _base_aspect(level)
			Assert.is_true(aspect >= 1.6 and aspect <= 2.4, "level %s base aspect %.2f is wide (1.6-2.4)" % [id, aspect])
	var first := LevelLoader.load_level("1", BOARD_SIZE)
	var last := LevelLoader.load_level(str(DifficultyProfile.max_level()), BOARD_SIZE)
	Assert.equals(roundi(float(first["board_width"]) / 48.0), 4, "level 1 starts with a 4-column base")
	Assert.is_true(roundi(float(last["board_width"]) / 48.0) >= 8, "the last level has an 8-9 column base")
	Assert.is_true(last["cards"].size() >= 60, "the last level has many cards (%d)" % last["cards"].size())
	_reset()
