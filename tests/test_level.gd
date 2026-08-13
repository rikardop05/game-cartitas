extends RefCounted

func test_loaded_levels_pass_validation() -> void:
	var ids: Array = LevelLoader.load_all_level_ids()
	Assert.is_true(ids.size() >= 2, "at least two levels found")
	for id in ids:
		var level: Dictionary = LevelLoader.load_level(id)
		Assert.is_false(level.has("error"), "level %s loads without error" % id)
		var v: Dictionary = LevelValidator.validate(level)
		Assert.is_true(v["valid"], "level %s valid: %s" % [id, str(v["errors"])])

func test_validator_rejects_bad_count() -> void:
	var level := {
		"id": "x",
		"clearing_capacity": 7,
		"cards": [
			{"id": "a", "type": "A", "x": 0, "y": 0, "layer": 0},
			{"id": "b", "type": "A", "x": 40, "y": 0, "layer": 0},
		],
		"deck_a": [],
		"deck_b": [],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
	}
	var v: Dictionary = LevelValidator.validate(level)
	Assert.is_false(v["valid"], "2 cards of type A is invalid")

func test_validator_rejects_duplicate_ids() -> void:
	var level := {
		"id": "x",
		"clearing_capacity": 7,
		"cards": [
			{"id": "a", "type": "A", "x": 0, "y": 0, "layer": 0},
			{"id": "a", "type": "B", "x": 40, "y": 0, "layer": 0},
			{"id": "c", "type": "C", "x": 80, "y": 0, "layer": 0},
		],
		"deck_a": [],
		"deck_b": [],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
	}
	Assert.is_false(LevelValidator.validate(level)["valid"], "duplicate ids invalid")
