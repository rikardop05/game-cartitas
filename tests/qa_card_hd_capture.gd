extends SceneTree

# Windowed/GPU capture for the enlarged Clearing Zone cards and the HD painted panels.
# Writes user://qa_shots/card_hd_*.png for L1/L8/L15 in both orientations.

const OUT_DIR := "user://qa_shots"
const LEVELS := ["1", "8", "15"]
const VIEWS := [
	{"tag": "portrait", "orientation": "portrait", "window": Vector2i(360, 640)},
	{"tag": "landscape", "orientation": "landscape", "window": Vector2i(640, 360)},
]

var _game
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _seconds(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := image.save_png(path)
	if err != OK:
		_failures.append("could not save %s (err %d)" % [path, err])
	print("QA CARD HD SHOT %s %dx%d" % [name, image.get_width(), image.get_height()])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	if _game == null:
		printerr("QA CARD HD FAIL: Game autoload missing")
		quit(1)
		return
	_game.save_path = "user://qa_card_hd_save.json"
	LevelLoader.deterministic = true
	for view in VIEWS:
		for level_id in LEVELS:
			await _capture(view, level_id)
	print("QA CARD HD DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		printerr("QA CARD HD FAIL: " + failure)
	quit(1)

func _capture(view: Dictionary, level_id: String) -> void:
	_game.endless_run = null
	_game.current_level_id = level_id
	_game.settings["orientation"] = view["orientation"]
	_game.settings["mascot"] = true
	_game.apply_orientation()
	root.size = view["window"]
	_game.set_locale("pt")
	change_scene_to_file("res://scenes/level.tscn")
	var scene = null
	for i in 120:
		await process_frame
		scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			break
	if scene == null:
		_failures.append("%s L%s: level did not load" % [view["tag"], level_id])
		return
	await _frames(30)
	await _seconds(4.6)
	await _shot("card_hd_%s_L%s_board" % [view["tag"], level_id])
	_fill_zone_and_reserve(scene)
	await _frames(5)
	await _shot("card_hd_%s_L%s_full" % [view["tag"], level_id])

func _fill_zone_and_reserve(scene) -> void:
	var c = scene.controller
	var types := ["heart", "gem", "leaf", "frog", "sacer", "cat", "wolf"]
	c.zone.cards.clear()
	for i in types.size():
		var z := Card.new("qa_hd_zone_%d" % i, types[i])
		z.source = Card.Source.DECK_A
		c.zone.add(z)
	c.reserve.clear()
	var reserve_types := ["heart", "gem", "frog", "leaf", "sacer"]
	for i in reserve_types.size():
		var r := Card.new("qa_hd_res_%d" % i, reserve_types[i])
		r.source = Card.Source.DECK_A
		r.location = Card.Location.RESERVE
		r.state = Card.State.SELECTED
		c.reserve.append(r)
	c.powers.counts = {"hold": 1, "undo": 5, "refresh": 4}
	scene.render()
