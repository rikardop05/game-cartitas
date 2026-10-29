class_name BoardSpec
extends RefCounted

# Declarative description of a board for BoardPipeline: card_count, card_size,
# board dimensions (the largest area the base layer may take), layers and
# layer_ratio, and the geometry_seed. Optional card_types and symbol_seed
# describe only the post-validation symbol assignment; decks and solvability
# remain outside BoardSpec.

var card_count: int = 0
var card_size: float = 48.0
var board_width: float = 0.0
var board_height: float = 0.0
var layers: int = 1
# Each upper layer targets about this fraction of the cards of the layer below
# (BoardPipeline.layer_targets); smaller ratios leave more cards free.
var layer_ratio: float = BoardPipeline.LAYER_RATIO
# Base-layer aspect (width / height): growth steers toward aspect_target and the base
# must end inside [aspect_min, aspect_max] (bases of up to 3 cards are exempt).
var aspect_target: float = BoardPipeline.ASPECT_TARGET
var aspect_min: float = BoardPipeline.ASPECT_MIN
var aspect_max: float = BoardPipeline.ASPECT_MAX
# Legacy alias retained for callers that still provide/read seed.
var seed: int = 0
var geometry_seed: int = 0
var symbol_seed: int = 0
var card_types: Array[String] = []

static func create(params: Dictionary) -> BoardSpec:
	var spec := BoardSpec.new()
	spec.card_count = int(params.get("card_count", 0))
	spec.card_size = float(params.get("card_size", 48.0))
	spec.board_width = float(params.get("board_width", 0.0))
	spec.board_height = float(params.get("board_height", 0.0))
	spec.layers = int(params.get("layers", 1))
	spec.layer_ratio = float(params.get("layer_ratio", BoardPipeline.LAYER_RATIO))
	spec.aspect_target = float(params.get("aspect_target", BoardPipeline.ASPECT_TARGET))
	spec.aspect_min = float(params.get("aspect_min", BoardPipeline.ASPECT_MIN))
	spec.aspect_max = float(params.get("aspect_max", BoardPipeline.ASPECT_MAX))
	var legacy_seed := int(params.get("seed", 0))
	spec.geometry_seed = int(params.get("geometry_seed", legacy_seed))
	spec.seed = spec.geometry_seed
	spec.symbol_seed = int(params.get("symbol_seed", 0))
	for raw_type in params.get("card_types", []):
		spec.card_types.append(String(raw_type).strip_edges())
	return spec

func validate() -> Dictionary:
	var errors: Array[String] = []
	if card_count < 1:
		errors.append("card_count must be >= 1")
	if card_size <= 0.0:
		errors.append("card_size must be > 0")
	if board_width < card_size or board_height < card_size:
		errors.append("board must be at least card_size in both dimensions")
	if layers < 1:
		errors.append("layers must be >= 1")
	if layer_ratio <= 0.0 or layer_ratio >= 1.0:
		errors.append("layer_ratio must be in (0, 1)")
	if aspect_min <= 0.0 or aspect_max < aspect_min or aspect_target < aspect_min or aspect_target > aspect_max:
		errors.append("aspect_target %.2f must lie within [aspect_min %.2f, aspect_max %.2f]" % [aspect_target, aspect_min, aspect_max])
	if layers > card_count:
		errors.append("layers %d cannot exceed card_count %d (each layer needs at least one card)" % [layers, card_count])
	var minimum_layer_cards := layers * (layers + 1) / 2
	if layers > 1 and card_count < minimum_layer_cards:
		errors.append("card_count %d is too small for %d strictly-decreasing positive layer counts (need >= %d)" % [card_count, layers, minimum_layer_cards])
	if not card_types.is_empty():
		if card_count % 3 != 0:
			errors.append("card_count must be a multiple of 3 when card_types are provided")
		var seen_types := {}
		for card_type in card_types:
			if card_type.is_empty():
				errors.append("card_types must not contain empty values")
			elif seen_types.has(card_type):
				errors.append("card_types must be unique: %s" % card_type)
			else:
				seen_types[card_type] = true
	if errors.is_empty():
		# The base layer sits on the full-card lattice of the board; the upper
		# layers are scattered over it on a quarter-card lattice inside its footprint.
		var lattice_columns := floori(board_width / card_size)
		var lattice_rows := floori(board_height / card_size)
		var targets := BoardPipeline.layer_targets(card_count, layers, layer_ratio)
		var base_cards := int(targets[0]) if not targets.is_empty() else card_count
		if lattice_columns * lattice_rows < base_cards:
			errors.append("card lattice %dx%d cannot hold the %d base cards" % [lattice_columns, lattice_rows, base_cards])
	return {"valid": errors.is_empty(), "errors": errors}
