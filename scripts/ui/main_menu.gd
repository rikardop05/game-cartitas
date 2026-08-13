extends Control

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

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

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
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	var ids: Array = LevelLoader.load_all_level_ids()
	for id in ids:
		vbox.add_child(_make_level_button(str(id)))

	var reset := Button.new()
	reset.text = Localizer.t("reset")
	reset.custom_minimum_size = Vector2(220, 40)
	reset.pressed.connect(_on_reset)
	vbox.add_child(reset)

	var lang_btn := Button.new()
	lang_btn.text = Localizer.t("language")
	lang_btn.custom_minimum_size = Vector2(220, 40)
	lang_btn.pressed.connect(_on_toggle_language)
	vbox.add_child(lang_btn)

	var orient_btn := Button.new()
	orient_btn.text = _orientation_label()
	orient_btn.custom_minimum_size = Vector2(220, 40)
	orient_btn.pressed.connect(_on_toggle_orientation)
	vbox.add_child(orient_btn)

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
		btn.pressed.connect(_on_level.bind(id))
	else:
		btn.text = "Level %s   (%s)" % [id, Localizer.t("locked")]
		btn.disabled = true
	return btn

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
