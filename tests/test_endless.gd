extends RefCounted

# Endless Mode (T6) core tests: ramp, round levels, scoring, power stock.

const BOARD_SIZE := Vector2(332, 264)

func _reset_loader() -> void:
	LevelLoader.deterministic = false

func test_difficulty_ramps_and_caps() -> void:
	var max_level := DifficultyProfile.max_level()
	Assert.equals(EndlessRun.difficulty_for_round(1), EndlessRun.START_DIFFICULTY, "round 1 starts at START_DIFFICULTY")
	Assert.equals(EndlessRun.difficulty_for_round(2), EndlessRun.START_DIFFICULTY + 1, "difficulty rises one per round")
	var prev := 0
	for n in range(1, 30):
		var d := EndlessRun.difficulty_for_round(n)
		Assert.is_true(d >= prev, "difficulty never drops at round %d" % n)
		Assert.is_true(d >= 1 and d <= max_level, "difficulty %d within profiles at round %d" % [d, n])
		prev = d
	Assert.equals(EndlessRun.difficulty_for_round(max_level), max_level, "capped at max profile")
	Assert.equals(EndlessRun.difficulty_for_round(500), max_level, "stays capped far past the max")

func test_deck_size_grows_gently() -> void:
	Assert.equals(EndlessRun.deck_card_count(1), 6, "round 1 deck is 6 cards")
	Assert.equals(EndlessRun.deck_card_count(2), 6, "round 2 deck is 6 cards")
	Assert.equals(EndlessRun.deck_card_count(3), 9, "round 3 deck is 9 cards")
	Assert.equals(EndlessRun.deck_card_count(7), 15, "round 7 reaches the cap")
	Assert.equals(EndlessRun.deck_card_count(100), 15, "deck capped at 15")

func _check_round(round_number: int) -> void:
	var run := EndlessRun.new()
	run.current_round = round_number
	var level := run.build_round_level(BOARD_SIZE)
	Assert.is_false(level.has("error"), "round %d builds a level: %s" % [round_number, str(level.get("error", ""))])
	if level.has("error"):
		return
	Assert.equals(level["id"], "endless-%d" % round_number, "round %d id" % round_number)
	Assert.equals(int(level["clearing_capacity"]), 7, "round %d capacity" % round_number)
	Assert.equals(level["rewards"], [], "round %d has no campaign rewards" % round_number)
	Assert.is_false(level.has("time_limit"), "round %d has no timeout" % round_number)
	var v: Dictionary = LevelValidator.validate(level)
	Assert.is_true(v["valid"], "round %d passes LevelValidator: %s" % [round_number, str(v["errors"])])
	Assert.is_true(SolvabilityChecker.is_solvable(level), "round %d is solvable" % round_number)
	var deck_total: int = level["deck_a"].size() + level["deck_b"].size()
	Assert.equals(deck_total, EndlessRun.deck_card_count(round_number), "round %d deck size" % round_number)
	var counts := {}
	for t in level["deck_a"] + level["deck_b"]:
		counts[t] = int(counts.get(t, 0)) + 1
	var profile := DifficultyProfile.for_level(EndlessRun.difficulty_for_round(round_number))
	for t in counts:
		Assert.equals(int(counts[t]) % 3, 0, "round %d deck type %s is a multiple of 3" % [round_number, t])
		Assert.is_true(profile.board_types.has(t), "round %d deck type %s comes from the profile" % [round_number, t])

func test_round_levels_valid_and_solvable() -> void:
	LevelLoader.deterministic = true
	_check_round(1)
	_check_round(5)
	_check_round(DifficultyProfile.max_level() + 4)
	_reset_loader()

func test_round_level_valid_with_random_seed() -> void:
	LevelLoader.deterministic = false
	_check_round(2)

func test_scoring_math() -> void:
	var run := EndlessRun.new()
	Assert.equals(run.score, 0, "score starts at 0")
	Assert.equals(run.record_match(3), 30, "a trio is worth 30")
	Assert.equals(run.score, 30, "score after one trio")
	run.record_match(6)
	Assert.equals(run.score, 90, "two trios in one move add 60")
	Assert.equals(run.record_match(0), 0, "zero matched cards score nothing")
	var done := run.complete_round()
	Assert.equals(done["bonus"], 100, "round 1 bonus is 100")
	Assert.equals(run.score, 190, "bonus added to score")
	var done2 := run.complete_round()
	Assert.equals(done2["bonus"], 200, "round 2 bonus is 200")
	Assert.equals(run.score, 390, "score after round 2 bonus")

