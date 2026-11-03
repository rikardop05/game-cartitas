extends SceneTree

# In-game Settings overlay smoke: the new Atele v2 pieces must be the real background,
# row plates and Accept/Close badges, in both orientations and both locales.

const THROWAWAY_SAVE := "user://smoke_settings_overlay_save.json"
const V2 := "res://assets/ui/kit/v2/"
const CASES := [
	{"orientation": "portrait", "locale": "pt", "window": Vector2i(360, 640)},
	{"orientation": "portrait", "locale": "en", "window": Vector2i(360, 640)},
	{"orientation": "landscape", "locale": "pt", "window": Vector2i(640, 360)},
	{"orientation": "landscape", "locale": "en", "window": Vector2i(640, 360)},
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
	for case in CASES:
		await _check_case(case)
	_finish()

func _check_case(case: Dictionary) -> void:
	var tag := "%s-%s" % [case["orientation"], case["locale"]]
	_game.endless_run = null
	_game.current_level_id = "1"
	_game.settings["orientation"] = case["orientation"]
	_game.settings["mascot"] = true
	_game.apply_orientation()
	root.size = case["window"]
	_game.set_locale(case["locale"])
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene == null:
		_fail("%s: level did not load" % tag)
		return
	scene.call("_on_settings")
	await _frames(4)
	var overlay := scene.find_child("SettingsOverlay", true, false) as Control
	var panel := scene.find_child("SettingsPanel", true, false) as Control
	var panel_art := scene.find_child("SettingsPanelArt", true, false) as TextureRect
	var body := scene.find_child("SettingsBody", true, false) as VBoxContainer
	_check(overlay != null and panel != null and panel_art != null and body != null,
		"%s: settings overlay/panel/body exists" % tag)
	if panel == null or panel_art == null or body == null:
		return
	_check(str(panel_art.get_meta("source_path", "")) == V2 + "panel_options.png",
		"%s: panel_options is the real background" % tag)
	_check(panel_art.texture != null and panel_art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"%s: panel_options uses linear + mipmaps" % tag)
	var rows := [
		["LanguageButton", "config_row_1.png"],
		["OrientationButton", "config_row_2.png"],
		["MascotButton", "config_row_3.png"],
	]
	for row in rows:
		var btn := panel.find_child(str(row[0]), true, false) as Button
		_check(btn != null, "%s: %s exists" % [tag, row[0]])
		if btn == null:
			continue
		var style := btn.get_theme_stylebox("normal") as StyleBoxTexture
		_check(style != null and style.texture != null and str(style.get_meta("source_path", "")).ends_with(str(row[1])),
			"%s: %s uses %s" % [tag, row[0], row[1]])
	var volume := panel.find_child("VolumeRow", true, false) as Control
	var volume_style := volume.get_theme_stylebox("panel") as StyleBoxTexture if volume != null else null
	_check(volume_style != null and volume_style.texture != null and
		str(volume_style.get_meta("source_path", "")).ends_with("config_row_1.png"),
		"%s: VolumeRow uses a Config row plate" % tag)
	var corner := panel.find_child("SettingsCornerClose", true, false) as Button
	var close := panel.find_child("SettingsClose", true, false) as Button
	_check(corner != null and str(corner.get_meta("source_path", "")) == V2 + "icon_close_v2.png",
		"%s: corner close uses icon_close_v2" % tag)
	_check(close != null and str(close.get_meta("source_path", "")) == V2 + "icon_accept_v2.png",
		"%s: confirm close uses icon_accept_v2" % tag)
	var screen := Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
	var panel_rect := panel.get_global_rect()
	_check(screen.grow(-2.0).encloses(panel_rect), "%s: panel %s fits %s" % [tag, str(panel_rect), str(screen)])
	for node_name in ["LanguageButton", "OrientationButton", "MascotButton", "VolumeRow", "SettingsClose"]:
		var node := panel.find_child(node_name, true, false) as Control
		_check(node != null and panel_rect.encloses(node.get_global_rect()),
			"%s: %s stays inside the painted panel" % [tag, node_name])

func _wait_level():
	for i in 120:
		await process_frame
		var scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			return scene
	return null

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("SMOKE SETTINGS OVERLAY OK")
		quit(0)
		return
	for failure in _failures:
		printerr("SMOKE SETTINGS FAIL: " + failure)
	quit(1)
