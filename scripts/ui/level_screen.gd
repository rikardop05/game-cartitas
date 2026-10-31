extends Control

const CARD_DISPLAY_SIZE := Card.DISPLAY_SIZE
const RESERVE_MIN_CARD_PX := 18.0
const TEXT_PRIMARY := Color("#fff1d2")
const TEXT_MUTED := Color("#f0c98e")
const INK := Color("#3a2410")
const GOLD := Color("#ffe36e")
const BOARD_CARD_SCALE := 1.0
const BOARD_X_COMPRESSION := 1.0
const BOARD_Y_COMPRESSION := 1.0
# The background inside the board window, darkened so the cards read.
const BOARD_SHADE := Color(0.0, 0.0, 0.0, 0.5)
# The cards sit this many px inside the window's drawn frame.
const BOARD_PAD := 2.0
# Thickest painted border drawn around the board, in logical px. The frame PNG is
# alpha-cropped to its visible box and 9-sliced; capping the border keeps the thick
# painted bevel from eating the play area. Drop the cleaned art's 9-slice margin here
# once the Atelie delivers it.
const BOARD_FRAME_BORDER_MAX := 6.0
# Painted UI pieces delivered by the Atelie. Margins are fractions of the cropped
# texture and keep the carved corners/ornaments from being cut by the 9-slice.
const RESERVE_FIELD_ART := "res://assets/ui/kit/panel_reserve_field.png"
const RESERVE_FIELD_MARGINS := Rect2(0.07, 0.11, 0.07, 0.11)
const POWERS_BOARD_ART := "res://assets/ui/kit/panel_powers_board.png"
const POWERS_BOARD_MARGINS := Rect2(0.09, 0.05, 0.09, 0.05)
# The square wooden plate is the table under each Support Deck's pile.
const DECK_TABLE_ART := "res://assets/ui/kit/card_available_frame.png"
const MATCH_BURST_ART := "res://assets/ui/fx/match_burst.png"
const MATCH_SMOKE_ART := "res://assets/ui/fx/match_smoke.png"
const MATCH_FX_CARD_SPAN := 2.0
const MATCH_FX_SECONDS := 0.34
# The Clearing Zone bar's painted body inside its file (the file has wide transparent margins)
# and the share of the width its carved end caps take when 9-sliced.
const ZONE_BAR_ART := "res://assets/ui/kit/bar_zone.png"
# Fractions of the cropped bar: the dark bevel and the carved end caps stay intact,
# the slots sit inside the wooden hole.
const ZONE_BAR_MARGINS := Rect2(0.025, 0.10, 0.025, 0.10)
# Size the painted sound note is cached at for the HUD buttons.
const SOUND_ICON_PX := 72
# Endless uses the autumn background like the later Levels.
const ENDLESS_BACKGROUND_LEVEL := 999
# Frame thickness (source px) when a kit panel is 9-sliced: border plus its shadow line.
const FRAME_MARGIN := 7

# Layout, in logical px. Landscape (640x360) follows the owner's mockup; portrait (360x640)
# stacks the same pieces. Every piece is a kit panel at an exact position, nothing reflows.
const LAND_HUD_HEIGHT := 48.0
const LAND_CHEVRON := Rect2(19, 11, 32, 30)
const LAND_TITLE := Rect2(58, 12, 165, 28)
const LAND_PILL_CLOCK := Vector2(241, 14)
const LAND_PILL_SECOND := Vector2(322, 14)
# Campaign: the stars plaque (about 2.5:1, like its art) sits right of the clock plate.
const LAND_PLAQUE := Rect2(314, 11, 90, 36)
const LAND_HELP := Rect2(500, 14, 36, 32)
const LAND_GEAR := Rect2(538, 5, 36, 36)
const LAND_SOUND := Rect2(576, 5, 36, 36)
const LAND_BOARD_FRAME := Rect2(96, 62, 464, 208)
# Inside the frame art (its transparent centre), in frame-local px.
const LAND_BOARD_INNER := Rect2(5, 6, 454, 193)
const LAND_POWERS := Rect2(571, 62, 64, 128)
const LAND_POWERS_INNER := Rect2(5, 6, 54, 115)
const LAND_DECK_A := Rect2(18, 201, 64, 64)
const LAND_DECK_B := Rect2(571, 201, 64, 64)
const LAND_RESERVE := Rect2(18, 280, 148, 64)
const LAND_ZONE := Rect2(172, 280, 464, 64)
# The hero may overlap the board/HUD intentionally; the MascotArea is only the
# placement box (the mascot itself is behind Layout, its bubble above it).
const LAND_MASCOT_AREA := Rect2(0, 48, 160, 222)
# Portrait fills the whole 360x640 screen: powers at the top-left, the hero top-centre,
# the zone bar under it, the board in the lower half, then decks/Reserve and a footer
# with the gear, sound, stars plaque and logo. Nothing reflows.
const PORT_CHEVRON := Rect2(4, 7, 32, 30)
const PORT_TITLE := Rect2(40, 6, 54, 32)
const PORT_PILL_CLOCK := Vector2(108, 6)
const PORT_PILL_SECOND := Vector2(145, 598)
# Campaign portrait: the clock moves right of the hero's head, beside the help button;
# the stars plaque and the logo take the footer.
const PORT_PILL_CLOCK_CAMPAIGN := Vector2(257, 6)
const PORT_PLAQUE := Rect2(132, 596, 90, 36)
const PORT_HELP := Rect2(322, 7, 30, 30)
const PORT_GEAR := Rect2(14, 601, 32, 32)
const PORT_SOUND := Rect2(52, 601, 32, 32)
const PORT_BOARD_FRAME := Rect2(11, 327, 339, 196)
const PORT_BOARD_INNER := Rect2(5, 6, 329, 184)
# Portrait keeps the vertical powers board (no 90-degree rotation blur): an 80x156
# panel at the top-left, with the three buttons stacked like the landscape panel.
const PORT_POWERS := Rect2(4, 48, 80, 156)
const PORT_POWERS_INNER := Rect2(5, 6, 70, 144)
const PORT_DECK_A := Rect2(18, 528, 64, 64)
const PORT_DECK_B := Rect2(278, 528, 64, 64)
const PORT_RESERVE := Rect2(96, 528, 168, 64)
const PORT_ZONE := Rect2(4, 254, 352, 52)
# The hero box: 174x260 top-centre, so the zone bar only overlaps the skirt by ~5 px.
const PORT_MASCOT_AREA := Rect2(104, 0, 174, 260)
# Safe free area for the instruction bubble in the sky: clear of the powers panel
# (left) and of the board/zone (below); the hero may sit under it.
const LAND_INSTRUCTION_AREA := Rect2(0, 48, 160, 222)
# Portrait: the narrow free strip right of the hero (the powers own the left, the hero the
# centre). Keeping the bubble there never covers the hero's head/face or the powers panel.
const PORT_INSTRUCTION_AREA := Rect2(276, 40, 80, 150)
# The painted wordmark lives in the portrait footer only (landscape keeps its title).
const PORT_LOGO := Rect2(266, 594, 90, 40)
const LOGO_ART := "res://assets/ui/branding/logo_claw_and_crown.png"
const PILL_SIZE := Vector2(64, 32)
# The stopwatch badge overlaps the left end of the clock plate (relative to the plate); the time
# text is centred on the part of the plate it leaves free.
const STOPWATCH_RECT := Rect2(-13, 0, 33, 32)
# The stopwatch badge overlaps the plate's left end; a small inset keeps the time
# clear of it while sitting visually near the plate centre (was 20 = too far right).
const CLOCK_TEXT_X := 8.0
# Where the three stars sit on the plaque art (fractions of its width / height).
const PLAQUE_STAR_X := [0.235, 0.5, 0.765]
const PLAQUE_STAR_Y := 0.52
const STARS_PATH_FORMAT := "stars_%d"
const STAR_PUFF_COUNT := 7
# End panel: the plaque of the earned stars (the art is 1024x409).
const END_PLAQUE_LANDSCAPE := Vector2(140, 56)
const END_PLAQUE_PORTRAIT := Vector2(230, 92)
# The plaque hangs over the result panel's top edge by this share of its height. Landscape is
# tight on 360 px, so there it tucks in further behind the panel.
const END_STARS_OVERLAP_LANDSCAPE := 0.22
const END_STARS_OVERLAP_PORTRAIT := 0.2
# The inside of a 64x64 slot (deck piles are centred in it).
const SLOT_INNER := Rect2(5, 6, 54, 52)
const POWER_BUTTON_LANDSCAPE := Vector2(54, 36)
const LANDSCAPE_ZONE_CARD_SIZE := Vector2(46.0, 46.0)
# The zone row fills the whole bar: 7 slots + 6 computed gaps, centered.
const PORTRAIT_ZONE_CARD_SIZE := Vector2(42.0, 42.0)
const LANDSCAPE_RESERVE_CARD_SIZE := Vector2(34.0, 34.0)
const PORTRAIT_RESERVE_CARD_SIZE := Vector2(42.0, 42.0)
const DECK_CARD_SIZE := Vector2(42.0, 42.0)
# A Support Deck is a pile: one face-up card plus up to PILE_MAX_EDGES card edges.
# 42 + 3*4 = 54 = SLOT_INNER width: the real stacked frames fill the 64 px slot.
const PILE_EDGE_STEP := 4.0
const PILE_MAX_EDGES := 3
# The hero portraits are 2:3 and replace the old 46x55 NPCs: 64x96 landscape keeps a
# free band for the bubble above the hero; portrait has room for a bigger figure.
const MASCOT_SCALE_LANDSCAPE := 1.6
const MASCOT_SCALE_PORTRAIT := 1.8
const INSTRUCTION_SECONDS := 4.0
# Card moves are applied to the controller the instant they are tapped; these timings only
# drive the overlay visuals (flying ghost, match flash) that catch up with the state.
const FLIGHT_SECONDS := 0.2
const FLIGHT_TILT := 0.07
const FLIGHT_START_SCALE := 1.08
const MATCH_FADE_SECONDS := 0.25
const MATCH_FLASH_SECONDS := 0.45
# A card entering the zone lands beside its kind: the cards right of the gap slide over while
# it flies. After a match, the survivors hop back into the freed slots once the flash has played.
const ZONE_SHIFT_SECONDS := 0.18
const ZONE_HOP_SECONDS := 0.26
# The hop lifts the card by this fraction of its own height before it drops into the slot.
const ZONE_HOP_LIFT_RATIO := 0.35
const ZONE_HOP_DELAY := 0.1
# The end panel waits for in-flight visuals, but never longer than this.
const END_WAIT_MAX_MSEC := 1200
# Blocked cards darken with their depth under reachable cards: 1 = directly under an
# available card, 2 = under a blocked card, 3+ = deeper still. Index 0 (available) is untouched.
const DEPTH_BRIGHTNESS := [1.0, 0.45, 0.32, 0.22]
const DEPTH_SATURATION := [1.0, 0.80, 0.68, 0.58]
# Painted card faces are busier than a flat placeholder, so blocked ones are dimmed less to
# stay recognisable. Never brighter than 0.5 and still strictly darker with depth, which
# repro_hud_bounds checks.
const ART_DEPTH_BRIGHTNESS := [1.0, 0.5, 0.38, 0.28]
const ART_DEPTH_SATURATION := [1.0, 0.9, 0.8, 0.7]
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
static var _chevron_texture_cache: ImageTexture
static var _portrait_frame_cache: ImageTexture
static var _sound_icon_cache := {}
# Visible (alpha bbox) rect of each painted FX inside its texture, in texture px.
static var _fx_optical_cache := {}

