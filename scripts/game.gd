extends Node

var progress: ProgressManager
var settings: Dictionary = {"locale": "pt", "orientation": "portrait", "mascot": true}
var current_level_id: String = ""
# The active Endless run, or null during campaign play. The level scene reads it to
# decide between a campaign Level and an Endless round.
var endless_run: EndlessRun = null
# Where progress and settings are saved. Tests that drive the real scenes point this
# at a throwaway file so they never touch the player's save.
var save_path: String = SaveManager.DEFAULT_PATH

# One line picker for the whole session, so Ace's no-repeat memory survives scene
# reloads (every Endless round, retry, orientation rebuild and end panel).
var _mascot_lines: MascotLines

func _ready() -> void:
	progress = ProgressManager.new()
	var data: Dictionary = SaveManager.load(save_path)
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
	else:
		root.content_scale_size = Vector2i(360, 640)
		get_window().size = Vector2i(720, 1280)
	# The handheld ProjectSettings value is only read at startup; on a device
	# the screen must be rotated through the DisplayServer.
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(
			DisplayServer.SCREEN_SENSOR_LANDSCAPE if landscape else DisplayServer.SCREEN_SENSOR_PORTRAIT)

func set_orientation(landscape: bool) -> void:
	settings["orientation"] = "landscape" if landscape else "portrait"
	save_progress()
	apply_orientation()

func mascot_enabled() -> bool:
	return bool(settings.get("mascot", true))

func set_mascot(enabled: bool) -> void:
	settings["mascot"] = enabled
	save_progress()

# Sound effects volume, 0..1. Saves from before the slider only had settings["sound"].
func volume() -> float:
	var fallback := 1.0 if bool(settings.get("sound", true)) else 0.0
	return clampf(float(settings.get("volume", fallback)), 0.0, 1.0)

# `persist` is false while a slider is being dragged, so only the release writes the save.
func set_volume(value: float, persist: bool = true) -> void:
	value = clampf(value, 0.0, 1.0)
	settings["volume"] = value
	settings["sound"] = value > 0.0
	if value > 0.0:
		settings["last_volume"] = value
	if persist:
		save_progress()

func sound_enabled() -> bool:
	return volume() > 0.0

# Mute keeps the last volume, so unmuting brings the slider back where it was.
func set_sound(enabled: bool) -> void:
	set_volume(float(settings.get("last_volume", 1.0)) if enabled else 0.0)

func mascot_lines() -> MascotLines:
	if _mascot_lines == null:
		_mascot_lines = MascotLines.new()
	return _mascot_lines

func save_progress() -> void:
	SaveManager.save({"progress": progress.to_dict(), "settings": settings}, save_path)

func set_locale(locale: String) -> void:
	settings["locale"] = locale
	Localizer.current = locale
	save_progress()

func start_level(level_id) -> void:
	endless_run = null
	current_level_id = str(level_id)
	get_tree().change_scene_to_file("res://scenes/level.tscn")

func start_endless() -> void:
	endless_run = EndlessRun.new()
	get_tree().change_scene_to_file("res://scenes/level.tscn")

func restart_level() -> void:
	get_tree().reload_current_scene()

func go_to_menu() -> void:
	endless_run = null
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func complete_level(stars: int, rewards: Array) -> Array:
	var granted := progress.record_victory(current_level_id, stars, rewards)
	save_progress()
	return granted
