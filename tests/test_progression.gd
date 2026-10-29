extends RefCounted

# Progression of the shipped levels through the BoardPipeline-based generator:
# the table of growth per level and statistics over many seeds per level.

const Checks = preload("res://tests/board_checks.gd")
const SAMPLES_PER_LEVEL := 60

func _deck_pool(id: int) -> Array:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%s.json" % id))
	var pool: Array = []
	for t in raw.get("deck", []):
		pool.append(str(t))
	return pool

func _level_dict_for(id: String, cards: Array, seed: int) -> Dictionary:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%s.json" % id))
	var split := LevelBoardGenerator.split_decks(_deck_pool(int(id)), seed)
	return {
		"id": id,
		"clearing_capacity": int(raw.get("clearing_capacity", 7)),
		"cards": cards,
		"deck_a": split["deck_a"],
		"deck_b": split["deck_b"],
		"time_thresholds": raw.get("time_thresholds", {"three_stars": 60, "two_stars": 120}),
		"rewards": raw.get("rewards", []),
	}

func _generate_sample(id: int, seed: int) -> Dictionary:
	var cfg := DifficultyProfile.for_level(id)
	cfg.with_deck(_deck_pool(id))
	cfg.seed = seed
	return cfg.generate()

# Share of the board area covered by the base layer (upper layers stack on top
# of it, so only layer 0 can be compared with the area).
func _occupation(cfg: LevelConfig, result: Dictionary) -> float:
	var area := float(result["board_width"]) * float(result["board_height"])
	return (float(Checks.layer_counts(result["cards"])[0]) * cfg.card_size * cfg.card_size) / area

func test_progression_table_and_growth() -> void:
	var prev_cards := -1
	var prev_types := -1
	var prev_layers := -1
	var prev_cols := -1
	var prev_rows := -1
	var prev_free := 1.0
	print("id   | cards| types| cols | rows | layers| free | blk  | freeR  | occ   | per layer")
	print("-----|------|------|------|------|-------|------|------|--------|-------|----------")
	for id in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(id)
		Assert.is_true(cfg != null, "level %d has a difficulty profile" % id)
		var result := _generate_sample(id, cfg.seed)
		Assert.is_true(result["ok"], "level %d generated" % id)
		var cards: Array = result["cards"]
		var m: Dictionary = result["metrics"]
		var free := int(m["free_cards"])
		var blocked := int(m["blocked_cards"])
		var occ := _occupation(cfg, result)
		var v := cfg.validate()
		Assert.is_true(v["valid"], "level %d config valid: %s" % [id, str(v["errors"])])
		Assert.equals(cards.size(), cfg.board_cards(), "level %d board card count" % id)
		Assert.equals(cards.size() % 3, 0, "level %d board cards multiple of 3" % id)
		Assert.is_true(free >= 3, "level %d has free cards" % id)
		Assert.is_true(blocked >= 1, "level %d has blocked cards (depth)" % id)
		Assert.is_true(occ <= 1.0, "level %d base layer never exceeds the board area (occ %.2f)" % [id, occ])
		Assert.equals(Checks.layer_counts(cards), cfg.layer_targets(), "level %d pyramid follows the profile" % id)
		Assert.is_true(cfg.columns >= prev_cols, "level %d columns grow" % id)
		Assert.is_true(cfg.rows >= prev_rows, "level %d rows grow" % id)
		Assert.is_true(int(m["board_cards"]) >= prev_cards, "level %d cards grow" % id)
		Assert.is_true(int(m["types"]) >= prev_types, "level %d unique types grow" % id)
		Assert.is_true(cfg.layers >= prev_layers, "level %d layers grow" % id)
		Assert.is_true(cfg.free_ratio <= prev_free + 0.021, "level %d wants no more free cards than level %d" % [id, id - 1])
		prev_cards = int(m["board_cards"])
		prev_types = int(m["types"])
		prev_layers = cfg.layers
		prev_cols = cfg.columns
		prev_rows = cfg.rows
		prev_free = cfg.free_ratio
		print("%4s | %4d | %4d | %4d | %4d | %5d | %4d | %4d | %6.2f | %5.2f | %s" % [
			str(id), int(m["board_cards"]), int(m["types"]), cfg.columns, cfg.rows, cfg.layers, free, blocked,
			float(m["free_ratio"]), occ, str(m["cards_per_layer"]),
		])
	Assert.equals(DifficultyProfile.max_level(), 11, "exactly 11 parametric difficulty profiles")

