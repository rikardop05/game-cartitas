extends RefCounted

func test_loaded_levels_solvable_and_multilayer() -> void:
	for id in LevelLoader.load_all_level_ids():
		var level: Dictionary = LevelLoader.load_level(id)
		Assert.is_false(level.has("error"), "level %s loads" % id)
		Assert.is_true(SolvabilityChecker.is_solvable(level), "level %s solvable" % id)
		var layers := {}
		for c in level["cards"]:
			layers[c["layer"]] = true
		Assert.is_true(layers.size() >= 2, "level %s uses multiple layers" % id)

func test_ten_levels_present() -> void:
	var ids: Array = LevelLoader.load_all_level_ids()
	Assert.is_true(ids.size() >= 10, "at least 10 levels present")
	for id in ids:
		var level: Dictionary = LevelLoader.load_level(id)
		Assert.is_false(level.has("error"), "level %s loads" % id)
		Assert.is_true(SolvabilityChecker.is_solvable(level), "level %s solvable" % id)

func test_generated_cards_are_within_bounds_and_layered() -> void:
	var card_size := 48
	var cards := LayoutGenerator.generate(["cat", "dog", "bird"], 3, {"layers": 2, "width": 240, "height": 200, "card_size": card_size, "seed": 3})
	var layers := {}
	for c in cards:
		Assert.is_true(c["x"] >= 0 and c["x"] + card_size <= 240, "x in bounds")
		Assert.is_true(c["y"] >= 0 and c["y"] + card_size <= 200, "y in bounds")
		layers[c["layer"]] = true
	Assert.is_true(layers.size() >= 2, "uses multiple layers")

func test_generated_ids_are_unique() -> void:
	var cards := LayoutGenerator.generate(["cat", "dog", "bird"], 3, {"layers": 2, "width": 240, "height": 200, "card_size": 48, "seed": 5})
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

func test_blocking_consistency_and_depth() -> void:
	for id in ["1", "2", "3", "10"]:
		var level := LevelLoader.load_level(id)
		var g := GameController.new()
		g.start_level(level, {"hold": 5, "undo": 5, "refresh": 5})
		var has_available := false
		var has_hidden := false
		for c in g.board.cards:
			var blocked := g.board.is_blocked(c)
			if blocked:
				has_hidden = true
				Assert.equals(c.state, Card.State.HIDDEN, "level %s: covered card %s hidden" % [id, c.id])
			else:
				has_available = true
				Assert.equals(c.state, Card.State.AVAILABLE, "level %s: exposed card %s available" % [id, c.id])
		Assert.is_true(has_available, "level %s has exposed cards" % id)
		Assert.is_true(has_hidden, "level %s has depth (covered cards)" % id)

func test_decks_are_mixed() -> void:
	var level := LevelLoader.load_level("1")
	var types := {}
	for t in level["deck_a"]:
		types[t] = true
	for t in level["deck_b"]:
		types[t] = true
	Assert.is_true(types.size() >= 2, "level 1 decks use more than one type")
	Assert.equals(level["deck_a"].size() + level["deck_b"].size(), 6, "level 1 deck size 6")

func _level_with_layout(randomize: bool, seed: int) -> Dictionary:
	return {
		"id": "rand",
		"clearing_capacity": 7,
		"layout": {
			"types": ["cat", "dog", "bird", "fish", "flower", "moon"],
			"count": 3,
			"layers": 2,
			"width": 240,
			"height": 200,
			"card_size": 48,
			"seed": seed,
			"randomize_per_attempt": randomize,
		},
		"deck": ["cat", "cat", "cat", "dog", "dog", "dog"],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
	}

func _card_signature(level: Dictionary) -> Array:
	var sig := []
	for c in level["cards"]:
		sig.append([str(c["type"]), int(c["x"]), int(c["y"]), int(c["layer"])])
	return sig

