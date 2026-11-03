extends SceneTree

## Runtime probe for level-screen render cost on the largest shipped board.
## Usage: --script res://tests/probe_render_cost.gd -- before landscape
## Node deltas count descendants of Board, ZoneSlots and ReserveCards for a stable comparison.

const OUT_DIR := "user://qa_shots"
const ACTION_COUNT := 30

var _phase := "baseline"
var _orientation := "landscape"
var _failed := false
var _render_metrics: Dictionary = {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_phase = str(args[0])
	if args.size() > 1:
		_orientation = str(args[1])
	call_deferred("_run")

func _run() -> void:
	var game := root.get_node_or_null("Game")
	if game == null:
		printerr("RENDER PROBE FAIL: Game autoload missing")
		quit(1)
		return
	LevelLoader.deterministic = true
	game.save_path = "user://probe_render_cost_save.json"
	game.progress = ProgressManager.new()
	game.endless_run = null
	game.settings["orientation"] = _orientation
	game.settings["mascot"] = true
	game.apply_orientation()
	root.size = Vector2i(1280, 720) if _orientation == "landscape" else Vector2i(720, 1280)
	game.current_level_id = "15"
	change_scene_to_file("res://scenes/level.tscn")
	var scene: Node = await _wait_for_level()
	if scene == null:
		printerr("RENDER PROBE FAIL: Level 15 did not load")
		quit(1)
		return
	await _frames(30)
	await _seconds(4.6)
	_hide_intro(scene)
	await _frames(2)
	await _capture(scene)
	await _measure(scene)
	game.save_path = SaveManager.DEFAULT_PATH
	print("RENDER PROBE DONE phase=%s orientation=%s selections=%d" % [
		_phase, _orientation, ACTION_COUNT,
	])
	quit(1 if _failed else 0)

func _wait_for_level():
	for _i in 2400:
		await process_frame
		if current_scene != null and current_scene.name == "LevelScreen" and current_scene.get("controller") != null:
			return current_scene
	return null

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _seconds(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _hide_intro(scene: Node) -> void:
	var intro := scene.find_child("IntroOverlay", true, false)
	if intro != null:
		intro.queue_free()
	var bubble := scene.find_child("InstructionBubble", true, false)
	if bubble != null:
		bubble.queue_free()
	var mascot = scene.get("mascot")
	if mascot != null:
		mascot.hide_bubble()
		var bubble_root := mascot.find_child("BubbleRoot", true, false) as Control
		if bubble_root != null:
			bubble_root.hide()

func _capture(scene: Node) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/level_L15_%s_%s.png" % [OUT_DIR, _orientation, _phase]
	var error := image.save_png(path)
	if error != OK:
		printerr("RENDER PROBE FAIL: could not save %s (err %d)" % [path, error])
	else:
		print("RENDER PROBE SHOT %s %dx%d" % [path, image.get_width(), image.get_height()])

func _measure(scene: Node) -> void:
	var controller = scene.get("controller")
	var board: Control = scene.get("board_container")
	var zone: Control = scene.get("zone_container")
	var reserve: Control = scene.get("reserve_container")
	_render_metrics = {"elapsed_total": 0, "elapsed_max": 0, "nodes_total": 0, "nodes_max": 0, "measured": 0}
	controller.powers.counts["hold"] = ACTION_COUNT
	var selection_count := 0
	while selection_count < ACTION_COUNT:
		var card: Card
		for candidate in controller.board.cards:
			if candidate.location == Card.Location.BOARD and candidate.state == Card.State.AVAILABLE:
				card = candidate
				break
		if card == null:
			printerr("RENDER PROBE FAIL: no available board card at selection %d" % selection_count)
			_failed = true
			break
		var result: Dictionary = controller.select_card(card.id)
		if not bool(result.get("ok", false)):
			printerr("RENDER PROBE FAIL: selection %d was rejected: %s" % [selection_count, str(result)])
			_failed = true
			break
		_measure_render(scene, board, zone, reserve)
		# Keep the real clearing-zone capacity in the probe. A stocked Hold power periodically
		# moves cards to Reserve just as a player would, letting the sequence reach 30 selections.
		if controller.zone.size() >= controller.clearing_capacity - 2:
			var hold_result: Dictionary = controller.use_hold()
			if bool(hold_result.get("ok", false)):
				_measure_render(scene, board, zone, reserve)
		selection_count += 1
		await process_frame
	var measured := int(_render_metrics["measured"])
	if measured == 0:
		printerr("RENDER PROBE FAIL: no actions measured")
		_failed = true
		return
	print("RENDER COST phase=%s orientation=%s level=15 selections=%d render_actions=%d avg=%.3fms max=%.3fms nodes/action=%.1f nodes/action_max=%d" % [
		_phase,
		_orientation,
		selection_count,
		measured,
		float(_render_metrics["elapsed_total"]) / float(measured) / 1000.0,
		float(_render_metrics["elapsed_max"]) / 1000.0,
		float(_render_metrics["nodes_total"]) / float(measured),
		int(_render_metrics["nodes_max"]),
	])

func _measure_render(scene: Node, board: Control, zone: Control, reserve: Control) -> void:
	var before_ids: Dictionary = {}
	_collect_node_ids(board, before_ids)
	_collect_node_ids(zone, before_ids)
	_collect_node_ids(reserve, before_ids)
	var start := Time.get_ticks_usec()
	scene.render()
	var elapsed := Time.get_ticks_usec() - start
	var after_ids: Dictionary = {}
	_collect_node_ids(board, after_ids)
	_collect_node_ids(zone, after_ids)
	_collect_node_ids(reserve, after_ids)
	var created := 0
	for instance_id in after_ids:
		if not before_ids.has(instance_id):
			created += 1
	# Update by reference is required because GDScript pass-by-value copies scalar arguments.
	_render_metrics["elapsed_total"] += elapsed
	_render_metrics["elapsed_max"] = maxi(int(_render_metrics["elapsed_max"]), elapsed)
	_render_metrics["nodes_total"] += created
	_render_metrics["nodes_max"] = maxi(int(_render_metrics["nodes_max"]), created)
	_render_metrics["measured"] += 1

func _collect_node_ids(parent: Node, ids: Dictionary) -> void:
	for child in parent.get_children():
		ids[child.get_instance_id()] = true
		_collect_node_ids(child, ids)
