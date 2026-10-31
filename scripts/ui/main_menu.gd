extends Control

enum Screen { MENU, LEVELS, OPTIONS }

# Same warm palette as the level screen, so menu and game read as one product.
const WARM_BACKGROUND := UiHelpers.WARM_BACKGROUND
const TEXT_MUTED := UiHelpers.TEXT_MUTED
const GOLD := UiHelpers.GOLD

# The kit panel and its buttons are drawn at exactly 2x their 64x32 source size.
const MENU_PANEL_SIZE := Vector2(128, 192)
const MENU_BUTTON_SIZE := Vector2(128, 64)

# Portrait stacks logo, plaque and stars with fixed gaps; landscape pins the logo/stars
# to the top-left and the plaque to the right.
const MENU_GAP_LOGO := 10.0
const MENU_GAP_STARS := 6.0
const MENU_EDGE := 14.0
const STARS_BAND := 22.0
const LANDSCAPE_MARGIN := 10.0

# Painted hanging sign that carries the menu. The rectangle below is its inner plank (fractions
# of the 1049x1499 art), so the buttons land on wood and never over the leaves or the lantern.
const MENU_BOARD_ART := "res://assets/ui/kit/panel_menu_board.png"
const MENU_BOARD_PLANK := Rect2(0.185, 0.209, 0.588, 0.538)
const MENU_BOARD_ASPECT := 1049.0 / 1499.0
const MENU_BOARD_ART_TOP := 72.0 / 1499.0
const MENU_BOARD_ART_BOTTOM := 1328.0 / 1499.0
const MENU_BOARD_ART_LEFT := 12.0 / 1049.0
const MENU_BOARD_ART_RIGHT := 1040.0 / 1049.0
const MENU_BOARD_SHADOW_OFFSET := Vector2(0, 12)
const MENU_BOARD_SHADOW_SCALE := 1.015

# Branding and the decorative hero behind the sign.
const LOGO_ART := "res://assets/ui/branding/logo_claw_and_crown.png"
const HERO_ART := "res://assets/ui/heroes/hero_menu_wolf.png"
const LOGO_HEIGHT_LANDSCAPE := 60.0
const LOGO_HEIGHT_PORTRAIT := 78.0
const HERO_SHADER := """
shader_type canvas_item;
uniform float edge = 0.10;
uniform float opacity = 0.92;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = min(UV, vec2(1.0) - UV);
	float fade = smoothstep(0.0, edge, min(d.x, d.y));
	COLOR = vec4(c.rgb, c.a * fade * opacity);
}
"""

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
var _board: TextureRect
var _board_shadow: TextureRect
var _content: Control
var _logo: Control
var _panel: Control
var _stars: Label
var _menu_buttons: Array[Button] = []
var _content_base := Vector2.ZERO
var _pointer := Vector2.ZERO
var _pointer_goal := Vector2.ZERO
var _manual_pointer := false
var _clock := 0.0

func _ready() -> void:
	theme = UiHelpers.warm_theme()
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
	_board = null
	_board_shadow = null
	_content = null
	_logo = null
	_panel = null
	_stars = null
	_menu_buttons.clear()
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
			Screen.LEVELS:
				_build_levels()
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
	var background := UiHelpers.make_background(landscape)
	# Keep the delivered city crisp; the plaque/logo already provide the focus.
	background.modulate = Color(0.96, 0.96, 0.96)
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
	_layout_after_frame()

func _make_menu_panel() -> Control:
	var panel := Control.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size = MENU_PANEL_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var buttons := VBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 0)
	panel.add_child(buttons)
	_menu_buttons.clear()
	_menu_buttons.append(_make_menu_button("PlayButton", "play", "btn_menu_jogar", _on_play))
	_menu_buttons.append(_make_menu_button("OptionsButton", "options", "btn_menu_opcoes", _on_options))
	_menu_buttons.append(_make_menu_button("QuitButton", "quit", "btn_menu_sair", _on_quit))
	for btn in _menu_buttons:
		buttons.add_child(btn)
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

func _make_menu_board() -> void:
	_make_hero()
	var texture := UiHelpers.hires_texture(MENU_BOARD_ART)
	_board_shadow = _make_shadow_rect(texture, 16.0, 0.6)
	_board_shadow.name = "BoardShadow"
	_board_shadow.scale = Vector2(MENU_BOARD_SHADOW_SCALE, MENU_BOARD_SHADOW_SCALE)
	_board_layer.add_child(_board_shadow)

	_board = _make_texture_rect(texture)
	_board.name = "Board"
	_board_layer.add_child(_board)

