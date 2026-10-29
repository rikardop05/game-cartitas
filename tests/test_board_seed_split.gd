extends RefCounted

const CARD_SIZE := 48.0
const BOARD_WIDTH := 360.0
const BOARD_HEIGHT := 280.0
const CARD_COUNT := 24
const GEOMETRY_SEED := 1001
const CARD_TYPES := ["cat", "dog", "owl"]

func test_round_robin_trios_produce_multiple_of_three_counts() -> void:
	var result := BoardPipeline.generate(_symbol_spec(GEOMETRY_SEED, 71))
	Assert.is_true(result.ok, "symbol board generates")
	var expected := {"cat": 9, "dog": 9, "owl": 6}
	Assert.equals(_card_type_counts(result.cards), expected,
		"8 trios are distributed round-robin as 9/9/6")
	for count in _card_type_counts(result.cards).values():
		Assert.equals(int(count) % 3, 0, "every final card-type count is a multiple of three")
	Assert.equals(result.metrics.get("card_type_counts", {}), expected, "metrics expose final card-type counts")
	Assert.is_true(bool(result.metrics.get("valid_card_counts", false)), "metrics validate trio counts")
	Assert.equals(int(result.metrics.get("geometry_seed_used", -1)), GEOMETRY_SEED, "geometry seed metric")
	Assert.equals(int(result.metrics.get("symbol_seed_used", -1)), 71, "symbol seed metric")

func test_symbol_seed_changes_only_type_assignment() -> void:
	var a := BoardPipeline.generate(_symbol_spec(GEOMETRY_SEED, 101))
	var b := BoardPipeline.generate(_symbol_spec(GEOMETRY_SEED, 202))
	Assert.is_true(a.ok and b.ok, "both symbol boards generate")
	Assert.equals(_geometry_signature(a.cards), _geometry_signature(b.cards),
		"same geometry_seed keeps geometry/layers/support/blocking identical")
	Assert.not_equals(_type_signature(a.cards), _type_signature(b.cards),
		"different symbol_seed changes type assignment")

func test_same_seed_pair_is_fully_deterministic() -> void:
	var a := BoardPipeline.generate(_symbol_spec(GEOMETRY_SEED, 303))
	var b := BoardPipeline.generate(_symbol_spec(GEOMETRY_SEED, 303))
	Assert.is_true(a.ok and b.ok, "both deterministic runs generate")
	Assert.equals(_complete_signature(a.cards), _complete_signature(b.cards),
		"same geometry_seed and symbol_seed reproduce the complete board")
	Assert.equals(int(a.metrics.get("geometry_seed_used", -1)), GEOMETRY_SEED, "geometry seed retained")
	Assert.equals(int(a.metrics.get("symbol_seed_used", -1)), 303, "symbol seed retained")

func test_legacy_seed_alias_matches_explicit_geometry_seed_without_symbols() -> void:
	var legacy := BoardPipeline.generate(BoardSpec.create(_base_params({"seed": GEOMETRY_SEED})))
	var explicit := BoardPipeline.generate(BoardSpec.create(_base_params({
		"geometry_seed": GEOMETRY_SEED,
		"symbol_seed": 999,
		"card_types": [],
	})))
	Assert.is_true(legacy.ok and explicit.ok, "legacy and explicit geometry-only specs generate")
	Assert.equals(_geometry_signature(legacy.cards), _geometry_signature(explicit.cards),
		"legacy seed aliases geometry_seed")
	Assert.is_true(_type_signature(legacy.cards).is_empty(), "legacy spec remains geometry-only")
	Assert.is_true(_type_signature(explicit.cards).is_empty(), "empty card_types remains geometry-only")
	Assert.equals(int(explicit.metrics.get("geometry_seed_used", -1)), GEOMETRY_SEED, "explicit geometry seed metric")
	Assert.equals(int(explicit.metrics.get("symbol_seed_used", -1)), 999, "explicit symbol seed metric is still reported")
	Assert.is_true(bool(explicit.metrics.get("valid_card_counts", false)), "geometry-only counts are valid")
	Assert.equals(explicit.metrics.get("card_type_counts", {}), {}, "geometry-only type counts are empty")

