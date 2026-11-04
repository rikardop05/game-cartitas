extends SceneTree

# Phase I card juice: only the active board/deck card owns a tilt material (blocked cards never
# do), it goes back to the shared material after release, and Clearing Zone cards sway with
# their own material. A tapped card still plays (tilt never eats clicks).

const THROWAWAY_SAVE := "user://smoke_card_juice_save.json"

var _errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors.append(msg)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _art(face: Control) -> TextureRect:
	for child in face.get_children():
		if child is TextureRect:
			return child
	return null

func _run() -> void:
	var game = root.get_node_or_null("Game")
	game.save_path = THROWAWAY_SAVE
	LevelLoader.deterministic = true
	game.settings["orientation"] = "landscape"
	game.apply_orientation()
	root.size = Vector2i(640, 360)
	game.current_level_id = "6"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = null
	for i in 120:
		await process_frame
		scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			break
	if scene == null:
		_finish(["level did not load"])
		return
	await _frames(10)
	var depths: Dictionary = scene.call("_blocked_depths")
	var free: Button = null
	var blocked: Button = null
	for id in scene._board_nodes.keys():
		var btn := scene._board_nodes[id] as Button
		if int(depths.get(id, 0)) == 0 and free == null:
			free = btn
		elif int(depths.get(id, 0)) > 0 and blocked == null:
			blocked = btn
	_check(free != null and blocked != null, "level 6 has free and blocked cards")
	if free == null or blocked == null:
		_finish(_errors)
		return

	# Blocked cards never tilt.
	scene.call("_juice_follow", blocked, blocked.size * 0.8)
	_check(_art(blocked.get_child(0)).material == null, "a blocked card never gets a tilt material")

	# A free card tilts: own material, rotated, scaled, shadow shifted; nobody else has one.
	scene.call("_juice_follow", free, free.size * Vector2(0.9, 0.1))
	await _wait_ms(250)
	var art := _art(free.get_child(0))
	var mat := art.material as ShaderMaterial
	_check(mat != null, "the active board card gets its own material")
	if mat != null:
		_check(absf(float(mat.get_shader_parameter("y_rot"))) > 5.0, "the card tilts about y")
		_check(absf(float(mat.get_shader_parameter("x_rot"))) > 5.0, "the card tilts about x")
		_check(absf(float(mat.get_shader_parameter("y_rot"))) <= scene.JUICE_MAX_TILT_DEG + 0.01, "tilt stays within the max angle")
	_check(free.get_child(0).scale.x > 1.0, "the active card pops in scale")
	var carriers := 0
	for id in scene._board_nodes.keys():
		var other := _art(scene._board_nodes[id].get_child(0))
		if other != null and other.material is ShaderMaterial and other.material.shader == scene.JUICE_SHADER:
			carriers += 1
	_check(carriers == 1, "only one board card carries a tilt material (%d)" % carriers)
	# Moving to another card hands the material over.
	scene.call("_juice_release", free)
	await _wait_ms(500)
	_check(art.material == null and is_equal_approx(free.get_child(0).scale.x, 1.0), "released card returns to the shared material and rest scale")

	# Deck top card.
	var deck: Button = scene.deck_a_btn
	var rect: Rect2 = deck.get_meta("face_rect")
	var expected_deck_card := Vector2(48.3, 48.3)
	_check(deck.size.is_equal_approx(expected_deck_card),
		"landscape deck hit area is the 1.25x face card (%s)" % str(deck.size))
	_check(rect.position.is_zero_approx() and rect.size.is_equal_approx(deck.size),
		"landscape deck hit area matches only the visible top card")
	var deck_stack := deck.get_meta("deck_stack") as Control
	var deck_slot := deck.get_parent() as Control
	_check(deck_stack != null and deck_slot != null and
		deck_slot.get_global_rect().encloses(deck_stack.get_global_rect()),
		"enlarged back-card stack remains on its table")
	_check(deck_stack != null and deck_stack.size.is_equal_approx(Vector2(62.1, 48.3)),
		"landscape pile offsets scale with the enlarged cards and leave a table margin")
	scene.call("_juice_follow", deck, rect.position + rect.size * Vector2(0.2, 0.8))
	var deck_art := _art(deck.get_meta("face"))
	_check(deck_art != null and deck_art.material is ShaderMaterial, "the deck's top card tilts too")
	scene.call("_juice_release", deck)
	await _wait_ms(500)

	# Clicks go through: a tilted free card is still taken by a tap.
	var free_id := ""
	for id in scene._board_nodes.keys():
		if scene._board_nodes[id] == free:
			free_id = id
	scene.call("_juice_follow", free, free.size * 0.5)
	var before: int = scene.controller.zone.cards.size()
	free.pressed.emit()
	await _wait_ms(900)
	_check(scene.controller.zone.cards.size() == before + 1, "a tilted card is still taken by a tap")
	_check(not scene._board_nodes.has(free_id), "the taken card left the board")

	# Zone cards sway with their own material.
	var swaying := 0
	for key in scene._zone_nodes.keys():
		if str(key).begins_with("card:"):
			var zart := _art(scene._zone_nodes[key])
			if zart != null and zart.material is ShaderMaterial and float(zart.material.get_shader_parameter("sway_amount")) > 0.0:
				swaying += 1
	_check(swaying >= 1, "Clearing Zone cards carry the sway/holo material")
	await _check_portrait_deck(game)
	_finish(_errors)

func _check_portrait_deck(game) -> void:
	game.settings["orientation"] = "portrait"
	game.apply_orientation()
	root.size = Vector2i(360, 640)
	game.current_level_id = "7"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = null
	for _i in 120:
		await process_frame
		scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			break
	if scene == null or scene.name != "LevelScreen":
		_check(false, "portrait deck regression check loads the level")
		return
	await _frames(6)
	var deck: Button = scene.deck_a_btn
	var stack := deck.get_meta("deck_stack") as Control
	_check(deck.size.is_equal_approx(Vector2(54.0, 42.0)),
		"portrait deck keeps its previous 54x42 pile hit area")
	var portrait_face: Rect2 = deck.get_meta("face_rect")
	_check(portrait_face.size.is_equal_approx(Vector2(42.0, 42.0)),
		"portrait face keeps its previous 42x42 size")
	_check(stack != null and stack.size.is_equal_approx(Vector2(54.0, 42.0)),
		"portrait deck stack keeps its previous 4 px edge step")

func _finish(errors: Array) -> void:
	LevelLoader.deterministic = false
	if FileAccess.file_exists(THROWAWAY_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(THROWAWAY_SAVE))
	if errors.is_empty():
		print("SMOKE CARD JUICE OK")
		quit(0)
		return
	for e in errors:
		printerr("SMOKE CARD JUICE FAIL: " + e)
	quit(1)
