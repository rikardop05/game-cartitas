extends SceneTree

# Main menu smoke test, driven through the real scene: the three main buttons exist and are
# clickable in both locales (Portuguese uses the baked kit artwork, English the blank plate with
# localized text), Play opens the level list and Back returns, Options shows the Sound toggle
# (which flips Game.sound_enabled()), and "Reset progress" needs its confirm step.
# The scene saves through Game.save_path, which is pointed at a throwaway user:// file before
# anything runs; the real save is also checked byte-for-byte at the end.

const STEP_TIMEOUT_MS := 20000
const THROWAWAY_SAVE := "user://smoke_main_menu_save.json"
const MAIN_BUTTONS := {
	"PlayButton": {"key": "play", "pt_texture": "btn_menu_jogar.png"},
	"OptionsButton": {"key": "options", "pt_texture": "btn_menu_opcoes.png"},
	"QuitButton": {"key": "quit", "pt_texture": "btn_menu_sair.png"},
}

var _failures: Array[String] = []
var _save_before: Dictionary
var _game

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_save_before = _snapshot_save()
	var game = root.get_node_or_null("Game")
	if game == null:
		_fail("Game autoload not available")
	else:
		_game = game
		# First thing: nothing below may write to the real save.
		game.save_path = THROWAWAY_SAVE
		_remove_throwaway_save()
		await _scenario(game)
	_finish()

func _scenario(game) -> void:
	game.progress = ProgressManager.new()
	game.settings["sound"] = true
	game.settings["volume"] = 1.0
	game.settings["mascot"] = true
	change_scene_to_file("res://scenes/main.tscn")
	var menu = await _wait_scene("MainMenu")
	if menu == null:
		return

	for locale in ["pt", "en"]:
		game.set_locale(locale)
		menu._build()
		await _frames(3)
		_check_menu(menu, locale)

	# Play opens the level list; Back returns to the menu (English is still active).
	_press(menu, "PlayButton")
	await _frames(3)
	_check(_find_label(menu, Localizer.t("select_level")) != null, "levels screen shows its heading")
	var level_buttons := 0
	for n in _all_nodes(menu):
		if n is Button and (n as Button).text.begins_with("Level"):
			level_buttons += 1
	_check(level_buttons > 0, "levels screen has level buttons")
	_check(menu.find_child("EndlessButton", true, false) != null, "levels screen has the Endless entry")
	_check(menu.find_child("Window", true, false) != null, "level list sits on a kit window")
	_press(menu, "BackButton")
	await _frames(3)
	_check(menu.find_child("PlayButton", true, false) != null, "Back returns to the main menu")
	# The sign layout is measured in untransformed space, so it must not move with
	# the parallax (the old code read the transformed content container).
	var board := menu.get("_board") as Control
	var board_layer := menu.get("_board_layer") as Control
	if board != null and board_layer != null:
		menu.set_parallax(Vector2.ZERO)
		menu.call("_layout_board")
		var origin_zero := board.position + board_layer.position
		menu.set_parallax(Vector2(1, 1))
		menu.call("_layout_board")
		var origin_moved := board.position + board_layer.position
		_check(origin_zero.is_equal_approx(origin_moved), "menu sign layout is stable under parallax")
		menu.set_parallax(Vector2.ZERO)
	var board_shadow := menu.find_child("BoardShadow", true, false) as TextureRect
	_check(board_shadow != null and board_shadow.material == null, "menu shadow is pre-rendered (no per-pixel shader)")

	# Options: volume row (minus, slider, plus, mute glyph).
	_press(menu, "OptionsButton")
	await _frames(3)
	_check(_find_label(menu, Localizer.t("options")) != null, "options screen shows its heading")
	for node_name in ["LanguageButton", "OrientationButton", "MascotButton", "VolumeRow", "VolumeDown", "VolumeSlider", "VolumeUp", "SoundButton", "ResetButton"]:
		_check(menu.find_child(node_name, true, false) != null, "options has %s" % node_name)
	var mute := menu.find_child("SoundButton", true, false) as TextureButton
	var slider := menu.find_child("VolumeSlider", true, false) as Control
	if mute == null or slider == null:
		return
	_check(is_equal_approx(game.volume(), 1.0) and game.sound_enabled(), "sound starts at full volume")
	_check(_sound_icon_is(menu, "icon_sound_on.png"), "volume row shows the 'on' glyph")
	var handle := slider.find_child("Handle", true, false) as Control
	var full_x := handle.position.x if handle != null else -1.0
	# Minus steps the volume down and moves the handle left.
	_press_texture(menu, "VolumeDown")
	await _frames(2)
	_check(is_equal_approx(game.volume(), 0.75), "minus lowers the volume to 0.75 (got %.2f)" % game.volume())
	_check(handle != null and handle.position.x < full_x, "the handle moves left with the volume")
	# A click at the slider's left end mutes: glyph turns 'off', saved on release.
	_click_slider(slider, 0.0)
	await _frames(2)
	_check(is_zero_approx(game.volume()) and not game.sound_enabled(), "clicking the left end mutes")
	_check(_sound_icon_is(menu, "icon_sound_off.png"), "muted shows the 'off' glyph")
	_check(is_zero_approx(float(SaveManager.load(THROWAWAY_SAVE).get("settings", {}).get("volume", -1.0))), "mute is saved to the throwaway file")
	# The glyph unmutes back to the last volume, plus raises it.
	mute.pressed.emit()
	await _frames(2)
	_check(is_equal_approx(game.volume(), 0.75), "the glyph unmutes to the last volume (got %.2f)" % game.volume())
	_press_texture(menu, "VolumeUp")
	await _frames(2)
	_check(is_equal_approx(game.volume(), 1.0), "plus raises the volume back to 1.0")
	_check(_sound_icon_is(menu, "icon_sound_on.png"), "unmuted shows the 'on' glyph")

	# Reset progress: needs the confirm step, and Cancel keeps the progress.
	game.progress.levels["1"] = {"completed": true, "stars": 3}
	_press(menu, "ResetButton")
	await _frames(3)
	_check(game.progress.get_stars("1") == 3, "first tap on Reset does not erase progress")
	var confirm := menu.find_child("ResetConfirm", true, false) as Button
	var cancel := menu.find_child("ResetCancel", true, false) as Button
	_check(confirm != null and cancel != null, "reset shows the confirm and cancel buttons")
	_check(menu.find_child("ResetButton", true, false) == null, "the plain Reset button is replaced by the confirm step")
	if confirm == null or cancel == null:
		return
	_check(confirm.icon != null and confirm.icon.resource_path.ends_with("icon_accept.png"), "confirm uses icon_accept")
	_check(cancel.icon != null and cancel.icon.resource_path.ends_with("icon_close_red.png"), "cancel uses icon_close_red")
	cancel.pressed.emit()
	await _frames(3)
	_check(game.progress.get_stars("1") == 3, "Cancel keeps the progress")
	_check(menu.find_child("ResetButton", true, false) != null, "Cancel returns to the plain Reset button")
	_press(menu, "ResetButton")
	await _frames(3)
	_press(menu, "ResetConfirm")
	await _frames(3)
	_check(game.progress.get_stars("1") == 0, "confirming erases the progress")
	_check(menu.find_child("ResetButton", true, false) != null, "Reset is disarmed after confirming")

	# Leaving Options disarms a pending reset.
	_press(menu, "ResetButton")
	await _frames(2)
	_press(menu, "BackButton")
	await _frames(2)
	_press(menu, "OptionsButton")
	await _frames(2)
	_check(menu.find_child("ResetConfirm", true, false) == null, "leaving Options disarms the reset")

