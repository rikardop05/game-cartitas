class_name CardTypeRegistry
extends RefCounted

const TYPES := {
	"cat": {"symbol": "🐱", "color": "#c9564f"},
	"mouse": {"symbol": "🐭", "color": "#b8a46a"},
	"boar": {"symbol": "🐗", "color": "#b0713c"},
	"owl": {"symbol": "🦉", "color": "#7a6bc9"},
	"wolf": {"symbol": "🐺", "color": "#8fa3b8"},
	"duck": {"symbol": "🦆", "color": "#d9a441"},
	"frog": {"symbol": "🐸", "color": "#7fae4a"},
	"whale": {"symbol": "🐋", "color": "#4f7fc9"},
	"leaf": {"symbol": "🍀", "color": "#6bc98a"},
	"heart": {"symbol": "❤️", "color": "#e06a6a"},
	"gem": {"symbol": "💎", "color": "#6ac9d9"},
	"crystal": {"symbol": "🔮", "color": "#9a7ae0"},
	"cat_mage": {"symbol": "🧙", "color": "#b06ac9"},
	"rhino": {"symbol": "🦏", "color": "#9a8f7a"},
	"sacer": {"symbol": "🕯️", "color": "#e0d06a"},
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
