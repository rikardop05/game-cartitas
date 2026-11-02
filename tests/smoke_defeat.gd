extends SceneTree

# Defeat-screen smoke: real level scene, throwaway save, both orientations and locales.
# Verifies the roster mapping, localised title/plates, HUD availability and that every
# piece of the composition stays inside the viewport without duplicate text.

const THROWAWAY_SAVE := "user://smoke_defeat_save.json"
const CASES := [
	{"level": "1", "hero": "cat", "character": "defeat_cat.png", "orientation": "portrait", "locale": "pt"},
	{"level": "8", "hero": "bunny", "character": "defeat_bunny.png", "orientation": "portrait", "locale": "pt"},
	{"level": "14", "hero": "sacer", "character": "defeat_sacer.png", "orientation": "portrait", "locale": "pt"},
	{"level": "15", "hero": "wolf_knight", "character": "defeat_archer.png", "orientation": "portrait", "locale": "pt"},
	{"level": "1", "hero": "cat", "character": "defeat_cat.png", "orientation": "portrait", "locale": "en"},
	{"level": "8", "hero": "bunny", "character": "defeat_bunny.png", "orientation": "portrait", "locale": "en"},
	{"level": "15", "hero": "wolf_knight", "character": "defeat_archer.png", "orientation": "portrait", "locale": "en"},
	{"level": "1", "hero": "cat", "character": "defeat_cat.png", "orientation": "landscape", "locale": "en"},
	{"level": "8", "hero": "bunny", "character": "defeat_bunny.png", "orientation": "landscape", "locale": "en"},
	{"level": "15", "hero": "wolf_knight", "character": "defeat_archer.png", "orientation": "landscape", "locale": "en"},
	{"level": "1", "hero": "cat", "character": "defeat_cat.png", "orientation": "landscape", "locale": "pt"},
	{"level": "8", "hero": "bunny", "character": "defeat_bunny.png", "orientation": "landscape", "locale": "pt"},
	{"level": "15", "hero": "wolf_knight", "character": "defeat_archer.png", "orientation": "landscape", "locale": "pt"},
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
	_game.endless_run = null
	_game.current_level_id = str(case["level"])
	_game.settings["orientation"] = str(case["orientation"])
	_game.settings["mascot"] = true
	_game.apply_orientation()
	root.size = Vector2i(360, 640) if case["orientation"] == "portrait" else Vector2i(640, 360)
	_game.set_locale(str(case["locale"]))
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	var tag := "L%s-%s-%s" % [case["level"], case["orientation"], case["locale"]]
	if scene == null:
		_fail("%s: no LevelScreen" % tag)
		return
	scene.call("_show_end", false)
	await _frames(3)
	var overlay := scene.find_child("DefeatOverlay", true, false) as Control
	var panel := scene.find_child("DefeatPanel", true, false) as Control
	var character := scene.find_child("DefeatCharacter", true, false) as TextureRect
	var title := scene.find_child("DefeatTitle", true, false) as TextureRect
	var retry := scene.find_child("DefeatRetry", true, false) as Button
	var quit := scene.find_child("DefeatQuit", true, false) as Button
	_check(overlay != null and panel != null, "%s: defeat overlay/panel exists" % tag)
	_check(character != null and title != null and retry != null and quit != null,
		"%s: character/title/retry/quit nodes exist" % tag)
	if character == null or title == null or retry == null or quit == null or panel == null:
		return
	_check(str(character.get_meta("source_path", "")).ends_with(str(case["character"])),
		"%s: %s maps to %s (got %s)" % [tag, case["hero"], case["character"], character.get_meta("source_path", "")])
	_check(str(character.get_meta("hero", "")) == str(case["hero"]),
		"%s: character carries the roster hero" % tag)
	_check(str(title.get_meta("source_path", "")).ends_with("defeat_title_%s.png" % case["locale"]),
		"%s: title is localised (got %s)" % [tag, title.get_meta("source_path", "")])
	_check(str(retry.get_meta("source_path", "")).ends_with("defeat_retry_%s.png" % case["locale"]),
		"%s: retry plate is localised (got %s)" % [tag, retry.get_meta("source_path", "")])
	_check(str(quit.get_meta("source_path", "")).ends_with("defeat_quit_%s.png" % case["locale"]),
		"%s: quit plate is localised (got %s)" % [tag, quit.get_meta("source_path", "")])
	_check(not retry.pressed.get_connections().is_empty(), "%s: retry has a real callback" % tag)
	_check(not quit.pressed.get_connections().is_empty(), "%s: quit has a real callback" % tag)
	# The art carries the text: no Label may be drawn over the stone window.
	var labels := panel.find_children("*", "Label", true, false)
	_check(labels.is_empty(), "%s: no duplicate text Label over the defeat art" % tag)
	var hud := scene.find_child("Hud", true, false) as Control
	_check(hud != null and hud.visible and hud.z_index == 10,
		"%s: HUD stays visible above the defeat shade" % tag)
	_check(scene.find_child("BackButton", true, false) != null and scene.find_child("HelpButton", true, false) != null,
		"%s: menu/help controls survive" % tag)
	var screen := Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
	var panel_rect := panel.get_global_rect()
	var character_rect := character.get_global_rect()
	_check(screen.encloses(panel_rect), "%s: panel %s fits the screen %s" % [tag, str(panel_rect), str(screen)])
	_check(screen.encloses(character_rect), "%s: character %s fits the screen %s" % [tag, str(character_rect), str(screen)])
	for plate in [title, retry, quit]:
		_check(panel_rect.encloses((plate as Control).get_global_rect()),
			"%s: %s sits inside the stone panel" % [tag, plate.name])
	_check(character_rect.size.x >= 200.0 and character_rect.size.y >= 230.0,
		"%s: the hero is large (%s)" % [tag, str(character_rect.size)])

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
		print("SMOKE DEFEAT OK")
		quit(0)
		return
	for failure in _failures:
		printerr("SMOKE DEFEAT FAIL: " + failure)
	quit(1)
