extends SceneTree

# Full-pipeline regression: logical slots (LevelConfig) -> LayoutGenerator
# positions -> level_screen._board_layout()/render() final node positions, for
# L1-L10 across every viewport (portrait canonical 360x640, landscape 640x360
# and the four mandatory desktop resolutions). Loads the real scene headless.
# Guards double compression: no same-layer collisions, no unique-position
# collapse, intentional cross-layer overlap preserved, non-degenerate pitch and
# rendered card scale.

const LEVELS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"]
const VIEWS := [
	{"name": "portrait-360x640", "orient": "portrait", "window": Vector2i(360, 640)},
	{"name": "landscape-640x360", "orient": "landscape", "window": Vector2i(640, 360)},
	{"name": "desktop-1280x720", "orient": "landscape", "window": Vector2i(1280, 720)},
	{"name": "desktop-1366x768", "orient": "landscape", "window": Vector2i(1366, 768)},
	{"name": "desktop-1920x1080", "orient": "landscape", "window": Vector2i(1920, 1080)},
	{"name": "desktop-2560x1440", "orient": "landscape", "window": Vector2i(2560, 1440)},
]
const SAME_LAYER_EPS := 1.0
const EPSILON := 0.01
const DEGENERATE_PITCH := 8.0
const MIN_CARD_SCALE := 0.85

var _fails: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _unique_positions(points: Array) -> Array:
	var uniq: Array = []
	for p in points:
		var hit := false
		for u in uniq:
			if (u as Vector2).distance_to(p) < SAME_LAYER_EPS:
				hit = true
				break
		if not hit:
			uniq.append(p)
	return uniq

func _min_gap(points: Array) -> float:
	if points.size() < 2:
		return INF
	var min_gap := INF
	for i in points.size():
		for j in range(i + 1, points.size()):
			var d := (points[i] as Vector2).distance_to(points[j])
			if d < min_gap:
				min_gap = d
	return min_gap

func _cross_layer_overlaps(final_by_id: Dictionary, controller, rendered_size: float) -> int:
	var size := rendered_size
	var overlaps := 0
	var ids: Array = final_by_id.keys()
	for i in ids.size():
		var a_id: String = ids[i]
		var a_pos: Vector2 = final_by_id[a_id]
		var a_layer: int = controller.board.get_card(a_id).layer
		var a_rect := Rect2(a_pos, Vector2(size, size))
		for j in range(i + 1, ids.size()):
			var b_id: String = ids[j]
			var b_pos: Vector2 = final_by_id[b_id]
			var b_layer: int = controller.board.get_card(b_id).layer
			if a_layer == b_layer:
				continue
			if a_rect.intersects(Rect2(b_pos, Vector2(size, size))):
				overlaps += 1
	return overlaps

