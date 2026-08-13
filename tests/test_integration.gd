extends RefCounted

func test_level_1_playthrough_wins_and_records_progress() -> void:
	var level: Dictionary = LevelLoader.load_level("1")
	var g := GameController.new()
	var inventory := {"hold": 3, "undo": 3, "refresh": 3}
	g.start_level(level, inventory)
	SolvabilityChecker.play_until_end(g, 500)
	Assert.is_true(g.check_victory(), "level 1 solvable to victory")
	Assert.equals(g.status, GameController.Status.WON, "status WON")
	Assert.is_true(g.stars >= 1 and g.stars <= 3, "stars in range")

	var p := ProgressManager.new()
	p.record_victory("1", g.stars, g.rewards)
	Assert.is_true(p.is_level_completed("1"), "progress recorded")
	Assert.equals(p.get_unlocked_level(), 2, "level 2 unlocked")
	Assert.equals(p.get_inventory()["hold"], 4, "hold reward applied")
