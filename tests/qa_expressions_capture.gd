extends SceneTree

# QA capture for the per-hero expression sets: one level per hero that has a set, the four
# moods (0 thinking, 1 sequence, 2 bad_choice, 3 defeat), portrait and landscape at 2x.
# Saves the full screen and a crop around the mascot to user://qa_shots/expressions.

const OUT_DIR := "user://qa_shots/expressions"
const PORTRAIT_SIZE := Vector2i(720, 1280)   # 2x of the 360x640 design viewport
const LANDSCAPE_SIZE := Vector2i(1280, 720)  # 2x of the 640x360 design viewport
const MOODS := [0, 1, 2, 3]
const MOOD_NAMES := ["thinking", "sequence", "bad_choice", "defeat"]
# One playable level per hero with a delivered set (L15 repeats wolf_knight, so it is skipped).
const HERO_LEVELS := [
	{"level": "1", "hero": "cat"},
	{"level": "2", "hero": "wolf_ranger"},
	{"level": "3", "hero": "boar"},
	{"level": "4", "hero": "mouse"},
	{"level": "5", "hero": "owl"},
	{"level": "6", "hero": "frog"},
	{"level": "7", "hero": "knight"},
	{"level": "8", "hero": "bunny"},
	{"level": "9", "hero": "wolf_knight"},
	{"level": "12", "hero": "cat_mage"},
	{"level": "13", "hero": "rhino"},
	{"level": "14", "hero": "sacer"},
]

var _game
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	if _game == null:
		printerr("QA EXPRESSIONS FAIL: Game autoload missing")
		quit(1)
		return
	_game.save_path = "user://qa_expressions_save.json"
	_game.settings["mascot"] = true
	for orientation in [["portrait", PORTRAIT_SIZE], ["landscape", LANDSCAPE_SIZE]]:
		_game.settings["orientation"] = orientation[0]
		_game.apply_orientation()
		root.size = orientation[1]
		for entry in HERO_LEVELS:
			await _capture_hero(entry["level"], entry["hero"], orientation[0])
	print("QA EXPRESSIONS DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		printerr("QA EXPRESSIONS FAIL: " + failure)
	quit(1)

func _capture_hero(level_id: String, hero: String, orientation: String) -> void:
	_game.endless_run = null
	_game.current_level_id = level_id
	change_scene_to_file("res://scenes/level.tscn")
	var scene = null
	for i in 180:
		await process_frame
		scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null and scene.get("mascot") != null:
			break
	if scene == null:
		_failures.append("%s %s: level did not load" % [hero, orientation])
		return
	var mascot = scene.get("mascot")
	if mascot == null:
		_failures.append("%s %s: no mascot" % [hero, orientation])
		return
	if mascot.character != hero:
		_failures.append("%s %s: wrong hero %s" % [hero, orientation, mascot.character])
		return
	# Let the level title overlay finish (0.9 s) and dismiss the instruction bubble, but
	# capture before the delayed intro line (~5 s) changes the mood again.
	await create_timer(1.2).timeout
	mascot.hide_bubble()
	await create_timer(0.25).timeout
	for mood in MOODS:
		mascot.set_mood(mood, 0.0)
		await _frames(2)
		var tag := "%s_L%s_%s_%s" % [hero, level_id, orientation, MOOD_NAMES[mood]]
		print("QA EXPRESSIONS %s frame=%s" % [tag, str(mascot.frame_id)])
		await _shot(tag, mascot)
	# One bubble shot per orientation (the layout must keep it above the cards in portrait).
	if hero == "cat":
		mascot.set_mood(0)
		mascot.say_text(Localizer.t("instruction"), 2.0, "instruction")
		await _frames(6)
		await _shot("%s_L%s_%s_bubble" % [hero, level_id, orientation], mascot)

func _shot(tag: String, mascot: Control) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, tag]
	var err := image.save_png(path)
	if err != OK:
		_failures.append("could not save %s (err %d)" % [path, err])
		return
	# Crop around the mascot: global rects are logical; the capture is at the 2x window size.
	var viewport_size := root.get_visible_rect().size
	var scale := float(image.get_width()) / maxf(1.0, viewport_size.x)
	var rect := mascot.get_global_rect().grow(70.0)
	var crop := Rect2i(
		Vector2i(floori(rect.position.x * scale), floori(rect.position.y * scale)),
		Vector2i(ceili(rect.size.x * scale), ceili(rect.size.y * scale)))
	crop = crop.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if crop.size.x > 0 and crop.size.y > 0:
		image.get_region(crop).save_png("%s/%s_crop.png" % [OUT_DIR, tag])
