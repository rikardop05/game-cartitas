extends Control

enum Screen { MENU, OPTIONS, HELP }

# Same warm palette as the level screen, so menu and game read as one product.
const WARM_BACKGROUND := UiHelpers.WARM_BACKGROUND
const TEXT_MUTED := UiHelpers.TEXT_MUTED
const GOLD := UiHelpers.GOLD

# The v2 art kit carries the whole menu now. Its painted banners are ~3.44:1, so the
# button box matches that ratio exactly and is drawn with linear filtering + mipmaps.
const V2_DIR := "res://assets/ui/kit/v2/"
const MENU_BUTTON_SIZE := Vector2(190, 55)
const MENU_BUTTON_ASPECT := 1130.0 / 330.0
const MENU_BUTTON_HEIGHT_PORTRAIT := 45.0
const MENU_BUTTON_HEIGHT_LANDSCAPE := 42.0
const MENU_BUTTON_ART := {
	"play": "Iniciar).png",
	"options": "Opcoes_.png",
	"quit": "sair_.png",
}
const MENU_ICON_SIZE := 36.0
const CONTINUE_ART := {"pt": "Continuar_.png", "en": "Layer 2.png"}

# Portrait stacks logo, plaque and stars with fixed gaps; landscape pins the logo/stars
# to the top-left and the plaque to the right.
const MENU_GAP_LOGO := 10.0
const MENU_GAP_STARS := 6.0
const MENU_EDGE := 14.0
const STARS_BAND := 22.0
const LANDSCAPE_MARGIN := 6.0

# Landscape tuning (hand-adjusted in the editor at 1280x720 = 640x360 logical px), kept as
# fractions of the board so it holds on other window sizes.
const LOGO_SCALE_LANDSCAPE := 1.35
const LOGO_CENTER_SHIFT_LANDSCAPE := -2.7
const LOGO_RISE_LANDSCAPE := 16.2 # logo top sits this far above the sign's visible top (y = 10 at 640x360)
const BOARD_TRIM_LANDSCAPE := 0.0911
const BOARD_TILT_DEG_LANDSCAPE := 0.3
const PANEL_DROP_LANDSCAPE := 0.0598

# v2 menu boards: the tall stone/banner board in portrait and the square three-slot
# wooden board in landscape. The rectangles below are the safe button areas (fractions
# of each art), so the plates sit on stone/wood and never over the carved frames.
const BOARDS := {
	"portrait": {
		"art": "panel_menu_board.png",
		"aspect": 1134.0 / 1387.0,
		"art_top": 8.0 / 1387.0,
		"art_bottom": 1234.0 / 1387.0,
		"art_left": 15.0 / 1134.0,
		"art_right": 1118.0 / 1134.0,
		"stone": Rect2(0.216, 0.216, 0.570, 0.508),
	},
	"landscape": {
		"art": "panel_menu_board.png",
		"aspect": 1134.0 / 1387.0,
		"art_top": 8.0 / 1387.0,
		"art_bottom": 1234.0 / 1387.0,
		"art_left": 15.0 / 1134.0,
		"art_right": 1118.0 / 1134.0,
		"stone": Rect2(0.216, 0.216, 0.570, 0.508),
	},
}
const BOARD_SHADOW_OFFSET := Vector2(0, 10)
const BOARD_SHADOW_SCALE := 1.012

# Options screen and help overlay art.
const OPTIONS_TITLE_ART := {"pt": "config_2.png", "en": "Configu.png"}
const GEAR_ART := "Config_Icon.png"
const HELP_ART := "interrog.png"
const VOLUME_HANDLE_ART := "Regulagem_botton.png"
# New Atele additions: the Options overlay frame, its row plates and the confirm/close badges.
const OPTIONS_PANEL_ART := "panel_options.png"
const OPTIONS_PANEL_ASPECT := 1227.0 / 1202.0
const CONFIG_ROW_ART := ["config_row_1.png", "config_row_2.png", "config_row_3.png"]
const ACCEPT_V2_ART := "icon_accept_v2.png"
const CLOSE_V2_ART := "icon_close_v2.png"

# Branding and the decorative hero behind the sign.
const LOGO_ART := "res://assets/ui/branding/logo_claw_and_crown.png"
const HERO_ART := "res://assets/ui/heroes/hero_menu_wolf.png"
const BACK_ICON_ART := "res://assets/ui/kit/v2/icon_back.png"
const LOGO_HEIGHT_LANDSCAPE := 84.0
const LOGO_HEIGHT_PORTRAIT := 92.0
const MENU_BACKGROUNDS: Array[Dictionary] = [
	# Every supplied scene has at least one painted character, so separate character sprites stay off.
	{"path": "res://assets/ui/menu_backgrounds/menu_bg_harbor.png", "show_heroes": false},
	{"path": "res://assets/ui/menu_backgrounds/menu_bg_training.png", "show_heroes": false},
	{"path": "res://assets/ui/menu_backgrounds/menu_bg_cathedral.png", "show_heroes": false},
	{"path": "res://assets/ui/menu_backgrounds/menu_bg_library.png", "show_heroes": false},
	{"path": "res://assets/ui/menu_backgrounds/menu_bg_castle.png", "show_heroes": false},
	{"path": "res://assets/ui/menu_backgrounds/menu_bg_forest.png", "show_heroes": false},
]
static var _session_menu_background := ""
static var _back_icon_texture_cache: Texture2D = null

