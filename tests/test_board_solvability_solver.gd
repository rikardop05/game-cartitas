extends RefCounted

const CARD_SIZE := Vector2(48, 48)
const SOLVER_PATH := "res://scripts/core/board_solvability_solver.gd"

func test_free_triples_produce_winning_witness() -> void:
	var cards := [
		_card("a1", "A", Vector2(0, 0)),
		_card("a2", "A", Vector2(96, 0)),
		_card("a3", "A", Vector2(192, 0)),
		_card("b1", "B", Vector2(0, 96)),
		_card("b2", "B", Vector2(96, 96)),
		_card("b3", "B", Vector2(192, 96)),
	]
	var result := _solve(cards)
	Assert.is_true(bool(result.get("solvable", false)), "free triples are solvable")
	Assert.equals(result.get("witness", []).size(), 6, "witness selects every card")
	Assert.equals(result.get("peak_zone_size", -1), 3, "peak includes transient zone.add before trio resolution")
	Assert.is_true(_replay(cards, result.get("witness", []), 7), "witness replays legally to victory")

func test_multilayer_witness_releases_lower_cards() -> void:
	var cards := _multilayer_cards()
	var result := _solve(cards)
	Assert.is_true(bool(result.get("solvable", false)), "multilayer layout is solvable")
	var witness: Array = result.get("witness", [])
	Assert.is_true(_replay(cards, witness, 7), "multilayer witness follows live availability")
	for lower_id in ["l1", "l2", "l3"]:
		var lower_index := witness.find(lower_id)
		var top_index := witness.find("t" + lower_id.substr(1))
		Assert.is_true(top_index >= 0 and top_index < lower_index, "%s is released by its top" % lower_id)

func test_zone_present_type_breaks_layer_id_tie() -> void:
	var cards := [
		_card("a1", "A", Vector2(0, 0)),
		_card("zA2", "A", Vector2(48, 0)),
		_card("zA3", "A", Vector2(96, 0)),
		_card("b0", "B", Vector2(144, 0)),
		_card("b1", "B", Vector2(192, 0)),
		_card("b2", "B", Vector2(240, 0)),
	]
	var result := _solve(cards)
	var witness: Array = result.get("witness", [])
	Assert.is_true(bool(result.get("solvable", false)), "tie-break fixture is solvable")
	Assert.equals(witness.slice(0, 3), ["a1", "zA2", "zA3"], "present type precedes absent type, then completes trio")
	Assert.is_true(_replay(cards, witness, 7), "priority witness replays")

func test_three_distinct_tops_capacity_boundary() -> void:
	var cards := _three_top_fixture()
	var too_small := _solve(cards, 2)
	Assert.is_false(bool(too_small.get("solvable", false)), "capacity 2 cannot hold three distinct tops")
	Assert.is_false(bool(too_small.get("budget_exhausted", false)), "capacity failure is not a budget failure")
	var sufficient := _solve(cards, 4)
	Assert.is_true(bool(sufficient.get("solvable", false)), "capacity 4 solves the same fixture")
	Assert.is_true(_replay(cards, sufficient.get("witness", []), 4), "capacity 4 witness replays")

func test_solver_is_deterministic_and_honest_about_budget() -> void:
	var cards := _three_top_fixture()
	var first := _solve(cards, 4)
	var second := _solve(cards, 4)
	Assert.equals(first.get("witness", []), second.get("witness", []), "same input gives same witness")
	Assert.equals(first.get("nodes_visited", -1), second.get("nodes_visited", -1), "same input gives same node count")
	var bounded := _solve(cards, 4, 1)
	Assert.is_false(bool(bounded.get("solvable", false)), "budget exhaustion never reports solvable")
	Assert.is_true(bool(bounded.get("budget_exhausted", false)), "small budget is reported honestly")

func _solve(cards: Array, capacity: int = 7, budget: int = 100000) -> Dictionary:
	var solver_script: GDScript = load(SOLVER_PATH)
	if solver_script == null or not solver_script.can_instantiate():
		return {}
	var solver: RefCounted = solver_script.new()
	return solver.solve(cards, capacity, budget)

func _card(card_id: String, card_type: String, position: Vector2, layer: int = 0) -> Dictionary:
	return {
		"id": card_id,
		"type": card_type,
		"rect": Rect2(position, CARD_SIZE),
		"layer": layer,
	}

func _multilayer_cards() -> Array:
	return [
		_card("t1", "A", Vector2(0, 0), 1),
		_card("t2", "B", Vector2(48, 0), 1),
		_card("t3", "A", Vector2(96, 0), 1),
		_card("l1", "A", Vector2(0, 0)),
		_card("l2", "B", Vector2(48, 0)),
		_card("l3", "B", Vector2(96, 0)),
	]

func _three_top_fixture() -> Array:
	return [
		_card("t1", "A", Vector2(0, 0), 1),
		_card("t2", "B", Vector2(96, 0), 1),
		_card("t3", "C", Vector2(192, 0), 1),
		_card("l1", "A", Vector2(0, 0)),
		_card("l2", "B", Vector2(24, 0)),
		_card("l3", "B", Vector2(96, 0)),
		_card("l4", "C", Vector2(120, 0)),
		_card("l5", "C", Vector2(192, 0)),
		_card("l6", "A", Vector2(216, 0)),
	]

# Independent replay model: it does not call solver helpers or mutate Board classes.
func _replay(cards: Array, witness: Array, capacity: int) -> bool:
	var active := {}
	for card in cards:
		active[String(card["id"])] = true
	var zone: Array[String] = []
	for raw_id in witness:
		var card_index := -1
		for i in cards.size():
			if String(cards[i]["id"]) == String(raw_id):
				card_index = i
				break
		if card_index < 0 or not active.get(String(raw_id), false):
			return false
		if not _available(cards, card_index, active) or zone.size() >= capacity:
			return false
		active[String(raw_id)] = false
		var card_type := String(cards[card_index]["type"])
		zone.append(card_type)
		var kept: Array[String] = []
		var matched := 0
		for zone_type in zone:
			if zone_type == card_type and matched < 3:
				matched += 1
			else:
				kept.append(zone_type)
		if matched == 3:
			zone = kept
	if not zone.is_empty():
		return false
	for remaining in active.values():
		if remaining:
			return false
	return true

func _available(cards: Array, card_index: int, active: Dictionary) -> bool:
	var target: Dictionary = cards[card_index]
	for i in cards.size():
		if i == card_index or not active.get(String(cards[i]["id"]), false):
			continue
		if BoardSpatialRules.blocks_with_layers(target["rect"], cards[i]["rect"], int(target["layer"]), int(cards[i]["layer"])):
			return false
	return true