# Decorative wolf knight in the board parallax layer, mouse-ignore. Landscape keeps
# it behind the sign on the right. Portrait moves it to the lower right and draws it
# in front of the sign (z=1, content stays z=2) so the whole body is visible beside
# the plaque instead of only the boots below it.
func _make_hero() -> void:
	var texture := UiHelpers.hires_texture(HERO_ART)
	if texture == null:
		return
	var view := get_viewport_rect().size
	var landscape := _landscape()
	var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
	var height := view.y * (0.90 if landscape else 0.26)
	var width := height * aspect
	if width > view.x * 0.42:
		width = view.x * 0.42
		height = width / aspect
	# Landscape: hero on the left/centre, plaque on the right. Portrait: lower right,
	# peeking over the plaque's lower lip without covering the buttons.
	var position := Vector2(36.0, view.y - height - 8.0)
	if not landscape:
		position = Vector2(view.x - width - 2.0, view.y - height - 18.0)
	_hero = _make_texture_rect(texture)
	_hero.name = "MenuHero"
	_hero.stretch_mode = TextureRect.STRETCH_SCALE
	_hero.size = Vector2(width, height)
	_hero.position = position
	_hero.z_index = 0 if landscape else 1
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = HERO_SHADER
	material.shader = shader
	_hero.material = material
	_board_layer.add_child(_hero)

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

# Lays out the whole menu in view coordinates: first the plaque is fitted around the
# button column, then the panel is pinned to the plank's centre, the logo sits above the
# plaque (portrait) or in the top-left corner (landscape), and the stars go under the
# plaque/logo. Running from untransformed space keeps it stable under parallax.
func _layout_board() -> void:
	if not is_instance_valid(_board) or not is_instance_valid(_board_shadow):
		return
	if _menu_buttons.is_empty() or not is_instance_valid(_menu_buttons[0]):
		return
	if not is_instance_valid(_panel) or not is_instance_valid(_logo) or not is_instance_valid(_stars):
		return
	var view := get_viewport_rect().size
	var landscape := _landscape()
	var button_size := Vector2(
		maxf(_menu_buttons[0].size.x, MENU_BUTTON_SIZE.x),
		maxf(_menu_buttons[0].size.y, MENU_BUTTON_SIZE.y) * _menu_buttons.size())
	var pad := Vector2(30, 42) if landscape else Vector2(28, 44)
	var wanted := button_size + pad * 2.0
	var height := maxf(wanted.y / MENU_BOARD_PLANK.size.y, wanted.x / MENU_BOARD_PLANK.size.x)
	height = minf(height, view.x * 0.90 / MENU_BOARD_ASPECT)
	var visible_fraction := MENU_BOARD_ART_BOTTOM - MENU_BOARD_ART_TOP
	var logo_size: Vector2 = _logo.custom_minimum_size
	if landscape:
		height = minf(height, (view.y - 8.0) / visible_fraction)
	else:
		# Leave room for the logo above and the stars below: the plaque may never cover them.
		var reserved := logo_size.y + MENU_GAP_LOGO + MENU_GAP_STARS + STARS_BAND + MENU_EDGE * 2.0
		height = minf(height, maxf(180.0, (view.y - reserved) / visible_fraction))
	var board_size := Vector2(height * MENU_BOARD_ASPECT, height)
	var visible_height := visible_fraction * height
	var origin := Vector2.ZERO
	var logo_pos := Vector2.ZERO
	var stars_pos := Vector2.ZERO
	if landscape:
		origin.x = view.x - board_size.x - LANDSCAPE_MARGIN
		origin.y = (view.y - board_size.y) * 0.5
		logo_pos = Vector2(20.0, 14.0)
		stars_pos = Vector2(20.0, logo_pos.y + logo_size.y + 4.0)
	else:
		var total := logo_size.y + MENU_GAP_LOGO + visible_height + MENU_GAP_STARS + STARS_BAND
		var top := maxf(MENU_EDGE, (view.y - total) * 0.5)
		origin.x = (view.x - board_size.x) * 0.5
		origin.y = top + logo_size.y + MENU_GAP_LOGO - MENU_BOARD_ART_TOP * height
		logo_pos = Vector2((view.x - logo_size.x) * 0.5, top)
		stars_pos = Vector2(0.0, top + logo_size.y + MENU_GAP_LOGO + visible_height + MENU_GAP_STARS)
	origin.x = _clamp_inside(origin.x, view.x, MENU_BOARD_ART_LEFT, MENU_BOARD_ART_RIGHT, board_size.x)
	origin.y = _clamp_inside(origin.y, view.y, MENU_BOARD_ART_TOP, MENU_BOARD_ART_BOTTOM, board_size.y)
	# Both the sign and its shadow live in the parallax layer; subtract the layer's
	# current offset so the origin stays expressed in the untransformed layout space.
	var layer_offset := _board_layer.position
	_board.size = board_size
	_board.position = origin - layer_offset
	_board.pivot_offset = board_size * 0.5
	_board_shadow.size = board_size
	_board_shadow.position = origin + MENU_BOARD_SHADOW_OFFSET - layer_offset
	_board_shadow.pivot_offset = board_size * 0.5
	# The button column is pinned to the painted plank, not to the whole art.
	var plank_center := (MENU_BOARD_PLANK.position + MENU_BOARD_PLANK.size * 0.5) * board_size
	_panel.size = MENU_PANEL_SIZE
	_panel.position = origin + plank_center - MENU_PANEL_SIZE * 0.5
	_logo.size = logo_size
	_logo.position = logo_pos
	_stars.size = Vector2(view.x, STARS_BAND)
	_stars.position = stars_pos
	if landscape:
		_stars.size.x = 240.0

