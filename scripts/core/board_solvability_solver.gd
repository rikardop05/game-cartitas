class_name BoardSolvabilitySolver
extends RefCounted

# Pure search module for Board cards. It deliberately does not instantiate or
# mutate BoardPipeline, BoardManager, GameController, or ClearingZoneManager.
# The zone is represented canonically by type counts because resolving a trio
# removes exactly three cards of one type and preserves every other type.

const DEFAULT_CAPACITY := 7
const DEFAULT_MAX_SEARCH_NODES := 100000
const DISPLAY_CARD_SIZE := Vector2(48, 48)

var _cards: Array = []
var _ids: Array[String] = []
var _types: Array[String] = []
var _layers: Array[int] = []
var _rects: Array[Rect2] = []
var _blockers: Array = []
var _removed: Array[bool] = []
var _zone_counts: Dictionary = {}
var _zone_size := 0
var _remaining := 0
var _capacity := DEFAULT_CAPACITY
var _max_nodes := DEFAULT_MAX_SEARCH_NODES
var _nodes_visited := 0
var _peak_zone_size := 0
var _budget_exhausted := false
var _witness: Array[String] = []
var _memo: Dictionary = {}

func solve(cards: Array, clearing_capacity: int = DEFAULT_CAPACITY, max_search_nodes: int = DEFAULT_MAX_SEARCH_NODES) -> Dictionary:
	_reset()
	_capacity = clearing_capacity
	_max_nodes = max_search_nodes
	var validation := _prepare(cards)
	if not bool(validation["valid"]):
		return _result(false, false, String(validation["reason"]))
	if _max_nodes < 1:
		_budget_exhausted = true
		return _result(false, true, "search budget exhausted")
	var solved := _search()
	if solved:
		return _result(true, false, "solved")
	if _budget_exhausted:
		return _result(false, true, "search budget exhausted")
	if _remaining > 0 and _zone_size >= _capacity:
		return _result(false, false, "clearing zone is full before board victory")
	return _result(false, false, "no legal witness")

func _reset() -> void:
	_cards = []
	_ids = []
	_types = []
	_layers = []
	_rects = []
	_blockers = []
	_removed = []
	_zone_counts = {}
	_zone_size = 0
	_remaining = 0
	_nodes_visited = 0
	_peak_zone_size = 0
	_budget_exhausted = false
	_witness = []
	_memo = {}

func _prepare(cards: Array) -> Dictionary:
	_cards = cards.duplicate()
	var seen_ids := {}
	for card in _cards:
		var card_id := String(_card_value(card, "id", ""))
		if card_id.is_empty():
			return {"valid": false, "reason": "card id must not be empty"}
		if seen_ids.has(card_id):
			return {"valid": false, "reason": "card ids must be unique"}
		seen_ids[card_id] = true
		_ids.append(card_id)
		_types.append(String(_card_value(card, "type", "")))
		_layers.append(int(_card_value(card, "layer", 0)))
		_rects.append(_card_rect(card))
		_removed.append(false)
	_remaining = _cards.size()
	if _capacity < 1 and _remaining > 0:
		return {"valid": false, "reason": "clearing capacity must be positive"}
	_precompute_blockers()
	return {"valid": true, "reason": ""}

func _precompute_blockers() -> void:
	_blockers = []
	for i in _cards.size():
		var blockers_for_card: Array[int] = []
		for j in _cards.size():
			if i == j:
				continue
			if BoardSpatialRules.blocks_with_layers(_rects[i], _rects[j], _layers[i], _layers[j]):
				blockers_for_card.append(j)
		_blockers.append(blockers_for_card)

func _search() -> bool:
	if _budget_exhausted:
		return false
	if _nodes_visited >= _max_nodes:
		_budget_exhausted = true
		return false
	_nodes_visited += 1
	if _remaining == 0:
		return _zone_size == 0
	if _zone_size >= _capacity:
		_memo[_state_key()] = true
		return false
	var state_key := _state_key()
	if _memo.has(state_key):
		return false
	var actions := _ordered_actions()
	if actions.is_empty():
		_memo[state_key] = true
		return false
	for index in actions:
		var card_type := _types[index]
		var previous_count := int(_zone_counts.get(card_type, 0))
		var previous_zone_size := _zone_size
		_removed[index] = true
		_remaining -= 1
		_witness.append(_ids[index])
		# ClearingZoneManager.add happens before resolve_matches. Record that
		# transient size even when this action immediately removes a trio.
		_zone_size = previous_zone_size + 1
		_peak_zone_size = maxi(_peak_zone_size, _zone_size)
		if previous_count >= 2:
			_zone_counts.erase(card_type)
			_zone_size -= 3
		else:
			_zone_counts[card_type] = previous_count + 1
		if _search():
			return true
		_witness.pop_back()
		_removed[index] = false
		_remaining += 1
		_zone_size = previous_zone_size
		if previous_count == 0:
			_zone_counts.erase(card_type)
		else:
			_zone_counts[card_type] = previous_count
		if _budget_exhausted:
			return false
	_memo[state_key] = true
	return false

func _ordered_actions() -> Array[int]:
	var ordered: Array[int] = []
	for i in _cards.size():
		if _removed[i] or not _is_available(i):
			continue
		var insert_at := ordered.size()
		for j in ordered.size():
			if _action_precedes(i, ordered[j]):
				insert_at = j
				break
		ordered.insert(insert_at, i)
	return ordered

func _action_precedes(left: int, right: int) -> bool:
	var left_completes := int(_zone_counts.get(_types[left], 0)) >= 2
	var right_completes := int(_zone_counts.get(_types[right], 0)) >= 2
	if left_completes != right_completes:
		return left_completes
	var left_present := int(_zone_counts.get(_types[left], 0)) > 0
	var right_present := int(_zone_counts.get(_types[right], 0)) > 0
	if left_present != right_present:
		return left_present
	if _layers[left] != _layers[right]:
		return _layers[left] > _layers[right]
	if _ids[left] != _ids[right]:
		return _ids[left] < _ids[right]
	return left < right

func _is_available(index: int) -> bool:
	for blocker_index in _blockers[index]:
		if not _removed[blocker_index]:
			return false
	return true

func _state_key() -> String:
	var removed_key := ""
	for was_removed in _removed:
		removed_key += "1" if was_removed else "0"
	var type_names: Array = _zone_counts.keys()
	type_names.sort()
	var zone_key := ""
	for card_type in type_names:
		zone_key += "%s=%d;" % [String(card_type), int(_zone_counts[card_type])]
	return removed_key + "|" + zone_key

func _result(solvable: bool, budget_exhausted: bool, reason: String) -> Dictionary:
	var witness: Array[String] = []
	witness.append_array(_witness)
	return {
		"solvable": solvable,
		"witness": witness,
		"nodes_visited": _nodes_visited,
		"peak_zone_size": _peak_zone_size,
		"budget_exhausted": budget_exhausted,
		"reason": reason,
	}

func _card_value(card, key: String, fallback):
	if card is Dictionary:
		return card.get(key, fallback)
	return card.get(key) if card.get(key) != null else fallback

func _card_rect(card) -> Rect2:
	if card is Dictionary:
		if card.has("rect"):
			return Rect2(card["rect"])
		if card.has("position"):
			return Rect2(card["position"], card.get("size", DISPLAY_CARD_SIZE))
		return Rect2(Vector2(float(card.get("x", 0.0)), float(card.get("y", 0.0))), DISPLAY_CARD_SIZE)
	if card.has_method("get_display_rect"):
		return card.get_display_rect()
	return Rect2(card.get("position"), DISPLAY_CARD_SIZE)
