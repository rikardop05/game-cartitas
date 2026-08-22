extends RefCounted

const LevelSnapshot = preload("res://scripts/core/level_snapshot.gd")

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
		"deck_a": ["bird", "bird", "bird"],
		"deck_b": [],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
	}

func test_snapshot_after_start() -> void:
	var g := GameController.new()
	g.start_level(_level(), {"hold": 2, "undo": 1, "refresh": 0})
	var s := g.snapshot()
	Assert.is_true(s is LevelSnapshot, "is LevelSnapshot")
	Assert.equals(s.status, GameController.Status.PLAYING, "status")
	Assert.equals(s.level_id, "1", "level id")
	Assert.equals(s.clearing_capacity, 7, "capacity")
	Assert.equals(s.board_cards.size(), 6, "board cards")
	Assert.equals(s.zone_cards.size(), 0, "zone empty")
	Assert.equals(s.reserve_cards.size(), 0, "reserve empty")
	Assert.equals(s.deck_a_type, "bird", "deck a type")
	Assert.equals(s.deck_a_remaining, 3, "deck a remaining")
	Assert.equals(s.deck_b_remaining, 0, "deck b remaining")
	Assert.equals(s.power_counts["hold"], 2, "hold count")
	Assert.equals(s.power_counts["refresh"], 0, "refresh count")
	Assert.is_true(s.time_remaining == INF, "no time limit")
	Assert.is_true(s.legal_actions.size() > 0, "legal actions present")

func test_snapshot_reflects_trio_removal() -> void:
	var g := GameController.new()
	g.start_level(_level())
	g.select_card("c1")
	g.select_card("c2")
	var s := g.snapshot()
	Assert.equals(s.zone_cards.size(), 2, "two in zone")
	g.select_card("c3")
	s = g.snapshot()
	Assert.equals(s.zone_cards.size(), 0, "zone cleared after trio")
	Assert.equals(s.board_cards.size(), 3, "three dogs remain")

func test_snapshot_reflects_hold_to_reserve() -> void:
	var g := GameController.new()
	g.start_level(_level(), {"hold": 2, "undo": 1, "refresh": 1})
	g.select_card("c1")
	g.select_card("c4")
	g.select_card("c2")
	g.use_hold()
	var s := g.snapshot()
	Assert.equals(s.zone_cards.size(), 0, "zone emptied")
	Assert.equals(s.reserve_cards.size(), 3, "three in reserve")
	Assert.equals(s.power_counts["hold"], 1, "hold consumed")

func test_snapshot_after_victory() -> void:
	var g := GameController.new()
	var level := _level()
	level["deck_a"] = []
	g.start_level(level)
	for id in ["c1", "c2", "c3", "c4", "c5", "c6"]:
		g.select_card(id)
	var s := g.snapshot()
	Assert.equals(s.status, GameController.Status.WON, "won")
	Assert.equals(s.board_cards.size(), 0, "board clear")
	Assert.is_true(s.stars >= 1 and s.stars <= 3, "stars set")

func test_snapshot_after_defeat() -> void:
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
	g.select_card("c")
	var s := g.snapshot()
	Assert.equals(s.status, GameController.Status.LOST, "lost")
	Assert.equals(s.legal_actions.size(), 0, "no legal actions")

func test_snapshot_is_read_only_copy() -> void:
	var g := GameController.new()
	g.start_level(_level())
	var s := g.snapshot()
	s.zone_cards.append(Card.new("x", "ghost"))
	Assert.equals(g.zone.size(), 0, "mutating snapshot zone does not affect controller")
	s.power_counts["hold"] = 999
	Assert.equals(g.powers.get_count("hold"), 0, "mutating snapshot powers does not affect controller")

func test_legacy_get_game_state_preserved() -> void:
	var g := GameController.new()
	g.start_level(_level(), {"hold": 2, "undo": 1, "refresh": 1})
	g.select_card("c1")
	var state: Dictionary = g.get_game_state()
	Assert.is_true(state is Dictionary, "returns dictionary")
	Assert.equals(state["status"], GameController.Status.PLAYING, "status key")
	Assert.equals(state["clearing_zone"].size(), 1, "clearing zone key")
	Assert.equals(state["deck_a"]["remaining"], 3, "deck_a nested")
	Assert.equals(state["powers"]["hold"], 2, "powers key")