# Parallax kept in logical pixels: the far background moves least, the sign a bit more and the
# title/buttons column the most. The layers are shifted as whole containers, never per button.
# The strength was reduced ~30% so the menu reads as gentle depth instead of sliding around.
const PARALLAX_BG := Vector2(2.8, 2.1)
const PARALLAX_BOARD := Vector2(6.3, 4.2)
const PARALLAX_CONTENT := Vector2(8.4, 5.6)
const PARALLAX_LERP := 6.0
const PARALLAX_BLEED := 12.0

var _screen: Screen = Screen.MENU
var _reset_armed := false
var _bg_layer: Control
var _board_layer: Control
var _hero: TextureRect
var _hero_secondary: TextureRect
var _board: TextureRect
var _board_shadow: TextureRect
var _content: Control
var _logo: Control
var _panel: Control
var _stars: Label
var _menu_buttons: Array[Button] = []
var _menu_icons: Array[Control] = []
var _content_base := Vector2.ZERO
var _pointer := Vector2.ZERO
var _pointer_goal := Vector2.ZERO
var _manual_pointer := false
var _clock := 0.0
var _resize_queued := false
var _menu_background_path := ""
var _menu_background_show_heroes := false

func _ready() -> void:
	theme = UiHelpers.warm_theme()
	_menu_background_path = _pick_session_menu_background()
	resized.connect(_on_viewport_resized)
	_build()
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.play_menu(self)

# Menu music fades out here, but only if no other scene has claimed the audio already.
func _exit_tree() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.release(self)

func _process(delta: float) -> void:
	if _content == null:
		return
	_clock += delta
	if not _manual_pointer:
		_pointer_goal = _mouse_pointer()
	# Frame-rate independent smoothing; snap the last sub-pixel so the menu never trembles.
	_pointer = _pointer.lerp(_pointer_goal, 1.0 - exp(-PARALLAX_LERP * delta))
	if _pointer.distance_squared_to(_pointer_goal) < 0.000001:
		_pointer = _pointer_goal
	var bob := sin(_clock * 0.85) * 2.0
	var tilt := sin(_clock * 0.6) * 0.007
	if is_instance_valid(_bg_layer):
		_bg_layer.position = Vector2(-PARALLAX_BLEED, -PARALLAX_BLEED) - _pointer * PARALLAX_BG
	if is_instance_valid(_board_layer):
		_board_layer.position = Vector2(0, bob) - _pointer * PARALLAX_BOARD
	if is_instance_valid(_board):
		_board.rotation = tilt
	if is_instance_valid(_board_shadow):
		_board_shadow.rotation = tilt
	_content.position = _content_base - _pointer * PARALLAX_CONTENT

# Drives the layered parallax directly (used by the visual check instead of a real mouse):
# -1..1 per axis, smoothed by _process like the pointer.
func set_parallax(value: Vector2) -> void:
	_manual_pointer = true
	_pointer = value.limit_length(1.0)
	_pointer_goal = _pointer

func _mouse_pointer() -> Vector2:
	var window := get_window()
	if window == null or not window.has_focus():
		return Vector2.ZERO
	var cursor := DisplayServer.mouse_get_position()
	if not Rect2i(window.position, window.size).has_point(cursor):
		return Vector2.ZERO
	var rel := Vector2(cursor - window.position) / Vector2(window.size)
	return (rel * 2.0 - Vector2.ONE).limit_length(1.0)

func _build() -> void:
	_bg_layer = null
	_board_layer = null
	_hero = null
	_hero_secondary = null
	_board = null
	_board_shadow = null
	_content = null
	_logo = null
	_panel = null
	_stars = null
	_menu_buttons.clear()
	_menu_icons.clear()
	# Reset the parallax on every rebuild: coming back from Options must not inherit
	# the pointer/offset of the screen that was just torn down. Keep the manual test
	# hook state so a scripted set_parallax() stays stable across the rebuild.
	_pointer = Vector2.ZERO
	_pointer_goal = Vector2.ZERO
	_content_base = Vector2.ZERO
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if _screen == Screen.MENU:
		_build_menu()
	else:
		add_child(UiHelpers.make_background(_landscape()))
		match _screen:
			Screen.HELP:
				_build_help()
			_:
				_build_options()
	_connect_click_sounds(self)