# The three cards of one match, flashed together once the last of them has landed.
class MatchGroup extends RefCounted:
	var pending := 0
	var nodes: Array = []
	var rects: Array = []
	var shifts: Array = []

# One card of the zone drawn on its way to the slot it now owns: the insertion slides the
# cards after the gap to the right, a match hops the survivors to the left.
class ZoneShift extends RefCounted:
	var card_id := ""
	var ghost: Control
	var from := Rect2()
	var to := Rect2()
	var lift := 0.0

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
var reserve_container: Control
var deck_a_btn: Button
var deck_b_btn: Button
var power_buttons: Dictionary = {}
var timer_label: Label
# Live stars: the stars plaque (campaign only; null in Endless). Its base picture shows the stars
# kept so far; the star at stake turns to stone gradually (an overlay of the next-lower picture
# fades in) and puffs away once its threshold passes. The first star never turns to stone (a
# win earns at least one). stars_row is the "StarsPill" node itself.
var stars_row: Control
var stars_base: TextureRect
var stars_overlay: TextureRect
# Stars still gold on the plaque (3, 2 or 1), -1 until the first sync after a (re)build.
var stars_shown := -1
var score_label: Label
var level_label: Label
var _sound_icon: TextureRect
var _mascot_area: Control
var _instruction_bubble: PanelContainer
var _is_landscape := true
var _ended := false
var _help_shown := false
# The in-game settings overlay is open (the clock is paused; a rebuild re-creates the overlay).
var _settings_open := false
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
var _shifts: Array = []
var _end_wait_started_msec := -1
var _layout_cache: Dictionary = {}
var _layout_cache_size := Vector2.ZERO
# Matches whose flash has played (the rapid-tap smoke asserts on it).
var match_flashes := 0
# The Endless run being played, or null for a campaign Level.
var _endless: EndlessRun

func _ready() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.play_gameplay(self)
	_level_id = Game.current_level_id
	_endless = Game.endless_run
	_build_ui()
	resized.connect(_on_resized)
	await get_tree().process_frame
	var attempts := 0
	while board_container != null and board_container.size.x <= 0.0 and attempts < 10:
		await get_tree().process_frame
		attempts += 1
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

# Gameplay music keeps playing while the next scene loads; the menu (or the next Level)
# crossfades over it. release() only mutes it if no scene has claimed the audio since.
func _exit_tree() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.release(self)

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
			if not _help_shown and not _settings_open:
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
	if controller == null or _ended:
		return
	var landscape := _viewport_is_landscape()
	if landscape != _is_landscape:
		_build_ui()
		await get_tree().process_frame
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if not is_inside_tree():
			return
		render()
	else:
		await get_tree().process_frame
		if not is_inside_tree():
			return
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
	_sound_icon = null
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

	add_child(UiHelpers.make_background(_is_landscape, _background_level()))

	# Every piece sits at its own kit position (logical px); the layout never reflows.
	var layout := Control.new()
	layout.name = "Layout"
	layout.z_index = 0
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	_build_hud(layout)
	_build_board_frame(layout)
	_build_deck_slot(layout, "a")
	_build_deck_slot(layout, "b")
	_build_reserve_panel(layout)
	_build_zone_panel(layout)
	_build_controls(layout)
	# Ace's free space; it is a plain spacer so the mascot and bubble have a known area.
	_mascot_area = Control.new()
	_mascot_area.name = "MascotArea"
	_mascot_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_mascot_area, _pick(LAND_MASCOT_AREA, PORT_MASCOT_AREA))
	layout.add_child(_mascot_area)
	_build_mascot()
	_fx()
	# The settings overlay survives a rebuild (language, orientation, mascot): it is rebuilt on
	# top of the new screen and the clock stays paused underneath.
	if _settings_open:
		_build_settings_overlay()

# Campaign Levels 1-3 use the meadow, later ones (and Endless) the autumn town.
func _background_level() -> int:
	return ENDLESS_BACKGROUND_LEVEL if _endless != null else _level_id.to_int()

# The big hero lives inside BoardFrame so the layer order is frame < hero < cards.
# It may overflow the frame (the frame does not clip); foreground panels (z>=8) and
# the HUD cover the parts that would hurt reading/taps. Its bubble is foreground.
func _build_mascot() -> void:
	mascot = null
	if not Game.mascot_enabled():
		return
	mascot = Mascot.new()
	mascot.name = "Mascot"
	mascot.z_index = 1
	mascot.visible = false  # shown by _place_mascot once the layout is known
	if _endless != null:
		mascot.idle_event = "idle_tip_endless"
	var frame := find_child("BoardFrame", true, false) as Control
	if frame != null:
		frame.add_child(mascot)
	else:
		add_child(mascot)

func _place_mascot() -> void:
	if mascot == null or _mascot_area == null:
		return
	var area := _mascot_area.get_global_rect()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	mascot.size = Mascot.BASE_SIZE * (MASCOT_SCALE_LANDSCAPE if _is_landscape else MASCOT_SCALE_PORTRAIT)
	if _is_landscape:
		# Landscape: bottom-align in the frame, left edge of the MascotArea.
		mascot.global_position = Vector2(area.position.x, area.end.y - mascot.size.y)
		mascot.free_bounds = Rect2()
		mascot.side_bubble_bounds = Rect2(
			mascot.global_position.x + mascot.size.x + 6.0,
			area.position.y + 10.0, 200.0, 60.0)
	else:
		# Portrait: x = MascotArea left, vertically centred; the bubble floats above
		# the hero over the board's top edge (opaque, mouse-ignore).
		mascot.global_position = Vector2(
			area.position.x,
			area.position.y + (area.size.y - mascot.size.y) * 0.5)
		mascot.side_bubble_bounds = Rect2()
		mascot.free_bounds = PORT_INSTRUCTION_AREA
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
	if _ended:
		return
	var area: Rect2 = _pick(LAND_INSTRUCTION_AREA, PORT_INSTRUCTION_AREA)
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
	bubble.global_position = Vector2(
		clampf(target.x, area.position.x, maxf(area.position.x, area.end.x - bubble.size.x)),
		clampf(target.y, area.position.y, maxf(area.position.y, area.end.y - bubble.size.y))
	)
	bubble.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_interval(INSTRUCTION_SECONDS - 0.3)
	fade.tween_property(bubble, "modulate:a", 0.0, 0.3)
	fade.tween_callback(bubble.queue_free)

func _pick(landscape_value, portrait_value):
	return landscape_value if _is_landscape else portrait_value

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

