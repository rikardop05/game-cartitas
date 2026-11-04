extends RefCounted

# Phase S1: Refresh no longer just reshuffles positions inside each layer -- it REDISTRIBUTES the
# board and both Support Decks. Every active board card keeps its id but gets another slot
# (position + layer, so it may move to another layer) and another type drawn from the shared pool
# of board + deck cards; the decks are refilled with their previous counts. Zone and Reserve are
# never touched.
#
# S1 seam: the public GameController.use_refresh() / use_refresh_typed() result, which also
# carries the "refresh" payload the level screen uses to animate the move.

func _level() -> Dictionary:
	return {
		"id": "refresh",
		"clearing_capacity": 7,
		"cards": [
			{"id": "b0", "type": "cat", "x": 0, "y": 0, "layer": 0},
			{"id": "b1", "type": "wolf", "x": 40, "y": 0, "layer": 0},
			{"id": "b2", "type": "owl", "x": 80, "y": 0, "layer": 0},
			{"id": "b3", "type": "cat", "x": 0, "y": 40, "layer": 1},
			{"id": "b4", "type": "wolf", "x": 40, "y": 40, "layer": 1},
			{"id": "b5", "type": "owl", "x": 80, "y": 40, "layer": 1},
		],
		"deck_a": ["boar", "fox", "gem"],
		"deck_b": ["leaf", "mouse"],
		"time_thresholds": {"three_stars": 60, "two_stars": 120},
		"rewards": [],
	}

func _controller(seed_value: int = 4242, stock: int = 1) -> GameController:
	var g := GameController.new()
	g.set_seed(seed_value)
	g.start_level(_level(), {"hold": 1, "undo": 1, "refresh": stock})
	return g

# Types of every card still in play across the board and the two decks, sorted.
func _pool_types(g: GameController) -> Array:
	var types: Array = []
	for c in g.board.active_cards():
		types.append(c.type)
	for t in g.deck_a.card_types.slice(g.deck_a.current_index):
		types.append(str(t))
	for t in g.deck_b.card_types.slice(g.deck_b.current_index):
		types.append(str(t))
	types.sort()
	return types

# id -> "position|layer|type", to compare two arrangements.
func _layout(g: GameController) -> Dictionary:
	var out := {}
	for c in g.board.active_cards():
		out[c.id] = "%s|%d|%s" % [str(c.position), c.layer, c.type]
	return out

func _available_count(g: GameController) -> int:
	var n := 0
	for c in g.board.active_cards():
		if c.state == Card.State.AVAILABLE:
			n += 1
	return n

# --- The redistribution ---------------------------------------------------------------------

func test_refresh_really_moves_board_cards_across_layers_and_types() -> void:
	var g := _controller()
	var before := _layout(g)
	Assert.is_true(g.use_refresh()["ok"], "refresh accepted")
	var after := _layout(g)
	var moved_slot := 0
	var changed_layer := 0
	var changed_type := 0
	for id in before.keys():
		var b: PackedStringArray = str(before[id]).split("|")
		var a: PackedStringArray = str(after[id]).split("|")
		if b[0] != a[0] or b[1] != a[1]:
			moved_slot += 1
		if b[1] != a[1]:
			changed_layer += 1
		if b[2] != a[2]:
			changed_type += 1
	Assert.is_true(moved_slot > 0, "some card lands on another slot (%d of %d)" % [moved_slot, before.size()])
	Assert.is_true(changed_layer > 0, "at least one card changes layer (%d)" % changed_layer)
	Assert.is_true(changed_type > 0, "at least one board card changes type (%d)" % changed_type)

func test_refresh_keeps_counts_ids_and_the_whole_type_multiset() -> void:
	var g := _controller()
	var types_before := _pool_types(g)
	var ids_before: Array = g.board.active_cards().map(func(c): return c.id)
	var result := g.use_refresh()
	Assert.is_true(result["ok"], "refresh accepted")
	Assert.equals(_pool_types(g), types_before, "board + both decks keep exactly the same types")
	Assert.equals(g.board.remaining_count(), ids_before.size(), "the board still holds the same number of cards")
	Assert.equals(g.deck_a.remaining_count(), 3, "deck a keeps its count")
	Assert.equals(g.deck_b.remaining_count(), 2, "deck b keeps its count")
	var ids_after: Array = g.board.active_cards().map(func(c): return c.id)
	ids_after.sort()
	ids_before.sort()
	Assert.equals(ids_after, ids_before, "every card id is still on the board")

func test_refresh_leaves_the_zone_and_the_reserve_alone() -> void:
	var g := _controller()
	g.select_card("b3")
	g.select_card("b4")
	g.use_hold()
	var zone_ids := g.zone.cards.map(func(c): return c.id)
	var reserve_ids := g.reserve.map(func(c): return c.id)
	Assert.is_true(g.use_refresh()["ok"], "refresh accepted")
	Assert.equals(g.zone.cards.map(func(c): return c.id), zone_ids, "zone untouched")
	Assert.equals(g.reserve.map(func(c): return c.id), reserve_ids, "reserve untouched")

