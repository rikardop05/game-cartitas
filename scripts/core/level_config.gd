class_name LevelConfig
extends RefCounted

const DEFAULT_PITCH_RATIO := 0.86
const DEFAULT_CARD_SIZE := 48.0

# Central visual metrics (Lumen spec). Single source of truth shared by the
# generator (logical space) and the renderer (level_screen / BoardLayout).
const CARD_LOGICAL_SIZE := 48.0
const MIN_CARD_SCALE := 0.85
const RESERVE_CARD_SCALE := 0.80
const BOARD_PADDING := 8.0
const HEADER_HEIGHT := 40.0
const INSTRUCTION_HEIGHT := 18.0
const BOARD_MIN_HEIGHT := 200.0
const MAX_VISIBLE_LAYERS := 4

# Overlap guardrails: covered fraction per axis, horizontal 35-60% and
# vertical 35-55% of the card dimension (Lumen spec).
const OVERLAP_H_MIN := 0.35
const OVERLAP_H_MAX := 0.60
const OVERLAP_V_MIN := 0.35
const OVERLAP_V_MAX := 0.55
const MIN_SAME_LAYER_DIST_RATIO := 0.35

# Board envelope guardrails. Portrait is the reference layout: 360x640 logical
# viewport with a ~332x264 board area (measured after the responsive layout).
# Landscape has a dedicated UI (640x360) leaving a ~546x240 board area. Configs
# that cannot keep the minimum rendered card size are MARKED
# (fits_landscape=false), not rejected. Guardrails live here and are enforced by
# validate(): 7x6 slots, 4 layers, 36 board cards, min rendered card size.
const PORTRAIT_BOARD_ENVELOPE := Vector2(332, 264)
const LANDSCAPE_BOARD_ENVELOPE := Vector2(546, 240)
const MIN_CARD_SIZE_PX := 24.0
const MAX_SLOT_COLUMNS := 7
const MAX_SLOT_ROWS := 6
const MAX_LAYERS := 4
const MAX_BOARD_CARDS := 36

var difficulty: int = 1
var board_types: Array[String] = []
var count_per_type: int = 3
var deck_types: Array[String] = []
var columns: int = 5
var rows: int = 5
var occupancy_h: float = 0.6
var occupancy_v: float = 0.6
var layers: int = 2
var overlap: float = 0.45
var overlap_h: float = 0.45
var overlap_v: float = 0.405
var free_ratio: float = 0.55
var free_ratio_min: float = 0.40
var free_ratio_max: float = 0.70
var complexity: float = 1.0
var card_size: float = DEFAULT_CARD_SIZE
var pitch_ratio: float = DEFAULT_PITCH_RATIO
var seed: int = 1001
var max_attempts: int = 60

var available_card_types: Array[String] = []
var types_used_in_level: Array[String] = []

func _init() -> void:
	available_card_types = []
	for t in CardTypeRegistry.all_types():
		available_card_types.append(str(t))

static func create(params: Dictionary) -> LevelConfig:
	var cfg := LevelConfig.new()
	cfg.difficulty = int(params.get("difficulty", 1))
	cfg.board_types = []
	for t in params.get("board_types", []):
		cfg.board_types.append(str(t))
	cfg.count_per_type = int(params.get("count_per_type", 3))
	cfg.columns = int(params.get("columns", 5))
	cfg.rows = int(params.get("rows", 5))
	cfg.occupancy_h = float(params.get("occupancy_h", 0.6))
	cfg.occupancy_v = float(params.get("occupancy_v", 0.6))
	cfg.layers = int(params.get("layers", 2))
	cfg.overlap = float(params.get("overlap", 0.45))
	if params.has("overlap_h") or params.has("overlap_v"):
		cfg.overlap_h = clampf(float(params.get("overlap_h", cfg.overlap)), OVERLAP_H_MIN, OVERLAP_H_MAX)
		cfg.overlap_v = clampf(float(params.get("overlap_v", cfg.overlap)), OVERLAP_V_MIN, OVERLAP_V_MAX)
	else:
		cfg.overlap_h = clampf(cfg.overlap, OVERLAP_H_MIN, OVERLAP_H_MAX)
		cfg.overlap_v = clampf(cfg.overlap * 0.9, OVERLAP_V_MIN, OVERLAP_V_MAX)
	cfg.overlap = (cfg.overlap_h + cfg.overlap_v) / 2.0
	cfg.free_ratio = float(params.get("free_ratio", 0.55))
	cfg.free_ratio_min = float(params.get("free_ratio_min", cfg.free_ratio - 0.15))
	cfg.free_ratio_max = float(params.get("free_ratio_max", cfg.free_ratio + 0.15))
	cfg.complexity = float(params.get("complexity", 1.0))
	cfg.card_size = float(params.get("card_size", DEFAULT_CARD_SIZE))
	cfg.pitch_ratio = clampf(float(params.get("pitch_ratio", DEFAULT_PITCH_RATIO)), 0.75, 0.95)
	cfg.seed = int(params.get("seed", 1001))
	cfg.max_attempts = int(params.get("max_attempts", 60))
	return cfg

