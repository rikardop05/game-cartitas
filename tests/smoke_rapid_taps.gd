extends SceneTree

# Rapid-tap smoke test, driven through the real level scene: every tap on a card, deck pile,
# Reserve card or power is applied to the controller at once, even while earlier moves are
# still animating, and the visuals (ghosts, hidden slots, match flash) always settle into a
# consistent zone. Scenarios: two then three non-matching taps in the same frame, a match
# made by rapid taps with other cards in flight (the zone compacts under a flying card),
# Undo / Hold / Reserve return while ghosts are in the air, the end panel waiting for the
# visuals, and a UI rebuild mid-animation.
#
# The scenes save through Game.save_path, which is pointed at a throwaway user:// file before
# anything runs; the real save is also backed up and checked byte-for-byte (see smoke_endless).

const STEP_TIMEOUT_MS := 20000
const THROWAWAY_SAVE := "user://smoke_rapid_taps_save.json"
const EMPTY_SLOT_COLOR := Color(0.48, 0.22, 0.05, 0.34)

var _failures: Array[String] = []
var _save_before: Dictionary
var _game

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_save_before = _snapshot_save()
	LevelLoader.deterministic = true
	var game = root.get_node_or_null("Game")
	if game == null:
		_fail("Game autoload not available")
	else:
		_game = game
		# First thing: nothing below may write to the real save.
		game.save_path = THROWAWAY_SAVE
		_remove_throwaway_save()
		await _scenarios(game)
		# Leave the level and let its audio finish before the engine quits (no leaked playbacks).
		change_scene_to_file("res://scenes/main.tscn")
		await create_timer(0.6).timeout
	_finish()