# Every button of the menu screens (main menu, Level selector, Options) clicks. Connected once
# per rebuild: the nodes are recreated each time, so nothing is connected twice.
func _connect_click_sounds(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			(child as BaseButton).pressed.connect(_play_click)
		_connect_click_sounds(child)

func _play_click() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.play_ui_click()

func _landscape() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.x >= viewport_size.y

func _has_progress() -> bool:
	return Game.progress != null and (
		Game.progress.total_stars() > 0
		or Game.progress.get_unlocked_level() > 1
		or Game.progress.endless_best > 0)

# Pick one of the six delivered paintings once per application session. The stored
# zero-based index points at the image currently shown, so the next launch advances.
func _pick_session_menu_background() -> String:
	if not _session_menu_background.is_empty():
		var session_spec := _menu_background_spec(_session_menu_background)
		_menu_background_show_heroes = bool(session_spec.get("show_heroes", false))
		return _session_menu_background
	var previous := int(Game.settings.get("menu_bg_index", -1))
	var next_index := posmod(previous + 1, MENU_BACKGROUNDS.size())
	var selected: Dictionary = MENU_BACKGROUNDS[next_index]
	_session_menu_background = str(selected["path"])
	_menu_background_show_heroes = bool(selected["show_heroes"])
	Game.settings["menu_bg_index"] = next_index
	Game.save_progress()
	return _session_menu_background

func _menu_background_spec(path: String) -> Dictionary:
	for spec in MENU_BACKGROUNDS:
		if str(spec["path"]) == path:
			return spec
	return {}

func _on_viewport_resized() -> void:
	if _resize_queued or not is_inside_tree():
		return
	_resize_queued = true
	call_deferred("_relayout_after_resize")

func _relayout_after_resize() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_resize_queued = false
	if is_inside_tree():
		_build()

func _build_menu() -> void:
	var landscape := _landscape()

	_bg_layer = Control.new()
	_bg_layer.name = "BackgroundLayer"
	_bg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_layer.offset_left = -PARALLAX_BLEED
	_bg_layer.offset_top = -PARALLAX_BLEED
	_bg_layer.offset_right = PARALLAX_BLEED
	_bg_layer.offset_bottom = PARALLAX_BLEED
	_bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_layer)
	var background := UiHelpers.make_background(landscape, 0, _menu_background_path)
	# The painted menu scenes already have their own legibility; avoid the gameplay
	# background filter's fullscreen samples while moving the parallax layers.
	background.material = null
	_bg_layer.add_child(background)

	_board_layer = Control.new()
	_board_layer.name = "BoardLayer"
	_board_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_layer)
	_make_menu_board()

	_content = Control.new()
	_content.name = "MenuContent"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The hero is in front of the sign in portrait (z=1); content stays above it (z=2).
	_content.z_index = 2
	add_child(_content)
	_content_base = Vector2.ZERO
	_content.position = _content_base
	# Absolute layout everywhere: the sign, the logo, the buttons and the stars are placed
	# by _layout_board() once the button sizes are known, so the logo can never slide over
	# the plaque in one orientation and the hero never covers the buttons in the other.
	_logo = _make_logo(landscape)
	_content.add_child(_logo)
	_panel = _make_menu_panel()
	_content.add_child(_panel)
	_stars = _make_total_stars(16)
	if landscape:
		_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_stars)
	# v2 shortcuts: the gear opens Options and the "?" opens the help overlay.
	_menu_icons.clear()
	_menu_icons.append(_make_v2_icon_button("ConfigButton", GEAR_ART, Localizer.t("options"), _on_options))
	_menu_icons.append(_make_v2_icon_button("HelpButton", HELP_ART, Localizer.t("help"), _on_help))
	for icon in _menu_icons:
		_content.add_child(icon)
	_layout_after_frame()

