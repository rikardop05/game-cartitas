extends Control

const CARD_DISPLAY_SIZE := Card.DISPLAY_SIZE
const RESERVE_COLUMNS := 2
const RESERVE_PANEL_SIZE := Vector2(80, 60)
const WARM_BACKGROUND := Color("#c78454")
const PANEL_BACKGROUND := Color(0.16, 0.10, 0.08, 0.78)
const PANEL_BORDER := Color("#f3d28d")
const TEXT_PRIMARY := Color("#fff1d2")
const TEXT_MUTED := Color("#f0c98e")

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
var _is_landscape := true
var _animating_card := false
var _ended := false

func _ready() -> void:
	var level_id: String = Game.current_level_id
	var level: Dictionary = LevelLoader.load_level(level_id)
	if level.has("error"):
		_show_error(str(level["error"]))
		return
	var validation := LevelValidator.validate(level)
	if not validation["valid"]:
		_show_error("%s\n%s" % [Localizer.t("invalid_level"), "\n".join(validation["errors"])])
		return
	controller = GameController.new()
	controller.start_level(level, Game.progress.inventory)
	_build_ui()
	resized.connect(_on_resized)
	await get_tree().process_frame
	render()

func _process(_delta: float) -> void:
	if controller == null:
		return
	if controller.status == GameController.Status.PLAYING:
		timer_label.text = _format_time(controller.timer.elapsed_seconds())
	_update_live_stars()

func _on_resized() -> void:
	if controller != null and not _ended:
		var landscape := _viewport_is_landscape()
		if landscape != _is_landscape:
			_build_ui()
			call_deferred("render")
		else:
			render()

func _build_ui() -> void:
	_is_landscape = _viewport_is_landscape()
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
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	vbox.add_child(_build_hud())
	instruction_label = Label.new()
	instruction_label.text = Localizer.t("instruction")
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	instruction_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(instruction_label)

	if _is_landscape:
		var body := HBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 10)
		vbox.add_child(body)
		body.add_child(_build_main_column())
		var controls := _build_controls()
		controls.custom_minimum_size = Vector2(80, 0)
		body.add_child(controls)
	else:
		vbox.add_child(_build_main_column())
		vbox.add_child(_build_controls())

func _build_hud() -> PanelContainer:
	var panel := _make_unframed_panel()
	panel.custom_minimum_size = Vector2(0, 34)
	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 5)
	panel.add_child(hud)
	var back := Button.new()
	back.text = "<"
	back.flat = true
	back.custom_minimum_size = Vector2(24, 24)
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_color_override("font_color", TEXT_PRIMARY)
	back.pressed.connect(Game.go_to_menu)
	hud.add_child(back)
	level_label = Label.new()
	level_label.text = "%s %s" % [Localizer.t("level"), controller.level_id]
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(level_label)
	_add_expander(hud)
	timer_label = Label.new()
	timer_label.text = "00:00"
	timer_label.add_theme_font_size_override("font_size", 14)
	timer_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.custom_minimum_size = Vector2(52, 24)
	hud.add_child(timer_label)
	_add_expander(hud)
	stars_label = UiHelpers.symbol_label("☆☆☆", 14)
	stars_label.add_theme_color_override("font_color", Color("#ffe36e"))
	stars_label.custom_minimum_size = Vector2(58, 24)
	stars_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(stars_label)
	return panel

func _build_main_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)

	var board_panel := _make_panel(Color(0.19, 0.12, 0.09, 0.30), Color(1, 0.88, 0.60, 0.45), 12)
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_container = Control.new()
	board_container.custom_minimum_size = Vector2(0, 80)
	board_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_child(board_container)
	col.add_child(board_panel)

	var deck_row := HBoxContainer.new()
	deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_row.add_theme_constant_override("separation", 44)
	deck_row.custom_minimum_size = Vector2(0, 62)
	col.add_child(deck_row)
	deck_a_btn = _make_deck_button("a")
	deck_b_btn = _make_deck_button("b")
	deck_row.add_child(_make_deck_slot("A", deck_a_btn))
	deck_row.add_child(_make_deck_slot("B", deck_b_btn))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 5)
	col.add_child(bottom)
	var reserve_panel := _make_panel(PANEL_BACKGROUND, PANEL_BORDER, 10)
	reserve_panel.custom_minimum_size = RESERVE_PANEL_SIZE
	var reserve_col := VBoxContainer.new()
	reserve_col.add_theme_constant_override("separation", 2)
	reserve_panel.add_child(reserve_col)
	reserve_header = Label.new()
	reserve_header.add_theme_font_size_override("font_size", 8)
	reserve_header.add_theme_color_override("font_color", TEXT_MUTED)
	reserve_col.add_child(reserve_header)
	reserve_container = Control.new()
	reserve_container.custom_minimum_size = Vector2(0, CARD_DISPLAY_SIZE.y)
	reserve_container.clip_contents = true
	reserve_col.add_child(reserve_container)
	bottom.add_child(reserve_panel)

	var zone_panel := _make_unframed_panel()
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
	zone_container.custom_minimum_size = CARD_DISPLAY_SIZE
	zone_container.add_theme_constant_override("h_separation", 3)
	zone_container.add_theme_constant_override("v_separation", 3)
	zone_col.add_child(zone_container)
	bottom.add_child(zone_panel)
	return col

