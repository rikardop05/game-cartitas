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
# Optional explicit cards per layer (base first). Empty = geometric layer_ratio.
var layer_counts: Array[int] = []
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
# Optional per-type symbol counts (type -> copies on the board). Empty = the board
# total is dealt as whole trios to card_types in turn.
var type_counts: Dictionary = {}

static func create(params: Dictionary) -> BoardSpec:
	var spec := BoardSpec.new()
	spec.card_count = int(params.get("card_count", 0))
	spec.card_size = float(params.get("card_size", 48.0))
	spec.board_width = float(params.get("board_width", 0.0))
	spec.board_height = float(params.get("board_height", 0.0))
	spec.layers = int(params.get("layers", 1))
	spec.layer_ratio = float(params.get("layer_ratio", BoardPipeline.LAYER_RATIO))
	for raw_count in params.get("layer_counts", []):
		spec.layer_counts.append(int(raw_count))
	spec.aspect_target = float(params.get("aspect_target", BoardPipeline.ASPECT_TARGET))
	spec.aspect_min = float(params.get("aspect_min", BoardPipeline.ASPECT_MIN))
	spec.aspect_max = float(params.get("aspect_max", BoardPipeline.ASPECT_MAX))
	var legacy_seed := int(params.get("seed", 0))
	spec.geometry_seed = int(params.get("geometry_seed", legacy_seed))
	spec.seed = spec.geometry_seed
	spec.symbol_seed = int(params.get("symbol_seed", 0))
	for raw_type in params.get("card_types", []):
		spec.card_types.append(String(raw_type).strip_edges())
	var raw_counts = params.get("type_counts", {})
	if raw_counts is Dictionary:
		for key in raw_counts:
			spec.type_counts[String(key).strip_edges()] = int(raw_counts[key])
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
	if not layer_counts.is_empty():
		if layer_counts.size() != layers:
			errors.append("layer_counts has %d entries for %d layers" % [layer_counts.size(), layers])
		var layer_sum := 0
		for i in layer_counts.size():
			var count := int(layer_counts[i])
			layer_sum += count
			if count < 1:
				errors.append("layer_counts must be positive")
			if i > 0 and count >= int(layer_counts[i - 1]):
				errors.append("layer_counts must decrease strictly")
		if layer_sum != card_count:
			errors.append("layer_counts add up to %d, not card_count %d" % [layer_sum, card_count])
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
	if not type_counts.is_empty():
		if card_types.is_empty():
			errors.append("type_counts requires card_types")
		else:
			var counted := 0
			for card_type in card_types:
				if not type_counts.has(card_type):
					errors.append("type_counts is missing '%s'" % card_type)
					continue
				var n := int(type_counts[card_type])
				if n < 0:
					errors.append("type_counts for '%s' must be >= 0" % card_type)
				counted += n
			for key in type_counts:
				if not card_types.has(str(key)):
					errors.append("type_counts has unknown type '%s'" % str(key))
			if counted != card_count:
				errors.append("type_counts add up to %d, not card_count %d" % [counted, card_count])
	if errors.is_empty():
		# The base layer sits on the full-card lattice of the board; the upper
		# layers are scattered over it on a quarter-card lattice inside its footprint.
		var lattice_columns := floori(board_width / card_size)
		var lattice_rows := floori(board_height / card_size)
		var targets := layer_counts.duplicate() if not layer_counts.is_empty() else BoardPipeline.layer_targets(card_count, layers, layer_ratio)
		var base_cards := int(targets[0]) if not targets.is_empty() else card_count
		if lattice_columns * lattice_rows < base_cards:
			errors.append("card lattice %dx%d cannot hold the %d base cards" % [lattice_columns, lattice_rows, base_cards])
	return {"valid": errors.is_empty(), "errors": errors}