# Small painted v2 icon (gear/settings, question mark/help) used as a menu shortcut.
func _make_v2_icon_button(node_name: String, art_name: String, label: String, callback: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.name = node_name
	btn.texture_normal = _v2_texture(art_name)
	btn.set_meta("source_path", V2_DIR + art_name)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	btn.custom_minimum_size = Vector2(MENU_ICON_SIZE, MENU_ICON_SIZE)
	btn.size = Vector2(MENU_ICON_SIZE, MENU_ICON_SIZE)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.tooltip_text = label
	btn.set_meta("label", label)
	btn.pressed.connect(callback)
	btn.button_down.connect(func(): btn.modulate = Color(0.82, 0.82, 0.82))
	btn.button_up.connect(func(): btn.modulate = Color.WHITE)
	btn.mouse_entered.connect(func(): btn.modulate = Color(1.12, 1.12, 1.12))
	btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
	return btn

# Loads a texture straight from the v2 kit (mipmapped/cached), or null when missing.
func _v2_texture(art_name: String) -> Texture2D:
	var path := V2_DIR + art_name
	if not ResourceLoader.exists(path):
		return null
	return UiHelpers.hires_texture(path)

func _make_menu_panel() -> Control:
	var panel := Control.new()
	panel.name = "MenuPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_buttons.clear()
	if _has_progress():
		var locale := "pt" if Localizer.current == "pt" else "en"
		_menu_buttons.append(_make_menu_button(
			"ContinueButton", "continue", str(CONTINUE_ART[locale]), _on_continue))
	_menu_buttons.append(_make_menu_button("PlayButton", "play", MENU_BUTTON_ART["play"], _on_play))
	_menu_buttons.append(_make_menu_button("OptionsButton", "options", MENU_BUTTON_ART["options"], _on_options))
	_menu_buttons.append(_make_menu_button("QuitButton", "quit", MENU_BUTTON_ART["quit"], _on_quit))
	for btn in _menu_buttons:
		panel.add_child(btn)
	return panel

func _make_total_stars(font_size: int) -> Label:
	var total_stars := UiHelpers.symbol_label(UiHelpers.total_stars_text(), font_size)
	total_stars.name = "TotalStars"
	total_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_stars.add_theme_color_override("font_color", GOLD)
	return total_stars

# Painted Claw & Crown logo in the old title slot: intrinsic aspect, centred, and
# never wider than the sign it sits over. Falls back to the localized title if the
# art is missing so the menu still reads.
func _make_logo(landscape: bool) -> Control:
	var texture := UiHelpers.hires_texture(LOGO_ART)
	if texture == null:
		var title := Label.new()
		title.name = "Logo"
		title.text = Localizer.t("title")
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 30 if landscape else 34)
		title.custom_minimum_size = Vector2(240.0, 44.0 if landscape else 52.0)
		return title
	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.texture = texture
	logo.set_meta("source_path", LOGO_ART)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var height := LOGO_HEIGHT_LANDSCAPE if landscape else LOGO_HEIGHT_PORTRAIT
	var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
	logo.custom_minimum_size = Vector2(height * aspect, height)
	return logo

func _layout_after_frame() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_layout_board()

func _board_spec() -> Dictionary:
	return BOARDS["landscape" if _landscape() else "portrait"]

func _make_menu_board() -> void:
	_make_hero()
	var spec := _board_spec()
	var texture := _v2_texture(str(spec["art"]))
	if texture == null:
		return
	_board_shadow = _make_shadow_rect(texture, 14.0, 0.55)
	_board_shadow.name = "BoardShadow"
	_board_shadow.scale = Vector2(BOARD_SHADOW_SCALE, BOARD_SHADOW_SCALE)
	_board_layer.add_child(_board_shadow)

	_board = _make_texture_rect(texture)
	_board.name = "Board"
	_board.set_meta("source_path", V2_DIR + str(spec["art"]))
	_board_layer.add_child(_board)

# The round-2 paintings include characters of their own. The per-background policy
# controls this optional foreground pair without relying on filenames or orientation.
func _make_hero() -> void:
	if not _landscape() or not _menu_background_show_heroes:
		return
	var view := get_viewport_rect().size
	var art_paths := [
		"res://assets/ui/heroes/hero_bunny.png",
		"res://assets/ui/heroes/hero_cat_mage.png",
	]
	for i in art_paths.size():
		var texture := UiHelpers.hires_texture(str(art_paths[i]))
		if texture == null:
			continue
		var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
		var width := view.x * 0.27
		var height := minf(view.y * 0.78, width / maxf(0.1, aspect))
		width = height * aspect
		var rect := _make_texture_rect(texture)
		rect.name = "MenuHero" if i == 0 else "MenuHeroSecondary"
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size = Vector2(width, height)
		rect.position = Vector2(view.x * (0.50 + i * 0.22), view.y - height + 8.0)
		rect.z_index = 0
		_board_layer.add_child(rect)
		if i == 0:
			_hero = rect
		else:
			_hero_secondary = rect

func _make_texture_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# The soft shadow is pre-rendered once (blurred alpha in a small texture) and cached:
# no per-frame 9-tap shader over the large sign art, and no pixelated edge.
func _make_shadow_rect(texture: Texture2D, softness: float, strength: float) -> TextureRect:
	var shadow := UiHelpers.shadow_texture(texture, softness, strength)
	if shadow == null:
		return _make_texture_rect(texture)
	var rect := _make_texture_rect(shadow)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return rect

