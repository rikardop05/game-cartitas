extends RefCounted

# The upper layers of every board are SCATTERED over the base, like the front cards of
# a shuffled pile: no straight rows of cards, varied fractional offsets from the base
# grid, spread over the whole board, every card resting on at least two cards below,
# and still fair (free cards at the start, cards released as the pile is uncovered).
#
# The scatter thresholds below are what the quarter-card scatter delivers with margin;
# the old half-card "midpoint" generator measured: straight-run ratio 0.90-1.00 (mean per
# level), longest run 4-8 cards, one or two distinct fractional x offsets per layer.

const Checks = preload("res://tests/board_checks.gd")
const SEEDS := 12
const CARD := 48.0
const RUN_RATIO_MAX := 0.5  # share of upper cards with a card exactly side by side, per board
const RUN_RATIO_MEAN_MAX := 0.3  # ... averaged over the seeds of a profile
const LONGEST_RUN_MAX := 3
const RUN_MIN_UPPER := 5  # smaller upper layers are too sparse for the run checks
const FREE_BAND_SHARE_MIN := 0.8  # share of seeds whose free ratio is inside the profile's band
const RELEASING_MEAN_MIN := 0.3  # share of upper cards that free something when lifted
const RESERVE_MIN_LAYER_CARDS := 8
const FREE_LAYER_SHARE_MIN := 0.07

var _boards := {}

# {label, config, boards: [{cards, metrics}]} for every shipped level and Endless rounds 1/5/15.
func _profiles() -> Array:
	var out: Array = []
	for n in range(1, DifficultyProfile.max_level() + 1):
		out.append({"label": "level %d" % n, "config": DifficultyProfile.for_level(n), "seed_offset": 0})
	for round_number in [1, 5, 15]:
		out.append({
			"label": "endless round %d" % round_number,
			"config": DifficultyProfile.for_level(EndlessRun.difficulty_for_round(round_number)),
			"seed_offset": 500 * round_number,
		})
	return out

func _generate(profile: Dictionary) -> Array:
	var key := str(profile["label"])
	if _boards.has(key):
		return _boards[key]
	var cfg: LevelConfig = profile["config"]
	var boards: Array = []
	for i in SEEDS:
		var seed_used: int = cfg.seed + int(profile["seed_offset"]) + i
		var result := BoardPipeline.generate(cfg.build_spec(seed_used, LevelBoardGenerator.symbol_seed_for(seed_used)))
		Assert.is_true(result.ok, "%s seed %d builds" % [key, seed_used])
		if result.ok:
			boards.append({"cards": result.cards, "metrics": result.metrics, "seed": seed_used})
	_boards[key] = boards
	return boards

# The pipeline's cards as a delivered level: cropped so the base touches (0, 0).
func _as_level(cards: Array) -> Dictionary:
	var bounds := Checks.base_bounds(cards, CARD)
	var cropped: Array = []
	for c in cards:
		cropped.append({"id": str(c["id"]), "x": float(c["x"]) - bounds.position.x, "y": float(c["y"]) - bounds.position.y, "layer": int(c["layer"])})
	return {"cards": cropped, "card_size": CARD, "board_width": bounds.size.x, "board_height": bounds.size.y}

func _upper_in_layer(cards: Array, layer: int) -> int:
	var n := 0
	for c in cards:
		if int(c["layer"]) == layer:
			n += 1
	return n

func test_run_metrics_flag_a_tidy_row() -> void:
	# The shape the owner circled: six upper cards in one straight row.
	var cards: Array = [{"id": "b", "x": 0, "y": 0, "layer": 0}]
	for i in 6:
		cards.append({"id": "u%d" % i, "x": i * 48, "y": 24, "layer": 1})
	Assert.equals(Checks.straight_run_ratio(cards, CARD), 1.0, "a row of six is entirely straight run")
	Assert.equals(Checks.adjacent_run_ratio(cards, CARD, true), 1.0, "... horizontally")
	Assert.equals(Checks.adjacent_run_ratio(cards, CARD, false), 0.0, "... and not vertically")
	Assert.equals(Checks.longest_run(cards, CARD), 6, "longest run is the six cards")
	Assert.equals(Checks.offset_classes(cards, 1, CARD, true).size(), 1, "a row has one fractional x offset")
	cards.clear()
	cards.append({"id": "b", "x": 0, "y": 0, "layer": 0})
	for p in [Vector2(0, 0), Vector2(60, 12), Vector2(110, 36), Vector2(24, 60), Vector2(84, 72)]:
		cards.append({"id": "s%d" % cards.size(), "x": p.x, "y": p.y, "layer": 1})
	Assert.equals(Checks.straight_run_ratio(cards, CARD), 0.0, "staggered cards form no run")

