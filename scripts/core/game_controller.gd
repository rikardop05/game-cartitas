class_name GameController
extends RefCounted

const MoveResultType = preload("res://scripts/core/move_result.gd")
const LevelSnapshotType = preload("res://scripts/core/level_snapshot.gd")
const MoveResult = MoveResultType

enum Status { READY, PLAYING, PAUSED, WON, LOST }

const HOLD_COUNT := 3

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
var time_limit: float = 0.0
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
	time_limit = float(level_data.get("time_limit", 0.0))
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
	return select_card_typed(card_id).to_dict()

func select_card_typed(card_id: String) -> MoveResultType:
	if status != Status.PLAYING:
		return _make_result(false, MoveResult.Reason.NOT_PLAYING)
	var card: Card = board.get_card(card_id)
	if card == null or card.is_removed():
		return _make_result(false, MoveResult.Reason.CARD_NOT_FOUND)
	if card.state != Card.State.AVAILABLE:
		return _make_result(false, MoveResult.Reason.CARD_NOT_AVAILABLE)
	if _would_overflow(card.type):
		_lose()
		return _make_result(false, MoveResult.Reason.ZONE_OVERFLOW, true)
	_record_action({"type": "SELECT_CARD", "card_id": card_id})
	zone.add(card)
	return _resolve_and_check(card.type)

func use_deck(deck_id: String) -> Dictionary:
	return use_deck_typed(deck_id).to_dict()

func use_deck_typed(deck_id: String) -> MoveResultType:
	if status != Status.PLAYING:
		return _make_result(false, MoveResult.Reason.NOT_PLAYING)
	var deck: DeckManager = _get_deck(deck_id)
	if deck == null:
		return _make_result(false, MoveResult.Reason.DECK_INVALID)
	if deck.is_empty():
		return _make_result(false, MoveResult.Reason.DECK_EMPTY)
	var card_type: String = deck.current_type()
	if _would_overflow(card_type):
		_lose()
		return _make_result(false, MoveResult.Reason.ZONE_OVERFLOW, true)
	var drawn: String = deck.draw_type()
	var card := Card.new(_unique_id(), drawn)
	card.source = Card.Source.DECK_A if deck_id == "a" else Card.Source.DECK_B
	card.location = Card.Location.CLEARING_ZONE
	card.state = Card.State.SELECTED
	_record_action({"type": "SELECT_DECK_CARD", "deck": deck_id})
	zone.add(card)
	return _resolve_and_check(drawn)

func use_hold() -> Dictionary:
	return use_hold_typed().to_dict()

func use_hold_typed() -> MoveResultType:
	if status != Status.PLAYING:
		return _make_result(false, MoveResult.Reason.NOT_PLAYING)
	if not powers.has("hold"):
		return _make_result(false, MoveResult.Reason.NO_POWER)
	if zone.size() == 0:
		return _make_result(false, MoveResult.Reason.ZONE_EMPTY)
	powers.consume("hold")
	_record_action({"type": "USE_HOLD"})
	var taken: Array[Card] = zone.take_first(HOLD_COUNT)
	for card in taken:
		card.location = Card.Location.RESERVE
		reserve.append(card)
	return _make_result(true)

func return_from_reserve(card_id: String) -> Dictionary:
	return return_from_reserve_typed(card_id).to_dict()

func return_from_reserve_typed(card_id: String) -> MoveResultType:
	if status != Status.PLAYING:
		return _make_result(false, MoveResult.Reason.NOT_PLAYING)
	var idx := -1
	for i in reserve.size():
		if reserve[i].id == card_id:
			idx = i
			break
	if idx == -1:
		return _make_result(false, MoveResult.Reason.NOT_IN_RESERVE)
	var card: Card = reserve[idx]
	if _would_overflow(card.type):
		return _make_result(false, MoveResult.Reason.ZONE_FULL)
	reserve.remove_at(idx)
	_record_action({"type": "RETURN_FROM_RESERVE", "card_id": card_id})
	zone.add(card)
	return _resolve_and_check(card.type)