# Responsive four-button composition. The portrait art board is used in both orientations;
# its intrinsic stone area is scaled to fit four banners, with the landscape panel anchored left.
func _layout_board() -> void:
	if not is_instance_valid(_board) or not is_instance_valid(_board_shadow):
		return
	if _menu_buttons.is_empty() or not is_instance_valid(_menu_buttons[0]):
		return
	if not is_instance_valid(_panel) or not is_instance_valid(_logo) or not is_instance_valid(_stars):
		return
	var view := get_viewport_rect().size
	var landscape := _landscape()
	var spec := _board_spec()
	var aspect: float = spec["aspect"]
	var art_top: float = spec["art_top"]
	var art_bottom: float = spec["art_bottom"]
	var visible_fraction: float = art_bottom - art_top
	var logo_size: Vector2 = _logo.custom_minimum_size
	var board_size: Vector2
	if landscape:
		var height := minf(view.y - 12.0, view.x * 0.45 / aspect)
		board_size = Vector2(height * aspect, height)
	else:
		var reserved := logo_size.y + MENU_GAP_LOGO + MENU_GAP_STARS + STARS_BAND + MENU_EDGE * 2.0
		var height := minf((view.y - reserved) / visible_fraction, (view.x - 12.0) / aspect)
		board_size = Vector2(height * aspect, height)
	var visible_height := visible_fraction * board_size.y
	var origin := Vector2.ZERO
	var logo_pos := Vector2.ZERO
	var stars_pos := Vector2.ZERO
	if landscape:
		var visible_top := (view.y - visible_height) * 0.5
		origin = Vector2(10.0, visible_top - art_top * board_size.y)
		# Hand-tuned at 1280x720: a 1.35x logo, a touch left of the board's centre, top at y = 10.
		logo_size *= LOGO_SCALE_LANDSCAPE
		logo_pos = Vector2(
			origin.x + board_size.x * 0.5 + LOGO_CENTER_SHIFT_LANDSCAPE - logo_size.x * 0.5,
			maxf(2.0, visible_top - LOGO_RISE_LANDSCAPE))
		stars_pos = Vector2(0.0, view.y - STARS_BAND - 2.0)
	else:
		var logo_overlap := 24.0
		var total := logo_size.y + visible_height - logo_overlap + MENU_GAP_STARS + STARS_BAND
		var top := maxf(6.0, (view.y - total) * 0.5)
		origin = Vector2((view.x - board_size.x) * 0.5, top + logo_size.y - logo_overlap - art_top * board_size.y)
		logo_pos = Vector2((view.x - logo_size.x) * 0.5, top)
		stars_pos = Vector2(0.0, top + logo_size.y - logo_overlap + visible_height + MENU_GAP_STARS)
	origin.x = _clamp_inside(origin.x, view.x, spec["art_left"], spec["art_right"], board_size.x)
	origin.y = _clamp_inside(origin.y, view.y, art_top, art_bottom, board_size.y)
	# Both the sign and its shadow live in the parallax layer; subtract the layer's
	# current offset so the origin stays expressed in the untransformed layout space.
	var layer_offset := _board_layer.position
	# Landscape sign: squashed from the top (bottom edge fixed) and tilted a hair, as tuned by hand.
	var art_origin := origin
	var art_size := board_size
	var tilt := 0.0
	var panel_drop := 0.0
	if landscape:
		var trim := board_size.y * BOARD_TRIM_LANDSCAPE
		art_origin.y += trim
		art_size.y -= trim
		tilt = BOARD_TILT_DEG_LANDSCAPE
		panel_drop = board_size.y * PANEL_DROP_LANDSCAPE
	_board.size = art_size
	_board.position = art_origin - layer_offset
	_board.pivot_offset = board_size * 0.5
	_board.rotation_degrees = tilt
	_board_shadow.size = art_size
	_board_shadow.position = art_origin + BOARD_SHADOW_OFFSET - layer_offset
	_board_shadow.pivot_offset = board_size * 0.5
	_board_shadow.rotation_degrees = tilt

	# Buttons: the panel is a full-board container, so plates are placed in board space.
	# In landscape the panel top sits PANEL_DROP lower, which slides the whole stack down.
	_panel.size = Vector2(board_size.x, board_size.y - panel_drop)
	_panel.position = origin + Vector2(0.0, panel_drop)
	var stone: Rect2 = spec["stone"]
	var area := Rect2(stone.position * board_size, stone.size * board_size)
	var gap := 4.0 if landscape else 5.0
	var max_height := MENU_BUTTON_HEIGHT_LANDSCAPE if landscape else MENU_BUTTON_HEIGHT_PORTRAIT
	var button_height := minf(max_height, (area.size.y - gap * (_menu_buttons.size() - 1)) / float(_menu_buttons.size()))
	var button_width := minf(area.size.x - 8.0, button_height * MENU_BUTTON_ASPECT)
	var button_size := Vector2(button_width, button_height)
	var stack := button_height * _menu_buttons.size() + gap * (_menu_buttons.size() - 1)
	var y := area.position.y + (area.size.y - stack) * 0.5
	for btn in _menu_buttons:
		btn.custom_minimum_size = button_size
		btn.size = button_size
		btn.position = Vector2((board_size.x - button_size.x) * 0.5, y)
		y += button_height + gap
	_logo.size = logo_size
	_logo.position = logo_pos
	_stars.size = Vector2(view.x, STARS_BAND)
	_stars.position = stars_pos
	# Total stars are available in the level selector; on the menu they collide with the scenic
	# composition at narrow and tablet aspect ratios, so keep the accessible node but hide it.
	_stars.visible = false
	_place_icons(Vector2(view.x - 8.0 - _icons_width(), 7.0))

func _icons_width() -> float:
	var gap := 10.0
	return MENU_ICON_SIZE * _menu_icons.size() + gap * maxf(0.0, _menu_icons.size() - 1.0)

