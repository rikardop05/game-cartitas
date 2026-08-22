extends RefCounted

const MoveResult = preload("res://scripts/core/move_result.gd")

func _level() -> Dictionary:
	return {
		"id": "1",
		"clearing_capacity": 7,
		"cards": [
			{"id": "c1", "type": "cat", "x": 0, "y": 0, "layer": 0},
			{"id": "c2", "type": "cat", "x": 40, "y": 0, "layer": 0},
			{"id": "c3", "type": "cat", "x": 80, "y": 0, "layer": 0},
			{"id": "c4", "type": "dog", "x": 0, "y": 40, "layer": 0},
			{"id": "c5", "type": "dog", "x": 40, "y": 40, "layer": 0},
			{"id": "c6", "type": "dog", "x": 80, "y": 40, "layer": 0},
		],
		"deck_a": [],
		"deck_b": [],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
	}

func test_typed_ok_result_fields() -> void:
	var g := GameController.new()
	g.start_level(_level())
	var r := g.select_card_typed("c1")
	Assert.is_true(r is MoveResult, "returns MoveResult")
	Assert.is_true(r.ok, "ok flag")
	Assert.equals(r.reason, MoveResult.Reason.OK, "reason OK")
	Assert.is_false(r.defeat, "no defeat")
	Assert.equals(r.status, GameController.Status.PLAYING, "status")
	Assert.equals(r.matched_ids.size(), 0, "no match yet")

func test_legacy_wrapper_matches_typed_dict() -> void:
	var g1 := GameController.new()
	g1.start_level(_level())
	var legacy: Dictionary = g1.select_card("c1")
	var g2 := GameController.new()
	g2.start_level(_level())
	var typed: Dictionary = g2.select_card_typed("c1").to_dict()
	Assert.equals(typed, legacy, "legacy dict equals typed to_dict")

func test_matched_ids_populated_on_trio() -> void:
	var g := GameController.new()
	g.start_level(_level())
	g.select_card("c1")
	g.select_card("c2")
	var r := g.select_card_typed("c3")
	Assert.is_true(r.ok, "trio accepted")
	Assert.equals(r.matched_ids.size(), 3, "three matched")
	Assert.equals(r.reason, MoveResult.Reason.OK, "reason OK")

func test_blocked_reason_and_legacy_message() -> void:
	var g := GameController.new()
	var lvl := _level()
	lvl["cards"] = [
		{"id": "a", "type": "A", "x": 0, "y": 0, "layer": 0},
		{"id": "b", "type": "B", "x": 0, "y": 0, "layer": 1},
	]
	g.start_level(lvl)
	var r := g.select_card_typed("a")
	Assert.is_false(r.ok, "blocked card rejected")
	Assert.equals(r.reason, MoveResult.Reason.CARD_NOT_AVAILABLE, "reason")
	Assert.equals(r.to_dict()["message"], "card_not_available", "legacy message")

func test_no_power_reason_maps_to_legacy() -> void:
	var g := GameController.new()
	g.start_level(_level(), {"undo": 0})
	g.select_card("c1")
	var r := g.use_undo_typed()
	Assert.is_false(r.ok, "undo rejected")
	Assert.equals(r.reason, MoveResult.Reason.NO_POWER, "reason")
	Assert.equals(r.to_dict()["message"], "no_power", "legacy message")

func test_zone_overflow_reason_defeat_and_legacy() -> void:
	var g := GameController.new()
	var lvl := {
		"id": "small",
		"clearing_capacity": 2,
		"cards": [
			{"id": "a", "type": "A", "x": 0, "y": 0, "layer": 0},
			{"id": "b", "type": "B", "x": 40, "y": 0, "layer": 0},
			{"id": "c", "type": "C", "x": 80, "y": 0, "layer": 0},
		],
		"deck_a": [],
		"deck_b": [],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
	}
	g.start_level(lvl)
	g.select_card("a")
	g.select_card("b")
	var r := g.select_card_typed("c")
	Assert.is_false(r.ok, "rejected")
	Assert.is_true(r.defeat, "defeat flagged")
	Assert.equals(r.reason, MoveResult.Reason.ZONE_OVERFLOW, "reason overflow")
	Assert.equals(r.to_dict()["message"], "clearing_zone_full", "legacy message")
	Assert.equals(r.status, GameController.Status.LOST, "status lost")

func test_zone_full_reason_no_defeat() -> void:
	var g := GameController.new()
	var lvl := {
		"id": "full",
		"clearing_capacity": 1,
		"cards": [
			{"id": "a", "type": "A", "x": 0, "y": 0, "layer": 0},
			{"id": "b", "type": "B", "x": 40, "y": 0, "layer": 0},
		],
		"deck_a": [],
		"deck_b": [],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
	}
	g.start_level(lvl, {"hold": 1, "undo": 1, "refresh": 1})
	g.select_card("a")
	g.use_hold()
	g.select_card("b")
	var r := g.return_from_reserve_typed("a")
	Assert.is_false(r.ok, "rejected when zone full")
	Assert.is_false(r.defeat, "no defeat for reserve return")
	Assert.equals(r.reason, MoveResult.Reason.ZONE_FULL, "reason full")
	Assert.equals(r.to_dict()["message"], "zone_full", "legacy message")

func test_deck_empty_reason() -> void:
	var g := GameController.new()
	var lvl := _level()
	lvl["deck_a"] = []
	g.start_level(lvl, {"hold": 1, "undo": 1, "refresh": 1})
	var r := g.use_deck_typed("a")
	Assert.is_false(r.ok, "deck empty rejected")
	Assert.equals(r.reason, MoveResult.Reason.DECK_EMPTY, "reason deck_empty")
