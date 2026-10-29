extends SceneTree

# In-game settings (gear in the top bar): opening pauses the clock; language, orientation and
# mascot apply at once without touching the level state (zone, board, clock); the volume row
# changes Game.volume(); closing (button, corner icon, shade tap, ui_cancel) resumes the clock.
# Works in a campaign Level and in Endless. Settings are saved through Game.save_path, which is
# pointed at a throwaway file before anything runs (the player's save is never written).

const THROWAWAY_SAVE := "user://smoke_settings_save.json"

var _errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors.append(msg)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _run() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		printerr("SMOKE SETTINGS FAIL: Game autoload missing")
		quit(1)
		return
	# First thing: nothing below may write to the real save.
	game.save_path = THROWAWAY_SAVE
	LevelLoader.deterministic = true
	game.settings["orientation"] = "landscape"
	game.settings["mascot"] = true
	game.settings["locale"] = "en"
	game.settings["volume"] = 1.0
	game.settings["sound"] = true
	Localizer.current = "en"
	game.apply_orientation()
	root.size = Vector2i(640, 360)
	await _frames(3)

	await _campaign(game)
	await _endless(game)

	LevelLoader.deterministic = false
	if FileAccess.file_exists(THROWAWAY_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(THROWAWAY_SAVE))
	if _errors.is_empty():
		print("SMOKE SETTINGS OK")
		quit(0)
		return
	for e in _errors:
		printerr("SMOKE SETTINGS FAIL: " + e)
	quit(1)

func _wait_level(endless: bool):
	for i in 120:
		await process_frame
		var scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			# Past the intro title, so the first rebuild cannot cut it short.
			await _wait_ms(1100)
			return scene
	return null

# What must survive any settings change: the clock, the zone, the board, the Reserve, the decks.
func _state(c) -> Dictionary:
	var zone: Array = []
	for card in c.zone.cards:
		zone.append(card.id)
	var board: Array = []
	for card in c.board.cards:
		if card.location == Card.Location.BOARD and not card.is_removed():
			board.append(card.id)
	return {
		"status": c.status, "elapsed": c.timer.elapsed_seconds(), "zone": zone, "board": board,
		"reserve": c.reserve.size(), "deck_a": c.deck_a.remaining_count(), "deck_b": c.deck_b.remaining_count(),
	}

func _same_state(a: Dictionary, b: Dictionary) -> bool:
	return a["zone"] == b["zone"] and a["board"] == b["board"] and a["reserve"] == b["reserve"] \
			and a["deck_a"] == b["deck_a"] and a["deck_b"] == b["deck_b"] and is_equal_approx(float(a["elapsed"]), float(b["elapsed"]))

func _press(scene, node_name: String, tag: String) -> bool:
	var overlay: Node = scene.get_node_or_null("SettingsOverlay")
	var btn := (overlay.find_child(node_name, true, false) if overlay != null else null) as BaseButton
	if btn == null:
		_check(false, "%s: no %s in the overlay" % [tag, node_name])
		return false
	btn.pressed.emit()
	return true

func _open_settings(scene, tag: String) -> Control:
	var gear := scene.find_child("SettingsButton", true, false) as Button
	_check(gear != null, "%s: the top bar has a gear" % tag)
	if gear == null:
		return null
	gear.pressed.emit()
	await _frames(3)
	var overlay := scene.get_node_or_null("SettingsOverlay") as Control
	_check(overlay != null, "%s: the gear opens the settings overlay" % tag)
	return overlay

