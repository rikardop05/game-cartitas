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

static func card_texture(type: String) -> Texture2D:
	if not _card_texture_cache.has(type):
		var path := "res://assets/cards/card_%s.png" % type
		if ResourceLoader.exists(path):
			_card_texture_cache[type] = load(path) as Texture2D
		else:
			_card_texture_cache[type] = null
	return _card_texture_cache[type]

static func warm_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", TEXT_PRIMARY)
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

static func total_stars_text() -> String:
	return "★ %d/%d" % [Game.progress.total_stars(), LevelLoader.load_all_level_ids().size() * 3]

static func symbol_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", symbol_font())
	return label
