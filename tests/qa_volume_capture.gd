extends SceneTree

# Windowed/GPU capture of the in-game Settings overlay focused on the volume row, at 2x
# (1280x720 landscape / 720x1280 portrait) with volume 0 and 100. Saves to user://qa_shots.

const OUT_DIR := "user://qa_shots"
const CASES := [
	{"tag": "volume_2x_landscape_0", "orientation": "landscape", "window": Vector2i(1280, 720), "volume": 0.0},
	{"tag": "volume_2x_landscape_100", "orientation": "landscape", "window": Vector2i(1280, 720), "volume": 1.0},
	{"tag": "volume_2x_portrait_0", "orientation": "portrait", "window": Vector2i(720, 1280), "volume": 0.0},
	{"tag": "volume_2x_portrait_100", "orientation": "portrait", "window": Vector2i(720, 1280), "volume": 1.0},
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
	print("QA VOLUME SHOT %s %dx%d" % [name, image.get_width(), image.get_height()])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	if _game == null:
		printerr("QA VOLUME FAIL: Game autoload missing")
		quit(1)
		return
	_game.save_path = "user://qa_volume_save.json"
	for case in CASES:
		await _capture(case)
	print("QA VOLUME DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		printerr("QA VOLUME FAIL: " + failure)
	quit(1)

func _capture(case: Dictionary) -> void:
	_game.endless_run = null
	_game.current_level_id = "1"
	_game.settings["orientation"] = case["orientation"]
	_game.settings["mascot"] = true
	_game.apply_orientation()
	root.size = case["window"]
	_game.set_locale("pt")
	_game.set_volume(float(case["volume"]))
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
	var overlay: Node = scene.get_node_or_null("SettingsOverlay")
	var slider: Control = overlay.find_child("VolumeSlider", true, false) if overlay != null else null
	var handle: Control = slider.find_child("Handle", true, false) if slider != null else null
	if slider == null or handle == null:
		_failures.append("%s: volume row missing" % case["tag"])
		return
	# Re-sync after the external volume write so the handle is at the target position.
	(overlay.find_child("VolumeRow", true, false) as Node).call("_sync")
	await _frames(3)
	print("QA VOLUME %s handle.x=%.2f (slider w=%.1f, groove %.2f..%.2f, drawn width %.2f)" % [
		case["tag"], handle.position.x, slider.size.x,
		VolumeRow.groove_left_px(), VolumeRow.groove_right_px(), VolumeRow.HANDLE_DRAWN_WIDTH])
	await _shot(str(case["tag"]))
	scene.call("_close_settings")
	await _frames(3)