func with_deck(pool: Array) -> void:
	deck_types = []
	for t in pool:
		deck_types.append(str(t))
	_recompute_types_used()

func _recompute_types_used() -> void:
	types_used_in_level = []
	for t in board_types:
		if not types_used_in_level.has(t):
			types_used_in_level.append(t)
	for t in deck_types:
		if not types_used_in_level.has(t):
			types_used_in_level.append(t)

func board_cards() -> int:
	return board_types.size() * count_per_type

func deck_card_count() -> int:
	return deck_types.size()

func total_cards() -> int:
	return board_cards() + deck_card_count()

func board_count(type_name: String) -> int:
	return count_per_type if board_types.has(type_name) else 0

func deck_count(type_name: String) -> int:
	var n := 0
	for t in deck_types:
		if t == type_name:
			n += 1
	return n

func pitch() -> float:
	return maxf(8.0, card_size * pitch_ratio)

func board_width() -> float:
	return maxf(card_size, (columns - 1) * pitch() + card_size)

func board_height() -> float:
	return maxf(card_size, (rows - 1) * pitch() + card_size)

func slot_columns() -> int:
	return maxi(1, roundi(columns * occupancy_h))

func slot_rows() -> int:
	return maxi(1, roundi(rows * occupancy_v))

func slot_count() -> int:
	return slot_columns() * slot_rows()

func capacity() -> int:
	return slot_count() * layers

# Occupancy-driven anchor pitch (Lumen): the anchor grid spans occupancy_h of
# the board width and occupancy_v of the board height.
func slot_pitch_x() -> float:
	return clampf(
		(occupancy_h * board_width() - card_size) / maxf(1.0, float(slot_columns() - 1)),
		card_size * MIN_SAME_LAYER_DIST_RATIO, card_size
	)

func slot_pitch_y() -> float:
	return clampf(
		(occupancy_v * board_height() - card_size) / maxf(1.0, float(slot_rows() - 1)),
		card_size * MIN_SAME_LAYER_DIST_RATIO, card_size
	)

func min_same_layer_distance() -> float:
	return card_size * MIN_SAME_LAYER_DIST_RATIO

func effective_overlap_h() -> float:
	return clampf(overlap_h, OVERLAP_H_MIN, OVERLAP_H_MAX)

func effective_overlap_v() -> float:
	return clampf(overlap_v, OVERLAP_V_MIN, OVERLAP_V_MAX)

func anchor_occupancy_h() -> float:
	var grid_w := float(maxi(0, slot_columns() - 1)) * slot_pitch_x() + card_size
	return grid_w / board_width()

func anchor_occupancy_v() -> float:
	var grid_h := float(maxi(0, slot_rows() - 1)) * slot_pitch_y() + card_size
	return grid_h / board_height()

# Rendered card size (px) when the board is fitted into the given envelope.
func envelope_card_size(envelope: Vector2) -> float:
	if envelope.x <= 0.0 or envelope.y <= 0.0:
		return INF
	var scale := minf(envelope.x / board_width(), envelope.y / board_height())
	return card_size * scale

func fits_portrait() -> bool:
	return envelope_card_size(PORTRAIT_BOARD_ENVELOPE) >= MIN_CARD_SIZE_PX

func fits_landscape() -> bool:
	return envelope_card_size(LANDSCAPE_BOARD_ENVELOPE) >= MIN_CARD_SIZE_PX

