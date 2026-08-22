extends Control

const CARD_DISPLAY_SIZE := Card.DISPLAY_SIZE
const DECK_CARD_SIZE := CARD_DISPLAY_SIZE * LevelConfig.RESERVE_CARD_SCALE
const RESERVE_COLUMNS := 2
const RESERVE_PANEL_SIZE := Vector2(100, 64)
const WARM_BACKGROUND := Color("#c78454")
const PANEL_BACKGROUND := Color(0.16, 0.10, 0.08, 0.78)
const PANEL_BORDER := Color("#f3d28d")
const TEXT_PRIMARY := Color("#fff1d2")
const TEXT_MUTED := Color("#f0c98e")
const BOARD_CARD_SCALE := 1.0
const BOARD_X_COMPRESSION := 1.0
const BOARD_Y_COMPRESSION := 1.0
const PORTRAIT_BOARD_FRAME := Vector2(344.0, 272.0)
const LANDSCAPE_BOARD_FRAME := Vector2(558.0, 248.0)
const LANDSCAPE_ZONE_CARD_SIZE := Vector2(31.0, 31.0)
const LANDSCAPE_RESERVE_CARD_SIZE := Vector2(30.0, 30.0)

var controller: GameController
var board_container: Control
var zone_container: HFlowContainer
var reserve_header: Label
var reserve_container: Control
var deck_a_btn: Button
var deck_b_btn: Button
var power_buttons: Dictionary = {}
var timer_label: Label
var stars_label: Label
var level_label: Label
var zone_header: Label
var instruction_label: Label
var _board_panel: PanelContainer
var _is_landscape := true
var _animating_card := false
var _ended := false
var _help_shown := false
var _live_star_count := -1
var _level_id: String = ""
var _sfx_player: AudioStreamPlayer
var _card_size: float = 48.0
var _fits_landscape := true
var _scale_limited := false
var _layout_warning: Label

func _ready() -> void:
	_level_id = Game.current_level_id
	_build_ui()
	resized.connect(_on_resized)
	await get_tree().process_frame
	var attempts := 0
	while board_container != null and board_container.size.x <= 0.0 and attempts < 10:
		await get_tree().process_frame
		attempts += 1
	_apply_board_panel_height()
	var board_size := Vector2(280.0, 360.0)
	if board_container != null and board_container.size.x > 0.0:
		board_size = board_container.size
	var level: Dictionary = LevelLoader.load_level(_level_id, board_size)
	if level.has("error"):
		_show_error(str(level["error"]))
		return
	var validation := LevelValidator.validate(level)
	if not validation["valid"]:
		_show_error("%s\n%s" % [Localizer.t("invalid_level"), "\n".join(validation["errors"])])
		return
	_card_size = float(level.get("card_size", Card.DISPLAY_SIZE.x))
	_fits_landscape = bool(level.get("generation_metrics", {}).get("fits_landscape", true))
	controller = GameController.new()
	controller.start_level(level, Game.progress.inventory)
	render()
	_play_intro()

func _process(_delta: float) -> void:
	if controller == null:
		return
	if controller.status == GameController.Status.PLAYING:
		controller.check_timeout()
		timer_label.text = _timer_text()
		_timer_warning(controller.time_remaining())
	_update_live_stars()
	if controller.status != GameController.Status.PLAYING and not _ended:
		_check_end()

func _timer_text() -> String:
	if controller.time_limit > 0.0:
		return _format_time(maxf(0.0, controller.time_remaining()))
	return _format_time(controller.timer.elapsed_seconds())

func _timer_warning(remaining: float) -> void:
	if controller.time_limit > 0.0 and remaining <= 10.0:
		timer_label.add_theme_color_override("font_color", Color("#ff6b5e"))
	else:
		timer_label.add_theme_color_override("font_color", TEXT_PRIMARY)

func _on_resized() -> void:
	if controller != null and not _ended:
		var landscape := _viewport_is_landscape()
		if landscape != _is_landscape:
			_build_ui()
			await get_tree().process_frame
			_apply_board_panel_height()
			await get_tree().process_frame
			render()
		else:
			_apply_board_panel_height()
			await get_tree().process_frame
			render()

func _build_ui() -> void:
	_is_landscape = _viewport_is_landscape()
	_help_shown = false
	power_buttons.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = WARM_BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "ScreenMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4 if _is_landscape else 6)
	margin.add_child(vbox)

	vbox.add_child(_build_hud())
	if _is_landscape:
		var body := HBoxContainer.new()
		body.name = "Body"
		body.custom_minimum_size = Vector2(624, 308)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 6)
		vbox.add_child(body)
		body.add_child(_build_main_column())
		var controls := _build_controls(false)
		controls.custom_minimum_size = Vector2(60, 0)
		body.add_child(controls)
	else:
		vbox.add_child(_build_main_column())