func test_upper_layers_are_scattered_not_in_straight_rows() -> void:
	for profile in _profiles():
		var boards := _generate(profile)
		var mean := 0.0
		var counted := 0
		for b in boards:
			var cards: Array = b["cards"]
			if Checks.upper_cards(cards).size() < RUN_MIN_UPPER:
				continue
			var ratio := Checks.straight_run_ratio(cards, CARD)
			counted += 1
			mean += ratio
			Assert.is_true(ratio <= RUN_RATIO_MAX, "%s seed %d: %.2f of the upper cards sit in a straight run (max %.2f)" % [profile["label"], b["seed"], ratio, RUN_RATIO_MAX])
			var longest := Checks.longest_run(cards, CARD)
			Assert.is_true(longest <= LONGEST_RUN_MAX, "%s seed %d: a run of %d cards side by side (max %d)" % [profile["label"], b["seed"], longest, LONGEST_RUN_MAX])
		if counted > 0:
			mean /= float(counted)
			Assert.is_true(mean <= RUN_RATIO_MEAN_MAX, "%s: mean straight-run ratio %.2f (max %.2f)" % [profile["label"], mean, RUN_RATIO_MEAN_MAX])

func test_every_upper_layer_uses_varied_fractional_offsets() -> void:
	for profile in _profiles():
		var cfg: LevelConfig = profile["config"]
		for b in _generate(profile):
			var cards: Array = b["cards"]
			for layer in range(1, cfg.layers):
				var n := _upper_in_layer(cards, layer)
				if n < 5:
					continue
				var wanted := 3 if n >= 8 else 2
				var xs := Checks.offset_classes(cards, layer, CARD, true)
				var ys := Checks.offset_classes(cards, layer, CARD, false)
				Assert.is_true(xs.size() >= wanted, "%s seed %d layer %d: %d distinct fractional x offsets %s (want %d)" % [profile["label"], b["seed"], layer, xs.size(), str(xs), wanted])
				Assert.is_true(ys.size() >= wanted, "%s seed %d layer %d: %d distinct fractional y offsets %s (want %d)" % [profile["label"], b["seed"], layer, ys.size(), str(ys), wanted])

func test_upper_cards_are_spread_over_the_whole_board() -> void:
	for profile in _profiles():
		var cfg: LevelConfig = profile["config"]
		for b in _generate(profile):
			var cards: Array = b["cards"]
			if Checks.upper_cards(cards).size() >= 6:
				var all_hits := Checks.region_hits(cards, CARD)
				Assert.equals(int(all_hits["thirds"]), 3, "%s seed %d: upper cards reach all three horizontal thirds" % [profile["label"], b["seed"]])
				Assert.equals(int(all_hits["halves"]), 2, "%s seed %d: upper cards reach top and bottom" % [profile["label"], b["seed"]])
			for layer in range(1, cfg.layers):
				if _upper_in_layer(cards, layer) < 6:
					continue
				var hits := Checks.region_hits(cards, CARD, [layer])
				Assert.equals(int(hits["thirds"]), 3, "%s seed %d layer %d reaches left, centre and right" % [profile["label"], b["seed"], layer])
				Assert.equals(int(hits["halves"]), 2, "%s seed %d layer %d reaches top and bottom" % [profile["label"], b["seed"], layer])

