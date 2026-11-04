extends SceneTree

## Windowed PHASE S evidence: three Refresh moments in 1280x720 landscape, one portrait mid-flip,
## and the red landing on Undo and Hold. Images are saved under docs/visual-reference/phase_s.

const OUT_DIR := "res://docs/visual-reference/phase_s"
const LANDSCAPE := Vector2i(1280, 720)
const PORTRAIT := Vector2i(720, 1280)
const STEP_TIMEOUT_MS := 20000
const THROWAWAY_SAVE := "user://qa_phase_s_save.json"

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
	LevelLoader.deterministic = true
	await _capture_refresh("refresh_landscape", "landscape", LANDSCAPE,
		[{"at": 0.10, "name": "refresh_landscape_lift"},
		 {"at": 0.40, "name": "refresh_landscape_mid_flip"},
		 {"at": 0.94, "name": "refresh_landscape_red_landing"}])
	await _capture_refresh("refresh_portrait", "portrait", PORTRAIT,
		[{"at": 0.40, "name": "refresh_portrait_mid_flip"}])
	await _capture_undo_hold()
	_finish()

func _capture_refresh(_tag: String, orientation: String, window_size: Vector2i, moments: Array) -> void:
	var scene = await _open_level(orientation, window_size)
	if scene == null:
		return
	scene.controller.powers.counts["refresh"] = 1
	scene._on_power("refresh")
	var started := Time.get_ticks_msec()
	for moment in moments:
		if str(moment["name"]) == "refresh_landscape_red_landing":
			if not await _wait_until(func(): return not bool(scene.get("_power_animation_active"))):
				_fail("Refresh did not land before its red-effect capture")
		else:
			await _wait_elapsed(started, float(moment["at"]))
		await _save_capture(str(moment["name"]))
	if not await _wait_until(func(): return not bool(scene.get("_power_animation_active"))):
		_fail("Refresh animation did not finish for %s" % orientation)
	await _wait_until(func(): return CardImpactFx.live_count == 0)

func _capture_undo_hold() -> void:
	var scene = await _open_level("landscape", LANDSCAPE)
	if scene == null:
		return
	var controller: GameController = scene.controller
	var selected := _first_selectable(controller)
	if selected == null:
		_fail("Undo capture has no selectable card")
		return
	controller.select_card(str(selected.id))
	controller.powers.counts["undo"] = 1
	scene.render()
	scene._on_power("undo")
	await _wait_elapsed(Time.get_ticks_msec(), 0.62)
	await _save_capture("undo_red_landing")
	await _wait_until(func(): return not bool(scene.get("_power_animation_active")))
	await _wait_until(func(): return CardImpactFx.live_count == 0)

	var selected_ids: Array[String] = []
	var seen: Dictionary = {}
	for action in controller.get_legal_actions():
		if action["action"] != "select_card":
			continue
		var card: Card = controller.board.get_card(str(action["card_id"]))
		if card == null or seen.has(card.type):
			continue
		seen[card.type] = true
		selected_ids.append(str(card.id))
		if selected_ids.size() == 3:
			break
	if selected_ids.size() < 3:
		_fail("Hold capture could not find three distinct card types")
		return
	for card_id in selected_ids:
		controller.select_card(card_id)
	controller.powers.counts["hold"] = 1
	scene.render()
	scene._on_power("hold")
	await _wait_elapsed(Time.get_ticks_msec(), 0.62)
	await _save_capture("hold_red_landing")
	await _wait_until(func(): return not bool(scene.get("_power_animation_active")))
	await _wait_until(func(): return CardImpactFx.live_count == 0)

func _first_selectable(controller: GameController) -> Card:
	for action in controller.get_legal_actions():
		if action["action"] == "select_card":
			return controller.board.get_card(str(action["card_id"]))
	return null

func _open_level(orientation: String, window_size: Vector2i):
	_game.settings["orientation"] = orientation
	_game.settings["mascot"] = true
	_game.apply_orientation()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	await process_frame
	await process_frame
	_game.endless_run = null
	_game.current_level_id = "6"
	var previous = current_scene
	change_scene_to_file("res://scenes/level.tscn")
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene != null and scene != previous and scene.name == "LevelScreen" and scene.get("controller") != null:
			var ready: bool = await _wait_until(func(): return not scene.is_dealing() and CardImpactFx.live_count == 0)
			if not ready:
				_fail("level did not settle before capture")
			return scene
	_fail("level did not load for %s" % orientation)
	return null

func _wait_elapsed(started_msec: int, seconds: float) -> void:
	while float(Time.get_ticks_msec() - started_msec) / 1000.0 < seconds:
		await process_frame

func _save_capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if name == "refresh_landscape_red_landing":
		_compose_refresh_impact_detail(image)
	var path := "%s/%s.png" % [OUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		_fail("could not save %s (%s)" % [name, error_string(error)])
	else:
		print("PHASE S CAPTURE %s %dx%d" % [path, image.get_width(), image.get_height()])

func _compose_refresh_impact_detail(image: Image) -> void:
	var scene = current_scene
	var layer: Node = scene.find_child("FxLayer", true, false) if scene != null else null
	if layer == null:
		_fail("Refresh landing capture has no FxLayer")
		return
	for child in layer.get_children():
		if not (child is CardImpactFx) or str(child.get_meta("palette", "green")) != "red" or not bool(child.get_meta("full", false)):
			continue
		var screen_center: Vector2 = root.get_final_transform() * (child as CanvasItem).global_position
		var viewport := Rect2i(Vector2i.ZERO, image.get_size())
		var crop_rect := Rect2i(Vector2i(screen_center) - Vector2i(128, 128), Vector2i(256, 256)).intersection(viewport)
		if crop_rect.size.x < 32 or crop_rect.size.y < 32:
			continue
		var detail := image.get_region(crop_rect)
		detail.resize(320, 320, Image.INTERPOLATE_LANCZOS)
		var insert_at := Vector2i(image.get_width() - 332, image.get_height() - 332)
		image.fill_rect(Rect2i(insert_at - Vector2i(3, 3), Vector2i(326, 326)), Color("#f2c46d"))
		image.blit_rect(detail, Rect2i(Vector2i.ZERO, detail.get_size()), insert_at)
		print("PHASE S CAPTURE red impact detail inset from %s" % str(child.global_position))
		return
	_fail("Refresh landing capture did not find a full red impact for the detail inset")

func _wait_until(condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		if condition.call():
			return true
		await process_frame
	return false

func _fail(message: String) -> void:
	_failures.append(message)
	printerr("PHASE S CAPTURE FAIL: " + message)

func _finish() -> void:
	Engine.time_scale = 1.0
	LevelLoader.deterministic = false
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("PHASE S CAPTURES OK dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
		quit(0)
		return
	quit(1)
