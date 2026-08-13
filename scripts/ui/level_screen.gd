extends Control

const BOARD_CARD := Vector2(64, 64)
const TRAY_CARD := Vector2(40, 40)

var controller: GameController
var board_container: Control
var zone_container: HFlowContainer
var reserve_header: Label
var reserve_container: HFlowContainer
var deck_a_btn: Button
var deck_b_btn: Button
var power_buttons: Dictionary = {}
var timer_label: Label
var stars_label: Label
var level_label: Label
var _ended := false

func _ready() -> void:
	var level_id: String = Game.current_level_id
	var level: Dictionary = LevelLoader.load_level(level_id)
	if level.has("error"):
		_show_error(str(level["error"]))
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
	if controller != null:
		render()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#17181d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	vbox.add_child(_build_hud())

	var landscape := get_viewport_rect().size.x > get_viewport_rect().size.y
	if landscape:
		var body := HBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 12)
		vbox.add_child(body)
		board_container = Control.new()
		board_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(board_container)
		var controls := _build_controls()
		controls.custom_minimum_size = Vector2(300, 0)
		body.add_child(controls)
	else:
		board_container = Control.new()
		board_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(board_container)
		vbox.add_child(_build_controls())

func _build_hud() -> HBoxContainer:
	var hud := HBoxContainer.new()
	level_label = Label.new()
	level_label.text = "Level %s" % controller.level_id
	level_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(level_label)
	_add_expander(hud)
	timer_label = Label.new()
	timer_label.text = "00:00"
	timer_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(timer_label)
	_add_expander(hud)
	stars_label = UiHelpers.symbol_label("☆☆☆", 18)
	hud.add_child(stars_label)
	return hud

func _build_controls() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var deck_row := HBoxContainer.new()
	deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_row.add_theme_constant_override("separation", 12)
	col.add_child(deck_row)
	deck_a_btn = _make_deck_button("a")
	deck_b_btn = _make_deck_button("b")
	deck_row.add_child(deck_a_btn)
	deck_row.add_child(deck_b_btn)

	var zone_header := Label.new()
	zone_header.text = "%s (%d)" % [Localizer.t("clearing_zone"), controller.clearing_capacity]
	zone_header.add_theme_font_size_override("font_size", 12)
	zone_header.modulate = Color(0.7, 0.7, 0.7)
	col.add_child(zone_header)

	zone_container = HFlowContainer.new()
	zone_container.alignment = FlowContainer.ALIGNMENT_CENTER
	zone_container.add_theme_constant_override("h_separation", 3)
	zone_container.add_theme_constant_override("v_separation", 3)
	col.add_child(zone_container)

	reserve_header = Label.new()
	reserve_header.text = Localizer.t("reserve")
	reserve_header.add_theme_font_size_override("font_size", 12)
	reserve_header.modulate = Color(0.7, 0.7, 0.7)
	col.add_child(reserve_header)

	reserve_container = HFlowContainer.new()
	reserve_container.alignment = FlowContainer.ALIGNMENT_CENTER
	reserve_container.add_theme_constant_override("h_separation", 3)
	reserve_container.add_theme_constant_override("v_separation", 3)
	col.add_child(reserve_container)

	var power_row := HBoxContainer.new()
	power_row.custom_minimum_size = Vector2(0, 56)
	power_row.add_theme_constant_override("separation", 12)
	col.add_child(power_row)
	for p in PowerManager.POWERS:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_power.bind(p))
		power_buttons[p] = btn
		power_row.add_child(btn)
	return col

