class_name UiHelpers
extends RefCounted

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

static func symbol_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", symbol_font())
	return label
