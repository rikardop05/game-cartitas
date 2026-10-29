extends Control

enum Screen { MENU, LEVELS, OPTIONS }

# Same warm palette as the level screen, so menu and game read as one product.
const WARM_BACKGROUND := UiHelpers.WARM_BACKGROUND
const TEXT_MUTED := UiHelpers.TEXT_MUTED
const GOLD := UiHelpers.GOLD

# The kit panel and its buttons are drawn at exactly 2x their 80x96 / 64x32 source size.
const MENU_PANEL_SIZE := Vector2(160, 192)
const MENU_BUTTON_SIZE := Vector2(128, 64)

const VOLUME_STEP := 0.25
const SLIDER_TRACK_PX := 64

var _screen: Screen = Screen.MENU
var _reset_armed := false

func _ready() -> void:
	theme = UiHelpers.warm_theme()
	_build()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_child(UiHelpers.make_background(_landscape()))
	match _screen:
		Screen.LEVELS:
			_build_levels()
		Screen.OPTIONS:
			_build_options()
		_:
			_build_menu()

func _landscape() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.x >= viewport_size.y

func _build_menu() -> void:
	var landscape := _landscape()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2 if landscape else 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = Localizer.t("title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30 if landscape else 34)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = Localizer.t("subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14 if landscape else 16)
	subtitle.add_theme_color_override("font_color", TEXT_MUTED)
	vbox.add_child(subtitle)

	# The kit panel is drawn at 2x (160x192) with the three 128x64 buttons stacked inside.
	var panel := Control.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size = MENU_PANEL_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(panel)
	var backdrop := TextureRect.new()
	backdrop.texture = UiHelpers.kit_texture("panel_menu")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backdrop)

	var buttons := VBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 0)
	panel.add_child(buttons)
	buttons.add_child(_make_menu_button("PlayButton", "play", "btn_play_pt", _on_play))
	buttons.add_child(_make_menu_button("OptionsButton", "options", "btn_options_pt", _on_options))
	buttons.add_child(_make_menu_button("QuitButton", "quit", "btn_quit_pt", _on_quit))

	var total_stars := UiHelpers.symbol_label(UiHelpers.total_stars_text(), 16)
	total_stars.name = "TotalStars"
	total_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_stars.add_theme_color_override("font_color", GOLD)
	vbox.add_child(total_stars)

# A kit button drawn at 2x. Portuguese uses the baked-in artwork; any other locale uses the
# blank plate with the localized text drawn on it, so English never shows Portuguese words.
func _make_menu_button(node_name: String, key: String, pt_texture: String, callback: Callable) -> Button:
	var pt := Localizer.current == "pt"
	var btn := _make_face_button(UiHelpers.kit_texture(pt_texture if pt else "pill"), MENU_BUTTON_SIZE)
	btn.name = node_name
	btn.tooltip_text = Localizer.t(key + "_tip")
	btn.pressed.connect(callback)
	if not pt:
		var label := Label.new()
		label.name = "FaceText"
		label.text = Localizer.t(key)
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 22)
		btn.get_node("Face").add_child(label)
	return btn

