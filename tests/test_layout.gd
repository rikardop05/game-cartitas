extends RefCounted

func test_loaded_levels_solvable_and_multilayer() -> void:
	for id in ["1", "2", "3"]:
		var level: Dictionary = LevelLoader.load_level(id)
		Assert.is_false(level.has("error"), "level %s loads" % id)
		Assert.is_true(SolvabilityChecker.is_solvable(level), "level %s solvable" % id)
		var layers := {}
		for c in level["cards"]:
			layers[c["layer"]] = true
		Assert.is_true(layers.size() >= 2, "level %s uses multiple layers" % id)

func test_generated_cards_are_within_bounds_and_layered() -> void:
	var card_size := 64
	var cards := LayoutGenerator.generate(["cat", "dog", "bird"], 3, {"layers": 2, "width": 240, "height": 200, "card_size": card_size, "seed": 3})
	var layers := {}
	for c in cards:
		Assert.is_true(c["x"] >= 0 and c["x"] + card_size <= 240, "x in bounds")
		Assert.is_true(c["y"] >= 0 and c["y"] + card_size <= 200, "y in bounds")
		layers[c["layer"]] = true
	Assert.is_true(layers.size() >= 2, "uses multiple layers")

func test_generated_ids_are_unique() -> void:
	var cards := LayoutGenerator.generate(["cat", "dog", "bird"], 3, {"layers": 2, "width": 240, "height": 200, "card_size": 64, "seed": 5})
	var ids := {}
	for c in cards:
		Assert.is_false(ids.has(c["id"]), "unique id")
		ids[c["id"]] = true

func test_load_level_generates_cards() -> void:
	var level := LevelLoader.load_level("2")
	Assert.is_false(level.has("error"), "level 2 loads")
	Assert.is_false(level.has("layout"), "layout resolved")
	Assert.is_true(level["cards"].size() >= 12, "cards generated")
	var v := LevelValidator.validate(level)
	Assert.is_true(v["valid"], "generated level valid: %s" % str(v["errors"]))

func test_no_exposed_lower_layer_cards() -> void:
	for id in ["1", "2", "3"]:
		var level := LevelLoader.load_level(id)
		var g := GameController.new()
		g.start_level(level, {"hold": 5, "undo": 5, "refresh": 5})
		var max_layer := 0
		for c in g.board.cards:
			max_layer = maxi(max_layer, c.layer)
		for c in g.board.cards:
			if c.layer < max_layer:
				Assert.equals(c.state, Card.State.HIDDEN, "level %s: lower-layer card %s must be blocked" % [id, c.id])

func test_decks_are_mixed() -> void:
	var level := LevelLoader.load_level("1")
	var types := {}
	for t in level["deck_a"]:
		types[t] = true
	for t in level["deck_b"]:
		types[t] = true
	Assert.is_true(types.size() >= 2, "level 1 decks use more than one type")
	Assert.equals(level["deck_a"].size() + level["deck_b"].size(), 6, "level 1 deck size 6")
