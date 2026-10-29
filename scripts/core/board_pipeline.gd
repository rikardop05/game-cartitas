class_name BoardPipeline
extends RefCounted

# Builds a classic tile-stacking board: the connected base layer (layer 0) fills a
# full-card lattice, and the upper layers are scattered over it on a QUARTER-card
# lattice, like the front cards of a shuffled pile. Every card stores its position in
# quarter-card steps (grid_x / grid_y: base cards sit on multiples of 4), and the
# whole board is validated with the single shared spatial blocking rule
# (BoardSpatialRules), also used by BoardManager at runtime and by LevelValidator.
# BoardSpec -> BoardBuildResult. Decks and solvability stay outside (see
# LevelBoardGenerator); optional symbols are assigned only after geometry and all
# spatial gates have passed.
#
# Layers: target counts shrink geometrically (LAYER_RATIO) so the base holds the
# largest share and each upper layer strictly fewer cards.
#
# Upper layers: candidates are every quarter-card position inside the base footprint
# whose card overlaps at least TWO cards of the layer right below at or above the
# shared spatial threshold (it visibly rests on the pile, never floats) without
# hiding more than 75% of any one of them. Cards of one layer never overlap. A seeded
# greedy scatter then fills the layer: each step takes the cheapest candidate, where
# cost grows with (a) a same-layer card exactly side by side on the same row or
# column (no straight runs) or merely in line with it, (b) crowding by same-layer
# neighbours (blue-noise style repulsion), (c) fractional x / y offsets already used
# by the layer (varied offsets relative to the base grid), (d) the layer's cards
# already in that left/centre/right x top/bottom region (spread over the board) and
# (e) burying lower cards, a stack on cards the layer already covers being cheaper than
# burying fresh ones (fair starts), plus a little seeded noise. A dense layer relaxes
# the spread costs (SCATTER_RELAX) until it fits. A few cards of each big layer are
# reserved: no card above may block them, so no layer starts buried completely. No
# random coordinates.
#
# Acceptance: up to MAX_ATTEMPTS deterministic attempts (attempt salt derived
# from the geometry seed) are grown; a candidate is accepted only when it passes the
# base compactness gates (for layers == 1) and the layer/support/blocking gates, and
# for layered boards the scatter gates (no tidy runs, varied offsets, cards in every
# region, no layer starved of free cards).
# If all attempts are rejected the pipeline fails structurally with
# COMPACTNESS_REJECTED (or BUDGET_EXHAUSTED when growth never completes).

const NEIGHBOR_WEIGHT := 1.5
const ASPECT_WEIGHT := 2.0
const ASPECT_TARGET := 1.6
const CENTER_WEIGHT := 1.0
const JITTER_WEIGHT := 2.5
const BUDGET_FLOOR := 2000
const BUDGET_PER_CARD := 200
const MAX_ATTEMPTS := 64
const ATTEMPT_SALT := 0x9E3779B9
const DENSITY_MIN := 0.55
const ASPECT_MIN := 1.15
const ASPECT_MAX := 2.25
const MAX_HOLE_HALF_CELLS := 4
const BRIDGE_GROUP_MIN := 3
const LAYER_RATIO := 0.5  # each upper layer targets about this fraction of the layer below
const SMALL_BASE_CARDS := 3  # bases this small skip the aspect and bridge shape gates

const QUARTERS := 4  # lattice steps per card edge: grid_x / grid_y count quarter cards
const MAX_HIDDEN_QUARTER_AREA := 12  # of 16: one card hides at most 75% of a card below (LevelValidator.MAX_OVERLAP)
const MIN_SUPPORTS := 2  # lower cards an upper card must overlap at the shared spatial threshold
const SCATTER_ROW_PENALTY := 12.0  # same row / column, exactly side by side
const SCATTER_ALIGN_PENALTY := 3.0  # same row / column within three cards
const SCATTER_ALIGN_REACH := 12  # quarter cards
const SCATTER_DENSITY := 3.0  # crowding by same-layer neighbours ...
const SCATTER_RADIUS := 9  # ... within this many quarter cards
const SCATTER_X_CLASS := 1.5  # per card of the layer already at this fractional x
const SCATTER_Y_CLASS := 1.5  # per card of the layer already at this fractional y
const SCATTER_REGION := 1.2  # per card of the layer already in this region
const SCATTER_NEW_COVER := 6.0  # per lower card newly blocked: keeps cards free at the start
const SCATTER_DOUBLE_COVER := -2.0  # per lower card another card of the layer already blocks (a bonus: stacks close up instead of burying the rest)
const SCATTER_NOISE := 1.5
const SCATTER_RELAX := [1.0, 0.5, 0.2, 0.0]  # spread-cost scale tried in turn until the layer fits
const REGION_COLUMNS := 3
const REGION_ROWS := 2
const RUN_RATIO_MAX := 0.5  # share of upper cards allowed in a straight run (old generator: ~0.95)
const RUN_LONGEST_MAX := 3  # longest chain of cards side by side on one row / column
const RUN_MIN_CARDS := 5  # smaller upper layers are too sparse for the run gates
const VARIETY_MIN_LAYER_CARDS := 5  # a layer this big uses at least 2 distinct fractional x and y offsets ...
const VARIETY_BIG_LAYER_CARDS := 8  # ... and a layer this big at least 3 distinct fractional x and y offsets
const REGION_MIN_LAYER_CARDS := 6  # a layer this big has cards in every horizontal third and both vertical halves
const RESERVE_SHARE := 0.10  # share of a layer's cards kept free of every card above (spread out) ...
const RESERVE_MIN_LAYER_CARDS := 8  # ... for layers of at least this many cards (below the top layer)
const STARVED_FREE_SHARE := 0.07  # such a layer keeps at least this share of its cards free at the start

# Base aspect (width / height) the growth steers toward and the band the base must land in.
# These are the defaults; BoardSpec.aspect_target / aspect_min / aspect_max override them
# (the shipped profiles ask for wide ~2:1 bases, see LevelConfig).
var _aspect_target := ASPECT_TARGET
var _aspect_min := ASPECT_MIN
var _aspect_max := ASPECT_MAX

static func generate(spec: BoardSpec) -> BoardBuildResult:
	var pipeline := BoardPipeline.new()
	return pipeline._generate(spec)

# Cards per layer (base first): strictly decreasing, every layer non-empty, exact
# total. Empty when card_count cannot form that many layers.
static func layer_targets(card_count: int, layers: int, layer_ratio: float = LAYER_RATIO) -> Array:
	if layers < 1:
		return []
	var minimum_layer_cards := layers * (layers + 1) / 2
	if card_count < minimum_layer_cards:
		return []
	if layers == 1:
		return [card_count]
	var weight_sum := 0.0
	for layer in layers:
		weight_sum += pow(layer_ratio, layer)
	var targets: Array[int] = []
	for layer in layers:
		targets.append(roundi(float(card_count) * pow(layer_ratio, layer) / weight_sum))
	# Every layer keeps room for the layers above it, then stays strictly smaller
	# than the layer below; the surplus always returns to the base.
	for i in range(layers):
		targets[i] = maxi(targets[i], layers - i)
	for i in range(1, layers):
		targets[i] = mini(targets[i], targets[i - 1] - 1)
	var total := 0
	for t in targets:
		total += t
	targets[0] += card_count - total
	var valid := true
	var sum := 0
	for i in layers:
		sum += targets[i]
		if targets[i] <= 0 or (i > 0 and targets[i] >= targets[i - 1]):
			valid = false
	if valid and sum == card_count:
		return targets
	# The triangular staircase is the minimum positive, strictly-decreasing
	# distribution. Surplus goes to the base so the exact total is preserved.
	targets.clear()
	for layer in layers:
		targets.append(layers - layer)
	targets[0] += card_count - minimum_layer_cards
	return targets

