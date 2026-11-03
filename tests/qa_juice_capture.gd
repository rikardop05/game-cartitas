extends SceneTree

# QA capture for the card juice (Phase I). Windowed/GPU instance; writes user://qa_shots:
# a board card mid-tilt, a deck card tilted, the Clearing Zone with swaying cards (two frames
# ~0.5 s apart), portrait and landscape at 2x.
const OUT_DIR := "user://qa_shots"
const CASES := [
	{"tag": "juice_portrait", "level": "6", "orientation": "portrait", "window": Vector2i(720, 1280)},
	{"tag": "juice_landscape", "level": "6", "orientation": "landscape", "window": Vector2i(1280, 720)},
]

var _game
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var err := image.save_png("%s/%s.png" % [OUT_DIR, name])
	if err != OK:
		_failures.append("could not save %s" % name)
	print("QA JUICE SHOT %s %dx%d" % [name, image.get_width(), image.get_height()])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	_game.save_path = "user://qa_juice_save.json"
	for case in CASES:
		await _capture(case)
	print("QA JUICE DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	for failure in _failures:
		printerr("QA JUICE FAIL: " + failure)
	quit(0 if _failures.is_empty() else 1)

func _capture(case: Dictionary) -> void:
	_game.endless_run = null
	_game.current_level_id = str(case["level"])
	_game.settings["orientation"] = str(case["orientation"])
	_game.settings["mascot"] = true
	_game.apply_orientation()
	root.size = case["window"]
	change_scene_to_file("res://scenes/level.tscn")
	var scene = null
	for i in 120:
		await process_frame
		scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			break
	if scene == null:
		_failures.append("%s: level did not load" % case["tag"])
		return
	await _wait_ms(3500)  # intro / instruction bubble
	# Fill the zone with up to 5 free cards of different types.
	var depths: Dictionary = scene.call("_blocked_depths")
	var seen := {}
	var taps := 0
	for card in scene.controller.board.cards.duplicate():
		if taps >= 5:
			break
		if card.is_removed() or int(depths.get(card.id, 0)) > 0 or seen.has(card.type):
			continue
		seen[card.type] = true
		scene.call("_on_card", card.id)
		taps += 1
		await _wait_ms(700)
	await _wait_ms(800)
	# A board card mid-tilt (pointer near its top-right corner).
	var nodes: Dictionary = scene.get("_board_nodes")
	depths = scene.call("_blocked_depths")
	var target: Button = null
	for id in nodes.keys():
		var btn := nodes[id] as Button
		if is_instance_valid(btn) and not btn.disabled and int(depths.get(id, 0)) == 0:
			target = btn
			break
	if target != null:
		scene.call("_juice_follow", target, target.size * Vector2(0.92, 0.1))
		await _wait_ms(300)
	await _shot(str(case["tag"]) + "_board_tilt_a")
	await _wait_ms(500)
	await _shot(str(case["tag"]) + "_board_tilt_b")
	if target != null:
		scene.call("_juice_release", target)
		await _wait_ms(500)
	# The deck's top card tilted.
	var deck: Button = scene.get("deck_a_btn")
	if deck != null:
		var face_rect: Rect2 = deck.get_meta("face_rect", Rect2(Vector2.ZERO, deck.size))
		scene.call("_juice_follow", deck, face_rect.position + face_rect.size * Vector2(0.1, 0.9))
		await _wait_ms(300)
		await _shot(str(case["tag"]) + "_deck_tilt")
		scene.call("_juice_release", deck)
