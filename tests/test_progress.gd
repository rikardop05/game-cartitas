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

func test_rewards_granted_only_on_first_victory() -> void:
	var p := ProgressManager.new()
	var first := p.record_victory(1, 1, [{"type": "hold", "quantity": 1}])
	var replay := p.record_victory(1, 3, [{"type": "hold", "quantity": 1}])
	Assert.equals(first.size(), 1, "first win grants the reward")
	Assert.equals(replay.size(), 0, "replay grants nothing")
	Assert.equals(p.get_inventory()["hold"], 4, "hold added once")
	Assert.equals(p.get_stars(1), 3, "replay still improves stars")

func test_save_load_survives_corrupt_or_wrong_shaped_file() -> void:
	var path := "user://test_save_corrupt.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	Assert.equals(SaveManager.load(path), {}, "array root falls back to empty save")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	Assert.equals(SaveManager.load(path), {}, "invalid JSON falls back to empty save")
	Assert.is_true(SaveManager.save({"ok": true}, path), "save reports success")
	Assert.equals(SaveManager.load(path), {"ok": true}, "save overwrites the corrupt file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_stars_kept_on_replay() -> void:
	var p := ProgressManager.new()
	p.record_victory(1, 1, [])
	p.record_victory(1, 3, [])
	Assert.equals(p.get_stars(1), 3, "best stars kept")

func test_total_stars_aggregates() -> void:
	var p := ProgressManager.new()
	p.record_victory(1, 3, [])
	p.record_victory(2, 2, [])
	Assert.equals(p.total_stars(), 5, "total stars sum across levels")

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

func test_endless_unlocks_after_the_last_level() -> void:
	var last := ProgressManager.endless_unlock_level()
	Assert.equals(last, int(LevelLoader.load_all_level_ids().back()), "unlock level is the last shipped Level")
	Assert.is_true(last >= 11, "all shipped Levels count, not just the first 10")
	var p := ProgressManager.new()
	Assert.is_false(p.is_endless_unlocked(), "endless locked at start")
	for id in range(1, last):
		p.record_victory(id, 3, [])
	Assert.is_false(p.is_endless_unlocked(), "endless still locked with only the last Level missing")
	p.record_victory(last, 1, [])
	Assert.is_true(p.is_endless_unlocked(), "endless unlocked by completing the last Level")

func test_endless_best_only_improves() -> void:
	var p := ProgressManager.new()
	Assert.is_false(p.record_endless_result(0, 0), "zero score is not a best")
	Assert.is_true(p.record_endless_result(500, 3), "first score is a new best")
	Assert.is_false(p.record_endless_result(500, 9), "equal score is not a new best")
	Assert.is_false(p.record_endless_result(200, 9), "lower score is not a new best")
	Assert.equals(p.endless_best, 500, "best kept")
	Assert.equals(p.endless_best_rounds, 3, "rounds of the best run kept")
	Assert.is_true(p.record_endless_result(900, 5), "higher score is a new best")
	Assert.equals(p.endless_best_rounds, 5, "rounds follow the new best")

func test_endless_best_round_trip_and_old_save() -> void:
	var p := ProgressManager.new()
	p.record_endless_result(1234, 7)
	var path := "user://test_save_endless.json"
	Assert.is_true(SaveManager.save(p.to_dict(), path), "endless save written")
	var p2 := ProgressManager.new()
	p2.from_dict(SaveManager.load(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Assert.equals(p2.endless_best, 1234, "best score survives round trip")
	Assert.equals(p2.endless_best_rounds, 7, "best rounds survive round trip")
	var old := ProgressManager.new()
	old.from_dict({"inventory": {"hold": 1, "undo": 1, "refresh": 1}, "levels": {}, "unlocked_level": 4})
	Assert.equals(old.endless_best, 0, "old save without endless keys loads best 0")
	Assert.equals(old.endless_best_rounds, 0, "old save without endless keys loads rounds 0")
	Assert.equals(old.get_unlocked_level(), 4, "old save keeps its progress")