func _build_controls() -> PanelContainer:
	var panel := _make_unframed_panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	panel.add_child(col)
	var title := Label.new()
	title.text = Localizer.t("powers")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	col.add_child(title)
	var power_row: Control = VBoxContainer.new() if _is_landscape else HBoxContainer.new()
	power_row.add_theme_constant_override("separation", 4)
	col.add_child(power_row)
	for p in PowerManager.POWERS:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 38)
		btn.add_theme_font_size_override("font_size", 12)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_power.bind(p))
		power_buttons[p] = btn
		power_row.add_child(btn)
	return panel

func _make_deck_slot(label_text: String, button: Button) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Label.new()
	title.text = "%s %s" % [Localizer.t("support_deck"), label_text]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", TEXT_MUTED)
	slot.add_child(title)
	slot.add_child(button)
	return slot

func _make_deck_button(deck_id: String) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = CARD_DISPLAY_SIZE
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
	var scale_x: float = layout["scale_x"]
	var scale_y: float = layout["scale_y"]

	var board_cards: Array = controller.board.cards.duplicate()
	board_cards.sort_custom(func(a, b): return a.layer < b.layer)
	for card in board_cards:
		if card.is_removed() or card.location != Card.Location.BOARD:
			continue
		var visually_blocked := _is_visually_blocked(card, board_cards, offset, scale_x, scale_y)
		var darken: bool = card.state != Card.State.AVAILABLE or visually_blocked
		var node := _make_card_button(card, darken, _on_card.bind(card.id), CARD_DISPLAY_SIZE)
		node.position = Vector2(
			offset.x + card.position.x * scale_x,
			offset.y + card.position.y * scale_y
		)
		node.z_index = card.layer
		board_container.add_child(node)

	zone_header.text = "%s  %d/%d" % [Localizer.t("clearing_zone"), controller.zone.size(), controller.clearing_capacity]
	for i in controller.clearing_capacity:
		if i < controller.zone.cards.size():
			zone_container.add_child(_make_card_display(controller.zone.cards[i].type, CARD_DISPLAY_SIZE))
		else:
			zone_container.add_child(_make_empty_slot(CARD_DISPLAY_SIZE))

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
		btn.text = "%s\n%d" % [_power_name(p), count]
		btn.disabled = count <= 0

func _clear(c: Node) -> void:
	for child in c.get_children():
		c.remove_child(child)
		child.queue_free()

func _reserve_card_size() -> Vector2:
	var count := controller.reserve.size()
	if count <= 0:
		return CARD_DISPLAY_SIZE
	var available_height := maxf(CARD_DISPLAY_SIZE.y, reserve_container.size.y)
	var tab := 6.0
	var rows := ceili(float(count) / float(RESERVE_COLUMNS))
	var side := minf(CARD_DISPLAY_SIZE.y, maxf(24.0, available_height - tab * maxi(0, rows - 1)))
	var available_width := maxf(24.0, reserve_container.size.x / float(RESERVE_COLUMNS) - 2.0)
	side = minf(side, available_width)
	return Vector2(side, side)

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
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	for c in controller.board.cards:
		if c.source != Card.Source.BOARD:
			continue
		minx = minf(minx, c.position.x)
		maxx = maxf(maxx, c.position.x)
		miny = minf(miny, c.position.y)
		maxy = maxf(maxy, c.position.y)
	if minx == INF:
		return {"offset": Vector2.ZERO, "scale_x": 1.0, "scale_y": 1.0}
	var span_x := maxx - minx
	var span_y := maxy - miny
	var avail := board_container.size
	if avail.x <= 0 or avail.y <= 0:
		return {"offset": Vector2.ZERO, "scale_x": 1.0, "scale_y": 1.0}
	var scale_x := 1.0
	var scale_y := 1.0
	if span_x > 0:
		scale_x = minf(scale_x, maxf(0.0, (avail.x - CARD_DISPLAY_SIZE.x) / span_x))
	if span_y > 0:
		scale_y = minf(scale_y, maxf(0.0, (avail.y - CARD_DISPLAY_SIZE.y) / span_y))
	var offset := Vector2(
		(avail.x - (span_x * scale_x + CARD_DISPLAY_SIZE.x)) / 2.0 - minx * scale_x,
		(avail.y - (span_y * scale_y + CARD_DISPLAY_SIZE.y)) / 2.0 - miny * scale_y
	)
	return {"offset": offset, "scale_x": scale_x, "scale_y": scale_y}