func test_symbol_assignment_preserves_geometry_only_board() -> void:
	var geometry_only := BoardPipeline.generate(BoardSpec.create(_base_params({"seed": GEOMETRY_SEED})))
	var with_symbols := BoardPipeline.generate(_symbol_spec(GEOMETRY_SEED, 404))
	Assert.is_true(geometry_only.ok and with_symbols.ok, "both corresponding boards generate")
	Assert.equals(_geometry_signature(geometry_only.cards), _geometry_signature(with_symbols.cards),
		"symbol phase does not alter geometry, layers, supports or blocking")
	Assert.equals(_type_signature(geometry_only.cards), [], "geometry-only cards have no type assignment")
	Assert.equals(_type_signature(with_symbols.cards).size(), CARD_COUNT, "symbol board assigns every card")

func test_symbol_card_count_not_multiple_of_three_is_spec_invalid() -> void:
	var params := _base_params({
		"card_count": 10,
		"geometry_seed": GEOMETRY_SEED,
		"symbol_seed": 1,
		"card_types": ["cat"],
	})
	_assert_symbol_spec_invalid(BoardSpec.create(params), "non-multiple card_count")

func test_duplicate_card_type_is_spec_invalid() -> void:
	var params := _base_params({
		"geometry_seed": GEOMETRY_SEED,
		"symbol_seed": 1,
		"card_types": ["cat", "cat"],
	})
	_assert_symbol_spec_invalid(BoardSpec.create(params), "duplicate card type")

func test_empty_card_type_is_spec_invalid() -> void:
	var params := _base_params({
		"geometry_seed": GEOMETRY_SEED,
		"symbol_seed": 1,
		"card_types": ["cat", ""],
	})
	_assert_symbol_spec_invalid(BoardSpec.create(params), "empty card type")

func _base_params(overrides: Dictionary = {}) -> Dictionary:
	var params := {
		"card_count": CARD_COUNT,
		"card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH,
		"board_height": BOARD_HEIGHT,
		"layers": 1,
	}
	params.merge(overrides, true)
	return params

func _symbol_spec(geometry_seed: int, symbol_seed: int) -> BoardSpec:
	return BoardSpec.create(_base_params({
		"geometry_seed": geometry_seed,
		"symbol_seed": symbol_seed,
		"card_types": CARD_TYPES,
	}))

func _assert_symbol_spec_invalid(spec: BoardSpec, label: String) -> void:
	var validation := spec.validate()
	Assert.is_false(validation["valid"], "%s rejected by BoardSpec" % label)
	var result := BoardPipeline.generate(spec)
	Assert.is_false(result.ok, "%s does not generate" % label)
	Assert.equals(result.error_code, BoardBuildResult.ErrorCode.SPEC_INVALID,
		"%s uses structured SPEC_INVALID" % label)
	Assert.equals(result.cards.size(), 0, "%s fails before symbol assignment" % label)
	Assert.equals(int(result.metrics.get("attempts", -1)), 0, "%s fails before geometry attempts" % label)
	Assert.is_false(bool(result.metrics.get("valid_card_counts", true)), "%s reports invalid card counts" % label)

func _card_type_counts(cards: Array) -> Dictionary:
	var counts := {}
	for card in cards:
		var card_type := str(card.get("type", ""))
		if card_type.is_empty():
			continue
		counts[card_type] = int(counts.get(card_type, 0)) + 1
	return counts

func _geometry_signature(cards: Array) -> Array:
	var signature: Array = []
	for card in cards:
		var supports: Array = []
		for support_id in card.get("support_ids", []):
			supports.append(str(support_id))
		supports.sort()
		signature.append("%s|%d|%d|%.5f|%.5f|%d|%s|%s" % [
			str(card["id"]), int(card["grid_x"]), int(card["grid_y"]),
			float(card["x"]), float(card["y"]), int(card["layer"]),
			str(supports), str(bool(card.get("blocked", false))),
		])
	signature.sort()
	return signature

func _type_signature(cards: Array) -> Array:
	var signature: Array = []
	for card in cards:
		if card.has("type"):
			signature.append("%s:%s" % [str(card["id"]), str(card["type"])])
	signature.sort()
	return signature

func _complete_signature(cards: Array) -> Array:
	var signature := _geometry_signature(cards)
	signature.append_array(_type_signature(cards))
	return signature
