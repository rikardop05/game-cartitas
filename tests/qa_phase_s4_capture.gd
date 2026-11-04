extends SceneTree

## PHASE S4 windowed evidence: the options panels omit the Hero toggle and an old save with
## mascot=false still opens a level with its Hero visible.

const OUT_DIR := "res://docs/visual-reference/phase_s4"
const WINDOW_SIZE := Vector2i(1280, 720)
const LEGACY_SAVE := "user://qa_phase_s4_legacy_save.json"
const STEP_TIMEOUT_MS := 20000

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
	_game.save_path = LEGACY_SAVE
	_game.progress = ProgressManager.new()
	SaveManager.save({
		"progress": _game.progress.to_dict(),
		"settings": {"locale": "pt", "orientation": "landscape", "mascot": false},
	}, LEGACY_SAVE)
	_game.load_save()
	_check(not _game.settings.has("mascot"), "legacy mascot key is removed")
	_check(_game.mascot_enabled(), "legacy false preference cannot hide the Hero")
	_game.settings["orientation"] = "landscape"
	_game.apply_orientation()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE
	await _frames(3)

	_game.endless_run = null
	_game.current_level_id = "1"
	change_scene_to_file("res://scenes/level.tscn")
	var level = await _wait_scene("LevelScreen")
	if level == null:
		_finish()
		return
	if not await _wait_until(func(): return not level.is_dealing()):
		_fail("level deal did not finish")
	else:
		_check(level.mascot != null and level.mascot.visible, "Hero stays visible after loading legacy save")
		await _capture("level_legacy_save_hero")
		level.call("_on_settings")
		await _frames(5)
		_check(level.find_child("MascotButton", true, false) == null, "in-game settings have no Mascot row")
		await _capture("settings_ingame_landscape")

	change_scene_to_file("res://scenes/main.tscn")
	var menu = await _wait_scene("MainMenu")
	if menu != null:
		menu.call("_on_options")
		await _frames(5)
		_check(menu.find_child("MascotButton", true, false) == null, "main-menu options have no Mascot row")
		await _capture("settings_main_menu_landscape")
	_finish()

func _wait_scene(scene_name: String):
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene != null and scene.name == scene_name:
			return scene
	_fail("%s scene did not load" % scene_name)
	return null

func _wait_until(condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		if condition.call():
			return true
		await process_frame
	return false

func _frames(count: int) -> void:
	for i in count:
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
		print("PHASE S4 CAPTURE %s %dx%d" % [path, image.get_width(), image.get_height()])

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr("PHASE S4 CAPTURE FAIL: " + message)

func _finish() -> void:
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	for path in [LEGACY_SAVE, LEGACY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("PHASE S4 CAPTURES OK dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
		quit(0)
		return
	quit(1)