func _is_visually_blocked(card: Card, board_cards: Array, offset: Vector2, scale_x: float, scale_y: float) -> bool:
	var card_rect := _visual_card_rect(card, offset, scale_x, scale_y)
	for other in board_cards:
		if other == card or other.location != Card.Location.BOARD or other.is_removed():
			continue
		if other.layer <= card.layer:
			continue
		if card_rect.intersects(_visual_card_rect(other, offset, scale_x, scale_y)):
			return true
	return false

func _visual_card_rect(card: Card, offset: Vector2, scale_x: float, scale_y: float) -> Rect2:
	return Rect2(
		Vector2(offset.x + card.position.x * scale_x, offset.y + card.position.y * scale_y),
		CARD_DISPLAY_SIZE
	)

func _make_card_rect(type: String, darken: bool, size: Vector2) -> Control:
	var root := Panel.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = CardTypeRegistry.color(type)
	card_style.border_color = Color("#fff2d5")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(5)
	root.add_theme_stylebox_override("panel", card_style)
	root.add_child(_make_card_art(type, size))
	if darken:
		root.modulate = Color(0.42, 0.42, 0.42)
	return root

func _make_card_art(type: String, size: Vector2) -> Control:
	var path := "res://assets/cards/card_%s.png" % type
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture == null:
			return _make_card_placeholder(type, size)
		var art := TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.position = Vector2.ZERO
		art.size = size
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return art
	return _make_card_placeholder(type, size)

func _make_card_placeholder(type: String, size: Vector2) -> Label:
	var label := UiHelpers.symbol_label(CardTypeRegistry.symbol(type), int(size.y * 0.55))
	label.position = Vector2.ZERO
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_card_button(card: Card, darken: bool, on_click: Callable, size: Vector2) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = size
	btn.size = size
	btn.disabled = darken
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_child(_make_card_rect(card.type, darken, size))
	btn.pressed.connect(on_click)
	return btn

func _make_card_display(type: String, size: Vector2) -> Control:
	return _make_card_rect(type, false, size)

func _make_empty_slot(size: Vector2) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = size
	slot.size = size
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
	btn.size = CARD_DISPLAY_SIZE
	if deck.is_empty():
		btn.disabled = true
		btn.add_child(_make_empty_slot(CARD_DISPLAY_SIZE))
		return
	btn.disabled = false
	btn.add_child(_make_card_rect(deck.current_type(), false, CARD_DISPLAY_SIZE))
	var badge := ColorRect.new()
	badge.color = Color(0, 0, 0, 0.55)
	badge.position = Vector2(CARD_DISPLAY_SIZE.x - 20, 2)
	badge.size = Vector2(18, 16)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	var cnt := Label.new()
	cnt.text = str(deck.remaining_count())
	cnt.position = badge.position
	cnt.size = badge.size
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cnt.add_theme_font_size_override("font_size", 12)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cnt)

func _make_unframed_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
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
	var size := get_viewport_rect().size
	return size.x >= size.y

func _power_name(p: String) -> String:
	match p:
		"hold":
			return "Hold"
		"undo":
			return "Undo"
		"refresh":
			return "Refresh"
	return p

func _on_card(card_id: String) -> void:
	if controller.status != GameController.Status.PLAYING or _animating_card:
		return
	var card := controller.board.get_card(card_id)
	if card == null:
		return
	var source_rect := _board_card_rect(card)
	var target_index := controller.zone.size()
	var result := controller.select_card(card_id)
	render()
	if result["ok"]:
		await _animate_card_to_zone(card.type, source_rect, target_index, result["matched_ids"].has(card_id))
	_check_end()

func _on_deck(deck_id: String) -> void:
	if controller.status != GameController.Status.PLAYING or _animating_card:
		return
	var deck: DeckManager = controller.deck_a if deck_id == "a" else controller.deck_b
	var card_type := deck.current_type()
	var source_rect := (deck_a_btn if deck_id == "a" else deck_b_btn).get_global_rect()
	var target_index := controller.zone.size()
	var result := controller.use_deck(deck_id)
	render()
	if result["ok"]:
		await _animate_card_to_zone(card_type, source_rect, target_index, result["matched_ids"].size() > 0)
	_check_end()