func _generate(spec: BoardSpec) -> BoardBuildResult:
	var result := BoardBuildResult.new()
	var validation := spec.validate()
	if not validation["valid"]:
		result.error_code = BoardBuildResult.ErrorCode.SPEC_INVALID
		result.error_message = "; ".join(validation["errors"])
		result.metrics = _metrics_from([], spec, spec.card_size / QUARTERS, spec.card_size / QUARTERS, {}, 0)
		return result

	_aspect_target = spec.aspect_target
	_aspect_min = spec.aspect_min
	_aspect_max = spec.aspect_max
	# The base grows on the half-card raster (full-card moves); positions are reported
	# in quarter-card steps.
	var step_x := spec.card_size / 2.0
	var step_y := spec.card_size / 2.0
	var quarter := spec.card_size / QUARTERS
	var cells_x := floori((spec.board_width - spec.card_size) / step_x) + 1
	var cells_y := floori((spec.board_height - spec.card_size) / step_y) + 1
	# Even coordinates keep the base lattice flush with the board's left/top edge,
	# so a board exactly N cards wide really holds N columns.
	var center := Vector2i((cells_x / 2) - ((cells_x / 2) % 2), (cells_y / 2) - ((cells_y / 2) % 2))
	var targets_per_layer := layer_targets(spec.card_count, spec.layers, spec.layer_ratio)

	var attempts := 0
	var rejection_counts := {}
	var best_cards: Array = []
	var best_gates: Dictionary = {}
	var best_score := -INF
	var best_growth_error := ""
	var best_failure_kind := ""  # "build" | "gates"

	for attempt in MAX_ATTEMPTS:
		attempts += 1
		var attempt_seed := spec.geometry_seed ^ (attempt * ATTEMPT_SALT)
		var built := _build_layers(spec, attempt_seed, targets_per_layer, step_x, step_y, cells_x, cells_y, center)
		if not built["ok"]:
			rejection_counts["layers"] = int(rejection_counts.get("layers", 0)) + 1
			if best_cards.is_empty():
				best_cards = built["cards"]
				best_growth_error = built["error"]
				best_failure_kind = "build"
			continue
		var cards: Array = built["cards"]
		var gates := _evaluate_gates_full(cards, spec, quarter, quarter)
		if gates["pass"]:
			_assign_symbols(cards, spec)
			result.ok = true
			result.cards = cards
			result.metrics = _metrics_from(cards, spec, quarter, quarter, gates, attempts, rejection_counts)
			return result
		for reason in gates["rejections"]:
			var key := String(reason)
			rejection_counts[key] = int(rejection_counts.get(key, 0)) + 1
		if float(gates["score"]) > best_score:
			best_score = float(gates["score"])
			best_cards = cards
			best_gates = gates
			best_failure_kind = "gates"

	result.ok = false
	if best_cards.is_empty():
		result.error_code = BoardBuildResult.ErrorCode.BUDGET_EXHAUSTED
		result.error_message = "growth never completed in %d attempts: %s" % [attempts, best_growth_error]
		result.metrics = _metrics_from([], spec, quarter, quarter, {}, attempts, rejection_counts)
	else:
		var is_layer_failure := best_failure_kind == "build"
		if best_failure_kind == "gates":
			for reason in best_gates["rejections"]:
				if String(reason) == "layers" or String(reason) == "unsupported":
					is_layer_failure = true
		var failure_gates := best_gates
		if failure_gates.is_empty() and not best_cards.is_empty():
			var connectivity := _compute_connectivity(best_cards)
			failure_gates = {
				"component_count": int(connectivity["component_count"]),
				"connected_layout": bool(connectivity["connected"]),
			}
		if is_layer_failure:
			result.error_code = BoardBuildResult.ErrorCode.UPPER_LAYER_REJECTED
			result.error_message = "no candidate passed the layer/support gates in %d attempts" % attempts
		else:
			result.error_code = BoardBuildResult.ErrorCode.COMPACTNESS_REJECTED
			result.error_message = "no candidate passed the compactness gates in %d attempts" % attempts
		result.metrics = _metrics_from(best_cards, spec, quarter, quarter, failure_gates, attempts, rejection_counts)
	return result

func _build_layers(spec: BoardSpec, seed: int, layer_targets: Array, step_x: float, step_y: float, cells_x: int, cells_y: int, center: Vector2i) -> Dictionary:
	var base_count := int(layer_targets[0])
	var minimum_layer_cards := spec.layers * (spec.layers + 1) / 2
	var base_growth: Dictionary
	if spec.layers > 1 and spec.card_count == minimum_layer_cards:
		base_growth = _build_minimum_pyramid_base(base_count, step_x, step_y, cells_x, cells_y, center)
	else:
		base_growth = _grow(spec, seed, step_x, step_y, cells_x, cells_y, center, base_count)
	if not base_growth["ok"]:
		return {"ok": false, "cards": [], "error": base_growth["error"]}
	var cards: Array[Dictionary] = []
	cards.assign(base_growth["cards"])
	# The base was grown on the half-card raster; from here on every card counts
	# quarter-card steps (a base card sits on multiples of QUARTERS).
	for c in cards:
		c["grid_x"] = int(c["grid_x"]) * (QUARTERS / 2)
		c["grid_y"] = int(c["grid_y"]) * (QUARTERS / 2)
	var bounds := _footprint(cards)
	var by_layer := {0: cards.duplicate()}
	# Free-card reserve: a few cards of each big layer stay clear of every card above
	# them, spread over the layer, so no layer is buried completely.
	var reserved: Array[Vector2i] = []
	var reserve_layers := not _is_minimum_pyramid(spec)
	if reserve_layers and layer_targets.size() > 1:
		reserved.append_array(_pick_reserved(cards, seed, 0))

	for layer in range(1, layer_targets.size()):
		var target := int(layer_targets[layer])
		if not by_layer.has(layer - 1):
			return {"ok": false, "cards": cards, "error": "missing lower layer %d" % (layer - 1)}
		var placed := _place_upper_layer(by_layer[layer - 1], bounds, layer, target, seed, cards.size(), spec.card_size, reserved)
		if not placed["ok"]:
			return {"ok": false, "cards": cards, "error": "layer %d: %s" % [layer, placed["error"]]}
		by_layer[layer] = placed["cards"]
		for c in placed["cards"]:
			cards.append(c)
		if reserve_layers and layer < layer_targets.size() - 1:
			reserved.append_array(_pick_reserved(placed["cards"], seed, layer))

	if cards.size() != spec.card_count:
		return {"ok": false, "cards": cards, "error": "card count %d != %d" % [cards.size(), spec.card_count]}
	return {"ok": true, "cards": cards, "error": ""}

