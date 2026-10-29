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

# ---------------------------------------------------------------------------
# Legacy scatter layouts for hand-written `layout` JSON levels (no shipped level
# uses one) and their tests. Every shipped Level and Endless round is built by
# BoardPipeline through LevelBoardGenerator instead; do not use this for them.
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