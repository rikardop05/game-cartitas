extends Control

var controller: GameController
var board_container: Control
var zone_container: HBoxContainer
var reserve_header: Label
var reserve_container: HBoxContainer
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
	render()

func _process(_delta: float) -> void:
	if controller == null:
		return
	if controller.status == GameController.Status.PLAYING:
		timer_label.text = _format_time(controller.timer.elapsed_seconds())
	_update_live_stars()

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

	var hud := HBoxContainer.new()
	vbox.add_child(hud)
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

	board_container = Control.new()
	board_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(board_container)

	var deck_row := HBoxContainer.new()
	deck_row.add_theme_constant_override("separation", 12)
	vbox.add_child(deck_row)
	deck_a_btn = Button.new()
	deck_b_btn = Button.new()
	deck_a_btn.add_theme_font_override("font", UiHelpers.symbol_font())
	deck_b_btn.add_theme_font_override("font", UiHelpers.symbol_font())
	deck_a_btn.custom_minimum_size = Vector2(0, 56)
	deck_b_btn.custom_minimum_size = Vector2(0, 56)
	deck_a_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_b_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_a_btn.pressed.connect(_on_deck.bind("a"))
	deck_b_btn.pressed.connect(_on_deck.bind("b"))
	deck_row.add_child(deck_a_btn)
	deck_row.add_child(deck_b_btn)

	var zone_header := Label.new()
	zone_header.text = "%s (%d)" % [Localizer.t("clearing_zone"), controller.clearing_capacity]
	zone_header.add_theme_font_size_override("font_size", 12)
	zone_header.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(zone_header)

	zone_container = HBoxContainer.new()
	zone_container.custom_minimum_size = Vector2(0, 40)
	zone_container.alignment = BoxContainer.ALIGNMENT_CENTER
	zone_container.add_theme_constant_override("separation", 4)
	vbox.add_child(zone_container)

	reserve_header = Label.new()
	reserve_header.text = Localizer.t("reserve")
	reserve_header.add_theme_font_size_override("font_size", 12)
	reserve_header.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(reserve_header)

	reserve_container = HBoxContainer.new()
	reserve_container.custom_minimum_size = Vector2(0, 40)
	reserve_container.alignment = BoxContainer.ALIGNMENT_CENTER
	reserve_container.add_theme_constant_override("separation", 4)
	vbox.add_child(reserve_container)

	var power_row := HBoxContainer.new()
	power_row.custom_minimum_size = Vector2(0, 60)
	power_row.add_theme_constant_override("separation", 12)
	vbox.add_child(power_row)
	for p in PowerManager.POWERS:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_power.bind(p))
		power_buttons[p] = btn
		power_row.add_child(btn)

func _add_expander(parent: Control) -> void:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)

func render() -> void:
	_clear(board_container)
	_clear(zone_container)
	_clear(reserve_container)

	var offset := _board_offset()
	var board_cards: Array = controller.board.cards.duplicate()
	board_cards.sort_custom(func(a, b): return a.layer < b.layer)
	for card in board_cards:
		if card.is_removed() or card.location != Card.Location.BOARD:
			continue
		var darken: bool = card.state != Card.State.AVAILABLE
		var node := _make_card_button(card, darken, _on_card.bind(card.id))
		node.position = card.position + offset
		node.size = Card.SIZE
		board_container.add_child(node)

	for card in controller.zone.cards:
		zone_container.add_child(_make_card_display(card.type))

	reserve_header.visible = controller.reserve.size() > 0
	for card in controller.reserve:
		reserve_container.add_child(_make_card_button(card, false, _on_reserve_return.bind(card.id)))

	_update_deck_button(deck_a_btn, controller.deck_a, "a")
	_update_deck_button(deck_b_btn, controller.deck_b, "b")

	for p in PowerManager.POWERS:
		var btn: Button = power_buttons[p]
		var count: int = controller.powers.get_count(p)
		btn.text = "%s  ×%d" % [_power_name(p), count]
		btn.disabled = count <= 0

func _clear(c: Node) -> void:
	for child in c.get_children():
		c.remove_child(child)
		child.queue_free()

func _board_offset() -> Vector2:
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	for c in controller.board.cards:
		if c.is_removed():
			continue
		minx = minf(minx, c.position.x)
		maxx = maxf(maxx, c.position.x + Card.SIZE.x)
		miny = minf(miny, c.position.y)
		maxy = maxf(maxy, c.position.y + Card.SIZE.y)
	if minx == INF:
		return Vector2.ZERO
	var bw := maxx - minx
	var bh := maxy - miny
	var ox := (board_container.size.x - bw) / 2.0 - minx
	var oy := (board_container.size.y - bh) / 2.0 - miny
	return Vector2(ox, oy)

func _make_card_rect(type: String, darken: bool) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Card.SIZE
	root.size = Card.SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ColorRect.new()
	rect.color = CardTypeRegistry.color(type)
	rect.position = Vector2.ZERO
	rect.size = Card.SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rect)
	var label := UiHelpers.symbol_label(CardTypeRegistry.symbol(type), 18)
	label.position = Vector2.ZERO
	label.size = Card.SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	if darken:
		root.modulate = Color(0.42, 0.42, 0.42)
	return root

func _make_card_button(card: Card, darken: bool, on_click: Callable) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Card.SIZE
	btn.add_child(_make_card_rect(card.type, darken))
	btn.pressed.connect(on_click)
	return btn

func _make_card_display(type: String) -> Control:
	return _make_card_rect(type, false)

func _update_deck_button(btn: Button, deck: DeckManager, deck_id: String) -> void:
	if deck.is_empty():
		btn.text = "Deck %s\n—" % deck_id.to_upper()
		btn.disabled = true
	else:
		var sym: String = CardTypeRegistry.symbol(deck.current_type())
		btn.text = "Deck %s\n%s ×%d" % [deck_id.to_upper(), sym, deck.remaining_count()]
		btn.disabled = false

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
