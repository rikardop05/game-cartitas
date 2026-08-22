extends SceneTree

# Deterministic full-scene repro for landscape HUD/container overflow.
# Read-only: loads Level 6 with its fixed profile seed and verifies the save
# file is byte-identical before/after the run.

const LEVEL_ID := "6"
const FIXED_SEED := 6001
const WINDOW := Vector2i(640, 360)
const EPSILON := 0.01
const REQUIRED := [
	"ScreenMargin",
	"Body",
	"MainColumn",
	"BoardFrame",
	"LowerStrip",
	"Support",
	"Reserve",
	"ClearingZone",
	"Powers",
]

var _failures: Array[String] = []
var _failure_keys := {}
var _save_before: Dictionary

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_save_before = _snapshot_save()
	var game = root.get_node_or_null("Game")
	if game == null:
		_fail("infrastructure", "Game autoload missing")
		_finish()
		return

	# Do not call Game.set_orientation(): it persists settings to the user save.
	game.settings["orientation"] = "landscape"
	game.apply_orientation()
	root.size = WINDOW
	for i in 3:
		await process_frame

	game.current_level_id = LEVEL_ID
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_for_level_scene()
	if scene == null:
		_fail("infrastructure", "LevelScreen did not become ready")
		_finish()
		return

	var nodes := _required_nodes(scene)
	if nodes.size() != REQUIRED.size():
		_finish()
		return
	var stable_frames := await _wait_for_stable_layout(scene)
	if stable_frames < 3:
		_fail("infrastructure", "HUD layout did not stabilize")

	var viewport_bounds := Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
	var controller = scene.get("controller")
	var board := scene.find_child("Board", true, false) as Control
	_verify_fixed_seed(controller, board)

	print("HUD BOUNDS REPRO level=%s seed=%d window=%s viewport=%s stable_frames=%d" % [
		LEVEL_ID, FIXED_SEED, str(WINDOW), str(viewport_bounds), stable_frames,
	])
	for node_name in REQUIRED:
		var node: Control = nodes[node_name]
		var parent_rect := Rect2()
		if node.get_parent() is Control:
			parent_rect = (node.get_parent() as Control).get_global_rect()
		print("HUD MEASURE name=%s path=%s rect=%s parent_rect=%s viewport_bottom=%.2f rect_bottom=%.2f" % [
			node_name, str(scene.get_path_to(node)), str(node.get_global_rect()), str(parent_rect),
			viewport_bounds.end.y, node.get_global_rect().end.y,
		])

	# Exact hierarchy contracts for the main HUD regions.
	_assert_inside(nodes["Body"], nodes["ScreenMargin"].get_global_rect(), "container:Body-in-ScreenMargin")
	_assert_inside(nodes["MainColumn"], nodes["Body"].get_global_rect(), "container:MainColumn-in-Body")
	_assert_inside(nodes["Powers"], nodes["Body"].get_global_rect(), "container:Powers-in-Body")
	_assert_inside(nodes["BoardFrame"], nodes["MainColumn"].get_global_rect(), "container:BoardFrame-in-MainColumn")
	_assert_inside(nodes["LowerStrip"], nodes["MainColumn"].get_global_rect(), "container:LowerStrip-in-MainColumn")
	for child_name in ["Support", "Reserve", "ClearingZone"]:
		_assert_inside(nodes[child_name], nodes["LowerStrip"].get_global_rect(), "container:%s-in-LowerStrip" % child_name)

	# Every visible Control under the HUD must stay inside the viewport. This is
	# the user-visible bottom-clipping invariant, independent of parent layout.
	_audit_viewport_descendants(nodes["ScreenMargin"], viewport_bounds, scene)
	_audit_clip_ancestors(nodes["ScreenMargin"], scene)

	# LowerStrip and every visible descendant must remain inside Body, even when
	# a child's theme/content minimum silently grows beyond the nominal 56 px.
	_audit_subtree_against(nodes["LowerStrip"], nodes["Body"].get_global_rect(), "lower-vs-body", scene, true)

	# Relevant visual groups must also contain their own descendants.
	for owner_name in ["BoardFrame", "Support", "Reserve", "ClearingZone", "Powers"]:
		var owner: Control = nodes[owner_name]
		_audit_subtree_against(owner, owner.get_global_rect(), "visual-vs-%s" % owner_name, scene, false)

	var zone := scene.get("zone_container") as Control
	_assert_zone_single_row(zone, scene)
	_assert_action_button(scene.get("deck_a_btn") as Button, "deck_a_btn", viewport_bounds, nodes["ScreenMargin"], scene)
	_assert_action_button(scene.get("deck_b_btn") as Button, "deck_b_btn", viewport_bounds, nodes["ScreenMargin"], scene)
	var power_buttons: Dictionary = scene.get("power_buttons")
	for power_name in PowerManager.POWERS:
		_assert_action_button(power_buttons.get(power_name) as Button, "power:%s" % power_name, viewport_bounds, nodes["ScreenMargin"], scene)

	_finish()

