class_name Localizer
extends RefCounted

static var current: String = "pt"

const STRINGS := {
	"title": {"en": "Cartitas Infinity", "pt": "Cartitas Infinity"},
	"subtitle": {"en": "Match 3 identical cards", "pt": "Combine 3 cartas iguais"},
	"reset": {"en": "Reset progress", "pt": "Resetar progresso"},
	"locked": {"en": "locked", "pt": "bloqueado"},
	"level": {"en": "Level", "pt": "Level"},
	"clearing_zone": {"en": "Clearing Zone", "pt": "Clearing Zone"},
	"reserve": {"en": "Reserve", "pt": "Reserve"},
	"level_complete": {"en": "Level complete!", "pt": "Level completo!"},
	"no_moves": {"en": "No moves!", "pt": "Sem movimentos!"},
	"time": {"en": "Time", "pt": "Tempo"},
	"next_level": {"en": "Next level", "pt": "Próximo level"},
	"retry": {"en": "Try again", "pt": "Tentar de novo"},
	"menu": {"en": "Menu", "pt": "Menu"},
	"language": {"en": "Language: English", "pt": "Idioma: Português"},
}

static func t(key: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	if entry.has(current):
		return str(entry[current])
	return str(entry.get("pt", key))
