extends Control

const CARD_DISPLAY_SIZE := Card.DISPLAY_SIZE
const RESERVE_COLUMNS := 2
const WARM_BACKGROUND := Color("#c78454")
const PANEL_BACKGROUND := Color(0.16, 0.10, 0.08, 0.78)
const PANEL_BORDER := Color("#f3d28d")
const TEXT_PRIMARY := Color("#fff1d2")
const TEXT_MUTED := Color("#f0c98e")
const INK := Color("#3a2410")
const GOLD := Color("#ffe36e")
# The Clearing Zone is the warm, highlighted bar of the screen.
const ZONE_BAR := Color("#e98a35")
const ZONE_BAR_BORDER := Color("#ffd18a")
const BOARD_CARD_SCALE := 1.0
const BOARD_X_COMPRESSION := 1.0
const BOARD_Y_COMPRESSION := 1.0
const PORTRAIT_BOARD_FRAME := Vector2(344.0, 272.0)
# Landscape (640x360): HUD row on top, then [Ace + Reserve | board, decks, zone | powers].
const LANDSCAPE_BOARD_FRAME := Vector2(478.0, 222.0)
const LANDSCAPE_SIDE_WIDTH := 84.0
const LANDSCAPE_POWERS_WIDTH := 62.0
const HUD_CENTER_WIDTH := 84.0
const LANDSCAPE_ZONE_CARD_SIZE := Vector2(32.0, 32.0)
# 7 slots + 6 gaps of 3 px must fit the 328 px zone row in one line.
const PORTRAIT_ZONE_CARD_SIZE := Vector2(44.0, 44.0)
const LANDSCAPE_RESERVE_CARD_SIZE := Vector2(30.0, 30.0)
const PORTRAIT_RESERVE_CARD_SIZE := Vector2(40.0, 40.0)
const LANDSCAPE_DECK_CARD_SIZE := Vector2(34.0, 34.0)
const PORTRAIT_DECK_CARD_SIZE := Vector2(46.0, 46.0)
# A Support Deck is a pile: one face-up card plus up to PILE_MAX_EDGES card edges.
const PILE_EDGE_STEP := 3.0
const PILE_MAX_EDGES := 6
const POWER_ICON_LANDSCAPE := 32.0
const POWER_ICON_PORTRAIT := 36.0
const MASCOT_SCALE_LANDSCAPE := 1.4
const MASCOT_SCALE_PORTRAIT := 1.2
const INSTRUCTION_SECONDS := 4.0
# Card moves are applied to the controller the instant they are tapped; these timings only
# drive the overlay visuals (flying ghost, match flash) that catch up with the state.
const FLIGHT_SECONDS := 0.2
const FLIGHT_TILT := 0.07
const FLIGHT_START_SCALE := 1.08
const MATCH_FADE_SECONDS := 0.25
const MATCH_FLASH_SECONDS := 0.45
# The end panel waits for in-flight visuals, but never longer than this.
const END_WAIT_MAX_MSEC := 1200
# Blocked cards darken with their depth under reachable cards: 1 = directly under an
# available card, 2 = under a blocked card, 3+ = deeper still. Index 0 (available) is untouched.
const DEPTH_BRIGHTNESS := [1.0, 0.45, 0.32, 0.22]
const DEPTH_SATURATION := [1.0, 0.80, 0.68, 0.58]
const DIM_SHADER_CODE := """
shader_type canvas_item;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
void fragment() {
	float grey = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(vec3(grey), COLOR.rgb, saturation) * brightness;
}
"""

static var _dim_shader: Shader
static var _dim_materials := {}

# The three cards of one match, flashed together once the last of them has landed.
class MatchGroup extends RefCounted:
	var pending := 0
	var nodes: Array = []
	var rects: Array = []

# One card in the air: its ghost node and where it is heading.
class Flight extends RefCounted:
	var card_id := ""
	var ghost: Control
	var target := Rect2()
	# The ghost re-bases its path from where it is when the target slot moves under it.
	var origin_pos := Vector2.ZERO
	var origin_scale := Vector2.ONE
	var origin_progress := 0.0
	var last_progress := 0.0
	var group: MatchGroup
	var warn := false

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
var score_label: Label
var level_label: Label
var zone_header: Label
var _board_panel: PanelContainer
var _mascot_area: Control
var _instruction_bubble: PanelContainer
var _is_landscape := true
var _ended := false
var _help_shown := false
var _live_star_count := -1
var _level_id: String = ""
var _sfx_player: AudioStreamPlayer
var _card_size: float = 48.0
var _fits_landscape := true
var _scale_limited := false
var _layout_warning: Label
var mascot: Mascot
# Overlay layer for everything that animates a move (ghosts, flashes, bursts). It never
# takes input; it is empty exactly when the visuals have caught up with the controller.
var _fx_layer: Control
# Cards still flying toward the zone, by card id; their zone slot stays hidden until they land.
var _flights: Dictionary = {}
var _hidden_cards: Dictionary = {}
var _end_wait_started_msec := -1
var _layout_cache: Dictionary = {}
var _layout_cache_size := Vector2.ZERO
# Matches whose flash has played (the rapid-tap smoke asserts on it).
var match_flashes := 0
# The Endless run being played, or null for a campaign Level.
var _endless: EndlessRun

func _ready() -> void:
	_level_id = Game.current_level_id
	_endless = Game.endless_run
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
	var level: Dictionary
	if _endless != null:
		level = _endless.build_round_level(board_size)
	else:
		level = LevelLoader.load_level(_level_id, board_size)
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
	# Endless rounds draw on the run's own power stock, never the persistent Inventory.
	controller.start_level(level, _endless.power_stock if _endless != null else Game.progress.inventory)
	render()
	_play_intro()

func _notification(what: int) -> void:
	match what:
		# Closing the app (or the Android back gesture) mid-run still counts: record
		# the best score. Pausing (APPLICATION_PAUSED) only stops the clock below.
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			if _endless != null and not _endless.is_over:
				_finish_endless_run()
			return
	if controller == null:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			controller.pause()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if not _help_shown:
				controller.resume()

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
	# The rebuild frees the help overlay too, so undo the pause it applied.
	if _help_shown and controller != null:
		controller.resume()
	_help_shown = false
	power_buttons.clear()
	_mascot_area = null
	_instruction_bubble = null
	# The rebuild frees every child, ghosts included; render() re-syncs the zone afterwards.
	_fx_layer = null
	_flights.clear()
	_hidden_cards.clear()
	_layout_cache = {}
	for child in get_children():
		remove_child(child)
		child.queue_free()
	# Any node held across rebuilds is gone now.
	_sfx_player = null
	_layout_warning = null

	var bg := ColorRect.new()
	bg.color = WARM_BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(_make_background_glow())

	var edge := 4 if _is_landscape else 6
	var margin := MarginContainer.new()
	margin.name = "ScreenMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Portrait keeps 8 px at the sides so the board area stays the 332 px reference width.
	var side := 4 if _is_landscape else 8
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_top", edge)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_bottom", edge)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3 if _is_landscape else 10)
	margin.add_child(vbox)

	vbox.add_child(_build_hud())
	if _is_landscape:
		var body := HBoxContainer.new()
		body.name = "Body"
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 4)
		vbox.add_child(body)
		body.add_child(_build_side_column())
		body.add_child(_build_main_column())
		var powers := _build_controls()
		powers.custom_minimum_size = Vector2(LANDSCAPE_POWERS_WIDTH, 0)
		powers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body.add_child(powers)
	else:
		vbox.add_child(_build_main_column())
	_build_mascot()
	_fx()

# A soft vertical glow over the flat warm background (darker top, lighter bottom).
func _make_background_glow() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(0.40, 0.18, 0.06, 0.30), Color(1.0, 0.66, 0.28, 0.0), Color(1.0, 0.72, 0.32, 0.32)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 128
	var glow := TextureRect.new()
	glow.texture = texture
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glow

