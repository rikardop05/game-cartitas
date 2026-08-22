extends Node

var progress: ProgressManager
var settings: Dictionary = {"locale": "pt", "orientation": "portrait"}
var current_level_id: String = ""

func _ready() -> void:
	progress = ProgressManager.new()
	var data: Dictionary = SaveManager.load()
	if not data.is_empty():
		if data.has("progress"):
			progress.from_dict(data["progress"])
		var saved_settings: Dictionary = data.get("settings", {})
		settings = {"locale": "pt", "orientation": "portrait"}
		settings.merge(saved_settings, true)
		Localizer.current = str(settings.get("locale", "pt"))
	apply_orientation()

func apply_orientation() -> void:
	var landscape: bool = str(settings.get("orientation", "portrait")) == "landscape"
	var root := get_tree().root
	if landscape:
		root.content_scale_size = Vector2i(640, 360)
		get_window().size = Vector2i(1280, 720)
		ProjectSettings.set_setting("display/window/handheld/orientation", 4)
	else:
		root.content_scale_size = Vector2i(360, 640)
		get_window().size = Vector2i(720, 1280)
		ProjectSettings.set_setting("display/window/handheld/orientation", 5)

func set_orientation(landscape: bool) -> void:
	settings["orientation"] = "landscape" if landscape else "portrait"
	save_progress()
	apply_orientation()

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
