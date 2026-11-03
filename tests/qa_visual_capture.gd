extends SceneTree

# QA (Sentinela) visual capture harness. Runs the real UI in a windowed instance and saves
# viewport PNGs for the final report, plus two runtime checks that are hard to see in a
# still: menu frame pacing and the parallax reset when returning from Options.
#
# Usage (windowed, GPU required):
#   Godot_v4.7-stable_win64_console.exe --path E:\Cartitas --script res://tests/qa_visual_capture.gd
# Output: user://qa_shots/*.png (the globalized path is printed at the end).

const OUT_DIR := "user://qa_shots"
const VIEWS := [
	{"tag": "portrait", "orientation": "portrait", "window": Vector2i(720, 1280)},
	{"tag": "landscape", "orientation": "landscape", "window": Vector2i(1280, 720)},
]
const LEVELS := ["1", "6", "8", "11"]
const LEVEL_TAG := {"1": "L1", "6": "L6", "8": "L8", "11": "L11"}

var _game
var _failures: Array[String] = []
var _saved: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _seconds(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := image.save_png(path)
	if err != OK:
		_failures.append("could not save %s (err %d)" % [path, err])
	else:
		_saved.append("%s %dx%d" % [name, image.get_width(), image.get_height()])
	print("QA SHOT %s %dx%d" % [name, image.get_width(), image.get_height()])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	if _game == null:
		printerr("QA CAPTURE FAIL: Game autoload missing")
		quit(1)
		return
	LevelLoader.deterministic = true
	_game.save_path = "user://qa_capture_save.json"
	# Index 1 advances to Cathedral, which has a painted foreground character; capture
	# both orientations to verify the separate hero pair stays hidden there.
	_game.settings["menu_bg_index"] = 1
	for view in VIEWS:
		await _capture_view(view)
	await _capture_match_fx()
	print("QA CAPTURE DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	for s in _saved:
		print("  " + s)
	if _failures.is_empty():
		print("QA VISUAL CHECKS OK")
		quit(0)
		return
	for f in _failures:
		printerr("QA VISUAL FAIL: " + f)
	quit(1)

func _capture_view(view: Dictionary) -> void:
	var tag: String = view["tag"]
	_game.settings["orientation"] = view["orientation"]
	_game.apply_orientation()
	root.size = view["window"]
	await _frames(4)

	# Menu, fresh. Then measure pacing and the Options round trip.
	change_scene_to_file("res://scenes/main.tscn")
	var menu = null
	for i in 120:
		await process_frame
		if current_scene != null and current_scene.name == "MainMenu":
			menu = current_scene
			break
	if menu == null:
		_failures.append("%s: main menu did not load" % tag)
		return
	if not bool(menu.get("_menu_background_show_heroes")) and (
		menu.find_child("MenuHero", true, false) != null
		or menu.find_child("MenuHeroSecondary", true, false) != null):
		_failures.append("%s: separate heroes overlap characters painted into the selected background" % tag)
	await _frames(20)
	await _shot("%s_menu" % tag)
	await _check_menu_pacing(menu, tag)
	await _check_options_round_trip(menu, tag)
	await _shot("%s_menu_after_options" % tag)

	# Painted world map replaces the former scrolling level list.
	change_scene_to_file("res://scenes/level_select.tscn")
	var map_scene: Node = null
	for _frame in 120:
		await process_frame
		if current_scene != null and current_scene.name == "LevelSelectMap":
			map_scene = current_scene
			break
	if map_scene == null:
		_failures.append("%s: world map did not load" % tag)
	else:
		await _frames(8)
		await _shot("%s_level_map" % tag)

	# Levels.
	for level_id in LEVELS:
		_game.current_level_id = level_id
		change_scene_to_file("res://scenes/level.tscn")
		var scene = null
		for i in 120:
			await process_frame
			scene = current_scene
			if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
				break
		if scene == null or scene.get("controller") == null:
			_failures.append("%s: level %s did not load" % [tag, level_id])
			continue
		await _frames(30)
		# The level-name/instruction banner fades after INSTRUCTION_SECONDS (4 s): capture the
		# steady state so the Clearing Zone is judged without the overlay on top of it.
		await _seconds(4.6)
		await _shot("%s_%s" % [tag, LEVEL_TAG[level_id]])
		if level_id == "6":
			_capture_reserve(scene)
			await _frames(4)
			await _shot("%s_reserve_full" % tag)
			# heart + gem side by side at the enlarged zone card size (64 px landscape /
			# 60 px portrait) to judge whether the two card faces read apart in play.
			await _shot("%s_zone_compare" % tag)
			await _shot("%s_powers" % tag)

	# Empty Reserve on a fresh Level 6.
	_game.current_level_id = "6"
	change_scene_to_file("res://scenes/level.tscn")
	for i in 120:
		await process_frame
		if current_scene != null and current_scene.name == "LevelScreen" and current_scene.get("controller") != null:
			break
	await _frames(30)
	await _seconds(4.6)
	await _shot("%s_reserve_empty" % tag)

	# Endless uses the castle backdrop too (level 999); capture round 1 in both views.
	_game.endless_run = EndlessRun.new()
	_game.current_level_id = ""
	change_scene_to_file("res://scenes/level.tscn")
	for i in 120:
		await process_frame
		if current_scene != null and current_scene.name == "LevelScreen" and current_scene.get("controller") != null:
			break
	await _frames(30)
	await _seconds(4.6)
	await _shot("%s_endless" % tag)
	_game.endless_run = null

func _check_menu_pacing(menu, tag: String) -> void:
	# Three seconds of real time: report average, p95 and worst frame time beside parallax movement.
	var samples: Array[float] = []
	var parallax_before: Vector2 = menu.get("_board_layer").position
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var start := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
	if samples.is_empty():
		return
	var total := 0.0
	var worst := 0.0
	for ms in samples:
		total += ms
		worst = maxf(worst, ms)
	var avg := total / float(samples.size())
	samples.sort()
	var p95 := samples[clampi(int(ceil(samples.size() * 0.95)) - 1, 0, samples.size() - 1)]
	var parallax_after: Vector2 = menu.get("_board_layer").position
	var focused: bool = menu.get_window().has_focus()
	print("QA MENU PACING %s frames=%d avg=%.2fms (%.1ffps) p95=%.2fms worst=%.2fms max_fps=%d vsync=%d focus=%s parallax_drift=%.2fpx" % [
		tag, samples.size(), avg, 1000.0 / maxf(0.001, avg), p95, worst, Engine.max_fps,
		DisplayServer.window_get_vsync_mode(), str(focused), parallax_before.distance_to(parallax_after),
	])
	# This harness is often run alongside the open editor; focus/VSync scheduling varies after
	# switching portrait and landscape windows. Keep the three-second measurement in the log;
	# the dedicated focused probe is the authoritative refresh-rate check.
	if worst > 120.0:
		_failures.append("%s: menu hit a %.0f ms stall" % [tag, worst])

func _check_options_round_trip(menu, tag: String) -> void:
	# The parallax must not inherit the Options screen's pointer when the menu is rebuilt.
	menu.call("set_parallax", Vector2(9.0, 7.0))
	menu.call("_on_options")
	await _frames(3)
	await _shot("%s_options" % tag)
	menu.call("_on_back")
	await _frames(3)
	var pointer: Vector2 = menu.get("_pointer")
	var goal: Vector2 = menu.get("_pointer_goal")
	var layer: Vector2 = menu.get("_board_layer").position
	print("QA OPTIONS ROUND TRIP %s pointer=%s goal=%s layer=%s" % [tag, str(pointer), str(goal), str(layer)])
	if pointer.length() > 0.001 or goal.length() > 0.001:
		_failures.append("%s: parallax pointer not reset after Options (%s / %s)" % [tag, str(pointer), str(goal)])
	# _board_layer.y also carries the intended idle bob (amplitude 2 px); the parallax part is x.
	if absf(layer.x) > 0.001 or absf(layer.y) > 2.5:
		_failures.append("%s: parallax layer still offset after Options (%s)" % [tag, str(layer)])

func _capture_reserve(scene) -> void:
	var c = scene.controller
	for card in c.board.cards:
		card.state = Card.State.REMOVED
	c.deck_a.current_index = c.deck_a.card_types.size()
	c.deck_b.current_index = c.deck_b.card_types.size()
	c.zone.cards.clear()
	var types := ["heart", "gem", "heart", "gem", "leaf", "frog", "sacer"]
	for i in types.size():
		var z := Card.new("qa_zone_%d" % i, types[i])
		z.source = Card.Source.DECK_A
		c.zone.add(z)
	c.reserve.clear()
	var reserve_types := ["heart", "gem", "frog", "leaf", "sacer"]
	for i in reserve_types.size():
		var r := Card.new("qa_res_%d" % i, reserve_types[i])
		r.source = Card.Source.DECK_A
		r.location = Card.Location.RESERVE
		r.state = Card.State.SELECTED
		c.reserve.append(r)
	c.powers.counts = {"hold": 1, "undo": 5, "refresh": 4}
	scene.render()

func _capture_match_fx() -> void:
	# A synthetic trio over the board centre exercises the same _play_match path a real match
	# uses (flash panels + painted burst/smoke), without mutating gameplay state.
	_game.settings["orientation"] = "landscape"
	_game.apply_orientation()
	root.size = Vector2i(1280, 720)
	await _frames(4)
	_game.current_level_id = "6"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = null
	for i in 120:
		await process_frame
		scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			break
	if scene == null:
		_failures.append("FX: level did not load")
		return
	await _frames(30)
	await _seconds(4.6)
	var center := Vector2(320, 170)
	var group = load("res://scripts/ui/level_screen.gd").MatchGroup.new()
	for i in 3:
		group.rects.append(Rect2(center + Vector2(-66 + i * 64, -30), Vector2(60, 60)))
	scene.call("_play_match", group)
	await process_frame
	await process_frame
	await _shot("landscape_match_fx")
