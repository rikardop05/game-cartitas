class_name SolvabilityChecker
extends RefCounted

static func is_solvable(level: Dictionary) -> bool:
	var g := GameController.new()
	g.set_seed(12345)
	# Phase S1: the generator was validated against the pre-S1 positional shuffle, so the solver
	# keeps simulating exactly that (see GameController.REFRESH_POSITION_SHUFFLE). Changing it
	# here would rewrite every generated board.
	g.refresh_rule = GameController.REFRESH_POSITION_SHUFFLE
	g.start_level(level, {"hold": 5, "undo": 5, "refresh": 5})
	play_until_end(g, 800)
	return g.status == GameController.Status.WON

static func play_until_end(g: GameController, max_steps: int) -> void:
	# Phase S1: the solver keeps simulating the pre-S1 positional shuffle (see is_solvable), so
	# every caller of the solver sees exactly the behaviour the generator was tuned against.
	g.refresh_rule = GameController.REFRESH_POSITION_SHUFFLE
	var steps := 0
	while g.status == GameController.Status.PLAYING and steps < max_steps:
		steps += 1
		if not step(g):
			break

static func step(g: GameController) -> bool:
	# Mirrors GameController.get_legal_actions() order exactly, but without building a
	# Dictionary per card: the solver runs up to 800 steps on every generated board.
	var zone_full := g.zone.is_full()
	if not zone_full:
		if _apply_completing_trio(g):
			return true
		if _apply_pairing(g):
			return true
		# Start a trio with a Support Deck card only when the zone can hold the two
		# cards still needed (board + the second deck card) and that type's board card
		# is actually available.
		if g.zone.size() + 3 <= g.clearing_capacity and _apply_deck_starter(g):
			return true
		if _apply_most_available(g):
			return true
		if _apply_first_support(g):
			return true
	for power in ["refresh", "undo", "hold"]:
		if g.powers.has(power) and (power == "refresh" or g.zone.size() > 0):
			_apply_power(g, power)
			return true
	return false

static func _is_board_available(card: Card) -> bool:
	return card.state == Card.State.AVAILABLE and card.location == Card.Location.BOARD and not card.is_removed()

# Same candidate order as get_legal_actions(): board cards in board order, then deck a,
# then deck b, then the Reserve.
static func _apply_completing_trio(g: GameController) -> bool:
	for card in g.board.cards:
		if _is_board_available(card) and g.zone.count_of_type(card.type) == 2:
			g.select_card(card.id)
			return true
	if not g.deck_a.is_empty() and g.zone.count_of_type(g.deck_a.current_type()) == 2:
		g.use_deck("a")
		return true
	if not g.deck_b.is_empty() and g.zone.count_of_type(g.deck_b.current_type()) == 2:
		g.use_deck("b")
		return true
	for card in g.reserve:
		if g.zone.count_of_type(card.type) == 2:
			g.return_from_reserve(card.id)
			return true
	return false

static func _apply_pairing(g: GameController) -> bool:
	for card in g.board.cards:
		if _is_board_available(card) and g.zone.count_of_type(card.type) == 1:
			g.select_card(card.id)
			return true
	if not g.deck_a.is_empty() and g.zone.count_of_type(g.deck_a.current_type()) == 1:
		g.use_deck("a")
		return true
	if not g.deck_b.is_empty() and g.zone.count_of_type(g.deck_b.current_type()) == 1:
		g.use_deck("b")
		return true
	for card in g.reserve:
		if g.zone.count_of_type(card.type) == 1:
			g.return_from_reserve(card.id)
			return true
	return false

static func _apply_deck_starter(g: GameController) -> bool:
	if not g.deck_a.is_empty():
		var type_a := g.deck_a.current_type()
		if g.zone.count_of_type(type_a) == 0 and _board_has_available(g, type_a):
			g.use_deck("a")
			return true
	if not g.deck_b.is_empty():
		var type_b := g.deck_b.current_type()
		if g.zone.count_of_type(type_b) == 0 and _board_has_available(g, type_b):
			g.use_deck("b")
			return true
	return false

static func _apply_first_support(g: GameController) -> bool:
	if not g.deck_a.is_empty():
		g.use_deck("a")
		return true
	if not g.deck_b.is_empty():
		g.use_deck("b")
		return true
	if not g.reserve.is_empty():
		g.return_from_reserve(g.reserve[0].id)
		return true
	return false

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

static func _apply_most_available(g: GameController) -> bool:
	var available := _available_by_type(g)
	var best: Card = null
	var best_count := -1
	for card in g.board.cards:
		if not _is_board_available(card):
			continue
		var n := int(available.get(card.type, 0))
		if n > best_count:
			best_count = n
			best = card
	if best == null:
		return false
	g.select_card(best.id)
	return true

static func _apply_power(g: GameController, power: String) -> void:
	match power:
		"refresh":
			g.use_refresh()
		"undo":
			g.use_undo()
		"hold":
			g.use_hold()