# A plain decorative picture at an exact size (never takes input).
func _make_art(node_name: String, texture: Texture2D, rect: Rect2, hires: bool = false) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hires:
		# Painted full-resolution art, scaled by the GPU to the real screen size (see hires_texture).
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_place(art, rect)
	return art

# A cached, pre-rendered soft drop shadow for a painted/pixel-art control. The alpha
# blur is baked once by UiHelpers.shadow_texture, so this costs one textured quad.
func _make_drop_shadow(texture: Texture2D, rect: Rect2, softness: float = 1.8, strength: float = 0.35) -> TextureRect:
	var shadow_tex := UiHelpers.shadow_texture(texture, softness, strength)
	if shadow_tex == null:
		return null
	var shadow := _make_art("Shadow", shadow_tex, rect, true)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return shadow

# The pixel-art "<" of the back button: drawn here (the kit has no chevron) as a 16x15 image
# shown at 2x with the project's nearest filter, so every pixel stays crisp.
static func _chevron_texture() -> Texture2D:
	if _chevron_texture_cache == null:
		var outline := Color("#000000")
		var light := Color("#8fd032")
		var body := Color("#74bc50")
		var dark := Color("#477238")
		var image := Image.create(16, 15, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		var filled := {}
		for y in range(1, 14):
			var x0 := 2 + absi(y - 7)
			for x in range(x0, x0 + 5):
				filled[Vector2i(x, y)] = true
				var shade := body
				if x == x0:
					shade = light
				elif x == x0 + 4:
					shade = dark
				image.set_pixel(x, y, shade)
		for cell: Vector2i in filled.keys():
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var near := cell + Vector2i(dx, dy)
					if not filled.has(near) and near.x >= 0 and near.y >= 0 and near.x < 16 and near.y < 15:
						image.set_pixel(near.x, near.y, outline)
		_chevron_texture_cache = ImageTexture.create_from_image(image)
	return _chevron_texture_cache

# A 9-sliced painted panel from UiHelpers' alpha-cropped data: the carved corners
# keep their shape, the border never squashes, and nothing is stretched diagonally.
func _make_nine_patch_art(node_name: String, frame_data: Dictionary, rect: Rect2) -> NinePatchRect:
	var art := NinePatchRect.new()
	art.name = node_name
	art.texture = frame_data.get("texture")
	var margins: Rect2i = frame_data.get("margins", Rect2i())
	art.patch_margin_left = margins.position.x
	art.patch_margin_top = margins.position.y
	art.patch_margin_right = margins.size.x
	art.patch_margin_bottom = margins.size.y
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(art, Rect2(Vector2.ZERO, rect.size))
	return art

# The Clearing Zone bar: the new painted plank, alpha-cropped and 9-sliced so the
# carved end caps stay intact and the slots can use the wooden hole.
func _zone_bar_data(rect: Rect2) -> Dictionary:
	return UiHelpers.trimmed_nine_patch(
		UiHelpers.hires_texture(ZONE_BAR_ART), rect.size, ZONE_BAR_MARGINS, "zone_bar")

# A flat button showing a picture at an exact size; it nudges down one pixel while pressed
# and brightens on hover.
func _make_icon_button(node_name: String, texture: Texture2D, rect: Rect2, hires: bool = false, inset: float = 0.0) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	_make_flat_button_compact(btn)
	_place(btn, rect)
	var icon_rect := Rect2(Vector2(inset, inset), rect.size - Vector2(inset, inset) * 2.0)
	var shadow := _make_drop_shadow(texture, Rect2(icon_rect.position + Vector2(1, 1), icon_rect.size), 1.5, 0.35)
	if shadow != null:
		btn.add_child(shadow)
	var icon := _make_art("Icon", texture, icon_rect, hires)
	btn.add_child(icon)
	btn.button_down.connect(func(): icon.position.y = inset + 1.0)
	btn.button_up.connect(func(): icon.position.y = inset)
	btn.mouse_entered.connect(func(): icon.modulate = Color(1.18, 1.18, 1.18))
	btn.mouse_exited.connect(func(): icon.modulate = Color.WHITE)
	return btn

func _build_hud(parent: Control) -> void:
	var hud := Control.new()
	hud.name = "Hud"
	hud.z_index = 8
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Portrait uses the full height (the footer lives in the HUD); landscape keeps its 48 px bar.
	_place(hud, Rect2(0.0, 0.0, get_viewport_rect().size.x, _pick(LAND_HUD_HEIGHT, get_viewport_rect().size.y)))
	parent.add_child(hud)

	var back := _make_icon_button("BackButton", _chevron_texture(), _pick(LAND_CHEVRON, PORT_CHEVRON))
	back.pressed.connect(_on_back)
	hud.add_child(back)

	# The Endless label ("Endless · Round 12") is wider than "Level 6": in the narrow portrait
	# title slot it wraps onto two lines.
	level_label = Label.new()
	level_label.name = "Title"
	if _endless != null:
		level_label.text = Localizer.t("endless_round") % _endless.current_round
	else:
		level_label.text = "%s %s" % [Localizer.t("level"), _level_id]
	level_label.add_theme_font_size_override("font_size", 14 if _is_landscape else 10)
	level_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	UiHelpers.add_text_shadow(level_label)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _is_landscape:
		level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(level_label, _pick(LAND_TITLE, PORT_TITLE))
	hud.add_child(level_label)

	_build_hud_pills(hud)

	var help := Button.new()
	help.name = "HelpButton"
	help.text = "?"
	help.focus_mode = Control.FOCUS_NONE
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", TEXT_PRIMARY)
	help.add_theme_color_override("font_hover_color", Color.WHITE)
	help.add_theme_color_override("font_pressed_color", TEXT_MUTED)
	help.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.03, 0.92))
	help.add_theme_constant_override("outline_size", 2)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := UiHelpers.kit_stylebox("pill", 8, 0)
		if state == "hover":
			style.modulate_color = Color(1.14, 1.14, 1.14)
		elif state == "pressed":
			style.modulate_color = Color(0.82, 0.82, 0.82)
		help.add_theme_stylebox_override(state, style)
	help.pressed.connect(_on_help)
	var help_rect: Rect2 = _pick(LAND_HELP, PORT_HELP)
	_place(help, help_rect)
	var help_shadow := _make_drop_shadow(
		UiHelpers.kit_texture("pill"),
		Rect2(help_rect.position + Vector2(1, 1), help_rect.size), 1.5, 0.35)
	if help_shadow != null:
		hud.add_child(help_shadow)
	hud.add_child(help)

	# The gear opens the in-game settings; it has the sound toggle's footprint and style.
	var gear := _make_icon_button("SettingsButton", UiHelpers.hud_texture("icon_gear"), _pick(LAND_GEAR, PORT_GEAR), true, 3.0)
	gear.tooltip_text = Localizer.t("settings")
	gear.pressed.connect(_on_settings)
	hud.add_child(gear)

	_sound_icon = null
	var sound := _make_icon_button("SoundButton", _sound_texture(), _pick(LAND_SOUND, PORT_SOUND), false, 2.0)
	_sound_icon = sound.get_node("Icon") as TextureRect
	sound.pressed.connect(_on_sound_toggle)
	hud.add_child(sound)

	# The painted wordmark only exists in the portrait footer (landscape has no logo).
	if not _is_landscape:
		var logo := _make_logo()
		if logo != null:
			hud.add_child(logo)

# The Claw & Crown wordmark: intrinsic aspect inside its footer slot, centred and never
# stretched. Returns null when the art is missing (the HUD then simply has no logo).
func _make_logo() -> Control:
	var texture := UiHelpers.hires_texture(LOGO_ART)
	if texture == null:
		return null
	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.texture = texture
	logo.set_meta("source_path", LOGO_ART)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(logo, PORT_LOGO)
	return logo

# The painted note icon is 1024 px square: it is shrunk once to HUD size and cached. The muted
# face is the same picture baked darker at build time, so it reads as off at a glance.
func _sound_texture() -> Texture2D:
	var icon_name := "icon_sound_on" if Game.sound_enabled() else "icon_sound_off"
	if not _sound_icon_cache.has(icon_name):
		var source := UiHelpers.kit_texture(icon_name)
		if source == null:
			return null
		var icon := source.get_image()
		if icon.is_compressed():
			icon.decompress()
		icon.convert(Image.FORMAT_RGBA8)
		icon.resize(SOUND_ICON_PX, SOUND_ICON_PX, Image.INTERPOLATE_LANCZOS)
		_sound_icon_cache[icon_name] = ImageTexture.create_from_image(icon)
	return _sound_icon_cache[icon_name]

func _on_sound_toggle() -> void:
	Game.set_sound(not Game.sound_enabled())
	if _sound_icon != null and is_instance_valid(_sound_icon):
		_sound_icon.texture = _sound_texture()

# One brown plate of the kit with a label centred on it (the plate itself is 64x32 and its
# drawn body sits a little above the middle, so the label box is offset to match).
func _make_pill(node_name: String, at: Vector2) -> TextureRect:
	return _make_art(node_name, UiHelpers.kit_texture("pill"), Rect2(at, PILL_SIZE))