# Ace lives in the free space of the layout (MascotArea): the left column in landscape,
# the middle of the deck row in portrait. It is a direct child of the screen (outside
# ScreenMargin), so it never takes layout space.
func _build_mascot() -> void:
	mascot = null
	if not Game.mascot_enabled():
		return
	mascot = Mascot.new()
	mascot.name = "Mascot"
	mascot.z_index = 600
	mascot.visible = false  # shown by _place_mascot once the layout is known
	if _endless != null:
		mascot.idle_event = "idle_tip_endless"
	add_child(mascot)

func _place_mascot() -> void:
	if mascot == null or _mascot_area == null:
		return
	var area := _mascot_area.get_global_rect()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	mascot.size = Mascot.BASE_SIZE * (MASCOT_SCALE_LANDSCAPE if _is_landscape else MASCOT_SCALE_PORTRAIT)
	if _is_landscape:
		# Left column: Ace in the upper-middle, its bubble in the free band above it.
		mascot.global_position = Vector2(
			area.get_center().x - mascot.size.x * 0.5,
			area.position.y + area.size.y * 0.46
		)
		mascot.side_bubble_bounds = Rect2()
		mascot.free_bounds = Rect2(area.position, Vector2(area.size.x, maxf(0.0, mascot.global_position.y - 4.0 - area.position.y)))
	else:
		# Deck row: Ace beside deck A, its bubble to the right inside the row's free middle.
		mascot.global_position = Vector2(area.position.x + 2.0, area.get_center().y - mascot.size.y * 0.5)
		mascot.free_bounds = Rect2()
		var left := mascot.global_position.x + mascot.size.x
		mascot.side_bubble_bounds = Rect2(left, area.position.y, area.end.x - left, area.size.y)
	mascot.visible = not _ended

func _say(event: String, context: Dictionary = {}) -> void:
	if mascot != null and not _ended:
		mascot.say(event, context)

# The how-to-play line shown at the start of a Level or Round: Ace says it in its bubble;
# with the mascot turned off a standalone bubble in the same free area shows it instead.
# Both go away by themselves after INSTRUCTION_SECONDS, so the board is never covered.
func _say_instruction() -> void:
	if _ended:
		return
	var text := Localizer.t("instruction")
	if mascot != null:
		mascot.say_text(text, INSTRUCTION_SECONDS, "instruction")
	else:
		_show_instruction_bubble(text)

func _show_instruction_bubble(text: String) -> void:
	if _mascot_area == null or _ended:
		return
	var area := _mascot_area.get_global_rect()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	if _instruction_bubble != null and is_instance_valid(_instruction_bubble):
		_instruction_bubble.queue_free()
	var bubble := PanelContainer.new()
	bubble.name = "InstructionBubble"
	bubble.z_index = 600
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Mascot.CARD_FACE
	style.border_color = Mascot.INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.anti_aliasing = true
	bubble.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Mascot.BUBBLE_FONT_SIZE)
	label.add_theme_color_override("font_color", Mascot.INK)
	label.custom_minimum_size = Vector2(minf(Mascot.BUBBLE_TEXT_MAX_WIDTH, area.size.x - 14.0), 0.0)
	bubble.add_child(label)
	bubble.modulate.a = 0.0
	add_child(bubble)
	_instruction_bubble = bubble
	# Autowrap settles its height over a couple of frames; place the bubble afterwards.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(bubble) or _ended:
		return
	bubble.reset_size()
	var target := Vector2(area.get_center().x - bubble.size.x * 0.5, area.get_center().y - bubble.size.y * 0.5)
	if _is_landscape:
		target.y = area.position.y + area.size.y * 0.46 - bubble.size.y - 4.0
	bubble.global_position = Vector2(
		clampf(target.x, area.position.x, maxf(area.position.x, area.end.x - bubble.size.x)),
		clampf(target.y, area.position.y, maxf(area.position.y, area.end.y - bubble.size.y))
	)
	bubble.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_interval(INSTRUCTION_SECONDS - 0.3)
	fade.tween_property(bubble, "modulate:a", 0.0, 0.3)
	fade.tween_callback(bubble.queue_free)

func _build_hud() -> PanelContainer:
	var panel := _make_unframed_panel(2, 2)
	panel.name = "Hud"
	panel.custom_minimum_size = Vector2(0, 34 if _is_landscape else 44)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	# The Endless label ("Endless · Round 12") is wider than "Level 6": on the 360 px
	# portrait HUD it only fits with a smaller font and button.
	var compact := _endless != null and not _is_landscape
	var left := HBoxContainer.new()
	left.name = "HudLeft"
	left.add_theme_constant_override("separation", 3 if compact else 5)
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(left)

	var back := _make_round_button("<", 26 if compact else 28, 16)
	back.pressed.connect(_on_back)
	left.add_child(back)

	level_label = Label.new()
	if _endless != null:
		level_label.text = Localizer.t("endless_round") % _endless.current_round
	else:
		level_label.text = "%s %s" % [Localizer.t("level"), _level_id]
	level_label.add_theme_font_size_override("font_size", 11 if compact else 14)
	level_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_child(level_label)

	var help := _make_round_button("?", 24, 14)
	help.pressed.connect(_on_help)

	row.add_child(_build_hud_center())

	var right := HBoxContainer.new()
	right.name = "HudRight"
	right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)

	if _is_landscape:
		# "?" sits next to the title. The clock cluster is centred over the board column
		# (the side columns differ in width), so the left section has a fixed width.
		left.add_child(help)
		var center_x := get_viewport_rect().size.x * 0.5 + (LANDSCAPE_SIDE_WIDTH - LANDSCAPE_POWERS_WIDTH) * 0.5
		left.custom_minimum_size = Vector2(center_x - HUD_CENTER_WIDTH * 0.5 - 6.0, 0.0)
	else:
		# Portrait: equal left/right sections keep the clock exactly centred.
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 1.0
		right.size_flags_stretch_ratio = 1.0
		right.add_child(help)
	return panel

# Clock pill with the live stars right below it (Endless: the run score instead of stars).
func _build_hud_center() -> VBoxContainer:
	var center := VBoxContainer.new()
	center.name = "HudCenter"
	center.custom_minimum_size = Vector2(HUD_CENTER_WIDTH, 0)
	center.add_theme_constant_override("separation", 0 if _is_landscape else 2)

	var clock_pill := _make_hud_pill(10)
	clock_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	timer_label = Label.new()
	timer_label.text = "00:00"
	timer_label.add_theme_font_size_override("font_size", 12 if _is_landscape else 14)
	timer_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.custom_minimum_size = Vector2(54, 17 if _is_landscape else 20)
	clock_pill.add_child(timer_label)
	center.add_child(clock_pill)

	if _endless != null:
		stars_label = null
		var score_pill := _make_hud_pill(8)
		score_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		score_label = UiHelpers.symbol_label(_score_text(), 12)
		score_label.add_theme_color_override("font_color", GOLD)
		score_label.custom_minimum_size = Vector2(48, 16 if _is_landscape else 18)
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_pill.add_child(score_label)
		center.add_child(score_pill)
	else:
		score_label = null
		stars_label = UiHelpers.symbol_label("☆☆☆", 13 if _is_landscape else 17)
		stars_label.add_theme_color_override("font_color", GOLD)
		stars_label.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.04, 0.9))
		stars_label.add_theme_constant_override("outline_size", 3)
		stars_label.custom_minimum_size = Vector2(0, 16 if _is_landscape else 20)
		stars_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stars_label.pivot_offset = Vector2(HUD_CENTER_WIDTH * 0.5, 9.0)
		center.add_child(stars_label)
	return center