func _build_hud() -> PanelContainer:
	var panel := _make_unframed_panel(2 if _is_landscape else 4)
	panel.name = "Hud"
	panel.custom_minimum_size = Vector2(0, 32 if _is_landscape else 40)
	var hud := VBoxContainer.new()
	hud.add_theme_constant_override("separation", 2)
	panel.add_child(hud)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	hud.add_child(top)

	var back := Button.new()
	back.text = "<"
	back.flat = true
	back.custom_minimum_size = Vector2(24, 24)
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_color_override("font_color", TEXT_PRIMARY)
	if _is_landscape:
		_make_flat_button_compact(back)
	back.pressed.connect(Game.go_to_menu)
	top.add_child(back)

	level_label = Label.new()
	level_label.text = "%s %s" % [Localizer.t("level"), _level_id]
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(level_label)

	_add_expander(top)

	var clock_pill := _make_hud_pill()
	timer_label = Label.new()
	timer_label.text = "00:00"
	timer_label.add_theme_font_size_override("font_size", 14)
	timer_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.custom_minimum_size = Vector2(52, 22)
	clock_pill.add_child(timer_label)
	top.add_child(clock_pill)

	_add_expander(top)

	var stars_pill := _make_hud_pill()
	stars_label = UiHelpers.symbol_label("☆☆☆", 16)
	stars_label.add_theme_color_override("font_color", Color("#ffe36e"))
	stars_label.custom_minimum_size = Vector2(52, 22)
	stars_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_pill.add_child(stars_label)
	top.add_child(stars_pill)

	_add_expander(top)

	var help := Button.new()
	help.text = "?"
	help.flat = true
	help.custom_minimum_size = Vector2(24, 24)
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", TEXT_PRIMARY)
	if _is_landscape:
		_make_flat_button_compact(help)
	help.pressed.connect(_on_help)
	top.add_child(help)
	return panel

func _make_flat_button_compact(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)

func _make_hud_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.32)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 0 if _is_landscape else 3
	style.content_margin_bottom = 0 if _is_landscape else 3
	pill.add_theme_stylebox_override("panel", style)
	return pill

func _build_main_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = "MainColumn"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4 if _is_landscape else 6)

	var board_panel := _make_panel(Color(0.19, 0.12, 0.09, 0.30), Color(1, 0.88, 0.60, 0.45), 12)
	board_panel.name = "BoardFrame"
	_board_panel = board_panel
	board_panel.custom_minimum_size = LANDSCAPE_BOARD_FRAME if _is_landscape else PORTRAIT_BOARD_FRAME
	var board_layer := Control.new()
	board_layer.name = "BoardLayer"
	board_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_panel.add_child(board_layer)
	board_container = Control.new()
	board_container.name = "Board"
	board_container.clip_contents = true
	board_container.z_index = 1
	board_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_layer.add_child(board_container)
	instruction_label = Label.new()
	instruction_label.name = "InstructionOverlay"
	instruction_label.text = Localizer.t("instruction")
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	instruction_label.add_theme_font_size_override("font_size", 10)
	instruction_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	instruction_label.offset_top = -18
	instruction_label.offset_bottom = 0
	instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_label.z_index = 0
	board_layer.add_child(instruction_label)
	col.add_child(board_panel)

	if _is_landscape:
		var lower := HBoxContainer.new()
		lower.name = "LowerStrip"
		lower.custom_minimum_size = Vector2(0, 56)
		lower.add_theme_constant_override("separation", 4)
		lower.add_child(_build_support_panel())
		lower.add_child(_build_reserve_panel())
		lower.add_child(_build_zone_panel())
		col.add_child(lower)
	else:
		col.add_child(_build_controls(true))
		col.add_child(_build_support_panel())
		col.add_child(_build_zone_panel())
		col.add_child(_build_reserve_panel())
	return col

func _build_support_panel() -> PanelContainer:
	var panel := _make_unframed_panel()
	panel.name = "Support"
	panel.custom_minimum_size = Vector2(200 if _is_landscape else 344, 54 if not _is_landscape else 56)
	var deck_row := HBoxContainer.new()
	deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_row.add_theme_constant_override("separation", 12 if _is_landscape else 44)
	panel.add_child(deck_row)
	deck_a_btn = _make_deck_button("a")
	deck_b_btn = _make_deck_button("b")
	deck_row.add_child(_make_deck_slot("A", deck_a_btn))
	deck_row.add_child(_make_deck_slot("B", deck_b_btn))
	return panel

func _build_reserve_panel() -> PanelContainer:
	var reserve_panel := _make_panel(PANEL_BACKGROUND, PANEL_BORDER, 10)
	reserve_panel.name = "Reserve"
	reserve_panel.custom_minimum_size = Vector2(100 if _is_landscape else 344, 56 if _is_landscape else 68)
	var reserve_col := VBoxContainer.new()
	reserve_col.add_theme_constant_override("separation", 2)
	reserve_panel.add_child(reserve_col)
	reserve_header = Label.new()
	reserve_header.add_theme_font_size_override("font_size", 8)
	reserve_header.add_theme_color_override("font_color", TEXT_MUTED)
	reserve_col.add_child(reserve_header)
	reserve_container = Control.new()
	reserve_container.custom_minimum_size = Vector2(0, LANDSCAPE_RESERVE_CARD_SIZE.y if _is_landscape else 40)
	reserve_container.clip_contents = true
	reserve_col.add_child(reserve_container)
	return reserve_panel