func _report(level_id: String, view: Dictionary, scene, controller, container: Control) -> void:
	var scale_limited := bool(scene.get("_scale_limited"))
	var nodes: Array = container.get_children()
	var cards: Array = []
	for c in controller.board.cards:
		if c.is_removed() or c.location != Card.Location.BOARD:
			continue
		cards.append(c)
	cards.sort_custom(func(a, b): return a.layer < b.layer)
	if nodes.size() != cards.size():
		_check(false, "L%s %s: node count %d != card count %d" % [level_id, view["name"], nodes.size(), cards.size()])
		return
	var layer_final := {}
	var final_by_id := {}
	var rendered_scale := 0.0
	var out_of_container := 0
	var node_size := Vector2.ZERO
	for i in cards.size():
		var node: Control = nodes[i]
		var pos: Vector2 = node.position
		var layer: int = node.z_index
		node_size = node.size
		if not layer_final.has(layer):
			layer_final[layer] = []
		layer_final[layer].append(pos)
		final_by_id[cards[i].id] = pos
		var r := Rect2(pos, node.size)
		if r.position.x < -EPSILON or r.position.y < -EPSILON or r.end.x > container.size.x + EPSILON or r.end.y > container.size.y + EPSILON:
			out_of_container += 1
	if node_size.y > 0.0:
		rendered_scale = node_size.y / 48.0
	var gen_layer := {}
	for c in controller.board.cards:
		if not gen_layer.has(int(c.layer)):
			gen_layer[int(c.layer)] = []
		gen_layer[int(c.layer)].append(Vector2(c.position.x, c.position.y))
	var cfg := DifficultyProfile.for_level(int(level_id))
	var slot_cols := cfg.slot_columns()
	var slot_rows := cfg.slot_rows()
	var min_eff := INF
	var layer_lines: Array = []
	for layer in gen_layer:
		var uniq_gen := _unique_positions(gen_layer[layer])
		var uniq_final := _unique_positions(layer_final.get(layer, []))
		var eff := _min_gap(uniq_final)
		min_eff = minf(min_eff, eff)
		layer_lines.append("      L%d: gen=%d final=%d ratio=%.2f gap=%.1f" % [
			layer, uniq_gen.size(), uniq_final.size(),
			(float(uniq_final.size()) / float(uniq_gen.size())) if uniq_gen.size() > 0 else 0.0, eff,
		])
		_check(uniq_final.size() >= uniq_gen.size() - 1,
			"L%s %s layer %d unique positions collapsed (%d final vs %d generated)" % [level_id, view["name"], layer, uniq_final.size(), uniq_gen.size()])
	_check(min_eff >= DEGENERATE_PITCH,
		"L%s %s effective pitch %.1f degenerates below %.1f" % [level_id, view["name"], min_eff, DEGENERATE_PITCH])
	var same_layer_col := 0
	for layer in layer_final:
		var seen := {}
		for p in layer_final[layer]:
			var key := "%d,%d" % [int(round(p.x)), int(round(p.y))]
			if seen.has(key):
				same_layer_col += 1
			seen[key] = true
	_check(same_layer_col == 0, "L%s %s: %d same-layer coincidences after re-snap" % [level_id, view["name"], same_layer_col])
	var cross := _cross_layer_overlaps(final_by_id, controller, node_size.y)
	_check(cross >= 1, "L%s %s: no intentional cross-layer overlap found" % [level_id, view["name"]])
	_check(rendered_scale >= MIN_CARD_SCALE - 0.01,
		"L%s %s: rendered card scale %.2f below MIN_CARD_SCALE %.2f" % [level_id, view["name"], rendered_scale, MIN_CARD_SCALE])
	_check(out_of_container == 0,
		"L%s %s: %d card(s) outside the board container (clip must be zero)" % [level_id, view["name"], out_of_container])
	if scale_limited:
		var warn: Label = scene.get("_layout_warning")
		_check(warn != null and warn.visible,
			"L%s %s: scale_limited but no visible layout warning (diagnostic)" % [level_id, view["name"]])
		print("L%s %s avail=%s rendered_scale=%.2f min_gap=%.1f cross=%d slots=%dx%d clip=%d scale_limited=YES" % [
			level_id, view["name"], str(container.size), rendered_scale, min_eff, cross, slot_cols, slot_rows, out_of_container,
		])
	else:
		print("L%s %s avail=%s rendered_scale=%.2f min_gap=%.1f cross=%d slots=%dx%d clip=%d scale_limited=NO" % [
			level_id, view["name"], str(container.size), rendered_scale, min_eff, cross, slot_cols, slot_rows, out_of_container,
		])
	for l in layer_lines:
		print(l)

func _run() -> void:
	var game = root.get_node("Game")
	for level_id in LEVELS:
		for view in VIEWS:
			game.settings["orientation"] = view["orient"]
			game.apply_orientation()
			root.size = view["window"]
			for i in 2:
				await process_frame
			game.current_level_id = level_id
			change_scene_to_file("res://scenes/level.tscn")
			for i in 12:
				await process_frame
			var scene := current_scene
			if scene == null or scene.name != "LevelScreen":
				_check(false, "L%s %s: level scene did not load" % [level_id, view["name"]])
				continue
			var controller = scene.get("controller")
			if controller == null:
				_check(false, "L%s %s: controller missing" % [level_id, view["name"]])
				continue
			var container: Control = scene.get("board_container")
			_report(level_id, view, scene, controller, container)
	if _fails.is_empty():
		print("REGRESSION BOARD LAYOUT OK")
		quit(0)
	else:
		for f in _fails:
			printerr("REGRESSION FAIL: " + f)
		quit(1)

func _init() -> void:
	call_deferred("_run")