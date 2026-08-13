extends SceneTree

var _frames := 0

func _init() -> void:
	var game = root.get_node_or_null("Game")
	if game:
		game.current_level_id = "1"

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		change_scene_to_file("res://scenes/level.tscn")
	if _frames >= 4:
		print("SMOKE OK")
		quit(0)
	return false