# Cards of a layer (quarter-card positions) that every card above must leave free:
# RESERVE_SHARE of the layer, chosen by farthest-point sampling from a seeded start so
# they are spread over the layer. Small layers keep none.
func _pick_reserved(layer_cards: Array, seed: int, layer: int) -> Array[Vector2i]:
	var picked: Array[Vector2i] = []
	if layer_cards.size() < RESERVE_MIN_LAYER_CARDS:
		return picked
	var wanted := ceili(RESERVE_SHARE * float(layer_cards.size()))
	var cells: Array[Vector2i] = []
	for c in layer_cards:
		cells.append(Vector2i(int(c["grid_x"]), int(c["grid_y"])))
	var first := 0
	var first_hash := 2.0
	for i in cells.size():
		var h := _hash01(seed ^ (layer * 40503), cells[i].x, cells[i].y)
		if h < first_hash:
			first_hash = h
			first = i
	picked.append(cells[first])
	while picked.size() < wanted:
		var far := -1
		var far_distance := -1.0
		for i in cells.size():
			var nearest := INF
			for p in picked:
				nearest = minf(nearest, Vector2(cells[i] - p).length_squared())
			if nearest > far_distance:
				far_distance = nearest
				far = i
		picked.append(cells[far])
	return picked

# Bounding box of the cards, in quarter-card steps, card extent included.
func _footprint(cards: Array) -> Rect2i:
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-(1 << 30), -(1 << 30))
	for c in cards:
		low.x = mini(low.x, int(c["grid_x"]))
		low.y = mini(low.y, int(c["grid_y"]))
		high.x = maxi(high.x, int(c["grid_x"]) + QUARTERS)
		high.y = maxi(high.y, int(c["grid_y"]) + QUARTERS)
	return Rect2i(low, high - low)

# At the triangular minimum every base card participates in the support
# staircase. A single full-card row is the only same-layer-overlap-free base
# whose adjacent pairs can carry the whole staircase; its elongated aspect is
# intentional, so _generate waives the aspect and bridge gates for it.
func _build_minimum_pyramid_base(count: int, step_x: float, step_y: float, cells_x: int, cells_y: int, center: Vector2i) -> Dictionary:
	var span := (count - 1) * 2
	var origin_x := center.x - (span / 4) * 2
	if origin_x < 0 or origin_x + span >= cells_x or center.y >= cells_y:
		return {"ok": false, "cards": [], "error": "board cannot fit minimum %d-card pyramid base" % count}
	var cards: Array[Dictionary] = []
	for i in count:
		cards.append(_make_card(i, Vector2i(origin_x + 2 * i, center.y), step_x, step_y, 0))
	return {"ok": true, "cards": cards, "error": ""}

# Scatters one upper layer over the lower one (see the header): every quarter-card
# position inside `bounds` that rests on at least MIN_SUPPORTS lower cards is a
# candidate, and a seeded greedy picks the cheapest one `target` times. Scatter
# costs are kept incrementally per candidate (the board has a few hundred of them).
func _place_upper_layer(lower: Array, bounds: Rect2i, layer: int, target: int, seed: int, next_index: int, card_size: float, reserved: Array[Vector2i] = []) -> Dictionary:
	var quarter := card_size / QUARTERS
	var extent := Vector2(card_size, card_size)
	var x0 := bounds.position.x
	var y0 := bounds.position.y
	var ny := bounds.size.y - QUARTERS + 1
	var count := (bounds.size.x - QUARTERS + 1) * ny
	if count <= 0:
		return {"ok": false, "cards": [], "error": "no room for layer %d" % layer}

	# Lower cards overlapping each candidate at the shared spatial threshold.
	var supports: Array = []
	supports.resize(count)
	for i in count:
		supports[i] = []
	var too_hidden := PackedByteArray()
	too_hidden.resize(count)
	for li in lower.size():
		var lx := int(lower[li]["grid_x"])
		var ly := int(lower[li]["grid_y"])
		var lower_rect := Rect2(Vector2(float(lx), float(ly)) * quarter, extent)
		for cx in range(maxi(x0, lx - QUARTERS + 1), mini(x0 + bounds.size.x - QUARTERS, lx + QUARTERS - 1) + 1):
			for cy in range(maxi(y0, ly - QUARTERS + 1), mini(y0 + bounds.size.y - QUARTERS, ly + QUARTERS - 1) + 1):
				var ci := (cx - x0) * ny + (cy - y0)
				if (QUARTERS - absi(cx - lx)) * (QUARTERS - absi(cy - ly)) > MAX_HIDDEN_QUARTER_AREA:
					too_hidden[ci] = 1
					continue
				var upper_rect := Rect2(Vector2(float(cx), float(cy)) * quarter, extent)
				if BoardSpatialRules.at_or_above_threshold(BoardSpatialRules.coverage(upper_rect, lower_rect)):
					(supports[ci] as Array).append(li)

	# Candidates that would block a reserved (kept free) card of any layer below.
	for cell in reserved:
		var reserved_rect := Rect2(Vector2(float(cell.x), float(cell.y)) * quarter, extent)
		for cx in range(maxi(x0, cell.x - QUARTERS + 1), mini(x0 + bounds.size.x - QUARTERS, cell.x + QUARTERS - 1) + 1):
			for cy in range(maxi(y0, cell.y - QUARTERS + 1), mini(y0 + bounds.size.y - QUARTERS, cell.y + QUARTERS - 1) + 1):
				if BoardSpatialRules.blocks(reserved_rect, Rect2(Vector2(float(cx), float(cy)) * quarter, extent)):
					too_hidden[(cx - x0) * ny + (cy - y0)] = 1

	var candidates: Array[int] = []
	var region_of := PackedInt32Array()
	region_of.resize(count)
	var noise := PackedFloat32Array()
	noise.resize(count)
	for ci in count:
		if too_hidden[ci] == 1 or (supports[ci] as Array).size() < MIN_SUPPORTS:
			continue
		candidates.append(ci)
		var cx := x0 + ci / ny
		var cy := y0 + ci % ny
		var rx := clampi((cx * 2 + QUARTERS - x0 * 2) * REGION_COLUMNS / (2 * bounds.size.x), 0, REGION_COLUMNS - 1)
		var ry := clampi((cy * 2 + QUARTERS - y0 * 2) * REGION_ROWS / (2 * bounds.size.y), 0, REGION_ROWS - 1)
		region_of[ci] = ry * REGION_COLUMNS + rx
		noise[ci] = _hash01(seed + layer * 7919, cx, cy) * SCATTER_NOISE

	# A dense layer cannot always keep the full scatter spacing: the spread terms are
	# relaxed step by step until the layer fits (the row / column penalty stays).
	var placed: Array[Dictionary] = []
	for relax in SCATTER_RELAX:
		placed = _scatter_fill(candidates, supports, region_of, noise, lower, bounds, layer, target, next_index, quarter, relax)
		if placed.size() >= target:
			break
	if placed.size() < target:
		return {"ok": false, "cards": placed, "error": "only %d/%d supported positions found" % [placed.size(), target]}
	return {"ok": true, "cards": placed, "error": ""}