func _make_round_button(text: String, diameter: float, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", TEXT_MUTED)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = PANEL_BACKGROUND
		if state == "hover":
			style.bg_color = PANEL_BACKGROUND.lightened(0.14)
		elif state == "pressed":
			style.bg_color = PANEL_BACKGROUND.darkened(0.2)
		style.border_color = PANEL_BORDER
		style.set_border_width_all(2)
		style.set_corner_radius_all(int(diameter * 0.5))
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		button.add_theme_stylebox_override(state, style)
	return button

func _make_flat_button_compact(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)

func _make_hud_pill(h_padding: int = 12) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.15, 0.06, 0.55)
	style.border_color = Color(1.0, 0.85, 0.55, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = h_padding
	style.content_margin_right = h_padding
	style.content_margin_top = 0 if _is_landscape else 1
	style.content_margin_bottom = 0 if _is_landscape else 1
	pill.add_theme_stylebox_override("panel", style)
	return pill

# Landscape left column: Ace's free space on top, the Reserve box at the bottom.
func _build_side_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = "SideColumn"
	col.custom_minimum_size = Vector2(LANDSCAPE_SIDE_WIDTH, 0)
	col.add_theme_constant_override("separation", 4)
	_mascot_area = Control.new()
	_mascot_area.name = "MascotArea"
	_mascot_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mascot_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_mascot_area)
	col.add_child(_build_reserve_panel())
	return col

func _build_main_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = "MainColumn"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3 if _is_landscape else 14)

	var board_panel := _make_panel(Color(0.19, 0.12, 0.09, 0.22), Color(1, 0.88, 0.60, 0.32), 12)
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
	col.add_child(board_panel)

	col.add_child(_build_support_panel())
	col.add_child(_build_zone_panel())
	if not _is_landscape:
		# Portrait bottom row: Reserve box on the left, power panel on the right.
		var bottom := HBoxContainer.new()
		bottom.name = "BottomRow"
		bottom.add_theme_constant_override("separation", 6)
		var reserve := _build_reserve_panel()
		reserve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom.add_child(reserve)
		var powers := _build_controls()
		powers.size_flags_horizontal = Control.SIZE_SHRINK_END
		bottom.add_child(powers)
		col.add_child(bottom)
	return col

# The two Support Decks as piles right under the board: deck A under its left part with
# its edges fanning left, deck B under the right part with its edges fanning right.
func _build_support_panel() -> PanelContainer:
	var panel := _make_unframed_panel(2, 12 if _is_landscape else 8)
	panel.name = "Support"
	panel.custom_minimum_size = Vector2(0, (LANDSCAPE_DECK_CARD_SIZE.y if _is_landscape else PORTRAIT_DECK_CARD_SIZE.y + 16.0) + 4.0)
	var deck_row := HBoxContainer.new()
	deck_row.add_theme_constant_override("separation", 4)
	panel.add_child(deck_row)
	deck_a_btn = _make_deck_button("a")
	deck_b_btn = _make_deck_button("b")
	deck_row.add_child(deck_a_btn)
	var middle := Control.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _is_landscape:
		middle.name = "MascotArea"
		_mascot_area = middle
	deck_row.add_child(middle)
	deck_row.add_child(deck_b_btn)
	return panel

func _build_reserve_panel() -> PanelContainer:
	var reserve_panel := _make_panel(PANEL_BACKGROUND, PANEL_BORDER, 10)
	reserve_panel.name = "Reserve"
	reserve_panel.custom_minimum_size = Vector2(LANDSCAPE_SIDE_WIDTH if _is_landscape else 130.0, 66 if _is_landscape else 96)
	var reserve_col := VBoxContainer.new()
	reserve_col.add_theme_constant_override("separation", 2)
	reserve_panel.add_child(reserve_col)
	reserve_header = Label.new()
	reserve_header.add_theme_font_size_override("font_size", 8)
	reserve_header.add_theme_color_override("font_color", TEXT_MUTED)
	reserve_col.add_child(reserve_header)
	reserve_container = Control.new()
	reserve_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reserve_container.custom_minimum_size = Vector2(0, LANDSCAPE_RESERVE_CARD_SIZE.y if _is_landscape else 48)
	reserve_container.clip_contents = true
	reserve_col.add_child(reserve_container)
	return reserve_panel

# The Clearing Zone: a warm orange bar with 7 slots in one row.
func _build_zone_panel() -> PanelContainer:
	var zone_panel := PanelContainer.new()
	zone_panel.name = "ClearingZone"
	var style := StyleBoxFlat.new()
	style.bg_color = ZONE_BAR
	style.border_color = ZONE_BAR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(1.0, 0.55, 0.15, 0.45)
	style.shadow_size = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	zone_panel.add_theme_stylebox_override("panel", style)
	zone_panel.custom_minimum_size = Vector2(0, 40 if _is_landscape else 66)
	zone_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: BoxContainer = HBoxContainer.new() if _is_landscape else VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4 if _is_landscape else 1)
	zone_panel.add_child(inner)
	zone_header = Label.new()
	zone_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_header.add_theme_font_size_override("font_size", 8)
	zone_header.add_theme_color_override("font_color", INK)
	zone_container = HFlowContainer.new()
	zone_container.alignment = FlowContainer.ALIGNMENT_CENTER
	zone_container.custom_minimum_size = _zone_card_size()
	zone_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_container.add_theme_constant_override("h_separation", 4 if _is_landscape else 3)
	zone_container.add_theme_constant_override("v_separation", 3)
	inner.add_child(zone_header)
	inner.add_child(zone_container)
	if _is_landscape:
		# Title on the left, an equal spacer on the right: the slots stay centred under the board.
		zone_header.custom_minimum_size = Vector2(64, 0)
		var balance := Control.new()
		balance.custom_minimum_size = Vector2(64, 0)
		balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(balance)
	return zone_panel

# The rounded power panel: landscape stacks the powers vertically on the right of the
# board, portrait lays them out in a row next to the Reserve.
func _build_controls() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Powers"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.80, 0.52, 0.20)
	style.border_color = Color(1.0, 0.88, 0.62, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	var box: BoxContainer = VBoxContainer.new() if _is_landscape else HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6 if _is_landscape else 4)
	panel.add_child(box)
	for p in PowerManager.POWERS:
		box.add_child(_make_power_button(p))
	return panel

# One power: its name above, a round icon, and a small badge with the stock ("xN").
func _make_power_button(p: String) -> Button:
	var icon_size := POWER_ICON_LANDSCAPE if _is_landscape else POWER_ICON_PORTRAIT
	var holder_width := icon_size + 16.0
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(holder_width + 2.0, icon_size + 16.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = _power_name(p)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.10)
	hover.set_corner_radius_all(8)
	for state in ["normal", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", hover)
	# Press, not release: a tap counts the moment it lands, even if render() rebuilds under it.
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.pressed.connect(_on_power.bind(p))
	power_buttons[p] = btn
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = _power_name(p)
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_lbl)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(holder_width, icon_size)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	var circle := Panel.new()
	circle.position = Vector2(8.0, 0.0)
	circle.size = Vector2(icon_size, icon_size)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circle_style := StyleBoxFlat.new()
	circle_style.bg_color = Color(0.19, 0.11, 0.07, 0.62)
	circle_style.border_color = Color(1.0, 0.88, 0.62, 0.70)
	circle_style.set_border_width_all(2)
	circle_style.set_corner_radius_all(int(icon_size * 0.5))
	circle.add_theme_stylebox_override("panel", circle_style)
	holder.add_child(circle)
	var icon := Label.new()
	icon.text = _power_icon(p)
	icon.add_theme_font_override("font", UiHelpers.symbol_font())
	icon.add_theme_font_size_override("font_size", int(icon_size * 0.5))
	icon.position = circle.position
	icon.size = circle.size
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	var badge := Panel.new()
	badge.size = Vector2(22.0, 13.0)
	badge.position = Vector2(holder_width - badge.size.x, icon_size - badge.size.y)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = INK
	badge_style.border_color = GOLD
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(7)
	badge.add_theme_stylebox_override("panel", badge_style)
	holder.add_child(badge)
	var count_lbl := Label.new()
	count_lbl.text = "x0"
	count_lbl.add_theme_font_size_override("font_size", 9)
	count_lbl.add_theme_color_override("font_color", GOLD)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(count_lbl)
	btn.set_meta("count_label", count_lbl)
	return btn

func _make_deck_button(deck_id: String) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = _deck_pile_size()
	btn.tooltip_text = "%s %s" % [Localizer.t("support_deck"), deck_id.to_upper()]
	_make_flat_button_compact(btn)
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.pressed.connect(_on_deck.bind(deck_id))
	return btn