# One locale of the main menu: the three buttons exist, are clickable, and show the right face.
func _check_menu(menu, locale: String) -> void:
	var logo := menu.find_child("Logo", true, false) as TextureRect
	_check(logo != null and logo.texture != null, "[%s] menu shows the painted logo" % locale)
	if logo != null and logo.texture != null:
		var source := str(logo.get_meta("source_path", ""))
		_check(source.ends_with("logo_claw_and_crown.png"),
			"[%s] logo uses the Claw & Crown art (got '%s')" % [locale, source])
		_check(logo.size.y >= 40.0, "[%s] logo is legible (height %.1f)" % [locale, logo.size.y])
	_check(menu.find_child("MenuHero", true, false) != null, "[%s] menu shows the decorative hero" % locale)
	_check(menu.find_child("TotalStars", true, false) != null, "[%s] menu shows the total stars line" % locale)
	for node_name in MAIN_BUTTONS:
		var spec: Dictionary = MAIN_BUTTONS[node_name]
		var btn := menu.find_child(node_name, true, false) as Button
		if btn == null:
			_fail("[%s] menu has no %s" % [locale, node_name])
			continue
		_check(not btn.disabled and btn.is_visible_in_tree(), "[%s] %s is enabled and visible" % [locale, node_name])
		_check(btn.mouse_filter == Control.MOUSE_FILTER_STOP, "[%s] %s receives clicks" % [locale, node_name])
		_check(btn.size.x >= 128.0 and btn.size.y >= 64.0, "[%s] %s is drawn at 2x (got %s)" % [locale, node_name, btn.size])
		_check(btn.tooltip_text == Localizer.t(str(spec["key"]) + "_tip"), "[%s] %s keeps its tooltip" % [locale, node_name])
		var face := btn.get_node_or_null("Face") as TextureRect
		_check(face != null and face.texture != null, "[%s] %s has a texture face" % [locale, node_name])
		var label := btn.find_child("FaceText", true, false) as Label
		var face_path := face.texture.resource_path if face != null and face.texture != null else ""
		# Both locales use the delivered Portuguese PNGs (the user wants to see them); the
		# localized wording stays available as tooltip/accessibility text.
		_check(face_path.ends_with(str(spec["pt_texture"])),
			"[%s] %s uses %s (got '%s')" % [locale, node_name, spec["pt_texture"], face_path])
		_check(label == null, "[%s] %s draws no extra text over the baked artwork" % [locale, node_name])
		_check(face != null and face.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"[%s] %s keeps the pixel art crisp (nearest)" % [locale, node_name])
		_check(str(btn.get_meta("label", "")) == Localizer.t(str(spec["key"])),
			"[%s] %s keeps its localized accessible label" % [locale, node_name])
	_check(logo != null and logo.size.y >= 40.0, "[%s] menu logo is legible" % locale)
	# Portrait: the logo must sit ABOVE the plaque art, never over it.
	var board := menu.get("_board") as Control
	var board_layer := menu.get("_board_layer") as Control
	if logo != null and not bool(menu.call("_landscape")):
		_check(board != null and board_layer != null, "[%s] portrait menu has the sign" % locale)
		if board != null and board_layer != null:
			var art_top := board.position.y + board_layer.position.y + (72.0 / 1499.0) * board.size.y
			_check(logo.global_position.y + logo.size.y <= art_top + 0.5,
				"[%s] logo sits above the plaque (logo bottom %.1f, plaque top %.1f)" % [
					locale, logo.global_position.y + logo.size.y, art_top])
	# The three buttons stack inside the panel, in order, without overlapping.
	var play := menu.find_child("PlayButton", true, false) as Control
	var opts := menu.find_child("OptionsButton", true, false) as Control
	var quit := menu.find_child("QuitButton", true, false) as Control
	if play != null and opts != null and quit != null:
		var stacked: bool = play.global_position.y + play.size.y <= opts.global_position.y + 0.5 \
				and opts.global_position.y + opts.size.y <= quit.global_position.y + 0.5
		_check(stacked, "[%s] main buttons stack without overlapping" % locale)