# One greedy scatter pass over the candidates (see _place_upper_layer). `relax`
# scales the spacing, alignment, region and offset-variety costs.
func _scatter_fill(candidates: Array[int], supports: Array, region_of: PackedInt32Array, noise: PackedFloat32Array, lower: Array, bounds: Rect2i, layer: int, target: int, next_index: int, quarter: float, relax: float) -> Array[Dictionary]:
	var x0 := bounds.position.x
	var y0 := bounds.position.y
	var nx := bounds.size.x - QUARTERS + 1
	var ny := bounds.size.y - QUARTERS + 1
	var live := candidates.duplicate()
	var penalty := PackedFloat32Array()
	penalty.resize(nx * ny)
	var x_used := PackedInt32Array([0, 0, 0, 0])
	var y_used := PackedInt32Array([0, 0, 0, 0])
	var region_used := PackedInt32Array()
	region_used.resize(REGION_COLUMNS * REGION_ROWS)
	var covered_by := PackedInt32Array()
	covered_by.resize(lower.size())
	var reach := maxi(SCATTER_ALIGN_REACH, SCATTER_RADIUS)
	var placed: Array[Dictionary] = []

	while placed.size() < target and not live.is_empty():
		var best := -1
		var best_cost := INF
		for ci in live:
			var cost := penalty[ci] + noise[ci] 				+ relax * (SCATTER_X_CLASS * x_used[posmod(ci / ny, QUARTERS)] 					+ SCATTER_Y_CLASS * y_used[posmod(ci % ny, QUARTERS)] 					+ SCATTER_REGION * region_used[region_of[ci]])
			for li in supports[ci]:
				cost += SCATTER_NEW_COVER if covered_by[li] == 0 else SCATTER_DOUBLE_COVER
			if cost < best_cost:
				best_cost = cost
				best = ci
		var px := x0 + best / ny
		var py := y0 + best % ny
		var support_ids: Array[String] = []
		for li in supports[best]:
			covered_by[li] += 1
			support_ids.append(str(lower[li]["id"]))
		var card := _make_card(next_index + placed.size(), Vector2i(px, py), quarter, quarter, layer)
		card["support_ids"] = support_ids
		placed.append(card)
		x_used[posmod(px - x0, QUARTERS)] += 1
		y_used[posmod(py - y0, QUARTERS)] += 1
		region_used[region_of[best]] += 1
		# Candidates this card overlaps are gone; the ones near it get costlier.
		var remaining: Array[int] = []
		for ci in live:
			if absi(x0 + ci / ny - px) >= QUARTERS or absi(y0 + ci % ny - py) >= QUARTERS:
				remaining.append(ci)
		live = remaining
		for dx in range(-reach, reach + 1):
			var cx := px + dx
			if cx < x0 or cx >= x0 + nx:
				continue
			for dy in range(-reach, reach + 1):
				var cy := py + dy
				if cy < y0 or cy >= y0 + ny or (absi(dx) < QUARTERS and absi(dy) < QUARTERS):
					continue
				var added := 0.0
				var distance := sqrt(float(dx * dx + dy * dy))
				if distance < SCATTER_RADIUS:
					added += relax * SCATTER_DENSITY * (1.0 - distance / SCATTER_RADIUS)
				if (dy == 0 and absi(dx) == QUARTERS) or (dx == 0 and absi(dy) == QUARTERS):
					added += SCATTER_ROW_PENALTY
				elif (dy == 0 and absi(dx) <= SCATTER_ALIGN_REACH) or (dx == 0 and absi(dy) <= SCATTER_ALIGN_REACH):
					added += relax * SCATTER_ALIGN_PENALTY
				if added > 0.0:
					penalty[(cx - x0) * ny + (cy - y0)] += added
	return placed

# step_x / step_y: one quarter card. The base compactness gates (holes, bridges,
# density, aspect) work on the half-card raster the base grows on, so they get the
# base cards with their coordinates halved.
func _evaluate_gates_full(cards: Array, spec: BoardSpec, step_x: float, step_y: float) -> Dictionary:
	var base_cards: Array = []
	for c in cards:
		if int(c["layer"]) == 0:
			base_cards.append({"grid_x": int(c["grid_x"]) / (QUARTERS / 2), "grid_y": int(c["grid_y"]) / (QUARTERS / 2)})
	var compact := _evaluate_gates(base_cards, spec, step_x * (QUARTERS / 2), step_y * (QUARTERS / 2))
	if _shape_gates_waived(spec):
		var kept: Array[String] = []
		for r in compact["rejections"]:
			if r != "aspect" and r != "narrow_bridge":
				kept.append(r)
		compact["rejections"] = kept
	var spatial := _compute_spatial_metrics(cards, spec, step_x, step_y)
	var connectivity := _compute_connectivity(cards)
	var rejections: Array[String] = []
	for r in compact["rejections"]:
		rejections.append(r)
	if int(spatial["same_layer_overlaps"]) > 0 or (spec.layers > 1 and not bool(spatial["valid_layers"])):
		rejections.append("layers")
	var scatter := _scatter_metrics(cards)
	if spec.layers > 1 and int(scatter["upper_cards"]) >= RUN_MIN_CARDS:
		if float(scatter["run_ratio"]) > RUN_RATIO_MAX or int(scatter["longest_run"]) > RUN_LONGEST_MAX:
			rejections.append("tidy")
	if spec.layers > 1 and bool(scatter["samey"]):
		rejections.append("samey")
	if spec.layers > 1 and bool(scatter["lopsided"]):
		rejections.append("lopsided")
	if spec.layers > 1 and bool(spatial["starved_layer"]) and not _is_minimum_pyramid(spec):
		rejections.append("starved")
	var pass_ := rejections.is_empty()
	var score := float(compact["score"]) if spec.layers <= 1 else (float(spatial["score"]) + float(compact["score"]) * 0.001)
	return {
		"pass": pass_,
		"rejections": rejections,
		"no_large_holes": compact["no_large_holes"],
		"largest_hole_half_cells": compact["largest_hole_half_cells"],
		"hole_count": compact["hole_count"],
		"no_narrow_bridges": compact["no_narrow_bridges"],
		"narrow_bridge_count": compact["narrow_bridge_count"],
		"compact_density": compact["compact_density"],
		"occupied_aspect": compact["occupied_aspect"],
		"valid_layers": spatial["valid_layers"],
		"same_layer_overlaps": spatial["same_layer_overlaps"],
		"max_coverage": spatial["max_coverage"],
		"unsupported_cards": spatial["unsupported_cards"],
		"support_edge_count": spatial["support_edge_count"],
		"blocking_edge_count": spatial["blocking_edge_count"],
		"free_cards": spatial["free_cards"],
		"blocked_cards": spatial["blocked_cards"],
		"free_per_layer": spatial["free_per_layer"],
		"run_ratio": scatter["run_ratio"],
		"longest_run": scatter["longest_run"],
		"layer_count": spatial["layer_count"],
		"cards_per_layer": spatial["cards_per_layer"],
		"component_count": int(connectivity["component_count"]),
		"connected_layout": bool(connectivity["connected"]),
		"score": score,
	}

