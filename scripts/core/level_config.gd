class_name LevelConfig
extends RefCounted

const DEFAULT_CARD_SIZE := 48.0

# Central visual metrics (Lumen spec). Single source of truth shared by the
# generator (logical space) and the renderer (level_screen / BoardLayout).
const CARD_LOGICAL_SIZE := 48.0
# Smallest rendered board card = MIN_CARD_SCALE x CARD_LOGICAL_SIZE (30 px, a touch target).
const MIN_CARD_SCALE := 0.625
const RESERVE_CARD_SCALE := 0.80
const BOARD_PADDING := 8.0
const HEADER_HEIGHT := 40.0
const INSTRUCTION_HEIGHT := 18.0
const BOARD_MIN_HEIGHT := 200.0
const MAX_VISIBLE_LAYERS := 4

# Board envelope guardrails. Portrait is the reference layout: 360x640 logical
# viewport with a ~332x264 board area (measured after the responsive layout).
# Landscape has a dedicated UI (640x360) leaving a ~466x214 board area. Configs
# that cannot keep the minimum rendered card size are MARKED
# (fits_landscape=false), not rejected. Guardrails live here and are enforced by
# validate(): 9x6 base grid, 4 layers, 72 board cards, min rendered card size.
# Boards are wide with many small cards: the renderer never draws a board card
# larger than MAX_BOARD_CARD_PX (small boards stay centered at that size).
const PORTRAIT_BOARD_ENVELOPE := Vector2(332, 264)
const LANDSCAPE_BOARD_ENVELOPE := Vector2(466, 214)
const MAX_BOARD_CARD_PX := 40.0
const MIN_CARD_SIZE_PX := 24.0
const MAX_COLUMNS := 9
const MAX_ROWS := 6
const MAX_LAYERS := 4
const MAX_BOARD_CARDS := 72

var difficulty: int = 1
var board_types: Array[String] = []
var count_per_type: int = 3
# Optional explicit board card total (a multiple of 3). 0 = board_types x count_per_type.
# Trios are dealt to the board types in turn (as BoardPipeline assigns symbols), so
# some types hold one trio more than others while every type stays a multiple of 3.
var board_card_total: int = 0
var deck_types: Array[String] = []
# Largest base-layer grid, in whole cards: BoardPipeline grows the base inside
# columns x rows and the delivered board is cropped to what it really occupies.
var columns: int = 5
var rows: int = 5
var layers: int = 2
# Fraction of the lower layer held by each upper layer (see BoardPipeline.layer_targets).
var layer_ratio: float = BoardPipeline.LAYER_RATIO
# Base layer aspect (width / height): wide ~2:1 boards (many small cards, like the
# reference). The pipeline steers growth toward aspect_target and rejects bases
# outside [aspect_min, aspect_max] (bases of up to 3 cards are exempt); rows raise
# aspect_min (L3+) so the base cannot come out squarish.
const DEFAULT_ASPECT_TARGET := 2.0
const DEFAULT_ASPECT_MIN := 1.15
const DEFAULT_ASPECT_MAX := 2.4
var aspect_target: float = DEFAULT_ASPECT_TARGET
var aspect_min: float = DEFAULT_ASPECT_MIN
var aspect_max: float = DEFAULT_ASPECT_MAX
# Share of cards free (not blocked) at the start. The generator prefers boards
# inside [free_ratio_min, free_ratio_max] and otherwise the closest to the target.
var free_ratio: float = 0.55
var free_ratio_min: float = 0.40
var free_ratio_max: float = 0.70
var complexity: float = 1.0
var card_size: float = DEFAULT_CARD_SIZE
var seed: int = 1001
var max_attempts: int = 60

var available_card_types: Array[String] = []
var types_used_in_level: Array[String] = []

func _init() -> void:
	available_card_types = []
	for t in CardTypeRegistry.all_types():
		available_card_types.append(str(t))

# Obsolete scatter-generator keys (occupancy_h/v, overlap*, pitch_ratio) in old
# rows or JSON are ignored: BoardPipeline places cards on the half-card grid.
static func create(params: Dictionary) -> LevelConfig:
	var cfg := LevelConfig.new()
	cfg.difficulty = int(params.get("difficulty", 1))
	cfg.board_types = []
	for t in params.get("board_types", []):
		cfg.board_types.append(str(t))
	cfg.count_per_type = int(params.get("count_per_type", 3))
	cfg.board_card_total = int(params.get("board_cards", 0))
	cfg.columns = int(params.get("columns", 5))
	cfg.rows = int(params.get("rows", 5))
	cfg.layers = int(params.get("layers", 2))
	cfg.layer_ratio = float(params.get("layer_ratio", BoardPipeline.LAYER_RATIO))
	cfg.aspect_target = float(params.get("aspect_target", DEFAULT_ASPECT_TARGET))
	cfg.aspect_min = float(params.get("aspect_min", DEFAULT_ASPECT_MIN))
	cfg.aspect_max = float(params.get("aspect_max", DEFAULT_ASPECT_MAX))
	cfg.free_ratio = float(params.get("free_ratio", 0.55))
	cfg.free_ratio_min = float(params.get("free_ratio_min", cfg.free_ratio - 0.15))
	cfg.free_ratio_max = float(params.get("free_ratio_max", cfg.free_ratio + 0.15))
	cfg.complexity = float(params.get("complexity", 1.0))
	cfg.card_size = float(params.get("card_size", DEFAULT_CARD_SIZE))
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
	if board_card_total > 0:
		return board_card_total
	return board_types.size() * count_per_type

func deck_card_count() -> int:
	return deck_types.size()

func total_cards() -> int:
	return board_cards() + deck_card_count()

