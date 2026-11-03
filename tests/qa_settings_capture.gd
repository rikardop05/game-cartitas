extends SceneTree

# Windowed/GPU capture of the in-game Settings overlay with the Atele v2 pieces.
const OUT_DIR := "user://qa_shots"
const CASES := [
	{"tag": "settings_portrait_pt", "orientation": "portrait", "locale": "pt", "window": Vector2i(360, 640)},
	{"tag": "settings_portrait_en", "orientation": "portrait", "locale": "en", "window": Vector2i(360, 640)},
	{"tag": "settings_landscape_pt", "orientation": "landscape", "locale": "pt", "window": Vector2i(640, 360)},
	{"tag": "settings_landscape_en", "orientation": "landscape", "locale": "en", "window": Vector2i(640, 360)},
]

var _game
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := image.save_png(path)
	if err != OK:
		_failures.append("could not save %s (err %d)" % [path, err])
	print("QA SETTINGS SHOT %s %dx%d" % [name, image.get_width(), image.get_height()])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	if _game == null:
		printerr("QA SETTINGS FAIL: Game autoload missing")
		quit(1)
		return
	_game.save_path = "user://qa_settings_save.json"
	for case in CASES:
		await _capture(case)
	print("QA SETTINGS DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		printerr("QA SETTINGS FAIL: " + failure)
	quit(1)

func _capture(case: Dictionary) -> void:
	_game.endless_run = null
	_game.current_level_id = "1"
	_game.settings["orientation"] = case["orientation"]
	_game.settings["mascot"] = true
	_game.apply_orientation()
	root.size = case["window"]
	_game.set_locale(case["locale"])
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
	await _frames(8)
	scene.call("_on_settings")
	await _frames(6)
	await _shot(str(case["tag"]))