func _campaign(game) -> void:
	game.endless_run = null
	game.current_level_id = "3"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level(false)
	if scene == null:
		_check(false, "campaign: level did not load")
		return
	var c = scene.controller
	# One real move first, so the state being protected is not empty.
	for card in c.board.cards:
		if card.state == Card.State.AVAILABLE and card.location == Card.Location.BOARD:
			scene._on_card(card.id)
			break
	await _wait_ms(500)
	_check(c.status == GameController.Status.PLAYING, "campaign: the clock runs before opening")

	var overlay := await _open_settings(scene, "campaign")
	if overlay == null:
		return
	_check(c.status == GameController.Status.PAUSED, "campaign: the gear pauses the clock")
	# Taken once paused, so the clock reading is exact.
	var before := _state(c)
	_check(before["zone"].size() > 0, "campaign: there is a state to protect")
	var viewport := Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
	for node_name in ["LanguageButton", "OrientationButton", "MascotButton", "VolumeRow", "VolumeDown", "VolumeSlider", "VolumeUp", "SoundButton", "SettingsClose", "SettingsCornerClose"]:
		_check(overlay.find_child(node_name, true, false) != null, "campaign: the overlay has %s" % node_name)
	var panel := overlay.find_child("SettingsPanel", true, false) as Control
	_check(panel != null and viewport.encloses(panel.get_global_rect()), "campaign: the panel fits the viewport (%s in %s)" % [str(panel.get_global_rect()) if panel != null else "-", str(viewport)])
	await _wait_ms(300)
	_check(is_equal_approx(c.timer.elapsed_seconds(), float(before["elapsed"])), "campaign: the clock is stopped while the overlay is open")

	# Language: texts change, the state does not.
	var heading_before := _heading(scene)
	var gear_tip_before: String = (scene.find_child("SettingsButton", true, false) as Button).tooltip_text
	if _press(scene, "LanguageButton", "campaign"):
		await _frames(4)
		_check(Localizer.current == "pt" and game.settings["locale"] == "pt", "campaign: language toggles to Portuguese and is stored")
		_check(_heading(scene) != heading_before and _heading(scene) == Localizer.t("settings"), "campaign: the overlay text follows the language (%s)" % _heading(scene))
		_check((scene.find_child("SettingsButton", true, false) as Button).tooltip_text != gear_tip_before, "campaign: the HUD text follows the language")
		_check(scene.controller == c, "campaign: the same controller after a language change")
		_check(scene.get_node_or_null("SettingsOverlay") != null and c.status == GameController.Status.PAUSED, "campaign: the overlay stays open and the clock paused")
		_check(_same_state(before, _state(c)), "campaign: zone, board and clock are unchanged by the language")
		_check(scene.board_container.get_child_count() == before["board"].size(), "campaign: the board is redrawn (%d cards)" % scene.board_container.get_child_count())
		_check(SaveManager.load(THROWAWAY_SAVE).get("settings", {}).get("locale", "") == "pt", "campaign: the language is saved")
	# ...and back to English.
	if _press(scene, "LanguageButton", "campaign"):
		await _frames(4)
		_check(Localizer.current == "en", "campaign: language toggles back")

	# Orientation: the screen re-lays out and the level goes on.
	if _press(scene, "OrientationButton", "campaign"):
		for i in 30:
			await process_frame
			if scene.get_viewport_rect().size.x < scene.get_viewport_rect().size.y:
				break
		if scene.get_viewport_rect().size.x >= scene.get_viewport_rect().size.y:
			# A headless window does not resize by itself: do what the OS would.
			root.size = Vector2i(360, 640)
		await _wait_ms(400)
		var size: Vector2 = scene.get_viewport_rect().size
		_check(size.x < size.y, "campaign: the viewport turns portrait (%s)" % str(size))
		_check(game.settings["orientation"] == "portrait", "campaign: the orientation is stored")
		_check(not bool(scene.get("_is_landscape")), "campaign: the screen re-laid out as portrait")
		_check(scene.controller == c, "campaign: the same controller after the orientation change")
		_check(_same_state(before, _state(c)), "campaign: zone, board and clock are unchanged by the orientation")
		var hud := scene.find_child("Hud", true, false) as Control
		_check(hud != null and absf(hud.size.x - 360.0) < 0.5, "campaign: the HUD follows the new width")
		overlay = scene.get_node_or_null("SettingsOverlay")
		_check(overlay != null and c.status == GameController.Status.PAUSED, "campaign: the overlay survives the re-layout, clock paused")
		if overlay != null:
			var pp := overlay.find_child("SettingsPanel", true, false) as Control
			var vp := Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
			_check(pp != null and vp.encloses(pp.get_global_rect()), "campaign: the panel fits the portrait viewport")
		_check(scene.board_container.get_child_count() == before["board"].size(), "campaign: the board is redrawn in portrait")

	# Mascot off hides Ace; on brings it back.
	_check(scene.mascot != null, "campaign: Ace is there before")
	if _press(scene, "MascotButton", "campaign"):
		await _frames(4)
		_check(scene.mascot == null and not game.mascot_enabled(), "campaign: mascot off removes Ace")
		_check(scene.find_child("Mascot", true, false) == null, "campaign: no Mascot node is left")
		_check(_same_state(before, _state(c)), "campaign: the state is unchanged by the mascot toggle")
	if _press(scene, "MascotButton", "campaign"):
		await _wait_ms(300)
		_check(scene.mascot != null and game.mascot_enabled(), "campaign: mascot on brings Ace back")

	# Volume: minus lowers it, the glyph follows, the HUD icon too.
	var volume_before: float = game.volume()
	var icon_before: Texture2D = (scene.find_child("SoundButton", true, false) as Button).get_node("Icon").texture
	var overlay_now: Node = scene.get_node_or_null("SettingsOverlay")
	var minus := (overlay_now.find_child("VolumeDown", true, false) as TextureButton) if overlay_now != null else null
	if minus != null:
		minus.pressed.emit()
		await _frames(2)
		_check(game.volume() < volume_before and is_equal_approx(game.volume(), 0.75), "campaign: minus lowers the volume (%.2f)" % game.volume())
		_check(is_equal_approx(float(SaveManager.load(THROWAWAY_SAVE).get("settings", {}).get("volume", -1.0)), 0.75), "campaign: the volume is saved")
		# Down to zero: muted, and the HUD sound icon changes with it.
		for i in 3:
			minus.pressed.emit()
		await _frames(2)
		_check(not game.sound_enabled(), "campaign: the volume reaches mute")
		var hud_icon: Texture2D = (scene.find_child("SoundButton", true, false) as Button).get_node("Icon").texture
		_check(hud_icon != icon_before, "campaign: the HUD sound icon follows the volume row")
		var plus := overlay_now.find_child("VolumeUp", true, false) as TextureButton
		plus.pressed.emit()
		plus.pressed.emit()
		await _frames(2)
		_check(game.sound_enabled(), "campaign: plus brings the sound back")

	# Close: button, corner icon, shade tap and ui_cancel each resume the clock.
	for closer in ["button", "corner", "shade", "cancel"]:
		if scene.get_node_or_null("SettingsOverlay") == null:
			overlay = await _open_settings(scene, "campaign-%s" % closer)
			if overlay == null:
				return
		_check(c.status == GameController.Status.PAUSED, "campaign: paused while open (%s)" % closer)
		match closer:
			"button":
				_press(scene, "SettingsClose", "campaign")
			"corner":
				_press(scene, "SettingsCornerClose", "campaign")
			"shade":
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				(scene.get_node("SettingsOverlay").find_child("SettingsShade", true, false) as Control).gui_input.emit(click)
			"cancel":
				var esc := InputEventAction.new()
				esc.action = "ui_cancel"
				esc.pressed = true
				scene._unhandled_input(esc)
		await _frames(3)
		_check(scene.get_node_or_null("SettingsOverlay") == null, "campaign: %s closes the overlay" % closer)
		_check(c.status == GameController.Status.PLAYING, "campaign: %s resumes the clock" % closer)
	var elapsed: float = c.timer.elapsed_seconds()
	await _wait_ms(400)
	_check(c.timer.elapsed_seconds() > elapsed, "campaign: the clock runs again after closing")

