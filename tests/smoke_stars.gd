extends SceneTree

# Live stars plaque (campaign HUD): the base picture shows the stars kept (stars_3 -> stars_2 ->
# stars_1); the star at stake turns to stone gradually (an overlay of the next-lower picture
# fades in); when its threshold passes the base switches and a puff of smoke is left at that
# star's place; the first star never turns to stone. A rebuild after stars were lost shows the
# right state with no puff. The campaign win panel shows the earned plaque and fits both
# orientations.

const THROWAWAY_SAVE := "user://smoke_stars_save.json"
const HUD_DIR := "res://assets/ui/hud/"

var _errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors.append(msg)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

# Tweens run on real time and headless frames are faster, so wait on the clock.
func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _stars_texture(n: int) -> Texture2D:
	return UiHelpers.hires_texture(HUD_DIR + "stars_%d.png" % n)

func _open_level(game, level_id: String, orientation: String, window: Vector2i):
	game.settings["orientation"] = orientation
	game.apply_orientation()
	root.size = window
	await _frames(3)
	game.current_level_id = level_id
	change_scene_to_file("res://scenes/level.tscn")
	var scene = null
	for i in 120:
		await process_frame
		scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			break
	if scene == null or scene.get("controller") == null:
		return null
	await _frames(10)
	return scene

