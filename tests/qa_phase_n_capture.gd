extends SceneTree

## Windowed landscape/portrait evidence for PHASE N and N2. Run with the project renderer
## (not --headless); it saves the review images under docs/visual-reference.

const OUT_DIR := "res://docs/visual-reference/phase_n"
const OUT_DIR_N2 := "res://docs/visual-reference/phase_n2"
const LANDSCAPE_WINDOW := Vector2i(1280, 720)
const PORTRAIT_WINDOW := Vector2i(720, 1280)
const THROWAWAY_SAVE := "user://qa_phase_n_save.json"

var _game
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	if _game == null:
		printerr("PHASE N CAPTURE FAIL: Game autoload missing")
		quit(1)
		return
	_game.save_path = THROWAWAY_SAVE
	await _capture_level("level_bunny_landscape", "8", "landscape", LANDSCAPE_WINDOW)
	await _capture_level("level_cat_landscape", "1", "landscape", LANDSCAPE_WINDOW)
	await _capture_settings_overlay()
	await _capture_menu_settings()
	await _capture_level("level_portrait_720x1280", "8", "portrait", PORTRAIT_WINDOW)
	await _capture_deck_closeups()
	await _capture_zone_at_size("clearing_zone_1280x720", LANDSCAPE_WINDOW)
	await _capture_zone_at_size("clearing_zone_wide_1560x720", Vector2i(1560, 720))
	await _capture_match_burst_comparison()
	await _capture_level_n2_portrait()
	_game.save_path = SaveManager.DEFAULT_PATH
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("PHASE N CAPTURES OK dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
		quit(0)
		return
	for failure in _failures:
		printerr("PHASE N CAPTURE FAIL: " + failure)
	quit(1)

func _set_orientation(orientation: String, window_size: Vector2i) -> void:
	_game.settings["orientation"] = orientation
	_game.settings["mascot"] = true
	_game.apply_orientation()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	await process_frame
	await process_frame

func _capture_level(tag: String, level_id: String, orientation: String, window_size: Vector2i) -> void:
	await _set_orientation(orientation, window_size)
	_game.endless_run = null
	_game.current_level_id = level_id
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene == null:
		_failures.append("%s: level did not load" % tag)
		return
	# The intro runs first; capture with its instruction bubble already laid out.
	await create_timer(1.5).timeout
	await _capture(tag)

func _capture_settings_overlay() -> void:
	await _set_orientation("landscape", LANDSCAPE_WINDOW)
	_game.endless_run = null
	_game.current_level_id = "8"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene == null:
		_failures.append("settings_ingame_landscape: level did not load")
		return
	await create_timer(0.9).timeout
	scene.call("_on_settings")
	await _frames(5)
	await _capture("settings_ingame_landscape")

func _capture_menu_settings() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	var menu = await _wait_named_scene("MainMenu")
	if menu == null:
		_failures.append("settings_main_menu_landscape: menu did not load")
		return
	await _frames(5)
	var selected_background := str(menu.get("_menu_background_path"))
	menu.call("_on_options")
	await _frames(5)
	if str(menu.get("_menu_background_path")) != selected_background:
		_failures.append("main-menu Options changed the selected background")
	await _capture("settings_main_menu_landscape")

func _capture(tag: String) -> void:
	await _capture_to_dir(OUT_DIR, tag)

func _capture_n2(tag: String) -> void:
	await _capture_to_dir(OUT_DIR_N2, tag)

func _capture_to_dir(output_dir: String, tag: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [output_dir, tag]
	var err := image.save_png(path)
	if err != OK:
		_failures.append("%s: could not save %s (err %d)" % [tag, path, err])
	else:
		print("PHASE N SHOT %s %dx%d" % [ProjectSettings.globalize_path(path), image.get_width(), image.get_height()])

func _capture_control_crop(scene: Control, control_name: String, tag: String, output_dir: String = OUT_DIR_N2) -> void:
	var control := scene.find_child(control_name, true, false) as Control
	if control == null:
		_failures.append("%s: missing %s control" % [tag, control_name])
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var transform := root.get_final_transform()
	var rect := control.get_global_rect()
	var scale := transform.get_scale()
	var screen_origin := transform * rect.position
	var margin := Vector2i(roundi(8.0 * scale.x), roundi(8.0 * scale.y))
	var crop_rect := Rect2i(
		Vector2i(roundi(screen_origin.x), roundi(screen_origin.y)) - margin,
		Vector2i(roundi(rect.size.x * scale.x), roundi(rect.size.y * scale.y)) + margin * 2)
	crop_rect = crop_rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(crop_rect)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var path := "%s/%s.png" % [output_dir, tag]
	var err := crop.save_png(path)
	if err != OK:
		_failures.append("%s: could not save crop %s (err %d)" % [tag, path, err])
	else:
		print("PHASE N SHOT %s %dx%d" % [ProjectSettings.globalize_path(path), crop.get_width(), crop.get_height()])

func _capture_deck_closeups() -> void:
	await _set_orientation("landscape", LANDSCAPE_WINDOW)
	_game.endless_run = null
	_game.current_level_id = "8"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene == null:
		_failures.append("deck close-ups: level did not load")
		return
	await create_timer(1.6).timeout
	await _capture_control_crop(scene, "DeckA", "deck_left_1280x720")
	await _capture_control_crop(scene, "DeckB", "deck_right_1280x720")

func _capture_zone_at_size(tag: String, window_size: Vector2i) -> void:
	await _set_orientation("landscape", window_size)
	_game.endless_run = null
	_game.current_level_id = "8"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene == null:
		_failures.append("%s: level did not load" % tag)
		return
	await create_timer(1.4).timeout
	await _capture_control_crop(scene, "ClearingZone", tag)

func _capture_match_burst_comparison() -> void:
	await _set_orientation("landscape", LANDSCAPE_WINDOW)
	_game.endless_run = null
	_game.current_level_id = "8"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene == null:
		_failures.append("match burst comparison: level did not load")
		return
	await create_timer(1.5).timeout
	var center: Vector2 = scene.board_container.get_global_rect().get_center()
	var card_side := 52.0
	# PHASE N reference scale (pre-N2) for direct before/after comparison.
	var old_side := maxf(72.0, card_side * float(scene.MATCH_FX_CARD_SPAN))
	scene.call("_spawn_match_fx", scene.MATCH_BURST_ART, center, old_side, 0.15, 1.08)
	scene.call("_spawn_match_fx", scene.MATCH_SMOKE_ART, center, old_side * 1.14, 0.15, 1.12)
	await _frames(10)
	await _capture_n2("match_burst_before_scale")
	var fx_layer := scene.find_child("FxLayer", true, false) as Control
	if fx_layer != null:
		for child in fx_layer.get_children():
			child.queue_free()
	await _frames(35)
	scene.call("_play_match_burst", center, card_side)
	await _frames(10)
	await _capture_n2("match_burst_after_scale")

func _capture_level_n2_portrait() -> void:
	await _capture_level("level_portrait_720x1280", "8", "portrait", PORTRAIT_WINDOW)
	var source := ProjectSettings.globalize_path("%s/level_portrait_720x1280.png" % OUT_DIR)
	var target := ProjectSettings.globalize_path("%s/level_portrait_720x1280.png" % OUT_DIR_N2)
	var image := Image.load_from_file(source)
	if image == null or image.save_png(target) != OK:
		_failures.append("could not copy portrait reference into phase_n2")

func _wait_level():
	for _i in 180:
		await process_frame
		var scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			return scene
	return null

func _wait_named_scene(scene_name: String):
	for _i in 120:
		await process_frame
		if current_scene != null and current_scene.name == scene_name:
			return current_scene
	return null

func _frames(count: int) -> void:
	for _i in count:
		await process_frame