func _make_pill_label(pill: TextureRect, text: String, font_size: int, color: Color, symbols: bool = false, inset_left: float = 0.0) -> Label:
	var label := UiHelpers.symbol_label(text, font_size) if symbols else Label.new()
	if not symbols:
		label.text = text
		label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	UiHelpers.add_text_shadow(label, 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, Rect2(inset_left, 4.0, PILL_SIZE.x - inset_left, 24.0))
	pill.add_child(label)
	return label

# Clock plate (the stopwatch badge stuck on its left end), then the live stars plaque
# (Endless: the run score plate instead).
func _build_hud_pills(hud: Control) -> void:
	var clock_at: Vector2 = _pick(LAND_PILL_CLOCK, PORT_PILL_CLOCK if _endless != null else PORT_PILL_CLOCK_CAMPAIGN)
	var clock_pill := _make_pill("ClockPill", clock_at)
	var clock_shadow := _make_drop_shadow(UiHelpers.kit_texture("pill"), Rect2(clock_at + Vector2(1, 1), PILL_SIZE), 1.5, 0.35)
	if clock_shadow != null:
		hud.add_child(clock_shadow)
	hud.add_child(clock_pill)
	timer_label = _make_pill_label(clock_pill, "00:00", 12, TEXT_PRIMARY, false, CLOCK_TEXT_X)
	clock_pill.add_child(_make_art("Stopwatch", UiHelpers.hud_texture("icon_stopwatch"), STOPWATCH_RECT, true))

	if _endless != null:
		stars_row = null
		stars_base = null
		stars_overlay = null
		var score_at: Vector2 = _pick(LAND_PILL_SECOND, PORT_PILL_SECOND)
		var score := _make_pill("ScorePill", score_at)
		var score_shadow := _make_drop_shadow(UiHelpers.kit_texture("pill"), Rect2(score_at + Vector2(1, 1), PILL_SIZE), 1.5, 0.35)
		if score_shadow != null:
			hud.add_child(score_shadow)
		hud.add_child(score)
		score_label = _make_pill_label(score, _score_text(), 11, GOLD, true)
	else:
		score_label = null
		_build_stars_plaque(hud)

func _make_flat_button_compact(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)

# The board window: a darkened copy of the background inside the kit frame, the cards on top.
func _build_board_frame(parent: Control) -> void:
	var rect: Rect2 = _pick(LAND_BOARD_FRAME, PORT_BOARD_FRAME)
	# The visible border of the current PNG decides the real hole; the constants are
	# only the fallback when the art is missing. This keeps the interior centred even
	# when the painted frame changes (new art, cleaned shadow, thicker bevel).
	var frame_data := UiHelpers.alpha_nine_patch(
		UiHelpers.kit_texture("panel_board_frame"), rect.size, BOARD_FRAME_BORDER_MAX)
	var inner: Rect2 = _pick(LAND_BOARD_INNER, PORT_BOARD_INNER)
	if not frame_data.is_empty():
		inner = frame_data["inner"]
	var frame := Control.new()
	frame.name = "BoardFrame"
	frame.z_index = 0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(frame, rect)
	parent.add_child(frame)
	var shade := ColorRect.new()
	shade.name = "BoardShade"
	shade.color = BOARD_SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(shade, inner)
	frame.add_child(shade)
	if not frame_data.is_empty():
		frame.add_child(_make_nine_patch_art("BoardArt", frame_data, rect))
	board_container = Control.new()
	board_container.name = "Board"
	board_container.clip_contents = true
	board_container.z_index = 2
	_place(board_container, inner.grow(-BOARD_PAD))
	frame.add_child(board_container)

# A Support Deck is a pile drawn inside its kit slot: deck A fans its card edges to the left,
# deck B to the right.
func _build_deck_slot(parent: Control, deck_id: String) -> void:
	var rect: Rect2 = _pick(LAND_DECK_A if deck_id == "a" else LAND_DECK_B, PORT_DECK_A if deck_id == "a" else PORT_DECK_B)
	var slot := Control.new()
	slot.name = "Deck%s" % deck_id.to_upper()
	slot.z_index = 8
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(slot, rect)
	parent.add_child(slot)
	# The square wooden plate is the deck's table; the pile sits on top of it.
	var table_shadow := Panel.new()
	table_shadow.name = "DeckTableShadow"
	table_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var table_style := StyleBoxFlat.new()
	table_style.bg_color = Color(0, 0, 0, 0)
	table_style.draw_center = false
	table_style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	table_style.shadow_size = 2
	table_style.shadow_offset = Vector2(1.0, 2.0)
	table_shadow.add_theme_stylebox_override("panel", table_style)
	_place(table_shadow, Rect2(Vector2.ZERO, rect.size))
	slot.add_child(table_shadow)
	slot.add_child(_make_art("DeckTable", UiHelpers.hires_texture(DECK_TABLE_ART), Rect2(Vector2.ZERO, rect.size), true))
	var btn := _make_deck_button(deck_id)
	btn.position = (SLOT_INNER.position + (SLOT_INNER.size - _deck_pile_size()) * 0.5).floor()
	slot.add_child(btn)
	if deck_id == "a":
		deck_a_btn = btn
	else:
		deck_b_btn = btn

# The Reserve box: the painted stone field 9-sliced to the box (no translucent fill
# over it), with the cards centred inside the stone hole. No header/count.
func _build_reserve_panel(parent: Control) -> void:
	var rect: Rect2 = _pick(LAND_RESERVE, PORT_RESERVE)
	var panel := Control.new()
	panel.name = "Reserve"
	panel.z_index = 8
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, rect)
	parent.add_child(panel)
	var frame_data := UiHelpers.trimmed_nine_patch(
		UiHelpers.hires_texture(RESERVE_FIELD_ART), rect.size, RESERVE_FIELD_MARGINS)
	var inner := Rect2(8.0, 8.0, rect.size.x - 16.0, rect.size.y - 16.0)
	if not frame_data.is_empty():
		inner = frame_data["inner"]
		panel.add_child(_make_nine_patch_art("ReserveArt", frame_data, rect))
	reserve_container = Control.new()
	reserve_container.name = "ReserveCards"
	reserve_container.clip_contents = true
	# Use the painted hole, inset a little so cards never touch the ornaments.
	_place(reserve_container, inner.grow(-3.0))
	panel.add_child(reserve_container)

# The Clearing Zone: the painted bar with the 7 slots inside its wooden hole, centred
# on both axes. No title/counter; render() distributes the leftover width into gaps.
func _build_zone_panel(parent: Control) -> void:
	var rect: Rect2 = _pick(LAND_ZONE, PORT_ZONE)
	var zone := Control.new()
	zone.name = "ClearingZone"
	zone.z_index = 8
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(zone, rect)
	parent.add_child(zone)
	var bar_data := _zone_bar_data(rect)
	var inner := Rect2(8.0, 6.0, rect.size.x - 16.0, rect.size.y - 12.0)
	if not bar_data.is_empty():
		zone.add_child(_make_nine_patch_art("ZoneArt", bar_data, rect))
		inner = bar_data["inner"]
	else:
		var fallback := ColorRect.new()
		fallback.name = "ZoneArt"
		fallback.color = Color("#b45f1d")
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(fallback, rect)
		zone.add_child(fallback)
	var card := _zone_card_size()
	var slots_rect := inner.grow(-2.0)
	zone_container = HFlowContainer.new()
	zone_container.name = "ZoneSlots"
	zone_container.alignment = FlowContainer.ALIGNMENT_CENTER
	zone_container.custom_minimum_size = card
	zone_container.add_theme_constant_override("h_separation", 2)
	zone_container.add_theme_constant_override("v_separation", 3)
	_place(zone_container, Rect2(
		slots_rect.position.x,
		slots_rect.position.y + floorf((slots_rect.size.y - card.y) * 0.5),
		slots_rect.size.x,
		card.y))
	zone.add_child(zone_container)

# The power panel: the tall painted board stays vertical in both orientations (no
# 90-degree rotation blur); landscape puts it right of the board, portrait puts it
# as a column on the right, with the three buttons stacked.
func _build_controls(parent: Control) -> void:
	var rect: Rect2 = _pick(LAND_POWERS, PORT_POWERS)
	var panel := Control.new()
	panel.name = "Powers"
	panel.z_index = 8
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, rect)
	parent.add_child(panel)
	var frame_data := UiHelpers.trimmed_nine_patch(
		UiHelpers.hires_texture(POWERS_BOARD_ART), rect.size, POWERS_BOARD_MARGINS)
	var inner: Rect2 = _pick(LAND_POWERS_INNER, PORT_POWERS_INNER)
	if not frame_data.is_empty():
		panel.add_child(_make_nine_patch_art("PowersArt", frame_data, rect))
		inner = frame_data["inner"]
	else:
		var art := UiHelpers.kit_panel("panel_powers", FRAME_MARGIN)
		art.name = "PowersArt"
		_place(art, Rect2(Vector2.ZERO, rect.size))
		panel.add_child(art)
	var box := VBoxContainer.new()
	box.name = "PowerButtons"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	_place(box, inner)
	panel.add_child(box)
	for p in PowerManager.POWERS:
		box.add_child(_make_power_button(p))

