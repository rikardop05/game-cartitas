extends SceneTree

# Help overlay regression: in both orientations the panel and its close button
# fit the viewport, closing (button, shade tap, ui_cancel) resumes the clock, and
# an orientation rebuild with help open never leaves the level paused.

const THROWAWAY_SAVE := "user://smoke_help_save.json"
const VIEWS := [
	{"orientation": "portrait", "window": Vector2i(360, 640)},
	{"orientation": "landscape", "window": Vector2i(640, 360)},
]

var _errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors.append(msg)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		printerr("SMOKE HELP FAIL: Game autoload missing")
		quit(1)
		return
	game.save_path = THROWAWAY_SAVE
	for view in VIEWS:
		await _run_view(game, view)
	await _check_rebuild_resumes(game)
	if FileAccess.file_exists(THROWAWAY_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(THROWAWAY_SAVE))
	if _errors.is_empty():
		print("SMOKE HELP OK")
		quit(0)
		return
	for e in _errors:
		printerr("SMOKE HELP FAIL: " + e)
	quit(1)

func _open_level(game, view: Dictionary):
	game.settings["orientation"] = view["orientation"]
	game.apply_orientation()
	root.size = view["window"]
	await _frames(3)
	game.current_level_id = "3"
	change_scene_to_file("res://scenes/level.tscn")
	for i in 90:
		await process_frame
		var scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			await _frames(5)
			return scene
	return null

func _run_view(game, view: Dictionary) -> void:
	var tag := str(view["orientation"])
	var scene = await _open_level(game, view)
	if scene == null:
		_check(false, "%s: level scene did not load" % tag)
		return
	var viewport := Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
	for closer in ["button", "shade", "cancel"]:
		scene._on_help()
		await _frames(3)
		var overlay := scene.get_node_or_null("HelpOverlay") as Control
		_check(overlay != null, "%s: help overlay opens" % tag)
		if overlay == null:
			return
		_check(scene.controller.status == GameController.Status.PAUSED, "%s: help pauses the clock" % tag)
		var panel := overlay.find_children("*", "PanelContainer", true, false)
		_check(panel.size() == 1, "%s: one help panel" % tag)
		if panel.size() == 1:
			_check(viewport.encloses((panel[0] as Control).get_global_rect()), "%s: help panel %s fits viewport %s" % [tag, str((panel[0] as Control).get_global_rect()), str(viewport)])
		var close := overlay.find_child("HelpClose", true, false) as Button
		_check(close != null and close.is_visible_in_tree(), "%s: close button visible" % tag)
		if close != null:
			_check(viewport.encloses(close.get_global_rect()), "%s: close button inside viewport" % tag)
		match closer:
			"button":
				close.pressed.emit()
			"shade":
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				(overlay.get_child(0) as Control).gui_input.emit(click)
			"cancel":
				var esc := InputEventAction.new()
				esc.action = "ui_cancel"
				esc.pressed = true
				scene._unhandled_input(esc)
		await _frames(3)
		_check(scene.get_node_or_null("HelpOverlay") == null, "%s: %s closes the help" % [tag, closer])
		_check(scene.controller.status == GameController.Status.PLAYING, "%s: %s resumes the clock" % [tag, closer])

func _check_rebuild_resumes(game) -> void:
	var scene = await _open_level(game, VIEWS[0])
	if scene == null:
		_check(false, "rebuild: level scene did not load")
		return
	scene._on_help()
	await _frames(2)
	scene._build_ui()
	await _frames(3)
	_check(scene.controller.status == GameController.Status.PLAYING, "rebuild with help open resumes the clock")
	_check(not bool(scene.get("_help_shown")), "rebuild clears the help flag")
