extends RefCounted

const SAMPLES_PER_LEVEL := 100

func _deck_pool(id: int) -> Array:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%s.json" % id))
	var pool: Array = []
	for t in raw.get("deck", []):
		pool.append(str(t))
	return pool

func _seeded_deck_split(pool: Array, seed: int) -> Dictionary:
	var p := pool.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(p.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = p[i]
		p[i] = p[j]
		p[j] = tmp
	var half := int(ceil(p.size() / 2.0))
	return {"deck_a": p.slice(0, half), "deck_b": p.slice(half)}

func _level_dict_for(id: String, cards: Array, seed: int) -> Dictionary:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%s.json" % id))
	var split := _seeded_deck_split(_deck_pool(int(id)), seed)
	return {
		"id": id,
		"clearing_capacity": int(raw.get("clearing_capacity", 7)),
		"cards": cards,
		"deck_a": split["deck_a"],
		"deck_b": split["deck_b"],
		"time_thresholds": raw.get("time_thresholds", {"three_stars": 60, "two_stars": 120}),
		"rewards": raw.get("rewards", []),
	}

func _occupation(cfg: LevelConfig, cards_n: int) -> float:
	var area := cfg.board_width() * cfg.board_height()
	return (float(cards_n) * cfg.card_size * cfg.card_size) / area

func _generate_sample(id: int, seed: int) -> Dictionary:
	var cfg := DifficultyProfile.for_level(id)
	cfg.with_deck(_deck_pool(id))
	cfg.seed = seed
	return cfg.generate()

func _fmt_table_row(id: String, cfg: LevelConfig, m: Dictionary, free: int, blocked: int, occ: float) -> String:
	return "%4s | %4d | %4d | %4d | %4d | %4d | %4d | %4d | %6.2f | %6.2f" % [
		id, int(m["board_cards"]), int(m["types"]), int(cfg.columns), int(cfg.rows),
		int(cfg.layers), free, blocked, float(m["free_ratio"]), occ,
	]

func test_progression_table_and_growth() -> void:
	var prev_cards := -1
	var prev_types := -1
	var prev_layers := -1
	var prev_cols := -1
	var prev_rows := -1
	var prev_overlap := -1.0
	print("id   | cards| types| cols | rows | layers| free | blk  | freeR  | occ   ")
	print("-----|------|------|------|------|-------|------|------|--------|-------")
	for id in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(id)
		Assert.is_true(cfg != null, "level %d has a difficulty profile" % id)
		var result := _generate_sample(id, cfg.seed)
		Assert.is_true(result["ok"], "level %d generated" % id)
		var cards: Array = result["cards"]
		var m: Dictionary = result["metrics"]
		var free := int(m["free_cards"])
		var blocked := int(m["blocked_cards"])
		var occ := _occupation(cfg, cards.size())
		var v := cfg.validate()
		Assert.is_true(v["valid"], "level %d config valid: %s" % [id, str(v["errors"])])
		Assert.equals(cards.size(), cfg.board_cards(), "level %d board card count" % id)
		Assert.equals(cards.size() % 3, 0, "level %d board cards multiple of 3" % id)
		Assert.is_true(free >= 1, "level %d has free cards" % id)
		Assert.is_true(blocked >= 1, "level %d has blocked cards (depth)" % id)
		Assert.is_true(occ <= 1.0, "level %d density without compression (occ %.2f)" % [id, occ])
		Assert.is_true(float(m["max_coverage"]) <= LayoutGenerator.MAX_LAYER_COVERAGE + 0.1,
			"level %d max coverage %.2f <= cap" % [id, float(m["max_coverage"])])
		for c in cards:
			Assert.is_true(float(c["x"]) >= 0 and float(c["x"]) + cfg.card_size <= cfg.board_width() + 0.01,
				"level %d x in bounds" % id)
			Assert.is_true(float(c["y"]) >= 0 and float(c["y"]) + cfg.card_size <= cfg.board_height() + 0.01,
				"level %d y in bounds" % id)
		Assert.is_true(cfg.columns >= prev_cols, "level %d columns grow" % id)
		Assert.is_true(cfg.rows >= prev_rows, "level %d rows grow" % id)
		Assert.is_true(int(m["board_cards"]) >= prev_cards, "level %d cards grow" % id)
		Assert.is_true(int(m["types"]) >= prev_types, "level %d unique types grow" % id)
		Assert.is_true(cfg.layers >= prev_layers, "level %d layers grow" % id)
		Assert.is_true(cfg.overlap >= prev_overlap, "level %d overlap grows" % id)
		prev_cards = int(m["board_cards"])
		prev_types = int(m["types"])
		prev_layers = cfg.layers
		prev_cols = cfg.columns
		prev_rows = cfg.rows
		prev_overlap = cfg.overlap
		print(_fmt_table_row(str(id), cfg, m, free, blocked, occ))
	Assert.equals(cfg_count(), DifficultyProfile.max_level(), "exactly %d parametric difficulty profiles" % DifficultyProfile.max_level())

func cfg_count() -> int:
	return DifficultyProfile.max_level()

func test_statistical_layouts_100_per_level() -> void:
	print("STATS (min / mean / max over %d samples per level)" % SAMPLES_PER_LEVEL)
	print("id   |       free      |     blocked     |  occupation    |  cards  ")
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
		var min_occ := 1e9
		var max_occ := -1.0
		var sum_occ := 0.0
		var min_cards := 999999
		var max_cards := -1
		var invalid := 0
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
			var occ := _occupation(cfg, cards_n)
			min_free = mini(min_free, free)
			max_free = maxi(max_free, free)
			sum_free += float(free)
			min_blocked = mini(min_blocked, blocked)
			max_blocked = maxi(max_blocked, blocked)
			sum_blocked += float(blocked)
			min_occ = minf(min_occ, occ)
			max_occ = maxf(max_occ, occ)
			sum_occ += occ
			min_cards = mini(min_cards, cards_n)
			max_cards = maxi(max_cards, cards_n)
			if cards_n != cfg.board_cards() or cards_n % 3 != 0 or free < 1:
				invalid += 1
		total_invalid += invalid
		print("%4s | %3d/%5.1f/%3d | %3d/%5.1f/%3d | %.2f/%.2f/%.2f | %3d/%3d" % [
			id, min_free, sum_free / float(SAMPLES_PER_LEVEL), max_free,
			min_blocked, sum_blocked / float(SAMPLES_PER_LEVEL), max_blocked,
			min_occ, sum_occ / float(SAMPLES_PER_LEVEL), max_occ,
			min_cards, max_cards,
		])
		Assert.equals(invalid, 0, "level %d: 0 invalid layouts (got %d)" % [id, invalid])
		Assert.is_true(min_free >= 1, "level %d: min free >= 1" % id)
		Assert.is_true(max_occ <= 1.0, "level %d: max occupation <= 1.0" % id)
		Assert.equals(max_cards, min_cards, "level %d: card count constant across layouts" % id)
	Assert.equals(total_samples, DifficultyProfile.max_level() * SAMPLES_PER_LEVEL, "total samples == %d" % [DifficultyProfile.max_level() * SAMPLES_PER_LEVEL])
	Assert.equals(total_invalid, 0, "no invalid layouts across all levels")

func test_solvability_statistical_100_per_level() -> void:
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

func _logical_unique_per_layer(cards: Array) -> int:
	var by_layer := {}
	for c in cards:
		var layer := int(c["layer"])
		if not by_layer.has(layer):
			by_layer[layer] = []
		var p := Vector2(float(c["x"]), float(c["y"]))
		var dup := false
		for q in by_layer[layer]:
			if (q as Vector2).distance_to(p) < 0.5:
				dup = true
				break
		if not dup:
			by_layer[layer].append(p)
	var total := 0
	for layer in by_layer:
		total += (by_layer[layer] as Array).size()
	return total

func _logical_oob(cards: Array, cfg: LevelConfig) -> int:
	var n := 0
	for c in cards:
		if float(c["x"]) < 0.0 or float(c["x"]) + cfg.card_size > cfg.board_width() + 0.01:
			n += 1
		elif float(c["y"]) < 0.0 or float(c["y"]) + cfg.card_size > cfg.board_height() + 0.01:
			n += 1
	return n

func test_statistical_visual_metrics_100_per_level() -> void:
	print("VISUAL METRICS min/mean/max over %d samples per level (scale = min_card_px / card_size)" % SAMPLES_PER_LEVEL)
	print("id | scaleP | scaleL | occH | occV | freeR | ovlH | ovlV | layers | uniq | oob | gen_ms")
	for id in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(id)
		var mn := {}
		var mx := {}
		var sum := {}
		var keys := ["scale_p", "scale_l", "occ_h", "occ_v", "free_r", "ovl_h", "ovl_v", "layers", "uniq", "oob", "ms"]
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
			var cards: Array = result["cards"]
			var vals := {
				"scale_p": float(m["min_card_px_portrait"]) / cfg.card_size,
				"scale_l": float(m["min_card_px_landscape"]) / cfg.card_size,
				"occ_h": float(m["anchor_occupancy_h"]),
				"occ_v": float(m["anchor_occupancy_v"]),
				"free_r": float(m["free_ratio"]),
				"ovl_h": float(m["overlap_h"]),
				"ovl_v": float(m["overlap_v"]),
				"layers": float(m["layers"]),
				"uniq": float(_logical_unique_per_layer(cards)),
				"oob": float(_logical_oob(cards, cfg)),
				"ms": dt,
			}
			for k in keys:
				mn[k] = minf(mn[k], vals[k])
				mx[k] = maxf(mx[k], vals[k])
				sum[k] += vals[k]
			Assert.equals(int(vals["oob"]), 0, "level %d: no card out of bounds" % id)
			Assert.equals(int(vals["uniq"]), cards.size(), "level %d: logical unique positions == cards (no logical collapse)" % id)
		var avg := {}
		for k in keys:
			avg[k] = sum[k] / float(maxi(1, samples))
		print("%2d | %.2f/%.2f/%.2f | %.2f/%.2f/%.2f | %.2f/%.2f/%.2f | %.2f/%.2f/%.2f | %.2f/%.2f/%.2f | %.2f/%.2f/%.2f | %.2f/%.2f/%.2f | %.0f/%.0f/%.0f | %.0f/%.0f/%.0f | %.0f/%.0f/%.0f | %.0f/%.0f/%.0f" % [
			id,
			mn["scale_p"], avg["scale_p"], mx["scale_p"],
			mn["scale_l"], avg["scale_l"], mx["scale_l"],
			mn["occ_h"], avg["occ_h"], mx["occ_h"],
			mn["occ_v"], avg["occ_v"], mx["occ_v"],
			mn["free_r"], avg["free_r"], mx["free_r"],
			mn["ovl_h"], avg["ovl_h"], mx["ovl_h"],
			mn["ovl_v"], avg["ovl_v"], mx["ovl_v"],
			mn["layers"], avg["layers"], mx["layers"],
			mn["uniq"], avg["uniq"], mx["uniq"],
			mn["oob"], avg["oob"], mx["oob"],
			mn["ms"], avg["ms"], mx["ms"],
		])
		Assert.equals(failed, 0, "level %d: all %d generations succeeded (got %d)" % [id, SAMPLES_PER_LEVEL, failed])

func test_l6_band_criteria() -> void:
	var cfg := DifficultyProfile.for_level(6)
	Assert.is_true(cfg.occupancy_h >= 0.80, "L6 occupancy H >= 80%% (got %.2f)" % cfg.occupancy_h)
	Assert.is_true(cfg.occupancy_v >= 0.70, "L6 occupancy V >= 70%% (got %.2f)" % cfg.occupancy_v)
	Assert.is_true(cfg.layers >= 3 and cfg.layers <= 4, "L6 3-4 layers (got %d)" % cfg.layers)
	Assert.is_true(cfg.free_ratio >= 0.30 and cfg.free_ratio <= 0.45, "L6 free_ratio target in 30-45%% (got %.2f)" % cfg.free_ratio)
	var result := _generate_sample(6, cfg.seed)
	Assert.is_true(result["ok"], "L6 generates")
	var m: Dictionary = result["metrics"]
	Assert.is_true(float(m["free_ratio"]) >= 0.30 and float(m["free_ratio"]) <= 0.45,
		"L6 measured free_ratio %.2f in 30-45%%" % float(m["free_ratio"]))
	Assert.is_true(bool(m["free_ratio_ok"]), "L6 free_ratio_ok reported")
	Assert.is_true(float(m["overlap_h"]) >= 0.35 and float(m["overlap_h"]) <= 0.60,
		"L6 overlap_h %.2f in 35-60%%" % float(m["overlap_h"]))
	Assert.is_true(float(m["overlap_v"]) >= 0.35 and float(m["overlap_v"]) <= 0.55,
		"L6 overlap_v %.2f in 35-55%%" % float(m["overlap_v"]))
	Assert.is_true(float(m["min_same_layer_distance"]) >= cfg.card_size * 0.35 - 0.01,
		"L6 min same-layer distance %.1f >= 0.35*card" % float(m["min_same_layer_distance"]))
	# Rendered scale is clamped to MIN_CARD_SCALE in the renderer; the metrics
	# expose the pre-clamp value as an explicit diagnostic (salvo diagnóstico).
	Assert.is_true(m.has("min_card_px_portrait") and m.has("min_card_px_landscape") and m.has("fits_portrait") and m.has("fits_landscape"),
		"L6 scale diagnostics explicit (min_card_px_*, fits_*)")