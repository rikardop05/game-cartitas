extends SceneTree

# QA capture for the painted HUD 9-slices (zone bar, reserve, powers, board frame) at 2x,
# portrait 720x1280 and landscape 1280x720. Writes user://qa_shots/panels_*.png.
const OUT_DIR := "user://qa_shots"
const CASES := [
	{"tag": "panels_portrait", "level": "6", "orientation": "portrait", "window": Vector2i(720, 1280)},
	{"tag": "panels_landscape", "level": "6", "orientation": "landscape", "window": Vector2i(1280, 720)},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var game = root.get_node_or_null("Game")
	game.save_path = "user://qa_panels_save.json"
	for case in CASES:
		game.endless_run = null
		game.current_level_id = str(case["level"])
		game.settings["orientation"] = str(case["orientation"])
		game.settings["mascot"] = true
		game.apply_orientation()
		root.size = case["window"]
		change_scene_to_file("res://scenes/level.tscn")
		for i in 90:
			await process_frame
		var deadline := Time.get_ticks_msec() + 1500
		while Time.get_ticks_msec() < deadline:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, case["tag"]])
		print("QA PANELS SHOT ", case["tag"])
	quit(0)