func _build_zone_panel() -> PanelContainer:
	var zone_panel := _make_unframed_panel()
	zone_panel.name = "ClearingZone"
	zone_panel.custom_minimum_size = Vector2(0, 56 if _is_landscape else 60)
	zone_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var zone_col := VBoxContainer.new()
	zone_col.add_theme_constant_override("separation", 1)
	zone_panel.add_child(zone_col)
	zone_header = Label.new()
	zone_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_header.add_theme_font_size_override("font_size", 8)
	zone_header.add_theme_color_override("font_color", TEXT_PRIMARY)
	zone_col.add_child(zone_header)
	zone_container = HFlowContainer.new()
	zone_container.alignment = FlowContainer.ALIGNMENT_CENTER
	zone_container.custom_minimum_size = _zone_card_size()
	zone_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_container.add_theme_constant_override("h_separation", 3)
	zone_container.add_theme_constant_override("v_separation", 3)
	zone_col.add_child(zone_container)
	return zone_panel

func _build_controls(horizontal: bool) -> PanelContainer:
	var panel := _make_unframed_panel()
	panel.name = "Powers"
	panel.custom_minimum_size = Vector2(344, 52) if horizontal else Vector2(60, 0)
	var content: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	var title := Label.new()
	title.text = Localizer.t("powers")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	if not _is_landscape or horizontal:
		content.add_child(title)
	var power_box: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	power_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	power_box.alignment = BoxContainer.ALIGNMENT_CENTER
	power_box.add_theme_constant_override("separation", 5)
	content.add_child(power_box)
	for p in PowerManager.POWERS:
		var button := _make_power_button(p)
		if horizontal:
			button.custom_minimum_size = Vector2(0, 44)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		power_box.add_child(button)
	return panel

func _make_power_button(p: String) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 48 if _is_landscape else 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = _power_name(p)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.22)
	style.border_color = Color(1, 0.87, 0.62, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.pressed.connect(_on_power.bind(p))
	power_buttons[p] = btn
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)
	var icon := Label.new()
	icon.text = _power_icon(p)
	icon.add_theme_font_override("font", UiHelpers.symbol_font())
	icon.add_theme_font_size_override("font_size", 15 if _is_landscape else 18)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	if not _is_landscape:
		var name_lbl := Label.new()
		name_lbl.text = _power_name(p)
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_lbl)
	var count_lbl := Label.new()
	count_lbl.text = "x0"
	count_lbl.add_theme_font_size_override("font_size", 9 if _is_landscape else 11)
	count_lbl.add_theme_color_override("font_color", Color("#ffe36e"))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(count_lbl)
	btn.set_meta("count_label", count_lbl)
	return btn

func _make_deck_slot(label_text: String, button: Button) -> BoxContainer:
	var slot: BoxContainer = HBoxContainer.new() if _is_landscape else VBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 4)
	var title := Label.new()
	var full_title := "%s %s" % [Localizer.t("support_deck"), label_text]
	title.text = label_text if _is_landscape else full_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 9 if _is_landscape else 10)
	title.add_theme_color_override("font_color", TEXT_MUTED)
	button.tooltip_text = full_title
	slot.add_child(title)
	slot.add_child(button)
	return slot

func _make_deck_button(deck_id: String) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = DECK_CARD_SIZE
	btn.pressed.connect(_on_deck.bind(deck_id))
	return btn

func _add_expander(parent: Control) -> void:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)

func render() -> void:
	_clear(board_container)
	_clear(zone_container)
	_clear(reserve_container)

	var layout := _board_layout()
	var offset: Vector2 = layout["offset"]
	var scale: float = layout["scale"]
	var origin: Vector2 = layout["origin"]
	var position_scale: Vector2 = layout["position_scale"]
	var grid_positions: Dictionary = layout["grid_positions"]
	var card_size: Vector2 = CARD_DISPLAY_SIZE * scale * BOARD_CARD_SCALE
	_show_layout_warning_if_needed()

	var board_cards: Array = controller.board.cards.duplicate()
	board_cards.sort_custom(func(a, b): return a.layer < b.layer)
	for card in board_cards:
		if card.is_removed() or card.location != Card.Location.BOARD:
			continue
		var darken: bool = card.state != Card.State.AVAILABLE
		var node := _make_card_button(card, darken, _on_card.bind(card.id), card_size)
		var visual_position: Vector2 = grid_positions.get(card.id, Vector2(
			(card.position.x - origin.x) * position_scale.x,
			(card.position.y - origin.y) * position_scale.y
		))
		node.position = _board_node_position(layout, visual_position)
		node.z_index = card.layer
		board_container.add_child(node)

	zone_header.text = "%s  %d/%d" % [Localizer.t("clearing_zone"), controller.zone.size(), controller.clearing_capacity]
	var zone_card_size := _zone_card_size()
	for i in controller.clearing_capacity:
		if i < controller.zone.cards.size():
			zone_container.add_child(_make_card_display(controller.zone.cards[i].type, zone_card_size))
		else:
			zone_container.add_child(_make_empty_slot(zone_card_size))

	reserve_header.text = "%s  %d" % [Localizer.t("reserve"), controller.reserve.size()]
	var reserve_size := _reserve_card_size()
	var reserve_step := _reserve_card_step(reserve_size)
	var reserve_column_width := reserve_container.size.x / float(RESERVE_COLUMNS)
	for i in controller.reserve.size():
		var card: Card = controller.reserve[i]
		var node: Control
		if i == controller.reserve.size() - 1:
			node = _make_card_button(card, false, _on_reserve_return.bind(card.id), reserve_size)
		else:
			node = _make_card_rect(card.type, false, reserve_size)
		var column := i % RESERVE_COLUMNS
		var row := floori(float(i) / float(RESERVE_COLUMNS))
		node.position = Vector2(
			column * reserve_column_width + (reserve_column_width - reserve_size.x) / 2.0,
			row * reserve_step
		)
		node.z_index = i
		reserve_container.add_child(node)

	_update_deck_button(deck_a_btn, controller.deck_a)
	_update_deck_button(deck_b_btn, controller.deck_b)

	for p in PowerManager.POWERS:
		var btn: Button = power_buttons[p]
		var count: int = controller.powers.get_count(p)
		var count_lbl: Label = btn.get_meta("count_label")
		count_lbl.text = "x%d" % count
		btn.disabled = count <= 0