func test_upper_cards_rest_on_the_pile_inside_the_base() -> void:
	for profile in _profiles():
		var cfg: LevelConfig = profile["config"]
		for b in _generate(profile):
			var cards: Array = b["cards"]
			var problems := Checks.problems(_as_level(cards))
			Assert.is_true(problems.is_empty(), "%s seed %d: %s" % [profile["label"], b["seed"], str(problems)])
			Assert.equals(Checks.layer_counts(cards), cfg.layer_targets(), "%s seed %d keeps the pyramid counts" % [profile["label"], b["seed"]])
			var m: Dictionary = b["metrics"]
			Assert.equals(int(m["unsupported_cards"]), 0, "%s seed %d: pipeline reports every upper card supported" % [profile["label"], b["seed"]])
			Assert.equals(int(m["same_layer_overlaps"]), 0, "%s seed %d: pipeline reports no same-layer overlap" % [profile["label"], b["seed"]])
			Assert.is_true(bool(m["connected_layout"]), "%s seed %d: the pile is one connected piece" % [profile["label"], b["seed"]])

func test_scattered_boards_stay_fair() -> void:
	for profile in _profiles():
		var cfg: LevelConfig = profile["config"]
		var in_band := 0
		var releasing := 0.0
		var boards := _generate(profile)
		for b in boards:
			var cards: Array = b["cards"]
			var free := Checks.free_per_layer(cards, CARD)
			var counts := Checks.layer_counts(cards)
			var ratio := float(Checks.free_cards(cards, CARD)) / float(cards.size())
			Assert.is_true(ratio >= 0.15 and ratio <= 0.8, "%s seed %d: free ratio %.2f is sane" % [profile["label"], b["seed"], ratio])
			if ratio >= cfg.free_ratio_min and ratio <= cfg.free_ratio_max:
				in_band += 1
			Assert.equals(int(free[free.size() - 1]), int(counts[counts.size() - 1]), "%s seed %d: the whole top layer is free" % [profile["label"], b["seed"]])
			for layer in range(counts.size() - 1):
				Assert.is_true(int(free[layer]) >= 1, "%s seed %d: layer %d keeps a free card" % [profile["label"], b["seed"], layer])
				if int(counts[layer]) >= RESERVE_MIN_LAYER_CARDS:
					Assert.is_true(float(free[layer]) >= FREE_LAYER_SHARE_MIN * float(counts[layer]),
						"%s seed %d: layer %d has %d of %d cards free" % [profile["label"], b["seed"], layer, int(free[layer]), int(counts[layer])])
			releasing += Checks.releasing_ratio(cards, CARD)
		Assert.is_true(float(in_band) >= FREE_BAND_SHARE_MIN * float(boards.size()),
			"%s: %d of %d seeds start inside the free-ratio band %.2f-%.2f" % [profile["label"], in_band, boards.size(), cfg.free_ratio_min, cfg.free_ratio_max])
		Assert.is_true(releasing / float(boards.size()) >= RELEASING_MEAN_MIN,
			"%s: lifting an upper card frees something for %.2f of them on average (min %.2f)" % [profile["label"], releasing / float(boards.size()), RELEASING_MEAN_MIN])

func test_scatter_is_deterministic_and_differs_between_seeds() -> void:
	for n in [4, 7, 11]:
		var cfg := DifficultyProfile.for_level(n)
		var signatures := {}
		for i in 8:
			var seed_used := cfg.seed + 700 + i
			var a := BoardPipeline.generate(cfg.build_spec(seed_used, 1))
			var b := BoardPipeline.generate(cfg.build_spec(seed_used, 1))
			Assert.is_true(a.ok and b.ok, "level %d seed %d builds twice" % [n, seed_used])
			if not (a.ok and b.ok):
				continue
			Assert.equals(_positions(a.cards), _positions(b.cards), "level %d seed %d: the same seed scatters the same board" % [n, seed_used])
			signatures[str(_positions(a.cards))] = true
		Assert.is_true(signatures.size() >= 7, "level %d: 8 seeds give at least 7 different boards (got %d)" % [n, signatures.size()])

func _positions(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append("%d:%d,%d" % [int(c["layer"]), int(c["grid_x"]), int(c["grid_y"])])
	out.sort()
	return out