func _scenarios(game) -> void:
	game.progress = ProgressManager.new()
	game.endless_run = null
	game.current_level_id = "1"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level(null)
	if scene == null:
		return

	# --- Two taps, then a third while the first two are still flying (no match) ---------
	print("rapid taps: two + one non-matching taps")
	var c: GameController = scene.controller
	var types := _types_by_count(c)
	if types.size() < 2:
		_fail("level 1 offers fewer than two card types to tap")
		return
	var a_type: String = types[0]
	var b_type: String = types[1]
	var c_type: String = types[2] if types.size() > 2 else a_type
	var ids: Array = []
	_tap(scene, a_type, ids)
	_tap(scene, b_type, ids)
	_check(c.zone.size() == 2 and _zone_ids(c) == ids, "two taps in one frame both landed in the zone (zone %s, tapped %s)" % [str(_zone_ids(c)), str(ids)])
	_check(not scene.visuals_settled(), "ghosts are still in flight right after the taps")
	_check(_zone_alpha(scene, 0) == 0.0 and _zone_alpha(scene, 1) == 0.0, "zone slots of the two flying cards are hidden until their ghosts land")
	await process_frame
	await process_frame
	_check(not scene.visuals_settled(), "animations are still running two frames later")
	_tap(scene, c_type, ids)
	_check(c.zone.size() == 3 and _zone_ids(c) == ids, "a third tap during the animations also landed (zone %s, tapped %s)" % [str(_zone_ids(c)), str(ids)])
	_check(_zone_alpha(scene, 2) == 0.0, "the third flying card's slot is hidden too")
	if not await _settle(scene):
		return
	_check_zone_clean(scene, [a_type, b_type, c_type], "after three non-matching taps")
	_check(scene.match_flashes == 0, "no match flash for non-matching taps")
	if not _failures.is_empty():
		return

	# --- Match by rapid taps, compaction under a flying card ------------------------------
	# T X T T: the match removes the first and third cards, so X shifts from slot 1 to slot 0
	# while its ghost is still flying, and the first T is matched while it is still in the air.
	print("rapid taps: match T X T T in one frame")
	scene = await _reload(game, scene)
	if scene == null:
		return
	c = scene.controller
	types = _types_by_count(c)
	var t_type: String = types[0]
	var x_type := ""
	for t in types:
		if t != t_type:
			x_type = t
			break
	if x_type == "":
		_fail("level 1 offers a single card type")
		return
	ids.clear()
	var taps_ok := _tap(scene, t_type, ids) and _tap(scene, x_type, ids) and _tap(scene, t_type, ids) and _tap(scene, t_type, ids)
	_check(taps_ok, "four rapid taps could be played (T X T T)")
	if not taps_ok:
		return
	_check(c.zone.size() == 1 and c.zone.cards[0].type == x_type, "T X T T leaves only X in the zone (zone %s)" % str(_zone_types(c)))
	_check(not scene.visuals_settled(), "the match visuals are still running right after the taps")
	_check(scene.match_flashes == 0, "the flash waits for the last matched card to land")
	_check(_zone_alpha(scene, 0) == 0.0, "X's slot stays hidden while its ghost flies to the compacted slot")
	if not await _settle(scene):
		return
	_check(scene.match_flashes == 1, "the match flashed exactly once (flashes %d)" % scene.match_flashes)
	_check_zone_clean(scene, [x_type], "after the rapid match")
	if not _failures.is_empty():
		return

	# --- Undo and Hold while ghosts are flying ----------------------------------------------
	print("rapid taps: Undo / Hold / Reserve return with ghosts in flight")
	scene = await _reload(game, scene)
	if scene == null:
		return
	c = scene.controller
	c.powers.counts["undo"] = 2
	c.powers.counts["hold"] = 2
	types = _types_by_count(c)
	a_type = types[0]
	b_type = types[1 % types.size()]
	ids.clear()
	_tap(scene, a_type, ids)
	_tap(scene, b_type, ids)
	scene._on_power("undo")
	_check(c.zone.size() == 1 and c.powers.get_count("undo") == 1, "Undo right after two taps removed the last card (zone %d)" % c.zone.size())
	if not await _settle(scene):
		return
	_check_zone_clean(scene, [a_type], "after Undo during flight")
	_tap(scene, b_type, ids)
	scene._on_power("hold")
	_check(c.zone.size() == 0 and c.reserve.size() == 2, "Hold right after a tap moved the zone to the Reserve (zone %d, reserve %d)" % [c.zone.size(), c.reserve.size()])
	if not await _settle(scene):
		return
	_check_zone_clean(scene, [], "after Hold during flight")
	var back_ids: Array = []
	for card in c.reserve:
		back_ids.append(card.id)
	scene._on_reserve_return(back_ids[1])
	scene._on_reserve_return(back_ids[0])
	_check(c.zone.size() == 2 and c.reserve.is_empty(), "two Reserve returns in one frame both landed (zone %d)" % c.zone.size())
	if not await _settle(scene):
		return
	_check_zone_clean(scene, [_card_type(c, back_ids[1]), _card_type(c, back_ids[0])], "after Reserve returns")
	if not _failures.is_empty():
		return

	# --- UI rebuild while a ghost is in the air ------------------------------------------
	print("rapid taps: rebuild mid-animation")
	scene = await _reload(game, scene)
	if scene == null:
		return
	c = scene.controller
	types = _types_by_count(c)
	ids.clear()
	_tap(scene, types[0], ids)
	_tap(scene, types[1 % types.size()], ids)
	scene._build_ui()
	await process_frame
	await process_frame
	scene.render()
	_check(scene.visuals_settled(), "the rebuild dropped the ghosts of the old layout")
	_check_zone_clean(scene, [_card_type(c, ids[0]), _card_type(c, ids[1])], "after a rebuild mid-flight")
	_tap(scene, types[0], ids)
	_check(c.zone.size() == 3, "taps still work after the rebuild (zone %d)" % c.zone.size())
	if not await _settle(scene):
		return
	_check_zone_clean(scene, [_card_type(c, ids[0]), _card_type(c, ids[1]), _card_type(c, ids[2])], "after taps following a rebuild")
	if not _failures.is_empty():
		return

	# --- The end panel waits for the visuals ------------------------------------------------
	print("rapid taps: end panel waits for the ghosts")
	scene = await _reload(game, scene)
	if scene == null:
		return
	c = scene.controller
	types = _types_by_count(c)
	ids.clear()
	_tap(scene, types[0], ids)
	c.status = GameController.Status.LOST
	await process_frame
	await process_frame
	_check(not scene._ended, "the end panel does not cut the flight short")
	var waited := await _wait_until(func(): return scene._ended)
	_check(waited, "the end panel appeared once the visuals had finished")
	_check(scene.visuals_settled(), "no ghost is left under the end panel")

func _tap(scene, type: String, ids: Array) -> bool:
	var c: GameController = scene.controller
	for a in c.get_legal_actions():
		if a["action"] == "select_card" and c.board.get_card(a["card_id"]).type == type:
			ids.append(a["card_id"])
			scene._on_card(a["card_id"])
			return true
		if a["action"] == "use_deck":
			var deck: DeckManager = c.deck_a if a["deck"] == "a" else c.deck_b
			if deck.current_type() == type:
				scene._on_deck(a["deck"])
				ids.append(c.zone.cards.back().id if c.zone.size() > 0 else "")
				return true
	_fail("no legal move of type %s to tap" % type)
	return false