# Real BFS/DFS connectivity over the full graph: same-layer grid adjacency plus
# support edges (undirected — an upper card rests on its supports). A connected
# board is exactly one component.
func _compute_connectivity(cards: Array) -> Dictionary:
	if cards.is_empty():
		return {"component_count": 0, "connected": false}
	var grid_idx := {}
	var by_id := {}
	for i in cards.size():
		var c = cards[i]
		grid_idx["%d:%d,%d" % [int(c["layer"]), int(c["grid_x"]), int(c["grid_y"])]] = i
		by_id[str(c["id"])] = i
	var adj: Array = []
	adj.resize(cards.size())
	for i in cards.size():
		adj[i] = []
	for i in cards.size():
		var c = cards[i]
		var layer := int(c["layer"])
		var gx := int(c["grid_x"])
		var gy := int(c["grid_y"])
		for delta in _moves_quarter():
			var j: int = grid_idx.get("%d:%d,%d" % [layer, gx + delta.x, gy + delta.y], -1)
			if j >= 0 and j != i:
				(adj[i] as Array).append(j)
		for sid in c.get("support_ids", []):
			if by_id.has(str(sid)):
				var k: int = by_id[str(sid)]
				if not (adj[i] as Array).has(k):
					(adj[i] as Array).append(k)
				if not (adj[k] as Array).has(i):
					(adj[k] as Array).append(i)
	var visited := {}
	var comps := 0
	for i in cards.size():
		if visited.has(i):
			continue
		comps += 1
		var stack: Array[int] = [i]
		visited[i] = true
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			for nb in adj[cur]:
				if not visited.has(nb):
					visited[nb] = true
					stack.append(nb)
	return {"component_count": comps, "connected": comps == 1}

# Straightness of the upper layers (quarter-card coordinates): the share of upper
# cards that have a same-layer card exactly side by side with them on one row or
# column, and the longest such chain.
func _scatter_metrics(cards: Array) -> Dictionary:
	var at := {}
	var upper := 0
	for c in cards:
		if int(c["layer"]) > 0:
			upper += 1
			at["%d:%d,%d" % [int(c["layer"]), int(c["grid_x"]), int(c["grid_y"])]] = true
	var in_run := 0
	var longest := 1 if upper > 0 else 0
	for c in cards:
		var layer := int(c["layer"])
		if layer == 0:
			continue
		var gx := int(c["grid_x"])
		var gy := int(c["grid_y"])
		var has_neighbor := false
		for step in [Vector2i(QUARTERS, 0), Vector2i(0, QUARTERS)]:
			var before := at.has("%d:%d,%d" % [layer, gx - step.x, gy - step.y])
			if before or at.has("%d:%d,%d" % [layer, gx + step.x, gy + step.y]):
				has_neighbor = true
			# Chains are counted from their first card.
			if not before:
				var length := 1
				while at.has("%d:%d,%d" % [layer, gx + step.x * length, gy + step.y * length]):
					length += 1
				longest = maxi(longest, length)
		if has_neighbor:
			in_run += 1
	# Variety of fractional offsets and spread over the base footprint, per layer.
	var bounds := Rect2i()
	var base_cards: Array = []
	for c in cards:
		if int(c["layer"]) == 0:
			base_cards.append(c)
	if not base_cards.is_empty():
		bounds = _footprint(base_cards)
	var x_classes := {}
	var y_classes := {}
	var thirds := {}
	var halves := {}
	var layer_cards := {}
	for c in cards:
		var layer := int(c["layer"])
		if layer == 0:
			continue
		layer_cards[layer] = int(layer_cards.get(layer, 0)) + 1
		x_classes[layer] = x_classes.get(layer, {})
		y_classes[layer] = y_classes.get(layer, {})
		thirds[layer] = thirds.get(layer, {})
		halves[layer] = halves.get(layer, {})
		var ox := int(c["grid_x"]) - bounds.position.x
		var oy := int(c["grid_y"]) - bounds.position.y
		x_classes[layer][posmod(ox, QUARTERS)] = true
		y_classes[layer][posmod(oy, QUARTERS)] = true
		thirds[layer][clampi((2 * ox + QUARTERS) * REGION_COLUMNS / (2 * bounds.size.x), 0, REGION_COLUMNS - 1)] = true
		halves[layer][clampi((2 * oy + QUARTERS) * REGION_ROWS / (2 * bounds.size.y), 0, REGION_ROWS - 1)] = true
	var samey := false
	var lopsided := false
	for layer in layer_cards:
		var n := int(layer_cards[layer])
		var wanted := 3 if n >= VARIETY_BIG_LAYER_CARDS else 2
		if n >= VARIETY_MIN_LAYER_CARDS and (x_classes[layer].size() < wanted or y_classes[layer].size() < wanted):
			samey = true
		if n >= REGION_MIN_LAYER_CARDS and (thirds[layer].size() < REGION_COLUMNS or halves[layer].size() < REGION_ROWS):
			lopsided = true
	return {
		"upper_cards": upper,
		"run_ratio": float(in_run) / float(upper) if upper > 0 else 0.0,
		"longest_run": longest,
		"samey": samey,
		"lopsided": lopsided,
	}

