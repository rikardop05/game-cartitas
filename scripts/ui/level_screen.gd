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
# Extend the shade underneath the painted bevel so transparent edge antialiasing never
# leaves a bright seam between the board interior and the frame.
const BOARD_SHADE_OVERDRAW := 0.0
# The cards sit this many px inside the window's drawn frame.
const BOARD_PAD := 2.0
# Thickest painted border drawn around the board, in logical px. The frame PNG is
# alpha-cropped to its visible box and 9-sliced; capping the border keeps the thick
# painted bevel from eating the play area. Drop the cleaned art's 9-slice margin here
# once the Atelie delivers it.
const BOARD_FRAME_BORDER_MAX := 12.0
# The portrait window has its own painted frame (near-square art). It is baked once to the
# exact 339x196 window with the border squeezed into the same 6/5 px band the landscape frame
# shows, so the play hole stays Luna's 327x185 (board 323x181).
const BOARD_FRAME_PORTRAIT_ART := "res://assets/ui/kit/panel_board_frame_portrait.png"
# Painted UI pieces delivered by the Atelie. Margins are fractions of the cropped
# texture and keep the carved corners/ornaments from being cut by the 9-slice.
const RESERVE_FIELD_ART := "res://assets/ui/kit/panel_reserve_field.png"
const RESERVE_FIELD_MARGINS := Rect2(0.07, 0.11, 0.07, 0.11)
const POWERS_BOARD_ART := "res://assets/ui/kit/panel_powers_board.png"
const POWERS_BOARD_MARGINS := Rect2(0.09, 0.05, 0.09, 0.05)
# The square wooden plate is the table under each Support Deck's pile.
const DECK_TABLE_ART := "res://assets/ui/kit/v2/card_available_frame.png"
const MATCH_BURST_ART := "res://assets/ui/fx/match_burst.png"
const MATCH_SMOKE_ART := "res://assets/ui/fx/match_smoke.png"
const MATCH_FX_CARD_SPAN := 2.0
const MATCH_FX_SECONDS := 0.34
# The Clearing Zone bar's painted body inside its file (the file has wide transparent margins)
# and the share of the width its carved end caps take when 9-sliced.
const ZONE_BAR_ART := "res://assets/ui/kit/v2/bar_zone.png"
# Fractions of the cropped bar: the dark bevel and the carved end caps stay intact,
# the slots sit inside the wooden hole.
const ZONE_BAR_MARGINS := Rect2(0.08, 0.10, 0.08, 0.10)
# Endless uses the autumn background like the later Levels.
const ENDLESS_BACKGROUND_LEVEL := 999
# Frame thickness (source px) when a kit panel is 9-sliced: border plus its shadow line.
const FRAME_MARGIN := 7
# v2 art kit. Both board frames, the zone bar, deck table, HUD icons and settings header
# use imported full-resolution art with mipmaps; decorative frames are oversampled 9-slices.
const V2_KIT_DIR := "res://assets/ui/kit/v2/"
const V2_BOARD_FRAME_ART := V2_KIT_DIR + "panel_board_frame.png"
const V2_ZONE_BAR_ART := V2_KIT_DIR + "bar_zone.png"
const V2_DECK_TABLE_ART := V2_KIT_DIR + "card_available_frame.png"
const V2_GEAR_ART := V2_KIT_DIR + "Config_Icon.png"
const V2_HELP_ART := V2_KIT_DIR + "interrog.png"
const V2_SETTINGS_TITLE_ART := {"pt": "config_2.png", "en": "Configu.png"}
const V2_OPTIONS_PANEL_ART := V2_KIT_DIR + "panel_options.png"
const V2_OPTIONS_PANEL_ASPECT := 1227.0 / 1202.0
const V2_CONFIG_ROW_ART := [
	V2_KIT_DIR + "config_row_1.png",
	V2_KIT_DIR + "config_row_2.png",
	V2_KIT_DIR + "config_row_3.png",
]
const V2_ACCEPT_ART := V2_KIT_DIR + "icon_accept_v2.png"
const V2_CLOSE_ART := V2_KIT_DIR + "icon_close_v2.png"


const LOGO_ART := "res://assets/ui/branding/logo_claw_and_crown.png"
const BACK_ARROW_ART := "res://assets/ui/kit/v2/icon_back.png"
const BACK_ARROW_REGION := Rect2(235.0, 105.0, 725.0, 1045.0)
const CLOCK_PLANK_ART := "res://assets/ui/hud/clock_plank.png"
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
# The v2 plates replace the old text buttons on the end panel. The v2 kit only has an
# English "EXIT"/"NEW GAME" pair, so PT keeps the matching v2 menu plates (SAIR/INICIAR)
# instead of showing English over a Portuguese result.
const END_CONTINUE_ART := {"pt": "Continuar_.png", "en": "Layer 2.png"}
const END_NEW_GAME_ART := {"pt": "Iniciar).png", "en": "Layer 3.png"}
const END_EXIT_ART := {"pt": "sair_.png", "en": "Layer 1.png"}
# Defeat screen: a full-screen result composition. The stone window is nearly square; the
# character is drawn behind it, large enough to read around its edges without covering the
# two localised plates. Both rects are logical px (360x640 portrait / 640x360 landscape).
const DEFEAT_DIR := "res://assets/ui/defeat/"
const DEFEAT_PANEL_ART := DEFEAT_DIR + "defeat_panel.png"
const DEFEAT_TITLE_ART := {"pt": "defeat_title_pt.png", "en": "defeat_title_en.png"}
const DEFEAT_RETRY_ART := {"pt": "defeat_retry_pt.png", "en": "defeat_retry_en.png"}
const DEFEAT_QUIT_ART := {"pt": "defeat_quit_pt.png", "en": "defeat_quit_en.png"}
const DEFEAT_PANEL_LANDSCAPE := Rect2(348, 48, 268, 275)
const DEFEAT_PANEL_PORTRAIT := Rect2(45, 180, 270, 276)
# The result overlay sits above the whole stage, HUD included, so the shade dims everything.
const DEFEAT_OVERLAY_Z := 1100
const VICTORY_DIR := "res://assets/ui/victory/"
const VICTORY_BOARD_ART := VICTORY_DIR + "victory_board.png"
const VICTORY_BUNNY_ART := VICTORY_DIR + "victory_bunny.png"
const VICTORY_TITLE_ART := {"pt": "victory_title_pt.png", "en": "victory_title_en.png"}
const VICTORY_RETRY_ART := {"pt": "victory_retry_pt.png", "en": "victory_retry_en.png"}
# The zone row fills the whole bar: 7 large slots with a computed step. The cards float
# slightly above the painted surface; when 7 do not fit, the step is negative (overlap).
const LANDSCAPE_RESERVE_CARD_SIZE := Vector2(34.0, 34.0)
const PORTRAIT_RESERVE_CARD_SIZE := Vector2(42.0, 42.0)
const DECK_CARD_SIZE := Vector2(42.0, 42.0)
# A Support Deck is a pile: one face-up card plus up to PILE_MAX_EDGES card edges.
# 42 + 3*4 = 54 = the visible deck-pile width inside the responsive stone slot.
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

# Card juice (Balatro-style, shader scripts/ui/card_juice.gdshader; credits in docs/CREDITS.md).
# Board + deck cards: perspective tilt following the pointer, a small scale pop and a shine
# sweep, on the ONE card under the pointer/finger. Clearing Zone cards: idle sway + foil shine.
const JUICE_SHADER := preload("res://scripts/ui/card_juice.gdshader")
const JUICE_MAX_TILT_DEG := 14.0      # tilt at the card edge
const JUICE_HOVER_SCALE := 1.06
const JUICE_SHINE := 1.0              # 0 = off
const JUICE_FOV := 50.0
const JUICE_POP_SECONDS := 0.14
const JUICE_RETURN_SECONDS := 0.30
const JUICE_SHADOW_SHIFT := 2.5       # px the shadow slides opposite to the tilt
const ZONE_SWAY_DEG := 4.0            # idle wobble amplitude
const ZONE_HOLO := 0.6                # foil strength, 0 = off

static var _dim_shader: Shader
static var _dim_materials := {}
static var _back_arrow_cache: Texture2D
# Visible (alpha bbox) rect of each painted FX inside its texture, in texture px.
static var _fx_optical_cache := {}
var _layout: Dictionary = {}

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
var _timer_display_second := -1
var _timer_warning_applied := false
# Live stars: the stars plaque (campaign only; null in Endless). Its base picture shows the stars
# kept so far; the star at stake turns to stone gradually (an overlay of the next-lower picture
# fades in) and puffs away once its threshold passes. The first star never turns to stone (a
# win earns at least one). stars_row is the "StarsPill" node itself.
var stars_row: Control
var stars_base: TextureRect
var stars_overlay: TextureRect
# Stars still gold on the plaque (3, 2 or 1), -1 until the first sync after a (re)build.
var stars_shown := -1
var _star_overlay_index := -1
var _star_burn_state := -1
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
var _board_nodes: Dictionary = {}
var _zone_nodes: Dictionary = {}
var _reserve_nodes: Dictionary = {}
var _blocker_cache: Dictionary = {}
var _blocker_cache_signature := ""
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
	_prewarm_level_shadows()
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
		var shown_second := floori(controller.time_remaining()) if controller.time_limit > 0.0 else floori(controller.timer.elapsed_seconds())
		if shown_second != _timer_display_second and timer_label != null:
			timer_label.text = _timer_text()
			_timer_display_second = shown_second
		_timer_warning(controller.time_remaining())
	_update_live_stars()
	if controller.status != GameController.Status.PLAYING and not _ended:
		_check_end()

func _timer_text() -> String:
	if controller.time_limit > 0.0:
		return _format_time(maxf(0.0, controller.time_remaining()))
	return _format_time(controller.timer.elapsed_seconds())