func _wait_for_level_scene():
	for i in 60:
		await process_frame
		var scene = current_scene
		if scene == null or scene.name != "LevelScreen":
			continue
		var controller = scene.get("controller")
		var screen_margin := scene.find_child("ScreenMargin", true, false) as Control
		var body := scene.find_child("Body", true, false) as Control
		if controller != null and screen_margin != null and body != null and body.size.x > 0.0:
			return scene
	return null

func _wait_for_stable_layout(scene) -> int:
	var previous := ""
	var consecutive := 0
	for i in 60:
		await process_frame
		var current := _layout_signature(scene)
		if current == previous and current != "":
			consecutive += 1
		else:
			consecutive = 0
			previous = current
		if consecutive >= 3:
			return consecutive
	return consecutive

func _layout_signature(scene) -> String:
	var parts: Array[String] = []
	for node_name in REQUIRED:
		var node := scene.find_child(node_name, true, false) as Control
		if node == null:
			return ""
		var rect := node.get_global_rect()
		parts.append("%s:%.3f,%.3f,%.3f,%.3f" % [node_name, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	return "|".join(parts)

func _required_nodes(scene) -> Dictionary:
	var out := {}
	for node_name in REQUIRED:
		var node := scene.find_child(node_name, true, false) as Control
		if node == null:
			_fail("infrastructure", "required Control missing: %s" % node_name)
		else:
			out[node_name] = node
	return out

func _verify_fixed_seed(controller, board: Control) -> void:
	if controller == null or board == null:
		_fail("infrastructure", "controller or Board missing")
		return
	var resolved: Dictionary = LevelLoader.load_level(LEVEL_ID, board.size)
	if resolved.has("error"):
		_fail("infrastructure", "fixed-seed load failed: %s" % str(resolved["error"]))
		return
	var seed_used := int(resolved.get("generation_metrics", {}).get("seed_used", -1))
	if seed_used != FIXED_SEED:
		_fail("infrastructure", "expected seed %d, got %d" % [FIXED_SEED, seed_used])
	if not _same_board(resolved["cards"], controller.board.cards):
		_fail("infrastructure", "scene board differs from fixed-seed LevelLoader output")

func _same_board(resolved_cards: Array, runtime_cards: Array) -> bool:
	if resolved_cards.size() != runtime_cards.size():
		return false
	var expected := {}
	for data in resolved_cards:
		expected[str(data["id"])] = [Vector2(float(data["x"]), float(data["y"])), int(data["layer"])]
	for card in runtime_cards:
		if not expected.has(card.id):
			return false
		var value: Array = expected[card.id]
		if not card.position.is_equal_approx(value[0]) or card.layer != value[1]:
			return false
	return true

func _audit_viewport_descendants(root_control: Control, viewport_bounds: Rect2, scene) -> void:
	var controls: Array[Control] = []
	_collect_visible_controls(root_control, controls, true)
	for control in controls:
		var rect := control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var overflow := _overflow(rect, viewport_bounds)
		if overflow["bottom"] > EPSILON:
			_fail("viewport-bottom", "path=%s rect=%s viewport=%s overflow=%s" % [
				str(scene.get_path_to(control)), str(rect), str(viewport_bounds), str(overflow),
			])
		elif _max_overflow(overflow) > EPSILON:
			_fail("viewport-other", "path=%s rect=%s viewport=%s overflow=%s" % [
				str(scene.get_path_to(control)), str(rect), str(viewport_bounds), str(overflow),
			])

func _audit_clip_ancestors(root_control: Control, scene) -> void:
	var controls: Array[Control] = []
	_collect_visible_controls(root_control, controls, true)
	for control in controls:
		_audit_control_clip_ancestors(control, root_control, scene, "clip-ancestor")

func _audit_control_clip_ancestors(control: Control, root_control: Control, scene, kind: String) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var ancestor_control := ancestor as Control
			if ancestor_control.clip_contents:
				var rect := control.get_global_rect()
				var bounds := ancestor_control.get_global_rect()
				var overflow := _overflow(rect, bounds)
				if _max_overflow(overflow) > EPSILON:
					_fail(kind, "path=%s clip_ancestor=%s rect=%s bounds=%s overflow=%s" % [
						str(scene.get_path_to(control)), str(scene.get_path_to(ancestor_control)),
						str(rect), str(bounds), str(overflow),
					])
		if ancestor == root_control:
			break
		ancestor = ancestor.get_parent()

func _assert_zone_single_row(zone: Control, scene) -> void:
	if zone == null:
		_fail("zone", "zone_container missing")
		return
	var visible_children: Array[Control] = []
	for child in zone.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			visible_children.append(child as Control)
	if visible_children.size() != 7:
		_fail("zone-count", "expected 7 visible children, got %d" % visible_children.size())
	if visible_children.is_empty():
		return
	var expected_y := visible_children[0].get_global_rect().position.y
	var zone_bounds := zone.get_global_rect()
	for child in visible_children:
		var rect := child.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			_fail("zone-size", "path=%s has non-positive rect=%s" % [str(scene.get_path_to(child)), str(rect)])
		if absf(rect.position.y - expected_y) > EPSILON:
			_fail("zone-row", "path=%s y=%.3f expected_y=%.3f" % [str(scene.get_path_to(child)), rect.position.y, expected_y])
		var overflow := _overflow(rect, zone_bounds)
		if _max_overflow(overflow) > EPSILON:
			_fail("zone-bounds", "path=%s rect=%s container=%s overflow=%s" % [
				str(scene.get_path_to(child)), str(rect), str(zone_bounds), str(overflow),
			])

func _assert_action_button(button: Button, label: String, viewport_bounds: Rect2, root_control: Control, scene) -> void:
	if button == null:
		_fail("button", "%s missing" % label)
		return
	if not button.is_visible_in_tree():
		_fail("button-visible", "%s path=%s is not visible" % [label, str(scene.get_path_to(button))])
		return
	var rect := button.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_fail("button-size", "%s path=%s has non-positive rect=%s" % [label, str(scene.get_path_to(button)), str(rect)])
	var viewport_overflow := _overflow(rect, viewport_bounds)
	if _max_overflow(viewport_overflow) > EPSILON:
		_fail("button-viewport", "%s path=%s rect=%s viewport=%s overflow=%s" % [
			label, str(scene.get_path_to(button)), str(rect), str(viewport_bounds), str(viewport_overflow),
		])
	_audit_control_clip_ancestors(button, root_control, scene, "button-clip:%s" % label)
	if button.disabled:
		_fail("button-disabled", "%s path=%s is disabled" % [label, str(scene.get_path_to(button))])
	if button.get_signal_connection_list(&"pressed").is_empty():
		_fail("button-signal", "%s path=%s has no pressed connection" % [label, str(scene.get_path_to(button))])

func _audit_subtree_against(root_control: Control, bounds: Rect2, kind: String, scene, include_root: bool) -> void:
	var controls: Array[Control] = []
	_collect_visible_controls(root_control, controls, include_root)
	for control in controls:
		var rect := control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var overflow := _overflow(rect, bounds)
		if _max_overflow(overflow) > EPSILON:
			_fail(kind, "path=%s rect=%s bounds=%s overflow=%s" % [
				str(scene.get_path_to(control)), str(rect), str(bounds), str(overflow),
			])

func _collect_visible_controls(node: Node, out: Array[Control], include_self: bool) -> void:
	if include_self and node is Control:
		var control := node as Control
		if control.is_visible_in_tree():
			out.append(control)
	for child in node.get_children():
		if child is Control:
			var child_control := child as Control
			if not child_control.is_visible_in_tree():
				continue
			out.append(child_control)
			_collect_visible_controls(child_control, out, false)

func _assert_inside(control: Control, bounds: Rect2, kind: String) -> void:
	var rect := control.get_global_rect()
	var overflow := _overflow(rect, bounds)
	if _max_overflow(overflow) > EPSILON:
		_fail(kind, "rect=%s bounds=%s overflow=%s" % [str(rect), str(bounds), str(overflow)])

func _overflow(rect: Rect2, bounds: Rect2) -> Dictionary:
	return {
		"top": maxf(0.0, bounds.position.y - rect.position.y),
		"bottom": maxf(0.0, rect.end.y - bounds.end.y),
		"left": maxf(0.0, bounds.position.x - rect.position.x),
		"right": maxf(0.0, rect.end.x - bounds.end.x),
	}

func _max_overflow(overflow: Dictionary) -> float:
	return maxf(maxf(float(overflow["top"]), float(overflow["bottom"])), maxf(float(overflow["left"]), float(overflow["right"])))

func _fail(kind: String, detail: String) -> void:
	var key := "%s|%s" % [kind, detail]
	if _failure_keys.has(key):
		return
	_failure_keys[key] = true
	_failures.append("kind=%s %s" % [kind, detail])

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
		_fail("save", "could not verify save preservation")
	elif _save_before["exists"] != save_after["exists"] or _save_before["bytes"] != save_after["bytes"]:
		_fail("save", "user save changed during repro")

	if _failures.is_empty():
		print("HUD BOUNDS REPRO GREEN: all visible HUD Controls fit viewport and containers")
		quit(0)
		return
	printerr("HUD BOUNDS REPRO RED: %d violation(s)" % _failures.size())
	for failure in _failures:
		printerr("  " + failure)
	quit(1)
