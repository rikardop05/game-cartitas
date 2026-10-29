class_name UiHelpers
extends RefCounted

const WARM_BACKGROUND := Color("#c78454")
const BUTTON_BACKGROUND := Color(0.16, 0.10, 0.08, 0.78)
const BUTTON_BORDER := Color("#f3d28d")
const TEXT_PRIMARY := Color("#fff1d2")
const TEXT_MUTED := Color("#f0c98e")
const GOLD := Color("#ffe36e")

static var _font_cache: SystemFont = null
static var _card_texture_cache: Dictionary = {}

static func symbol_font() -> SystemFont:
	if _font_cache == null:
		_font_cache = SystemFont.new()
		_font_cache.font_names = PackedStringArray(["Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji", "Arial"])
	return _font_cache

# Card art standard: assets/cards/card_<type>.png, square, high resolution (>= 512 px, ideally
# a multiple of 64 such as 960, frame included). The UI is drawn at the PHYSICAL screen size
# (stretch mode canvas_items), so a 40 px logical card is 80+ real pixels; the art is kept at
# full resolution with mipmaps and drawn with trilinear filtering, letting the GPU scale it to
# whatever size the screen needs instead of pre-shrinking it to logical pixels (which blurred
# and pixelated it once the window upscaled the result). Mipmaps are built here, so any
# delivered PNG works without import tweaks. Cached per type.
static func card_texture(type: String) -> Texture2D:
	return hires_texture("res://assets/cards/card_%s.png" % type)

# Any painted (not pixel-art) picture at full resolution: loaded once, mipmaps generated, cached
# by path, null when the file is missing. Draw it with TEXTURE_FILTER_LINEAR_WITH_MIPMAPS.
static func hires_texture(path: String) -> Texture2D:
	if not _card_texture_cache.has(path):
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			var source := load(path) as Texture2D
			var image := source.get_image() if source != null else null
			if image != null:
				image = image.duplicate()
				if image.is_compressed():
					image.decompress()
				if not image.has_mipmaps():
					image.generate_mipmaps()
				texture = ImageTexture.create_from_image(image)
			else:
				texture = source
		_card_texture_cache[path] = texture
	return _card_texture_cache[path]

# HUD art (assets/ui/hud/<name>.png): the star plaque states and the stopwatch/gear icons.
static func hud_texture(name: String) -> Texture2D:
	return hires_texture(HUD_DIR + name + ".png")

# True when `type` has a painted card face (assets/cards/card_<type>.png); the others keep the
# emoji placeholder.
static func has_card_art(type: String) -> bool:
	return card_texture(type) != null

static func warm_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", TEXT_PRIMARY)
	# Labels may sit straight on the painted background (menu titles).
	t.set_color("font_outline_color", "Label", Color(0.14, 0.07, 0.03, 0.92))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = BUTTON_BACKGROUND
		style.border_color = BUTTON_BORDER
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.content_margin_left = 12
		style.content_margin_right = 12
		match state:
			"hover":
				style.bg_color = BUTTON_BACKGROUND.lightened(0.12)
			"pressed":
				style.bg_color = BUTTON_BACKGROUND.darkened(0.2)
			"disabled":
				style.bg_color.a = 0.4
				style.border_color.a = 0.35
			"focus":
				style.bg_color = Color(0, 0, 0, 0)
		t.set_stylebox(state, "Button", style)
	t.set_color("font_color", "Button", TEXT_PRIMARY)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", TEXT_MUTED)
	t.set_color("font_disabled_color", "Button", Color(TEXT_PRIMARY, 0.45))
	return t

# Full-screen painted background for the orientation, calmed by a filter shader so
# the cards and HUD stay readable. Falls back to the flat warm colour without art.
const KIT_DIR := "res://assets/ui/kit/"
const HUD_DIR := "res://assets/ui/hud/"
# Levels from this one on (and Endless) use the second background set.
const AUTUMN_FROM_LEVEL := 4

# A piece of the pixel-art UI kit (assets/ui/kit/<name>.png), or null if missing.
static func kit_texture(name: String) -> Texture2D:
	var path := KIT_DIR + name + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# 9-slice stylebox from a kit piece, for PanelContainers/buttons of any size. `margin` is
# the frame thickness in source pixels; content_margin pads the children inside it.
static func kit_stylebox(name: String, margin: int = 5, content_margin: int = 6) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = kit_texture(name)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style

# 9-slice rect from a kit piece, for decorative frames drawn at an exact size.
static func kit_panel(name: String, margin: int = 5) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.texture = kit_texture(name)
	panel.patch_margin_left = margin
	panel.patch_margin_top = margin
	panel.patch_margin_right = margin
	panel.patch_margin_bottom = margin
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

# Kit-plate style for list/option rows (9-sliced, so any width works) with hover/press tints.
static func apply_plate_style(btn: Button, tint := Color.WHITE) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := kit_stylebox("panel_reserve", 6, 8)
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		var shade := tint
		match state:
			"hover":
				shade = tint.lightened(0.15)
			"pressed":
				shade = tint.darkened(0.2)
			"disabled":
				shade = Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7, 0.8)
		style.modulate_color = shade
		btn.add_theme_stylebox_override(state, style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

# `level` picks the background set: 1-3 the meadow, AUTUMN_FROM_LEVEL+ (and Endless,
# passed as a large number) the autumn town; 0 (menus) uses the meadow.
static func background_path(landscape: bool, level: int = 0) -> String:
	if level >= AUTUMN_FROM_LEVEL and ResourceLoader.exists("res://assets/ui/background_autumn.png"):
		return "res://assets/ui/background_autumn.png"
	return "res://assets/ui/background.png" if landscape else "res://assets/ui/background_portrait.png"

static func make_background(landscape: bool, level: int = 0) -> Control:
	var path := background_path(landscape, level)
	if not ResourceLoader.exists(path):
		var flat := ColorRect.new()
		flat.color = WARM_BACKGROUND
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return flat
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = load(path) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Painted art, not pixel art: linear filtering keeps the blur smooth when scaled.
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/ui/background_filter.gdshader")
	bg.material = mat
	return bg

# Dark outline + drop shadow for text drawn straight over the painted background.
static func add_text_shadow(label: Label, outline := 4) -> void:
	label.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.03, 0.92))
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

static func total_stars_text() -> String:
	# Looked up at call time: naming the `Game` autoload here would stop this script compiling
	# in the headless test runner (autoloads are not registered while it loads suites).
	var game: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Game")
	return "★ %d/%d" % [game.progress.total_stars(), LevelLoader.load_all_level_ids().size() * 3]

static func symbol_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", symbol_font())
	return label
