extends SceneTree

# Reserve regression with REAL mouse input (Viewport.push_input at each card's centre),
# rebuilt from a reported soft-lock: board and decks empty, Clearing Zone full of pairs,
# five cards in the Reserve, Hold x1. Every Reserve card must be tappable, a tap with a
# full zone must not lose or stall, and Hold + Reserve taps must be able to win.

const THROWAWAY_SAVE := "user://smoke_reserve_save.json"
const ZONE_TYPES := ["leaf", "gem", "crystal", "gem", "crystal", "leaf", "moon"]
const RESERVE_TYPES := ["moon", "leaf", "gem", "crystal", "moon"]
const VIEWS := [
	{"orientation": "landscape", "window": Vector2i(640, 360)},
	{"orientation": "portrait", "window": Vector2i(360, 640)},
]

var _errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors.append(msg)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		printerr("SMOKE RESERVE FAIL: Game autoload missing")
		quit(1)
		return
	game.save_path = THROWAWAY_SAVE
	LevelLoader.deterministic = true
	for view in VIEWS:
		await _run_view(game, view)
	if FileAccess.file_exists(THROWAWAY_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(THROWAWAY_SAVE))
	if _errors.is_empty():
		print("SMOKE RESERVE OK")
		quit(0)
		return
	for e in _errors:
		printerr("SMOKE RESERVE FAIL: " + e)
	quit(1)

func _run_view(game, view: Dictionary) -> void:
	var tag := str(view["orientation"])
	game.settings["orientation"] = view["orientation"]
	game.apply_orientation()
	root.size = view["window"]
	await _frames(3)
	game.current_level_id = "7"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = null
	for i in 120:
		await process_frame
		scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			break
	if scene == null or scene.get("controller") == null:
		_check(false, "%s: level did not load" % tag)
		return
	await _frames(20)
	_setup_softlock(scene)
	await _frames(5)

	# 1. Every Reserve card is a visible, tappable button.
	var buttons := _reserve_buttons(scene)
	_check(buttons.size() == RESERVE_TYPES.size(), "%s: all %d Reserve cards are buttons (got %d)" % [tag, RESERVE_TYPES.size(), buttons.size()])
	var viewport := Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
	for b in buttons:
		var r: Rect2 = b.get_global_rect()
		_check(viewport.encloses(r), "%s: Reserve card %s inside the viewport" % [tag, str(r)])

	# 2. Tapping the Reserve with a full zone neither loses nor changes anything.
	var c = scene.controller
	if not buttons.is_empty():
		_click(scene, buttons[0])
		await _frames(4)
	_check(c.status == GameController.Status.PLAYING, "%s: full-zone Reserve tap keeps playing" % tag)
	_check(c.zone.size() == 7 and c.reserve.size() == RESERVE_TYPES.size(), "%s: full-zone Reserve tap changes nothing" % tag)

	# 3. Hold through the real power button frees 3 slots.
	_click(scene, scene.power_buttons["hold"])
	await _frames(6)
	_check(c.zone.size() == 4 and c.reserve.size() == 8, "%s: Hold moves 3 cards (zone=%d reserve=%d)" % [tag, c.zone.size(), c.reserve.size()])

	# 4. Tap Reserve cards by type (any position) until the level is won.
	for step in 12:
		if c.status != GameController.Status.PLAYING:
			break
		var pick := _best_reserve_index(c)
		if pick < 0:
			break
		var target := _reserve_button_for(scene, c.reserve[pick].id)
		_check(target != null, "%s: Reserve card %s has a button" % [tag, c.reserve[pick].type])
		if target == null:
			break
		var before: int = c.reserve.size()
		_click(scene, target)
		await _frames(6)
		_check(c.reserve.size() == before - 1, "%s: tapping Reserve card %d returns it (reserve %d -> %d)" % [tag, pick, before, c.reserve.size()])
	_check(c.status == GameController.Status.WON, "%s: Hold + Reserve taps win the reported position (status=%d)" % [tag, c.status])
	# The end panel waits for the visuals (capped at 1.2 s of real time), and headless frames
	# run faster than that, so wait on the clock rather than a frame count.
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and not bool(scene.get("_ended")):
		await process_frame
	_check(bool(scene.get("_ended")), "%s: the end panel appears" % tag)

func _setup_softlock(scene) -> void:
	var c = scene.controller
	for card in c.board.cards:
		card.state = Card.State.REMOVED
	c.deck_a.current_index = c.deck_a.card_types.size()
	c.deck_b.current_index = c.deck_b.card_types.size()
	c.zone.cards.clear()
	var n := 0
	for t in ZONE_TYPES:
		var z := Card.new("zone_%d" % n, t)
		z.source = Card.Source.DECK_A
		c.zone.add(z)
		n += 1
	c.reserve.clear()
	for t in RESERVE_TYPES:
		var r := Card.new("res_%d" % n, t)
		r.source = Card.Source.DECK_A
		r.location = Card.Location.RESERVE
		r.state = Card.State.SELECTED
		c.reserve.append(r)
		n += 1
	c.powers.counts = {"hold": 1, "undo": 5, "refresh": 4}
	scene.render()

func _reserve_buttons(scene) -> Array:
	var out: Array = []
	for child in scene.reserve_container.get_children():
		if child is BaseButton and (child as Control).is_visible_in_tree():
			out.append(child)
	return out

func _reserve_button_for(scene, card_id: String) -> Control:
	var index: int = -1
	for i in scene.controller.reserve.size():
		if scene.controller.reserve[i].id == card_id:
			index = i
	if index < 0 or index >= scene.reserve_container.get_child_count():
		return null
	var node := scene.reserve_container.get_child(index) as Control
	return node if node is BaseButton else null

# Picks the Reserve card whose type is most present in the zone (completes pairs first).
func _best_reserve_index(c) -> int:
	var best := -1
	var best_score := -1
	for i in c.reserve.size():
		var score: int = c.zone.count_of_type(c.reserve[i].type)
		if score > best_score:
			best_score = score
			best = i
	return best

func _click(scene, node: Control) -> void:
	# Click inside the part of the card that is not covered by the cards drawn above it.
	var pos := _tappable_point(scene, node)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e, true)

func _tappable_point(scene, node: Control) -> Vector2:
	var rect := node.get_global_rect()
	var parent := node.get_parent()
	if parent == null:
		return rect.get_center()
	var covers: Array[Rect2] = []
	var after := false
	for sibling in parent.get_children():
		if sibling == node:
			after = true
			continue
		if after and sibling is Control and (sibling as Control).is_visible_in_tree():
			covers.append((sibling as Control).get_global_rect())
	for fy in [0.5, 0.25, 0.1, 0.75, 0.9]:
		for fx in [0.5, 0.25, 0.75]:
			var p := rect.position + rect.size * Vector2(fx, fy)
			var covered := false
			for r in covers:
				if r.has_point(p):
					covered = true
					break
			if not covered:
				return p
	return rect.get_center()
