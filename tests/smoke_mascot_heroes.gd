extends SceneTree

## PHASE S3 regression: verify the actual LevelScreen hero remains visible with its portrait
## after the initial deal at wide desktop sizes, including a window resize during the deal.

const STEP_TIMEOUT_MS := 20000
const THROWAWAY_SAVE := "user://smoke_mascot_heroes_save.json"
const CASES := [
	{"level": "1", "window": Vector2i(1920, 1032)},
	{"level": "8", "window": Vector2i(1366, 728)},
	{"level": "12", "window": Vector2i(2560, 1392)},
]

var _failures: Array[String] = []
var _game

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_game = root.get_node_or_null("Game")
	if _game == null:
		_fail("Game autoload missing")
		_finish()
		return
	_game.save_path = THROWAWAY_SAVE
	_game.progress = ProgressManager.new()
	_game.endless_run = null
	LevelLoader.deterministic = true
	for test_case in CASES:
		await _open_and_check(str(test_case["level"]), test_case["window"], false)
	await _open_and_check("2", Vector2i(1280, 720), true)
	_finish()

func _open_and_check(level_id: String, window_size: Vector2i, resize_mid_deal: bool) -> void:
	_game.settings["orientation"] = "landscape"
	_game.settings["mascot"] = true
	_game.apply_orientation()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(window_size)
	root.size = window_size
	await _frames(2)
	_game.current_level_id = level_id
	var previous = current_scene
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_for_level(previous)
	if scene == null:
		return
	if resize_mid_deal:
		var started: bool = await _wait_until(func(): return scene.is_dealing())
		_check(started, "level %s exposes the initial deal before the resize" % level_id)
		if started:
			var fitted_size := Vector2i(1920, 1032)
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_size(fitted_size)
			root.size = fitted_size
			# Reproduce the fit-to-monitor resize synchronously as well as through the viewport event.
			scene._on_resized()
			await _frames(2)
	var completed: bool = await _wait_until(func(): return not scene.is_dealing())
	_check(completed, "level %s finishes its deal after the window size change" % level_id)
	await _frames(2)
	_assert_hero(scene, level_id, window_size)

func _assert_hero(scene, level_id: String, window_size: Vector2i) -> void:
	var hero = scene.mascot
	_check(hero != null, "level %s has a hero instance at %s" % [level_id, str(window_size)])
	if hero == null:
		return
	var texture := hero.get("_texture") as Texture2D
	_check(texture != null and texture.get_width() > 0 and texture.get_height() > 0,
		"level %s hero has a loaded non-empty portrait after the deal (%s)" % [level_id, str(window_size)])
	if scene._is_landscape:
		scene._mascot_area.size = Vector2.ZERO
		hero.visible = false
		scene._place_mascot()
		_check(hero.visible,
			"landscape hero placement ignores a zero-sized spacer after resize (%s)" % str(window_size))
	_check(hero.visible and hero.is_visible_in_tree(),
		"level %s hero stays visible after the deal at %s" % [level_id, str(window_size)])
	var rect: Rect2 = hero.get_global_rect()
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_check(rect.size.x > 1.0 and rect.size.y > 1.0 and rect.intersects(viewport),
		"level %s hero has a non-empty on-screen rect after deal (rect=%s viewport=%s)" % [level_id, str(rect), str(viewport)])

func _wait_for_level(previous):
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene != null and scene != previous and scene.name == "LevelScreen" and scene.get("controller") != null:
			return scene
	_fail("level scene did not load")
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

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr("MASCOT HERO FAIL: " + message)

func _finish() -> void:
	LevelLoader.deterministic = false
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("SMOKE MASCOT HEROES OK")
		quit(0)
		return
	printerr("SMOKE MASCOT HEROES RED: %d failure(s)" % _failures.size())
	quit(1)