func _make_deck_button(deck_id: String) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = BOARD_CARD
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

	var board_cards: Array = controller.board.cards.duplicate()
	board_cards.sort_custom(func(a, b): return a.layer < b.layer)
	for card in board_cards:
		if card.is_removed() or card.location != Card.Location.BOARD:
			continue
		var darken: bool = card.state != Card.State.AVAILABLE
		var node := _make_card_button(card, darken, _on_card.bind(card.id), BOARD_CARD)
		node.position = offset + card.position * scale
		node.scale = Vector2(scale, scale)
		board_container.add_child(node)

	for card in controller.zone.cards:
		zone_container.add_child(_make_card_display(card.type, TRAY_CARD))

	reserve_header.visible = controller.reserve.size() > 0
	for card in controller.reserve:
		reserve_container.add_child(_make_card_button(card, false, _on_reserve_return.bind(card.id), TRAY_CARD))

	_update_deck_button(deck_a_btn, controller.deck_a)
	_update_deck_button(deck_b_btn, controller.deck_b)

	for p in PowerManager.POWERS:
		var btn: Button = power_buttons[p]
		var count: int = controller.powers.get_count(p)
		btn.text = "%s  ×%d" % [_power_name(p), count]
		btn.disabled = count <= 0

func _clear(c: Node) -> void:
	for child in c.get_children():
		c.remove_child(child)
		child.queue_free()

func _board_layout() -> Dictionary:
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	for c in controller.board.cards:
		minx = minf(minx, c.position.x)
		maxx = maxf(maxx, c.position.x + Card.SIZE.x)
		miny = minf(miny, c.position.y)
		maxy = maxf(maxy, c.position.y + Card.SIZE.y)
	if minx == INF:
		return {"offset": Vector2.ZERO, "scale": 1.0}
	var bw := maxx - minx
	var bh := maxy - miny
	var avail := board_container.size
	if bw <= 0 or bh <= 0 or avail.x <= 0 or avail.y <= 0:
		return {"offset": Vector2.ZERO, "scale": 1.0}
	var scale := minf(1.0, minf(avail.x / bw, avail.y / bh))
	var offset := Vector2(
		(avail.x - bw * scale) / 2.0 - minx * scale,
		(avail.y - bh * scale) / 2.0 - miny * scale
	)
	return {"offset": offset, "scale": scale}

func _make_card_rect(type: String, darken: bool, size: Vector2) -> Control:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ColorRect.new()
	rect.color = CardTypeRegistry.color(type)
	rect.position = Vector2.ZERO
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rect)
	var label := UiHelpers.symbol_label(CardTypeRegistry.symbol(type), int(size.y * 0.55))
	label.position = Vector2.ZERO
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	if darken:
		root.modulate = Color(0.42, 0.42, 0.42)
	return root

func _make_card_button(card: Card, darken: bool, on_click: Callable, size: Vector2) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = size
	btn.add_child(_make_card_rect(card.type, darken, size))
	btn.pressed.connect(on_click)
	return btn

func _make_card_display(type: String, size: Vector2) -> Control:
	return _make_card_rect(type, false, size)

func _update_deck_button(btn: Button, deck: DeckManager) -> void:
	_clear(btn)
	if deck.is_empty():
		btn.disabled = true
		var rect := ColorRect.new()
		rect.color = Color(0.22, 0.22, 0.28)
		rect.position = Vector2.ZERO
		rect.size = BOARD_CARD
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(rect)
		return
	btn.disabled = false
	btn.add_child(_make_card_rect(deck.current_type(), false, BOARD_CARD))
	var badge := ColorRect.new()
	badge.color = Color(0, 0, 0, 0.55)
	badge.position = Vector2(BOARD_CARD.x - 24, 2)
	badge.size = Vector2(22, 18)
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
	if controller.status != GameController.Status.PLAYING:
		return
	controller.select_card(card_id)
	render()
	_check_end()

func _on_deck(deck_id: String) -> void:
	if controller.status != GameController.Status.PLAYING:
		return
	controller.use_deck(deck_id)
	render()
	_check_end()

func _on_reserve_return(card_id: String) -> void:
	if controller.status != GameController.Status.PLAYING:
		return
	controller.return_from_reserve(card_id)
	render()
	_check_end()

func _on_power(power: String) -> void:
	if controller.status != GameController.Status.PLAYING:
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
	add_child(shade)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
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