# Card types currently on offer (available board cards and deck tops), most plentiful first.
func _types_by_count(c: GameController) -> Array:
	var counts := {}
	for a in c.get_legal_actions():
		var type := ""
		if a["action"] == "select_card":
			type = c.board.get_card(a["card_id"]).type
		elif a["action"] == "use_deck":
			type = (c.deck_a if a["deck"] == "a" else c.deck_b).current_type()
		if type != "":
			counts[type] = int(counts.get(type, 0)) + 1
	var out: Array = counts.keys()
	out.sort_custom(func(x, y): return int(counts[x]) > int(counts[y]) or (int(counts[x]) == int(counts[y]) and str(x) < str(y)))
	return out

func _zone_ids(c: GameController) -> Array:
	var out: Array = []
	for card in c.zone.cards:
		out.append(card.id)
	return out

func _zone_types(c: GameController) -> Array:
	var out: Array = []
	for card in c.zone.cards:
		out.append(card.type)
	return out

func _card_type(c: GameController, card_id: String) -> String:
	for card in c.zone.cards:
		if card.id == card_id:
			return card.type
	return ""

func _zone_alpha(scene, index: int) -> float:
	var zone: Container = scene.zone_container
	if index >= zone.get_child_count():
		return -1.0
	return (zone.get_child(index) as Control).modulate.a

# Waits for the visuals to finish; fails the test when they never do (a stuck ghost).
func _settle(scene) -> bool:
	var settled: bool = await _wait_until(func(): return scene.visuals_settled())
	await process_frame
	await process_frame
	_check(settled, "visuals settled (no ghost or flash left)")
	return settled

# The zone shows exactly `types` in its first slots, every slot opaque, no ghost left.
func _check_zone_clean(scene, types: Array, when: String) -> void:
	var c: GameController = scene.controller
	var zone: Container = scene.zone_container
	_check(zone.get_child_count() == c.clearing_capacity, "%s: the zone has %d slots (got %d)" % [when, c.clearing_capacity, zone.get_child_count()])
	for i in zone.get_child_count():
		var slot := zone.get_child(i) as Control
		_check(slot.visible and is_equal_approx(slot.modulate.a, 1.0), "%s: zone slot %d is visible and opaque (alpha %s)" % [when, i, str(slot.modulate.a)])
		var style := slot.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		if i < types.size():
			_check(style.bg_color == CardTypeRegistry.color(types[i]), "%s: zone slot %d shows card type %s" % [when, i, str(types[i])])
		else:
			_check(style.bg_color == EMPTY_SLOT_COLOR, "%s: zone slot %d is an empty slot" % [when, i])
	_check(c.zone.size() == types.size(), "%s: the controller zone holds %d cards (got %d)" % [when, types.size(), c.zone.size()])
	_check(scene.visuals_settled(), "%s: no ghost node is left" % when)
	_check(scene._flights.is_empty(), "%s: no flight is left pending" % when)
	_check(scene._hidden_cards.is_empty(), "%s: no zone slot is still marked hidden" % when)

func _reload(game, previous):
	game.restart_level()
	return await _wait_level(previous)

# A level scene whose controller is ready and whose board has been laid out.
func _wait_level(previous):
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene == null or scene == previous or scene.name != "LevelScreen":
			continue
		var column := scene.find_child("BoardFrame", true, false) as Control
		if scene.get("controller") != null and column != null and column.size.x > 0.0:
			# Let the intro start; taps are accepted during it.
			await process_frame
			return scene
	_fail("level scene did not become ready")
	return null

func _wait_until(condition: Callable) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < STEP_TIMEOUT_MS:
		if condition.call():
			return true
		await process_frame
	return false

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _snapshot_save() -> Dictionary:
	var path := SaveManager.DEFAULT_PATH
	var exists := FileAccess.file_exists(path)
	var bytes := PackedByteArray()
	if exists:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"exists": true, "bytes": bytes, "read_error": FileAccess.get_open_error()}
		bytes = file.get_buffer(file.get_length())
	return {"exists": exists, "bytes": bytes}

func _remove_throwaway_save() -> void:
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	LevelLoader.deterministic = false
	_remove_throwaway_save()
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	var save_after := _snapshot_save()
	if _save_before.has("read_error") or save_after.has("read_error"):
		_fail("could not verify save preservation")
	elif _save_before["exists"] != save_after["exists"] or _save_before["bytes"] != save_after["bytes"]:
		# The test only ever writes its throwaway save, so a change here is the player's own
		# game saving meanwhile. Never write the real save back: that would undo their progress.
		print("NOTE: user save changed during the run (not by this test); left untouched")
	if _failures.is_empty():
		print("SMOKE RAPID TAPS OK")
		quit(0)
		return
	printerr("SMOKE RAPID TAPS FAIL: %d problem(s)" % _failures.size())
	for failure in _failures:
		printerr("  " + failure)
	quit(1)