func _deck_card_size() -> Vector2:
	return LANDSCAPE_DECK_CARD_SIZE if _is_landscape else PORTRAIT_DECK_CARD_SIZE

# The button covers the face card plus the room the pile's edges can take.
func _deck_pile_size() -> Vector2:
	var card := _deck_card_size()
	return Vector2(card.x + PILE_MAX_EDGES * PILE_EDGE_STEP, card.y)

func render() -> void:
	_clear(board_container)
	_clear(zone_container)
	_clear(reserve_container)

	var layout := _board_layout()
	_layout_cache = layout
	_layout_cache_size = board_container.size
	var offset: Vector2 = layout["offset"]
	var scale: float = layout["scale"]
	var origin: Vector2 = layout["origin"]
	var position_scale: Vector2 = layout["position_scale"]
	var grid_positions: Dictionary = layout["grid_positions"]
	var card_size: Vector2 = CARD_DISPLAY_SIZE * scale * BOARD_CARD_SCALE
	_show_layout_warning_if_needed()

	var depths := _blocked_depths()
	var board_cards: Array = controller.board.cards.duplicate()
	board_cards.sort_custom(func(a, b): return a.layer < b.layer)
	for card in board_cards:
		if card.is_removed() or card.location != Card.Location.BOARD:
			continue
		var node := _make_card_button(card, int(depths.get(card.id, 0)), _on_card.bind(card.id), card_size, true)
		var visual_position: Vector2 = grid_positions.get(card.id, Vector2(
			(card.position.x - origin.x) * position_scale.x,
			(card.position.y - origin.y) * position_scale.y
		))
		node.position = _board_node_position(layout, visual_position)
		node.z_index = card.layer
		board_container.add_child(node)

	if _is_landscape:
		zone_header.text = "%s\n%d/%d" % [Localizer.t("clearing_zone"), controller.zone.size(), controller.clearing_capacity]
	else:
		zone_header.text = "%s  %d/%d" % [Localizer.t("clearing_zone"), controller.zone.size(), controller.clearing_capacity]
	var zone_card_size := _zone_card_size()
	for i in controller.clearing_capacity:
		if i < controller.zone.cards.size():
			var zone_card: Card = controller.zone.cards[i]
			var display := _make_card_display(zone_card.type, zone_card_size)
			# A card still flying in shows up in its slot only when its ghost lands.
			if _hidden_cards.has(zone_card.id):
				display.modulate = Color(1, 1, 1, 0)
			zone_container.add_child(display)
		else:
			zone_container.add_child(_make_empty_slot(zone_card_size, true))
	# Slot rects are read right after a move, in the same frame: lay the slots out now.
	zone_container.notification(Container.NOTIFICATION_SORT_CHILDREN)

	reserve_header.text = "%s  %d" % [Localizer.t("reserve"), controller.reserve.size()]
	var reserve_size := _reserve_card_size()
	var reserve_step := _reserve_card_step(reserve_size)
	var reserve_column_width := reserve_container.size.x / float(RESERVE_COLUMNS)
	for i in controller.reserve.size():
		var card: Card = controller.reserve[i]
		var node: Control
		if i == controller.reserve.size() - 1:
			node = _make_card_button(card, 0, _on_reserve_return.bind(card.id), reserve_size)
		else:
			node = _make_card_rect(card.type, 0, reserve_size)
		var column := i % RESERVE_COLUMNS
		var row := floori(float(i) / float(RESERVE_COLUMNS))
		node.position = Vector2(
			column * reserve_column_width + (reserve_column_width - reserve_size.x) / 2.0,
			row * reserve_step
		)
		node.z_index = i
		reserve_container.add_child(node)

	_update_deck_button(deck_a_btn, controller.deck_a, true)
	_update_deck_button(deck_b_btn, controller.deck_b, false)

	for p in PowerManager.POWERS:
		var btn: Button = power_buttons[p]
		var count: int = controller.powers.get_count(p)
		var count_lbl: Label = btn.get_meta("count_label")
		count_lbl.text = "x%d" % count
		btn.disabled = count <= 0
		btn.modulate = Color(1, 1, 1, 0.55) if count <= 0 else Color.WHITE
	_refresh_score()
	_place_mascot()

func _clear(c: Node) -> void:
	for child in c.get_children():
		c.remove_child(child)
		child.queue_free()

# Depth of every board card under the cards that cover it: 0 = reachable, 1 = covered only
# by reachable cards, 2 = covered by a depth-1 card, and so on. Cards are visited from the
# top layer down, so a card's blockers already have their depth when it is reached.
func _blocked_depths() -> Dictionary:
	var cards: Array = []
	for c in controller.board.cards:
		if c.location == Card.Location.BOARD and not c.is_removed():
			cards.append(c)
	cards.sort_custom(func(a, b): return a.layer > b.layer)
	var depths := {}
	for card in cards:
		if card.state == Card.State.AVAILABLE:
			depths[card.id] = 0
			continue
		var depth := 1
		for other in cards:
			if other.layer <= card.layer or not depths.has(other.id):
				continue
			if BoardSpatialRules.blocks_with_layers(card.get_display_rect(), other.get_display_rect(), card.layer, other.layer):
				depth = maxi(depth, int(depths[other.id]) + 1)
		depths[card.id] = depth
	return depths

func _reserve_max_card_size() -> Vector2:
	return LANDSCAPE_RESERVE_CARD_SIZE if _is_landscape else PORTRAIT_RESERVE_CARD_SIZE

func _reserve_card_size() -> Vector2:
	var count := controller.reserve.size()
	var max_card_size := _reserve_max_card_size().y
	if count <= 0:
		return _reserve_max_card_size()
	var available_height := maxf(max_card_size, reserve_container.size.y)
	var tab := 6.0
	var rows := ceili(float(count) / float(RESERVE_COLUMNS))
	var side := minf(max_card_size, maxf(28.0, available_height - tab * maxi(0, rows - 1)))
	var available_width := maxf(28.0, reserve_container.size.x / float(RESERVE_COLUMNS) - 2.0)
	side = minf(side, available_width)
	return Vector2(side, side)