func test_refresh_reports_the_state_before_it_moved() -> void:
	var g := _controller()
	var before := _layout(g)
	var deck_a_before := g.deck_a.remaining_count()
	var deck_b_before := g.deck_b.remaining_count()
	var result := g.use_refresh()
	var refresh: Dictionary = result.get("refresh", {})
	Assert.is_true(not refresh.is_empty(), "the result carries the refresh payload")
	var board_before: Dictionary = refresh.get("board_before", {})
	Assert.equals(board_before.size(), before.size(), "the payload lists every board card")
	for id in before.keys():
		Assert.is_true(board_before.has(id), "%s is in the payload" % id)
		if not board_before.has(id):
			continue
		var entry: Dictionary = board_before[id]
		var parts: PackedStringArray = str(before[id]).split("|")
		Assert.equals(str(entry.get("type", "")), parts[2], "%s keeps its old type in the payload" % id)
		Assert.equals(int(entry.get("layer", -1)), int(parts[1]), "%s keeps its old layer in the payload" % id)
		var position: Vector2 = entry.get("position", Vector2(-1, -1))
		var rect := Rect2(position, Card.DISPLAY_SIZE)
		Assert.is_true(entry.get("position") is Vector2, "%s carries a Vector2 position" % id)
		Assert.is_true(rect.size.x > 0.0, "%s carries a usable rect" % id)
	Assert.equals(int(refresh.get("deck_a_before", -1)), deck_a_before, "deck a count before is reported")
	Assert.equals(int(refresh.get("deck_b_before", -1)), deck_b_before, "deck b count before is reported")

# --- Determinism and the availability/blocker index -------------------------------------------

func test_refresh_is_deterministic_for_the_same_seed_and_state() -> void:
	var a := _controller(777)
	var b := _controller(777)
	a.use_refresh()
	b.use_refresh()
	Assert.equals(_layout(a), _layout(b), "same seed and state give the same redistribution")
	Assert.equals(a.deck_a.card_types, b.deck_a.card_types, "deck a matches")
	Assert.equals(a.deck_b.card_types, b.deck_b.card_types, "deck b matches")
	var c := _controller(778)
	var untouched := _layout(c)
	c.use_refresh()
	Assert.is_true(_layout(c) != untouched, "another seed still redistributes")
	Assert.is_true(_layout(c) != _layout(a), "a different seed gives a different arrangement")

func test_refresh_recalculates_availability_and_the_blocker_index() -> void:
	var g := _controller()
	Assert.is_true(g.use_refresh()["ok"], "refresh accepted")
	Assert.is_true(_available_count(g) > 0, "the refresh leaves at least one playable card")
	# The cached blocker index was rebuilt for the new positions/layers.
	for c in g.board.active_cards():
		if c.state == Card.State.AVAILABLE:
			Assert.is_false(g.board.is_blocked(c), "%s is available and not blocked" % c.id)
		elif c.state == Card.State.HIDDEN:
			Assert.is_true(g.board.is_blocked(c), "%s is hidden because something covers it" % c.id)

func test_refresh_prefers_a_playable_board_on_a_real_level() -> void:
	# A real generated board has enough duplicate types for the preference to be satisfiable, so
	# the refresh must land on an arrangement the player can actually use.
	var level: Dictionary = LevelLoader.load_level("8", Vector2.ZERO)
	level.erase("error")
	var g := GameController.new()
	g.set_seed(99001)
	g.start_level(level, {"hold": 2, "undo": 2, "refresh": 1})
	Assert.is_true(g.use_refresh()["ok"], "refresh accepted on a real board")
	Assert.is_true(_available_count(g) > 0, "at least one card is available after the refresh")
	# A reachable triple: some type with 3 copies among available board cards, deck remainders,
	# the Reserve and the zone.
	var reachable := {}
	for c in g.board.active_cards():
		if c.state == Card.State.AVAILABLE:
			reachable[c.type] = int(reachable.get(c.type, 0)) + 1
	for t in g.deck_a.card_types.slice(g.deck_a.current_index):
		reachable[str(t)] = int(reachable.get(str(t), 0)) + 1
	for t in g.deck_b.card_types.slice(g.deck_b.current_index):
		reachable[str(t)] = int(reachable.get(str(t), 0)) + 1
	var best := 0
	var best_type := ""
	for t in reachable:
		if int(reachable[t]) > best:
			best = int(reachable[t])
			best_type = str(t)
	Assert.is_true(best >= 3, "a triple is reachable after a refresh (best: %s x%d)" % [best_type, best])

func test_refresh_without_stock_changes_nothing() -> void:
	var g := _controller(4242, 0)
	var before := _layout(g)
	var result := g.use_refresh()
	Assert.equals(result["message"], "no_power", "refresh needs stock")
	Assert.equals(_layout(g), before, "a rejected refresh leaves the board alone")
	Assert.is_true(result.get("refresh", {}).is_empty(), "a rejected refresh carries no payload")

# --- Solver compatibility (generation depends on the old simulation) --------------------------

func test_legacy_rule_keeps_the_solver_simulation_identical() -> void:
	var g := _controller()
	g.refresh_rule = GameController.REFRESH_POSITION_SHUFFLE
	var types_before := _pool_types(g)
	var before := _layout(g)
	var result := g.use_refresh()
	Assert.is_true(result["ok"], "the legacy refresh is accepted")
	Assert.equals(_pool_types(g), types_before, "the legacy refresh never moves types between board and decks")
	var moved := 0
	for id in before.keys():
		if str(before[id]) != str(_layout(g).get(id, "")):
			moved += 1
	Assert.is_true(moved > 0, "the legacy refresh still moves cards inside their layer")