# Computes the spatial/support/blocking metrics and stamps each card's "blocked"
# field using the single shared rule BoardSpatialRules.
func _compute_spatial_metrics(cards: Array, spec: BoardSpec, step_x: float, step_y: float) -> Dictionary:
	var by_id := {}
	for c in cards:
		by_id[str(c["id"])] = c
	var counts := {}
	for c in cards:
		var l := int(c["layer"])
		counts[l] = int(counts.get(l, 0)) + 1
	var layer_count := counts.size()
	var cards_per_layer: Array = []
	var max_layer := 0
	for l in counts:
		max_layer = maxi(max_layer, int(l))
	for l in range(max_layer + 1):
		cards_per_layer.append(int(counts.get(l, 0)))

	var unsupported := 0
	var support_edge_count := 0
	var coverage_ok := true
	for c in cards:
		var layer := int(c["layer"])
		if layer == 0:
			continue
		var support_ids: Array = c.get("support_ids", [])
		support_edge_count += support_ids.size()
		if support_ids.size() < MIN_SUPPORTS:
			unsupported += 1
			coverage_ok = false
			continue
		var rect_c := Rect2(Vector2(float(c["x"]), float(c["y"])), Vector2(spec.card_size, spec.card_size))
		for sid in support_ids:
			var sp = by_id.get(str(sid), null)
			if sp == null:
				unsupported += 1
				coverage_ok = false
				continue
			if int(sp["layer"]) != layer - 1:
				unsupported += 1
				coverage_ok = false
				continue
			var rect_s := Rect2(Vector2(float(sp["x"]), float(sp["y"])), Vector2(spec.card_size, spec.card_size))
			if not BoardSpatialRules.at_or_above_threshold(BoardSpatialRules.coverage(rect_c, rect_s)):
				coverage_ok = false

	var blocked_cards := 0
	var free_cards := 0
	var blocking_edge_count := 0
	var free_per_layer: Array = []
	for _l in cards_per_layer.size():
		free_per_layer.append(0)
	for i in cards.size():
		var ci = cards[i]
		var layer_i := int(ci["layer"])
		var rect_i := Rect2(Vector2(float(ci["x"]), float(ci["y"])), Vector2(spec.card_size, spec.card_size))
		var blocked := false
		for j in cards.size():
			if i == j:
				continue
			var cj = cards[j]
			if int(cj["layer"]) <= layer_i:
				continue
			var rect_j := Rect2(Vector2(float(cj["x"]), float(cj["y"])), Vector2(spec.card_size, spec.card_size))
			if BoardSpatialRules.blocks(rect_i, rect_j):
				blocked = true
				blocking_edge_count += 1
		ci["blocked"] = blocked
		if blocked:
			blocked_cards += 1
		else:
			free_cards += 1
			free_per_layer[layer_i] = int(free_per_layer[layer_i]) + 1

	# Same-layer cards must never overlap (grid alignment); coverage is the largest
	# fraction of any card hidden by a single card of a higher layer.
	var same_layer_overlaps := 0
	var max_coverage := 0.0
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			var lo = cards[i]
			var hi = cards[j]
			var lo_rect := Rect2(Vector2(float(lo["x"]), float(lo["y"])), Vector2(spec.card_size, spec.card_size))
			var hi_rect := Rect2(Vector2(float(hi["x"]), float(hi["y"])), Vector2(spec.card_size, spec.card_size))
			if int(lo["layer"]) == int(hi["layer"]):
				if lo_rect.intersects(hi_rect):
					same_layer_overlaps += 1
			else:
				max_coverage = maxf(max_coverage, BoardSpatialRules.coverage(lo_rect, hi_rect))
	var strictly_decreasing := true
	for i in range(1, cards_per_layer.size()):
		if int(cards_per_layer[i]) >= int(cards_per_layer[i - 1]):
			strictly_decreasing = false
	# A layer buried almost completely leaves the player nothing to uncover from it.
	var starved_layer := false
	for l in range(cards_per_layer.size() - 1):
		if int(cards_per_layer[l]) >= RESERVE_MIN_LAYER_CARDS and float(free_per_layer[l]) < maxf(1.0, ceilf(STARVED_FREE_SHARE * float(cards_per_layer[l]))):
			starved_layer = true
	var valid_layers := unsupported == 0 and coverage_ok and strictly_decreasing and layer_count == spec.layers and same_layer_overlaps == 0
	var score := float(blocking_edge_count) + float(free_cards) + float(support_edge_count) - float(unsupported) * 100.0
	return {
		"valid_layers": valid_layers,
		"same_layer_overlaps": same_layer_overlaps,
		"max_coverage": max_coverage,
		"unsupported_cards": unsupported,
		"support_edge_count": support_edge_count,
		"blocking_edge_count": blocking_edge_count,
		"free_cards": free_cards,
		"blocked_cards": blocked_cards,
		"free_per_layer": free_per_layer,
		"starved_layer": starved_layer,
		"layer_count": layer_count,
		"cards_per_layer": cards_per_layer,
		"coverage_ok": coverage_ok,
		"score": score,
	}

func _grow(spec: BoardSpec, seed: int, step_x: float, step_y: float, cells_x: int, cells_y: int, center: Vector2i, count: int) -> Dictionary:
	var occupied := {}
	var frontier := {}
	var min_gx := center.x
	var max_gx := center.x
	var min_gy := center.y
	var max_gy := center.y
	occupied[center] = true
	var cards: Array[Dictionary] = []
	cards.append(_make_card(0, center, step_x, step_y, 0))
	_add_frontier(frontier, occupied, center, cells_x, cells_y)

	var budget := maxi(BUDGET_FLOOR, count * BUDGET_PER_CARD)
	while cards.size() < count:
		budget -= 1
		if budget <= 0:
			return {"ok": false, "cards": cards, "error": "budget exhausted placing %d/%d cards" % [cards.size(), count]}
		if frontier.is_empty():
			return {"ok": false, "cards": cards, "error": "no frontier cells left placing %d/%d cards" % [cards.size(), count]}
		var candidate: Vector2i = _pick_candidate(frontier, occupied, center, seed, min_gx, max_gx, min_gy, max_gy, spec.card_size)
		frontier.erase(candidate)
		occupied[candidate] = true
		min_gx = mini(min_gx, candidate.x)
		max_gx = maxi(max_gx, candidate.x)
		min_gy = mini(min_gy, candidate.y)
		max_gy = maxi(max_gy, candidate.y)
		cards.append(_make_card(cards.size(), candidate, step_x, step_y, 0))
		_add_frontier(frontier, occupied, candidate, cells_x, cells_y)

	return {"ok": true, "cards": cards, "error": ""}

func _evaluate_gates(cards: Array, spec: BoardSpec, step_x: float, step_y: float) -> Dictionary:
	var cells_x := floori((spec.board_width - spec.card_size) / step_x) + 1
	var cells_y := floori((spec.board_height - spec.card_size) / step_y) + 1
	var holes := _find_holes(cards, cells_x, cells_y)
	var largest := int(holes["largest"])
	var no_large_holes := largest <= MAX_HOLE_HALF_CELLS
	var bridge_count := _narrow_bridge_count(cards)
	var no_narrow_bridges := bridge_count == 0
	var density := _compact_density(cards, cells_x, cells_y)
	var aspect := _occupied_aspect(cards, spec, step_x, step_y)
	var aspect_ok := aspect >= _aspect_min and aspect <= _aspect_max
	var density_ok := density >= DENSITY_MIN

	var rejections: Array[String] = []
	if not no_large_holes:
		rejections.append("large_hole")
	if not no_narrow_bridges:
		rejections.append("narrow_bridge")
	if not density_ok:
		rejections.append("density")
	if not aspect_ok:
		rejections.append("aspect")

	return {
		"pass": rejections.is_empty(),
		"rejections": rejections,
		"no_large_holes": no_large_holes,
		"largest_hole_half_cells": largest,
		"hole_count": int(holes["count"]),
		"no_narrow_bridges": no_narrow_bridges,
		"narrow_bridge_count": bridge_count,
		"compact_density": density,
		"occupied_aspect": aspect,
		"score": density * 10.0 + (5.0 if aspect_ok else 0.0) + (3.0 if no_large_holes else 0.0) + (3.0 if no_narrow_bridges else 0.0),
	}

func _pick_candidate(frontier: Dictionary, occupied: Dictionary, center: Vector2i, seed: int, min_gx: int, max_gx: int, min_gy: int, max_gy: int, card_size: float) -> Vector2i:
	var best := Vector2i.ZERO
	var best_score := -INF
	var best_key := Vector2i.ZERO
	for key in frontier:
		var score := _candidate_score(key, center, occupied, seed, min_gx, max_gx, min_gy, max_gy, card_size)
		if score > best_score or (score == best_score and _cell_less(key, best_key)):
			best_score = score
			best = key
			best_key = key
	return best

func _candidate_score(cell: Vector2i, center: Vector2i, occupied: Dictionary, seed: int, min_gx: int, max_gx: int, min_gy: int, max_gy: int, card_size: float) -> float:
	var jitter := _hash01(seed, cell.x, cell.y) * JITTER_WEIGHT
	var neighbor_bonus := float(_occupied_neighbor_count(cell, occupied)) * NEIGHBOR_WEIGHT
	var aspect_penalty := _aspect_penalty(cell, min_gx, max_gx, min_gy, max_gy, card_size) * ASPECT_WEIGHT
	var centering := _centering_penalty(cell, center, min_gx, max_gx, min_gy, max_gy) * CENTER_WEIGHT
	return jitter + neighbor_bonus - aspect_penalty - centering

