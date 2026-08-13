class_name CardTypeRegistry
extends RefCounted

const TYPES := {
	"cat": {"symbol": "🐱", "color": "#e07a7a"},
	"dog": {"symbol": "🐶", "color": "#d9a05b"},
	"bird": {"symbol": "🐦", "color": "#e0c95b"},
	"fish": {"symbol": "🐟", "color": "#6bb5e0"},
	"flower": {"symbol": "🌸", "color": "#e08ac9"},
	"moon": {"symbol": "🌙", "color": "#c9b8e0"},
	"star": {"symbol": "⭐", "color": "#f0e060"},
	"sun": {"symbol": "☀️", "color": "#f0b060"},
	"leaf": {"symbol": "🍀", "color": "#6bc98a"},
	"heart": {"symbol": "❤️", "color": "#e06a6a"},
	"gem": {"symbol": "💎", "color": "#6ac9d9"},
	"crystal": {"symbol": "🔮", "color": "#9a7ae0"},
}

static func all_types() -> Array:
	return TYPES.keys()

static func has_type(type: String) -> bool:
	return TYPES.has(type)

static func symbol(type: String) -> String:
	return str(TYPES.get(type, {}).get("symbol", "❔"))

static func color(type: String) -> Color:
	var hex: String = str(TYPES.get(type, {}).get("color", "#888888"))
	return Color.html(hex)
