class_name GameController
extends RefCounted

enum Status { READY, PLAYING, PAUSED, WON, LOST }

const HOLD_COUNT := 4

var status: int = Status.READY
var level_id: String = ""
var clearing_capacity: int = 7

var board: BoardManager
var zone: ClearingZoneManager
var deck_a: DeckManager
var deck_b: DeckManager
var reserve: Array[Card] = []
var powers: PowerManager
var timer: TimerManager
var rng: RandomNumberGenerator

var time_thresholds: Dictionary = {}
var rewards: Array = []
var stars: int = 0
var action_history: Array = []

var _id_counter: int = 0

func _init() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	timer = TimerManager.new()
	powers = PowerManager.new()

func set_seed(seed_value: int) -> void:
	rng.seed = seed_value

func start_level(level_data: Dictionary, inventory: Dictionary = {}) -> void:
	level_id = str(level_data.get("id", ""))
	clearing_capacity = int(level_data.get("clearing_capacity", 7))
	time_thresholds = (level_data.get("time_thresholds", {})).duplicate()
	rewards = (level_data.get("rewards", [])).duplicate()

	var board_cards: Array[Card] = []
	for cdata in level_data.get("cards", []):
		var c := Card.new(
			str(cdata.get("id", "")),
			str(cdata.get("type", "")),
			Vector2(float(cdata.get("x", 0)), float(cdata.get("y", 0))),
			int(cdata.get("layer", 0))
		)
		c.source = Card.Source.BOARD
		c.location = Card.Location.BOARD
		board_cards.append(c)
	board = BoardManager.new(board_cards)
	board.recalculate_availability()

	zone = ClearingZoneManager.new(clearing_capacity)
	deck_a = DeckManager.new(level_data.get("deck_a", []))
	deck_b = DeckManager.new(level_data.get("deck_b", []))
	reserve.clear()
	powers = PowerManager.new(inventory)
	stars = 0
	action_history.clear()

	status = Status.PLAYING
	timer.start()

func select_card(card_id: String) -> Dictionary:
	if status != Status.PLAYING:
		return _result(false, "not_playing")
	var card: Card = board.get_card(card_id)
	if card == null or card.is_removed():
		return _result(false, "card_not_found")
	if card.state != Card.State.AVAILABLE:
		return _result(false, "card_not_available")
	if _would_overflow(card.type):
		_lose()
		return _result(false, "clearing_zone_full", true)
	_record_action({"type": "SELECT_CARD", "card_id": card_id})
	zone.add(card)
	return _resolve_and_check(card.type)

func use_deck(deck_id: String) -> Dictionary:
	if status != Status.PLAYING:
		return _result(false, "not_playing")
	var deck: DeckManager = _get_deck(deck_id)
	if deck == null:
		return _result(false, "invalid_deck")
	if deck.is_empty():
		return _result(false, "deck_empty")
	var card_type: String = deck.current_type()
	if _would_overflow(card_type):
		_lose()
		return _result(false, "clearing_zone_full", true)
	var drawn: String = deck.draw_type()
	var card := Card.new(_unique_id(), drawn)
	card.source = Card.Source.DECK_A if deck_id == "a" else Card.Source.DECK_B
	card.location = Card.Location.CLEARING_ZONE
	card.state = Card.State.SELECTED
	_record_action({"type": "SELECT_DECK_CARD", "deck": deck_id})
	zone.add(card)
	return _resolve_and_check(drawn)

func use_hold() -> Dictionary:
	if status != Status.PLAYING:
		return _result(false, "not_playing")
	if not powers.has("hold"):
		return _result(false, "no_power")
	if zone.size() == 0:
		return _result(false, "zone_empty")
	powers.consume("hold")
	_record_action({"type": "USE_HOLD"})
	var taken: Array[Card] = zone.take_last(HOLD_COUNT)
	for card in taken:
		card.location = Card.Location.RESERVE
		reserve.append(card)
	return _result(true)

func return_from_reserve(card_id: String) -> Dictionary:
	if status != Status.PLAYING:
		return _result(false, "not_playing")
	var idx := -1
	for i in reserve.size():
		if reserve[i].id == card_id:
			idx = i
			break
	if idx == -1:
		return _result(false, "card_not_in_reserve")
	var card: Card = reserve[idx]
	if _would_overflow(card.type):
		return _result(false, "zone_full")
	reserve.remove_at(idx)
	_record_action({"type": "RETURN_FROM_RESERVE", "card_id": card_id})
	zone.add(card)
	return _resolve_and_check(card.type)