# Penalizes a candidate whose addition pushes the occupied bounding box aspect
# away from the spec's aspect_target, so growth stays comfortably within the valid band.
func _aspect_penalty(cell: Vector2i, min_gx: int, max_gx: int, min_gy: int, max_gy: int, card_size: float) -> float:
	var nmx := mini(min_gx, cell.x)
	var nxx := maxi(max_gx, cell.x)
	var nmy := mini(min_gy, cell.y)
	var nxy := maxi(max_gy, cell.y)
	var step := card_size / 2.0
	var w := float(nxx - nmx) * step + card_size
	var h := float(nxy - nmy) * step + card_size
	var aspect := w / h if h > 0.0 else _aspect_target
	return absf(aspect - _aspect_target)

# Penalizes a candidate that would move the occupied bounding box away from the
# board center: a side may not extend further from the center than the mirrored
# extent of the opposite side already is. Keeps the shape balanced/centralized.
func _centering_penalty(cell: Vector2i, center: Vector2i, min_gx: int, max_gx: int, min_gy: int, max_gy: int) -> float:
	var pen := 0.0
	if cell.x < min_gx:
		pen += maxf(0.0, float(center.x - cell.x) - float(max_gx - center.x))
	elif cell.x > max_gx:
		pen += maxf(0.0, float(cell.x - center.x) - float(center.x - min_gx))
	if cell.y < min_gy:
		pen += maxf(0.0, float(center.y - cell.y) - float(max_gy - center.y))
	elif cell.y > max_gy:
		pen += maxf(0.0, float(cell.y - center.y) - float(center.y - min_gy))
	return pen

func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y

func _occupied_neighbor_count(cell: Vector2i, occupied: Dictionary) -> int:
	var count := 0
	for delta in _lattice_moves():
		if occupied.has(cell + (delta as Vector2i)):
			count += 1
	return count

func _add_frontier(frontier: Dictionary, occupied: Dictionary, cell: Vector2i, cells_x: int, cells_y: int) -> void:
	for delta in _lattice_moves():
		var n := cell + delta
		if n.x < 0 or n.x >= cells_x or n.y < 0 or n.y >= cells_y:
			continue
		if occupied.has(n) or frontier.has(n):
			continue
		frontier[n] = true

func _make_card(index: int, cell: Vector2i, step_x: float, step_y: float, layer: int = 0) -> Dictionary:
	return {
		"id": "c%d" % index,
		"grid_x": cell.x,
		"grid_y": cell.y,
		"x": float(cell.x) * step_x,
		"y": float(cell.y) * step_y,
		"layer": layer,
		"support_ids": [],
	}

func _assign_symbols(cards: Array, spec: BoardSpec) -> void:
	if spec.card_types.is_empty():
		return
	var assignments: Array[String] = []
	var trio_count := spec.card_count / 3
	for trio_index in trio_count:
		var card_type := spec.card_types[trio_index % spec.card_types.size()]
		for copy_index in 3:
			assignments.append(card_type)
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.symbol_seed
	for i in range(assignments.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, i)
		var previous := assignments[i]
		assignments[i] = assignments[swap_index]
		assignments[swap_index] = previous
	for i in cards.size():
		cards[i]["type"] = assignments[i]

func _card_type_metrics(cards: Array, spec: BoardSpec) -> Dictionary:
	var counts := {}
	if spec.card_types.is_empty():
		return {"counts": counts, "valid": true}
	for card_type in spec.card_types:
		counts[card_type] = 0
	for card in cards:
		if not card.has("type"):
			return {"counts": counts, "valid": false}
		var card_type := String(card["type"])
		if not counts.has(card_type):
			return {"counts": counts, "valid": false}
		counts[card_type] = int(counts[card_type]) + 1
	var valid := cards.size() == spec.card_count
	for count in counts.values():
		valid = valid and int(count) % 3 == 0
	return {"counts": counts, "valid": valid}

func _metrics_from(cards: Array, spec: BoardSpec, step_x: float, step_y: float, gates: Dictionary = {}, attempts: int = 1, rejection_counts: Dictionary = {}) -> Dictionary:
	var min_x := 0
	var max_x := 0
	var min_y := 0
	var max_y := 0
	if not cards.is_empty():
		var first = cards[0]
		min_x = int(first["grid_x"])
		max_x = min_x
		min_y = int(first["grid_y"])
		max_y = min_y
		for i in range(1, cards.size()):
			var c = cards[i]
			var gx := int(c["grid_x"])
			var gy := int(c["grid_y"])
			min_x = mini(min_x, gx)
			max_x = maxi(max_x, gx)
			min_y = mini(min_y, gy)
			max_y = maxi(max_y, gy)
	var occupied_width := float(max_x - min_x) * step_x + spec.card_size
	var occupied_height := float(max_y - min_y) * step_y + spec.card_size
	var completed := cards.size() == spec.card_count and cards.size() > 0
	var symbol_metrics := _card_type_metrics(cards, spec)
	return {
		"total_cards": cards.size(),
		"base_card_count": int(gates.get("cards_per_layer", [cards.size()])[0]),
		"connected_layout": bool(gates.get("connected_layout", completed)),
		"component_count": int(gates.get("component_count", 1 if completed else 0)),
		"occupied_width": occupied_width,
		"occupied_height": occupied_height,
		"occupied_aspect": occupied_width / occupied_height if occupied_height > 0.0 else 0.0,
		"step_x": step_x,
		"step_y": step_y,
		"seed_used": spec.geometry_seed,
		"geometry_seed_used": spec.geometry_seed,
		"symbol_seed_used": spec.symbol_seed,
		"valid_card_counts": bool(symbol_metrics["valid"]),
		"card_type_counts": symbol_metrics["counts"],
		"no_large_holes": bool(gates.get("no_large_holes", false)),
		"largest_hole_half_cells": int(gates.get("largest_hole_half_cells", 0)),
		"hole_count": int(gates.get("hole_count", 0)),
		"no_narrow_bridges": bool(gates.get("no_narrow_bridges", false)),
		"narrow_bridge_count": int(gates.get("narrow_bridge_count", 0)),
		"compact_density": float(gates.get("compact_density", 0.0)),
		"attempts": attempts,
		"rejection_counts": rejection_counts.duplicate(),
		"valid_layers": bool(gates.get("valid_layers", false)),
		"same_layer_overlaps": int(gates.get("same_layer_overlaps", 0)),
		"max_coverage": float(gates.get("max_coverage", 0.0)),
		"free_ratio": float(gates.get("free_cards", 0)) / float(cards.size()) if not cards.is_empty() else 0.0,
		"unsupported_cards": int(gates.get("unsupported_cards", 0)),
		"support_edge_count": int(gates.get("support_edge_count", 0)),
		"blocking_edge_count": int(gates.get("blocking_edge_count", 0)),
		"free_cards": int(gates.get("free_cards", 0)),
		"blocked_cards": int(gates.get("blocked_cards", 0)),
		"free_per_layer": gates.get("free_per_layer", []),
		"run_ratio": float(gates.get("run_ratio", 0.0)),
		"longest_run": int(gates.get("longest_run", 0)),
		"layer_count": int(gates.get("layer_count", 1)),
		"cards_per_layer": gates.get("cards_per_layer", [cards.size()]),
	}