func _timer_warning(remaining: float) -> void:
	if timer_label == null:
		return
	var warning := controller.time_limit > 0.0 and remaining <= 10.0
	if warning == _timer_warning_applied:
		return
	_timer_warning_applied = warning
	timer_label.add_theme_color_override(
		"font_color", Color("#ff6b5e") if warning else TEXT_PRIMARY)

func _on_resized() -> void:
	if controller == null or _ended:
		return
	# `expand` can change the viewport dimensions without changing orientation. Rebuild all
	# computed rects after the new expanded viewport has settled, preserving controller state.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_build_ui()
	await get_tree().process_frame
	if not is_inside_tree() or controller == null:
		return
	render()

func _build_ui() -> void:
	_is_landscape = _viewport_is_landscape()
	_layout = LevelLayout.compute(get_viewport_rect().size)
	_prewarm_layout_frames()
	# The rebuild frees the help overlay too, so undo the pause it applied.
	if _help_shown and controller != null:
		controller.resume()
	_help_shown = false
	power_buttons.clear()
	_board_nodes.clear()
	_zone_nodes.clear()
	_reserve_nodes.clear()
	_mascot_area = null
	_instruction_bubble = null
	_sound_icon = null
	# The rebuild frees every child, ghosts included; render() re-syncs the zone afterwards.
	_fx_layer = null
	_flights.clear()
	_hidden_cards.clear()
	_layout_cache = {}
	_timer_display_second = -1
	_timer_warning_applied = false
	stars_shown = -1
	_star_overlay_index = -1
	_star_burn_state = -1
	for child in get_children():
		remove_child(child)
		child.queue_free()
	# Any node held across rebuilds is gone now.
	_sfx_player = null
	_layout_warning = null

	add_child(UiHelpers.make_background(_is_landscape, _background_level()))

	# Every piece is positioned from the expanded logical viewport returned by LevelLayout.
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
	_place(_mascot_area, _rect("mascot_area"))
	layout.add_child(_mascot_area)
	_build_mascot()
	_fx()
	# The settings overlay survives a rebuild (language, orientation, mascot): it is rebuilt on
	# top of the new screen and the clock stays paused underneath.
	if _settings_open:
		_build_settings_overlay()

func _prewarm_layout_frames() -> void:
	# Decode, crop and bake every layout-dependent painted panel before the first game render.
	var board_rect := _rect("board_frame")
	var board_path := V2_BOARD_FRAME_ART if _is_landscape else BOARD_FRAME_PORTRAIT_ART
	UiHelpers.alpha_nine_patch(
		UiHelpers.hires_texture(board_path), board_rect.size, BOARD_FRAME_BORDER_MAX)
	UiHelpers.trimmed_nine_patch(
		UiHelpers.hires_texture(RESERVE_FIELD_ART), _rect("reserve").size,
		RESERVE_FIELD_MARGINS, "", true)
	_zone_bar_data(_rect("zone"))
	var powers_texture := UiHelpers.hires_texture(POWERS_BOARD_ART)
	var powers_margins := POWERS_BOARD_MARGINS
	if not _is_landscape:
		powers_texture = UiHelpers.rotated_texture(POWERS_BOARD_ART)
		powers_margins = Rect2(
			POWERS_BOARD_MARGINS.position.y, POWERS_BOARD_MARGINS.position.x,
			POWERS_BOARD_MARGINS.size.y, POWERS_BOARD_MARGINS.size.x)
	UiHelpers.trimmed_nine_patch(
		powers_texture, _rect("powers").size, powers_margins)

func _prewarm_level_shadows() -> void:
	# Card PNG decoding and alpha blurs are paid during level load, never on the first tap.
	var card_types: Dictionary = {}
	for card in controller.board.cards:
		if card.source == Card.Source.BOARD:
			card_types[card.type] = true
	for card_type in controller.deck_a.card_types:
		card_types[str(card_type)] = true
	for card_type in controller.deck_b.card_types:
		card_types[str(card_type)] = true
	for card_type in card_types:
		var texture := UiHelpers.card_texture(str(card_type))
		if texture == null:
			continue
		UiHelpers.shadow_texture(texture, 1.5, 0.30)
		UiHelpers.shadow_texture(texture, 2.4, 0.42)

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
	mascot.z_index = LevelLayout.HERO_Z
	mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		# Portrait: the hero stands on the left edge (partly off-screen), in front of the board
		# frame and behind the deck/powers/zone panels; the cards start to her right.
		var hero := _portrait_hero_rect()
		var scale_to_fit := minf(hero.size.x / Mascot.BASE_SIZE.x, hero.size.y / Mascot.BASE_SIZE.y)
		mascot.size = Mascot.BASE_SIZE * scale_to_fit
		mascot.global_position = Vector2(hero.position.x, hero.end.y - mascot.size.y) + get_global_rect().position
		mascot.side_bubble_bounds = Rect2()
		mascot.free_bounds = _rect("instruction_area")
	mascot.visible = not _ended

# Portrait hero box (may extend off the left edge); empty in landscape or without the mascot.
func _portrait_hero_rect() -> Rect2:
	if _is_landscape or not Game.mascot_enabled():
		return Rect2()
	return _layout.get("hero_rect", Rect2())

func _say(event: String, context: Dictionary = {}) -> void:
	if mascot != null and not _ended:
		mascot.say(event, context)

# The how-to-play line shown at the start of a Level or Round: Ace says it in its bubble;
# with the mascot turned off a standalone bubble in the same free area shows it instead.
# Both go away by themselves after INSTRUCTION_SECONDS, so the board is never covered.
func _say_instruction() -> void:
	if _ended or _settings_open:
		return
	var text := Localizer.t("instruction")
	if mascot != null:
		mascot.say_text(text, INSTRUCTION_SECONDS, "instruction")
	else:
		_show_instruction_bubble(text)

func _show_instruction_bubble(text: String) -> void:
	if _ended:
		return
	var area: Rect2 = _rect("instruction_area")
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

func _rect(name: String) -> Rect2:
	return _layout.get("rects", {}).get(name, Rect2())

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

# A plain decorative picture at an exact size (never takes input).
func _make_art(node_name: String, texture: Texture2D, rect: Rect2, _hires: bool = false) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Painted icons and plaques keep their source proportions in the fixed HUD boxes.
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

# The painted gold back arrow, cropped to its visible pixels (alpha > 24; the 1254x1254 PNG
# has a faint halo almost to its edges) so it fills the button like the other HUD icons.
static func _back_arrow_texture() -> Texture2D:
	if _back_arrow_cache == null:
		var source := UiHelpers.hires_texture(BACK_ARROW_ART)
		if source == null:
			return null
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = BACK_ARROW_REGION
		_back_arrow_cache = atlas
	return _back_arrow_cache

# A 9-sliced painted panel from UiHelpers' alpha-cropped data: the carved corners
# keep their shape, the border never squashes, and nothing is stretched diagonally.
func _make_nine_patch_art(node_name: String, frame_data: Dictionary, rect: Rect2) -> NinePatchRect:
	# Oversampled bake drawn scaled down, so the panel stays sharp on 2x+ windows.
	var art := UiHelpers.nine_patch_rect(frame_data, rect.size)
	art.name = node_name
	return art

func _ensure_frame_border(data: Dictionary, target_size: Vector2, minimum: int) -> Dictionary:
	# Alpha-run detection can see only the thin centerline of a painted bevel. Keep at least
	# the visible 12 design-pixel rim fixed so the shade/cards never occupy the copper corners.
	if data.is_empty() or data.get("texture") == null:
		return data
	var texture := data["texture"] as Texture2D
	var texture_limit_x := maxi(1, texture.get_width() / 2 - 1)
	var texture_limit_y := maxi(1, texture.get_height() / 2 - 1)
	var margins: Rect2i = data.get("margins", Rect2i())
	var left := clampi(maxi(margins.position.x, minimum), 1, texture_limit_x)
	var top := clampi(maxi(margins.position.y, minimum), 1, texture_limit_y)
	var right := clampi(maxi(margins.size.x, minimum), 1, texture_limit_x)
	var bottom := clampi(maxi(margins.size.y, minimum), 1, texture_limit_y)
	if left + right >= int(target_size.x):
		left = mini(left, int(target_size.x * 0.25))
		right = mini(right, int(target_size.x * 0.25))
	if top + bottom >= int(target_size.y):
		top = mini(top, int(target_size.y * 0.25))
		bottom = mini(bottom, int(target_size.y * 0.25))
	margins = Rect2i(left, top, right, bottom)
	data["margins"] = margins
	data["inner"] = Rect2(
		left, top,
		maxf(1.0, target_size.x - left - right),
		maxf(1.0, target_size.y - top - bottom))
	if data.has("hires_texture"):
		var factor := float(data.get("oversample", 1.0))
		var hires := data["hires_texture"] as Texture2D
		data["hires_margins"] = Rect2i(
			roundi(left * factor), roundi(top * factor),
			mini(hires.get_width() / 2, roundi(right * factor)),
			mini(hires.get_height() / 2, roundi(bottom * factor)))
	return data

# The Clearing Zone bar: the new painted plank, alpha-cropped and 9-sliced so the
# carved end caps stay intact and the slots can use the wooden hole.
func _zone_bar_data(rect: Rect2) -> Dictionary:
	return UiHelpers.trimmed_nine_patch(
		UiHelpers.hires_texture(ZONE_BAR_ART), rect.size, ZONE_BAR_MARGINS, "zone_bar", true)

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
	# Portrait owns the full screen for safe z-order; landscape only needs a header row.
	_place(hud, _layout["hud"])
	parent.add_child(hud)

	var back := _make_icon_button("BackButton", _back_arrow_texture(), _rect("back"), true, 2.0)
	(back.get_node("Icon") as TextureRect).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	_place(level_label, _rect("level_title"))
	level_label.visible = not _rect("level_title").size.is_zero_approx()
	hud.add_child(level_label)

	var help_texture := UiHelpers.hires_texture(V2_HELP_ART)
	var help := _make_icon_button(
		"HelpButton", help_texture, _rect("help"), true, 2.0)
	help.tooltip_text = Localizer.t("help")
	help.pressed.connect(_on_help)
	hud.add_child(help)

	# The gear opens the in-game settings; it has the sound toggle's footprint and style.
	var gear_texture := UiHelpers.hires_texture(V2_GEAR_ART)
	var gear := _make_icon_button("SettingsButton", gear_texture, _rect("gear"), true, 3.0)
	gear.tooltip_text = Localizer.t("settings")
	gear.pressed.connect(_on_settings)
	hud.add_child(gear)

	_sound_icon = null
	var sound := _make_icon_button("SoundButton", _sound_texture(), _rect("sound"), true, 2.0)
	_sound_icon = sound.get_node("Icon") as TextureRect
	_sound_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sound.pressed.connect(_on_sound_toggle)
	hud.add_child(sound)

	var logo := _make_logo()
	if logo != null:
		hud.add_child(logo)
	_build_hud_pills(hud)

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
	_place(logo, _rect("logo"))
	return logo

