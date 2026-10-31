extends SceneTree

# Hero mascot smoke: phase portraits, L8 bunny expression frames and neutral intro.
# Drives the real level scene (autoloads available), using a throwaway save.

const THROWAWAY_SAVE := "user://smoke_mascot_heroes_save.json"
const CASES := [
	{"level": "1", "hero": "cat", "bunny": false},
	{"level": "6", "hero": "frog", "bunny": false},
	{"level": "8", "hero": "bunny", "bunny": true},
	{"level": "9", "hero": "wolf_knight", "bunny": false},
	{"level": "10", "hero": "menu_wolf", "bunny": false},
	{"level": "11", "hero": "menu_wolf", "bunny": false},
]

var _failures: Array[String] = []
var _game

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_game = root.get_node_or_null("Game")
	if _game == null:
		_fail("Game autoload missing")
		_finish()
		return
	_game.save_path = THROWAWAY_SAVE
	_game.settings["mascot"] = true
	_game.settings["orientation"] = "portrait"
	_game.apply_orientation()
	for case in CASES:
		await _check_case(case)
	await _check_intro_line()
	_finish()

# The delayed intro line must come from the neutral hero_intro_* keys, not an NPC family.
func _check_intro_line() -> void:
	_game.endless_run = null
	_game.current_level_id = "1"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene == null:
		_fail("intro: no LevelScreen")
		return
	await create_timer(5.6).timeout
	var mascot = scene.get("mascot")
	if mascot == null:
		_fail("intro: no mascot")
		return
	var bubble = mascot.find_child("Bubble", true, false)
	var label: Label = null
	if bubble != null:
		label = bubble.get_child(0) as Label
	var text: String = label.text if label != null else ""
	var allowed := [Localizer.t("hero_intro_1"), Localizer.t("hero_intro_2"), Localizer.t("hero_intro_3")]
	_check(allowed.has(text), "intro bubble uses hero_intro_* (got '%s')" % text)

func _check_case(case: Dictionary) -> void:
	_game.endless_run = null
	_game.current_level_id = str(case["level"])
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene == null:
		_fail("L%s: no LevelScreen" % case["level"])
		return
	var mascot = scene.get("mascot")
	if mascot == null:
		_fail("L%s: no mascot" % case["level"])
		return
	var tag := "L%s" % case["level"]
	_check(mascot.character == case["hero"], "%s: hero %s (got %s)" % [tag, case["hero"], mascot.character])
	if case["bunny"]:
		_check(mascot.frame_id == "hero_bunny_thinking", "%s: idle is thinking (got %s)" % [tag, mascot.frame_id])
		mascot.set_mood(1)
		_check(mascot.frame_id == "hero_bunny_sequence", "%s: happy is sequence (got %s)" % [tag, mascot.frame_id])
		mascot.set_mood(2)
		_check(mascot.frame_id == "hero_bunny_bad_choice", "%s: worried is bad choice (got %s)" % [tag, mascot.frame_id])
		mascot.set_mood(3)
		_check(mascot.frame_id == "hero_bunny_defeat", "%s: sad is defeat (got %s)" % [tag, mascot.frame_id])
		mascot.set_mood(0)
		_check(mascot.frame_id == "hero_bunny_thinking", "%s: idle returns to thinking (got %s)" % [tag, mascot.frame_id])
		# The gameplay events must select the same frames.
		mascot.say("match")
		_check(mascot.frame_id == "hero_bunny_sequence", "%s: match -> happy frame (got %s)" % [tag, mascot.frame_id])
		mascot.say("zone_warning")
		_check(mascot.frame_id == "hero_bunny_bad_choice", "%s: warning -> worried frame (got %s)" % [tag, mascot.frame_id])
		mascot.say("power_used")
		_check(mascot.frame_id == "hero_bunny_sequence", "%s: power -> happy frame (got %s)" % [tag, mascot.frame_id])
		mascot.say("lose")
		_check(mascot.frame_id == "hero_bunny_defeat", "%s: lose -> sad frame (got %s)" % [tag, mascot.frame_id])
		mascot.say("win", {"stars": 3})
		_check(mascot.frame_id == "hero_bunny_sequence", "%s: win -> happy frame (got %s)" % [tag, mascot.frame_id])
		mascot.set_mood(0)
	else:
		var expected := "hero_%s" % case["hero"]
		_check(mascot.frame_id == expected, "%s: portrait %s (got %s)" % [tag, expected, mascot.frame_id])
		mascot.set_mood(1)
		_check(mascot.frame_id == expected, "%s: a common hero keeps its portrait on mood changes (got %s)" % [tag, mascot.frame_id])
		mascot.set_mood(0)
	# The hero is intentionally larger than its placement box and overlaps the frame.
	_check(mascot.size.x > 100.0 and mascot.size.y > 150.0,
		"%s: mascot is the large hero (%s)" % [tag, str(mascot.size)])
	var line: String = mascot.localized_line("intro")
	_check(line != "" and not line.contains("Ace") and not line.contains("Bruno") and not line.contains("Marlow") and not line.contains("Mallard"),
		"%s: intro line is neutral (got '%s')" % [tag, line])

func _wait_level():
	for i in 120:
		await process_frame
		var scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null and scene.get("mascot") != null:
			return scene
	return null

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("SMOKE MASCOT HEROES OK")
		quit(0)
	else:
		for message in _failures:
			printerr("SMOKE MASCOT HEROES FAIL: %s" % message)
		quit(1)