func _sound_icon_is(menu: Node, file_name: String) -> bool:
	var icon := menu.find_child("SoundButton", true, false) as TextureButton
	return icon != null and icon.texture_normal != null and icon.texture_normal.resource_path.ends_with(file_name)

func _press_texture(menu: Node, node_name: String) -> void:
	var btn := menu.find_child(node_name, true, false) as TextureButton
	if btn == null:
		_fail("no texture button named %s" % node_name)
		return
	btn.pressed.emit()

# Press and release on the slider at a fraction of its width, as a real click would.
func _click_slider(slider: Control, fraction: float) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = Vector2(slider.size.x * fraction, slider.size.y * 0.5)
		slider.gui_input.emit(e)

func _press(menu: Node, node_name: String) -> void:
	var btn := menu.find_child(node_name, true, false) as Button
	if btn == null:
		_fail("no button named %s" % node_name)
		return
	_check(not btn.disabled, "%s is enabled" % node_name)
	btn.pressed.emit()

func _wait_scene(scene_name: String):
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene != null and scene.name == scene_name and scene.find_child("PlayButton", true, false) != null:
			await _frames(3)
			return scene
	_fail("scene %s did not become ready" % scene_name)
	return null

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _texts(node: Node) -> Array:
	var out: Array = []
	for n in _all_nodes(node):
		if n is Label:
			out.append((n as Label).text)
		elif n is Button:
			out.append((n as Button).text)
	return out

func _find_label(node: Node, text: String) -> Label:
	for n in _all_nodes(node):
		if n is Label and (n as Label).text == text:
			return n as Label
	return null

func _all_nodes(node: Node) -> Array:
	var out: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for child in n.get_children():
			stack.append(child)
	return out

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _snapshot_save() -> Dictionary:
	var path := SaveManager.DEFAULT_PATH
	var exists := FileAccess.file_exists(path)
	var bytes := PackedByteArray()
	if exists:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"exists": true, "bytes": bytes, "read_error": FileAccess.get_open_error()}
		bytes = file.get_buffer(file.get_length())
	return {"exists": exists, "bytes": bytes}

func _remove_throwaway_save() -> void:
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	_remove_throwaway_save()
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	var save_after := _snapshot_save()
	if _save_before.has("read_error") or save_after.has("read_error"):
		_fail("could not verify save preservation")
	elif _save_before["exists"] != save_after["exists"] or _save_before["bytes"] != save_after["bytes"]:
		_fail("the real save changed during the test")
	if _failures.is_empty():
		print("SMOKE OK")
		quit(0)
	else:
		for message in _failures:
			printerr("SMOKE FAIL: %s" % message)
		quit(1)