# One power: its icon and the "xN" stock side by side; the full name stays in the tooltip.
func _make_power_button(p: String) -> Button:
	var btn := Button.new()
	btn.name = "Power_%s" % p
	btn.custom_minimum_size = POWER_BUTTON_LANDSCAPE
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = _power_name(p)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.12)
	hover.set_corner_radius_all(4)
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
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)

	var icon_size := 33.0
	var icon := TextureRect.new()
	icon.name = "PowerIcon"
	icon.texture = UiHelpers.hires_texture("res://assets/ui/icons/icon_power_%s.png" % p)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size = Vector2(icon_size, icon_size)
	icon.position = Vector2.ZERO
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_box := Control.new()
	icon_box.name = "PowerIconBox"
	icon_box.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_shadow := _make_drop_shadow(
		icon.texture, Rect2(Vector2(1, 2), Vector2(icon_size, icon_size)), 1.5, 0.35)
	if icon_shadow != null:
		icon_box.add_child(icon_shadow)
	icon_box.add_child(icon)
	row.add_child(icon_box)
	var count_lbl := Label.new()
	count_lbl.text = "x0"
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", GOLD)
	UiHelpers.add_text_shadow(count_lbl, 3)
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count_lbl)
	btn.set_meta("count_label", count_lbl)
	return btn

func _make_deck_button(deck_id: String) -> Button:
	var btn := Button.new()
	btn.name = "Deck%sButton" % deck_id.to_upper()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = _deck_pile_size()
	btn.tooltip_text = "%s %s" % [Localizer.t("support_deck"), deck_id.to_upper()]
	_make_flat_button_compact(btn)
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.pressed.connect(_on_deck.bind(deck_id))
	return btn

func _deck_card_size() -> Vector2:
	return DECK_CARD_SIZE

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
		var node := _make_card_button(card, int(depths.get(card.id, 0)), _on_card.bind(card.id), card_size, false)
		var visual_position: Vector2 = grid_positions.get(card.id, Vector2(
			(card.position.x - origin.x) * position_scale.x,
			(card.position.y - origin.y) * position_scale.y
		))
		node.position = _board_node_position(layout, visual_position)
		node.z_index = card.layer
		board_container.add_child(node)

	var zone_card_size := _zone_card_size()
	# Fill the whole bar: distribute the leftover width into equal gaps between slots
	# (the container's ALIGNMENT_CENTER then keeps the row optically centred).
	var slots := maxi(1, controller.clearing_capacity)
	var gap := 2
	if slots > 1:
		var usable: float = zone_container.size.x
		gap = maxi(2, floori((usable - slots * zone_card_size.x) / float(slots - 1)))
	zone_container.add_theme_constant_override("h_separation", gap)
	for i in controller.clearing_capacity:
		if i < controller.zone.cards.size():
			var zone_card: Card = controller.zone.cards[i]
			var display := _make_card_display(zone_card.type, zone_card_size, true)
			# A card still flying in shows up in its slot only when its ghost lands.
			if _hidden_cards.has(zone_card.id):
				display.modulate = Color(1, 1, 1, 0)
			zone_container.add_child(display)
		else:
			zone_container.add_child(_make_empty_slot(zone_card_size, true))
	# Slot rects are read right after a move, in the same frame: lay the slots out now.
	zone_container.notification(Container.NOTIFICATION_SORT_CHILDREN)

	# Any Reserve card can go back to the zone, so every one is a button laid out where it
	# can be seen and tapped (returning only the last one could soft-lock a level).
	var reserve_layout := _reserve_layout(controller.reserve.size())
	var reserve_size: Vector2 = reserve_layout["size"]
	var reserve_positions: Array = reserve_layout["positions"]
	for i in controller.reserve.size():
		var card: Card = controller.reserve[i]
		var node := _make_card_button(card, 0, _on_reserve_return.bind(card.id), reserve_size, true)
		node.position = reserve_positions[i]
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

# Grid for the Reserve cards: the largest card size (down to RESERVE_MIN_CARD_PX) at which
# every card fits the box without overlap; only past that are rows overlapped, keeping a
# tappable strip of each card.
func _reserve_layout(count: int) -> Dictionary:
	var box := reserve_container.size
	var max_size := _reserve_max_card_size()
	if count <= 0 or box.x <= 0.0 or box.y <= 0.0:
		return {"size": max_size, "positions": []}
	var gap := 1.0
	var side := minf(max_size.x, box.y)
	var cols := 1
	var rows := count
	while true:
		cols = maxi(1, floori((box.x + gap) / (side + gap)))
		rows = ceili(float(count) / float(cols))
		if rows * side + (rows - 1) * gap <= box.y or side <= RESERVE_MIN_CARD_PX:
			break
		side -= 1.0
	var step_y := side + gap
	if rows > 1 and rows * side + (rows - 1) * gap > box.y:
		step_y = maxf(side * 0.4, (box.y - side) / float(rows - 1))
	# Centre the whole grid vertically and each row horizontally inside the field.
	var total_h := side + float(rows - 1) * step_y
	var y0 := maxf(0.0, (box.y - total_h) * 0.5)
	var positions: Array = []
	for i in count:
		var row := floori(float(i) / float(cols))
		var col := i % cols
		var in_row := mini(cols, count - row * cols)
		var row_width := in_row * side + float(in_row - 1) * gap
		var row_x0 := maxf(0.0, (box.x - row_width) * 0.5)
		positions.append(Vector2(row_x0 + col * (side + gap), y0 + float(row) * step_y))
	return {"size": Vector2(side, side), "positions": positions}

func _zone_card_size() -> Vector2:
	return LANDSCAPE_ZONE_CARD_SIZE if _is_landscape else PORTRAIT_ZONE_CARD_SIZE

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
	# Portrait has no 44 px bar any more: keep the warning above the footer, never off-screen.
	var warn_y: float = _pick(
		LAND_HUD_HEIGHT,
		maxf(0.0, get_viewport_rect().size.y - _layout_warning.size.y - 8.0))
	_layout_warning.position = Vector2(get_viewport_rect().size.x - _layout_warning.size.x - 8, warn_y)

# `depth` > 0 marks a blocked board card: it is dimmed by the DEPTH_* tables (see
# _dim_material). `shadow` adds the soft drop shadow board cards use so stacked layers read.
# A type with art is drawn as that art alone (it already carries its own frame); the others
# get the coloured panel with the emoji placeholder.
func _make_card_rect(type: String, depth: int, card_size: Vector2, shadow: bool = false, zone_shadow: bool = false) -> Control:
	var root := Panel.new()
	root.custom_minimum_size = card_size
	root.size = card_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	# bg_color always names the type (smoke_rapid_taps reads it back from the zone slots).
	card_style.bg_color = CardTypeRegistry.color(type)
	var has_art := UiHelpers.has_card_art(type)
	if has_art:
		# Painted face: the fill is not drawn and there is no border, rounding or extra
		# shadow, so only the frame painted in the PNG is visible.
		card_style.draw_center = false
		card_style.set_corner_radius_all(0)
		card_style.shadow_size = 0
	else:
		card_style.border_color = Color("#fff2d5")
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(5)
	if (shadow or zone_shadow) and not has_art:
		# Placeholder cards have no alpha silhouette; a soft rounded box shadow is fine.
		card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
		card_style.shadow_size = 2
		card_style.shadow_offset = Vector2(1.0, 2.0)
	root.add_theme_stylebox_override("panel", card_style)
	if (shadow or zone_shadow) and has_art:
		# Painted cards use their own alpha silhouette, never a transparent rectangle.
		var card_tex := UiHelpers.card_texture(type)
		var shadow_tex := UiHelpers.shadow_texture(
			card_tex, 2.0 if zone_shadow else 1.5, 0.35 if zone_shadow else 0.30)
		if shadow_tex != null:
			var shadow_node := Control.new()
			shadow_node.name = "CardShadow"
			shadow_node.custom_minimum_size = card_size
			shadow_node.size = card_size
			shadow_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var shadow_offset := Vector2(2.0, 2.0) if zone_shadow else Vector2(1.0, 2.0)
			shadow_node.draw.connect(func():
				shadow_node.draw_texture_rect(shadow_tex, Rect2(shadow_offset, card_size), false))
			root.add_child(shadow_node)
	var art := _make_card_art(type, card_size)
	root.add_child(art)
	if depth > 0:
		root.material = _dim_material(depth, UiHelpers.has_card_art(type))
		art.use_parent_material = true
	return root

# One shared material per depth (and per art/placeholder kind): brightness and saturation
# come from the DEPTH_* tables.
func _dim_material(depth: int, art: bool = false) -> ShaderMaterial:
	var brightness: Array = ART_DEPTH_BRIGHTNESS if art else DEPTH_BRIGHTNESS
	var saturation: Array = ART_DEPTH_SATURATION if art else DEPTH_SATURATION
	var index := clampi(depth, 0, brightness.size() - 1)
	var key := index + (100 if art else 0)
	if not _dim_materials.has(key):
		if _dim_shader == null:
			_dim_shader = Shader.new()
			_dim_shader.code = DIM_SHADER_CODE
		var material := ShaderMaterial.new()
		material.shader = _dim_shader
		material.set_shader_parameter("brightness", float(brightness[index]))
		material.set_shader_parameter("saturation", float(saturation[index]))
		_dim_materials[key] = material
	return _dim_materials[key]

