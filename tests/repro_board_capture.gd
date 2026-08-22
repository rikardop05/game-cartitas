extends SceneTree

# Permanent full-pipeline regression for the two canonical mobile viewports.
const LEVEL_ID := "6"
const FIXED_SEED := 6001
const EPSILON := 0.01
const VIEWS := [
	{"name": "portrait-360x640", "orientation": "portrait", "window": Vector2i(360, 640), "board": Vector2(332, 264)},
	{"name": "landscape-640x360", "orientation": "landscape", "window": Vector2i(640, 360), "board": Vector2(546, 240)},
]

var _errors: Array[String] = []
var _save_before: Dictionary

func _run() -> void:
	_save_before = _snapshot_save()
	var game = root.get_node_or_null("Game")
	if game == null:
		_errors.append("Game autoload missing")
		_finish()
		return

	for view in VIEWS:
		game.settings["orientation"] = view["orientation"]
		game.apply_orientation()
		root.size = view["window"]
		for i in 3:
			await process_frame

		game.current_level_id = LEVEL_ID
		change_scene_to_file("res://scenes/level.tscn")
		var scene = null
		var controller = null
		var container: Control = null
		for i in 30:
			await process_frame
			scene = current_scene
			if scene != null:
				controller = scene.get("controller")
				container = scene.get("board_container") as Control
				if controller != null and container != null and container.get_child_count() > 0:
					break
		if scene == null or controller == null or container == null:
			_errors.append("%s: scene/controller/board missing" % view["name"])
			continue
		if not container.size.is_equal_approx(view["board"]):
			_errors.append("%s: board size %s != %s" % [view["name"], str(container.size), str(view["board"])])

		var resolved: Dictionary = LevelLoader.load_level(LEVEL_ID, container.size)
		if resolved.has("error"):
			_errors.append("%s: fixed-seed load failed: %s" % [view["name"], str(resolved["error"])])
			continue
		var metrics: Dictionary = resolved.get("generation_metrics", {})
		var seed_used := int(metrics.get("seed_used", -1))
		if seed_used != FIXED_SEED:
			_errors.append("%s: expected seed %d, got %d" % [view["name"], FIXED_SEED, seed_used])
		if view["orientation"] == "landscape" and not bool(metrics.get("fits_landscape", false)):
			_errors.append("%s: fits_landscape must be true" % view["name"])
		if not _same_board(resolved["cards"], controller.board.cards):
			_errors.append("%s: scene board differs from fixed-seed output" % view["name"])

		var offenders := _audit(controller, container)
		for offender in offenders:
			_errors.append("%s: %s" % [view["name"], offender])
		var warning := scene.get("_layout_warning") as Label
		if warning != null and warning.visible:
			_errors.append("%s: unexpected layout warning" % view["name"])
		print("board regression view=%s viewport=%s board=%s cards=%d overflow=%d" % [
			view["name"], str(scene.get_viewport_rect().size), str(container.size),
			container.get_child_count(), offenders.size(),
		])
	_finish()

func _same_board(resolved_cards: Array, runtime_cards: Array) -> bool:
	if resolved_cards.size() != runtime_cards.size():
		return false
	var expected := {}
	for c in resolved_cards:
		expected[str(c["id"])] = [Vector2(float(c["x"]), float(c["y"])), int(c["layer"])]
	for card in runtime_cards:
		if not expected.has(card.id):
			return false
		var value: Array = expected[card.id]
		if not (card.position as Vector2).is_equal_approx(value[0]) or card.layer != value[1]:
			return false
	return true

func _audit(controller, container: Control) -> Array[String]:
	var offenders: Array[String] = []
	var nodes: Array = container.get_children()
	var cards: Array = []
	for card in controller.board.cards:
		if not card.is_removed() and card.location == Card.Location.BOARD:
			cards.append(card)
	cards.sort_custom(func(a, b): return a.layer < b.layer)
	if nodes.size() != cards.size():
		offenders.append("node count %d != card count %d" % [nodes.size(), cards.size()])
		return offenders
	var bounds := Rect2(Vector2.ZERO, container.size)
	for i in cards.size():
		var node := nodes[i] as Control
		if node == null:
			offenders.append("board child %d is not a Control" % i)
			continue
		var rect := node.get_rect()
		var top := maxf(0.0, -rect.position.y)
		var bottom := maxf(0.0, rect.end.y - bounds.end.y)
		var left := maxf(0.0, -rect.position.x)
		var right := maxf(0.0, rect.end.x - bounds.end.x)
		if top > EPSILON or bottom > EPSILON or left > EPSILON or right > EPSILON:
			offenders.append("card=%s layer=%d rect=%s bounds=%s overflow(top=%.2f bottom=%.2f left=%.2f right=%.2f)" % [
				cards[i].id, cards[i].layer, str(rect), str(bounds), top, bottom, left, right,
			])
	return offenders

func _snapshot_save() -> Dictionary:
	var path := SaveManager.DEFAULT_PATH
	var exists := FileAccess.file_exists(path)
	var bytes := PackedByteArray()
	if exists:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"exists": true, "bytes": bytes, "read_error": FileAccess.get_open_error()}
		bytes = file.get_buffer(file.get_length())
	return {"exists": exists, "bytes": bytes}

func _finish() -> void:
	var save_after := _snapshot_save()
	if _save_before.has("read_error") or save_after.has("read_error"):
		_errors.append("could not verify save preservation")
	elif _save_before["exists"] != save_after["exists"] or _save_before["bytes"] != save_after["bytes"]:
		_errors.append("user save changed during regression")
	if not _errors.is_empty():
		for error in _errors:
			printerr("BOARD REGRESSION FAIL: " + error)
		quit(1)
		return
	print("BOARD CAPTURE REGRESSION OK: portrait and landscape have zero overflow")
	quit(0)

func _init() -> void:
	call_deferred("_run")
