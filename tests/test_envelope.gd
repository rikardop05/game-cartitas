extends RefCounted

const PORTRAIT_AVAIL := Vector2(256.0, 195.0)
const LANDSCAPE_AVAIL := Vector2(540.0, 114.0)
const MIN_EFFECTIVE_PITCH := 20.0
const MAX_SLOT_COLS := 7
const MAX_SLOT_ROWS := 6
const MAX_LAYERS := 4
const MAX_BOARD_CARDS := 36

func _envelope(cfg: LevelConfig, avail: Vector2) -> Dictionary:
	var pitch := cfg.pitch()
	var slot_cols := cfg.slot_columns()
	var slot_rows := cfg.slot_rows()
	var total_x := float(maxi(0, slot_cols - 1)) * pitch + cfg.card_size
	var total_y := float(maxi(0, slot_rows - 1)) * pitch + cfg.card_size
	var scale := minf(avail.x / total_x, avail.y / total_y)
	scale = clampf(scale, 0.01, 2.5)
	var effective_pitch := pitch * scale
	var reasons: Array[String] = []
	if effective_pitch < MIN_EFFECTIVE_PITCH:
		reasons.append("effective pitch %.1fpx below minimum %.1fpx" % [effective_pitch, MIN_EFFECTIVE_PITCH])
	if slot_cols > MAX_SLOT_COLS or slot_rows > MAX_SLOT_ROWS:
		reasons.append("slot grid %dx%d exceeds envelope %dx%d" % [slot_cols, slot_rows, MAX_SLOT_COLS, MAX_SLOT_ROWS])
	if cfg.layers > MAX_LAYERS:
		reasons.append("layers %d exceed envelope %d" % [cfg.layers, MAX_LAYERS])
	if cfg.board_cards() > MAX_BOARD_CARDS:
		reasons.append("board cards %d exceed envelope %d" % [cfg.board_cards(), MAX_BOARD_CARDS])
	return {
		"ok": reasons.is_empty(),
		"reasons": reasons,
		"pitch": pitch,
		"scale": scale,
		"effective_pitch": effective_pitch,
		"slot_cols": slot_cols,
		"slot_rows": slot_rows,
		"layers": cfg.layers,
		"board_cards": cfg.board_cards(),
	}

func _seeded_split(pool: Array, seed: int) -> Dictionary:
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

func _level_from_generate(cfg: LevelConfig, cards: Array, seed: int) -> Dictionary:
	var split := _seeded_split(cfg.deck_types.duplicate(), seed)
	return {
		"id": str(cfg.difficulty),
		"clearing_capacity": 7,
		"cards": cards,
		"deck_a": split["deck_a"],
		"deck_b": split["deck_b"],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
	}

func test_envelope_metrics_per_orientation() -> void:
	print("ENVELOPE REPORT (portrait avail %s, landscape avail %s, min pitch %.0fpx)" % [str(PORTRAIT_AVAIL), str(LANDSCAPE_AVAIL), MIN_EFFECTIVE_PITCH])
	print("id | portrait: slots  pitch(px)  ok | landscape: slots  pitch(px)  ok")
	for id in range(1, DifficultyProfile.max_level() + 1):
		var cfg := DifficultyProfile.for_level(id)
		var p := _envelope(cfg, PORTRAIT_AVAIL)
		var l := _envelope(cfg, LANDSCAPE_AVAIL)
		print("%2d | %2dx%d    %6.1f     %s | %2dx%d    %6.1f     %s" % [
			id, p["slot_cols"], p["slot_rows"], p["effective_pitch"], "OK" if p["ok"] else "REJECT",
			l["slot_cols"], l["slot_rows"], l["effective_pitch"], "OK" if l["ok"] else "REJECT",
		])
		Assert.is_true(p["ok"], "level %d fits portrait envelope" % id)
		if not l["ok"]:
			print("  landscape reject reasons: %s" % ", ".join(l["reasons"]))
	Assert.is_true(_envelope(DifficultyProfile.for_level(DifficultyProfile.max_level()), LANDSCAPE_AVAIL)["effective_pitch"] < MIN_EFFECTIVE_PITCH,
		"last level landscape pitch drops below the minimum (double-compression guard)")
	Assert.is_true(_envelope(DifficultyProfile.for_level(1), LANDSCAPE_AVAIL)["ok"],
		"L1 landscape stays inside the envelope")