# Art cards draw the full-resolution face (UiHelpers.card_texture) at the card's size; the GPU
# picks the right mipmap for the physical screen size, so it stays sharp at any window scale.
func _make_card_art(type: String, card_size: Vector2) -> Control:
	var texture := UiHelpers.card_texture(type)
	if texture != null:
		var art := TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		# Full-resolution art scaled by the GPU to the real on-screen size (see card_texture).
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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

func _make_card_display(type: String, card_size: Vector2, zone_shadow: bool = false) -> Control:
	return _make_card_rect(type, 0, card_size, false, zone_shadow)

# `on_zone` draws the painted card frame as the empty selection slot; otherwise it is
# the dark kit slot used by an empty Support Deck.
func _make_empty_slot(card_size: Vector2, on_zone: bool = false) -> Control:
	if on_zone:
		# Cards sit directly on the bar: an empty zone slot is reserved space only.
		# The style keeps the legacy slot contract but draws nothing (no square plate).
		var empty := Panel.new()
		empty.custom_minimum_size = card_size
		empty.size = card_size
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var empty_style := StyleBoxFlat.new()
		empty_style.bg_color = Color(0.48, 0.22, 0.05, 0.34)
		empty_style.draw_center = false
		empty.add_theme_stylebox_override("panel", empty_style)
		return empty
	var slot := Panel.new()
	slot.custom_minimum_size = card_size
	slot.size = card_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The kit's 48 px square, 9-sliced to the slot size and dimmed so cards stand out on it.
	var style := UiHelpers.kit_stylebox("slot_48", 4, 0)
	style.modulate_color = Color(0.62, 0.55, 0.5, 0.75)
	slot.add_theme_stylebox_override("panel", style)
	return slot

# Number of visible card edges: the pile's thickness follows its share of the deck left.
func _pile_edges(deck: DeckManager) -> int:
	var remaining := deck.remaining_count()
	if remaining <= 1:
		return 0
	var total := maxi(deck.card_types.size(), 2)
	var edges := clampi(roundi(float(PILE_MAX_EDGES) * float(remaining - 1) / float(total - 1)), 1, PILE_MAX_EDGES)
	# Never pretend there are more cards than the ones actually left under the top.
	return mini(edges, remaining - 1)

# Draws a deck as a pile: the real faces of the next cards are stacked behind the
# face-up top card, fanning left (deck A) or right (deck B). The top card covers most
# of each lower face, leaving its frame as the visible stacked edge.
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
	# Far cards first, then nearer ones, so the top card covers them naturally.
	for i in range(edges, 0, -1):
		var type_index := deck.current_index + i
		if type_index >= deck.card_types.size():
			continue
		var lower := _make_card_rect(str(deck.card_types[type_index]), 0, card_size)
		lower.position = face_rect.position + Vector2(
			(-1.0 if edges_left else 1.0) * float(i) * PILE_EDGE_STEP, 0.0)
		lower.modulate = Color(1, 1, 1, 1).darkened(0.05 * float(i))
		btn.add_child(lower)
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

# A PanelContainer in the kit's brown window style (help and end panels).
func _make_kit_panel(margin_x: int, margin_top: int, margin_bottom: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := UiHelpers.kit_stylebox("panel_board", FRAME_MARGIN, 0)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_top
	style.content_margin_bottom = margin_bottom
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
	var panel := _make_kit_panel(18, 14, 16)
	panel.theme = UiHelpers.warm_theme()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	# Kit close icon in the panel's top-right corner, next to the Close button below.
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(header)
	var corner_close := TextureButton.new()
	corner_close.name = "HelpCornerClose"
	corner_close.texture_normal = UiHelpers.kit_texture("icon_close_green")
	corner_close.ignore_texture_size = true
	corner_close.stretch_mode = TextureButton.STRETCH_SCALE
	corner_close.custom_minimum_size = Vector2(24, 24)
	corner_close.tooltip_text = Localizer.t("close")
	corner_close.pressed.connect(_close_help)
	header.add_child(corner_close)
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

# --- In-game settings ---------------------------------------------------------------------
# The gear opens the same four settings as the Options screen. Everything applies at once
# through the Game API (and so persists); the level itself is never restarted: language and
# mascot rebuild the screen UI around the live controller, orientation goes through the
# existing resize path, and the overlay is re-created on top of either rebuild.

func _on_settings() -> void:
	if _settings_open or _help_shown or _ended or controller == null:
		return
	_settings_open = true
	controller.pause()
	if mascot != null:
		mascot.hide_bubble()
	_build_settings_overlay()

func _close_settings() -> void:
	var overlay := get_node_or_null("SettingsOverlay")
	if overlay != null:
		overlay.name = "SettingsOverlayClosing"
		overlay.queue_free()
	if not _settings_open:
		return
	_settings_open = false
	if controller != null:
		controller.resume()

func _build_settings_overlay() -> void:
	var overlay := Control.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 900
	add_child(overlay)
	# Tapping the shade also closes, so the overlay can never trap the player.
	var shade := ColorRect.new()
	shade.name = "SettingsShade"
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_settings()
	)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := _make_kit_panel(18, 12, 16)
	panel.name = "SettingsPanel"
	panel.theme = UiHelpers.warm_theme()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6 if _is_landscape else 8)
	panel.add_child(col)
	# Heading with the kit's green close icon in the top-right corner.
	var header := HBoxContainer.new()
	col.add_child(header)
	var heading := Label.new()
	heading.text = Localizer.t("settings")
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", TEXT_PRIMARY)
	header.add_child(heading)
	var corner_close := TextureButton.new()
	corner_close.name = "SettingsCornerClose"
	corner_close.texture_normal = UiHelpers.kit_texture("icon_close_green")
	corner_close.ignore_texture_size = true
	corner_close.stretch_mode = TextureButton.STRETCH_SCALE
	corner_close.custom_minimum_size = Vector2(24, 24)
	corner_close.tooltip_text = Localizer.t("close")
	corner_close.pressed.connect(_close_settings)
	header.add_child(corner_close)
	var row_height := 34 if _is_landscape else 42
	col.add_child(_make_settings_row("LanguageButton", Localizer.t("language"), _on_settings_language, row_height))
	col.add_child(_make_settings_row("OrientationButton", _settings_orientation_text(), _on_settings_orientation, row_height))
	col.add_child(_make_settings_row("MascotButton", _settings_mascot_text(), _on_settings_mascot, row_height))
	var volume := VolumeRow.new(row_height)
	volume.changed.connect(_refresh_sound_icon)
	col.add_child(volume)
	var close := Button.new()
	close.name = "SettingsClose"
	close.text = Localizer.t("close")
	close.custom_minimum_size = Vector2(120, 32)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_settings)
	col.add_child(close)

func _make_settings_row(node_name: String, text: String, callback: Callable, height: int) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = text
	btn.custom_minimum_size = Vector2(280, height)
	btn.pressed.connect(callback)
	UiHelpers.apply_plate_style(btn)
	return btn

func _settings_orientation_text() -> String:
	var current := "landscape" if str(Game.settings.get("orientation", "portrait")) == "landscape" else "portrait"
	return "%s: %s" % [Localizer.t("orientation_label"), Localizer.t(current)]

func _settings_mascot_text() -> String:
	return "%s: %s" % [Localizer.t("mascot_label"), Localizer.t("option_on" if Game.mascot_enabled() else "option_off")]

func _on_settings_language() -> void:
	Game.set_locale("en" if Localizer.current == "pt" else "pt")
	_rebuild_for_settings()

func _on_settings_mascot() -> void:
	Game.set_mascot(not Game.mascot_enabled())
	_rebuild_for_settings()

# The window changes shape: the existing resize path (_on_resized) rebuilds the screen, and
# _build_ui re-creates this overlay on top of it.
func _on_settings_orientation() -> void:
	Game.set_orientation(str(Game.settings.get("orientation", "portrait")) != "landscape")

# Rebuilds the screen UI around the live controller (state untouched) and redraws the board.
func _rebuild_for_settings() -> void:
	_build_ui()
	render()
	# Ace's area is only laid out a couple of frames later: draw once more by then.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree() and controller != null:
		render()

func _refresh_sound_icon() -> void:
	if _sound_icon != null and is_instance_valid(_sound_icon):
		_sound_icon.texture = _sound_texture()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _help_shown:
			_close_help()
			get_viewport().set_input_as_handled()
		elif _settings_open:
			_close_settings()
			get_viewport().set_input_as_handled()

# --- Moves --------------------------------------------------------------------------------
# A tap goes to the controller immediately, whatever is still animating: state is the source
# of truth and the visuals (ghost flights, match flash) catch up on top of it.