func _clamp_inside(origin: float, extent: float, art_from: float, art_to: float, board_extent: float) -> float:
	var low := 6.0 - art_from * board_extent
	var high := extent - 6.0 - art_to * board_extent
	if low > high:
		return (extent - (art_to - art_from) * board_extent) * 0.5 - art_from * board_extent
	return clampf(origin, low, high)

# A kit button drawn at 2x. Both locales use the baked Portuguese artwork for now (the
# delivered look), so the face is always the 64x32 PNG scaled 1:1 with nearest filtering;
# the localized label stays available through the tooltip and the accessibility name.
func _make_menu_button(node_name: String, key: String, art_name: String, callback: Callable) -> Button:
	var texture: Texture2D = UiHelpers.kit_texture("pill")
	var path := "res://assets/ui/branding/%s.png" % art_name
	if ResourceLoader.exists(path):
		var loaded := load(path) as Texture2D
		if loaded != null:
			texture = loaded
	var btn := _make_face_button(texture, MENU_BUTTON_SIZE)
	btn.name = node_name
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
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_top = 5
	shadow.offset_bottom = 5
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(shadow)
	var face := TextureRect.new()
	face.name = "Face"
	face.texture = texture
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	# The menu buttons are pixel art drawn at exactly 2x; nearest keeps them crisp.
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

# Kit-plate style for list/option rows (9-sliced, so any width works) with hover/press tints.
func _apply_plate_style(btn: Button, tint := Color.WHITE) -> void:
	UiHelpers.apply_plate_style(btn, tint)

# The brown kit window the list and the options sit on.
func _make_window() -> PanelContainer:
	var window := PanelContainer.new()
	window.name = "Window"
	var style := UiHelpers.kit_stylebox("panel_board" if _landscape() else "panel_board_portrait", 6, 12)
	# The kit window has a thicker lower lip (shadow and feet).
	style.texture_margin_bottom = 10
	style.content_margin_bottom = 14
	window.add_theme_stylebox_override("panel", style)
	return window

func _make_margin(parent: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	parent.add_child(margin)
	return margin

func _make_header(text: String) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.add_child(_make_back_button())
	var heading := Label.new()
	heading.text = text
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	header.add_child(heading)
	return header

func _build_levels() -> void:
	var margin := _make_margin(self)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	col.add_child(_make_header(Localizer.t("select_level")))

	var window := _make_window()
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(window)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var ids: Array = LevelLoader.load_all_level_ids()
	var total_stars := UiHelpers.symbol_label(UiHelpers.total_stars_text(), 18)
	total_stars.name = "TotalStars"
	total_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_stars.add_theme_color_override("font_color", GOLD)
	vbox.add_child(total_stars)

	vbox.add_child(_make_endless_button())
	for id in ids:
		vbox.add_child(_make_level_button(str(id)))

func _build_options() -> void:
	var landscape := _landscape()
	var margin := _make_margin(self)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	col.add_child(_make_header(Localizer.t("options")))

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)

	var window := _make_window()
	window.custom_minimum_size = Vector2(320, 0)
	center.add_child(window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6 if landscape else 10)
	window.add_child(vbox)

	var row_height := 42 if landscape else 46
	vbox.add_child(_make_option_row("LanguageButton", Localizer.t("language"), Localizer.t("language"), _on_toggle_language, row_height))
	vbox.add_child(_make_option_row("OrientationButton", _orientation_label(), Localizer.t("orientation_label"), _on_toggle_orientation, row_height))
	vbox.add_child(_make_option_row("MascotButton", _mascot_label(), Localizer.t("mascot_label"), _on_toggle_mascot, row_height))
	vbox.add_child(VolumeRow.new(row_height))

	if _reset_armed:
		vbox.add_child(_make_reset_confirm(row_height))
	else:
		vbox.add_child(_make_option_row("ResetButton", Localizer.t("reset"), Localizer.t("reset"), _on_reset, row_height))