func board_count(type_name: String) -> int:
	var index := board_types.find(type_name)
	if index < 0:
		return 0
	if board_card_total <= 0:
		return count_per_type
	# Trio t goes to type t % types: the first (trios % types) types hold one more.
	var trios := board_card_total / 3
	return 3 * (trios / board_types.size() + (1 if index < trios % board_types.size() else 0))

func deck_count(type_name: String) -> int:
	var n := 0
	for t in deck_types:
		if t == type_name:
			n += 1
	return n

# Largest area the base grid may take (logical px); also the BoardSpec board size.
func board_width() -> float:
	return maxf(card_size, columns * card_size)

func board_height() -> float:
	return maxf(card_size, rows * card_size)

# Cards per layer, base first (the BoardPipeline pyramid distribution).
func layer_targets() -> Array:
	return BoardPipeline.layer_targets(board_cards(), layers, layer_ratio)

# Rendered card size (px) when a board of the given size (default: the largest
# allowed board) is fitted into the envelope (never above MAX_BOARD_CARD_PX).
func envelope_card_size(envelope: Vector2, size: Vector2 = Vector2.ZERO) -> float:
	var extent := size if size.x > 0.0 and size.y > 0.0 else Vector2(board_width(), board_height())
	if envelope.x <= 0.0 or envelope.y <= 0.0:
		return INF
	var scale := minf(envelope.x / extent.x, envelope.y / extent.y)
	return minf(card_size * scale, MAX_BOARD_CARD_PX)

func fits_portrait() -> bool:
	return envelope_card_size(PORTRAIT_BOARD_ENVELOPE) >= MIN_CARD_SIZE_PX

func fits_landscape() -> bool:
	return envelope_card_size(LANDSCAPE_BOARD_ENVELOPE) >= MIN_CARD_SIZE_PX

func build_spec(geometry_seed: int, symbol_seed: int) -> BoardSpec:
	return BoardSpec.create({
		"card_count": board_cards(),
		"card_size": card_size,
		"board_width": board_width(),
		"board_height": board_height(),
		"layers": layers,
		"layer_ratio": layer_ratio,
		"aspect_target": aspect_target,
		"aspect_min": aspect_min,
		"aspect_max": aspect_max,
		"geometry_seed": geometry_seed,
		"symbol_seed": symbol_seed,
		"card_types": board_types,
	})

func validate() -> Dictionary:
	var errors: Array[String] = []
	if board_types.is_empty():
		errors.append("no board types configured")
	if board_card_total <= 0 and count_per_type % 3 != 0:
		errors.append("count_per_type %d is not a multiple of 3" % count_per_type)
	if board_cards() % 3 != 0:
		errors.append("board cards %d is not a multiple of 3" % board_cards())
	if total_cards() % 3 != 0:
		errors.append("total cards %d is not a multiple of 3" % total_cards())
	if layers < 1:
		errors.append("layers must be >= 1")
	if columns < 1 or rows < 1:
		errors.append("columns and rows must be >= 1")
	if columns > MAX_COLUMNS or rows > MAX_ROWS:
		errors.append("base grid %dx%d exceeds guardrail %dx%d" % [columns, rows, MAX_COLUMNS, MAX_ROWS])
	if layers > MAX_LAYERS:
		errors.append("layers %d exceeds guardrail %d" % [layers, MAX_LAYERS])
	if board_cards() > MAX_BOARD_CARDS:
		errors.append("board cards %d exceed guardrail %d" % [board_cards(), MAX_BOARD_CARDS])
	if not board_types.is_empty() and layers >= 1 and columns >= 1 and rows >= 1:
		var spec_check := build_spec(seed, seed).validate()
		if not bool(spec_check["valid"]):
			for e in spec_check["errors"]:
				errors.append("board spec: %s" % str(e))
		else:
			var targets := layer_targets()
			if not targets.is_empty() and int(targets[0]) > columns * rows:
				errors.append("base layer needs %d cards but the %dx%d grid holds %d" % [int(targets[0]), columns, rows, columns * rows])
	if not fits_portrait():
		errors.append("config does not fit the canonical portrait envelope (rendered card %.1fpx < %dpx)" % [envelope_card_size(PORTRAIT_BOARD_ENVELOPE), int(MIN_CARD_SIZE_PX)])
	if free_ratio_min > free_ratio or free_ratio_max < free_ratio:
		errors.append("free_ratio target %.2f outside declared range [%.2f, %.2f]" % [free_ratio, free_ratio_min, free_ratio_max])
	if free_ratio_min < 0.0 or free_ratio_max > 1.0:
		errors.append("free_ratio range must lie within [0, 1]")
	for t in types_used_in_level:
		var total := board_count(t) + deck_count(t)
		if total % 3 != 0:
			errors.append("type '%s' has %d total cards (not a multiple of 3)" % [t, total])
	return {"valid": errors.is_empty(), "errors": errors}

# {"cards", "metrics", "ok", "board_width", "board_height"}; see LevelBoardGenerator.
func generate(board_size: Vector2 = Vector2.ZERO) -> Dictionary:
	return LevelBoardGenerator.generate(self, board_size)

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
		"layers": layers,
		"layer_ratio": layer_ratio,
		"aspect_target": aspect_target,
		"aspect_min": aspect_min,
		"aspect_max": aspect_max,
		"layer_targets": layer_targets(),
		"free_ratio_target": free_ratio,
		"free_ratio_min": free_ratio_min,
		"free_ratio_max": free_ratio_max,
		"complexity": complexity,
		"card_size": card_size,
		"seed": seed,
		"fits_portrait": fits_portrait(),
		"fits_landscape": fits_landscape(),
		"min_card_px_portrait": envelope_card_size(PORTRAIT_BOARD_ENVELOPE),
		"min_card_px_landscape": envelope_card_size(LANDSCAPE_BOARD_ENVELOPE),
	}