func _flash_zone_full() -> void:
	var panel := find_child("ClearingZone", true, false) as Control
	if panel == null:
		return
	var t := panel.create_tween()
	t.tween_property(panel, "modulate", Color(1.0, 0.55, 0.5), 0.08)
	t.tween_property(panel, "modulate", Color.WHITE, 0.3)

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
		# A refused tap must never look like a frozen game: say why when the zone is full.
		if controller.status == GameController.Status.PLAYING and controller.zone.is_full():
			_flash_zone_full()
			_say("zone_warning")
		_check_end()
		return
	_play_sfx("select")
	var matched: Array = result["matched_ids"]
	# Score right away: a winning move ends the round once its flash has played.
	_record_endless_match(matched.size())
	var snap_ids: Array = snap["ids"]
	var snap_rects: Array = snap["rects"]
	var target_index := int(result.get("zone_index", -1))
	if target_index < 0:
		target_index = _zone_insertion_index(snap["types"], card_type)
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
	_animate_zone_reorder(snap, group)
	var warn := matched.is_empty() and controller.zone.size() == controller.clearing_capacity - 1
	_launch_flight(card_id, card_type, source_rect, target, group, warn)
	_check_end()

# Where a card of `card_type` goes: right after the last card of its kind, else at the end.
func _zone_insertion_index(types: Array, card_type: String) -> int:
	var index := types.size()
	for i in types.size():
		if str(types[i]) == card_type:
			index = i + 1
	return index

# Id of the card a deck draw just put in the zone (it is gone again if it matched).
func _drawn_card_id(snap_ids: Array, matched: Array, target_index: int) -> String:
	if matched.is_empty():
		if target_index >= 0 and target_index < controller.zone.cards.size():
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
	_shifts.clear()
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
	_clear_shifts()
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

func _zone_child_rect(index: int) -> Rect2:
	if index >= 0 and index < zone_container.get_child_count():
		return (zone_container.get_child(index) as Control).get_global_rect()
	return Rect2(zone_container.global_position, _zone_card_size())

func _hide_zone_card(card_id: String) -> void:
	var index := _zone_index_of(card_id)
	if index >= 0 and index < zone_container.get_child_count():
		(zone_container.get_child(index) as Control).modulate = Color(1, 1, 1, 0)

func _show_zone_card(card_id: String) -> void:
	var index := _zone_index_of(card_id)
	if index >= 0 and index < zone_container.get_child_count():
		(zone_container.get_child(index) as Control).modulate = Color.WHITE

# Every card the move pushed to another slot gets a ghost that walks to it: cards right of the
# fresh gap slide while the new card flies in, and the cards the removal frees up wait for the
# flash, then hop left and drop into their slot with an impact.
func _animate_zone_reorder(snap: Dictionary, group: MatchGroup) -> void:
	var ids: Array = snap["ids"]
	var rects: Array = snap["rects"]
	for i in controller.zone.cards.size():
		var card: Card = controller.zone.cards[i]
		var old_index := ids.find(card.id)
		if old_index < 0 or old_index == i or i >= zone_container.get_child_count():
			continue
		if _flights.has(card.id) or old_index >= rects.size():
			continue
		var shift := _make_shift(card, rects[old_index], _zone_child_rect(i), old_index > i)
		if shift == null:
			continue
		if group != null:
			group.shifts.append(shift)
		else:
			_start_shift(shift, 0.0)

func _make_shift(card: Card, from: Rect2, to: Rect2, hop: bool) -> ZoneShift:
	var size := to.size if to.size.x > 0.0 else from.size
	if size.x <= 0.0 or from.size.x <= 0.0:
		return null
	var ghost := _make_card_rect(card.type, 0, size)
	_fx().add_child(ghost)
	ghost.global_position = from.position
	var shift := ZoneShift.new()
	shift.card_id = card.id
	shift.ghost = ghost
	shift.from = from
	shift.to = to
	shift.lift = maxf(8.0, size.y * ZONE_HOP_LIFT_RATIO) if hop else 0.0
	_hidden_cards[card.id] = true
	_hide_zone_card(card.id)
	_shifts.append(shift)
	return shift

func _start_shift(shift: ZoneShift, delay: float) -> void:
	if shift == null or shift.ghost == null or not is_instance_valid(shift.ghost):
		return
	var tween := shift.ghost.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(_step_shift.bind(shift), 0.0, 1.0, ZONE_HOP_SECONDS if shift.lift > 0.0 else ZONE_SHIFT_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_land_shift.bind(shift))

func _step_shift(progress: float, shift: ZoneShift) -> void:
	if shift.ghost == null or not is_instance_valid(shift.ghost):
		return
	var pos := shift.from.position.lerp(shift.to.position, progress)
	if shift.lift > 0.0:
		pos.y -= shift.lift * sin(progress * PI)
	shift.ghost.global_position = pos

func _land_shift(shift: ZoneShift) -> void:
	_shifts.erase(shift)
	_hidden_cards.erase(shift.card_id)
	_show_zone_card(shift.card_id)
	if shift.lift > 0.0:
		_play_card_impact(shift.to.get_center())
	_drop_fx_node(shift.ghost)

func _clear_shifts() -> void:
	for shift: ZoneShift in _shifts.duplicate():
		_drop_fx_node(shift.ghost)
	_shifts.clear()

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
	for node: Control in group.nodes:
		if not is_instance_valid(node):
			continue
		var fade := node.create_tween()
		fade.tween_property(node, "modulate:a", 0.0, MATCH_FADE_SECONDS).set_delay(0.08)
		fade.tween_callback(node.queue_free)
	for shift: ZoneShift in group.shifts:
		_start_shift(shift, ZONE_HOP_DELAY)
	group.shifts.clear()
	# One burst + smoke per matched card, scaled to that card (not one central FX).
	for rect: Rect2 in group.rects:
		_play_match_burst(rect.get_center(), rect.size.x)

# Painted burst + smoke over one matched card, played as the three cards fade.
# Kept short and entirely on the FX layer so rapid taps never wait for it.
func _play_match_burst(center: Vector2, card_side: float) -> void:
	var side := maxf(72.0, card_side * MATCH_FX_CARD_SPAN)
	# Same card centre for both layers: no vertical offset, delay or spin.
	_spawn_match_fx(MATCH_BURST_ART, center, side, 0.15, 1.08)
	_spawn_match_fx(MATCH_SMOKE_ART, center, side * 1.14, 0.15, 1.12)

# The painted FX files carry wide transparent margins, so centring the whole texture rect
# made the visible puff sit visibly above the card. This returns the alpha bounding box
# (the visible picture) in texture px, cached per texture.
static func _fx_optical_rect(texture: Texture2D) -> Rect2:
	var key := texture.resource_path
	if key == "":
		key = str(texture.get_rid())
	if _fx_optical_cache.has(key):
		return _fx_optical_cache[key]
	var used := Rect2(Vector2.ZERO, texture.get_size())
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		# Sample the alpha on a grid: the files carry a near-invisible 1-4/255 border, so
		# Image.get_used_rect() (alpha > 0) still reports the whole file.
		var w := image.get_width()
		var h := image.get_height()
		var step := maxi(1, int(minf(float(w), float(h)) / 96.0))
		var min_x := w
		var min_y := h
		var max_x := -1
		var max_y := -1
		for y in range(0, h, step):
			for x in range(0, w, step):
				if image.get_pixel(x, y).a > 0.02:
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
		if max_x >= min_x and max_y >= min_y:
			used = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + step, max_y - min_y + step))
	_fx_optical_cache[key] = used
	return used

func _spawn_match_fx(path: String, center: Vector2, side: float, start_scale: float, end_scale: float) -> void:
	var texture := UiHelpers.hires_texture(path)
	if texture == null:
		return
	# Draw only the visible alpha box and centre THAT on the card centre.
	var optical := _fx_optical_rect(texture)
	var aspect := optical.size.x / maxf(1.0, optical.size.y)
	var drawn := Vector2(side, side / aspect) if aspect >= 1.0 else Vector2(side * aspect, side)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = optical
	var node := TextureRect.new()
	node.texture = atlas
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.size = drawn
	node.pivot_offset = drawn * 0.5
	node.modulate = Color(1, 1, 1, 0)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx().add_child(node)
	# Put the pivot (the visible centre) on the card centre while the node is still at scale 1,
	# then scale around it: the FX expands in place and can never drift off the card.
	node.global_position = center - drawn * 0.5
	node.scale = Vector2(start_scale, start_scale)
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, 0.05)
	tween.tween_property(node, "scale", Vector2(end_scale, end_scale), MATCH_FX_SECONDS)
	tween.chain().tween_property(node, "modulate:a", 0.0, 0.20)
	tween.chain().tween_callback(node.queue_free)

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
	if not Game.sound_enabled():
		return
	if _sfx_player == null or not is_instance_valid(_sfx_player):
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "PlaceholderSfx"
		add_child(_sfx_player)
	_sfx_player.volume_db = linear_to_db(Game.volume())
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
		"puff":
			frequency = 260.0
			duration = 0.12
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
	# Landscape is only 360 px tall: a smaller number leaves room for the stars plaque.
	stage_num.add_theme_font_size_override("font_size", 32 if _is_landscape else 40)
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
		_add_end_stars(info)

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
	# The result takes the whole screen: the HUD row would only peek out behind the stars.
	var hud := find_child("Hud", true, false) as Control
	if hud != null:
		hud.visible = false

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

	# The column centers the panel with the earned stars plaque riding on its top edge.
	var column := VBoxContainer.new()
	column.name = "EndColumn"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	center.add_child(column)

	var panel := _make_kit_panel(22, 16, 18)
	panel.name = "EndPanel"
	panel.custom_minimum_size = Vector2(240, 0)
	panel.theme = UiHelpers.warm_theme()
	column.add_child(panel)

	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	# Landscape is only 360 px tall: tighten the rows to make room for Ace's line.
	info.add_theme_constant_override("separation", 3 if _is_landscape and Game.mascot_enabled() else 6)
	panel.add_child(info)
	return info