func _make_option_row(node_name: String, text: String, tooltip: String, callback: Callable, height: int) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = text
	btn.custom_minimum_size = Vector2(280, height)
	btn.tooltip_text = tooltip
	btn.pressed.connect(callback)
	_apply_plate_style(btn)
	return btn

# Second step of "Reset progress": the warning, a green check to erase and a red cross to keep.
func _make_reset_confirm(height: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ResetConfirmRow"
	row.add_theme_constant_override("separation", 6)
	var warning := Label.new()
	warning.name = "ResetWarning"
	warning.text = Localizer.t("reset_confirm")
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(170, 0)
	warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 13)
	row.add_child(warning)
	row.add_child(_make_icon_button("ResetConfirm", "icon_accept", Localizer.t("confirm"), _on_reset, height))
	row.add_child(_make_icon_button("ResetCancel", "icon_close_red", Localizer.t("cancel"), _on_reset_cancel, height))
	return row

func _make_icon_button(node_name: String, icon_name: String, tooltip: String, callback: Callable, size: int) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.icon = UiHelpers.kit_texture(icon_name)
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 24)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size = Vector2(size + 8, size)
	btn.tooltip_text = tooltip
	btn.pressed.connect(callback)
	_apply_plate_style(btn)
	return btn

# Flat button with a green chevron (dark outline), matching the level screen's back button.
func _make_back_button() -> Button:
	var btn := Button.new()
	btn.name = "BackButton"
	btn.custom_minimum_size = Vector2(36, 36)
	btn.tooltip_text = Localizer.t("back")
	btn.pressed.connect(_on_back)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	btn.draw.connect(func():
		var c := btn.size * 0.5 + (Vector2(0, 1) if btn.is_pressed() else Vector2.ZERO)
		var pts := PackedVector2Array([c + Vector2(5, -10), c + Vector2(-5, 0), c + Vector2(5, 10)])
		var outline := Color("#2a1a0e")
		var green := Color("#8be04e") if btn.is_hovered() else Color("#6fcf3a")
		btn.draw_polyline(pts, outline, 8.0)
		for p in pts:
			btn.draw_circle(p, 4.0, outline)
		btn.draw_polyline(pts, green, 4.0)
		for p in pts:
			btn.draw_circle(p, 2.0, green))
	btn.mouse_entered.connect(btn.queue_redraw)
	btn.mouse_exited.connect(btn.queue_redraw)
	btn.button_down.connect(btn.queue_redraw)
	btn.button_up.connect(btn.queue_redraw)
	return btn

func _make_level_button(id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(240, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_override("font", UiHelpers.symbol_font())
	if Game.progress.is_level_unlocked(id):
		var stars: int = Game.progress.get_stars(id)
		var star_str := ""
		for i in 3:
			star_str += "★" if i < stars else "☆"
		btn.text = "%s %s   %s" % [Localizer.t("level"), id, star_str]
		btn.tooltip_text = "%s %s" % [Localizer.t("level"), id]
		btn.pressed.connect(_on_level.bind(id))
	else:
		btn.text = "%s %s   (%s)" % [Localizer.t("level"), id, Localizer.t("locked")]
		btn.disabled = true
	_apply_plate_style(btn)
	return btn

# Endless entry, styled like a level button: best score once the last Level is beaten.
func _make_endless_button() -> Button:
	var btn := Button.new()
	btn.name = "EndlessButton"
	btn.custom_minimum_size = Vector2(240, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_override("font", UiHelpers.symbol_font())
	var tint := Color.WHITE
	if Game.progress.is_endless_unlocked():
		btn.text = Localizer.t("endless")
		if Game.progress.endless_best > 0:
			btn.text += "   ★ %s" % (Localizer.t("endless_best") % Game.progress.endless_best)
		btn.add_theme_color_override("font_color", GOLD)
		btn.tooltip_text = Localizer.t("endless_tip")
		btn.pressed.connect(_on_endless)
		tint = Color(1.12, 1.0, 0.72)
	else:
		btn.text = "%s   %s" % [Localizer.t("endless"), Localizer.t("endless_locked") % ProgressManager.endless_unlock_level()]
		btn.disabled = true
	_apply_plate_style(btn, tint)
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
	_reset_armed = false
	_build()

func _on_level(level_id: String) -> void:
	Game.start_level(level_id)

func _on_endless() -> void:
	Game.start_endless()

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