func _clear(c: Node) -> void:
	for child in c.get_children():
		c.remove_child(child)
		child.queue_free()

func _reserve_card_size() -> Vector2:
	var count := controller.reserve.size()
	if count <= 0:
		return LANDSCAPE_RESERVE_CARD_SIZE if _is_landscape else DECK_CARD_SIZE
	var max_card_size := LANDSCAPE_RESERVE_CARD_SIZE.y if _is_landscape else DECK_CARD_SIZE.y
	var available_height := maxf(max_card_size, reserve_container.size.y)
	var tab := 6.0
	var rows := ceili(float(count) / float(RESERVE_COLUMNS))
	var side := minf(max_card_size, maxf(28.0, available_height - tab * maxi(0, rows - 1)))
	var available_width := maxf(28.0, reserve_container.size.x / float(RESERVE_COLUMNS) - 2.0)
	side = minf(side, available_width)
	return Vector2(side, side)

func _zone_card_size() -> Vector2:
	return LANDSCAPE_ZONE_CARD_SIZE if _is_landscape else CARD_DISPLAY_SIZE

func _apply_board_panel_height() -> void:
	if _board_panel == null or board_container == null:
		return
	_board_panel.custom_minimum_size = LANDSCAPE_BOARD_FRAME if _is_landscape else PORTRAIT_BOARD_FRAME

func _reserve_card_step(card_size: Vector2) -> float:
	var count := controller.reserve.size()
	if count <= 1:
		return 0.0
	var available_height := maxf(card_size.y, reserve_container.size.y)
	var rows := ceili(float(count) / float(RESERVE_COLUMNS))
	if rows <= 1:
		return 0.0
	return minf(6.0, maxf(2.0, (available_height - card_size.y) / float(rows - 1)))

func _board_layout() -> Dictionary:
	# Keep the original board frame so removing cards does not collapse the layout.
	var visual_positions: Array = []
	var visual_by_id := {}
	for c in controller.board.cards:
		if c.source != Card.Source.BOARD:
			continue
		var layer_offset := Vector2(float(c.layer % 2) * 4.0, float(c.layer % 3) * 3.0)
		var visual: Vector2 = c.position + layer_offset
		visual_positions.append(visual)
		visual_by_id[c.id] = visual
	if visual_positions.is_empty():
		return {"offset": Vector2.ZERO, "scale": 1.0, "origin": Vector2.ZERO, "position_scale": Vector2.ONE, "grid_positions": {}}
	# Single source of scale: logical positions are mapped to the container by
	# BoardLayout.compute with a uniform scale. Positions are NOT snapped to a
	# fixed pitch — snapping scaled positions collapses distinct slots. The
	# scale never goes below LevelConfig.MIN_CARD_SCALE; if the container is too
	# small the layout is flagged (scale_limited) and surfaced as a warning.
	# The depth-cue layer offset is reserved as a fit margin so edge cards do
	# not clip the container.
	var card := _card_size * BOARD_CARD_SCALE
	var fit := BoardLayout.compute(visual_positions, board_container.size, card, LevelConfig.MIN_CARD_SCALE)
	_scale_limited = bool(fit["scale_limited"])
	var position_scale := Vector2(BOARD_X_COMPRESSION, BOARD_Y_COMPRESSION)
	var grid_positions := {}
	for c in controller.board.cards:
		if c.source != Card.Source.BOARD:
			continue
		var visual: Vector2 = visual_by_id[c.id]
		grid_positions[c.id] = Vector2(
			(visual.x - fit["origin"].x) * position_scale.x,
			(visual.y - fit["origin"].y) * position_scale.y
		)
	return {
		"offset": fit["offset"],
		"scale": fit["scale"],
		"origin": fit["origin"],
		"position_scale": position_scale,
		"grid_positions": grid_positions,
	}

# Single transform, shared by render() and _board_card_rect(): logical ->
# visual node position. No re-snap happens here.
func _board_node_position(layout: Dictionary, visual_position: Vector2) -> Vector2:
	return layout["offset"] + visual_position * layout["scale"]

func _show_layout_warning_if_needed() -> void:
	var warn := _scale_limited or (_is_landscape and not _fits_landscape)
	if not warn:
		if _layout_warning != null:
			_layout_warning.visible = false
		return
	if _layout_warning == null:
		_layout_warning = Label.new()
		_layout_warning.add_theme_font_size_override("font_size", 10)
		_layout_warning.add_theme_color_override("font_color", Color("#3a2410"))
		_layout_warning.add_theme_color_override("font_color_shadow", Color(1, 1, 1, 0.7))
		_layout_warning.add_theme_constant_override("shadow_offset_x", 1)
		_layout_warning.add_theme_constant_override("shadow_offset_y", 1)
		_layout_warning.z_index = 2000
		_layout_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_layout_warning)
	var msg := Localizer.t("landscape_warning") if (_is_landscape and not _fits_landscape) else Localizer.t("layout_warning")
	_layout_warning.text = msg
	_layout_warning.visible = true
	_layout_warning.reset_size()
	_layout_warning.position = Vector2(get_viewport_rect().size.x - _layout_warning.size.x - 8, 6)

