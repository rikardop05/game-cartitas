extends Node

# Emitted whenever the player changes the sound volume/mute (Options slider, HUD button,
# set_sound). AudioManager listens to it instead of polling the mix every frame.
signal volume_changed(volume: float, enabled: bool)

var progress: ProgressManager
var settings: Dictionary = {"locale": "pt", "orientation": "portrait"}
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
	load_save()

func load_save() -> void:
	var data: Dictionary = SaveManager.load(save_path)
	if not data.is_empty():
		if data.has("progress"):
			progress.from_dict(data["progress"])
		var saved_settings: Dictionary = data.get("settings", {})
		settings = {"locale": "pt", "orientation": "portrait"}
		settings.merge(saved_settings, true)
		Localizer.current = str(settings.get("locale", "pt"))
	# Old profiles may still contain the removed Mascot On/Off preference.
	settings.erase("mascot")
	apply_orientation()

func apply_orientation() -> void:
	var landscape: bool = str(settings.get("orientation", "portrait")) == "landscape"
	var root := get_tree().root
	if landscape:
		root.content_scale_size = Vector2i(640, 360)
	else:
		root.content_scale_size = Vector2i(360, 640)
	# The handheld ProjectSettings value is only read at startup; on a device
	# the screen must be rotated through the DisplayServer.
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(
			DisplayServer.SCREEN_SENSOR_LANDSCAPE if landscape else DisplayServer.SCREEN_SENSOR_PORTRAIT)
		return
	# Keep the window's orientation ratio, but never request a desktop window taller or
	# wider than the usable monitor area. Window mode and mobile rotation belong to the OS.
	var window_mode := DisplayServer.window_get_mode()
	if window_mode in [
		DisplayServer.WINDOW_MODE_MAXIMIZED,
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]:
		return
	var window := get_window()
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var decorations := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	decorations = Vector2i(maxi(0, decorations.x), maxi(0, decorations.y))
	var client_area := Vector2i(
		maxi(1, usable.size.x - decorations.x),
		maxi(1, usable.size.y - decorations.y))
	var fitted := fit_window(client_area, landscape)
	window.size = fitted
	var decorated_size := fitted + decorations
	window.position = usable.position + Vector2i(
		floori(float(usable.size.x - decorated_size.x) * 0.5),
		floori(float(usable.size.y - decorated_size.y) * 0.5))

## Largest 9:16 or 16:9 client size that fits inside the supplied work-area bounds.
static func fit_window(usable: Vector2i, landscape: bool) -> Vector2i:
	var width := maxi(1, usable.x)
	var height := maxi(1, usable.y)
	if landscape:
		var width_from_height := floori(float(height) * 16.0 / 9.0)
		if width_from_height <= width:
			return Vector2i(maxi(1, width_from_height), height)
		return Vector2i(width, maxi(1, floori(float(width) * 9.0 / 16.0)))
	var width_from_height := floori(float(height) * 9.0 / 16.0)
	if width_from_height <= width:
		return Vector2i(maxi(1, width_from_height), height)
	return Vector2i(width, maxi(1, floori(float(width) * 16.0 / 9.0)))

func set_orientation(landscape: bool) -> void:
	settings["orientation"] = "landscape" if landscape else "portrait"
	save_progress()
	apply_orientation()

func mascot_enabled() -> bool:
	return true

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
	volume_changed.emit(volume(), sound_enabled())

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