func test_randomized_layouts_differ_between_loads() -> void:
	var a := LevelLoader.resolve(_level_with_layout(true, 1))
	var b := LevelLoader.resolve(_level_with_layout(true, 1))
	Assert.is_false(a.has("error"), "first randomized load ok")
	Assert.is_false(b.has("error"), "second randomized load ok")
	Assert.is_true(SolvabilityChecker.is_solvable(a), "first randomized layout solvable")
	Assert.is_true(SolvabilityChecker.is_solvable(b), "second randomized layout solvable")
	Assert.not_equals(_card_signature(a), _card_signature(b), "consecutive loads produce different layouts")

func test_fixed_seed_layouts_are_identical() -> void:
	var a := LevelLoader.resolve(_level_with_layout(false, 4242))
	var b := LevelLoader.resolve(_level_with_layout(false, 4242))
	Assert.equals(_card_signature(a), _card_signature(b), "fixed seed layouts are identical")

func test_layer0_cards_align_to_grid_pitch() -> void:
	var cards := LayoutGenerator.generate(["cat", "dog", "bird"], 3, {"layers": 2, "width": 240, "height": 200, "card_size": 48, "seed": 12})
	var pitch := 48.0 * LayoutGenerator.DEFAULT_PITCH_RATIO
	var layer0 := 0
	for c in cards:
		if c["layer"] != 0:
			continue
		layer0 += 1
		var rx := fposmod(float(c["x"]), pitch)
		var ry := fposmod(float(c["y"]), pitch)
		Assert.is_true(rx < 1.0 or rx > pitch - 1.0, "layer0 x on grid pitch")
		Assert.is_true(ry < 1.0 or ry > pitch - 1.0, "layer0 y on grid pitch")
	Assert.is_true(layer0 >= 2, "enough layer0 cards to sample the grid")

func test_generated_seed_determinism() -> void:
	var a := LayoutGenerator.generate(["cat", "dog", "bird", "fish"], 3, {"layers": 2, "width": 240, "height": 200, "card_size": 48, "seed": 2024})
	var b := LayoutGenerator.generate(["cat", "dog", "bird", "fish"], 3, {"layers": 2, "width": 240, "height": 200, "card_size": 48, "seed": 2024})
	Assert.equals(_card_signature({"cards": a}), _card_signature({"cards": b}), "same seed -> identical grid")

func test_layer_overlap_coverage_max_75() -> void:
	for seed in [1, 1001, 4242, 12345, 777]:
		var cards := LayoutGenerator.generate(["cat", "dog", "bird", "fish", "flower", "moon"], 3, {"layers": 3, "width": 320, "height": 240, "card_size": 48, "seed": seed})
		var by_layer := {}
		for c in cards:
			if not by_layer.has(c["layer"]):
				by_layer[c["layer"]] = []
			by_layer[c["layer"]].append(Rect2(Vector2(c["x"], c["y"]), Vector2(48, 48)))
		for layer in by_layer:
			for rect in by_layer[layer]:
				var cov := 0.0
				for l in range(0, int(layer)):
					for lr in by_layer.get(l, []):
						cov = maxf(cov, _rect_overlap_frac(rect, lr))
				Assert.is_true(cov <= LayoutGenerator.MAX_LAYER_COVERAGE + 0.001, "seed %s: layer %s coverage <=75%% (got %.2f)" % [seed, str(layer), cov])

func test_generated_grid_blocking_compatible() -> void:
	var level := LevelLoader.resolve(_level_with_layout(false, 777))
	var g := GameController.new()
	g.start_level(level, {"hold": 5, "undo": 5, "refresh": 5})
	var has_available := false
	var has_hidden := false
	for c in g.board.cards:
		if g.board.is_blocked(c):
			has_hidden = true
			Assert.equals(c.state, Card.State.HIDDEN, "covered card hidden")
		else:
			has_available = true
			Assert.equals(c.state, Card.State.AVAILABLE, "exposed card available")
	Assert.is_true(has_available, "grid has exposed (clickable) cards")
	Assert.is_true(has_hidden, "grid has depth (covered cards)")

func _rect_overlap_frac(a: Rect2, b: Rect2) -> float:
	var ix := maxf(0.0, minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x))
	var iy := maxf(0.0, minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y))
	return (ix * iy) / maxf(1.0, 48.0 * 48.0)