func _zone_card_size() -> Vector2:
	return LANDSCAPE_ZONE_CARD_SIZE if _is_landscape else PORTRAIT_ZONE_CARD_SIZE

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
	# Cards are drawn exactly where the generator put them (no per-layer visual offset).
	var visual_positions: Array = []
	for c in controller.board.cards:
		if c.source != Card.Source.BOARD:
			continue
		visual_positions.append(c.position)
	if visual_positions.is_empty():
		return {"offset": Vector2.ZERO, "scale": 1.0, "origin": Vector2.ZERO, "position_scale": Vector2.ONE, "grid_positions": {}}
	# Single source of scale: logical positions are mapped to the container by
	# BoardLayout.compute with a uniform scale. Positions are NOT snapped to a
	# fixed pitch — snapping scaled positions collapses distinct slots. The
	# scale never goes below LevelConfig.MIN_CARD_SCALE; if the container is too
	# small the layout is flagged (scale_limited) and surfaced as a warning.
	var card := _card_size * BOARD_CARD_SCALE
	var fit := BoardLayout.compute(visual_positions, board_container.size, card, LevelConfig.MIN_CARD_SCALE)
	_scale_limited = bool(fit["scale_limited"])
	# Boards are wide with many small cards: a board card is never drawn larger than
	# LevelConfig.MAX_BOARD_CARD_PX. Small boards keep that size and are re-centered.
	var max_scale := LevelConfig.MAX_BOARD_CARD_PX / maxf(1.0, CARD_DISPLAY_SIZE.y * BOARD_CARD_SCALE)
	if float(fit["scale"]) > max_scale:
		fit["scale"] = max_scale
		fit["offset"] = Vector2(
			maxf(0.0, (board_container.size.x - (float(fit["span_x"]) + card) * max_scale) / 2.0),
			maxf(0.0, (board_container.size.y - (float(fit["span_y"]) + card) * max_scale) / 2.0)
		)
	var position_scale := Vector2(BOARD_X_COMPRESSION, BOARD_Y_COMPRESSION)
	var grid_positions := {}
	for c in controller.board.cards:
		if c.source != Card.Source.BOARD:
			continue
		grid_positions[c.id] = Vector2(
			(c.position.x - fit["origin"].x) * position_scale.x,
			(c.position.y - fit["origin"].y) * position_scale.y
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

# `depth` > 0 marks a blocked board card: it is dimmed by the DEPTH_* tables (see
# _dim_material). `shadow` adds the soft drop shadow board cards use so stacked layers read.
func _make_card_rect(type: String, depth: int, card_size: Vector2, shadow: bool = false) -> Control:
	var root := Panel.new()
	root.custom_minimum_size = card_size
	root.size = card_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = CardTypeRegistry.color(type)
	card_style.border_color = Color("#fff2d5")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(5)
	if shadow:
		card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
		card_style.shadow_size = 3
		card_style.shadow_offset = Vector2(0.0, 2.0)
	root.add_theme_stylebox_override("panel", card_style)
	var art := _make_card_art(type, card_size)
	root.add_child(art)
	if depth > 0:
		root.material = _dim_material(depth)
		art.use_parent_material = true
	return root

# One shared material per depth: brightness and saturation come from the DEPTH_* tables.
func _dim_material(depth: int) -> ShaderMaterial:
	var index := clampi(depth, 0, DEPTH_BRIGHTNESS.size() - 1)
	if not _dim_materials.has(index):
		if _dim_shader == null:
			_dim_shader = Shader.new()
			_dim_shader.code = DIM_SHADER_CODE
		var material := ShaderMaterial.new()
		material.shader = _dim_shader
		material.set_shader_parameter("brightness", float(DEPTH_BRIGHTNESS[index]))
		material.set_shader_parameter("saturation", float(DEPTH_SATURATION[index]))
		_dim_materials[index] = material
	return _dim_materials[index]

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

func _make_card_button(card: Card, depth: int, on_click: Callable, card_size: Vector2, shadow: bool = false) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = card_size
	btn.size = card_size
	btn.disabled = depth > 0
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_child(_make_card_rect(card.type, depth, card_size, shadow))
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.pressed.connect(on_click)
	return btn

func _make_card_display(type: String, card_size: Vector2) -> Control:
	return _make_card_rect(type, 0, card_size)

# `on_zone` styles the slot for the orange Clearing Zone bar; otherwise it is the dark
# placeholder (empty deck).
func _make_empty_slot(card_size: Vector2, on_zone: bool = false) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = card_size
	slot.size = card_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	if on_zone:
		style.bg_color = Color(0.48, 0.22, 0.05, 0.34)
		style.border_color = Color(1.0, 0.86, 0.58, 0.55)
	else:
		style.bg_color = Color(0.12, 0.08, 0.06, 0.28)
		style.border_color = Color(1, 0.87, 0.62, 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("panel", style)
	return slot

# Number of visible card edges: the pile's thickness follows its share of the deck left.
func _pile_edges(deck: DeckManager) -> int:
	var remaining := deck.remaining_count()
	if remaining <= 1:
		return 0
	var total := maxi(deck.card_types.size(), 2)
	return clampi(roundi(float(PILE_MAX_EDGES) * float(remaining - 1) / float(total - 1)), 1, PILE_MAX_EDGES)

func _make_pile_edge(card_size: Vector2, shade: float) -> Control:
	var edge := Panel.new()
	edge.size = card_size
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#6a4b3a").darkened(shade)
	style.border_color = Color("#2b1a12")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	edge.add_theme_stylebox_override("panel", style)
	return edge

# Draws a deck as a pile: card edges stacked behind a face-up top card, fanning to the
# left (deck A) or to the right (deck B). The pile fades away once the deck is empty.
func _update_deck_button(btn: Button, deck: DeckManager, edges_left: bool) -> void:
	_clear(btn)
	var card_size := _deck_card_size()
	var pile_size := _deck_pile_size()
	btn.size = pile_size
	var face_rect := Rect2(Vector2(pile_size.x - card_size.x if edges_left else 0.0, 0.0), card_size)
	btn.set_meta("face_rect", face_rect)
	if deck.is_empty():
		btn.disabled = true
		var empty := _make_empty_slot(card_size)
		empty.position = face_rect.position
		btn.add_child(empty)
		btn.set_meta("face", empty)
		_fade_out_deck(btn)
		return
	btn.set_meta("faded", false)
	if btn.has_meta("fade_tween"):
		var fade: Tween = btn.get_meta("fade_tween")
		if fade != null and fade.is_valid():
			fade.kill()
		btn.remove_meta("fade_tween")
	btn.modulate = Color.WHITE
	btn.scale = Vector2.ONE
	btn.visible = true
	btn.disabled = false
	var edges := _pile_edges(deck)
	for i in range(edges, 0, -1):
		var edge := _make_pile_edge(card_size, 0.04 * float(i))
		edge.position = face_rect.position + Vector2((-1.0 if edges_left else 1.0) * float(i) * PILE_EDGE_STEP, 0.0)
		btn.add_child(edge)
	var face := _make_card_rect(deck.current_type(), 0, card_size, true)
	face.position = face_rect.position
	btn.add_child(face)
	btn.set_meta("face", face)
	var badge := Panel.new()
	badge.size = Vector2(16, 12)
	badge.position = face_rect.position + Vector2(card_size.x - badge.size.x - 2.0, 2.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0, 0, 0, 0.58)
	badge_style.set_corner_radius_all(5)
	badge.add_theme_stylebox_override("panel", badge_style)
	btn.add_child(badge)
	var cnt := Label.new()
	cnt.text = str(deck.remaining_count())
	cnt.set_anchors_preset(Control.PRESET_FULL_RECT)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cnt.add_theme_font_size_override("font_size", 9)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(cnt)

# Global rect of the pile's top card (where a drawn card takes off from).
func _deck_face_rect(btn: Button) -> Rect2:
	var local: Rect2 = btn.get_meta("face_rect", Rect2(Vector2.ZERO, btn.size))
	return Rect2(btn.get_global_rect().position + local.position, local.size)

func _fade_out_deck(btn: Button) -> void:
	if bool(btn.get_meta("faded", false)):
		return
	btn.set_meta("faded", true)
	var t := btn.create_tween()
	btn.set_meta("fade_tween", t)
	t.set_parallel(true)
	t.tween_property(btn, "modulate:a", 0.0, 0.3)
	t.tween_property(btn, "scale", Vector2(0.7, 0.7), 0.3)
	t.chain().tween_callback(func(): btn.visible = false)

func _make_unframed_panel(vertical_margin: float = 4.0, horizontal_margin: float = 6.0) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	style.content_margin_left = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_right = horizontal_margin
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
	if p in PowerManager.POWERS:
		return Localizer.t("power_" + p)
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
	if controller != null:
		controller.pause()
	if mascot != null:
		mascot.hide_bubble()
	var overlay := Control.new()
	overlay.name = "HelpOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 900
	add_child(overlay)
	# Tapping the shade also closes, so the overlay can never trap the player.
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_help()
	)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.theme = UiHelpers.warm_theme()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BACKGROUND.darkened(0.25)
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	# Width follows the viewport so the panel always fits, in both orientations.
	var viewport_size := get_viewport_rect().size
	var text_width := minf(400.0, viewport_size.x - 64.0)
	var txt := Label.new()
	txt.text = Localizer.t("help_text")
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(text_width, 0)
	txt.add_theme_font_size_override("font_size", 10 if _is_landscape else 11)
	txt.add_theme_color_override("font_color", TEXT_PRIMARY)
	col.add_child(txt)
	var close := Button.new()
	close.name = "HelpClose"
	close.text = Localizer.t("close")
	close.custom_minimum_size = Vector2(120, 32)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_help)
	col.add_child(close)

func _close_help() -> void:
	var overlay := get_node_or_null("HelpOverlay")
	if overlay == null:
		return
	overlay.name = "HelpOverlayClosing"
	overlay.queue_free()
	_help_shown = false
	if controller != null:
		controller.resume()