func _make_card_rect(type: String, darken: bool, card_size: Vector2) -> Control:
	var root := Panel.new()
	root.custom_minimum_size = card_size
	root.size = card_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = CardTypeRegistry.color(type)
	card_style.border_color = Color("#fff2d5")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(5)
	root.add_theme_stylebox_override("panel", card_style)
	root.add_child(_make_card_art(type, card_size))
	if darken:
		root.modulate = Color(0.62, 0.62, 0.62)
	return root

func _make_card_art(type: String, card_size: Vector2) -> Control:
	var texture := UiHelpers.card_texture(type)
	if texture != null:
		var art := TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.position = Vector2.ZERO
		art.size = card_size
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return art
	return _make_card_placeholder(type, card_size)

func _make_card_placeholder(type: String, card_size: Vector2) -> Label:
	var label := UiHelpers.symbol_label(CardTypeRegistry.symbol(type), int(card_size.y * 0.55))
	label.position = Vector2.ZERO
	label.size = card_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_card_button(card: Card, darken: bool, on_click: Callable, card_size: Vector2) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = card_size
	btn.size = card_size
	btn.disabled = darken
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_child(_make_card_rect(card.type, darken, card_size))
	btn.pressed.connect(on_click)
	return btn

func _make_card_display(type: String, card_size: Vector2) -> Control:
	return _make_card_rect(type, false, card_size)

func _make_empty_slot(card_size: Vector2) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = card_size
	slot.size = card_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.06, 0.28)
	style.border_color = Color(1, 0.87, 0.62, 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("panel", style)
	return slot

func _update_deck_button(btn: Button, deck: DeckManager) -> void:
	_clear(btn)
	btn.size = DECK_CARD_SIZE
	if deck.is_empty():
		btn.disabled = true
		btn.add_child(_make_empty_slot(DECK_CARD_SIZE))
		_fade_out_deck(btn)
		return
	btn.set_meta("faded", false)
	btn.modulate = Color.WHITE
	btn.scale = Vector2.ONE
	btn.visible = true
	btn.disabled = false
	btn.add_child(_make_card_rect(deck.current_type(), false, DECK_CARD_SIZE))
	var badge := ColorRect.new()
	badge.color = Color(0, 0, 0, 0.55)
	badge.position = Vector2(DECK_CARD_SIZE.x - 18, 2)
	badge.size = Vector2(16, 14)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	var cnt := Label.new()
	cnt.text = str(deck.remaining_count())
	cnt.position = badge.position
	cnt.size = badge.size
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cnt.add_theme_font_size_override("font_size", 10)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cnt)

func _fade_out_deck(btn: Button) -> void:
	if bool(btn.get_meta("faded", false)):
		return
	btn.set_meta("faded", true)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(btn, "modulate:a", 0.0, 0.3)
	t.tween_property(btn, "scale", Vector2(0.7, 0.7), 0.3)
	await t.finished
	btn.visible = false

