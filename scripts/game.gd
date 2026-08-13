extends Node

var progress: ProgressManager
var settings: Dictionary = {"locale": "pt"}
var current_level_id: String = ""

func _ready() -> void:
	progress = ProgressManager.new()
	var data: Dictionary = SaveManager.load()
	if not data.is_empty():
		if data.has("progress"):
			progress.from_dict(data["progress"])
		settings = data.get("settings", {"locale": "pt"})
		Localizer.current = str(settings.get("locale", "pt"))

func save_progress() -> void:
	SaveManager.save({"progress": progress.to_dict(), "settings": settings})

func set_locale(locale: String) -> void:
	settings["locale"] = locale
	Localizer.current = locale
	save_progress()

func start_level(level_id) -> void:
	current_level_id = str(level_id)
	get_tree().change_scene_to_file("res://scenes/level.tscn")

func restart_level() -> void:
	get_tree().reload_current_scene()

func go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func complete_level(stars: int, rewards: Array) -> void:
	progress.record_victory(current_level_id, stars, rewards)
	save_progress()