func test_envelope_rejects_out_of_envelope_with_diagnostics() -> void:
	var base := DifficultyProfile.for_level(1)
	# within-envelope baseline passes
	Assert.is_true(_envelope(base, PORTRAIT_AVAIL)["ok"], "baseline L1 passes portrait")
	# oversized slot grid
	var big := LevelConfig.create({
		"difficulty": 11, "board_types": ["cat", "dog", "bird"], "count_per_type": 3,
		"columns": 10, "rows": 8, "occupancy_h": 0.9, "occupancy_v": 0.9, "layers": 2, "seed": 1,
	})
	var b := _envelope(big, PORTRAIT_AVAIL)
	Assert.is_false(b["ok"], "oversized slot grid rejected")
	Assert.is_true(_reasons_mention(b["reasons"], "slot grid"), "diagnostic names the slot grid")
	# too many layers
	var deep := LevelConfig.create({
		"difficulty": 11, "board_types": ["cat", "dog", "bird"], "count_per_type": 3,
		"columns": 5, "rows": 5, "occupancy_h": 0.6, "occupancy_v": 0.6, "layers": 6, "seed": 1,
	})
	var d := _envelope(deep, PORTRAIT_AVAIL)
	Assert.is_false(d["ok"], "deep stack rejected")
	Assert.is_true(_reasons_mention(d["reasons"], "layers"), "diagnostic names layers")
	# too many board cards
	var tall := LevelConfig.create({
		"difficulty": 11, "board_types": ["cat", "dog", "bird", "fish", "flower", "moon", "star", "sun", "leaf", "heart", "gem", "crystal", "leaf"],
		"count_per_type": 3, "columns": 9, "rows": 7, "occupancy_h": 0.78, "occupancy_v": 0.86,
		"layers": 4, "seed": 1,
	})
	var t := _envelope(tall, PORTRAIT_AVAIL)
	Assert.is_false(t["ok"], "39 board cards rejected")
	Assert.is_true(_reasons_mention(t["reasons"], "board cards"), "diagnostic names board cards")
	# landscape pitch rejection (L10 slots in landscape)
	var l10 := _envelope(DifficultyProfile.for_level(DifficultyProfile.max_level()), LANDSCAPE_AVAIL)
	Assert.is_false(l10["ok"], "L10 rejected in landscape")
	Assert.is_true(_reasons_mention(l10["reasons"], "pitch"), "diagnostic names effective pitch")

func _reasons_mention(reasons: Array[String], needle: String) -> bool:
	for r in reasons:
		if r.contains(needle):
			return true
	return false

func test_same_seed_reproduces_board_and_decks() -> void:
	for id in range(1, 11):
		var a := LevelLoader.load_level(id)
		var b := LevelLoader.load_level(id)
		Assert.is_false(a.has("error"), "level %d loads" % id)
		Assert.equals(_cards_sig(a), _cards_sig(b), "level %d same seed -> same board" % id)
		Assert.equals(str(a["deck_a"]), str(b["deck_a"]), "level %d same seed -> same deck_a" % id)
		Assert.equals(str(a["deck_b"]), str(b["deck_b"]), "level %d same seed -> same deck_b" % id)

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
		"count_per_type": 3, "columns": 8, "rows": 6, "occupancy_h": 0.78, "occupancy_v": 0.8,
		"layers": 4, "overlap": 0.62, "free_ratio": 0.35, "seed": 11001, "max_attempts": 80,
	})
	Assert.is_true(cfg.validate()["valid"], "safe config validates")
	cfg.with_deck(["cat", "cat", "cat", "dog", "dog", "dog", "bird", "bird", "bird"])
	Assert.is_true(cfg.validate()["valid"], "safe config with deck validates")
	Assert.is_true(_envelope(cfg, PORTRAIT_AVAIL)["ok"], "safe config fits portrait envelope")
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

func _errors_mention(errors: Array[String], needle: String) -> bool:
	for e in errors:
		if e.contains(needle):
			return true
	return false

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