func _run() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		printerr("SMOKE STARS FAIL: Game autoload missing")
		quit(1)
		return
	game.save_path = THROWAWAY_SAVE
	LevelLoader.deterministic = true
	# The tallest win panel has Ace's line in it.
	game.settings["mascot"] = true
	var scene = await _open_level(game, "1", "landscape", Vector2i(640, 360))
	if scene == null:
		_finish(["level did not load"])
		return
	var c = scene.controller
	var plaque = scene.get("stars_row")
	var base: TextureRect = scene.get("stars_base")
	var overlay: TextureRect = scene.get("stars_overlay")
	_check(plaque != null and plaque.name == "StarsPill", "the plaque node is named StarsPill")
	_check(base != null and overlay != null, "the plaque has a base and an overlay picture")
	if base == null or overlay == null:
		_finish(_errors)
		return
	_check(base.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and overlay.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "the plaque art is drawn with mipmaps + trilinear filtering")
	_check(plaque.size.is_equal_approx(Vector2(90, 36)), "landscape plaque is 90x36 (got %s)" % plaque.size)
	var three: float = float(c.time_thresholds["three_stars"])
	var two: float = float(c.time_thresholds["two_stars"])

	# Fresh level: 3 stars, nothing fading.
	_check(base.texture == _stars_texture(3) and scene.get("stars_shown") == 3, "a fresh level shows stars_3")
	_check(overlay.modulate.a < 0.2, "the star at stake has barely started to fade at the start")

	# Halfway to the 3-star time: the third star is turning to stone (stars_2 fading in).
	c.timer.set_elapsed_seconds(three * 0.5)
	await _frames(2)
	var burn: float = scene._star_burn(three * 0.5, 3)
	_check(base.texture == _stars_texture(3), "the base is still stars_3 while fading")
	_check(overlay.texture == _stars_texture(2), "the overlay is the stars_2 picture")
	_check(absf(overlay.modulate.a - burn) < 0.02 and overlay.modulate.a > 0.3 and overlay.modulate.a < 0.7, "the overlay is about half faded (alpha %.2f, burn %.2f)" % [overlay.modulate.a, burn])

	# Past the 3-star time: the base switches to stars_2 and smoke is left at the third star.
	c.timer.set_elapsed_seconds(three + 1.0)
	await _frames(2)
	var fx: Node = scene.find_child("FxLayer", true, false)
	_check(fx != null and fx.get_child_count() > 0, "the puff leaves smoke on the overlay")
	_check(base.texture == _stars_texture(2) and scene.get("stars_shown") == 2, "the base switches to stars_2")
	if fx != null and fx.get_child_count() > 0:
		var expected: Vector2 = plaque.global_position + Vector2(plaque.size.x * 0.765, plaque.size.y * 0.52)
		var mean := Vector2.ZERO
		var smoke := 0
		for child in fx.get_children():
			if child is Panel:
				mean += (child as Control).global_position + (child as Control).size * 0.5
				smoke += 1
		_check(smoke > 0, "the smoke is made of puffs")
		if smoke > 0:
			mean /= float(smoke)
			_check(mean.distance_to(expected) < 8.0, "the smoke is at the third star (%s vs %s)" % [str(mean), str(expected)])
	await _wait_ms(700)
	_check(fx == null or not is_instance_valid(fx) or fx.get_child_count() == 0, "the smoke is gone after the puff")

	# Next star starts fading: stars_1 in.
	c.timer.set_elapsed_seconds((three + two) * 0.5 + 1.0)
	await _frames(2)
	_check(overlay.texture == _stars_texture(1) and overlay.modulate.a > 0.2, "the second star fades next (alpha %.2f)" % overlay.modulate.a)

	# Past the 2-star time: stars_1; the puff is at the middle star.
	c.timer.set_elapsed_seconds(two + 1.0)
	await _frames(2)
	_check(base.texture == _stars_texture(1) and scene.get("stars_shown") == 1, "after the 2-star time the base is stars_1")
	await _wait_ms(700)
	# Star 1 never turns to stone, however long it takes.
	c.timer.set_elapsed_seconds(two * 10.0)
	await _frames(5)
	_check(base.texture == _stars_texture(1) and overlay.modulate.a <= 0.001, "star 1 never turns to stone")

	# A rebuild shows the right state with no puff.
	scene._build_ui()
	await _frames(2)
	scene.render()
	await _frames(3)
	_check(scene.get("stars_base").texture == _stars_texture(1) and scene.get("stars_shown") == 1, "rebuild shows stars_1")
	var fx2: Node = scene.find_child("FxLayer", true, false)
	_check(fx2 == null or fx2.get_child_count() == 0, "rebuild does not replay the puff")

	# Portrait: the plaque is smaller, and the same states hold.
	var portrait = await _open_level(game, "1", "portrait", Vector2i(360, 640))
	if portrait == null:
		_check(false, "portrait level did not load")
	else:
		var pplaque = portrait.get("stars_row")
		_check(pplaque != null and pplaque.size.is_equal_approx(Vector2(70, 28)), "portrait plaque is 70x28")
		portrait.controller.timer.set_elapsed_seconds(float(portrait.controller.time_thresholds["three_stars"]) + 1.0)
		await _frames(3)
		_check(portrait.get("stars_base").texture == _stars_texture(2), "portrait: the base switches to stars_2")

	# Campaign win panel: the earned plaque, inside the screen, in both orientations.
	for view in [["landscape", Vector2i(640, 360)], ["portrait", Vector2i(360, 640)]]:
		var win_scene = await _open_level(game, "2", view[0], view[1])
		if win_scene == null:
			_check(false, "%s: level did not load for the win panel" % view[0])
			continue
		var wc = win_scene.controller
		wc.stars = 2
		# The tallest panel: a first win, so the reward lines are there too (in memory only).
		game.progress = ProgressManager.new()
		wc.rewards = [{"type": "undo", "quantity": 1}]
		win_scene.call("_show_end", true)
		await _frames(3)
		var end_stars := win_scene.find_child("EndStars", true, false) as TextureRect
		_check(end_stars != null and end_stars.texture == _stars_texture(2), "%s: the win panel shows the stars_2 plaque" % view[0])
		await _wait_ms(700)
		var screen := Rect2(Vector2.ZERO, win_scene.get_viewport_rect().size)
		if end_stars != null:
			_check(end_stars.get_global_rect().size.x >= 130.0 and end_stars.get_global_rect().size.x <= 180.0, "%s: plaque width is 130-180 px (got %s)" % [view[0], end_stars.get_global_rect().size])
			_check(end_stars.scale.is_equal_approx(Vector2.ONE) and end_stars.modulate.a > 0.99, "%s: the plaque popped in" % view[0])
			var panel := end_stars.get_parent().get_parent() as Control
			_check(screen.grow(-6.0).encloses(panel.get_global_rect()), "%s: win panel %s fits the screen %s with a 6 px margin" % [view[0], str(panel.get_global_rect()), str(screen)])
	_finish(_errors)

func _finish(errors: Array) -> void:
	LevelLoader.deterministic = false
	if FileAccess.file_exists(THROWAWAY_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(THROWAWAY_SAVE))
	if errors.is_empty():
		print("SMOKE STARS OK")
		quit(0)
		return
	for e in errors:
		printerr("SMOKE STARS FAIL: " + e)
	quit(1)
