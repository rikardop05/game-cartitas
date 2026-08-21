extends Control

enum Screen { MENU, LEVELS, OPTIONS }

var _screen: Screen = Screen.MENU

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var bg := ColorRect.new()
	bg.color = Color("#17181d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	match _screen:
		Screen.LEVELS:
			_build_levels()
		Screen.OPTIONS:
			_build_options()
		_:
			_build_menu()

func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = Localizer.t("title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = Localizer.t("subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	vbox.add_child(_make_menu_button(Localizer.t("play"), Localizer.t("play_tip"), _on_play))
	vbox.add_child(_make_menu_button(Localizer.t("options"), Localizer.t("options_tip"), _on_options))
	vbox.add_child(_make_menu_button(Localizer.t("quit"), Localizer.t("quit_tip"), _on_quit))

	var total_stars := Label.new()
	total_stars.text = "★ %d/%d" % [Game.progress.total_stars(), LevelLoader.load_all_level_ids().size() * 3]
	total_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_stars.add_theme_font_size_override("font_size", 16)
	total_stars.add_theme_color_override("font_color", Color("#ffe36e"))
	total_stars.add_theme_font_override("font", UiHelpers.symbol_font())
	vbox.add_child(total_stars)

func _make_menu_button(text: String, tooltip: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 48)
	btn.tooltip_text = tooltip
	btn.pressed.connect(callback)
	return btn

func _build_levels() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)
	header.add_child(_make_back_button())

	var heading := Label.new()
	heading.text = Localizer.t("select_level")
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	header.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var ids: Array = LevelLoader.load_all_level_ids()
	var total_stars := Label.new()
	total_stars.text = "★ %d/%d" % [Game.progress.total_stars(), ids.size() * 3]
	total_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_stars.add_theme_font_size_override("font_size", 20)
	total_stars.add_theme_color_override("font_color", Color("#ffe36e"))
	total_stars.add_theme_font_override("font", UiHelpers.symbol_font())
	vbox.add_child(total_stars)

	for id in ids:
		vbox.add_child(_make_level_button(str(id)))

func _build_options() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)
	header.add_child(_make_back_button())

	var heading := Label.new()
	heading.text = Localizer.t("options")
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	header.add_child(heading)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var lang_btn := Button.new()
	lang_btn.text = Localizer.t("language")
	lang_btn.custom_minimum_size = Vector2(220, 44)
	lang_btn.tooltip_text = Localizer.t("language")
	lang_btn.pressed.connect(_on_toggle_language)
	vbox.add_child(lang_btn)

	var orient_btn := Button.new()
	orient_btn.text = _orientation_label()
	orient_btn.custom_minimum_size = Vector2(220, 44)
	orient_btn.tooltip_text = Localizer.t("orientation_label")
	orient_btn.pressed.connect(_on_toggle_orientation)
	vbox.add_child(orient_btn)

	var reset := Button.new()
	reset.text = Localizer.t("reset")
	reset.custom_minimum_size = Vector2(220, 44)
	reset.tooltip_text = Localizer.t("reset")
	reset.pressed.connect(_on_reset)
	vbox.add_child(reset)

func _make_back_button() -> Button:
	var back := Button.new()
	back.text = "<"
	back.flat = true
	back.custom_minimum_size = Vector2(28, 28)
	back.add_theme_font_size_override("font_size", 18)
	back.tooltip_text = Localizer.t("back")
	back.pressed.connect(_on_back)
	return back

func _make_level_button(id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 48)
	btn.add_theme_font_override("font", UiHelpers.symbol_font())
	if Game.progress.is_level_unlocked(id):
		var stars: int = Game.progress.get_stars(id)
		var star_str := ""
		for i in 3:
			star_str += "★" if i < stars else "☆"
		btn.text = "Level %s   %s" % [id, star_str]
		btn.tooltip_text = "%s %s" % [Localizer.t("level"), id]
		btn.pressed.connect(_on_level.bind(id))
	else:
		btn.text = "Level %s   (%s)" % [id, Localizer.t("locked")]
		btn.disabled = true
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
	_build()

func _on_level(level_id: String) -> void:
	Game.start_level(level_id)

func _on_reset() -> void:
	Game.progress = ProgressManager.new()
	Game.save_progress()
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