func use_undo() -> Dictionary:
	if status != Status.PLAYING:
		return _result(false, "not_playing")
	if not powers.has("undo"):
		return _result(false, "no_power")
	if zone.size() == 0:
		return _result(false, "nothing_to_undo")
	powers.consume("undo")
	_record_action({"type": "USE_UNDO"})
	var card: Card = zone.remove_last()
	if card.source == Card.Source.BOARD:
		card.location = Card.Location.BOARD
		card.state = Card.State.HIDDEN
		board.recalculate_availability()
	else:
		if card.source == Card.Source.DECK_A:
			deck_a.return_type()
		else:
			deck_b.return_type()
		card.state = Card.State.REMOVED
	_check_end()
	return _result(true)

func use_refresh() -> Dictionary:
	if status != Status.PLAYING:
		return _result(false, "not_playing")
	if not powers.has("refresh"):
		return _result(false, "no_power")
	powers.consume("refresh")
	_record_action({"type": "USE_REFRESH"})
	board.shuffle_positions(rng)
	deck_a.shuffle_remaining(rng)
	deck_b.shuffle_remaining(rng)
	board.recalculate_availability()
	return _result(true)

func check_victory() -> bool:
	return board.remaining_count() == 0 \
		and deck_a.is_empty() \
		and deck_b.is_empty() \
		and zone.size() == 0 \
		and reserve.size() == 0

func check_defeat() -> bool:
	return status == Status.LOST

func calculate_stars(elapsed: float) -> int:
	var three: float = float(time_thresholds.get("three_stars", INF))
	var two: float = float(time_thresholds.get("two_stars", INF))
	if elapsed <= three:
		return 3
	if elapsed <= two:
		return 2
	return 1

func pause() -> void:
	if status == Status.PLAYING:
		status = Status.PAUSED
		timer.pause()

func resume() -> void:
	if status == Status.PAUSED:
		status = Status.PLAYING
		timer.resume()

func get_game_state() -> Dictionary:
	var available: Array = []
	var hidden: Array = []
	for c in board.cards:
		if c.is_removed() or c.location != Card.Location.BOARD:
			continue
		if c.state == Card.State.AVAILABLE:
			available.append(c.id)
		elif c.state == Card.State.HIDDEN:
			hidden.append(c.id)
	var zone_ids: Array = []
	for c in zone.cards:
		zone_ids.append(c.id)
	var reserve_ids: Array = []
	for c in reserve:
		reserve_ids.append(c.id)
	return {
		"status": status,
		"level_id": level_id,
		"available_cards": available,
		"hidden_cards": hidden,
		"clearing_zone": zone_ids,
		"reserve": reserve_ids,
		"deck_a": {"current": deck_a.current_type(), "remaining": deck_a.remaining_count()},
		"deck_b": {"current": deck_b.current_type(), "remaining": deck_b.remaining_count()},
		"powers": powers.counts.duplicate(),
		"elapsed_time": timer.elapsed_seconds(),
		"stars": stars,
		"legal_actions": get_legal_actions(),
	}

func get_legal_actions() -> Array:
	var actions: Array = []
	if status != Status.PLAYING:
		return actions
	for c in board.cards:
		if c.state == Card.State.AVAILABLE and c.location == Card.Location.BOARD and not c.is_removed():
			actions.append({"action": "select_card", "card_id": c.id})
	if not deck_a.is_empty():
		actions.append({"action": "use_deck", "deck": "a"})
	if not deck_b.is_empty():
		actions.append({"action": "use_deck", "deck": "b"})
	for r in reserve:
		actions.append({"action": "return_from_reserve", "card_id": r.id})
	if powers.has("hold") and zone.size() > 0:
		actions.append({"action": "use_hold"})
	if powers.has("undo") and zone.size() > 0:
		actions.append({"action": "use_undo"})
	if powers.has("refresh"):
		actions.append({"action": "use_refresh"})
	return actions

func _would_overflow(card_type: String) -> bool:
	return zone.is_full() and zone.count_of_type(card_type) < 2

func _resolve_and_check(card_type: String) -> Dictionary:
	var matched: Array[Card] = zone.resolve_matches(card_type)
	board.recalculate_availability()
	_check_end()
	return _result(true, "", false, matched.map(_card_id))

func _card_id(c: Card) -> String:
	return c.id

func _check_end() -> void:
	if check_victory():
		status = Status.WON
		timer.stop()
		stars = calculate_stars(timer.elapsed_seconds())

func _lose() -> void:
	status = Status.LOST
	timer.stop()

func _get_deck(deck_id: String) -> DeckManager:
	if deck_id == "a":
		return deck_a
	if deck_id == "b":
		return deck_b
	return null

func _record_action(action: Dictionary) -> void:
	action_history.append(action)

func _unique_id() -> String:
	_id_counter += 1
	return "deck_%d" % _id_counter

func _result(ok: bool, message: String = "", defeat: bool = false, matched_ids: Array = []) -> Dictionary:
	return {
		"ok": ok,
		"message": message,
		"defeat": defeat,
		"matched_ids": matched_ids,
		"status": status,
	}