func _make_unframed_panel(vertical_margin: float = 4.0) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	style.content_margin_left = 6
	style.content_margin_top = vertical_margin
	style.content_margin_right = 6
	style.content_margin_bottom = vertical_margin
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_panel(background: Color, border: Color, radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _viewport_is_landscape() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.x >= viewport_size.y

func _power_name(p: String) -> String:
	match p:
		"hold":
			return "Hold"
		"undo":
			return "Undo"
		"refresh":
			return "Refresh"
	return p

func _power_icon(p: String) -> String:
	match p:
		"hold":
			return "📥"
		"undo":
			return "↩️"
		"refresh":
			return "🔀"
	return "?"

func _on_help() -> void:
	if _help_shown:
		return
	_help_shown = true
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 900
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BACKGROUND
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var txt := Label.new()
	txt.text = Localizer.t("help_text")
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(240, 0)
	txt.add_theme_color_override("font_color", TEXT_PRIMARY)
	col.add_child(txt)
	var close := Button.new()
	close.text = Localizer.t("close")
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(func(): overlay.queue_free(); _help_shown = false)
	col.add_child(close)

func _on_card(card_id: String) -> void:
	if controller.status != GameController.Status.PLAYING or _animating_card:
		return
	var card := controller.board.get_card(card_id)
	if card == null:
		return
	_play_sfx("select")
	var source_rect := _board_card_rect(card)
	var snap := _snapshot_zone()
	var target_index := controller.zone.size()
	var result := controller.select_card(card_id)
	await _perform_move(card.type, source_rect, snap, target_index, result)
	_check_end()

func _on_deck(deck_id: String) -> void:
	if controller.status != GameController.Status.PLAYING or _animating_card:
		return
	_play_sfx("select")
	var deck: DeckManager = controller.deck_a if deck_id == "a" else controller.deck_b
	var card_type := deck.current_type()
	var source_rect := (deck_a_btn if deck_id == "a" else deck_b_btn).get_global_rect()
	var snap := _snapshot_zone()
	var target_index := controller.zone.size()
	var result := controller.use_deck(deck_id)
	await _perform_move(card_type, source_rect, snap, target_index, result)
	_check_end()

func _on_reserve_return(card_id: String) -> void:
	if controller.status != GameController.Status.PLAYING or _animating_card:
		return
	_play_sfx("select")
	var source_rect := _reserve_card_rect(card_id)
	var card := _reserve_card(card_id)
	if card == null:
		return
	var snap := _snapshot_zone()
	var target_index := controller.zone.size()
	var result := controller.return_from_reserve(card_id)
	await _perform_move(card.type, source_rect, snap, target_index, result)
	_check_end()

func _perform_move(card_type: String, source_rect: Rect2, snap: Dictionary, target_index: int, result: Dictionary) -> void:
	if not result["ok"]:
		return
	var matched: Array = result["matched_ids"]
	# Keep the two existing zone cards on screen until the arriving third card
	# has landed. Non-matching moves can render immediately.
	if matched.is_empty():
		render()
	else:
		_hide_source_visual(source_rect)
	var target_rect: Rect2 = _zone_landing_rect(snap, target_index)
	var target_node: Control = null
	if matched.size() == 0 and target_index < zone_container.get_child_count():
		target_node = zone_container.get_child(target_index)
	await _animate_card_to_zone(card_type, source_rect, target_rect, matched.size() > 0, target_node)
	if matched.size() > 0:
		render()
		await _play_match_flash(_matched_rects(card_type, snap, target_index))
		await _slide_zone_compact(card_type, snap)
	_animating_card = false

func _hide_source_visual(source_rect: Rect2) -> void:
	var center := source_rect.get_center()
	for container in [board_container, reserve_container]:
		if container == null:
			continue
		for child in container.get_children():
			if child is Control and child.get_global_rect().has_point(center):
				child.modulate.a = 0.0
	for button in [deck_a_btn, deck_b_btn]:
		if button != null and button.get_global_rect().has_point(center):
			button.modulate.a = 0.0

func _on_power(power: String) -> void:
	if controller.status != GameController.Status.PLAYING or _animating_card:
		return
	_play_sfx("select")
	match power:
		"hold":
			controller.use_hold()
		"undo":
			controller.use_undo()
		"refresh":
			controller.use_refresh()
	render()
	_check_end()

func _board_card_rect(card: Card) -> Rect2:
	var layout := _board_layout()
	var scale: float = layout["scale"]
	var origin: Vector2 = layout["origin"]
	var position_scale: Vector2 = layout["position_scale"]
	var grid_positions: Dictionary = layout["grid_positions"]
	var card_size := CARD_DISPLAY_SIZE * scale * BOARD_CARD_SCALE
	var fallback_position := Vector2(
		(card.position.x - origin.x) * position_scale.x,
		(card.position.y - origin.y) * position_scale.y
	)
	var visual_position: Vector2 = grid_positions.get(card.id, fallback_position)
	return Rect2(board_container.global_position + _board_node_position(layout, visual_position), card_size)

func _reserve_card(card_id: String) -> Card:
	for card in controller.reserve:
		if card.id == card_id:
			return card
	return null

func _reserve_card_rect(card_id: String) -> Rect2:
	var card := _reserve_card(card_id)
	if card == null or reserve_container.get_child_count() == 0:
		return Rect2(reserve_container.global_position, CARD_DISPLAY_SIZE)
	var index := controller.reserve.find(card)
	if index < 0 or index >= reserve_container.get_child_count():
		return Rect2(reserve_container.global_position, CARD_DISPLAY_SIZE)
	return reserve_container.get_child(index).get_global_rect()

func _animate_card_to_zone(card_type: String, source_rect: Rect2, target_rect: Rect2, matched: bool, target_node: Control) -> void:
	_animating_card = true
	var ghost := _make_card_rect(card_type, false, CARD_DISPLAY_SIZE)
	ghost.global_position = source_rect.position
	ghost.pivot_offset = CARD_DISPLAY_SIZE / 2.0
	ghost.rotation = deg_to_rad(4.0)
	ghost.scale = Vector2(1.08, 1.08)
	ghost.z_index = 2000
	add_child(ghost)

	if not matched and target_node != null:
		target_node.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "global_position", target_rect.position, 0.3)
	tween.tween_property(ghost, "scale", Vector2.ONE, 0.3)
	tween.tween_property(ghost, "rotation", 0.0, 0.3)
	await tween.finished
	await get_tree().process_frame
	_play_sfx("place")
	if not matched and target_node != null:
		var reveal := create_tween()
		reveal.tween_property(target_node, "modulate", Color.WHITE, 0.1)
		await reveal.finished
	await _play_card_impact(target_rect.get_center())
	ghost.queue_free()

func _zone_landing_rect(snap: Dictionary, target_index: int) -> Rect2:
	var rects: Array = snap["rects"]
	if rects.size() > 0:
		return rects[mini(target_index, rects.size() - 1)]
	return Rect2(zone_container.global_position, _zone_card_size())

func _snapshot_zone() -> Dictionary:
	var types: Array = []
	var rects: Array = []
	for c in controller.zone.cards:
		types.append(c.type)
	for i in zone_container.get_child_count():
		rects.append(zone_container.get_child(i).get_global_rect())
	return {"types": types, "rects": rects}

