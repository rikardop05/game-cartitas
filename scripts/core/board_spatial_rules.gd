class_name BoardSpatialRules
extends RefCounted

# Single source of truth for the spatial blocking rule shared by BoardPipeline
# and BoardManager. A covering card blocks a covered card when the covered
# fraction (intersection_area / card_area) reaches BLOCK_THRESHOLD.
#
# Boundary representation: coverage remains raw and scalar comparisons remain
# direct. blocks() compares areas and uses only a derived half-ULP area step to
# canonicalize the stored float32 representative of an exact geometric limit.
# The next representable position beyond that cell remains below the threshold.

const BLOCK_THRESHOLD := 0.10
const FLOAT32_FRACTION_BITS := 23
const FLOAT32_MIN_SUBNORMAL_EXPONENT := -149

static func coverage(covered_rect: Rect2, covering_rect: Rect2) -> float:
	var covered := covered_rect.abs()
	var covering := covering_rect.abs()
	var card_area := covered.size.x * covered.size.y
	if card_area <= 0.0:
		return 0.0
	var ix := _axis_overlap(covered.position.x, covered.size.x, covering.position.x, covering.size.x)
	var iy := _axis_overlap(covered.position.y, covered.size.y, covering.position.y, covering.size.y)
	return (ix * iy) / card_area

static func blocks(covered_rect: Rect2, covering_rect: Rect2) -> bool:
	var covered := covered_rect.abs()
	var covering := covering_rect.abs()
	var covered_area := covered.size.x * covered.size.y
	if covered_area <= 0.0:
		return false
	var overlap_x := _axis_overlap(covered.position.x, covered.size.x, covering.position.x, covering.size.x)
	var overlap_y := _axis_overlap(covered.position.y, covered.size.y, covering.position.y, covering.size.y)
	if overlap_x <= 0.0 or overlap_y <= 0.0:
		return false
	var intersection_area := overlap_x * overlap_y
	var threshold_area := covered_area * BLOCK_THRESHOLD
	if intersection_area >= threshold_area:
		return true
	var deficit := threshold_area - intersection_area
	return deficit <= _half_representable_area_step(covered, covering, overlap_x, overlap_y)

# Pure coverage-threshold decision: direct comparison, no rounding. A coverage
# value strictly below BLOCK_THRESHOLD never blocks; exactly BLOCK_THRESHOLD
# (the double closest to 0.10) blocks.
static func at_or_above_threshold(cov: float) -> bool:
	return cov >= BLOCK_THRESHOLD

# Keep endpoint arithmetic scalar. Rect2.end materializes a Vector2 and rounds
# position + size back to float32; after translation that extra rounding can
# cancel the next representable offset and promote sub-threshold geometry.
static func _axis_overlap(a_position: float, a_size: float, b_position: float, b_size: float) -> float:
	var a_end := a_position + a_size
	var b_end := b_position + b_size
	return maxf(0.0, minf(a_end, b_end) - maxf(a_position, b_position))

# Rect2 stores coordinates as float32. For a normal value x, one representable
# step is ULP(x) = 2^(floor(log2(abs(x))) - 23); subnormals use 2^-149. An axis'
# area step is that coordinate ULP times the overlap on the orthogonal axis.
# Only half of the smallest relevant area step may canonicalize a deficit.
#
# For measured case A, exponent(43.2) = 5, hence ULP = 2^-18. Its half-area
# step includes the storage error at the mathematical boundary. Case B is the
# next float32 offset and its deficit is already larger than that half-step, so
# no representable below-threshold geometry is promoted.
static func _float32_ulp(value: float) -> float:
	var magnitude := absf(value)
	if magnitude == 0.0:
		return pow(2.0, FLOAT32_MIN_SUBNORMAL_EXPONENT)
	var exponent := floori(log(magnitude) / log(2.0))
	return pow(2.0, maxi(exponent - FLOAT32_FRACTION_BITS, FLOAT32_MIN_SUBNORMAL_EXPONENT))

static func _half_representable_area_step(covered: Rect2, covering: Rect2, overlap_x: float, overlap_y: float) -> float:
	var area_steps: Array[float] = []
	if overlap_x < minf(covered.size.x, covering.size.x):
		area_steps.append(_float32_ulp(covering.position.x) * overlap_y)
	if overlap_y < minf(covered.size.y, covering.size.y):
		area_steps.append(_float32_ulp(covering.position.y) * overlap_x)
	if area_steps.is_empty():
		return 0.0
	var smallest_step := area_steps[0]
	for step in area_steps:
		smallest_step = minf(smallest_step, step)
	return smallest_step / 2.0

static func higher_layer_blocks(covered_layer: int, covering_layer: int) -> bool:
	return covering_layer > covered_layer

static func blocks_with_layers(covered_rect: Rect2, covering_rect: Rect2, covered_layer: int, covering_layer: int) -> bool:
	return higher_layer_blocks(covered_layer, covering_layer) and blocks(covered_rect, covering_rect)