func validate() -> Dictionary:
	var errors: Array[String] = []
	if board_types.is_empty():
		errors.append("no board types configured")
	if count_per_type % 3 != 0:
		errors.append("count_per_type %d is not a multiple of 3" % count_per_type)
	if board_cards() % 3 != 0:
		errors.append("board cards %d is not a multiple of 3" % board_cards())
	if total_cards() % 3 != 0:
		errors.append("total cards %d is not a multiple of 3" % total_cards())
	if layers < 1:
		errors.append("layers must be >= 1")
	if columns < 1 or rows < 1:
		errors.append("columns and rows must be >= 1")
	if slot_count() < 1:
		errors.append("slot grid is empty")
	if board_cards() > capacity():
		errors.append("board cards %d exceed slot capacity %d (slots %d x layers %d)" % [board_cards(), capacity(), slot_count(), layers])
	if slot_columns() > MAX_SLOT_COLUMNS or slot_rows() > MAX_SLOT_ROWS:
		errors.append("slot grid %dx%d exceeds guardrail %dx%d" % [slot_columns(), slot_rows(), MAX_SLOT_COLUMNS, MAX_SLOT_ROWS])
	if layers > MAX_LAYERS:
		errors.append("layers %d exceeds guardrail %d" % [layers, MAX_LAYERS])
	if board_cards() > MAX_BOARD_CARDS:
		errors.append("board cards %d exceed guardrail %d" % [board_cards(), MAX_BOARD_CARDS])
	if not fits_portrait():
		errors.append("config does not fit the canonical portrait envelope (rendered card %.1fpx < %dpx)" % [envelope_card_size(PORTRAIT_BOARD_ENVELOPE), int(MIN_CARD_SIZE_PX)])
	if overlap_h < OVERLAP_H_MIN or overlap_h > OVERLAP_H_MAX:
		errors.append("overlap_h %.2f outside H range [%.2f, %.2f]" % [overlap_h, OVERLAP_H_MIN, OVERLAP_H_MAX])
	if overlap_v < OVERLAP_V_MIN or overlap_v > OVERLAP_V_MAX:
		errors.append("overlap_v %.2f outside V range [%.2f, %.2f]" % [overlap_v, OVERLAP_V_MIN, OVERLAP_V_MAX])
	if slot_pitch_x() < card_size * MIN_SAME_LAYER_DIST_RATIO - 0.01 or slot_pitch_y() < card_size * MIN_SAME_LAYER_DIST_RATIO - 0.01:
		errors.append("slot pitch below minimum same-layer distance 0.35*card")
	if free_ratio_min > free_ratio or free_ratio_max < free_ratio:
		errors.append("free_ratio target %.2f outside declared range [%.2f, %.2f]" % [free_ratio, free_ratio_min, free_ratio_max])
	if free_ratio_min < 0.0 or free_ratio_max > 1.0:
		errors.append("free_ratio range must lie within [0, 1]")
	for t in types_used_in_level:
		var total := board_count(t) + deck_count(t)
		if total % 3 != 0:
			errors.append("type '%s' has %d total cards (not a multiple of 3)" % [t, total])
	return {"valid": errors.is_empty(), "errors": errors}

func generate(board_size: Vector2 = Vector2.ZERO) -> Dictionary:
	return LayoutGenerator.generate_level(self, board_size)

func metrics() -> Dictionary:
	return {
		"difficulty": difficulty,
		"board_cards": board_cards(),
		"deck_cards": deck_card_count(),
		"types": board_types.size(),
		"types_used_in_level": types_used_in_level.duplicate(),
		"available_card_types": available_card_types.duplicate(),
		"columns": columns,
		"rows": rows,
		"slot_columns": slot_columns(),
		"slot_rows": slot_rows(),
		"occupancy_h": occupancy_h,
		"occupancy_v": occupancy_v,
		"layers": layers,
		"overlap": overlap,
		"overlap_target": overlap,
		"overlap_h": effective_overlap_h(),
		"overlap_v": effective_overlap_v(),
		"free_ratio_target": free_ratio,
		"free_ratio_min": free_ratio_min,
		"free_ratio_max": free_ratio_max,
		"complexity": complexity,
		"card_size": card_size,
		"seed": seed,
		"min_same_layer_distance": min_same_layer_distance(),
		"anchor_occupancy_h": anchor_occupancy_h(),
		"anchor_occupancy_v": anchor_occupancy_v(),
		"fits_portrait": fits_portrait(),
		"fits_landscape": fits_landscape(),
		"min_card_px_portrait": envelope_card_size(PORTRAIT_BOARD_ENVELOPE),
		"min_card_px_landscape": envelope_card_size(LANDSCAPE_BOARD_ENVELOPE),
	}