func _matched_rects(card_type: String, snap: Dictionary, target_index: int) -> Array:
	var out: Array = []
	var types: Array = snap["types"]
	var rects: Array = snap["rects"]
	for i in types.size():
		if types[i] == card_type:
			out.append(rects[i])
	if rects.size() > 0:
		var land := mini(target_index, rects.size() - 1)
		out.append(rects[land])
	return out

func _play_match_flash(rects: Array) -> void:
	if rects.is_empty():
		return
	var flashes: Array = []
	var center := Vector2.ZERO
	for r in rects:
		var f := Panel.new()
		f.size = r.size
		f.global_position = r.position
		f.pivot_offset = r.size / 2.0
		f.z_index = 2005
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#ffd54a")
		style.border_color = Color("#fff7d6")
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		f.add_theme_stylebox_override("panel", style)
		add_child(f)
		flashes.append(f)
		center += r.get_center()
	center /= rects.size()
	_play_sfx("match")
	var tween := create_tween()
	tween.set_parallel(true)
	for f in flashes:
		tween.tween_property(f, "scale", Vector2(1.3, 1.3), 0.3)
		tween.tween_property(f, "modulate:a", 0.0, 0.45)
	await _play_gold_burst(center)
	await tween.finished
	for f in flashes:
		f.queue_free()

func _play_gold_burst(center: Vector2) -> void:
	var burst := UiHelpers.symbol_label("✦", 40)
	burst.position = center - Vector2(20, 20)
	burst.size = Vector2(40, 40)
	burst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	burst.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	burst.modulate = Color(1, 0.84, 0.3, 0.95)
	burst.pivot_offset = Vector2(20, 20)
	burst.z_index = 2006
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(burst)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(burst, "scale", Vector2(2.2, 2.2), 0.35)
	t.tween_property(burst, "modulate:a", 0.0, 0.35)
	await t.finished
	burst.queue_free()

func _slide_zone_compact(card_type: String, snap: Dictionary) -> void:
	var types: Array = snap["types"]
	var rects: Array = snap["rects"]
	var matched_count := 0
	var old_rects: Array = []
	for i in types.size():
		if types[i] == card_type and matched_count < 3:
			matched_count += 1
			continue
		old_rects.append(rects[i])
	if old_rects.is_empty():
		return
	await get_tree().process_frame
	var children := zone_container.get_children()
	for i in mini(old_rects.size(), children.size()):
		var child: Control = children[i]
		var final_pos: Vector2 = child.position
		var old_global: Vector2 = (old_rects[i] as Rect2).position
		var old_local: Vector2 = old_global - zone_container.global_position
		child.position = old_local
		var t := create_tween()
		t.set_trans(Tween.TRANS_CUBIC)
		t.set_ease(Tween.EASE_OUT)
		t.tween_property(child, "position", final_pos, 0.18)
	await get_tree().create_timer(0.18).timeout

func _play_card_impact(center: Vector2) -> void:
	var impact := UiHelpers.symbol_label("✦", 24)
	impact.position = center - Vector2(12, 12)
	impact.size = Vector2(24, 24)
	impact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	impact.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	impact.modulate = Color(1, 0.88, 0.35, 0.95)
	impact.pivot_offset = Vector2(12, 12)
	impact.z_index = 2001
	add_child(impact)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(impact, "scale", Vector2(1.6, 1.6), 0.16)
	tween.tween_property(impact, "modulate", Color(1, 0.88, 0.35, 0), 0.16)
	await tween.finished
	impact.queue_free()

