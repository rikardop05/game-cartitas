extends SceneTree

## PHASE S3 visual evidence: a desktop level with the hero and Refresh in flight.
const OUT_DIR := "res://docs/visual-reference/phase_s3"
const WINDOW_SIZE := Vector2i(1920, 1032)
const STEP_TIMEOUT_MS := 20000
const THROWAWAY_SAVE := "user://qa_phase_s3_save.json"
var _game
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	if _game == null:
		_fail("Game autoload missing")
		_finish()
		return
	_game.save_path = THROWAWAY_SAVE
	_game.settings["orientation"] = "landscape"
	_game.settings["mascot"] = true
	_game.apply_orientation()
	LevelLoader.deterministic = true
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE
	_game.endless_run = null
	_game.current_level_id = "1"
	var previous = current_scene
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level(previous)
	if scene == null:
		_finish()
		return
	if not await _wait_until(func(): return not scene.is_dealing()):
		_fail("level deal did not finish")
	else:
		await _capture("level_1920x1032_hero")
		scene.controller.powers.counts["refresh"] = 1
		scene._on_power("refresh")
		var started := Time.get_ticks_msec()
		await _wait_elapsed(started, 0.30)
		await _capture("refresh_midflight_preflip")
		await _wait_elapsed(started, 0.43)
		await _capture("refresh_midflight_postflip")
		if not await _wait_until(func(): return not bool(scene.get("_power_animation_active"))):
			_fail("Refresh animation did not finish")
	_finish()

func _wait_level(previous):
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene != null and scene != previous and scene.name == "LevelScreen" and scene.get("controller") != null:
			return scene
	_fail("level did not load")
	return null

func _wait_until(condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		if condition.call():
			return true
		await process_frame
	return false

func _wait_elapsed(started_msec: int, seconds: float) -> void:
	while float(Time.get_ticks_msec() - started_msec) / 1000.0 < seconds:
		await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_fail("could not save %s (%s)" % [path, error_string(error)])
	else:
		print("PHASE S3 CAPTURE %s %dx%d" % [path, image.get_width(), image.get_height()])

func _fail(message: String) -> void:
	_failures.append(message)
	printerr("PHASE S3 CAPTURE FAIL: " + message)

func _finish() -> void:
	LevelLoader.deterministic = false
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("PHASE S3 CAPTURES OK dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
		quit(0)
		return
	quit(1)