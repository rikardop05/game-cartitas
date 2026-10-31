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
		# Pair up with a type already in the zone (board card, deck card or Reserve card).
		for a in actions:
			if g.zone.count_of_type(_type_of(g, a)) == 1:
				_apply(g, a)
				return true
		# Start a trio with a Support Deck card only when the zone can hold the two
		# cards still needed (board + the second deck card) and that type's board card
		# is actually available. This is what lets the last single board card of a type
		# pair with its two support cards instead of piling up with other singles.
		if g.zone.size() + 3 <= g.clearing_capacity:
			for a in actions:
				if a["action"] == "use_deck":
					var deck_type := _type_of(g, a)
					if g.zone.count_of_type(deck_type) == 0 and _board_has_available(g, deck_type):
						_apply(g, a)
						return true
		var available := _available_by_type(g)
		var best: Dictionary = {}
		var best_count := -1
		for a in actions:
			if a["action"] != "select_card":
				continue
			var t := _type_of(g, a)
			var n := int(available.get(t, 0))
			if n > best_count:
				best_count = n
				best = a
		if not best.is_empty():
			_apply(g, best)
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

static func _available_by_type(g: GameController) -> Dictionary:
	var counts := {}
	for card in g.board.cards:
		if card.state == Card.State.AVAILABLE and card.location == Card.Location.BOARD:
			counts[card.type] = int(counts.get(card.type, 0)) + 1
	return counts

static func _board_has_available(g: GameController, card_type: String) -> bool:
	for card in g.board.cards:
		if card.type == card_type and card.state == Card.State.AVAILABLE and card.location == Card.Location.BOARD:
			return true
	return false

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