# Half-card rasterization: each card occupies a 2x2 block of half-cells starting
# at its grid coordinate. Flood-fills empty cells reachable from the raster
# border (the exterior); empty cells NOT reachable are internal holes.
func _find_holes(cards: Array, cells_x: int, cells_y: int) -> Dictionary:
	var raster_w := cells_x + 1
	var raster_h := cells_y + 1
	var covered := {}
	for c in cards:
		var gx := int(c["grid_x"])
		var gy := int(c["grid_y"])
		for dx in 2:
			for dy in 2:
				covered["%d,%d" % [gx + dx, gy + dy]] = true

	var exterior := {}
	var stack: Array[Vector2i] = []
	for x in raster_w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, raster_h - 1))
	for y in raster_h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(raster_w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		var key := "%d,%d" % [p.x, p.y]
		if covered.has(key) or exterior.has(key):
			continue
		exterior[key] = true
		for d in _orthogonal():
			var n := p + (d as Vector2i)
			if n.x < 0 or n.x >= raster_w or n.y < 0 or n.y >= raster_h:
				continue
			var nk := "%d,%d" % [n.x, n.y]
			if not covered.has(nk) and not exterior.has(nk):
				stack.append(n)

	var hole_count := 0
	var largest := 0
	var visited := {}
	for y in raster_h:
		for x in raster_w:
			var key := "%d,%d" % [x, y]
			if covered.has(key) or exterior.has(key) or visited.has(key):
				continue
			hole_count += 1
			var size := 0
			var hstack: Array[Vector2i] = [Vector2i(x, y)]
			visited[key] = true
			while not hstack.is_empty():
				var hp: Vector2i = hstack.pop_back()
				size += 1
				for d in _orthogonal():
					var hn := hp + (d as Vector2i)
					if hn.x < 0 or hn.x >= raster_w or hn.y < 0 or hn.y >= raster_h:
						continue
					var hk := "%d,%d" % [hn.x, hn.y]
					if not covered.has(hk) and not exterior.has(hk) and not visited.has(hk):
						visited[hk] = true
						hstack.append(hn)
			largest = maxi(largest, size)
	return {"largest": largest, "count": hole_count}

# Slot-graph articulation scan: a card is a narrow bridge if removing it splits
# the board into at least two connected groups each holding >= BRIDGE_GROUP_MIN
# cards.
func _narrow_bridge_count(cards: Array) -> int:
	var n := cards.size()
	if n < 3:
		return 0
	var pos := {}
	for i in n:
		pos["%d,%d" % [int(cards[i]["grid_x"]), int(cards[i]["grid_y"])]] = i
	var adj: Array = []
	adj.resize(n)
	for i in n:
		var gx := int(cards[i]["grid_x"])
		var gy := int(cards[i]["grid_y"])
		var list: Array[int] = []
		for delta in _moves():
			var j: int = pos.get("%d,%d" % [gx + delta.x, gy + delta.y], -1)
			if j >= 0:
				list.append(int(j))
		adj[i] = list
	var bridge_count := 0
	for v in n:
		var visited := {}
		var groups: Array[int] = []
		for s in n:
			if s == v or visited.has(s):
				continue
			var count := 0
			var stack: Array[int] = [s]
			visited[s] = true
			while not stack.is_empty():
				var cur: int = stack.pop_back()
				count += 1
				for nb in adj[cur]:
					if nb == v or visited.has(nb):
						continue
					visited[nb] = true
					stack.append(nb)
			groups.append(count)
		var big := 0
		for g in groups:
			if g >= BRIDGE_GROUP_MIN:
				big += 1
		if big >= 2:
			bridge_count += 1
	return bridge_count

func _compact_density(cards: Array, cells_x: int, cells_y: int) -> float:
	var covered := {}
	var min_x := cells_x + 1
	var max_x := -1
	var min_y := cells_y + 1
	var max_y := -1
	for c in cards:
		var gx := int(c["grid_x"])
		var gy := int(c["grid_y"])
		for dx in 2:
			for dy in 2:
				var x := gx + dx
				var y := gy + dy
				covered["%d,%d" % [x, y]] = true
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	var bbox_w := float(max_x - min_x + 1)
	var bbox_h := float(max_y - min_y + 1)
	if bbox_w <= 0.0 or bbox_h <= 0.0:
		return 0.0
	return float(covered.size()) / (bbox_w * bbox_h)

func _occupied_aspect(cards: Array, spec: BoardSpec, step_x: float, step_y: float) -> float:
	if cards.is_empty():
		return 0.0
	var first = cards[0]
	var min_x := int(first["grid_x"])
	var max_x := min_x
	var min_y := int(first["grid_y"])
	var max_y := min_y
	for i in range(1, cards.size()):
		var c = cards[i]
		var gx := int(c["grid_x"])
		var gy := int(c["grid_y"])
		min_x = mini(min_x, gx)
		max_x = maxi(max_x, gx)
		min_y = mini(min_y, gy)
		max_y = maxi(max_y, gy)
	var w := float(max_x - min_x) * step_x + spec.card_size
	var h := float(max_y - min_y) * step_y + spec.card_size
	return w / h if h > 0.0 else 0.0

func _orthogonal() -> Array[Vector2i]:
	return [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func _hash01(seed: int, x: int, y: int) -> float:
	var h := seed
	h = (h * 0x9E3779B1) ^ (x * 0x85EBCA77)
	h = (h * 0xC2B2AE35) ^ (y * 0x27D4EB2F)
	h = (h ^ (h >> 15)) * 0x165667B1
	h = (h ^ (h >> 13))
	var m := (h % 1000003 + 1000003) % 1000003
	return float(m) / 1000003.0

# Base growth moves one full card at a time so layer-0 cards never overlap.
func _lattice_moves() -> Array[Vector2i]:
	return [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]

# Adjacency on the half-card raster (base compactness gates).
func _moves() -> Array[Vector2i]:
	return [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

# Adjacency used by the connectivity metrics, in quarter-card steps (full-card and
# half-card neighbours).
func _moves_quarter() -> Array[Vector2i]:
	var full := QUARTERS
	var half := QUARTERS / 2
	return [Vector2i(full, 0), Vector2i(-full, 0), Vector2i(0, full), Vector2i(0, -full),
			Vector2i(half, half), Vector2i(half, -half), Vector2i(-half, half), Vector2i(-half, -half)]

func _is_minimum_pyramid(spec: BoardSpec) -> bool:
	return spec.layers > 1 and spec.card_count == spec.layers * (spec.layers + 1) / 2

# A base of up to 3 cards (or the single-row base of the minimum pyramid, the only
# same-layer-overlap-free staircase base) has no meaningful aspect or bridge shape.
func _shape_gates_waived(spec: BoardSpec) -> bool:
	if _is_minimum_pyramid(spec):
		return true
	var targets := layer_targets(spec.card_count, spec.layers, spec.layer_ratio)
	return not targets.is_empty() and int(targets[0]) <= SMALL_BASE_CARDS
