class_name LevelBoardGenerator
extends RefCounted

# Generator for the board of every parametric Level and Endless round: maps a
# LevelConfig (DifficultyProfile row) to a BoardSpec, builds the board with
# BoardPipeline (full-card base, upper layers scattered on a quarter-card lattice,
# pyramidal counts, one shared blocking rule) and keeps the
# fairness guarantees on top:
#  - every returned board is solvable WITH the level's Support Decks and a power
#    stock (SolvabilityChecker); an unsolvable board is never returned;
#  - boards whose share of free cards at the start lies inside the profile's
#    [free_ratio_min, free_ratio_max] band are preferred; if none is found within
#    max_attempts, the solvable board closest to free_ratio is returned instead
#    (flagged by free_ratio_ok=false).
# Attempt i uses geometry seed config.seed + i; the symbol seed and the deck
# split derive from that same attempt seed, so one seed reproduces the level.

const SYMBOL_SEED_MIX := 0x2545F491
const SYMBOL_SEED_ADD := 0x1B873593
const CLEARING_CAPACITY := 7

# Returns {"cards", "metrics", "ok", "board_width", "board_height"}. Cards are
# [{id, type, x, y, layer}] on the quarter-card lattice, cropped so the board touches
# (0, 0); board_width/board_height are the occupied size. On failure only
# {"cards": [], "metrics": {...status "failed"}, "ok": false}.
# board_size (the UI's available board area) never changes the geometry, so one
# seed gives the same board in every orientation; it only feeds the fit metrics.
static func generate(config: LevelConfig, board_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var best: Dictionary = {}
	var best_gap := INF
	for attempt in config.max_attempts:
		var seed_used := config.seed + attempt
		var built := BoardPipeline.generate(config.build_spec(seed_used, symbol_seed_for(seed_used)))
		if not built.ok:
			continue
		var board := _export_board(built.cards, config.card_size)
		var cards: Array = board["cards"]
		var free_ratio := float(built.metrics.get("free_cards", 0)) / float(cards.size())
		var in_band := free_ratio >= config.free_ratio_min and free_ratio <= config.free_ratio_max
		var gap := absf(free_ratio - config.free_ratio)
		if not in_band and gap >= best_gap:
			continue
		if not SolvabilityChecker.is_solvable(instantiate_level(config, cards, seed_used)):
			continue
		var result := {
			"cards": cards,
			"metrics": _metrics(config, built.metrics, board, attempt + 1, seed_used, free_ratio, in_band, board_size),
			"ok": true,
			"board_width": float(board["width"]),
			"board_height": float(board["height"]),
		}
		if in_band:
			return result
		# Solvable but outside the free_ratio band: keep as the fallback (never an
		# unsolvable board), flagged by free_ratio_ok=false.
		best = result
		best_gap = gap
	if not best.is_empty():
		return best
	push_warning("difficulty %d: no solvable board within %d attempts" % [config.difficulty, config.max_attempts])
	return {
		"cards": [],
		"metrics": {"status": "failed", "attempts": config.max_attempts, "difficulty": config.difficulty},
		"ok": false,
	}

static func symbol_seed_for(seed_used: int) -> int:
	return (seed_used * SYMBOL_SEED_MIX + SYMBOL_SEED_ADD) & 0x7FFFFFFF

# Deterministic Support Deck split: seeded shuffle of the pool, first half to A.
# Single implementation shared by the solvability check here and LevelLoader.
static func split_decks(pool: Array, seed_used: int) -> Dictionary:
	var shuffled := pool.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_used
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var half := int(ceil(shuffled.size() / 2.0))
	return {"deck_a": shuffled.slice(0, half), "deck_b": shuffled.slice(half)}

static func instantiate_level(config: LevelConfig, cards: Array, seed_used: int) -> Dictionary:
	var decks := split_decks(config.deck_types, seed_used)
	return {
		"id": "generated",
		"clearing_capacity": CLEARING_CAPACITY,
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
		"cards": cards,
		"deck_a": decks["deck_a"],
		"deck_b": decks["deck_b"],
	}

# Pipeline cards -> level cards, shifted so the occupied box starts at (0, 0).
# The shift is a whole number of cards (the base lattice), so the upper layers stay
# on the quarter-card lattice.
static func _export_board(pipeline_cards: Array, card_size: float) -> Dictionary:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for c in pipeline_cards:
		min_x = minf(min_x, float(c["x"]))
		min_y = minf(min_y, float(c["y"]))
		max_x = maxf(max_x, float(c["x"]))
		max_y = maxf(max_y, float(c["y"]))
	var cards: Array = []
	for c in pipeline_cards:
		cards.append({
			"id": str(c["id"]),
			"type": str(c["type"]),
			"x": _plain_number(float(c["x"]) - min_x),
			"y": _plain_number(float(c["y"]) - min_y),
			"layer": int(c["layer"]),
		})
	return {"cards": cards, "width": max_x - min_x + card_size, "height": max_y - min_y + card_size}

static func _plain_number(value: float):
	return int(round(value)) if is_equal_approx(value, round(value)) else value

static func _metrics(config: LevelConfig, pipeline_metrics: Dictionary, board: Dictionary, attempts: int, seed_used: int, free_ratio: float, in_band: bool, board_size: Vector2) -> Dictionary:
	var m := config.metrics()
	var size := Vector2(float(board["width"]), float(board["height"]))
	m["status"] = "ok"
	m["solvable"] = true
	m["generator"] = "board_pipeline"
	m["attempts"] = attempts
	m["seed_used"] = seed_used
	m["geometry_seed_used"] = seed_used
	m["symbol_seed_used"] = symbol_seed_for(seed_used)
	m["pipeline_attempts"] = int(pipeline_metrics.get("attempts", 1))
	m["free_ratio"] = free_ratio
	m["free_ratio_ok"] = in_band
	m["free_cards"] = int(pipeline_metrics.get("free_cards", 0))
	m["blocked_cards"] = int(pipeline_metrics.get("blocked_cards", 0))
	m["free_per_layer"] = pipeline_metrics.get("free_per_layer", [])
	m["run_ratio"] = float(pipeline_metrics.get("run_ratio", 0.0))
	m["longest_run"] = int(pipeline_metrics.get("longest_run", 0))
	m["cards_per_layer"] = pipeline_metrics.get("cards_per_layer", [])
	m["layer_count"] = int(pipeline_metrics.get("layer_count", config.layers))
	m["max_coverage"] = float(pipeline_metrics.get("max_coverage", 0.0))
	m["same_layer_overlaps"] = int(pipeline_metrics.get("same_layer_overlaps", 0))
	m["support_edge_count"] = int(pipeline_metrics.get("support_edge_count", 0))
	m["blocking_edge_count"] = int(pipeline_metrics.get("blocking_edge_count", 0))
	m["occupied_width"] = size.x
	m["occupied_height"] = size.y
	m["base_card_count"] = int(pipeline_metrics.get("base_card_count", 0))
	# The delivered board is the occupied box, so the fit flags describe the real
	# board (not the largest board the profile allows).
	m["min_card_px_portrait"] = config.envelope_card_size(LevelConfig.PORTRAIT_BOARD_ENVELOPE, size)
	m["min_card_px_landscape"] = config.envelope_card_size(LevelConfig.LANDSCAPE_BOARD_ENVELOPE, size)
	m["fits_portrait"] = float(m["min_card_px_portrait"]) >= LevelConfig.MIN_CARD_SIZE_PX
	m["fits_landscape"] = float(m["min_card_px_landscape"]) >= LevelConfig.MIN_CARD_SIZE_PX
	if board_size.x > 0.0 and board_size.y > 0.0:
		m["available_board_size"] = board_size
		m["fit_scale"] = minf(board_size.x / size.x, board_size.y / size.y)
	return m