# The painted note icon is 1024 px square: it is shrunk once to HUD size and cached. The muted
# face is the same picture baked darker at build time, so it reads as off at a glance.
func _sound_texture() -> Texture2D:
	var icon_name := "icon_sound_on" if Game.sound_enabled() else "icon_sound_off"
	return UiHelpers.hires_texture(UiHelpers.KIT_DIR + icon_name + ".png")

func _on_sound_toggle() -> void:
	Game.set_sound(not Game.sound_enabled())
	if _sound_icon != null and is_instance_valid(_sound_icon):
		_sound_icon.texture = _sound_texture()

# One brown plate of the kit with a label centred on it (the plate itself is 64x32 and its
# drawn body sits a little above the middle, so the label box is offset to match).
func _make_pill(node_name: String, rect: Rect2) -> NinePatchRect:
	var pill := NinePatchRect.new()
	pill.name = node_name
	pill.texture = UiHelpers.kit_texture("pill")
	pill.patch_margin_left = 9
	pill.patch_margin_top = 8
	pill.patch_margin_right = 9
	pill.patch_margin_bottom = 8
	pill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(pill, rect)
	return pill

func _make_pill_label(pill: Control, text: String, font_size: int, color: Color, symbols: bool = false, inset_left: float = 0.0) -> Label:
	var label := UiHelpers.symbol_label(text, font_size) if symbols else Label.new()
	if not symbols:
		label.text = text
		label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	UiHelpers.add_text_shadow(label, 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, Rect2(inset_left, 3.0, pill.size.x - inset_left - 4.0, pill.size.y - 6.0))
	pill.add_child(label)
	return label

# Clock plate (the stopwatch badge stuck on its left end), then the live stars plaque
# (Endless: the run score plate instead).
func _build_hud_pills(hud: Control) -> void:
	var clock_rect := _rect("clock_pill")
	var clock_texture := UiHelpers.hires_texture(CLOCK_PLANK_ART)
	var clock_pill := _make_art("ClockPill", clock_texture, clock_rect, true)
	var clock_shadow := _make_drop_shadow(
		clock_texture, Rect2(clock_rect.position + Vector2(1.0, 2.0), clock_rect.size - Vector2(1.0, 2.0)), 1.5, 0.28)
	if clock_shadow != null:
		hud.add_child(clock_shadow)
	hud.add_child(clock_pill)
	timer_label = _make_pill_label(clock_pill, "00:00", 12, TEXT_PRIMARY, false, float(_layout["clock_text_inset"]))
	clock_pill.add_child(_make_art("Stopwatch", UiHelpers.hud_texture("icon_stopwatch"), _rect("stopwatch_in_pill"), true))

	if _endless != null:
		stars_row = null
		stars_base = null
		stars_overlay = null
		var score_rect := _rect("score_pill")
		var score := _make_pill("ScorePill", score_rect)
		var score_shadow := _make_drop_shadow(UiHelpers.kit_texture("pill"), score_rect.grow(1.0), 1.5, 0.35)
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
	var rect := _rect("board_frame")
	var inner := _rect("board_inner")
	inner.position -= rect.position
	var frame_art: Control = null
	var frame_path := V2_BOARD_FRAME_ART if _is_landscape else BOARD_FRAME_PORTRAIT_ART
	var frame_data := UiHelpers.alpha_nine_patch(
		UiHelpers.hires_texture(frame_path), rect.size, BOARD_FRAME_BORDER_MAX)
	if not frame_data.is_empty():
		frame_data = _ensure_frame_border(frame_data, rect.size, 12)
		inner = frame_data["inner"]
		frame_art = _make_nine_patch_art("BoardArt", frame_data, rect)
	# The shade and card viewport must stay inside the painted border at all aspect ratios.
	var safe_inner := inner.intersection(Rect2(Vector2(6.0, 6.0), rect.size - Vector2(12.0, 12.0)))
	if safe_inner.has_area():
		inner = safe_inner
	var frame := Control.new()
	frame.name = "BoardFrame"
	frame.z_index = 0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_meta("inner_rect", inner)
	_place(frame, rect)
	parent.add_child(frame)
	var shade := ColorRect.new()
	shade.name = "BoardShade"
	shade.color = BOARD_SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(shade, Rect2(Vector2.ZERO, rect.size).intersection(inner.grow(BOARD_SHADE_OVERDRAW)))
	frame.add_child(shade)
	if frame_art != null:
		frame.add_child(frame_art)
	board_container = Control.new()
	board_container.name = "Board"
	board_container.clip_contents = true
	board_container.z_index = 2
	var cards_area := inner.grow(-BOARD_PAD)
	# The hero is drawn in front of the frame art but behind the cards (LevelLayout.HERO_Z < card
	# layer): dense boards need the full width (touch-size floor), so she never hides a card.
	_place(board_container, cards_area)
	frame.add_child(board_container)

# A Support Deck is a pile drawn inside its kit slot: deck A fans its card edges to the left,
# deck B to the right.
func _build_deck_slot(parent: Control, deck_id: String) -> void:
	var rect := _rect("deck_a" if deck_id == "a" else "deck_b")
	var slot := Control.new()
	slot.name = "Deck%s" % deck_id.to_upper()
	slot.z_index = 8
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(slot, rect)
	parent.add_child(slot)
	# The square wooden plate is the deck's table; the pile sits on top of it.
	var table_texture := UiHelpers.hires_texture(DECK_TABLE_ART)
	var table_shadow := _make_drop_shadow(
		table_texture, Rect2(Vector2(1.0, 2.0), rect.size - Vector2(1.0, 2.0)), 1.8, 0.26)
	if table_shadow != null:
		table_shadow.name = "DeckTableShadow"
		slot.add_child(table_shadow)
	slot.add_child(_make_art("DeckTable", table_texture, Rect2(Vector2.ZERO, rect.size), true))
	var btn := _make_deck_button(deck_id)
	btn.position = ((rect.size - _deck_pile_size()) * 0.5).floor()
	slot.add_child(btn)
	if deck_id == "a":
		deck_a_btn = btn
	else:
		deck_b_btn = btn

# The Reserve box: the painted stone field 9-sliced to the box (no translucent fill
# over it), with the cards centred inside the stone hole. No header/count.
func _build_reserve_panel(parent: Control) -> void:
	var rect := _rect("reserve")
	var panel := Control.new()
	panel.name = "Reserve"
	panel.z_index = 8
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, rect)
	parent.add_child(panel)
	var frame_data := UiHelpers.trimmed_nine_patch(
		UiHelpers.hires_texture(RESERVE_FIELD_ART), rect.size, RESERVE_FIELD_MARGINS, "", true)
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
	var rect := _rect("zone")
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
	var slots_rect := _rect("zone_cards")
	slots_rect.position -= rect.position
	zone_container = HFlowContainer.new()
	zone_container.name = "ZoneSlots"
	zone_container.alignment = FlowContainer.ALIGNMENT_CENTER
	zone_container.custom_minimum_size = card
	zone_container.add_theme_constant_override("h_separation", int(_layout["zone_h_separation"]))
	zone_container.add_theme_constant_override("v_separation", int(_layout["zone_v_separation"]))
	_place(zone_container, slots_rect)
	zone.add_child(zone_container)

# The power panel: the tall painted board stays vertical in both orientations (no
# 90-degree rotation blur); landscape puts it right of the board, portrait puts it
# as a column on the right, with the three buttons stacked.
func _build_controls(parent: Control) -> void:
	var rect := _rect("powers")
	var panel := Control.new()
	panel.name = "Powers"
	panel.z_index = 8
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, rect)
	parent.add_child(panel)
	var power_art := UiHelpers.hires_texture(POWERS_BOARD_ART)
	var power_margins := POWERS_BOARD_MARGINS
	if not _is_landscape:
		# The same tall board turns sideways for the portrait action strip; the rotation
		# stays full source resolution before the 9-slice is oversampled for the window.
		power_art = UiHelpers.rotated_texture(POWERS_BOARD_ART)
		power_margins = Rect2(POWERS_BOARD_MARGINS.position.y, POWERS_BOARD_MARGINS.position.x,
			POWERS_BOARD_MARGINS.size.y, POWERS_BOARD_MARGINS.size.x)
	var frame_data := UiHelpers.trimmed_nine_patch(power_art, rect.size, power_margins)
	var inner := _rect("powers_inner")
	inner.position -= rect.position
	if not frame_data.is_empty():
		panel.add_child(_make_nine_patch_art("PowersArt", frame_data, rect))
		inner = frame_data["inner"]
	else:
		var art := UiHelpers.kit_panel("panel_powers", FRAME_MARGIN)
		art.name = "PowersArt"
		_place(art, Rect2(Vector2.ZERO, rect.size))
		panel.add_child(art)
	var box: BoxContainer = VBoxContainer.new() if _is_landscape else HBoxContainer.new()
	box.name = "PowerButtons"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	_place(box, inner)
	panel.add_child(box)
	for i in PowerManager.POWERS.size():
		var button_rect: Rect2 = _layout["power_buttons"][i]
		box.add_child(_make_power_button(str(PowerManager.POWERS[i]), button_rect.size))