func _unhandled_input(event: InputEvent) -> void:
	if _help_shown and event.is_action_pressed("ui_cancel"):
		_close_help()
		get_viewport().set_input_as_handled()

# --- Moves --------------------------------------------------------------------------------
# A tap goes to the controller immediately, whatever is still animating: state is the source
# of truth and the visuals (ghost flights, match flash) catch up on top of it.

func _accepts_taps() -> bool:
	return controller != null and controller.status == GameController.Status.PLAYING

func _on_card(card_id: String) -> void:
	if not _accepts_taps():
		return
	var card := controller.board.get_card(card_id)
	if card == null:
		return
	var source_rect := _board_card_rect(card)
	var snap := _snapshot_zone()
	var result := controller.select_card(card_id)
	_apply_move(card.type, card_id, source_rect, snap, result)

func _on_deck(deck_id: String) -> void:
	if not _accepts_taps():
		return
	var deck: DeckManager = controller.deck_a if deck_id == "a" else controller.deck_b
	var card_type := deck.current_type()
	var source_rect := _deck_face_rect(deck_a_btn if deck_id == "a" else deck_b_btn)
	var snap := _snapshot_zone()
	var result := controller.use_deck(deck_id)
	_apply_move(card_type, "", source_rect, snap, result)

func _on_reserve_return(card_id: String) -> void:
	if not _accepts_taps():
		return
	var card := _reserve_card(card_id)
	if card == null:
		return
	var source_rect := _reserve_card_rect(card_id)
	var snap := _snapshot_zone()
	var result := controller.return_from_reserve(card_id)
	_apply_move(card.type, card_id, source_rect, snap, result)

# Redraws from the new state at once, then launches the visuals of the move. `card_id` is ""
# for a deck draw (the controller makes the card up). `snap` is the zone before the move.
func _apply_move(card_type: String, card_id: String, source_rect: Rect2, snap: Dictionary, result: Dictionary) -> void:
	if not bool(result["ok"]):
		_check_end()
		return
	_play_sfx("select")
	var matched: Array = result["matched_ids"]
	# Score right away: a winning move ends the round once its flash has played.
	_record_endless_match(matched.size())
	var snap_ids: Array = snap["ids"]
	var snap_rects: Array = snap["rects"]
	var target_index := snap_ids.size()
	if card_id == "":
		card_id = _drawn_card_id(snap_ids, matched, target_index)
	var target := _zone_slot_rect(snap_rects, target_index)
	var group: MatchGroup = null
	if not matched.is_empty():
		group = MatchGroup.new()
		for id in matched:
			var matched_id := str(id)
			if matched_id == card_id:
				continue
			if _flights.has(matched_id):
				# Still in the air: it keeps flying to the slot it was heading for and
				# joins the flash when it gets there.
				var flight: Flight = _flights[matched_id]
				flight.group = group
				flight.warn = false
				group.pending += 1
				_hidden_cards.erase(matched_id)
			else:
				var index := snap_ids.find(matched_id)
				if index >= 0:
					group.nodes.append(_spawn_card_overlay(snap["types"][index], snap_rects[index]))
					group.rects.append(snap_rects[index])
	else:
		_hidden_cards[card_id] = true
	render()
	var warn := matched.is_empty() and controller.zone.size() == controller.clearing_capacity - 1
	_launch_flight(card_id, card_type, source_rect, target, group, warn)
	_check_end()

# Id of the card a deck draw just put in the zone (it is gone again if it matched).
func _drawn_card_id(snap_ids: Array, matched: Array, target_index: int) -> String:
	if matched.is_empty():
		if target_index < controller.zone.cards.size():
			return controller.zone.cards[target_index].id
		return ""
	for id in matched:
		if not snap_ids.has(str(id)):
			return str(id)
	return ""

func _on_power(power: String) -> void:
	if not _accepts_taps():
		return
	_play_sfx("select")
	# Hold, Undo and Refresh move or remove zone cards: land the cards still flying in first,
	# so no ghost or hidden slot outlives the zone it was heading for.
	_cancel_zone_flights()
	var result: Dictionary = {}
	match power:
		"hold":
			result = controller.use_hold()
		"undo":
			result = controller.use_undo()
		"refresh":
			result = controller.use_refresh()
	if bool(result.get("ok", false)):
		# Campaign power stock is permanent: persist it now, not only on the end screen.
		# An Endless run's stock lives in memory and dies with the run.
		if _endless == null:
			Game.save_progress()
		_say("power_used")
	render()
	_check_end()

func _board_card_rect(card: Card) -> Rect2:
	# render() caches the layout of the board it drew; reuse it while the board has not resized.
	var layout := _layout_cache
	if layout.is_empty() or _layout_cache_size != board_container.size:
		layout = _board_layout()
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

# --- Move visuals -------------------------------------------------------------------------
# Everything below is an overlay in the FxLayer: it never changes state and never blocks a tap.
# Each node owns its tween (node.create_tween), so freeing a node (rebuild, scene reload)
# stops its animation with it, and no coroutine is left awaiting a freed node.

# True when no ghost, flash or burst is left on screen.
func visuals_settled() -> bool:
	if _fx_layer == null or not is_instance_valid(_fx_layer):
		return true
	for child in _fx_layer.get_children():
		if not child.is_queued_for_deletion():
			return false
	return true

func _fx() -> Control:
	if _fx_layer == null or not is_instance_valid(_fx_layer):
		_fx_layer = Control.new()
		_fx_layer.name = "FxLayer"
		_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_layer.z_index = 2000
		add_child(_fx_layer)
	return _fx_layer

func _drop_fx_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()

# Removes every overlay and re-syncs the zone (all slots visible).
func _clear_fx() -> void:
	if _fx_layer != null and is_instance_valid(_fx_layer):
		for child in _fx_layer.get_children():
			_drop_fx_node(child)
	_flights.clear()
	_hidden_cards.clear()
	if controller != null and zone_container != null:
		render()

# Cards flying to a slot are landed on the spot (ghost removed, slot shown). Cards that are
# part of a match keep flying: they sit outside the zone already and only feed the flash.
func _cancel_zone_flights() -> void:
	for id in _flights.keys():
		var flight: Flight = _flights[id]
		if flight.group != null:
			continue
		_flights.erase(id)
		_drop_fx_node(flight.ghost)
	_hidden_cards.clear()

func _launch_flight(card_id: String, card_type: String, source_rect: Rect2, target: Rect2, group: MatchGroup, warn: bool) -> void:
	var ghost_size := source_rect.size if source_rect.size.x > 0.0 else CARD_DISPLAY_SIZE
	var ghost := _make_card_rect(card_type, 0, ghost_size)
	_fx().add_child(ghost)
	ghost.global_position = source_rect.position
	ghost.rotation = FLIGHT_TILT
	ghost.scale = Vector2.ONE * FLIGHT_START_SCALE
	var flight := Flight.new()
	flight.card_id = card_id
	flight.ghost = ghost
	flight.target = target
	flight.origin_pos = source_rect.position
	flight.origin_scale = ghost.scale
	flight.group = group
	flight.warn = warn
	if group != null:
		group.pending += 1
	_flights[card_id] = flight
	var tween := ghost.create_tween()
	tween.tween_method(_step_flight.bind(flight), 0.0, 1.0, FLIGHT_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_land_flight.bind(flight))

# `progress` is the eased 0..1 of the flight. The target is read live, by card id, so a ghost
# follows its slot when a match elsewhere in the zone compacts the cards around it.
func _step_flight(progress: float, flight: Flight) -> void:
	var ghost := flight.ghost
	if ghost == null or not is_instance_valid(ghost):
		return
	var rect := _flight_target(flight)
	if not rect.is_equal_approx(flight.target):
		flight.origin_pos = ghost.global_position
		flight.origin_scale = ghost.scale
		flight.origin_progress = flight.last_progress
		flight.target = rect
	var k := clampf((progress - flight.origin_progress) / maxf(0.0001, 1.0 - flight.origin_progress), 0.0, 1.0)
	ghost.global_position = flight.origin_pos.lerp(rect.position, k)
	ghost.scale = flight.origin_scale.lerp(Vector2.ONE * (rect.size.x / maxf(1.0, ghost.size.x)), k)
	ghost.rotation = lerpf(FLIGHT_TILT, 0.0, progress)
	flight.last_progress = progress

