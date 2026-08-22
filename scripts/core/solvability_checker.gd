class_name SolvabilityChecker
extends RefCounted

static func is_solvable(level: Dictionary) -> bool:
	var g := GameController.new()
	g.set_seed(12345)
	g.start_level(level, {"hold": 5, "undo": 5, "refresh": 5})
	play_until_end(g, 800)
	return g.status == GameController.Status.WON

static func play_until_end(g: GameController, max_steps: int) -> void:
	var steps := 0
	while g.status == GameController.Status.PLAYING and steps < max_steps:
		steps += 1
		if not step(g):
			break

static func step(g: GameController) -> bool:
	var actions: Array = g.get_legal_actions()
	if actions.is_empty():
		return false
	for a in actions:
		if _completes_trio(g, a):
			_apply(g, a)
			return true
	if not g.zone.is_full():
		for a in actions:
			if a["action"] == "select_card" and g.zone.count_of_type(_type_of(g, a)) >= 1:
				_apply(g, a)
				return true
		for a in actions:
			if a["action"] == "select_card":
				_apply(g, a)
				return true
	for a in actions:
		if a["action"] == "use_deck" or a["action"] == "return_from_reserve":
			_apply(g, a)
			return true
	for p in ["refresh", "undo", "hold"]:
		var pa := _power_action(g, actions, p)
		if not pa.is_empty():
			_apply(g, pa)
			return true
	return false

static func _type_of(g: GameController, a: Dictionary) -> String:
	match a["action"]:
		"select_card":
			return g.board.get_card(a["card_id"]).type
		"use_deck":
			if a["deck"] == "a":
				return g.deck_a.current_type()
			return g.deck_b.current_type()
		"return_from_reserve":
			for r in g.reserve:
				if r.id == a["card_id"]:
					return r.type
	return ""

static func _completes_trio(g: GameController, a: Dictionary) -> bool:
	var t := _type_of(g, a)
	if t == "":
		return false
	return g.zone.count_of_type(t) == 2

static func _power_action(_g: GameController, actions: Array, power: String) -> Dictionary:
	for a in actions:
		if a["action"] == "use_%s" % power:
			return a
	return {}

static func _apply(g: GameController, a: Dictionary) -> void:
	match a["action"]:
		"select_card":
			g.select_card(a["card_id"])
		"use_deck":
			g.use_deck(a["deck"])
		"return_from_reserve":
			g.return_from_reserve(a["card_id"])
		"use_hold":
			g.use_hold()
		"use_undo":
			g.use_undo()
		"use_refresh":
			g.use_refresh()
