extends RefCounted

func test_generated_levels_are_solvable() -> void:
	var levels := [
		{"types": ["cat", "dog", "bird"], "count": 3, "layers": 2, "width": 240, "height": 200, "seed": 7},
		{"types": ["cat", "dog", "bird", "fish", "flower", "moon"], "count": 3, "layers": 3, "width": 300, "height": 240, "seed": 11},
		{"types": ["cat", "dog", "bird", "fish", "flower", "moon", "star", "sun", "leaf"], "count": 3, "layers": 3, "width": 320, "height": 260, "seed": 13},
	]
	for params in levels:
		var cards := LayoutGenerator.generate(params["types"], params["count"], params)
		var level := {
			"id": "gen",
			"clearing_capacity": 7,
			"cards": cards,
			"deck_a": [],
			"deck_b": [],
			"time_thresholds": {"three_stars": 999, "two_stars": 999},
			"rewards": [],
		}
		Assert.is_true(SolvabilityChecker.is_solvable(level), "generated layout solvable (seed %s)" % params["seed"])

func test_generated_cards_are_within_bounds_and_layered() -> void:
	var cards := LayoutGenerator.generate(["cat", "dog", "bird"], 3, {"layers": 2, "width": 240, "height": 200, "seed": 3})
	var layers := {}
	for c in cards:
		Assert.is_true(c["x"] >= 0 and c["x"] + 32 <= 240, "x in bounds")
		Assert.is_true(c["y"] >= 0 and c["y"] + 32 <= 200, "y in bounds")
		layers[c["layer"]] = true
	Assert.is_true(layers.size() >= 2, "uses multiple layers")

func test_generated_ids_are_unique() -> void:
	var cards := LayoutGenerator.generate(["cat", "dog", "bird"], 3, {"layers": 2, "width": 240, "height": 200, "seed": 5})
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