func _place_icons(at: Vector2) -> void:
	var x := at.x
	for icon in _menu_icons:
		icon.size = Vector2(MENU_ICON_SIZE, MENU_ICON_SIZE)
		icon.position = Vector2(x, at.y)
		x += MENU_ICON_SIZE + 10.0

func _clamp_inside(origin: float, extent: float, art_from: float, art_to: float, board_extent: float) -> float:
	var low := 6.0 - art_from * board_extent
	var high := extent - 6.0 - art_to * board_extent
	if low > high:
		return (extent - (art_to - art_from) * board_extent) * 0.5 - art_from * board_extent
	return clampf(origin, low, high)

# v2 banner button. Both locales use the baked Portuguese artwork for now (the delivered
# look), so no localized text is drawn over the plate; the wording stays available through
# the tooltip, the meta label and the accessibility name.
func _make_menu_button(node_name: String, key: String, art_name: String, callback: Callable) -> Button:
	var texture := _v2_texture(art_name)
	if texture == null:
		texture = UiHelpers.kit_texture("pill")
	var btn := _make_face_button(texture, MENU_BUTTON_SIZE)
	btn.name = node_name
	btn.set_meta("source_path", V2_DIR + art_name)
	var label := Localizer.t(key)
	btn.tooltip_text = Localizer.t(key + "_tip")
	btn.set_meta("label", label)
	if btn.has_method("set_accessibility_name"):
		btn.call("set_accessibility_name", label)
	btn.pressed.connect(callback)
	return btn

# Button hosting a texture "Face" over a soft drop shadow: hover lifts it 2px, press dips it 3px.
func _make_face_button(texture: Texture2D, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = min_size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var shadow := _make_shadow_rect(texture, 1.8, 0.5)
	shadow.name = "Shadow"
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_top = 5
	shadow.offset_bottom = 5
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(shadow)
	var face := TextureRect.new()
	face.name = "Face"
	face.texture = texture
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The v2 plates are painted art; linear filtering + mipmaps keep them clean at any scale.
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(face)
	var lift := func(hovered: bool):
		face.position.y = -2 if hovered else 0
		shadow.offset_top = 7 if hovered else 5
		shadow.offset_bottom = 7 if hovered else 5
	btn.mouse_entered.connect(func():
		face.modulate = Color(1.12, 1.12, 1.12)
		lift.call(true))
	btn.mouse_exited.connect(func():
		face.modulate = Color.WHITE
		lift.call(false))
	btn.button_down.connect(func():
		face.position.y = 3
		face.modulate = Color(0.85, 0.85, 0.85)
		shadow.offset_top = 2
		shadow.offset_bottom = 2)
	btn.button_up.connect(func():
		var hovered := btn.is_hovered()
		lift.call(hovered)
		face.modulate = Color(1.12, 1.12, 1.12) if hovered else Color.WHITE)
	return btn

func _make_margin(parent: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	parent.add_child(margin)
	return margin

func _build_options() -> void:
	var landscape := _landscape()
	var margin := _make_margin(self)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	if not landscape:
		col.add_child(_make_options_title(46.0))

	# panel_options.png is the Options overlay background; the rows live inside its stone.
	var panel := _make_options_panel(landscape)
	col.add_child(panel)
	var vbox := panel.find_child("OptionsBody", true, false) as VBoxContainer
	if vbox == null:
		return
	var row_height := 28 if landscape else 40
	if landscape:
		vbox.add_child(_make_options_title(20.0))
	vbox.add_child(_make_option_row("LanguageButton", Localizer.t("language"), Localizer.t("language"), _on_toggle_language, row_height, CONFIG_ROW_ART[0]))
	vbox.add_child(_make_option_row("OrientationButton", _orientation_label(), Localizer.t("orientation_label"), _on_toggle_orientation, row_height, CONFIG_ROW_ART[1]))
	vbox.add_child(_make_option_row("MascotButton", _mascot_label(), Localizer.t("mascot_label"), _on_toggle_mascot, row_height, CONFIG_ROW_ART[2]))
	var volume := VolumeRow.new(row_height)
	_style_v2_volume_row(volume, CONFIG_ROW_ART[0], row_height)
	vbox.add_child(volume)
	if _reset_armed:
		vbox.add_child(_make_reset_confirm(row_height))
	else:
		vbox.add_child(_make_option_row("ResetButton", Localizer.t("reset"), Localizer.t("reset"), _on_reset, row_height, CONFIG_ROW_ART[1]))
	if landscape:
		vbox.add_child(_make_overlay_back_button())
	else:
		col.add_child(_make_overlay_back_button())

# v2 settings title plate, localized: "Configuração" (config_2) or "Settings" (Configu).
func _make_options_title(height: float) -> Control:
	var art: String = OPTIONS_TITLE_ART["pt" if Localizer.current == "pt" else "en"]
	var texture := _v2_texture(art)
	if texture == null:
		var fallback := Label.new()
		fallback.name = "OptionsTitle"
		fallback.text = Localizer.t("options")
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 22)
		return fallback
	var title := TextureRect.new()
	title.name = "OptionsTitle"
	title.texture = texture
	title.set_meta("source_path", V2_DIR + art)
	title.set_meta("label", Localizer.t("options"))
	title.tooltip_text = Localizer.t("options")
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
	title.custom_minimum_size = Vector2(height * aspect, height)
	return title

# The Options overlay: panel_options.png scaled to its own aspect, with a body margin that
# keeps every row on the painted stone (clear of the emblem and of the gold frame).
func _make_options_panel(landscape: bool) -> Control:
	var width := 351.0 if landscape else 344.0
	var height := width / OPTIONS_PANEL_ASPECT
	var frame := Control.new()
	frame.name = "OptionsPanel"
	frame.custom_minimum_size = Vector2(width, height)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var art := TextureRect.new()
	art.name = "PanelArt"
	art.texture = _v2_texture(OPTIONS_PANEL_ART)
	art.set_meta("source_path", V2_DIR + OPTIONS_PANEL_ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(art)
	var body := MarginContainer.new()
	body.name = "Body"
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	var side := int(round(width * 0.117))
	var vertical := int(round(height * 0.17))
	body.add_theme_constant_override("margin_left", side)
	body.add_theme_constant_override("margin_right", side)
	body.add_theme_constant_override("margin_top", vertical)
	body.add_theme_constant_override("margin_bottom", vertical)
	frame.add_child(body)
	var vbox := VBoxContainer.new()
	vbox.name = "OptionsBody"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2 if landscape else 4)
	body.add_child(vbox)
	return frame

# Option row on a config_row_N.png plate (9-sliced so the gem ends keep their shape).
func _make_option_row(node_name: String, text: String, tooltip: String, callback: Callable, height: int, art_name: String) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = text
	btn.custom_minimum_size = Vector2(0, height)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 16 if height >= 36 else 12)
	btn.tooltip_text = tooltip
	btn.pressed.connect(callback)
	_apply_v2_row_style(btn, art_name, height)
	return btn