# One power: its icon and the "xN" stock side by side; the full name stays in the tooltip.
func _make_power_button(p: String, button_size: Vector2) -> Button:
	var btn := Button.new()
	btn.name = "Power_%s" % p
	btn.custom_minimum_size = button_size
	btn.size = button_size
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
	var icon_size := 30.0 if not _is_landscape else 28.0
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
	var count_lbl := Label.new()
	count_lbl.text = "x0"
	count_lbl.add_theme_font_size_override("font_size", 10 if _is_landscape else 11)
	count_lbl.add_theme_color_override("font_color", GOLD)
	UiHelpers.add_text_shadow(count_lbl, 3)
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _is_landscape:
		var content_row := HBoxContainer.new()
		content_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		content_row.alignment = BoxContainer.ALIGNMENT_CENTER
		content_row.add_theme_constant_override("separation", 2)
		content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(content_row)
		content_row.add_child(icon_box)
		content_row.add_child(count_lbl)
	else:
		var content_column := VBoxContainer.new()
		content_column.set_anchors_preset(Control.PRESET_FULL_RECT)
		content_column.alignment = BoxContainer.ALIGNMENT_CENTER
		content_column.add_theme_constant_override("separation", 0)
		content_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(content_column)
		content_column.add_child(icon_box)
		content_column.add_child(count_lbl)
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
	_hook_juice(btn)
	return btn

func _deck_card_size() -> Vector2:
	return DECK_CARD_SIZE

# The button covers the face card plus the room the pile's edges can take.
func _deck_pile_size() -> Vector2:
	var card := _deck_card_size()
	return Vector2(card.x + PILE_MAX_EDGES * PILE_EDGE_STEP, card.y)

func render() -> void:
	var layout := _board_layout()
	_layout_cache = layout
	_layout_cache_size = board_container.size
	var offset: Vector2 = layout["offset"]
	var scale: float = layout["scale"]
	var origin: Vector2 = layout["origin"]
	var position_scale: Vector2 = layout["position_scale"]
	var grid_positions: Dictionary = layout["grid_positions"]
	var card_size := Vector2(_card_size, _card_size) * scale * BOARD_CARD_SCALE
	_show_layout_warning_if_needed()

	var depths := _blocked_depths()
	var board_cards: Array = controller.board.cards.duplicate()
	board_cards.sort_custom(func(a, b): return a.layer < b.layer)
	var live_board_ids: Dictionary = {}
	for card in board_cards:
		if card.is_removed() or card.location != Card.Location.BOARD:
			continue
		live_board_ids[card.id] = true
		var depth := int(depths.get(card.id, 0))
		var node := _board_nodes.get(card.id) as Button
		if not is_instance_valid(node):
			node = _make_card_button(card, depth, _on_card.bind(card.id), card_size, false)
			_hook_juice(node)
			_board_nodes[card.id] = node
			board_container.add_child(node)
		var visual_position: Vector2 = grid_positions.get(card.id, Vector2(
			(card.position.x - origin.x) * position_scale.x,
			(card.position.y - origin.y) * position_scale.y
		))
		_update_board_card_node(node, depth, card_size, _board_node_position(layout, visual_position), card.layer)
	for card_id in _board_nodes.keys().duplicate():
		if not live_board_ids.has(card_id):
			_remove_cached_node(_board_nodes, card_id)

	var zone_card_size := _zone_card_size()
	# Fill the whole bar: distribute the leftover width into the slot step. When the seven
	# larger cards do not fit, the step goes negative so they overlap and still occupy one
	# row (the container's ALIGNMENT_CENTER keeps the overlapped row centred).
	var slots := maxi(1, controller.clearing_capacity)
	var gap := int(_layout["zone_h_separation"])
	if _is_landscape and slots > 1:
		var usable: float = zone_container.size.x
		gap = floori((usable - slots * zone_card_size.x) / float(slots - 1))
		if gap > 0:
			gap = maxi(2, gap)
	zone_container.add_theme_constant_override("h_separation", gap)
	var live_zone_keys: Dictionary = {}
	for i in controller.clearing_capacity:
		var node: Control
		var key: String
		if i < controller.zone.cards.size():
			var zone_card: Card = controller.zone.cards[i]
			key = "card:%s" % zone_card.id
			node = _zone_nodes.get(key) as Control
			if not is_instance_valid(node):
				node = _make_card_display(zone_card.type, zone_card_size, true)
				_apply_zone_juice(node, str(zone_card.id))
				_zone_nodes[key] = node
			_sync_zone_juice(node, zone_card_size)
			# A card still flying in shows up in its slot only when its ghost lands.
			node.modulate = Color(1, 1, 1, 0) if _hidden_cards.has(zone_card.id) else Color.WHITE
		else:
			key = "empty:%d" % i
			node = _zone_nodes.get(key) as Control
			if not is_instance_valid(node):
				node = _make_empty_slot(zone_card_size, true)
				_zone_nodes[key] = node
			node.modulate = Color.WHITE
		live_zone_keys[key] = true
		node.custom_minimum_size = zone_card_size
		node.size = zone_card_size
		if node.get_parent() != zone_container:
			zone_container.add_child(node)
		var target_index := mini(i, zone_container.get_child_count() - 1)
		if node.get_index() != target_index:
			zone_container.move_child(node, target_index)
	for key in _zone_nodes.keys().duplicate():
		if not live_zone_keys.has(key):
			_remove_cached_node(_zone_nodes, key)
	# Slot rects are read right after a move, in the same frame: lay the slots out now.
	zone_container.notification(Container.NOTIFICATION_SORT_CHILDREN)

	# Any Reserve card can go back to the zone, so every one is a button laid out where it
	# can be seen and tapped (returning only the last one could soft-lock a level).
	var reserve_layout := _reserve_layout(controller.reserve.size())
	var reserve_size: Vector2 = reserve_layout["size"]
	var reserve_positions: Array = reserve_layout["positions"]
	var live_reserve_ids: Dictionary = {}
	for i in controller.reserve.size():
		var card: Card = controller.reserve[i]
		live_reserve_ids[card.id] = true
		var node := _reserve_nodes.get(card.id) as Button
		if not is_instance_valid(node):
			node = _make_card_button(card, 0, _on_reserve_return.bind(card.id), reserve_size, true)
			_reserve_nodes[card.id] = node
			reserve_container.add_child(node)
		_update_board_card_node(node, 0, reserve_size, reserve_positions[i], i)
		var target_index := mini(i, reserve_container.get_child_count() - 1)
		if node.get_index() != target_index:
			reserve_container.move_child(node, target_index)
	for card_id in _reserve_nodes.keys().duplicate():
		if not live_reserve_ids.has(card_id):
			_remove_cached_node(_reserve_nodes, card_id)

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

# ---------------------------------------------------------------- card juice
# Only the card under the pointer/finger owns a ShaderMaterial (on its art); everyone else keeps
# the shared depth material (or none). Tilt updates on pointer motion only; no per-frame work.
var _juice_button: Button
var _juice_face: Control
var _juice_art: Control
var _juice_mat: ShaderMaterial
var _juice_tween: Tween

func _hook_juice(btn: Button) -> void:
	btn.gui_input.connect(_on_juice_input.bind(btn))
	btn.mouse_exited.connect(_juice_release.bind(btn))

func _juice_face_of(btn: Button) -> Control:
	if btn.has_meta("face"):   # a Support Deck's top card
		return btn.get_meta("face") as Control
	if btn.get_child_count() > 0:   # a board card
		return btn.get_child(0) as Control
	return null

func _juice_art_of(face: Control) -> TextureRect:
	for child in face.get_children():
		if child is TextureRect:
			return child
	return null