func use_undo() -> Dictionary:
	return use_undo_typed().to_dict()

func use_undo_typed() -> MoveResultType:
	if status != Status.PLAYING:
		return _make_result(false, MoveResult.Reason.NOT_PLAYING)
	if not powers.has("undo"):
		return _make_result(false, MoveResult.Reason.NO_POWER)
	if zone.size() == 0:
		return _make_result(false, MoveResult.Reason.NOTHING_TO_UNDO)
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
	return _make_result(true)

func use_refresh() -> Dictionary:
	return use_refresh_typed().to_dict()

func use_refresh_typed() -> MoveResultType:
	if status != Status.PLAYING:
		return _make_result(false, MoveResult.Reason.NOT_PLAYING)
	if not powers.has("refresh"):
		return _make_result(false, MoveResult.Reason.NO_POWER)
	powers.consume("refresh")
	_record_action({"type": "USE_REFRESH"})
	board.shuffle_positions(rng)
	deck_a.shuffle_remaining(rng)
	deck_b.shuffle_remaining(rng)
	board.recalculate_availability()
	return _make_result(true)

func check_victory() -> bool:
	return board.remaining_count() == 0 \
		and deck_a.is_empty() \
		and deck_b.is_empty() \
		and zone.size() == 0 \
		and reserve.size() == 0

func check_defeat() -> bool:
	return status == Status.LOST

func check_timeout() -> void:
	if status == Status.PLAYING and time_limit > 0.0 and timer.elapsed_seconds() > time_limit:
		_lose()

func time_remaining() -> float:
	if time_limit <= 0.0:
		return INF
	return maxf(0.0, time_limit - timer.elapsed_seconds())

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
		"time_limit": time_limit,
		"time_remaining": maxf(0.0, time_limit - timer.elapsed_seconds()) if time_limit > 0.0 else INF,
		"stars": stars,
		"legal_actions": get_legal_actions(),
	}

func snapshot() -> LevelSnapshotType:
	var snap := LevelSnapshotType.new()
	snap.status = status
	snap.level_id = level_id
	snap.board_cards = _active_board_cards()
	snap.clearing_capacity = clearing_capacity
	snap.zone_cards = zone.cards.duplicate()
	snap.reserve_cards = reserve.duplicate()
	snap.deck_a_type = deck_a.current_type()
	snap.deck_a_remaining = deck_a.remaining_count()
	snap.deck_b_type = deck_b.current_type()
	snap.deck_b_remaining = deck_b.remaining_count()
	snap.power_counts = powers.counts.duplicate()
	snap.elapsed_seconds = timer.elapsed_seconds()
	snap.time_limit = time_limit
	snap.time_remaining = time_remaining()
	snap.stars = stars
	snap.current_stars = calculate_stars(timer.elapsed_seconds())
	snap.legal_actions = get_legal_actions()
	return snap

func _active_board_cards() -> Array[Card]:
	var out: Array[Card] = []
	for c in board.cards:
		if c.location == Card.Location.BOARD and not c.is_removed():
			out.append(c)
	return out

func get_legal_actions() -> Array:
	var actions: Array = []
	if status != Status.PLAYING:
		return actions
	if not zone.is_full():
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

func _would_overflow(_card_type: String) -> bool:
	return zone.is_full()

func _resolve_and_check(card_type: String) -> MoveResultType:
	var matched: Array[Card] = zone.resolve_matches(card_type)
	board.recalculate_availability()
	_check_end()
	return _make_result(true, MoveResult.Reason.OK, false, matched.map(_card_id))

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

func _make_result(ok: bool, reason: MoveResultType.Reason = MoveResultType.Reason.OK, defeat: bool = false, matched_ids: Array = []) -> MoveResultType:
	var result := MoveResultType.new(ok, reason, status, defeat)
	for id in matched_ids:
		result.matched_ids.append(String(id))
	return result