# Invisible Button hosting a texture "Face" child: hover brightens it, press dips it 2px.
func _make_face_button(texture: Texture2D, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = min_size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var face := TextureRect.new()
	face.name = "Face"
	face.texture = texture
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(face)
	btn.mouse_entered.connect(func(): face.modulate = Color(1.12, 1.12, 1.12))
	btn.mouse_exited.connect(func():
		face.modulate = Color.WHITE
		face.position.y = 0)
	btn.button_down.connect(func():
		face.position.y = 2
		face.modulate = Color(0.85, 0.85, 0.85))
	btn.button_up.connect(func():
		face.position.y = 0
		face.modulate = Color(1.12, 1.12, 1.12) if btn.is_hovered() else Color.WHITE)
	return btn

# Kit-plate style for list/option rows (9-sliced, so any width works) with hover/press tints.
func _apply_plate_style(btn: Button, tint := Color.WHITE) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := UiHelpers.kit_stylebox("panel_reserve", 6, 8)
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		var shade := tint
		match state:
			"hover":
				shade = tint.lightened(0.15)
			"pressed":
				shade = tint.darkened(0.2)
			"disabled":
				shade = Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7, 0.8)
		style.modulate_color = shade
		btn.add_theme_stylebox_override(state, style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

# The brown kit window the list and the options sit on.
func _make_window() -> PanelContainer:
	var window := PanelContainer.new()
	window.name = "Window"
	var style := UiHelpers.kit_stylebox("panel_board" if _landscape() else "panel_board_portrait", 6, 12)
	# The kit window has a thicker lower lip (shadow and feet).
	style.texture_margin_bottom = 10
	style.content_margin_bottom = 14
	window.add_theme_stylebox_override("panel", style)
	return window

func _make_margin(parent: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	parent.add_child(margin)
	return margin

func _make_header(text: String) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.add_child(_make_back_button())
	var heading := Label.new()
	heading.text = text
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	header.add_child(heading)
	return header

func _build_levels() -> void:
	var margin := _make_margin(self)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	col.add_child(_make_header(Localizer.t("select_level")))

	var window := _make_window()
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(window)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var ids: Array = LevelLoader.load_all_level_ids()
	var total_stars := UiHelpers.symbol_label(UiHelpers.total_stars_text(), 18)
	total_stars.name = "TotalStars"
	total_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_stars.add_theme_color_override("font_color", GOLD)
	vbox.add_child(total_stars)

	vbox.add_child(_make_endless_button())
	for id in ids:
		vbox.add_child(_make_level_button(str(id)))

func _build_options() -> void:
	var landscape := _landscape()
	var margin := _make_margin(self)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	col.add_child(_make_header(Localizer.t("options")))

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)

	var window := _make_window()
	window.custom_minimum_size = Vector2(320, 0)
	center.add_child(window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6 if landscape else 10)
	window.add_child(vbox)

	var row_height := 42 if landscape else 46
	vbox.add_child(_make_option_row("LanguageButton", Localizer.t("language"), Localizer.t("language"), _on_toggle_language, row_height))
	vbox.add_child(_make_option_row("OrientationButton", _orientation_label(), Localizer.t("orientation_label"), _on_toggle_orientation, row_height))
	vbox.add_child(_make_option_row("MascotButton", _mascot_label(), Localizer.t("mascot_label"), _on_toggle_mascot, row_height))
	vbox.add_child(_make_volume_row(row_height))

	if _reset_armed:
		vbox.add_child(_make_reset_confirm(row_height))
	else:
		vbox.add_child(_make_option_row("ResetButton", Localizer.t("reset"), Localizer.t("reset"), _on_reset, row_height))

# Volume row from the kit: minus, a slider bar with a draggable handle, plus, and the sound
# glyph (muted at zero) on a light plate, since the glyph is dark. Tapping the glyph mutes or
# brings back the last volume. Pieces are drawn at 2x like the rest of the menu art.
func _make_volume_row(height: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "VolumeRow"
	row.custom_minimum_size = Vector2(280, height)
	row.tooltip_text = Localizer.t("sound_label")
	var style := UiHelpers.kit_stylebox("panel_reserve", 6, 8)
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	row.add_theme_stylebox_override("panel", style)
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)
	box.add_child(_make_kit_icon_button("VolumeDown", "icon_minus", func(): _step_volume(-VOLUME_STEP)))
	box.add_child(_make_volume_slider())
	box.add_child(_make_kit_icon_button("VolumeUp", "icon_plus", func(): _step_volume(VOLUME_STEP)))
	var plate := PanelContainer.new()
	plate.name = "SoundPlate"
	plate.add_theme_stylebox_override("panel", UiHelpers.kit_stylebox("panel_menu", 3, 1))
	box.add_child(plate)
	var mute := _make_kit_icon_button("SoundButton", "icon_sound_on" if Game.sound_enabled() else "icon_sound_off", _on_toggle_sound)
	mute.tooltip_text = Localizer.t("sound_label")
	plate.add_child(mute)
	return row

func _make_kit_icon_button(node_name: String, kit_name: String, callback: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.name = node_name
	btn.texture_normal = UiHelpers.kit_texture(kit_name)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = Vector2(32, 32)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(callback)
	btn.button_down.connect(func(): btn.modulate = Color(0.8, 0.8, 0.8))
	btn.button_up.connect(func(): btn.modulate = Color.WHITE)
	return btn

# The kit's 48 px bar is stretched to SLIDER_TRACK_PX keeping its rounded ends (9-slice),
# then drawn at 2x; the handle slides from the left end (muted) to the right end (full).
func _make_volume_slider() -> Control:
	var slider := Control.new()
	slider.name = "VolumeSlider"
	slider.custom_minimum_size = Vector2(SLIDER_TRACK_PX * 2, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.tooltip_text = Localizer.t("sound_label")
	var bar := UiHelpers.kit_panel("slider_bar", 4)
	bar.name = "Track"
	bar.size = Vector2(SLIDER_TRACK_PX, 16)
	bar.scale = Vector2(2, 2)
	slider.add_child(bar)
	var handle := TextureRect.new()
	handle.name = "Handle"
	handle.texture = UiHelpers.kit_texture("slider_handle")
	handle.size = Vector2(16, 16)
	handle.scale = Vector2(2, 2)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.position = Vector2(_handle_x(Game.volume()), 0)
	slider.add_child(handle)
	slider.gui_input.connect(_on_volume_slider_input.bind(slider))
	return slider

# Left edge of the handle (in slider px) for a volume: the handle stays inside the bar.
func _handle_x(value: float) -> float:
	return value * float(SLIDER_TRACK_PX * 2 - 32)

func _on_volume_slider_input(event: InputEvent, slider: Control) -> void:
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	var press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	if not drag and not press:
		return
	var value := clampf((event.position.x - 16.0) / float(SLIDER_TRACK_PX * 2 - 32), 0.0, 1.0)
	# Save only when the finger lifts; while dragging just move the handle and the glyph.
	var released: bool = press and not event.pressed
	Game.set_volume(value, released)
	_sync_volume_row(slider.get_parent())

func _step_volume(delta: float) -> void:
	Game.set_volume(snappedf(Game.volume() + delta, VOLUME_STEP))
	_sync_volume_row(find_child("VolumeRow", true, false))

func _sync_volume_row(row: Node) -> void:
	if row == null:
		return
	var handle := row.find_child("Handle", true, false) as Control
	if handle != null:
		handle.position.x = _handle_x(Game.volume())
	var mute := row.find_child("SoundButton", true, false) as TextureButton
	if mute != null:
		mute.texture_normal = UiHelpers.kit_texture("icon_sound_on" if Game.sound_enabled() else "icon_sound_off")

func _make_option_row(node_name: String, text: String, tooltip: String, callback: Callable, height: int) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = text
	btn.custom_minimum_size = Vector2(280, height)
	btn.tooltip_text = tooltip
	btn.pressed.connect(callback)
	_apply_plate_style(btn)
	return btn

# Second step of "Reset progress": the warning, a green check to erase and a red cross to keep.
func _make_reset_confirm(height: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ResetConfirmRow"
	row.add_theme_constant_override("separation", 6)
	var warning := Label.new()
	warning.name = "ResetWarning"
	warning.text = Localizer.t("reset_confirm")
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(170, 0)
	warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 13)
	row.add_child(warning)
	row.add_child(_make_icon_button("ResetConfirm", "icon_accept", Localizer.t("confirm"), _on_reset, height))
	row.add_child(_make_icon_button("ResetCancel", "icon_close_red", Localizer.t("cancel"), _on_reset_cancel, height))
	return row

func _make_icon_button(node_name: String, icon_name: String, tooltip: String, callback: Callable, size: int) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.icon = UiHelpers.kit_texture(icon_name)
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 24)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size = Vector2(size + 8, size)
	btn.tooltip_text = tooltip
	btn.pressed.connect(callback)
	_apply_plate_style(btn)
	return btn

# Flat button with a green chevron (dark outline), matching the level screen's back button.
func _make_back_button() -> Button:
	var btn := Button.new()
	btn.name = "BackButton"
	btn.custom_minimum_size = Vector2(36, 36)
	btn.tooltip_text = Localizer.t("back")
	btn.pressed.connect(_on_back)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	btn.draw.connect(func():
		var c := btn.size * 0.5 + (Vector2(0, 1) if btn.is_pressed() else Vector2.ZERO)
		var pts := PackedVector2Array([c + Vector2(5, -10), c + Vector2(-5, 0), c + Vector2(5, 10)])
		var outline := Color("#2a1a0e")
		var green := Color("#8be04e") if btn.is_hovered() else Color("#6fcf3a")
		btn.draw_polyline(pts, outline, 8.0)
		for p in pts:
			btn.draw_circle(p, 4.0, outline)
		btn.draw_polyline(pts, green, 4.0)
		for p in pts:
			btn.draw_circle(p, 2.0, green))
	btn.mouse_entered.connect(btn.queue_redraw)
	btn.mouse_exited.connect(btn.queue_redraw)
	btn.button_down.connect(btn.queue_redraw)
	btn.button_up.connect(btn.queue_redraw)
	return btn

func _make_level_button(id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(240, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_override("font", UiHelpers.symbol_font())
	if Game.progress.is_level_unlocked(id):
		var stars: int = Game.progress.get_stars(id)
		var star_str := ""
		for i in 3:
			star_str += "★" if i < stars else "☆"
		btn.text = "%s %s   %s" % [Localizer.t("level"), id, star_str]
		btn.tooltip_text = "%s %s" % [Localizer.t("level"), id]
		btn.pressed.connect(_on_level.bind(id))
	else:
		btn.text = "%s %s   (%s)" % [Localizer.t("level"), id, Localizer.t("locked")]
		btn.disabled = true
	_apply_plate_style(btn)
	return btn

# Endless entry, styled like a level button: best score once the last Level is beaten.
func _make_endless_button() -> Button:
	var btn := Button.new()
	btn.name = "EndlessButton"
	btn.custom_minimum_size = Vector2(240, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_override("font", UiHelpers.symbol_font())
	var tint := Color.WHITE
	if Game.progress.is_endless_unlocked():
		btn.text = Localizer.t("endless")
		if Game.progress.endless_best > 0:
			btn.text += "   ★ %s" % (Localizer.t("endless_best") % Game.progress.endless_best)
		btn.add_theme_color_override("font_color", GOLD)
		btn.tooltip_text = Localizer.t("endless_tip")
		btn.pressed.connect(_on_endless)
		tint = Color(1.12, 1.0, 0.72)
	else:
		btn.text = "%s   %s" % [Localizer.t("endless"), Localizer.t("endless_locked") % ProgressManager.endless_unlock_level()]
		btn.disabled = true
	_apply_plate_style(btn, tint)
	return btn

func _on_play() -> void:
	_screen = Screen.LEVELS
	_build()

func _on_options() -> void:
	_screen = Screen.OPTIONS
	_build()

func _on_quit() -> void:
	get_tree().quit()

func _on_back() -> void:
	_screen = Screen.MENU
	_reset_armed = false
	_build()

func _on_level(level_id: String) -> void:
	Game.start_level(level_id)

func _on_endless() -> void:
	Game.start_endless()

# Erasing progress is irreversible, so the first tap only arms it and the check mark confirms.
func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_build()
		return
	_reset_armed = false
	Game.progress = ProgressManager.new()
	Game.save_progress()
	_build()

func _on_reset_cancel() -> void:
	_reset_armed = false
	_build()

func _on_toggle_language() -> void:
	var next := "en" if Localizer.current == "pt" else "pt"
	Game.set_locale(next)
	_build()

func _orientation_label() -> String:
	var cur := "landscape" if str(Game.settings.get("orientation", "portrait")) == "landscape" else "portrait"
	return "%s: %s" % [Localizer.t("orientation_label"), Localizer.t(cur)]

func _on_toggle_orientation() -> void:
	var landscape := str(Game.settings.get("orientation", "portrait")) != "landscape"
	Game.set_orientation(landscape)
	_build()

func _mascot_label() -> String:
	return "%s: %s" % [Localizer.t("mascot_label"), Localizer.t("option_on" if Game.mascot_enabled() else "option_off")]

func _on_toggle_mascot() -> void:
	Game.set_mascot(not Game.mascot_enabled())
	_build()

func _on_toggle_sound() -> void:
	Game.set_sound(not Game.sound_enabled())
	_sync_volume_row(find_child("VolumeRow", true, false))
