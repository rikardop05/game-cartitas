extends SceneTree

## Reproduces the desktop portrait window from Options on the current monitor and at
## the three supported physical window sizes. Run windowed with the GPU enabled.

const OUT_DIR := "user://qa_shots"
const CASES := [Vector2i(720, 1280), Vector2i(540, 960), Vector2i(600, 1080)]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := root.get_node_or_null("Game")
	if game == null:
		printerr("PORTRAIT WINDOW PROBE FAIL: Game autoload missing")
		quit(1)
		return
	game.save_path = "user://portrait_window_probe_save.json"
	game.progress = ProgressManager.new()
	game.settings["locale"] = "pt"
	Localizer.current = "pt"
	# Use the same orientation action as the Options screen.
	game.set_orientation(false)
	await _frames(3)
	var window := root
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	_print_window_state("after-options-720x1280", window, usable)
	game.current_level_id = "6"
	change_scene_to_file("res://scenes/level.tscn")
	var scene: Control = await _wait_for_level()
	if scene == null:
		printerr("PORTRAIT WINDOW PROBE FAIL: Level 6 did not load")
		quit(1)
		return
	await _seconds(4.6)
	_hide_intro(scene)
	await _frames(2)
	for size: Vector2i in CASES:
		window.size = size
		await _frames(8)
		_print_window_state("requested-%dx%d" % [size.x, size.y], window, usable)
		await _capture("portrait_window_%dx%d_before" % [size.x, size.y])
	game.save_path = SaveManager.DEFAULT_PATH
	print("PORTRAIT WINDOW PROBE OK")
	quit(0)

func _wait_for_level() -> Control:
	for _index in 2400:
		await process_frame
		if current_scene != null and current_scene.name == "LevelScreen" and current_scene.get("controller") != null:
			return current_scene as Control
	return null

func _frames(count: int) -> void:
	for _index in count:
		await process_frame

func _seconds(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _hide_intro(scene: Node) -> void:
	for overlay_name in ["IntroOverlay", "InstructionBubble"]:
		var overlay := scene.find_child(overlay_name, true, false)
		if overlay != null:
			overlay.queue_free()
	var mascot = scene.get("mascot")
	if mascot != null:
		mascot.hide_bubble()

func _print_window_state(tag: String, window: Window, usable: Rect2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var window_size := DisplayServer.window_get_size()
	var decorated_size := DisplayServer.window_get_size_with_decorations()
	var logical := root.get_visible_rect().size
	print("PORTRAIT WINDOW %s screen=%s usable=%s requested=%s client=%s decorated=%s logical=%s design=%s" % [
		tag, str(screen_size), str(usable), str(window.size), str(window_size),
		str(decorated_size), str(logical), str(root.content_scale_size),
	])

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		printerr("PORTRAIT WINDOW PROBE FAIL: could not save %s (err %d)" % [path, error])
	else:
		print("PORTRAIT WINDOW SHOT %s %dx%d" % [path, image.get_width(), image.get_height()])