func _apply_v2_row_style(btn: Button, art_name: String, row_height: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tint := Color.WHITE
		match state:
			"hover":
				tint = Color(1.12, 1.12, 1.12)
			"pressed":
				tint = Color(0.82, 0.82, 0.82)
			"disabled":
				tint = Color(0.65, 0.65, 0.65, 0.85)
		btn.add_theme_stylebox_override(state, _v2_row_style(art_name, tint, row_height))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", UiHelpers.TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func _v2_row_style(art_name: String, tint := Color.WHITE, row_height: int = 36) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var texture := _v2_texture(art_name)
	if texture != null:
		# Fit to the displayed row height, then 9-slice the gem end-caps while the centre expands.
		var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
		var target := Vector2(float(row_height) * aspect, float(row_height))
		var sliced := UiHelpers.trimmed_nine_patch(
			texture, target, Rect2(0.12, 0.14, 0.12, 0.14),
			"menu_row:%s:%d" % [art_name, row_height])
		style.texture = sliced.get("texture", texture)
		var margins: Rect2i = sliced.get("margins", Rect2i())
		style.texture_margin_left = margins.position.x
		style.texture_margin_top = margins.position.y
		style.texture_margin_right = margins.size.x
		style.texture_margin_bottom = margins.size.y
	style.draw_center = true
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.set_meta("source_path", V2_DIR + art_name)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	style.modulate_color = tint
	return style

# Volume gets the same config_row plate as the other rows, keeping its shared controls.
func _style_v2_volume_row(row: Control, art_name: String, row_height: int) -> void:
	row.custom_minimum_size.x = 0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _v2_row_style(art_name, Color.WHITE, row_height))
	_apply_v2_volume_handle(row)

# Second step of "Reset progress": the warning plus the v2 Accept/Close badges.
func _make_reset_confirm(height: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ResetConfirmRow"
	panel.custom_minimum_size = Vector2(0, height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _v2_row_style(CONFIG_ROW_ART[1], Color.WHITE, height))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var warning := Label.new()
	warning.name = "ResetWarning"
	warning.text = Localizer.t("reset_confirm")
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 11 if height >= 36 else 10)
	row.add_child(warning)
	row.add_child(_make_v2_action_icon("ResetConfirm", ACCEPT_V2_ART, Localizer.t("confirm"), _on_reset, height))
	row.add_child(_make_v2_action_icon("ResetCancel", CLOSE_V2_ART, Localizer.t("cancel"), _on_reset_cancel, height))
	return panel

# Circular v2 badge button (Accept/Close) with the same hover/press feel as the banners.
func _make_v2_action_icon(node_name: String, art_name: String, tooltip: String, callback: Callable, icon_size: int) -> Button:
	var btn := _make_face_button(_v2_texture(art_name), Vector2(icon_size, icon_size))
	btn.name = node_name
	btn.set_meta("source_path", V2_DIR + art_name)
	btn.tooltip_text = tooltip
	btn.set_meta("label", tooltip)
	btn.pressed.connect(callback)
	return btn