func test_statistical_layouts_per_level() -> void:
	print("STATS (min / mean / max over %d samples per level)" % SAMPLES_PER_LEVEL)
	print("id   |       free      |     blocked     |   free ratio    |  cards  ")
	var total_samples := 0
	var total_invalid := 0
	for id in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(id)
		var min_free := 999999
		var max_free := -1
		var sum_free := 0.0
		var min_blocked := 999999
		var max_blocked := -1
		var sum_blocked := 0.0
		var min_ratio := 9.0
		var max_ratio := -1.0
		var sum_ratio := 0.0
		var min_cards := 999999
		var max_cards := -1
		var invalid := 0
		var in_band := 0
		for i in SAMPLES_PER_LEVEL:
			var result := _generate_sample(id, cfg.seed + i)
			total_samples += 1
			if not result["ok"]:
				invalid += 1
				continue
			var m: Dictionary = result["metrics"]
			var cards_n: int = (result["cards"] as Array).size()
			var free := int(m["free_cards"])
			var blocked := int(m["blocked_cards"])
			var ratio := float(m["free_ratio"])
			min_free = mini(min_free, free)
			max_free = maxi(max_free, free)
			sum_free += float(free)
			min_blocked = mini(min_blocked, blocked)
			max_blocked = maxi(max_blocked, blocked)
			sum_blocked += float(blocked)
			min_ratio = minf(min_ratio, ratio)
			max_ratio = maxf(max_ratio, ratio)
			sum_ratio += ratio
			min_cards = mini(min_cards, cards_n)
			max_cards = maxi(max_cards, cards_n)
			if bool(m["free_ratio_ok"]):
				in_band += 1
			var level := {"cards": result["cards"], "card_size": cfg.card_size, "board_width": result["board_width"], "board_height": result["board_height"]}
			if cards_n != cfg.board_cards() or cards_n % 3 != 0 or free < 3 or not Checks.problems(level).is_empty():
				invalid += 1
		total_invalid += invalid
		print("%4s | %3d/%5.1f/%3d | %3d/%5.1f/%3d | %.2f/%.2f/%.2f | %3d/%3d" % [
			id, min_free, sum_free / float(SAMPLES_PER_LEVEL), max_free,
			min_blocked, sum_blocked / float(SAMPLES_PER_LEVEL), max_blocked,
			min_ratio, sum_ratio / float(SAMPLES_PER_LEVEL), max_ratio,
			min_cards, max_cards,
		])
		Assert.equals(invalid, 0, "level %d: 0 invalid layouts (got %d)" % [id, invalid])
		Assert.is_true(min_free >= 3, "level %d: min free >= 3" % id)
		Assert.equals(max_cards, min_cards, "level %d: card count constant across layouts" % id)
		Assert.is_true(in_band >= SAMPLES_PER_LEVEL * 8 / 10, "level %d: at least 80%% of seeds land in the free band (got %d/%d)" % [id, in_band, SAMPLES_PER_LEVEL])
	Assert.equals(total_samples, DifficultyProfile.max_level() * SAMPLES_PER_LEVEL, "total samples == %d" % [DifficultyProfile.max_level() * SAMPLES_PER_LEVEL])
	Assert.equals(total_invalid, 0, "no invalid layouts across all levels")

func test_solvability_statistical_per_level() -> void:
	print("SOLVABILITY (clearing capacity 7, greedy solver, %d samples per level)" % SAMPLES_PER_LEVEL)
	print("id   | solvable | generated | unsolvable  ")
	for id in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(id)
		var solved := 0
		var generated := 0
		var unsolvable := 0
		for i in SAMPLES_PER_LEVEL:
			var result := _generate_sample(id, cfg.seed + i)
			if not result["ok"]:
				continue
			generated += 1
			var m: Dictionary = result["metrics"]
			var level := _level_dict_for(str(id), result["cards"], int(m["seed_used"]))
			if SolvabilityChecker.is_solvable(level):
				solved += 1
			else:
				unsolvable += 1
		print("%4s | %5d    | %5d      | %5d" % [id, solved, generated, unsolvable])
		Assert.equals(unsolvable, 0, "level %d: no generated layout is unsolvable (got %d)" % [id, unsolvable])