func test_complete_round_advances_and_grants_every_three() -> void:
	var run := EndlessRun.new()
	Assert.equals(run.current_round, 1, "run starts at round 1")
	var order: Array = []
	for i in 9:
		var r := run.complete_round()
		Assert.equals(r["round"], i + 2, "round advances after clear %d" % (i + 1))
		Assert.equals(run.current_round, i + 2, "run.current_round advances after clear %d" % (i + 1))
		if (i + 1) % 3 == 0:
			Assert.equals(r["granted"].size(), 1, "grant on clear %d" % (i + 1))
			order.append(r["granted"][0]["type"])
			Assert.equals(r["granted"][0]["quantity"], 1, "grant quantity is 1")
		else:
			Assert.equals(r["granted"], [], "no grant on clear %d" % (i + 1))
	Assert.equals(order, ["hold", "undo", "refresh"], "grants rotate hold, undo, refresh")
	Assert.equals(run.rounds_cleared, 9, "rounds_cleared counts clears")
	Assert.equals(run.power_stock, {"hold": 3, "undo": 3, "refresh": 2}, "stock includes the grants")
	Assert.equals(run.complete_round()["granted"], [], "10th clear grants nothing")
	var wrap := EndlessRun.new()
	for i in 12:
		wrap.complete_round()
	Assert.equals(wrap.power_stock["hold"], 4, "rotation wraps back to hold on clear 12")

func test_end_run_result_and_progress() -> void:
	var run := EndlessRun.new()
	run.record_match(3)
	run.complete_round()
	var progress := ProgressManager.new()
	var result := run.end_run(progress)
	Assert.equals(result["score"], 130, "result score")
	Assert.equals(result["rounds_cleared"], 1, "result rounds")
	Assert.is_true(result["new_best"], "first result is a new best")
	Assert.equals(progress.endless_best, 130, "best recorded in memory")
	Assert.is_true(run.is_over, "run marked over")
	Assert.equals(run.end_run(progress), result, "end_run is idempotent")
	Assert.equals(run.record_match(3), 0, "no scoring after the run ends")
	Assert.equals(run.complete_round()["bonus"], 0, "no round clear after the run ends")
	Assert.equals(run.score, 130, "score frozen after end")
	var worse := EndlessRun.new()
	worse.record_match(3)
	Assert.is_false(worse.end_run(progress)["new_best"], "lower run is not a new best")
	Assert.is_false(EndlessRun.new().end_run()["new_best"], "no progress given means no new best")

func test_power_stock_shared_across_rounds_and_not_inventory() -> void:
	LevelLoader.deterministic = true
	var progress := ProgressManager.new()
	var inventory_before := progress.get_inventory()
	var run := EndlessRun.new()
	Assert.equals(run.power_stock, EndlessRun.START_POWER_STOCK, "start stock")
	Assert.is_false(is_same(run.power_stock, EndlessRun.START_POWER_STOCK), "the run copies the start stock instead of aliasing the constant")
	var g := GameController.new()
	g.start_level(run.build_round_level(BOARD_SIZE), run.power_stock)
	var card_id := ""
	for a in g.get_legal_actions():
		if a["action"] == "select_card":
			card_id = a["card_id"]
			break
	Assert.is_true(g.select_card(card_id)["ok"], "select a card in round 1")
	Assert.is_true(g.use_undo()["ok"], "undo in round 1")
	Assert.is_true(g.use_refresh()["ok"], "refresh in round 1")
	Assert.equals(run.power_stock["undo"], 1, "undo consumed from the run stock")
	Assert.equals(run.power_stock["refresh"], 0, "refresh consumed from the run stock")
	run.complete_round()
	var g2 := GameController.new()
	g2.start_level(run.build_round_level(BOARD_SIZE), run.power_stock)
	Assert.equals(g2.powers.get_count("undo"), 1, "round 2 starts with the reduced undo")
	Assert.equals(g2.powers.get_count("refresh"), 0, "round 2 starts with no refresh")
	Assert.equals(EndlessRun.START_POWER_STOCK, {"hold": 2, "undo": 2, "refresh": 1}, "start stock constant untouched")
	# The run's stock and the persistent inventory are separate Dictionaries: spending
	# from one must be invisible in the other (this fails if the run ever aliases it).
	Assert.is_false(is_same(run.power_stock, progress.inventory), "run stock is not the persistent inventory object")
	var undo_in_inventory := int(progress.inventory.get("undo", 0))
	progress.inventory["undo"] = undo_in_inventory + 5
	Assert.equals(run.power_stock["undo"], 1, "changing the inventory does not change the run stock")
	run.power_stock["hold"] = 0
	Assert.is_true(int(progress.inventory.get("hold", 0)) == int(inventory_before.get("hold", 0)), "spending run stock does not change the inventory")
	_reset_loader()
