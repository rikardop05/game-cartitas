extends SceneTree

const MAX_FRAMES := 120
const CONTROLLER_READY_FRAME := 20

var _frames := 0
var _started := false

func _process(_delta: float) -> bool:
	_frames += 1
	if not _started:
		_started = true
		var game = root.get_node_or_null("Game")
		if game == null:
			printerr("SMOKE FAIL: Game autoload not available")
			quit(1)
			return false
		game.current_level_id = "1"
		change_scene_to_file("res://scenes/level.tscn")
		return false
	if _frames >= MAX_FRAMES:
		printerr("SMOKE FAIL: did not reach SMOKE OK within %d frames" % MAX_FRAMES)
		quit(1)
		return false
	if _frames < CONTROLLER_READY_FRAME:
		return false
	var scene := current_scene
	if scene == null or scene.name != "LevelScreen":
		printerr("SMOKE FAIL: level scene did not load (current=%s)" % (str(scene.name) if scene != null else "null"))
		quit(1)
		return false
	if scene.get("controller") == null:
		printerr("SMOKE FAIL: LevelScreen controller was not created")
		quit(1)
		return false
	print("SMOKE OK")
	quit(0)
	return false