func _heading(scene) -> String:
	var overlay: Node = scene.get_node_or_null("SettingsOverlay")
	if overlay == null:
		return ""
	var panel: Node = overlay.find_child("SettingsPanel", true, false)
	if panel == null:
		return ""
	for label in panel.find_children("*", "Label", true, false):
		return (label as Label).text
	return ""

func _endless(game) -> void:
	game.progress = ProgressManager.new()
	game.settings["orientation"] = "landscape"
	game.settings["mascot"] = true
	game.apply_orientation()
	root.size = Vector2i(640, 360)
	await _frames(3)
	game.start_endless()
	var scene = await _wait_level(true)
	if scene == null:
		_check(false, "endless: round did not load")
		return
	var c = scene.controller
	var overlay := await _open_settings(scene, "endless")
	if overlay == null:
		return
	_check(c.status == GameController.Status.PAUSED, "endless: the gear pauses the clock")
	var before := _state(c)
	if _press(scene, "LanguageButton", "endless"):
		await _frames(4)
		_check(scene.controller == c and _same_state(before, _state(c)), "endless: language change keeps the round state")
		_check(scene.score_label != null and scene.find_child("ScorePill", true, false) != null, "endless: the score plate survives the rebuild")
	_press(scene, "SettingsClose", "endless")
	await _frames(3)
	_check(scene.get_node_or_null("SettingsOverlay") == null and c.status == GameController.Status.PLAYING, "endless: close resumes the clock")
