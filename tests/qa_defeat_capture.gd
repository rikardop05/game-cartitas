extends SceneTree

# QA capture for the defeat screen. Windowed/GPU instance; writes user://qa_shots.
const OUT_DIR := "user://qa_shots"
const CASES := [
	{"tag": "defeat_L1_portrait_pt", "level": "1", "orientation": "portrait", "locale": "pt"},
	{"tag": "defeat_L8_portrait_pt", "level": "8", "orientation": "portrait", "locale": "pt"},
	{"tag": "defeat_L15_portrait_pt", "level": "15", "orientation": "portrait", "locale": "pt"},
	{"tag": "defeat_L1_portrait_en", "level": "1", "orientation": "portrait", "locale": "en"},
	{"tag": "defeat_L8_portrait_en", "level": "8", "orientation": "portrait", "locale": "en"},
	{"tag": "defeat_L15_portrait_en", "level": "15", "orientation": "portrait", "locale": "en"},
	{"tag": "defeat_L1_landscape_pt", "level": "1", "orientation": "landscape", "locale": "pt"},
	{"tag": "defeat_L8_landscape_pt", "level": "8", "orientation": "landscape", "locale": "pt"},
	{"tag": "defeat_L15_landscape_pt", "level": "15", "orientation": "landscape", "locale": "pt"},
	{"tag": "defeat_L1_landscape_en", "level": "1", "orientation": "landscape", "locale": "en"},
	{"tag": "defeat_L8_landscape_en", "level": "8", "orientation": "landscape", "locale": "en"},
	{"tag": "defeat_L15_landscape_en", "level": "15", "orientation": "landscape", "locale": "en"},
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
	print("QA DEFEAT SHOT %s %dx%d" % [name, image.get_width(), image.get_height()])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	if _game == null:
		printerr("QA DEFEAT FAIL: Game autoload missing")
		quit(1)
		return
	_game.save_path = "user://qa_defeat_save.json"
	for case in CASES:
		await _capture(case)
	print("QA DEFEAT DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		printerr("QA DEFEAT FAIL: " + failure)
	quit(1)

func _capture(case: Dictionary) -> void:
	_game.endless_run = null
	_game.current_level_id = str(case["level"])
	_game.settings["orientation"] = str(case["orientation"])
	_game.settings["mascot"] = true
	_game.apply_orientation()
	root.size = Vector2i(360, 640) if case["orientation"] == "portrait" else Vector2i(640, 360)
	_game.set_locale(str(case["locale"]))
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
	scene.call("_show_end", false)
	await _frames(5)
	await _shot(str(case["tag"]))