# Stone/gold dialog window of the Help overlay (the Options overlay uses panel_options.png).
func _make_v2_window() -> PanelContainer:
	var window := PanelContainer.new()
	window.name = "Window"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#392e27")
	style.border_color = Color("#d9a441")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	window.add_theme_stylebox_override("panel", style)
	return window

# Options/help return button: the gold arrow fills a larger touch target than the header arrow.
func _make_overlay_back_button() -> Button:
	return _make_back_button(Vector2(48.0, 48.0))

# Replaces the shared VolumeRow handle with the v2 green gem (kept vertical, centred in
# the 32 px hit box). The row itself keeps working untouched for the in-game settings.
func _apply_v2_volume_handle(row: Control) -> void:
	var handle := row.find_child("Handle", true, false) as TextureRect
	var texture := _v2_texture(VOLUME_HANDLE_ART)
	if handle == null or texture == null:
		return
	handle.texture = texture
	handle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	handle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	handle.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	handle.set_meta("source_path", V2_DIR + VOLUME_HANDLE_ART)

# Help overlay reached from the menu "?" badge: the localized rules and a v2 return plate.
func _build_help() -> void:
	var margin := _make_margin(self)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var icon := TextureRect.new()
	icon.name = "HelpIcon"
	icon.texture = _v2_texture(HELP_ART)
	icon.set_meta("source_path", V2_DIR + HELP_ART)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)

	var window := _make_v2_window()
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(window)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window.add_child(scroll)
	var text := Label.new()
	text.name = "HelpText"
	text.text = Localizer.t("help_text")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 15)
	scroll.add_child(text)

	col.add_child(_make_overlay_back_button())

# Gold painted back arrow. Keep the full rectangular hit target independent of the icon's
# visible alpha bounds; only the atlas region is cropped so the imported mipmaps stay intact.
func _make_back_button(button_size: Vector2 = Vector2(36.0, 36.0)) -> Button:
	var btn := Button.new()
	btn.name = "BackButton"
	btn.custom_minimum_size = button_size
	btn.size = button_size
	btn.tooltip_text = Localizer.t("back")
	btn.set_meta("label", Localizer.t("back"))
	btn.set_meta("source_path", BACK_ICON_ART)
	btn.pressed.connect(_on_back)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.name = "BackIcon"
	icon.texture = _cropped_back_icon()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3.0
	icon.offset_top = 2.0
	icon.offset_right = -3.0
	icon.offset_bottom = -2.0
	btn.add_child(icon)
	if icon.texture == null:
		btn.text = "‹"
		btn.add_theme_font_size_override("font_size", 28)
	btn.mouse_entered.connect(func(): icon.modulate = Color(1.14, 1.08, 0.90))
	btn.mouse_exited.connect(func(): icon.modulate = Color.WHITE)
	btn.button_down.connect(func():
		icon.position.y = 1.0
		icon.modulate = Color(0.78, 0.78, 0.78))
	btn.button_up.connect(func():
		icon.position.y = 0.0
		icon.modulate = Color(1.14, 1.08, 0.90) if btn.is_hovered() else Color.WHITE)
	return btn

func _cropped_back_icon() -> Texture2D:
	if _back_icon_texture_cache != null:
		return _back_icon_texture_cache
	var source := UiHelpers.hires_texture(BACK_ICON_ART)
	if source == null:
		return null
	var image := source.get_image()
	if image == null:
		return source
	if image.is_compressed():
		image.decompress()
	var threshold := 24
	var left := image.get_width()
	var top := image.get_height()
	var right := -1
	var bottom := -1
	for y in image.get_height():
		for x in image.get_width():
			if roundi(image.get_pixel(x, y).a * 255.0) <= threshold:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	if right < left or bottom < top:
		return source
	var crop := AtlasTexture.new()
	crop.atlas = source
	crop.region = Rect2(left, top, right - left + 1, bottom - top + 1)
	crop.filter_clip = true
	_back_icon_texture_cache = crop
	return _back_icon_texture_cache

func _on_play() -> void:
	call_deferred("_open_level_select")

func _open_level_select() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_continue() -> void:
	var ids: Array = LevelLoader.load_all_level_ids()
	if ids.is_empty():
		_on_play()
		return
	var next_level := Game.progress.get_unlocked_level()
	if next_level <= int(ids.back()):
		Game.start_level(next_level)
	elif Game.progress.is_endless_unlocked():
		Game.start_endless()
	else:
		Game.start_level(ids.back())

func _on_options() -> void:
	_screen = Screen.OPTIONS
	_build()

func _on_help() -> void:
	_screen = Screen.HELP
	_build()

func _on_quit() -> void:
	get_tree().quit()

func _on_back() -> void:
	_screen = Screen.MENU
	_reset_armed = false
	_build()

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
