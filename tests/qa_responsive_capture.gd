extends SceneTree

# Responsive comparison captures: each listed size is a logical viewport, while the
# window is twice as large so canvas_items stretch is visible in the resulting PNG.
# Run windowed with a GPU: Godot_v4.7-stable_win64_console.exe --path E:\Cartitas --script res://tests/qa_responsive_capture.gd

const OUT_DIR := "user://qa_shots"
const CASES := [
	{"name": "portrait_360x640", "orientation": "portrait", "logical": Vector2i(360, 640), "background": "harbor"},
	{"name": "portrait_360x780", "orientation": "portrait", "logical": Vector2i(360, 780), "background": "harbor"},
	{"name": "portrait_360x800", "orientation": "portrait", "logical": Vector2i(360, 800), "background": "harbor"},
	{"name": "portrait_480x640", "orientation": "portrait", "logical": Vector2i(480, 640), "background": "harbor"},
	{"name": "landscape_640x360", "orientation": "landscape", "logical": Vector2i(640, 360), "background": "harbor"},
	{"name": "landscape_780x360", "orientation": "landscape", "logical": Vector2i(780, 360), "background": "castle"},
	{"name": "landscape_640x480", "orientation": "landscape", "logical": Vector2i(640, 480), "background": "harbor"},
]

var _game: Node
var _failures: Array[String] = []
var _saved: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _seconds(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	if image.save_png(path) != OK:
		_failures.append("could not write %s" % path)
	else:
		_saved.append("%s %dx%d" % [name, image.get_width(), image.get_height()])
	print("RESPONSIVE SHOT %s %dx%d" % [name, image.get_width(), image.get_height()])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	if _game == null:
		printerr("RESPONSIVE QA FAIL: Game autoload missing")
		quit(1)
		return
	LevelLoader.deterministic = true
	_game.save_path = "user://qa_responsive_save.json"
	_game.progress = ProgressManager.new()
	_game.progress.record_victory("1", 3, [])
	_game.progress.record_victory("2", 2, [])
	_game.settings["mascot"] = true
	_game.settings["locale"] = "pt"
	Localizer.current = "pt"
	for case in CASES:
		await _capture_case(case)
	# Save both example landscape scenes at their reference design ratio.
	await _capture_menu_variant("castle")
	await _capture_menu_variant("harbor")
	_game.save_path = SaveManager.DEFAULT_PATH
	print("RESPONSIVE QA DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	for shot in _saved:
		print("  " + shot)
	if _failures.is_empty():
		print("RESPONSIVE QA OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("RESPONSIVE QA FAIL: " + failure)
		quit(1)

func _capture_case(case: Dictionary) -> void:
	var orientation := str(case["orientation"])
	_game.settings["orientation"] = orientation
	_game.settings["menu_background_variant"] = str(case["background"])
	_game.apply_orientation()
	root.size = Vector2i(case["logical"]) * 2
	await _frames(4)
	await _capture_menu(str(case["name"]))
	_game.endless_run = null
	_game.current_level_id = "6"
	change_scene_to_file("res://scenes/level.tscn")
	var level: Control = await _wait_for_level()
	if level == null:
		_failures.append("%s: Level 6 did not load" % case["name"])
		return
	await _seconds(4.8)
	var intro: Node = level.find_child("IntroOverlay", true, false)
	if intro != null:
		intro.queue_free()
	var bubble: Node = level.find_child("InstructionBubble", true, false)
	if bubble != null:
		bubble.queue_free()
	var mascot = level.get("mascot")
	if mascot != null:
		mascot.hide_bubble()
		var bubble_root := mascot.find_child("BubbleRoot", true, false) as Control
		if bubble_root != null:
			bubble_root.visible = false
			bubble_root.modulate.a = 0.0
	await _frames(2)
	await _shot("level_L6_%s" % case["name"])
	if case["name"] in ["portrait_360x640", "landscape_640x360", "landscape_640x480"]:
		await _capture_panel_crops(level, str(case["name"]))
		_populate_zone(level)
		await _frames(2)
		await _shot("level_zone_cards_%s" % case["name"])

func _populate_zone(scene: Control) -> void:
	var controller = scene.get("controller")
	for card in controller.board.cards:
		card.state = Card.State.REMOVED
	controller.deck_a.current_index = controller.deck_a.card_types.size()
	controller.deck_b.current_index = controller.deck_b.card_types.size()
	controller.zone.cards.clear()
	var kinds: Array[String] = ["heart", "gem", "heart", "gem", "leaf", "frog", "sacer"]
	for i in kinds.size():
		var card := Card.new("qa_zone_%d" % i, kinds[i])
		card.source = Card.Source.DECK_A
		controller.zone.add(card)
	scene.render()

func _capture_panel_crops(scene: Node, tag: String) -> void:
	var screen := root.get_texture().get_image()
	var logical_size: Vector2 = scene.get_viewport_rect().size
	var factor := Vector2(float(screen.get_width()) / logical_size.x, float(screen.get_height()) / logical_size.y)
	for node_name in ["Reserve", "ClearingZone", "Powers", "BoardFrame"]:
		var node := scene.find_child(node_name, true, false) as Control
		if node == null:
			_failures.append("%s: missing %s for the 2x crop" % [tag, node_name])
			continue
		var global_rect := node.get_global_rect()
		var rect := Rect2i(
			Vector2i(roundi(global_rect.position.x * factor.x), roundi(global_rect.position.y * factor.y)),
			Vector2i(roundi(global_rect.size.x * factor.x), roundi(global_rect.size.y * factor.y)))
		rect = rect.intersection(Rect2i(Vector2i.ZERO, Vector2i(screen.get_width(), screen.get_height())))
		if not rect.has_area():
			_failures.append("%s: %s produced an empty 2x crop" % [tag, node_name])
			continue
		var crop := screen.get_region(rect)
		var name := "detail_2x_%s_%s" % [tag, node_name.to_snake_case()]
		var path := "%s/%s.png" % [OUT_DIR, name]
		if crop.save_png(path) != OK:
			_failures.append("could not write 2x crop %s" % path)
		else:
			_saved.append("%s %dx%d" % [name, crop.get_width(), crop.get_height()])

func _capture_menu(tag: String) -> void:
	change_scene_to_file("res://scenes/main.tscn")
	var menu: Node = await _wait_for_menu()
	if menu == null:
		_failures.append("%s: menu did not load" % tag)
		return
	await _frames(12)
	await _shot("menu_%s" % tag)

func _capture_menu_variant(variant: String) -> void:
	_game.settings["orientation"] = "landscape"
	_game.settings["menu_background_variant"] = variant
	_game.apply_orientation()
	root.size = Vector2i(1280, 720)
	await _frames(4)
	await _capture_menu("landscape_%s" % variant)

func _wait_for_menu():
	for _i in 120:
		await process_frame
		if current_scene != null and current_scene.name == "MainMenu":
			return current_scene
	return null

func _wait_for_level():
	for _i in 180:
		await process_frame
		if current_scene != null and current_scene.name == "LevelScreen" and current_scene.get("controller") != null:
			return current_scene
	return null
