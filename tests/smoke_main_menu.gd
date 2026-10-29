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
	"PlayButton": {"key": "play", "pt_texture": "btn_play_pt.png"},
	"OptionsButton": {"key": "options", "pt_texture": "btn_options_pt.png"},
	"QuitButton": {"key": "quit", "pt_texture": "btn_quit_pt.png"},
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

	# Options: sound toggle.
	_press(menu, "OptionsButton")
	await _frames(3)
	_check(_find_label(menu, Localizer.t("options")) != null, "options screen shows its heading")
	for node_name in ["LanguageButton", "OrientationButton", "MascotButton", "SoundButton", "ResetButton"]:
		_check(menu.find_child(node_name, true, false) != null, "options has %s" % node_name)
	var sound_btn := menu.find_child("SoundButton", true, false) as Button
	if sound_btn == null:
		return
	_check(game.sound_enabled(), "sound starts enabled")
	_check(sound_btn.text == "%s: %s" % [Localizer.t("sound_label"), Localizer.t("option_on")], "sound row reads On (got '%s')" % sound_btn.text)
	_check(_sound_icon_is(menu, "icon_sound_on.png"), "sound row shows the 'on' icon")
	sound_btn.pressed.emit()
	await _frames(3)
	_check(not game.sound_enabled(), "toggling sound turns it off")
	_check(not bool(SaveManager.load(THROWAWAY_SAVE).get("settings", {}).get("sound", true)), "sound off is saved to the throwaway file")
	sound_btn = menu.find_child("SoundButton", true, false) as Button
	_check(sound_btn.text == "%s: %s" % [Localizer.t("sound_label"), Localizer.t("option_off")], "sound row reads Off (got '%s')" % sound_btn.text)
	_check(_sound_icon_is(menu, "icon_sound_off.png"), "sound row shows the 'off' icon")
	sound_btn.pressed.emit()
	await _frames(3)
	_check(game.sound_enabled(), "toggling sound again turns it back on")

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
	var texts := _texts(menu)
	_check(texts.has(Localizer.t("title")), "[%s] menu shows the title" % locale)
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
		if locale == "pt":
			_check(face_path.ends_with(str(spec["pt_texture"])), "[pt] %s uses %s (got '%s')" % [node_name, spec["pt_texture"], face_path])
			_check(label == null, "[pt] %s draws no extra text over the baked artwork" % node_name)
		else:
			_check(face_path.ends_with("pill.png"), "[en] %s uses the blank pill (got '%s')" % [node_name, face_path])
			_check(label != null and label.text == Localizer.t(str(spec["key"])), "[en] %s shows localized text" % node_name)
	if locale == "en":
		# The English menu must not show any of the Portuguese words.
		for key in ["play", "options", "quit"]:
			var pt_word: String = Localizer.STRINGS[key]["pt"]
			if pt_word != Localizer.STRINGS[key]["en"]:
				_check(not texts.has(pt_word), "[en] menu does not show Portuguese '%s'" % pt_word)
	# The three buttons stack inside the panel, in order, without overlapping.
	var play := menu.find_child("PlayButton", true, false) as Control
	var opts := menu.find_child("OptionsButton", true, false) as Control
	var quit := menu.find_child("QuitButton", true, false) as Control
	if play != null and opts != null and quit != null:
		var stacked: bool = play.global_position.y + play.size.y <= opts.global_position.y + 0.5 \
				and opts.global_position.y + opts.size.y <= quit.global_position.y + 0.5
		_check(stacked, "[%s] main buttons stack without overlapping" % locale)

func _sound_icon_is(menu: Node, file_name: String) -> bool:
	var icon := menu.find_child("SoundIcon", true, false) as TextureRect
	return icon != null and icon.texture != null and icon.texture.resource_path.ends_with(file_name)

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
