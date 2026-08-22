class_name LayoutGenerator
extends RefCounted

const CARD := 48.0
const PITCH_MIN_RATIO := 0.84
const PITCH_MAX_RATIO := 0.88
const DEFAULT_PITCH_RATIO := 0.86
const MAX_LAYER_COVERAGE := 0.75
const NORMAL_UPPER_OFFSET := 12.0
const SLIT_OFFSET_MIN := 3.0
const SLIT_OFFSET_MAX := 6.0

const COVERAGE_EPSILON := 0.001

# ---------------------------------------------------------------------------
# Legacy entry point. Kept byte-compatible so existing callers and tests keep
# working; new parametric levels go through generate_level().
# ---------------------------------------------------------------------------
static func generate(types: Array, count: int, params: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(params.get("seed", 1))
	var layers := maxi(1, int(params.get("layers", 2)))
	var width := float(params.get("width", 240))
	var height := float(params.get("height", 200))
	var card := float(params.get("card_size", CARD))
	var ratio := clampf(float(params.get("grid_pitch_ratio", DEFAULT_PITCH_RATIO)), PITCH_MIN_RATIO, PITCH_MAX_RATIO)
	var pitch := maxf(8.0, card * ratio)

	var flat: Array = []
	for t in types:
		for i in count:
			flat.append(str(t))
	_shuffle(flat, rng)

	var cols := maxi(1, floori(maxf(1.0, width - card) / pitch) + 1)
	var rows := maxi(1, floori(maxf(1.0, height - card) / pitch) + 1)
	var layer0_cells := _grid_cells(cols, rows, rng)

	var result: Array = []
	var by_layer := {}
	var cell_cursor := 0
	var counter := 0
	for i in flat.size():
		var layer := _layer_for_index(i, flat.size(), layers)
		var pos := Vector2.ZERO
		if layer == 0:
			pos = _take_layer0_cell(layer0_cells, cell_cursor, pitch, card, width, height)
			cell_cursor += 1
		else:
			pos = _place_upper(rng, by_layer, layer, pitch, card, width, height)
		counter += 1
		result.append({
			"id": "c%d" % counter,
			"type": flat[i],
			"x": int(round(pos.x)),
			"y": int(round(pos.y)),
			"layer": layer,
		})
		if not by_layer.has(layer):
			by_layer[layer] = []
		by_layer[layer].append(Rect2(pos, Vector2(card, card)))
	return result

# ---------------------------------------------------------------------------
# Parametric pipeline (used by LevelConfig / DifficultyProfile).
# Stages: geometry -> slots -> layers -> trios -> distribution ->
#         spatial validation -> blocking (free ratio) -> solvability ->
#         instantiation. Returns {"cards": Array, "metrics": Dictionary, "ok": bool}.
# ---------------------------------------------------------------------------
static func generate_level(config: LevelConfig, board_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var gen := LayoutGenerator.new()
	return gen._run_pipeline(config, board_size)

func _run_pipeline(config: LevelConfig, board_size: Vector2) -> Dictionary:
	var geo := _geometry(config, board_size)
	var best_solvable: Dictionary = {}
	var best_score := INF
	for attempt in config.max_attempts:
		var seed_used := config.seed + attempt
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_used
		var board := _generate_board(config, geo, rng)
		if not board["ok"]:
			continue
		var level_dict := _instantiate_level(config, board["cards"], seed_used)
		if not SolvabilityChecker.is_solvable(level_dict):
			continue
		board["metrics"]["attempts"] = attempt + 1
		board["metrics"]["seed_used"] = seed_used
		board["metrics"]["status"] = "ok"
		board["metrics"]["solvable"] = true
		if bool(board["metrics"].get("free_ratio_ok", false)):
			return {"cards": board["cards"], "metrics": board["metrics"], "ok": true}
		# Solvable but outside the profile's free_ratio band: keep as fallback
		# (never returns an unsolvable board), flagged by free_ratio_ok=false.
		var score: float = absf(float(board["metrics"].get("free_ratio", 0.0)) - config.free_ratio)
		if score < best_score:
			best_score = score
			best_solvable = board
	if not best_solvable.is_empty():
		return {"cards": best_solvable["cards"], "metrics": best_solvable["metrics"], "ok": true}
	push_warning("difficulty %d: no solvable board within %d attempts" % [config.difficulty, config.max_attempts])
	return {"cards": [], "metrics": {"status": "failed", "attempts": config.max_attempts, "difficulty": config.difficulty}, "ok": false}

func _generate_board(config: LevelConfig, geo: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	# trios stage: type multiset where every type count is a multiple of 3.
	var multiset := _trio_multiset(config, rng)
	# layers stage: split the shuffled multiset across stacked layers.
	var counts := _layer_counts(config, multiset.size())
	var layer_types := _split_layers(multiset, counts)
	var best: Dictionary = {}
	var best_score := INF
	for tune in 7:
		var delta := float(tune - 3) * 0.03
		var oh := clampf(config.effective_overlap_h() + delta, config.OVERLAP_H_MIN, config.OVERLAP_H_MAX)
		var ov := clampf(config.effective_overlap_v() + delta * 0.8, config.OVERLAP_V_MIN, config.OVERLAP_V_MAX)
		# distribution + spatial placement stage.
		var cards := _place_cards(config, geo, layer_types, rng, oh, ov)
		var stats := _spatial_validation(geo, cards, config)
		if not bool(stats["bounds_ok"]) or int(stats["free_count"]) < 1:
			continue
		var coverage_ok: bool = float(stats["max_coverage"]) <= MAX_LAYER_COVERAGE + COVERAGE_EPSILON
		if not coverage_ok or not bool(stats["same_layer_ok"]) or float(stats["min_exposure"]) < 0.10:
			continue
		var metrics := _stats_metrics(config, stats, oh, ov)
		var free_ok: bool = float(stats["free_ratio"]) >= config.free_ratio_min and float(stats["free_ratio"]) <= config.free_ratio_max
		metrics["free_ratio_ok"] = free_ok
		var score: float = absf(float(stats["free_ratio"]) - config.free_ratio) + float(stats["max_coverage"])
		if not free_ok:
			score += 2.0
		if score < best_score:
			best_score = score
			best = {"cards": cards, "metrics": metrics, "ok": true}
	if best.is_empty():
		return {"ok": false}
	return best

func _geometry(config: LevelConfig, board_size: Vector2) -> Dictionary:
	# geometry + slots stages: derive the board rectangle and slot grid.
	# Positions are generated in LOGICAL space (config board dims). The
	# board_size argument is intentionally NOT used to reduce positions: the
	# renderer (BoardLayout / level_screen._board_layout) is the single source
	# of scale. Scaling here would break the pitch/spacing that blocking and
	# overlap were planned with, and re-scaling the scaled positions collapses
	# distinct slots onto the same cell.
	var width := config.board_width()
	var height := config.board_height()
	var sc := config.slot_columns()
	var sr := config.slot_rows()
	var pitch_x := config.slot_pitch_x()
	var pitch_y := config.slot_pitch_y()
	var grid_w := float(maxi(0, sc - 1)) * pitch_x + config.card_size
	var grid_h := float(maxi(0, sr - 1)) * pitch_y + config.card_size
	var x_start := maxf(0.0, (width - grid_w) / 2.0)
	var y_start := maxf(0.0, (height - grid_h) / 2.0)
	var slots: Array = []
	for r in sr:
		for c in sc:
			slots.append(Vector2(x_start + c * pitch_x, y_start + r * pitch_y))
	return {
		"slots": slots,
		"pitch_x": pitch_x,
		"pitch_y": pitch_y,
		"slot_columns": sc,
		"slot_rows": sr,
		"width": width,
		"height": height,
		"card_size": config.card_size,
	}

func _trio_multiset(config: LevelConfig, rng: RandomNumberGenerator) -> Array:
	var flat: Array = []
	for t in config.board_types:
		for i in config.count_per_type:
			flat.append(t)
	_shuffle(flat, rng)
	return flat

func _layer_counts(config: LevelConfig, n: int) -> Array:
	var L := config.layers
	if L <= 1:
		return [n]
	var weights: Array = []
	var total := 0.0
	for l in L:
		var w := 1.0 / pow(1.6, l)
		weights.append(w)
		total += w
	var counts: Array = []
	var remaining := n
	for l in L:
		if l == L - 1:
			counts.append(remaining)
		else:
			var c := roundi(n * weights[l] / total)
			c = clampi(c, 1, remaining - (L - 1 - l))
			counts.append(c)
			remaining -= c
	return counts

func _split_layers(multiset: Array, counts: Array) -> Array:
	var layers: Array = []
	var idx := 0
	for c in counts:
		layers.append(multiset.slice(idx, idx + int(c)))
		idx += int(c)
	return layers

func _place_cards(config: LevelConfig, geo: Dictionary, layer_types: Array, rng: RandomNumberGenerator, overlap_h: float, overlap_v: float) -> Array:
	var card := config.card_size
	# Bidimensional, limited offset: dx covers H fraction of the lower card,
	# dy covers V fraction (Lumen: H 35-60%, V 35-55%).
	var dx := card * (1.0 - clampf(overlap_h, 0.1, 0.9))
	var dy := card * (1.0 - clampf(overlap_v, 0.1, 0.9))
	var cap := MAX_LAYER_COVERAGE + COVERAGE_EPSILON
	var min_same := config.min_same_layer_distance()
	var cards: Array = []
	var layer_positions := {}
	var lower_rects: Array = []
	var counter := 0
	var layer0_slots: Array = _spread_layer0(geo, rng)
	for layer in layer_types.size():
		var types: Array = layer_types[layer]
		var rects: Array = []
		var same_layer_positions: Array = []
		if layer == 0:
			for i in types.size():
				var pos: Vector2 = layer0_slots[i % layer0_slots.size()]
				counter += 1
				cards.append(_card(counter, str(types[i]), pos, 0))
				same_layer_positions.append(pos)
				rects.append(Rect2(pos, Vector2(card, card)))
		else:
			var bases: Array = layer_positions[layer - 1]
			var base_order := _range(bases.size())
			_shuffle(base_order, rng)
			for i in types.size():
				var base: Vector2 = bases[base_order[i % base_order.size()]]
				var pos := _offset_with_constraints(rng, base, dx, dy, geo, lower_rects, same_layer_positions, cap, min_same)
				counter += 1
				cards.append(_card(counter, str(types[i]), pos, layer))
				same_layer_positions.append(pos)
				rects.append(Rect2(pos, Vector2(card, card)))
		layer_positions[layer] = same_layer_positions
		lower_rects.append_array(rects)
	return cards

# Ensures the layer-0 cards include the 4 corner slots so the occupied area
# spans the full slot grid (anchors fill occupancy_h x occupancy_v of the board).
func _spread_layer0(geo: Dictionary, rng: RandomNumberGenerator) -> Array:
	var slots: Array = (geo["slots"] as Array).duplicate()
	var sc: int = int(geo["slot_columns"])
	var sr: int = int(geo["slot_rows"])
	var corners: Array = []
	if sc > 0 and sr > 0:
		for idx in [0, sc - 1, (sr - 1) * sc, sc * sr - 1]:
			corners.append(slots[idx])
	_shuffle(slots, rng)
	if corners.size() == 4 and slots.size() >= 4:
		for corner in corners:
			var ci := slots.find(corner)
			if ci >= 4:
				for i in 4:
					if not corners.has(slots[i]):
						var tmp = slots[i]
						slots[i] = slots[ci]
						slots[ci] = tmp
						break
	return slots

func _offset_with_constraints(rng: RandomNumberGenerator, base: Vector2, dx: float, dy: float, geo: Dictionary, lower_rects: Array, same_layer_positions: Array, cap: float, min_same: float) -> Vector2:
	var card: float = geo["card_size"]
	var best := _offset_pos(base, dx, dy, rng, geo)
	var best_score := INF
	for attempt in 12:
		var pos := _offset_pos(base, dx, dy, rng, geo)
		var probe := Rect2(pos, Vector2(card, card))
		var cov := 0.0
		for lr in lower_rects:
			cov = maxf(cov, _overlap_frac(probe, lr, card))
		var dist_ok := true
		for p in same_layer_positions:
			if (pos as Vector2).distance_to(p) < min_same:
				dist_ok = false
				break
		if cov <= cap and dist_ok:
			return pos
		var score: float = maxf(0.0, cov - cap) + (0.0 if dist_ok else 1.0)
		if score < best_score:
			best_score = score
			best = pos
	return best

func _spatial_validation(geo: Dictionary, cards: Array, config: LevelConfig) -> Dictionary:
	var width: float = geo["width"]
	var height: float = geo["height"]
	var card: float = geo["card_size"]
	var min_same := config.min_same_layer_distance()
	var bounds_ok := true
	var max_coverage := 0.0
	var min_exposure := 1.0
	var blocked := 0
	for c in cards:
		if float(c["x"]) < 0.0 or float(c["x"]) + card > width + 0.01:
			bounds_ok = false
		if float(c["y"]) < 0.0 or float(c["y"]) + card > height + 0.01:
			bounds_ok = false
		var rect := Rect2(Vector2(c["x"], c["y"]), Vector2(card, card))
		var covering: Array = []
		var cov := 0.0
		var is_blocked := false
		for o in cards:
			if int(o["layer"]) <= int(c["layer"]):
				continue
			var orect := Rect2(Vector2(o["x"], o["y"]), Vector2(card, card))
			if rect.intersects(orect):
				is_blocked = true
				covering.append(orect)
			cov = maxf(cov, _overlap_frac(rect, orect, card))
		if cov > max_coverage:
			max_coverage = cov
		if is_blocked:
			blocked += 1
		min_exposure = minf(min_exposure, 1.0 - _union_coverage(rect, covering, 8))
	# intra-layer collapse guard: same-layer cards keep >= 0.35*card spacing.
	var same_layer_ok := true
	var by_layer := {}
	for c in cards:
		var layer := int(c["layer"])
		if not by_layer.has(layer):
			by_layer[layer] = []
		by_layer[layer].append(Vector2(c["x"], c["y"]))
	for layer in by_layer:
		var pts: Array = by_layer[layer]
		for i in pts.size():
			for j in range(i + 1, pts.size()):
				if (pts[i] as Vector2).distance_to(pts[j]) < min_same - 0.01:
					same_layer_ok = false
	var occ := _anchor_occupancy(geo, cards)
	var total := cards.size()
	var free := total - blocked
	return {
		"bounds_ok": bounds_ok,
		"same_layer_ok": same_layer_ok,
		"max_coverage": max_coverage,
		"min_exposure": min_exposure,
		"free_count": free,
		"blocked_count": blocked,
		"total": total,
		"free_ratio": float(free) / float(total) if total > 0 else 0.0,
		"anchor_occupancy_h": occ["h"],
		"anchor_occupancy_v": occ["v"],
	}

func _anchor_occupancy(geo: Dictionary, cards: Array) -> Dictionary:
	var card: float = geo["card_size"]
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	var found := false
	for c in cards:
		if int(c["layer"]) != 0:
			continue
		found = true
		minx = minf(minx, float(c["x"]))
		maxx = maxf(maxx, float(c["x"]))
		miny = minf(miny, float(c["y"]))
		maxy = maxf(maxy, float(c["y"]))
	if not found:
		return {"h": 0.0, "v": 0.0}
	return {
		"h": (maxx - minx + card) / geo["width"],
		"v": (maxy - miny + card) / geo["height"],
	}

func _union_coverage(rect: Rect2, covering: Array, samples: int) -> float:
	if covering.is_empty():
		return 0.0
	var card := rect.size.x
	var covered := 0
	for ix in samples:
		for iy in samples:
			var p := rect.position + Vector2((float(ix) + 0.5) / float(samples) * card, (float(iy) + 0.5) / float(samples) * card)
			for r in covering:
				if r.has_point(p):
					covered += 1
					break
	return float(covered) / float(samples * samples)

func _instantiate_level(config: LevelConfig, cards: Array, seed: int) -> Dictionary:
	var pool := config.deck_types.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_shuffle(pool, rng)
	var half := int(ceil(pool.size() / 2.0))
	return {
		"id": "generated",
		"clearing_capacity": 7,
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
		"cards": cards,
		"deck_a": pool.slice(0, half),
		"deck_b": pool.slice(half),
	}

func _stats_metrics(config: LevelConfig, stats: Dictionary, overlap_h: float, overlap_v: float) -> Dictionary:
	var m := config.metrics()
	m["overlap"] = (overlap_h + overlap_v) / 2.0
	m["overlap_h"] = overlap_h
	m["overlap_v"] = overlap_v
	m["free_ratio"] = stats["free_ratio"]
	m["free_ratio_target"] = config.free_ratio
	m["free_ratio_min"] = config.free_ratio_min
	m["free_ratio_max"] = config.free_ratio_max
	m["free_cards"] = stats["free_count"]
	m["blocked_cards"] = stats["blocked_count"]
	m["max_coverage"] = stats["max_coverage"]
	m["min_exposure"] = stats["min_exposure"]
	m["anchor_occupancy_h"] = stats["anchor_occupancy_h"]
	m["anchor_occupancy_v"] = stats["anchor_occupancy_v"]
	return m

func _card(id: int, type: String, pos: Vector2, layer: int) -> Dictionary:
	return {"id": "c%d" % id, "type": type, "x": int(round(pos.x)), "y": int(round(pos.y)), "layer": layer}

func _layer_pos(dict: Dictionary, layer: int, pos: Vector2) -> void:
	if not dict.has(layer):
		dict[layer] = []
	dict[layer].append(pos)

func _range(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(i)
	return out

func _offset_pos(base: Vector2, dx: float, dy: float, rng: RandomNumberGenerator, geo: Dictionary) -> Vector2:
	var axis := rng.randi() % 2
	var dir := 1.0 if rng.randi() % 2 == 0 else -1.0
	var delta := Vector2.ZERO
	if axis == 0:
		delta.x = dir * dx
	else:
		delta.y = dir * dy
	var pos := base + delta
	return _clamp_to_bounds(pos, geo["card_size"], geo["width"], geo["height"])

static func _take_layer0_cell(cells: Array, cursor: int, pitch: float, card: float, width: float, height: float) -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	var cell: Vector2i = cells[cursor % cells.size()]
	return _cell_pos(cell, pitch, card, width, height)

static func _grid_cells(cols: int, rows: int, rng: RandomNumberGenerator) -> Array:
	var cells: Array = []
	for r in rows:
		for c in cols:
			cells.append(Vector2i(c, r))
	_shuffle(cells, rng)
	return cells

static func _cell_pos(cell: Vector2i, pitch: float, card: float, width: float, height: float) -> Vector2:
	return Vector2(
		clampf(cell.x * pitch, 0, maxf(0, width - card)),
		clampf(cell.y * pitch, 0, maxf(0, height - card))
	)

static func _place_upper(rng: RandomNumberGenerator, by_layer: Dictionary, layer: int, pitch: float, card: float, width: float, height: float) -> Vector2:
	var lower: Array = []
	for l in layer:
		lower.append_array(by_layer.get(l, []))
	if lower.is_empty():
		return _cell_pos(Vector2i(0, 0), pitch, card, width, height)
	var best := _cell_pos(Vector2i(0, 0), pitch, card, width, height)
	var best_coverage := INF
	for attempt in 16:
		var anchor: Rect2 = lower[rng.randi_range(0, lower.size() - 1)]
		var pos := _clamp_to_bounds(anchor.position + _upper_offset(rng), card, width, height)
		var cov := _max_coverage(Rect2(pos, Vector2(card, card)), lower, card)
		if cov <= MAX_LAYER_COVERAGE:
			return pos
		if cov < best_coverage:
			best_coverage = cov
			best = pos
	return best

static func _upper_offset(rng: RandomNumberGenerator) -> Vector2:
	var axis := rng.randi() % 2
	var sign := 1.0 if rng.randi() % 2 == 0 else -1.0
	var mag := NORMAL_UPPER_OFFSET
	if rng.randf() < 0.3:
		mag = NORMAL_UPPER_OFFSET + rng.randf_range(SLIT_OFFSET_MIN, SLIT_OFFSET_MAX)
	var delta := Vector2.ZERO
	if axis == 0:
		delta.x = sign * mag
	else:
		delta.y = sign * mag
	return delta

static func _max_coverage(probe: Rect2, rects: Array, card: float) -> float:
	var worst := 0.0
	for r in rects:
		worst = maxf(worst, _overlap_frac(probe, r, card))
	return worst

static func _overlap_frac(a: Rect2, b: Rect2, card: float) -> float:
	var ix := maxf(0.0, minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x))
	var iy := maxf(0.0, minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y))
	return (ix * iy) / maxf(1.0, card * card)

static func _clamp_to_bounds(pos: Vector2, card: float, width: float, height: float) -> Vector2:
	return Vector2(
		clampf(pos.x, 0, maxf(0, width - card)),
		clampf(pos.y, 0, maxf(0, height - card))
	)

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _layer_for_index(index: int, n: int, layers: int) -> int:
	if layers <= 1:
		return 0
	var weights: Array = []
	var total := 0.0
	for l in layers:
		var w := 1.0 / pow(1.6, l)
		weights.append(w)
		total += w
	var acc := 0.0
	for l in layers:
		acc += weights[l] / total
		if index < int(n * acc):
			return l
	return layers - 1