func _on_reserve_return(card_id: String) -> void:
	if controller.status != GameController.Status.PLAYING or _animating_card:
		return
	var source_rect := _reserve_card_rect(card_id)
	var card := _reserve_card(card_id)
	if card == null:
		return
	var target_index := controller.zone.size()
	var result := controller.return_from_reserve(card_id)
	render()
	if result["ok"]:
		await _animate_card_to_zone(card.type, source_rect, target_index, result["matched_ids"].has(card_id))
	_check_end()

func _on_power(power: String) -> void:
	if controller.status != GameController.Status.PLAYING or _animating_card:
		return
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
	var offset: Vector2 = layout["offset"]
	return Rect2(
		board_container.global_position + Vector2(
			offset.x + card.position.x * float(layout["scale_x"]),
			offset.y + card.position.y * float(layout["scale_y"])
		),
		CARD_DISPLAY_SIZE
	)

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

func _animate_card_to_zone(card_type: String, source_rect: Rect2, target_index: int, matched: bool) -> void:
	_animating_card = true
	await get_tree().process_frame
	var target_rect := _zone_target_rect(target_index)
	var ghost := _make_card_rect(card_type, false, CARD_DISPLAY_SIZE)
	ghost.global_position = source_rect.position
	ghost.pivot_offset = CARD_DISPLAY_SIZE / 2.0
	ghost.rotation = deg_to_rad(4.0)
	ghost.scale = Vector2(1.08, 1.08)
	ghost.z_index = 2000
	add_child(ghost)

	var target: CanvasItem = null
	if not matched and target_index < zone_container.get_child_count():
		target = zone_container.get_child(target_index)
		target.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "global_position", target_rect.position, 0.3)
	tween.tween_property(ghost, "scale", Vector2.ONE, 0.3)
	tween.tween_property(ghost, "rotation", 0.0, 0.3)
	await tween.finished
	if target != null:
		var reveal := create_tween()
		reveal.tween_property(target, "modulate", Color.WHITE, 0.1)
		await reveal.finished
	await _play_card_impact(target_rect.get_center())
	ghost.queue_free()
	_animating_card = false

func _zone_target_rect(target_index: int) -> Rect2:
	if zone_container.get_child_count() > 0:
		var index := mini(target_index, zone_container.get_child_count() - 1)
		return zone_container.get_child(index).get_global_rect()
	var fallback := Rect2(zone_container.global_position, CARD_DISPLAY_SIZE)
	fallback.position += Vector2(0, zone_container.size.y / 2.0 - CARD_DISPLAY_SIZE.y / 2.0)
	return fallback

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

func _check_end() -> void:
	if controller.status == GameController.Status.WON:
		_show_end(true)
	elif controller.status == GameController.Status.LOST:
		_show_end(false)

func _show_end(win: bool) -> void:
	if _ended:
		return
	_ended = true
	if win:
		Game.complete_level(controller.stars, controller.rewards)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 1000
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	vbox.z_index = 1001
	add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	if win:
		title.text = Localizer.t("level_complete")
	else:
		title.text = Localizer.t("no_moves")
	vbox.add_child(title)

	if win:
		var stars: int = controller.stars
		var star_str := ""
		for i in 3:
			star_str += "★" if i < stars else "☆"
		var stars_label := UiHelpers.symbol_label(star_str, 40)
		stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stars_label)
		var time_line := Label.new()
		time_line.text = "%s: %s" % [Localizer.t("time"), _format_time(controller.timer.elapsed_seconds())]
		time_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(time_line)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	if win and LevelLoader.level_exists(int(controller.level_id) + 1):
		var next_btn := Button.new()
		next_btn.text = Localizer.t("next_level")
		next_btn.custom_minimum_size = Vector2(200, 46)
		next_btn.pressed.connect(func(): Game.start_level(int(controller.level_id) + 1))
		vbox.add_child(next_btn)

	if not win:
		var retry_btn := Button.new()
		retry_btn.text = Localizer.t("retry")
		retry_btn.custom_minimum_size = Vector2(200, 46)
		retry_btn.pressed.connect(func(): Game.restart_level())
		vbox.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = Localizer.t("menu")
	menu_btn.custom_minimum_size = Vector2(200, 46)
	menu_btn.pressed.connect(func(): Game.go_to_menu())
	vbox.add_child(menu_btn)

func _show_error(msg: String) -> void:
	var label := Label.new()
	label.text = "Erro: %s" % msg
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)

func _format_time(sec: float) -> String:
	var s := int(sec)
	var m := s / 60
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