# The slot the flying card occupies right now; a card that left the zone (matched away)
# keeps the last slot it was heading for.
func _flight_target(flight: Flight) -> Rect2:
	var index := _zone_index_of(flight.card_id)
	if index >= 0 and index < zone_container.get_child_count():
		return (zone_container.get_child(index) as Control).get_global_rect()
	return flight.target

func _land_flight(flight: Flight) -> void:
	if _flights.get(flight.card_id) == flight:
		_flights.erase(flight.card_id)
	_play_sfx("place")
	_play_card_impact(flight.target.get_center())
	if flight.group != null:
		var group: MatchGroup = flight.group
		group.nodes.append(flight.ghost)
		group.rects.append(flight.target)
		group.pending -= 1
		if group.pending <= 0:
			_play_match(group)
		return
	# Plain move: the ghost hands over to the real card in its slot.
	_hidden_cards.erase(flight.card_id)
	var index := _zone_index_of(flight.card_id)
	if index >= 0 and index < zone_container.get_child_count():
		(zone_container.get_child(index) as Control).modulate = Color.WHITE
	_drop_fx_node(flight.ghost)
	if flight.warn:
		_say("zone_warning")

func _zone_index_of(card_id: String) -> int:
	for i in controller.zone.cards.size():
		if controller.zone.cards[i].id == card_id:
			return i
	return -1

# Stand-in for a card that already left the zone state, drawn where it sat until the flash.
func _spawn_card_overlay(card_type: String, rect: Rect2) -> Control:
	var overlay := _make_card_rect(card_type, 0, rect.size)
	_fx().add_child(overlay)
	overlay.global_position = rect.position
	return overlay

func _snapshot_zone() -> Dictionary:
	var ids: Array = []
	var types: Array = []
	var rects: Array = []
	for c in controller.zone.cards:
		ids.append(c.id)
		types.append(c.type)
	for i in zone_container.get_child_count():
		rects.append(zone_container.get_child(i).get_global_rect())
	return {"ids": ids, "types": types, "rects": rects}

func _zone_slot_rect(rects: Array, index: int) -> Rect2:
	if rects.size() > 0:
		return rects[mini(index, rects.size() - 1)]
	return Rect2(zone_container.global_position, _zone_card_size())

# The gold flash over the three matched cards; they fade away under it. Plays once the last
# of the three has landed, as an overlay: the zone underneath is already updated.
func _play_match(group: MatchGroup) -> void:
	match_flashes += 1
	_play_sfx("match")
	_say("match")
	var center := Vector2.ZERO
	for rect: Rect2 in group.rects:
		var flash := Panel.new()
		flash.size = rect.size
		flash.pivot_offset = rect.size / 2.0
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#ffd54a")
		style.border_color = Color("#fff7d6")
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		flash.add_theme_stylebox_override("panel", style)
		_fx().add_child(flash)
		flash.global_position = rect.position
		var tween := flash.create_tween()
		tween.set_parallel(true)
		tween.tween_property(flash, "scale", Vector2(1.3, 1.3), 0.3)
		tween.tween_property(flash, "modulate:a", 0.0, MATCH_FLASH_SECONDS)
		tween.chain().tween_callback(flash.queue_free)
		center += rect.get_center()
	for node: Control in group.nodes:
		if not is_instance_valid(node):
			continue
		var fade := node.create_tween()
		fade.tween_property(node, "modulate:a", 0.0, MATCH_FADE_SECONDS).set_delay(0.08)
		fade.tween_callback(node.queue_free)
	if not group.rects.is_empty():
		_play_gold_burst(center / group.rects.size())

func _play_gold_burst(center: Vector2) -> void:
	var burst := UiHelpers.symbol_label("✦", 40)
	burst.size = Vector2(40, 40)
	burst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	burst.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	burst.modulate = Color(1, 0.84, 0.3, 0.95)
	burst.pivot_offset = Vector2(20, 20)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx().add_child(burst)
	burst.global_position = center - Vector2(20, 20)
	var t := burst.create_tween()
	t.set_parallel(true)
	t.tween_property(burst, "scale", Vector2(2.2, 2.2), 0.35)
	t.tween_property(burst, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(burst.queue_free)

func _play_card_impact(center: Vector2) -> void:
	var impact := UiHelpers.symbol_label("✦", 24)
	impact.size = Vector2(24, 24)
	impact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	impact.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	impact.modulate = Color(1, 0.88, 0.35, 0.95)
	impact.pivot_offset = Vector2(12, 12)
	impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx().add_child(impact)
	impact.global_position = center - Vector2(12, 12)
	var tween := impact.create_tween()
	tween.set_parallel(true)
	tween.tween_property(impact, "scale", Vector2(1.6, 1.6), 0.16)
	tween.tween_property(impact, "modulate", Color(1, 0.88, 0.35, 0), 0.16)
	tween.chain().tween_callback(impact.queue_free)

func _play_sfx(kind: String) -> void:
	if _sfx_player == null or not is_instance_valid(_sfx_player):
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

# The end panel waits for the visuals still in flight (the last match must be seen), but
# never longer than END_WAIT_MAX_MSEC. _process keeps calling this until the panel is up.
func _check_end() -> void:
	if _ended:
		return
	var win := controller.status == GameController.Status.WON
	if not win and controller.status != GameController.Status.LOST:
		return
	if not visuals_settled():
		var now := Time.get_ticks_msec()
		if _end_wait_started_msec < 0:
			_end_wait_started_msec = now
		if now - _end_wait_started_msec < END_WAIT_MAX_MSEC:
			return
		_clear_fx()
	_show_end(win)

func _show_end(win: bool) -> void:
	if _ended:
		return
	_ended = true
	if mascot != null:
		mascot.visible = false
	if _instruction_bubble != null and is_instance_valid(_instruction_bubble):
		_instruction_bubble.queue_free()
	_play_sfx("win" if win else "lose")
	if _endless != null:
		_show_endless_end(win)
		return
	var granted: Array = []
	if win:
		granted = Game.complete_level(controller.stars, controller.rewards)
	else:
		# Powers spent during a lost attempt are already gone from the inventory.
		Game.save_progress()

	var info := _open_end_panel()

	var stage_num := Label.new()
	stage_num.text = str(controller.level_id)
	stage_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_num.add_theme_font_size_override("font_size", 40)
	stage_num.add_theme_color_override("font_color", TEXT_PRIMARY)
	info.add_child(stage_num)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TEXT_MUTED)
	if win:
		title.text = Localizer.t("level_complete")
	elif controller.loss_reason == GameController.LossReason.TIMEOUT:
		title.text = Localizer.t("time_up")
	else:
		title.text = Localizer.t("no_moves")
	info.add_child(title)

	if win:
		var stars_row := HBoxContainer.new()
		stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stars_row.add_theme_constant_override("separation", 6)
		info.add_child(stars_row)
		for i in 3:
			var earned: bool = i < controller.stars
			var star := UiHelpers.symbol_label("★" if earned else "☆", 36)
			star.add_theme_color_override("font_color", GOLD if earned else Color(1, 1, 1, 0.35))
			star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			star.custom_minimum_size = Vector2(40, 44)
			star.pivot_offset = star.custom_minimum_size / 2.0
			star.modulate = Color(1, 1, 1, 0)
			star.scale = Vector2(0.3, 0.3)
			stars_row.add_child(star)
		_reveal_stars(stars_row)

		var time_line := Label.new()
		time_line.text = "%s: %s" % [Localizer.t("time"), _format_time(controller.timer.elapsed_seconds())]
		time_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_line.add_theme_color_override("font_color", TEXT_PRIMARY)
		info.add_child(time_line)

		_add_reward_lines(info, "stage_reward", granted)

		var total_stars := UiHelpers.symbol_label(UiHelpers.total_stars_text(), 14)
		total_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_stars.add_theme_color_override("font_color", GOLD)
		info.add_child(total_stars)

	_add_end_mascot(info, win, "win" if win else "lose", {
		"stars": controller.stars,
		"timeout": controller.loss_reason == GameController.LossReason.TIMEOUT,
	})

	var buttons := _add_end_buttons(info)
	if win and LevelLoader.level_exists(int(controller.level_id) + 1):
		buttons.add_child(_make_end_button(Localizer.t("next_level"), func(): Game.start_level(int(controller.level_id) + 1)))
	if not win:
		buttons.add_child(_make_end_button(Localizer.t("retry"), func(): Game.restart_level()))
	buttons.add_child(_make_end_button(Localizer.t("menu"), func(): Game.go_to_menu()))