func _on_juice_input(event: InputEvent, btn: Button) -> void:
	if _ended or not is_instance_valid(btn) or btn.disabled:
		return
	if event is InputEventMouseMotion:
		_juice_follow(btn, (event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_juice_follow(btn, mb.position)   # touch-down tilts too
		elif mb.device == InputEvent.DEVICE_ID_EMULATION:
			_juice_release(btn)               # a finger lifting is not followed by mouse_exited

func _juice_follow(btn: Button, local_pos: Vector2) -> void:
	if btn.disabled:
		return   # blocked cards keep their exact dimmed look
	var face := _juice_face_of(btn)
	if face == null or not is_instance_valid(face):
		return
	var art := _juice_art_of(face)
	if art == null:
		return   # placeholder/empty slot: nothing to tilt
	if _juice_button != btn or _juice_face != face or not is_instance_valid(_juice_mat):
		_juice_begin(btn, face, art)
	if _juice_tween != null and _juice_tween.is_valid():
		_juice_tween.kill()
		_juice_tween = null
	var area := Rect2(Vector2.ZERO, face.size)
	if btn.has_meta("face_rect"):
		area = btn.get_meta("face_rect")
	var n := ((local_pos - area.position) / area.size - Vector2(0.5, 0.5)) * 2.0
	n = n.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	_juice_mat.set_shader_parameter("y_rot", n.x * JUICE_MAX_TILT_DEG)
	_juice_mat.set_shader_parameter("x_rot", -n.y * JUICE_MAX_TILT_DEG)
	_juice_set_shadow(face, -n * JUICE_SHADOW_SHIFT)

func _juice_begin(btn: Button, face: Control, art: TextureRect) -> void:
	_juice_end_now()
	var mat := ShaderMaterial.new()
	mat.shader = JUICE_SHADER
	mat.set_shader_parameter("rect_size", art.size)
	mat.set_shader_parameter("fov", JUICE_FOV)
	mat.set_shader_parameter("shine_strength", JUICE_SHINE)
	art.material = mat
	_juice_button = btn
	_juice_face = face
	_juice_art = art
	_juice_mat = mat
	face.pivot_offset = face.size * 0.5
	var pop := create_tween()
	pop.tween_property(face, "scale", Vector2(JUICE_HOVER_SCALE, JUICE_HOVER_SCALE), JUICE_POP_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _juice_release(btn: Button) -> void:
	if _juice_button != btn or not is_instance_valid(_juice_mat):
		return
	if _juice_tween != null and _juice_tween.is_valid():
		_juice_tween.kill()
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_juice_tween = tween
	tween.tween_property(_juice_mat, "shader_parameter/x_rot", 0.0, JUICE_RETURN_SECONDS)
	tween.tween_property(_juice_mat, "shader_parameter/y_rot", 0.0, JUICE_RETURN_SECONDS)
	if is_instance_valid(_juice_face):
		tween.tween_property(_juice_face, "scale", Vector2.ONE, JUICE_RETURN_SECONDS)
		_juice_set_shadow(_juice_face, Vector2.ZERO)
	tween.chain().tween_callback(_juice_end_now)

# Back to the shared material at once (also when the card is rebuilt, blocked or removed).
func _juice_end_now() -> void:
	if _juice_tween != null and _juice_tween.is_valid():
		_juice_tween.kill()
	_juice_tween = null
	if is_instance_valid(_juice_art):
		_juice_art.material = null
	if is_instance_valid(_juice_face):
		_juice_face.scale = Vector2.ONE
		_juice_set_shadow(_juice_face, Vector2.ZERO)
	_juice_button = null
	_juice_face = null
	_juice_art = null
	_juice_mat = null

func _juice_set_shadow(face: Control, shift: Vector2) -> void:
	var shadow := face.get_node_or_null("CardShadow") as Control
	if shadow != null:
		shadow.position = shift

# Clearing Zone cards: each owns a small material with idle sway + holographic foil.
func _apply_zone_juice(node: Control, card_id: String) -> void:
	var art := _juice_art_of(node)
	if art == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = JUICE_SHADER
	mat.set_shader_parameter("rect_size", art.size)
	mat.set_shader_parameter("fov", JUICE_FOV)
	mat.set_shader_parameter("sway_amount", ZONE_SWAY_DEG)
	mat.set_shader_parameter("holo_strength", ZONE_HOLO)
	mat.set_shader_parameter("sway_phase", float(card_id.hash() % 628) / 100.0)
	art.material = mat

func _sync_zone_juice(node: Control, card_size: Vector2) -> void:
	var art := _juice_art_of(node)
	if art == null or art.material == null:
		return
	if art.size != card_size:
		art.size = card_size
		(art.material as ShaderMaterial).set_shader_parameter("rect_size", card_size)

func _clear(c: Node) -> void:
	for child in c.get_children():
		c.remove_child(child)
		child.queue_free()

func _remove_cached_node(cache: Dictionary, key: Variant) -> void:
	var node := cache.get(key) as Node
	if is_instance_valid(node):
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.queue_free()
	cache.erase(key)

func _update_board_card_node(button: Button, depth: int, card_size: Vector2, at: Vector2, z: int) -> void:
	if button.position != at:
		button.position = at
	if button.size != card_size:
		button.size = card_size
	if button.custom_minimum_size != card_size:
		button.custom_minimum_size = card_size
	if button.z_index != z:
		button.z_index = z
	var disabled := depth > 0
	if button.disabled != disabled:
		button.disabled = disabled
		if disabled and _juice_button == button:
			_juice_end_now()
	if button.get_child_count() == 0:
		return
	var face := button.get_child(0) as Control
	if face.size != card_size:
		face.size = card_size
	if face.custom_minimum_size != card_size:
		face.custom_minimum_size = card_size
	var material: Material = _dim_material(depth, UiHelpers.has_card_art(str(button.get_meta("card_type", "")))) if depth > 0 else null
	if face.material != material:
		face.material = material
	for child in face.get_children():
		if child is Control:
			var child_control := child as Control
			if child_control.size != card_size:
				child_control.size = card_size
			if child_control.custom_minimum_size != card_size:
				child_control.custom_minimum_size = card_size
			if child.name != "CardShadow":
				var use_parent := depth > 0
				if child_control.use_parent_material != use_parent:
					child_control.use_parent_material = use_parent

# Depth of every board card under the cards that cover it: 0 = reachable, 1 = covered only
# by reachable cards, 2 = covered by a depth-1 card, and so on. Cards are visited from the
# top layer down, so a card's blockers already have their depth when it is reached.
func _blocked_depths() -> Dictionary:
	var geometry_cards: Array[Card] = []
	var signature_parts := PackedStringArray()
	for c in controller.board.cards:
		if c.source != Card.Source.BOARD:
			continue
		geometry_cards.append(c)
		signature_parts.append("%s:%.3f:%.3f:%d" % [c.id, c.position.x, c.position.y, c.layer])
	var signature := "|".join(signature_parts)
	if signature != _blocker_cache_signature:
		_blocker_cache.clear()
		for card in geometry_cards:
			var blockers: Array[String] = []
			for other in geometry_cards:
				if other.layer > card.layer and BoardSpatialRules.blocks_with_layers(
					card.get_display_rect(), other.get_display_rect(), card.layer, other.layer):
					blockers.append(other.id)
			_blocker_cache[card.id] = blockers
		_blocker_cache_signature = signature
	var cards: Array[Card] = []
	for card in geometry_cards:
		if card.location == Card.Location.BOARD and not card.is_removed():
			cards.append(card)
	cards.sort_custom(func(a, b): return a.layer > b.layer)
	var depths: Dictionary = {}
	for card in cards:
		if card.state == Card.State.AVAILABLE:
			depths[card.id] = 0
			continue
		var depth := 1
		for blocker_id in _blocker_cache.get(card.id, []):
			if not depths.has(blocker_id):
				continue
			depth = maxi(depth, int(depths[blocker_id]) + 1)
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
	return _layout["zone_card_size"]

func _board_layout() -> Dictionary:
	# Scale the whole set of square faces into the clipped interior. The frame's inner
	# rect can be narrower than the generated grid, so include card extents in the fit.
	var positions: Array[Vector2] = []
	for card in controller.board.cards:
		if card.source == Card.Source.BOARD:
			positions.append(card.position)
	if positions.is_empty():
		return {"offset": Vector2.ZERO, "scale": 1.0, "origin": Vector2.ZERO, "position_scale": Vector2.ONE, "grid_positions": {}}
	var origin := Vector2(INF, INF)
	var far_edge := Vector2(-INF, -INF)
	for position in positions:
		origin = Vector2(minf(origin.x, position.x), minf(origin.y, position.y))
		far_edge = Vector2(maxf(far_edge.x, position.x), maxf(far_edge.y, position.y))
	var card_extent := Vector2.ONE * _card_size * BOARD_CARD_SCALE
	var content := far_edge - origin + card_extent
	var available := (board_container.size - Vector2.ONE * BOARD_PAD * 2.0).max(Vector2.ONE)
	var scale := minf(available.x / content.x, available.y / content.y)
	var scale_cap := LevelConfig.MAX_BOARD_CARD_PX / maxf(1.0, _card_size * BOARD_CARD_SCALE)
	scale = minf(scale, scale_cap)
	var position_scale := Vector2(BOARD_X_COMPRESSION, BOARD_Y_COMPRESSION)
	var grid_positions: Dictionary = {}
	for card in controller.board.cards:
		if card.source == Card.Source.BOARD:
			grid_positions[card.id] = Vector2(
				(card.position.x - origin.x) * position_scale.x,
				(card.position.y - origin.y) * position_scale.y)
	var scaled_content := content * scale
	return {
		"offset": (board_container.size - scaled_content) * 0.5,
		"scale": scale,
		"origin": origin,
		"position_scale": position_scale,
		"grid_positions": grid_positions,
	}

func _board_layout_legacy() -> Dictionary:
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
	var max_scale := LevelConfig.MAX_BOARD_CARD_PX / maxf(1.0, _card_size * BOARD_CARD_SCALE)
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
	# BoardLayout.compute sizes the *logical* span, but the final node rect is the scaled
	# position plus the rendered card size (and the max-scale cap can re-centre it). Measure
	# that real bbox and re-centre the offset so no card can ever leave the container:
	# min >= 0 and max <= board_container.size, with the same uniform scale/pitches.
	var scale: float = float(fit["scale"])
	var card_size := Vector2(_card_size, _card_size) * scale * BOARD_CARD_SCALE
	var content_min := Vector2(INF, INF)
	var content_max := Vector2(-INF, -INF)
	for p: Vector2 in grid_positions.values():
		var scaled := p * scale
		content_min = Vector2(minf(content_min.x, scaled.x), minf(content_min.y, scaled.y))
		content_max = Vector2(maxf(content_max.x, scaled.x + card_size.x), maxf(content_max.y, scaled.y + card_size.y))
	var content := content_max - content_min
	var target := (board_container.size - content) * 0.5 - content_min
	# When the board fits, pin it inside (lower bound keeps min >= 0; upper keeps max <= size).
	if content.x <= board_container.size.x:
		target.x = clampf(target.x, -content_min.x, board_container.size.x - content_max.x)
	if content.y <= board_container.size.y:
		target.y = clampf(target.y, -content_min.y, board_container.size.y - content_max.y)
	fit["offset"] = target
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
	var warn := _scale_limited
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
	var warn_y := float(_layout["header_height"]) if _is_landscape else maxf(
		0.0, get_viewport_rect().size.y - _layout_warning.size.y - 8.0)
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
			card_tex, 2.4 if zone_shadow else 1.5, 0.42 if zone_shadow else 0.30)
		if shadow_tex != null:
			var shadow_node := Control.new()
			shadow_node.name = "CardShadow"
			shadow_node.custom_minimum_size = card_size
			shadow_node.size = card_size
			shadow_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var shadow_offset := Vector2(2.0, 3.0) if zone_shadow else Vector2(1.0, 2.0)
			shadow_node.draw.connect(func():
				shadow_node.draw_texture_rect(shadow_tex, Rect2(shadow_offset, shadow_node.size), false))
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
	btn.set_meta("card_type", card.type)
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
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var card_size := _deck_card_size()
	var signature := "%d|%d|%s|%s|%s" % [
		deck.current_index, deck.remaining_count(), deck.current_type(), str(edges_left), str(card_size),
	]
	if str(btn.get_meta("deck_render_signature", "")) == signature:
		return
	btn.set_meta("deck_render_signature", signature)
	if _juice_button == btn:
		_juice_end_now()
	_clear(btn)
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
			return "ðŸ“¥"
		"undo":
			return "↩️"
		"refresh":
			return "ðŸ”€"
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
	corner_close.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_play_effect("play_ui_setting")
	_settings_open = true
	controller.pause()
	# A quick gear tap can land while the level-name intro is still on screen (z1500);
	# it must not sit over the settings panel.
	var intro := find_child("IntroOverlay", true, false)
	if intro != null:
		intro.queue_free()
	if _instruction_bubble != null and is_instance_valid(_instruction_bubble):
		_instruction_bubble.queue_free()
		_instruction_bubble = null
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
	var panel := _make_settings_panel()
	center.add_child(panel)
	var col := panel.find_child("SettingsBody", true, false) as VBoxContainer
	if col == null:
		return
	# Heading with the kit's green close icon in the top-right corner. The v2 settings
	# plate is localised (config_2/Configu); the text Label is only a missing-art fallback.
	var header := HBoxContainer.new()
	col.add_child(header)
	var title_art: String = str(V2_SETTINGS_TITLE_ART["pt" if Localizer.current == "pt" else "en"])
	var title_texture := UiHelpers.hires_texture(V2_KIT_DIR + title_art)
	if title_texture != null:
		var heading_art := TextureRect.new()
		heading_art.name = "SettingsTitle"
		heading_art.texture = title_texture
		heading_art.set_meta("source_path", V2_KIT_DIR + title_art)
		heading_art.set_meta("locale", "pt" if Localizer.current == "pt" else "en")
		heading_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heading_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heading_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		heading_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading_art.custom_minimum_size = Vector2(0, 28 if _is_landscape else 32)
		header.add_child(heading_art)
	else:
		var heading := Label.new()
		heading.name = "SettingsTitle"
		heading.text = Localizer.t("settings")
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_theme_font_size_override("font_size", 16)
		heading.add_theme_color_override("font_color", TEXT_PRIMARY)
		header.add_child(heading)
	var corner_close := _make_v2_action_icon(
		"SettingsCornerClose", V2_CLOSE_ART, Localizer.t("close"),
		_close_settings, 28 if _is_landscape else 30)
	corner_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(corner_close)
	var row_height := 30 if _is_landscape else 36
	col.add_child(_make_settings_row("LanguageButton", Localizer.t("language"), _on_settings_language, row_height, V2_CONFIG_ROW_ART[0]))
	col.add_child(_make_settings_row("OrientationButton", _settings_orientation_text(), _on_settings_orientation, row_height, V2_CONFIG_ROW_ART[1]))
	col.add_child(_make_settings_row("MascotButton", _settings_mascot_text(), _on_settings_mascot, row_height, V2_CONFIG_ROW_ART[2]))
	var volume := VolumeRow.new(row_height)
	volume.changed.connect(_refresh_sound_icon)
	volume.custom_minimum_size.x = 0
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.add_theme_stylebox_override("panel", _v2_row_style(
		V2_CONFIG_ROW_ART[0], Color.WHITE, row_height))
	col.add_child(volume)
	var close := _make_v2_action_icon(
		"SettingsClose", V2_ACCEPT_ART, Localizer.t("close"),
		_close_settings, 32 if _is_landscape else 36)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(close)
	# Every option inside the gear window clicks with the same sound as the gear itself.
	_connect_settings_clicks(overlay)

# Connected once per overlay build (the overlay is always re-created), covering the option
# rows, the volume buttons and both closes.
func _connect_settings_clicks(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			(child as BaseButton).pressed.connect(_play_settings_click)
		_connect_settings_clicks(child)

func _play_settings_click() -> void:
	_play_effect("play_ui_setting")

# v2 Options frame: panel_options.png scaled to its own aspect, with a body margin that
# keeps the rows on the painted stone, clear of the gold border and the top gem.
func _make_settings_panel() -> Control:
	var width := 351.0 if _is_landscape else 344.0
	var height := width / V2_OPTIONS_PANEL_ASPECT
	var frame := Control.new()
	frame.name = "SettingsPanel"
	frame.custom_minimum_size = Vector2(width, height)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var art := TextureRect.new()
	art.name = "SettingsPanelArt"
	art.texture = UiHelpers.hires_texture(V2_OPTIONS_PANEL_ART)
	art.set_meta("source_path", V2_OPTIONS_PANEL_ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(art)
	var body := MarginContainer.new()
	body.name = "SettingsBodyFrame"
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	var side := int(round(width * 0.117))
	var vertical := int(round(height * 0.15))
	body.add_theme_constant_override("margin_left", side)
	body.add_theme_constant_override("margin_right", side)
	body.add_theme_constant_override("margin_top", vertical)
	body.add_theme_constant_override("margin_bottom", vertical)
	frame.add_child(body)
	var col := VBoxContainer.new()
	col.name = "SettingsBody"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2 if _is_landscape else 4)
	body.add_child(col)
	return frame

# Circular v2 Accept/Close badge (the painted icon carries the action; no text label).
func _make_v2_action_icon(node_name: String, art_path: String, label: String, callback: Callable, icon_size: int) -> Button:
	var texture := UiHelpers.hires_texture(art_path)
	if texture == null:
		var fallback := Button.new()
		fallback.name = node_name
		fallback.text = label
		fallback.custom_minimum_size = Vector2(icon_size, icon_size)
		fallback.pressed.connect(callback)
		return fallback
	var btn := _make_face_button(node_name, texture, Vector2(icon_size, icon_size), label, callback)
	btn.set_meta("source_path", art_path)
	return btn

func _apply_v2_row_style(btn: Button, art_path: String, row_height: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tint := Color.WHITE
		match state:
			"hover":
				tint = Color(1.12, 1.12, 1.12)
			"pressed":
				tint = Color(0.82, 0.82, 0.82)
			"disabled":
				tint = Color(0.65, 0.65, 0.65, 0.85)
		btn.add_theme_stylebox_override(state, _v2_row_style(art_path, tint, row_height))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func _v2_row_style(art_path: String, tint := Color.WHITE, row_height: int = 36) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var texture := UiHelpers.hires_texture(art_path)
	if texture != null:
		# Fit to the displayed row height, then 9-slice the gem end-caps while the centre expands.
		var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
		var target := Vector2(float(row_height) * aspect, float(row_height))
		var sliced := UiHelpers.trimmed_nine_patch(
			texture, target, Rect2(0.12, 0.14, 0.12, 0.14),
			"settings_row:%s:%d" % [art_path, row_height])
		style.texture = sliced.get("texture", texture)
		var margins: Rect2i = sliced.get("margins", Rect2i())
		style.texture_margin_left = margins.position.x
		style.texture_margin_top = margins.position.y
		style.texture_margin_right = margins.size.x
		style.texture_margin_bottom = margins.size.y
	style.draw_center = true
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.set_meta("source_path", art_path)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	style.modulate_color = tint
	return style

func _make_settings_row(node_name: String, text: String, callback: Callable, height: int, art_path: String) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = text
	btn.custom_minimum_size = Vector2(0, height)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 16 if height >= 36 else 13)
	btn.tooltip_text = text
	btn.pressed.connect(callback)
	_apply_v2_row_style(btn, art_path, height)
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
	# A card taken from the Board has its own landing sound; a refused tap plays nothing.
	if bool(result.get("ok", false)):
		_play_effect("play_card_select")
	_apply_move(card.type, card_id, source_rect, snap, result, false)

func _on_deck(deck_id: String) -> void:
	if not _accepts_taps():
		return
	var deck: DeckManager = controller.deck_a if deck_id == "a" else controller.deck_b
	var card_type := deck.current_type()
	var source_rect := _deck_face_rect(deck_a_btn if deck_id == "a" else deck_b_btn)
	var snap := _snapshot_zone()
	var result := controller.use_deck(deck_id)
	# A draw from a Support Deck has its own sound; a refused draw plays nothing.
	if bool(result.get("ok", false)):
		_play_effect("play_deck_draw")
	_apply_move(card_type, "", source_rect, snap, result, false)

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
# `select_sfx` is false when the caller already played the move's own sound (Board, Deck).
func _apply_move(card_type: String, card_id: String, source_rect: Rect2, snap: Dictionary, result: Dictionary, select_sfx: bool = true) -> void:
	if not bool(result["ok"]):
		# A refused tap must never look like a frozen game: say why when the zone is full.
		if controller.status == GameController.Status.PLAYING and controller.zone.is_full():
			_flash_zone_full()
			_say("zone_warning")
		_check_end()
		return
	if select_sfx:
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
	_play_effect("play_power", power)
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
	var card_size := Vector2(_card_size, _card_size) * scale * BOARD_CARD_SCALE
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
	_play_effect("play_match")
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

# Plays one of the real effects owned by the Audio autoload (Board, Deck, win, lose).
func _play_effect(method_name: String, argument = null) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio == null:
		return
	if argument == null:
		audio.call(method_name)
	else:
		audio.call(method_name, argument)

# Short synthesized beeps still used by the match/puff/reserve visuals, until those get art too.
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
	_juice_end_now()
	if mascot != null:
		mascot.visible = false
	if _instruction_bubble != null and is_instance_valid(_instruction_bubble):
		_instruction_bubble.queue_free()
	_play_effect("play_level_complete" if win else "play_level_failed")
	# A very fast defeat can land while the level-name intro is still on screen; it sits at
	# z1500 and would cover the result plates.
	var intro := find_child("IntroOverlay", true, false)
	if intro != null:
		intro.queue_free()
	if _endless != null:
		_show_endless_end(win)
		return
	if win:
		Game.complete_level(controller.stars, controller.rewards)
		_show_victory_screen(false, {})
		return
	else:
		# Powers spent during a lost attempt are already gone from the inventory.
		Game.save_progress()
		# A campaign defeat has its own composition: the stage stays visible behind the
		# stone window and the HUD remains available for menu/help.
		_show_defeat_screen()
		return

# The campaign defeat composition. The stage (background and HUD) stays behind a lighter
# shade; the hero is mapped from HeroRoster and drawn large behind the stone window, which
# carries the localised title and the two real retry/quit plates. The HUD is lifted above
# the shade so Back/Help/Sound keep working.
func _show_defeat_screen() -> void:
	var overlay := Control.new()
	overlay.name = "DefeatOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = DEFEAT_OVERLAY_Z
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var shade := ColorRect.new()
	shade.name = "DefeatShade"
	shade.color = Color(0, 0, 0, 0.46)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var hero_id := HeroRoster.hero_for(_level_id)
	var character_file := defeat_character_file(hero_id)
	var character_texture := _defeat_texture(character_file)
	if character_texture == null:
		character_file = "defeat_archer.png"
		character_texture = _defeat_texture(character_file)
	if character_texture != null:
		var character := TextureRect.new()
		character.name = "DefeatCharacter"
		character.texture = character_texture
		character.set_meta("source_path", DEFEAT_DIR + character_file)
		character.set_meta("hero", hero_id)
		character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		character.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		character.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		character.mouse_filter = Control.MOUSE_FILTER_IGNORE
		character.z_index = 1
		_place(character, _defeat_character_rect(character_texture))
		overlay.add_child(character)

	var panel := Control.new()
	panel.name = "DefeatPanel"
	panel.z_index = 2
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, _defeat_panel_rect())
	overlay.add_child(panel)

	var panel_texture := _defeat_texture("defeat_panel.png")
	if panel_texture != null:
		var shadow := _make_drop_shadow(panel_texture, Rect2(Vector2(2, 4), panel.size), 2.2, 0.5)
		if shadow != null:
			shadow.name = "DefeatPanelShadow"
			shadow.z_index = 0
			panel.add_child(shadow)
		var art := TextureRect.new()
		art.name = "DefeatPanelArt"
		art.texture = panel_texture
		art.set_meta("source_path", DEFEAT_PANEL_ART)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.z_index = 1
		_place(art, Rect2(Vector2.ZERO, panel.size))
		panel.add_child(art)
	else:
		var fallback := Panel.new()
		fallback.name = "DefeatPanelArt"
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#5b4a42")
		style.border_color = Color("#d9a441")
		style.set_border_width_all(4)
		style.set_corner_radius_all(12)
		fallback.add_theme_stylebox_override("panel", style)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.z_index = 1
		_place(fallback, Rect2(Vector2.ZERO, panel.size))
		panel.add_child(fallback)

	var locale := _defeat_locale()
	var title_texture := _defeat_texture(str(DEFEAT_TITLE_ART[locale]))
	if title_texture != null:
		var title := TextureRect.new()
		title.name = "DefeatTitle"
		title.texture = title_texture
		title.set_meta("source_path", DEFEAT_DIR + str(DEFEAT_TITLE_ART[locale]))
		title.set_meta("locale", locale)
		title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.z_index = 2
		_place(title, _defeat_title_rect())
		panel.add_child(title)
	else:
		var fallback_title := Label.new()
		fallback_title.name = "DefeatTitle"
		fallback_title.text = Localizer.t("defeat")
		fallback_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback_title.add_theme_font_size_override("font_size", 28 if _is_landscape else 30)
		fallback_title.add_theme_color_override("font_color", Color("#ffd86b"))
		UiHelpers.add_text_shadow(fallback_title, 4)
		fallback_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback_title.z_index = 2
		_place(fallback_title, _defeat_title_rect())
		panel.add_child(fallback_title)

	var retry := _make_defeat_button(
		"DefeatRetry", str(DEFEAT_RETRY_ART[locale]), _defeat_retry_rect(),
		"retry", func(): Game.restart_level())
	retry.z_index = 2
	panel.add_child(retry)
	var quit := _make_defeat_button(
		"DefeatQuit", str(DEFEAT_QUIT_ART[locale]), _defeat_quit_rect(),
		"menu", _on_back)
	quit.z_index = 2
	panel.add_child(quit)

# Hero -> defeat art, per the HeroRoster contract. Everything that is not bunny/cat/sacer
# uses the archer plate; the caller falls back to the archer file if a PNG is missing.
static func defeat_character_file(hero_id: String) -> String:
	return HeroRoster.defeat_character_file(hero_id)

func _defeat_locale() -> String:
	return "pt" if Localizer.current == "pt" else "en"

func _defeat_texture(file_name: String) -> Texture2D:
	var path := DEFEAT_DIR + file_name
	if not ResourceLoader.exists(path):
		return null
	return UiHelpers.hires_texture(path)

func _defeat_panel_rect() -> Rect2:
	return _pick(DEFEAT_PANEL_LANDSCAPE, DEFEAT_PANEL_PORTRAIT)

func _defeat_title_rect() -> Rect2:
	return Rect2(24, 24, 220, 81) if _is_landscape else Rect2(30, 26, 210, 78)

func _defeat_retry_rect() -> Rect2:
	return Rect2(39, 112, 190, 56) if _is_landscape else Rect2(45, 112, 180, 53)

func _defeat_quit_rect() -> Rect2:
	return Rect2(39, 176, 190, 56) if _is_landscape else Rect2(45, 174, 180, 53)

func _defeat_character_rect(texture: Texture2D) -> Rect2:
	var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
	# Large hero on the left, allowed to bleed off the left and bottom screen edges; the
	# stone window is drawn over her.
	var screen_h := get_viewport_rect().size.y
	var height := screen_h * (1.0 if _is_landscape else 0.74)
	var width := minf(height * aspect, get_viewport_rect().size.x * (0.62 if _is_landscape else 1.05))
	height = width / aspect
	var top := screen_h - height + height * 0.03 if _is_landscape else 30.0
	return Rect2(-width * (0.10 if _is_landscape else 0.20), top, width, height)

# A localised defeat plate. If the PNG is missing, the old text button is used as a safe
# fallback; the art itself carries the label, so no duplicate Label is drawn over it.
func _make_defeat_button(node_name: String, file_name: String, rect: Rect2, label_key: String, callback: Callable) -> Button:
	var texture := _defeat_texture(file_name)
	if texture == null:
		var fallback := _make_end_button(Localizer.t(label_key), callback)
		fallback.name = node_name
		_place(fallback, rect)
		return fallback
	var btn := _make_face_button(node_name, texture, rect.size, Localizer.t(label_key), callback)
	btn.set_meta("source_path", DEFEAT_DIR + file_name)
	_place(btn, rect)
	return btn

# Board-art geometry: the stone window's inner hole as fractions of the PNG (1165x1350).
const VICTORY_HOLE := Rect2(0.235, 0.205, 0.53, 0.60)

# The victory composition, same arrangement as the defeat one: the celebrating bunny large on
# the left, the painted board with the localised title and the earned stars plaque, and the
# painted Continue / Retry / Quit buttons. `endless` swaps the plaque for the round summary
# (ctx["lines"]: Controls) and drops Retry; the shade covers the whole screen, HUD included.
func _show_victory_screen(endless: bool, ctx: Dictionary) -> void:
	var overlay := Control.new()
	overlay.name = "VictoryOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = DEFEAT_OVERLAY_Z
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var shade := ColorRect.new()
	shade.name = "VictoryShade"
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var screen := get_viewport_rect().size
	var locale := _defeat_locale()

	var board_texture := UiHelpers.hires_texture(VICTORY_BOARD_ART)
	var board_aspect := 0.863
	if board_texture != null:
		board_aspect = float(board_texture.get_width()) / float(board_texture.get_height())
	var board_h: float
	if _is_landscape:
		board_h = minf(screen.y - 46.0, 312.0)
	else:
		board_h = minf(minf(screen.y - 150.0, 360.0), (screen.x - 30.0) / board_aspect)
	var board_w := board_h * board_aspect
	var board_x: float
	var board_y: float
	if _is_landscape:
		board_x = maxf(screen.x * 0.5, screen.x - board_w - 44.0)
		board_y = screen.y - board_h - 6.0
	else:
		board_x = (screen.x - board_w) * 0.5 + 8.0
		board_y = (screen.y - board_h) * 0.5 + 52.0
	var board_rect := Rect2(board_x, board_y, board_w, board_h)

	# The bunny: large, behind the board, bleeding off the left/bottom edges.
	var bunny_texture := _victory_texture(VICTORY_BUNNY_ART)
	if bunny_texture != null:
		var aspect := float(bunny_texture.get_width()) / float(bunny_texture.get_height())
		var bh := screen.y * (1.0 if _is_landscape else 0.95)
		var bw := bh * aspect
		if _is_landscape and bw > screen.x * 0.62:
			bw = screen.x * 0.62
			bh = bw / aspect
		var bunny := _make_art("VictoryCharacter", bunny_texture,
			Rect2(-bw * (0.06 if _is_landscape else 0.30), screen.y - bh + bh * 0.02 if _is_landscape else -46.0, bw, bh))
		bunny.set_meta("source_path", VICTORY_BUNNY_ART)
		bunny.z_index = 1
		overlay.add_child(bunny)

	var panel := Control.new()
	panel.name = "VictoryPanel"
	panel.z_index = 2
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, board_rect)
	overlay.add_child(panel)

	if board_texture != null:
		var board_shadow := _make_drop_shadow(board_texture, Rect2(Vector2(2, 4), board_rect.size), 2.2, 0.5)
		if board_shadow != null:
			panel.add_child(board_shadow)
		var board := _make_art("VictoryBoard", board_texture, Rect2(Vector2.ZERO, board_rect.size), true)
		board.set_meta("source_path", VICTORY_BOARD_ART)
		panel.add_child(board)

	var hole := Rect2(board_rect.size * VICTORY_HOLE.position, board_rect.size * VICTORY_HOLE.size)

	# Title straddling the board's top laurel.
	var title_path: String = VICTORY_DIR + str(VICTORY_TITLE_ART[locale])
	var title_texture := _victory_texture(title_path)
	if title_texture != null:
		var tw := board_w * 0.82
		var th := tw * float(title_texture.get_height()) / float(title_texture.get_width())
		var title := _make_art("VictoryTitle", title_texture,
			Rect2((board_w - tw) * 0.5, -th * 0.52, tw, th))
		title.set_meta("source_path", title_path)
		title.set_meta("locale", locale)
		title.z_index = 2
		panel.add_child(title)
	else:
		var fallback := _make_end_label(Localizer.t("level_complete"), 26, GOLD)
		_place(fallback, Rect2(0, -34, board_w, 40))
		panel.add_child(fallback)

	# Buttons: [node name, art path, label key, callback].
	var specs: Array = []
	var has_next := endless or LevelLoader.level_exists(int(controller.level_id) + 1)
	if has_next:
		var cont_cb: Callable = func(): Game.restart_level()
		if not endless:
			cont_cb = func(): Game.start_level(int(controller.level_id) + 1)
		specs.append(["VictoryContinue", V2_KIT_DIR + str(END_CONTINUE_ART[locale]),
			"next_round" if endless else "next_level", cont_cb])
	if not endless:
		specs.append(["VictoryRetry", VICTORY_DIR + str(VICTORY_RETRY_ART[locale]), "retry",
			func(): Game.restart_level()])
	var quit_cb: Callable = func(): Game.go_to_menu()
	if endless:
		quit_cb = _on_back
	specs.append(["VictoryQuit", V2_KIT_DIR + str(END_EXIT_ART[locale]), "menu", quit_cb])

	var gap := 3.0
	var btn_w := hole.size.x * 0.94
	var textures: Array = []
	var btn_h_total := 0.0
	for spec in specs:
		var tex := _victory_texture(str(spec[1]))
		textures.append(tex)
		btn_h_total += btn_w * float(tex.get_height()) / float(tex.get_width()) if tex != null else 36.0
	btn_h_total += gap * (specs.size() - 1)
	var top_h := hole.size.y * (0.40 if endless else 0.36)
	var avail_buttons := hole.size.y - top_h - 4.0
	var shrink := minf(1.0, avail_buttons / maxf(1.0, btn_h_total))
	btn_w *= shrink

	# Top block: the earned stars plaque, or the endless round summary.
	var top_rect := Rect2(hole.position, Vector2(hole.size.x, top_h))
	if endless:
		var column := VBoxContainer.new()
		column.name = "VictorySummary"
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 1)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(column, top_rect)
		column.z_index = 2
		for line in ctx.get("lines", []):
			column.add_child(line)
		panel.add_child(column)
	else:
		var stars_path := VICTORY_DIR + "victory_stars_%d.png" % clampi(controller.stars, 1, 3)
		var stars_texture := _victory_texture(stars_path)
		if stars_texture != null:
			var ratio := float(stars_texture.get_width()) / float(stars_texture.get_height())
			var sw := minf(top_rect.size.x * 1.04, top_rect.size.y * ratio)
			var sh := sw / ratio
			var plaque := _make_art("VictoryStars", stars_texture,
				Rect2(top_rect.position + Vector2((top_rect.size.x - sw) * 0.5, (top_rect.size.y - sh) * 0.5), Vector2(sw, sh)))
			plaque.set_meta("source_path", stars_path)
			plaque.set_meta("stars", clampi(controller.stars, 1, 3))
			plaque.z_index = 2
			plaque.pivot_offset = plaque.size * 0.5
			plaque.scale = Vector2(0.3, 0.3)
			plaque.modulate.a = 0.0
			panel.add_child(plaque)
			var pop := create_tween()
			pop.set_parallel(true)
			pop.tween_property(plaque, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.tween_property(plaque, "modulate:a", 1.0, 0.2)

	var by := top_rect.end.y + 4.0 + maxf(0.0, avail_buttons - btn_h_total * shrink) * 0.5
	for i in specs.size():
		var spec: Array = specs[i]
		var tex: Texture2D = textures[i]
		var size := Vector2(btn_w, 36.0 * shrink)
		if tex != null:
			size = Vector2(btn_w, btn_w * float(tex.get_height()) / float(tex.get_width()))
		var rect := Rect2(Vector2(hole.position.x + (hole.size.x - size.x) * 0.5, by), size)
		var btn: Button
		if tex != null:
			btn = _make_face_button(str(spec[0]), tex, size, Localizer.t(str(spec[2])), spec[3])
			btn.set_meta("source_path", str(spec[1]))
		else:
			btn = _make_end_button(Localizer.t(str(spec[2])), spec[3])
			btn.name = str(spec[0])
		_place(btn, rect)
		btn.z_index = 2
		panel.add_child(btn)
		by += size.y + gap * shrink

func _victory_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return UiHelpers.hires_texture(path)

# Endless end panels: a cleared round (the run goes on) or the end of the run.
func _show_endless_end(win: bool) -> void:
	if win:
		var cleared := _endless.complete_round()
		var round_number: int = int(cleared["round"]) - 1
		var lines: Array = []
		lines.append(_make_end_label("%s %d" % [Localizer.t("round_cleared"), round_number], 13, TEXT_PRIMARY))
		lines.append(_make_end_label("%s  +%d" % [Localizer.t("round_bonus"), int(cleared["bonus"])], 12, GOLD))
		for r in cleared["granted"]:
			var rtype := str(r.get("type", ""))
			var reward := UiHelpers.symbol_label("%s +%d" % [_power_icon(rtype), int(r.get("quantity", 0))], 12)
			reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reward.add_theme_color_override("font_color", GOLD)
			lines.append(reward)
		lines.append(_make_end_label("%s: %d" % [Localizer.t("score"), _endless.score], 12, TEXT_PRIMARY))
		_show_victory_screen(true, {"lines": lines})
		return
	var info := _open_end_panel()
	var result := _finish_endless_run()
	info.add_child(_make_end_label(Localizer.t("run_over"), 22, TEXT_MUTED))
	info.add_child(_make_end_label(str(result["score"]), 40, TEXT_PRIMARY))
	info.add_child(_make_end_label("%s: %d" % [Localizer.t("rounds_cleared"), int(result["rounds_cleared"])], 14, TEXT_PRIMARY))
	if bool(result["new_best"]):
		info.add_child(_make_end_label("★ %s" % Localizer.t("new_best"), 18, GOLD, true))
	else:
		info.add_child(_make_end_label("%s: %d" % [Localizer.t("best_score"), Game.progress.endless_best], 14, TEXT_MUTED))
	_add_end_mascot(info, false, "lose", {})
	var buttons := _add_end_buttons(info)
	buttons.add_child(_make_end_art_button("new_game", "play_again", func(): Game.start_endless()))
	buttons.add_child(_make_end_art_button("exit", "menu", _on_back))

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

# End-panel action plate from the v2 kit. The art carries the label; the fallback text
# button is only used when the PNG is unavailable.
func _make_end_art_button(kind: String, label_key: String, callback: Callable) -> Button:
	var locale := "pt" if Localizer.current == "pt" else "en"
	var art := ""
	match kind:
		"continue":
			art = str(END_CONTINUE_ART[locale])
		"new_game":
			art = str(END_NEW_GAME_ART[locale])
		"exit":
			art = str(END_EXIT_ART[locale])
	var texture := UiHelpers.hires_texture(V2_KIT_DIR + art) if not art.is_empty() else null
	if texture == null:
		return _make_end_button(Localizer.t(label_key), callback)
	var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
	var btn := _make_face_button("End" + kind.capitalize(), texture, Vector2(104, 104.0 / aspect), Localizer.t(label_key), callback)
	btn.set_meta("source_path", V2_KIT_DIR + art)
	btn.set_meta("locale", locale)
	return btn

# A flat button with a painted face (no text). The face is centred in the hit box, so a
# taller plate such as the PT retry banner never distorts; hover brightens and press dips it.
func _make_face_button(node_name: String, texture: Texture2D, size: Vector2, label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.custom_minimum_size = size
	btn.size = size
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.tooltip_text = label
	btn.set_meta("label", label)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	btn.pressed.connect(callback)
	var shadow := _make_drop_shadow(texture, Rect2(Vector2(2, 3), size), 1.8, 0.45)
	if shadow != null:
		shadow.name = "Shadow"
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		btn.add_child(shadow)
	var face := TextureRect.new()
	face.name = "Face"
	face.texture = texture
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(face, Rect2(Vector2.ZERO, size))
	btn.add_child(face)
	btn.button_down.connect(func(): face.position.y = 1.0)
	btn.button_up.connect(func(): face.position.y = 0.0)
	btn.mouse_entered.connect(func(): face.modulate = Color(1.12, 1.12, 1.12))
	btn.mouse_exited.connect(func(): face.modulate = Color.WHITE)
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
	_play_effect("play_level_start")
	var overlay := Control.new()
	overlay.name = "IntroOverlay"
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
	var rect := _rect("plaque")
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
	_star_overlay_index = -1
	_star_burn_state = -1

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
	var overlay_index := stars - 1 if stars > 1 else -1
	if overlay_index != _star_overlay_index:
		if overlay_index > 0:
			stars_overlay.texture = UiHelpers.hud_texture(STARS_PATH_FORMAT % overlay_index)
		_star_overlay_index = overlay_index
	var burn_state := stars if playing and stars > 1 else 0
	if burn_state != _star_burn_state:
		stars_overlay.visible = burn_state > 0
		if burn_state == 0 and absf(stars_overlay.modulate.a) > 0.005:
			stars_overlay.modulate.a = 0.0
		_star_burn_state = burn_state
	if burn_state > 0:
		var burn := _star_burn(elapsed, stars)
		if absf(stars_overlay.modulate.a - burn) > 0.005:
			stars_overlay.modulate.a = burn

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
