extends SceneTree

## Cost probe for the card impact FX (Phase M): Level 15 deal + 10 zone landings.
## Prints avg/max frame ms during each phase and the node count before/after (leak check).
## Usage: --script res://tests/probe_impact_cost.gd -- landscape|portrait   (windowed for real numbers)

var _frames: Array[float] = []

func _init() -> void:
	call_deferred("_run")

func _measure(seconds: float, label: String) -> void:
	var start := Time.get_ticks_msec()
	var last := start
	var samples: Array[float] = []
	while float(Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await process_frame
		var now := Time.get_ticks_msec()
		samples.append(float(now - last))
		last = now
	var total := 0.0
	var worst := 0.0
	for v in samples:
		total += v
		worst = maxf(worst, v)
	print("IMPACT PROBE %s: frames=%d avg=%.2f ms max=%.2f ms" % [label, samples.size(), total / maxf(1.0, samples.size()), worst])

func _run() -> void:
	var orientation := "landscape"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		orientation = str(args[0])
	var game := root.get_node_or_null("Game")
	LevelLoader.deterministic = true
	game.save_path = "user://probe_impact_cost_save.json"
	game.progress = ProgressManager.new()
	game.endless_run = null
	game.settings["orientation"] = orientation
	game.apply_orientation()
	root.size = Vector2i(1280, 720) if orientation == "landscape" else Vector2i(720, 1280)
	game.current_level_id = "15"
	change_scene_to_file("res://scenes/level.tscn")
	var scene: Node = null
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.name == "LevelScreen" and current_scene.get("controller") != null:
			scene = current_scene
			break
	if scene == null:
		printerr("IMPACT PROBE FAIL: level did not load")
		quit(1)
		return
	var nodes_start := get_node_count()
	await _measure(1.7, "deal (%d cards)" % scene._board_nodes.size())
	await _measure(4.0, "idle after deal")
	var base_nodes := get_node_count()
	var tapped := 0
	var c: GameController = scene.controller
	var start := Time.get_ticks_msec()
	var last := start
	var samples: Array[float] = []
	var next_tap := 0.0
	while float(Time.get_ticks_msec() - start) / 1000.0 < 2.8:
		var t := float(Time.get_ticks_msec() - start) / 1000.0
		if tapped < 10 and t >= next_tap:
			for a in c.get_legal_actions():
				if a["action"] == "select_card":
					scene._on_card(a["card_id"])
					tapped += 1
					break
			next_tap += 0.12
		await process_frame
		var now := Time.get_ticks_msec()
		samples.append(float(now - last))
		last = now
	var total := 0.0
	var worst := 0.0
	for v in samples:
		total += v
		worst = maxf(worst, v)
	print("IMPACT PROBE %d zone landings: frames=%d avg=%.2f ms max=%.2f ms" % [tapped, samples.size(), total / maxf(1.0, samples.size()), worst])
	await _measure(2.0, "settle")
	var after := get_node_count()
	print("IMPACT PROBE nodes: after-level-built=%d baseline(after deal)=%d after-landings=%d fx_live=%d (zone cards removed on match may differ)" % [nodes_start, base_nodes, after, CardImpactFx.live_count])
	game.save_path = SaveManager.DEFAULT_PATH
	quit(0)
