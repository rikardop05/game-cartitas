extends RefCounted

func _level(level_id: String = "1") -> Dictionary:
	return {
		"id": level_id,
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
		"rewards": [{"type": "hold", "quantity": 1}],
	}

func _small_level() -> Dictionary:
	return {
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

func test_trio_removed_on_third_select() -> void:
	var g := GameController.new()
	g.start_level(_level())
	g.select_card("c1")
	g.select_card("c2")
	var r := g.select_card("c3")
	Assert.is_true(r["ok"], "third cat accepted")
	Assert.equals(r["matched_ids"].size(), 3, "three matched")
	Assert.equals(g.zone.size(), 0, "zone empty after trio")
	Assert.equals(g.board.remaining_count(), 3, "three dogs remain")

func test_victory_when_board_cleared() -> void:
	var g := GameController.new()
	g.start_level(_level())
	for id in ["c1", "c2", "c3", "c4", "c5", "c6"]:
		g.select_card(id)
	Assert.is_true(g.check_victory(), "victory when all cleared")
	Assert.equals(g.status, GameController.Status.WON, "status WON")

func test_defeat_when_zone_full_without_match() -> void:
	var g := GameController.new()
	# An Undo in stock keeps the full zone recoverable, so the overflow path runs.
	g.start_level(_small_level(), {"undo": 1})
	g.select_card("a")
	g.select_card("b")
	var r := g.select_card("c")
	Assert.is_false(r["ok"], "selection rejected")
	Assert.is_true(r["defeat"], "defeat flagged")
	Assert.is_true(g.check_defeat(), "defeat true")
	Assert.equals(g.status, GameController.Status.LOST, "status LOST")

func test_full_zone_rejects_eighth_card_even_when_it_matches() -> void:
	var g := GameController.new()
	var level := _level()
	level["clearing_capacity"] = 3
	g.start_level(level, {"undo": 1})
	g.select_card("c1")
	g.select_card("c4")
	g.select_card("c2")
	var r := g.select_card("c3")
	Assert.is_false(r["ok"], "eighth card rejected when zone is full")
	Assert.is_true(r["defeat"], "full zone causes defeat")
	Assert.equals(g.zone.size(), 3, "zone remains at capacity")

func test_blocked_card_not_selectable() -> void:
	var g := GameController.new()
	var lvl := _level()
	lvl["cards"] = [
		{"id": "a", "type": "A", "x": 0, "y": 0, "layer": 0},
		{"id": "b", "type": "B", "x": 0, "y": 0, "layer": 1},
	]
	g.start_level(lvl)
	var r := g.select_card("a")
	Assert.is_false(r["ok"], "blocked card rejected")
	Assert.equals(r["message"], "card_not_available", "reason is not available")

func test_undo_returns_card_to_board() -> void:
	var g := GameController.new()
	g.start_level(_level(), {"hold": 1, "undo": 1, "refresh": 1})
	g.select_card("c1")
	Assert.equals(g.zone.size(), 1, "one in zone")
	var r := g.use_undo()
	Assert.is_true(r["ok"], "undo ok")
	Assert.equals(g.zone.size(), 0, "zone empty")
	Assert.equals(g.board.get_card("c1").state, Card.State.AVAILABLE, "card back available")
	Assert.equals(g.powers.get_count("undo"), 0, "undo consumed")

func test_undo_rejected_without_power() -> void:
	var g := GameController.new()
	g.start_level(_level(), {"undo": 0})
	g.select_card("c1")
	var r := g.use_undo()
	Assert.is_false(r["ok"], "undo rejected")
	Assert.equals(r["message"], "no_power", "no power reason")

func test_hold_moves_to_reserve_and_return() -> void:
	var g := GameController.new()
	g.start_level(_level(), {"hold": 2, "undo": 1, "refresh": 1})
	g.select_card("c1")
	g.select_card("c4")
	g.select_card("c2")
	Assert.equals(g.zone.size(), 3, "three in zone")
	var r := g.use_hold()
	Assert.is_true(r["ok"], "hold ok")
	Assert.equals(g.zone.size(), 0, "zone emptied")
	Assert.equals(g.reserve.size(), 3, "three in reserve")
	var rr := g.return_from_reserve("c1")
	Assert.is_true(rr["ok"], "return ok")
	Assert.equals(g.zone.size(), 1, "one back in zone")
	Assert.equals(g.reserve.size(), 2, "two left in reserve")

func test_hold_rejected_when_zone_empty() -> void:
	var g := GameController.new()
	g.start_level(_level(), {"hold": 1})
	var r := g.use_hold()
	Assert.is_false(r["ok"], "hold rejected on empty zone")
	Assert.equals(g.powers.get_count("hold"), 1, "power not consumed")

func test_hold_moves_oldest_three() -> void:
	var g := GameController.new()
	var lvl := {
		"id": "hold5",
		"clearing_capacity": 7,
		"cards": [
			{"id": "a", "type": "A", "x": 0, "y": 0, "layer": 0},
			{"id": "b", "type": "B", "x": 40, "y": 0, "layer": 0},
			{"id": "c", "type": "C", "x": 80, "y": 0, "layer": 0},
			{"id": "d", "type": "D", "x": 120, "y": 0, "layer": 0},
			{"id": "e", "type": "E", "x": 160, "y": 0, "layer": 0},
		],
		"deck_a": [],
		"deck_b": [],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
	}
	g.start_level(lvl, {"hold": 2, "undo": 1, "refresh": 1})
	for id in ["a", "b", "c", "d", "e"]:
		g.select_card(id)
	Assert.equals(g.zone.size(), 5, "five in zone")
	var r := g.use_hold()
	Assert.is_true(r["ok"], "hold ok")
	Assert.equals(g.zone.size(), 2, "two remain")
	Assert.equals(g.zone.cards[0].id, "d", "oldest remaining is d")
	Assert.equals(g.zone.cards[1].id, "e", "then e")
	Assert.equals(g.reserve.size(), 3, "three in reserve")
	Assert.equals(g.reserve[0].id, "a", "reserve keeps oldest first")
	Assert.equals(g.reserve[1].id, "b", "then b")
	Assert.equals(g.reserve[2].id, "c", "then c")

func test_refresh_shuffles_deck_deterministically() -> void:
	var lvl := _level()
	lvl["deck_a"] = ["a", "b", "c", "d", "e"]
	var g1 := GameController.new()
	g1.set_seed(12345)
	g1.start_level(lvl, {"hold": 1, "undo": 1, "refresh": 1})
	g1.use_refresh()
	var g2 := GameController.new()
	g2.set_seed(12345)
	g2.start_level(lvl, {"hold": 1, "undo": 1, "refresh": 1})
	g2.use_refresh()
	Assert.equals(g1.deck_a.card_types, g2.deck_a.card_types, "same seed -> same order")
	Assert.equals(g1.powers.get_count("refresh"), 0, "refresh consumed")

func test_stars_thresholds() -> void:
	var g := GameController.new()
	g.start_level(_level())
	Assert.equals(g.calculate_stars(30), 3, "fast -> 3 stars")
	Assert.equals(g.calculate_stars(90), 2, "mid -> 2 stars")
	Assert.equals(g.calculate_stars(300), 1, "slow -> 1 star")

func test_pause_resume() -> void:
	var g := GameController.new()
	g.start_level(_level())
	g.pause()
	Assert.equals(g.status, GameController.Status.PAUSED, "paused")
	g.resume()
	Assert.equals(g.status, GameController.Status.PLAYING, "resumed")

func test_start_level_resets_timer() -> void:
	var g := GameController.new()
	g.start_level(_level())
	g.timer.set_elapsed_seconds(42)
	g.start_level(_level("second"))
	Assert.equals(g.timer.elapsed_seconds(), 0.0, "new level starts at zero")

func test_power_consumption_persists_to_inventory() -> void:
	var inventory := {"hold": 2, "undo": 1, "refresh": 1}
	var g := GameController.new()
	g.start_level(_level(), inventory)
	g.select_card("c1")
	g.use_hold()
	Assert.equals(inventory["hold"], 1, "inventory dict reflects consumption")

func test_timeout_loses_when_limit_exceeded() -> void:
	var g := GameController.new()
	var lvl := _level()
	lvl["time_limit"] = 10
	g.start_level(lvl)
	g.timer.set_elapsed_seconds(11)
	g.check_timeout()
	Assert.equals(g.status, GameController.Status.LOST, "timeout loses")
	Assert.is_false(g.timer.is_running(), "timer stopped on timeout")

func test_no_timeout_before_limit() -> void:
	var g := GameController.new()
	var lvl := _level()
	lvl["time_limit"] = 10
	g.start_level(lvl)
	g.timer.set_elapsed_seconds(5)
	g.check_timeout()
	Assert.equals(g.status, GameController.Status.PLAYING, "still playing before limit")

func test_level_without_time_limit_never_loses_by_time() -> void:
	var g := GameController.new()
	g.start_level(_level())
	g.timer.set_elapsed_seconds(9999)
	g.check_timeout()
	Assert.equals(g.status, GameController.Status.PLAYING, "no time limit means no timeout")

func test_victory_before_limit_keeps_won() -> void:
	var g := GameController.new()
	var lvl := _level()
	lvl["time_limit"] = 100
	g.start_level(lvl)
	for id in ["c1", "c2", "c3", "c4", "c5", "c6"]:
		g.select_card(id)
	Assert.equals(g.status, GameController.Status.WON, "won before limit")
	g.timer.set_elapsed_seconds(30)
	g.check_timeout()
	Assert.equals(g.status, GameController.Status.WON, "timeout does not override win")

func test_full_zone_without_recovery_powers_loses_immediately() -> void:
	var g := GameController.new()
	g.start_level(_small_level(), {"hold": 0, "undo": 0, "refresh": 3})
	g.select_card("a")
	Assert.equals(g.status, GameController.Status.PLAYING, "one free slot left")
	g.select_card("b")
	Assert.equals(g.status, GameController.Status.LOST, "full zone with no Hold/Undo ends the level")
	Assert.equals(g.loss_reason, GameController.LossReason.ZONE_FULL, "loss reason is the full zone")
	Assert.is_false(g.timer.is_running(), "timer stopped on defeat")

func test_full_zone_with_hold_stays_playable() -> void:
	var g := GameController.new()
	g.start_level(_small_level(), {"hold": 1, "undo": 0})
	g.select_card("a")
	g.select_card("b")
	Assert.equals(g.status, GameController.Status.PLAYING, "Hold can still free the zone")
	Assert.is_true(g.use_hold()["ok"], "Hold frees the full zone")

func test_timeout_sets_loss_reason() -> void:
	var g := GameController.new()
	var lvl := _level()
	lvl["time_limit"] = 10
	g.start_level(lvl)
	g.timer.set_elapsed_seconds(11)
	g.check_timeout()
	Assert.equals(g.loss_reason, GameController.LossReason.TIMEOUT, "loss reason is the timeout")

func test_undo_deck_card_after_later_draw_was_matched() -> void:
	var g := GameController.new()
	var lvl := _level()
	lvl["deck_a"] = ["cat", "dog"]
	g.start_level(lvl, {"undo": 1})
	g.use_deck("a")
	g.use_deck("a")
	g.select_card("c4")
	g.select_card("c5")
	Assert.equals(g.zone.size(), 1, "deck dog matched with two board dogs, deck cat stays")
	Assert.is_true(g.use_undo()["ok"], "undo the deck cat")
	Assert.equals(g.deck_a.remaining_count(), 1, "one card back on deck A")
	Assert.equals(g.deck_a.current_type(), "cat", "the undone cat is back on top, not the matched dog")

func test_stars_use_whole_seconds_like_the_clock() -> void:
	var g := GameController.new()
	g.start_level(_level())
	Assert.equals(g.calculate_stars(60.0), 3, "exactly on the 3-star threshold")
	Assert.equals(g.calculate_stars(60.4), 3, "clock still shows 01:00")
	Assert.equals(g.calculate_stars(61.0), 2, "01:01 drops to 2 stars")
	Assert.equals(g.calculate_stars(120.9), 2, "02:00 keeps 2 stars")

func test_no_victory_while_deck_or_reserve_has_cards() -> void:
	var g := GameController.new()
	var lvl := _level()
	lvl["deck_b"] = ["cat"]
	g.start_level(lvl, {"hold": 1})
	for id in ["c1", "c2", "c3", "c4", "c5"]:
		g.select_card(id)
	g.use_hold()
	g.select_card("c6")
	Assert.equals(g.board.remaining_count(), 0, "board is empty")
	Assert.equals(g.status, GameController.Status.PLAYING, "reserve and deck still hold cards")
	Assert.is_false(g.check_victory(), "no victory before deck and reserve are empty")

func test_refresh_keeps_cards_and_leaves_zone_and_reserve() -> void:
	var g := GameController.new()
	g.set_seed(7)
	g.start_level(_level(), {"hold": 1, "refresh": 1})
	g.select_card("c1")
	g.select_card("c4")
	g.select_card("c2")
	g.use_hold()
	g.select_card("c5")
	var zone_ids := g.zone.cards.map(func(c): return c.id)
	var reserve_ids := g.reserve.map(func(c): return c.id)
	var board_types := []
	for c in g.board.active_cards():
		board_types.append(c.type)
	board_types.sort()
	Assert.is_true(g.use_refresh()["ok"], "refresh accepted")
	var after_types := []
	for c in g.board.active_cards():
		after_types.append(c.type)
	after_types.sort()
	Assert.equals(after_types, board_types, "same cards stay on the board")
	Assert.equals(g.zone.cards.map(func(c): return c.id), zone_ids, "zone untouched")
	Assert.equals(g.reserve.map(func(c): return c.id), reserve_ids, "reserve untouched")

func test_hold_and_refresh_rejected_without_stock() -> void:
	var g := GameController.new()
	g.start_level(_level(), {"hold": 0, "undo": 0, "refresh": 0})
	g.select_card("c1")
	Assert.equals(g.use_hold()["message"], "no_power", "hold needs stock")
	Assert.equals(g.use_refresh()["message"], "no_power", "refresh needs stock")
	Assert.equals(g.zone.size(), 1, "rejected powers change nothing")