func test_statistical_visual_metrics_per_level() -> void:
	print("VISUAL METRICS min/mean/max over %d samples per level (scale = card px / card_size)" % SAMPLES_PER_LEVEL)
	print("id | scaleP | scaleL | board w | board h | gen_ms")
	for id in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(id)
		var keys := ["scale_p", "scale_l", "w", "h", "ms"]
		var mn := {}
		var mx := {}
		var sum := {}
		for k in keys:
			mn[k] = 1e9
			mx[k] = -1.0
			sum[k] = 0.0
		var samples := 0
		var failed := 0
		for i in SAMPLES_PER_LEVEL:
			var t0 := Time.get_ticks_msec()
			var result := _generate_sample(id, cfg.seed + i)
			var dt := float(Time.get_ticks_msec() - t0)
			if not result["ok"]:
				failed += 1
				continue
			samples += 1
			var m: Dictionary = result["metrics"]
			var vals := {
				"scale_p": float(m["min_card_px_portrait"]) / cfg.card_size,
				"scale_l": float(m["min_card_px_landscape"]) / cfg.card_size,
				"w": float(result["board_width"]),
				"h": float(result["board_height"]),
				"ms": dt,
			}
			for k in keys:
				mn[k] = minf(mn[k], vals[k])
				mx[k] = maxf(mx[k], vals[k])
				sum[k] += vals[k]
			Assert.is_true(bool(m["fits_portrait"]) and bool(m["fits_landscape"]), "level %d seed %d fits both envelopes" % [id, i])
			for key in ["min_card_px_portrait", "min_card_px_landscape"]:
				Assert.is_true(float(m[key]) <= LevelConfig.MAX_BOARD_CARD_PX + 0.01 and float(m[key]) >= 30.0, "level %d seed %d %s %.1fpx is a small touch-sized card (30-%.0fpx)" % [id, i, key, float(m[key]), LevelConfig.MAX_BOARD_CARD_PX])
			Assert.is_true(vals["w"] <= cfg.board_width() and vals["h"] <= cfg.board_height(), "level %d seed %d stays inside its base grid" % [id, i])
		print("%2d | %.2f/%.2f/%.2f | %.2f/%.2f/%.2f | %.0f/%.0f/%.0f | %.0f/%.0f/%.0f | %.0f/%.0f/%.0f" % [
			id,
			mn["scale_p"], sum["scale_p"] / float(maxi(1, samples)), mx["scale_p"],
			mn["scale_l"], sum["scale_l"] / float(maxi(1, samples)), mx["scale_l"],
			mn["w"], sum["w"] / float(maxi(1, samples)), mx["w"],
			mn["h"], sum["h"] / float(maxi(1, samples)), mx["h"],
			mn["ms"], sum["ms"] / float(maxi(1, samples)), mx["ms"],
		])
		Assert.equals(failed, 0, "level %d: all %d generations succeeded (got %d)" % [id, SAMPLES_PER_LEVEL, failed])

func test_l6_band_criteria() -> void:
	var cfg := DifficultyProfile.for_level(6)
	Assert.is_true(cfg.layers >= 3 and cfg.layers <= 4, "L6 3-4 layers (got %d)" % cfg.layers)
	Assert.is_true(cfg.free_ratio >= 0.25 and cfg.free_ratio <= 0.45, "L6 free_ratio target in 25-45%% (got %.2f)" % cfg.free_ratio)
	var result := _generate_sample(6, cfg.seed)
	Assert.is_true(result["ok"], "L6 generates")
	var m: Dictionary = result["metrics"]
	Assert.is_true(float(m["free_ratio"]) >= cfg.free_ratio_min and float(m["free_ratio"]) <= cfg.free_ratio_max,
		"L6 measured free_ratio %.2f inside its band" % float(m["free_ratio"]))
	Assert.is_true(bool(m["free_ratio_ok"]), "L6 free_ratio_ok reported")
	Assert.equals(int(m["same_layer_overlaps"]), 0, "L6 has no same-layer overlap")
	# Rendered scale is clamped to MIN_CARD_SCALE in the renderer; the metrics
	# expose the pre-clamp value as an explicit diagnostic.
	Assert.is_true(m.has("min_card_px_portrait") and m.has("min_card_px_landscape") and m.has("fits_portrait") and m.has("fits_landscape"),
		"L6 scale diagnostics explicit (min_card_px_*, fits_*)")
