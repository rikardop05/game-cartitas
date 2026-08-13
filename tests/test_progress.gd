extends RefCounted

func test_default_state() -> void:
	var p := ProgressManager.new()
	Assert.equals(p.get_unlocked_level(), 1, "starts at level 1")
	Assert.is_true(p.is_level_unlocked(1), "level 1 unlocked")
	Assert.is_false(p.is_level_unlocked(2), "level 2 locked")
	Assert.equals(p.get_inventory()["hold"], 3, "default hold stock")

func test_record_victory_unlocks_next_and_rewards() -> void:
	var p := ProgressManager.new()
	p.record_victory(1, 2, [{"type": "hold", "quantity": 1}])
	Assert.is_true(p.is_level_completed(1), "level 1 completed")
	Assert.equals(p.get_stars(1), 2, "stars recorded")
	Assert.equals(p.get_unlocked_level(), 2, "level 2 unlocked")
	Assert.equals(p.get_inventory()["hold"], 4, "reward applied to inventory")

func test_stars_kept_on_replay() -> void:
	var p := ProgressManager.new()
	p.record_victory(1, 1, [])
	p.record_victory(1, 3, [])
	Assert.equals(p.get_stars(1), 3, "best stars kept")

func test_save_load_round_trip() -> void:
	var p := ProgressManager.new()
	p.record_victory(1, 3, [{"type": "undo", "quantity": 2}])
	SaveManager.save(p.to_dict(), "user://test_save.json")
	var loaded := SaveManager.load("user://test_save.json")
	var p2 := ProgressManager.new()
	p2.from_dict(loaded)
	Assert.equals(p2.get_stars(1), 3, "stars survive round trip")
	Assert.equals(p2.get_unlocked_level(), 2, "unlock survives round trip")
	Assert.equals(p2.get_inventory()["undo"], 5, "inventory survives round trip")