func _play_sfx(kind: String) -> void:
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "PlaceholderSfx"
		add_child(_sfx_player)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.18
	_sfx_player.stream = stream
	_sfx_player.play()
	var playback := _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frequency := 440.0
	var duration := 0.08
	match kind:
		"select":
			frequency = 700.0
		"place":
			frequency = 520.0
		"match":
			frequency = 760.0
			duration = 0.16
		"win":
			frequency = 920.0
			duration = 0.22
		"lose":
			frequency = 180.0
			duration = 0.20
	var frames := int(stream.mix_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	for i in frames:
		var t := float(i) / stream.mix_rate
		var envelope := 1.0 - float(i) / float(frames)
		var sample := sin(TAU * frequency * t) * 0.16 * envelope
		buffer[i] = Vector2(sample, sample)
	playback.push_buffer(buffer)

func _check_end() -> void:
	if controller.status == GameController.Status.WON:
		_show_end(true)
	elif controller.status == GameController.Status.LOST:
		_show_end(false)

func _show_end(win: bool) -> void:
	if _ended:
		return
	_ended = true
	_play_sfx("win" if win else "lose")
	if win:
		Game.complete_level(controller.stars, controller.rewards)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 1000
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var info := VBoxContainer.new()
	info.set_anchors_preset(Control.PRESET_FULL_RECT)
	info.offset_bottom = -84
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 8)
	info.z_index = 1001
	add_child(info)

	var stage_num := Label.new()
	stage_num.text = str(controller.level_id)
	stage_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_num.add_theme_font_size_override("font_size", 48)
	stage_num.add_theme_color_override("font_color", TEXT_PRIMARY)
	info.add_child(stage_num)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TEXT_MUTED)
	title.text = Localizer.t("level_complete") if win else Localizer.t("no_moves")
	info.add_child(title)

	if win:
		var stars_row := HBoxContainer.new()
		stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stars_row.add_theme_constant_override("separation", 6)
		info.add_child(stars_row)
		for i in 3:
			var star := UiHelpers.symbol_label("★" if i < controller.stars else "☆", 40)
			star.modulate = Color(1, 1, 1, 0)
			star.scale = Vector2(0.3, 0.3)
			stars_row.add_child(star)
		_reveal_stars(stars_row)

		var time_line := Label.new()
		time_line.text = "%s: %s" % [Localizer.t("time"), _format_time(controller.timer.elapsed_seconds())]
		time_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_line.add_theme_color_override("font_color", TEXT_PRIMARY)
		info.add_child(time_line)

		if controller.rewards.size() > 0:
			var reward_title := Label.new()
			reward_title.text = Localizer.t("stage_reward")
			reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reward_title.add_theme_font_size_override("font_size", 14)
			reward_title.add_theme_color_override("font_color", TEXT_MUTED)
			info.add_child(reward_title)
			for r in controller.rewards:
				var rtype := str(r.get("type", ""))
				var qty := int(r.get("quantity", 0))
				var line := Label.new()
				line.text = "%s  +%d" % [_power_name(rtype), qty]
				line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				line.add_theme_font_size_override("font_size", 16)
				line.add_theme_color_override("font_color", Color("#ffe36e"))
				info.add_child(line)

		var total_stars := Label.new()
		total_stars.text = "★ %d/%d" % [Game.progress.total_stars(), LevelLoader.load_all_level_ids().size() * 3]
		total_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_stars.add_theme_font_size_override("font_size", 16)
		total_stars.add_theme_color_override("font_color", Color("#ffe36e"))
		total_stars.add_theme_font_override("font", UiHelpers.symbol_font())
		info.add_child(total_stars)

	var buttons := HBoxContainer.new()
	buttons.anchor_left = 0.0
	buttons.anchor_right = 1.0
	buttons.anchor_top = 1.0
	buttons.anchor_bottom = 1.0
	buttons.offset_top = -76.0
	buttons.offset_bottom = -16.0
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.z_index = 1002
	add_child(buttons)

	if win and LevelLoader.level_exists(int(controller.level_id) + 1):
		var next_btn := Button.new()
		next_btn.text = Localizer.t("next_level")
		next_btn.custom_minimum_size = Vector2(150, 44)
		next_btn.pressed.connect(func(): Game.start_level(int(controller.level_id) + 1))
		buttons.add_child(next_btn)

	if not win:
		var retry_btn := Button.new()
		retry_btn.text = Localizer.t("retry")
		retry_btn.custom_minimum_size = Vector2(150, 44)
		retry_btn.pressed.connect(func(): Game.restart_level())
		buttons.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = Localizer.t("menu")
	menu_btn.custom_minimum_size = Vector2(150, 44)
	menu_btn.pressed.connect(func(): Game.go_to_menu())
	buttons.add_child(menu_btn)

func _reveal_stars(stars_row: HBoxContainer) -> void:
	await get_tree().process_frame
	for child in stars_row.get_children():
		var star := child as Control
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(star, "modulate", Color.WHITE, 0.2)
		t.tween_property(star, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.3).timeout

func _play_intro() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1500
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := get_viewport_rect().size * 0.5
	var burst := UiHelpers.symbol_label("✦", 120)
	burst.position = center - Vector2(60, 60)
	burst.size = Vector2(120, 120)
	burst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	burst.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	burst.modulate = Color(1, 0.84, 0.3, 0.9)
	burst.pivot_offset = Vector2(60, 60)
	burst.scale = Vector2(0.4, 0.4)
	overlay.add_child(burst)

	var title := Label.new()
	title.text = "%s %s" % [Localizer.t("level"), controller.level_id]
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.modulate = Color(1, 1, 1, 0)
	overlay.add_child(title)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(burst, "scale", Vector2(1.6, 1.6), 0.45)
	t.tween_property(burst, "modulate:a", 0.0, 0.5)
	t.tween_property(title, "modulate", Color.WHITE, 0.25)
	await get_tree().create_timer(0.7).timeout
	var fade := create_tween()
	fade.tween_property(title, "modulate:a", 0.0, 0.2)
	await fade.finished
	overlay.queue_free()

func _show_error(msg: String) -> void:
	var label := Label.new()
	label.text = "Erro: %s" % msg
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)

func _format_time(sec: float) -> String:
	var s := int(sec)
	var m := int(s / 60.0)
	var ss := s % 60
	return "%02d:%02d" % [m, ss]

func _update_live_stars() -> void:
	if stars_label == null:
		return
	var s: int = controller.stars
	if controller.status == GameController.Status.PLAYING:
		s = controller.calculate_stars(controller.timer.elapsed_seconds())
	var txt := ""
	for i in 3:
		txt += "★" if i < s else "☆"
	stars_label.text = txt
	if s < _live_star_count:
		_animate_star_loss()
	_live_star_count = s

func _animate_star_loss() -> void:
	if stars_label == null:
		return
	var t := create_tween()
	t.tween_property(stars_label, "scale", Vector2(1.25, 1.25), 0.12)
	t.tween_property(stars_label, "scale", Vector2.ONE, 0.18)
	t.tween_property(stars_label, "modulate", Color(1, 0.55, 0.3), 0.1)
	t.tween_property(stars_label, "modulate", Color.WHITE, 0.15)