# The earned stars plaque, sitting on top of the result panel and straddling its edge.
func _add_end_stars(info: Container) -> void:
	var plaque := TextureRect.new()
	plaque.name = "EndStars"
	plaque.texture = UiHelpers.hud_texture(STARS_PATH_FORMAT % clampi(controller.stars, 1, 3))
	plaque.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaque.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	plaque.custom_minimum_size = END_PLAQUE_LANDSCAPE if _is_landscape else END_PLAQUE_PORTRAIT
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.pivot_offset = plaque.custom_minimum_size * 0.5
	plaque.modulate = Color(1, 1, 1, 0)
	plaque.scale = Vector2(0.3, 0.3)
	var column := info.get_parent().get_parent() as VBoxContainer
	if column == null:
		return
	column.add_child(plaque)
	column.move_child(plaque, 0)
	# The stars sit in front of the panel, over its top edge.
	plaque.z_index = 2
	column.add_theme_constant_override("separation", -roundi(plaque.custom_minimum_size.y * float(_pick(END_STARS_OVERLAP_LANDSCAPE, END_STARS_OVERLAP_PORTRAIT))))
	if _is_landscape:
		# The plaque eats into the short landscape screen: tighten the rows to keep it inside.
		var sep := info.get_theme_constant("separation")
		info.add_theme_constant_override("separation", maxi(1, sep - 2))
	_reveal_plaque(plaque)

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
	# End-panel portrait keeps the 2:3 hero aspect, just smaller than the in-game one.
	ace.custom_minimum_size = Vector2(36, 54)
	ace.size = Vector2(36, 54)
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

# The earned plaque pops in with a little overshoot.
func _reveal_plaque(plaque: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(plaque):
		return
	var t := plaque.create_tween()
	t.set_parallel(true)
	t.tween_property(plaque, "modulate", Color.WHITE, 0.2)
	t.tween_property(plaque, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	# A rebuild (settings change) during the intro frees the overlay with everything else.
	if not is_instance_valid(overlay) or not is_instance_valid(title):
		_say_instruction()
		return
	var fade := create_tween()
	fade.tween_property(title, "modulate:a", 0.0, 0.2)
	await fade.finished
	if is_instance_valid(overlay):
		overlay.queue_free()
	_say_instruction()
	# After the how-to line, the hero says one neutral intro line (hero_intro_*).
	# Skip it if a match/warning bubble is already showing or the level ended.
	await get_tree().create_timer(INSTRUCTION_SECONDS + 0.25).timeout
	if _ended or not is_inside_tree() or mascot == null or not is_instance_valid(mascot):
		return
	if not mascot.bubble_global_rect().has_area():
		mascot.say("intro")

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

# The wooden plaque with three stars (campaign HUD). Base = the state kept so far; the overlay
# is the next-lower state, faded in as the star at stake turns to stone.
func _build_stars_plaque(hud: Control) -> void:
	var rect: Rect2 = _pick(LAND_PLAQUE, PORT_PLAQUE)
	stars_row = Control.new()
	stars_row.name = "StarsPill"
	stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(stars_row, rect)
	stars_row.pivot_offset = rect.size * 0.5
	var plaque_shadow := _make_drop_shadow(
		UiHelpers.hud_texture(STARS_PATH_FORMAT % 3),
		Rect2(rect.position + Vector2(1, 1), rect.size), 3.0, 0.35)
	if plaque_shadow != null:
		hud.add_child(plaque_shadow)
	hud.add_child(stars_row)
	var full := Rect2(Vector2.ZERO, rect.size)
	stars_base = _make_art("StarsBase", UiHelpers.hud_texture(STARS_PATH_FORMAT % 3), full, true)
	stars_row.add_child(stars_base)
	stars_overlay = _make_art("StarsOverlay", UiHelpers.hud_texture(STARS_PATH_FORMAT % 2), full, true)
	stars_overlay.modulate.a = 0.0
	stars_row.add_child(stars_overlay)
	# -1 = not synced yet: the first update shows the right state with no puff.
	stars_shown = -1

# Fraction of the current star's time window already used (0 = fresh, 1 = about to puff).
# Star 3 burns from 0 s to three_stars, star 2 from three_stars to two_stars.
func _star_burn(elapsed: float, stars: int) -> float:
	var three: float = float(controller.time_thresholds.get("three_stars", INF))
	var two: float = float(controller.time_thresholds.get("two_stars", INF))
	# Stars count whole seconds like the clock, so a star really goes one second after its
	# threshold: burn over that whole window so it is fully dark exactly when it puffs.
	var start := 0.0 if stars == 3 else three + 1.0
	var finish := (three if stars == 3 else two) + 1.0
	if is_inf(finish) or finish <= start:
		return 0.0
	return clampf((elapsed - start) / (finish - start), 0.0, 1.0)

func _update_live_stars() -> void:
	if stars_row == null or stars_base == null or not is_instance_valid(stars_base):
		return
	var elapsed := controller.timer.elapsed_seconds()
	var playing := controller.status == GameController.Status.PLAYING
	var stars: int = controller.stars if controller.status == GameController.Status.WON else controller.calculate_stars(elapsed)
	stars = clampi(stars, 1, 3)
	if stars_shown < 0:
		# First sync (new screen or rebuild): stars already lost are just stone, no puff.
		stars_shown = stars
		stars_base.texture = UiHelpers.hud_texture(STARS_PATH_FORMAT % stars)
	elif stars < stars_shown:
		# The star at stake passed its threshold: puff at its place, then show the lower state.
		for index in range(stars, stars_shown):
			_puff_star(index)
		stars_shown = stars
		stars_base.texture = UiHelpers.hud_texture(STARS_PATH_FORMAT % stars)
	var burn := 0.0
	if stars > 1 and playing:
		burn = _star_burn(elapsed, stars)
	if stars > 1:
		stars_overlay.texture = UiHelpers.hud_texture(STARS_PATH_FORMAT % (stars - 1))
	stars_overlay.modulate.a = burn
	stars_overlay.visible = burn > 0.0 and stars > 1

# Global centre of star `index` (0-2) on the plaque.
func _plaque_star_center(index: int) -> Vector2:
	return stars_row.global_position + Vector2(stars_row.size.x * float(PLAQUE_STAR_X[index]), stars_row.size.y * PLAQUE_STAR_Y)

# The star that just turned to stone: the plaque pops, a small flash and puff of smoke are left
# at that star's place (overlay only).
func _puff_star(index: int) -> void:
	var center := _plaque_star_center(index)
	var pop := stars_row.create_tween()
	pop.tween_property(stars_row, "scale", Vector2(1.12, 1.12), 0.09)
	pop.tween_property(stars_row, "scale", Vector2.ONE, 0.16)
	_play_sfx("puff")
	var fx := _fx()
	var flash := UiHelpers.symbol_label("✦", 22)
	flash.size = Vector2(22, 22)
	flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flash.modulate = Color(1, 0.95, 0.8, 0.95)
	flash.pivot_offset = Vector2(11, 11)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(flash)
	flash.global_position = center - Vector2(11, 11)
	var burst := flash.create_tween()
	burst.set_parallel(true)
	burst.tween_property(flash, "scale", Vector2(1.7, 1.7), 0.18)
	burst.tween_property(flash, "modulate:a", 0.0, 0.18)
	burst.chain().tween_callback(flash.queue_free)
	for i in STAR_PUFF_COUNT:
		var puff := Panel.new()
		puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.86, 0.84, 0.80, 0.92)
		style.set_corner_radius_all(4)
		puff.add_theme_stylebox_override("panel", style)
		puff.size = Vector2(7, 7)
		puff.pivot_offset = puff.size * 0.5
		puff.global_position = center - puff.size * 0.5
		fx.add_child(puff)
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(STAR_PUFF_COUNT) + randf_range(-0.3, 0.3))
		var drift := puff.create_tween()
		drift.set_parallel(true)
		drift.tween_property(puff, "position", puff.position + dir * randf_range(10.0, 15.0), 0.42).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		drift.tween_property(puff, "scale", Vector2.ONE * randf_range(1.6, 2.2), 0.42)
		drift.tween_property(puff, "modulate:a", 0.0, 0.42).set_ease(Tween.EASE_IN)
		# A rebuild mid-puff frees the overlay first; never touch a freed puff.
		drift.chain().tween_callback(func():
			if is_instance_valid(puff):
				puff.queue_free()
		)