# Endless end panels: a cleared round (the run goes on) or the end of the run.
func _show_endless_end(win: bool) -> void:
	var info := _open_end_panel()
	var buttons: HBoxContainer
	if win:
		var cleared := _endless.complete_round()
		var round_number: int = int(cleared["round"]) - 1
		info.add_child(_make_end_label(str(round_number), 40, TEXT_PRIMARY))
		info.add_child(_make_end_label(Localizer.t("round_cleared"), 18, TEXT_MUTED))
		info.add_child(_make_end_label("%s  +%d" % [Localizer.t("round_bonus"), int(cleared["bonus"])], 15, GOLD))
		_add_reward_lines(info, "power_reward", cleared["granted"])
		info.add_child(_make_end_label("%s: %d" % [Localizer.t("score"), _endless.score], 15, TEXT_PRIMARY))
		_add_end_mascot(info, true, "round_intro", {})
		buttons = _add_end_buttons(info)
		buttons.add_child(_make_end_button(Localizer.t("next_round"), func(): Game.restart_level()))
	else:
		var result := _finish_endless_run()
		info.add_child(_make_end_label(Localizer.t("run_over"), 22, TEXT_MUTED))
		info.add_child(_make_end_label(str(result["score"]), 40, TEXT_PRIMARY))
		info.add_child(_make_end_label("%s: %d" % [Localizer.t("rounds_cleared"), int(result["rounds_cleared"])], 14, TEXT_PRIMARY))
		if bool(result["new_best"]):
			info.add_child(_make_end_label("★ %s" % Localizer.t("new_best"), 18, GOLD, true))
		else:
			info.add_child(_make_end_label("%s: %d" % [Localizer.t("best_score"), Game.progress.endless_best], 14, TEXT_MUTED))
		_add_end_mascot(info, false, "lose", {})
		buttons = _add_end_buttons(info)
		buttons.add_child(_make_end_button(Localizer.t("play_again"), func(): Game.start_endless()))
	buttons.add_child(_make_end_button(Localizer.t("menu"), _on_back))

# Shared end-of-round panel shell: dark shade + centered warm panel. Returns the
# VBox the caller fills with rows.
func _open_end_panel() -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 1000
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.z_index = 1001
	add_child(center)

	var panel := _make_panel(PANEL_BACKGROUND.darkened(0.25), PANEL_BORDER, 14)
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	panel_style.bg_color.a = 0.96
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 14
	panel.custom_minimum_size = Vector2(240, 0)
	panel.theme = UiHelpers.warm_theme()
	center.add_child(panel)

	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	# Landscape is only 360 px tall: tighten the rows to make room for Ace's line.
	info.add_theme_constant_override("separation", 3 if _is_landscape and Game.mascot_enabled() else 6)
	panel.add_child(info)
	return info

func _make_end_label(text: String, font_size: int, color: Color, symbols: bool = false) -> Label:
	var label := UiHelpers.symbol_label(text, font_size) if symbols else Label.new()
	if not symbols:
		label.text = text
		label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	return label

# "Reward" heading plus one "icon Name +qty" line per granted power (nothing when empty).
func _add_reward_lines(parent: Container, title_key: String, granted: Array) -> void:
	if granted.is_empty():
		return
	var reward_title := Label.new()
	reward_title.text = Localizer.t(title_key)
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_title.add_theme_font_size_override("font_size", 13)
	reward_title.add_theme_color_override("font_color", TEXT_MUTED)
	parent.add_child(reward_title)
	for r in granted:
		var rtype := str(r.get("type", ""))
		var qty := int(r.get("quantity", 0))
		var line := UiHelpers.symbol_label("%s %s  +%d" % [_power_icon(rtype), _power_name(rtype), qty], 15)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_color_override("font_color", GOLD)
		parent.add_child(line)

# Spacer + empty button row at the bottom of an end panel; the caller adds the buttons.
func _add_end_buttons(parent: Container) -> HBoxContainer:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	parent.add_child(gap)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	parent.add_child(buttons)
	return buttons

# Ace's line, inside the result panel: `event` picks the pool ("win" depends on the stars).
func _add_end_mascot(parent: Container, win: bool, event: String, context: Dictionary) -> void:
	if not Game.mascot_enabled():
		return
	var ace := Mascot.new()
	ace.idle_tips = false
	ace.custom_minimum_size = Vector2(33, 39)
	ace.set_mood(Mascot.Mood.HAPPY if win else Mascot.Mood.SAD)
	var line := ace.localized_line(event, context)
	var row := HBoxContainer.new()
	row.name = "MascotRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(ace)
	var speech := Label.new()
	speech.text = line
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.custom_minimum_size = Vector2(170, 0)
	speech.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech.add_theme_font_size_override("font_size", 11)
	speech.add_theme_color_override("font_color", TEXT_MUTED)
	row.add_child(speech)
	parent.add_child(row)

# Back button: a quit mid-run still counts (score recorded and saved) before the menu.
func _on_back() -> void:
	if _endless != null:
		_finish_endless_run()
	Game.go_to_menu()

# Ends the run in memory, then writes the best score to disk. Idempotent.
func _finish_endless_run() -> Dictionary:
	var result := _endless.end_run(Game.progress)
	Game.save_progress()
	return result

func _record_endless_match(card_count: int) -> void:
	if _endless == null or card_count <= 0:
		return
	var points := _endless.record_match(card_count)
	_refresh_score()
	_pop_score(points)

func _score_text() -> String:
	return "✦ %d" % _endless.score

func _refresh_score() -> void:
	if score_label != null and _endless != null:
		score_label.text = _score_text()

# Small "+30" that floats up from the score pill and fades.
func _pop_score(points: int) -> void:
	if score_label == null or points <= 0:
		return
	var pop := Label.new()
	pop.text = "+%d" % points
	pop.add_theme_font_size_override("font_size", 14)
	pop.add_theme_color_override("font_color", GOLD)
	pop.add_theme_color_override("font_outline_color", Color(0.16, 0.10, 0.08))
	pop.add_theme_constant_override("outline_size", 4)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.z_index = 1900
	add_child(pop)
	var rect := score_label.get_global_rect()
	pop.global_position = Vector2(rect.end.x - 34.0, rect.end.y + 2.0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(pop, "global_position:y", pop.global_position.y + 14.0, 0.7)
	t.tween_property(pop, "modulate:a", 0.0, 0.7).set_delay(0.25)
	t.chain().tween_callback(pop.queue_free)

func _make_end_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(108, 40)
	btn.pressed.connect(callback)
	return btn

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
	if _endless != null:
		title.text = Localizer.t("round_title") % _endless.current_round
	else:
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
	_say_instruction()

func _show_error(msg: String) -> void:
	var label := Label.new()
	label.text = "%s: %s" % [Localizer.t("error"), msg]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	label.z_index = 100
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
	var t := stars_label.create_tween()
	t.tween_property(stars_label, "scale", Vector2(1.25, 1.25), 0.12)
	t.tween_property(stars_label, "scale", Vector2.ONE, 0.18)
	t.tween_property(stars_label, "modulate", Color(1, 0.55, 0.3), 0.1)
	t.tween_property(stars_label, "modulate", Color.WHITE, 0.15)
