extends RefCounted

func test_level_1_playthrough_wins_and_records_progress() -> void:
	var level: Dictionary = LevelLoader.load_level("1")
	var g := GameController.new()
	var inventory := {"hold": 3, "undo": 3, "refresh": 3}
	g.start_level(level, inventory)
	var guard := 0
	while g.status == GameController.Status.PLAYING and guard < 200:
		guard += 1
		var acted := false
		for a in g.get_legal_actions():
			match a["action"]:
				"select_card":
					g.select_card(a["card_id"])
					acted = true
				"use_deck":
					g.use_deck(a["deck"])
					acted = true
				"return_from_reserve":
					g.return_from_reserve(a["card_id"])
					acted = true
			if acted:
				break
		if not acted:
			break
	Assert.is_true(g.check_victory(), "level 1 solvable to victory")
	Assert.equals(g.status, GameController.Status.WON, "status WON")
	Assert.is_true(g.stars >= 1 and g.stars <= 3, "stars in range")

	var p := ProgressManager.new()
	p.record_victory("1", g.stars, g.rewards)
	Assert.is_true(p.is_level_completed("1"), "progress recorded")
	Assert.equals(p.get_unlocked_level(), 2, "level 2 unlocked")
	Assert.equals(p.get_inventory()["hold"], 4, "hold reward applied")
