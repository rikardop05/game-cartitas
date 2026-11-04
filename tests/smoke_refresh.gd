extends SceneTree

## PHASE S2 power-animation smoke. Exercises Refresh, Undo and Hold through the real LevelScreen,
## including the handoff from animated ghosts to the controller's final card nodes.

const STEP_TIMEOUT_MS := 20000
const THROWAWAY_SAVE := "user://smoke_refresh_save.json"

var _failures: Array[String] = []
var _game

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_game = root.get_node_or_null("Game")
	if _game == null:
		_fail("Game autoload not available")
		_finish()
		return
	_game.save_path = THROWAWAY_SAVE
	_game.progress = ProgressManager.new()
	_game.endless_run = null
	_game.current_level_id = "6"
	LevelLoader.deterministic = true
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene != null:
		await _wait_until(func(): return not scene.is_dealing() and CardImpactFx.live_count == 0)
		await _refresh(scene)
		await _undo(scene)
		await _hold(scene)
	_finish()

func _refresh(scene) -> void:
	var controller: GameController = scene.controller
	controller.powers.counts["refresh"] = 1
	var deck_a_count := controller.deck_a.remaining_count()
	var deck_b_count := controller.deck_b.remaining_count()
	var zone_before := controller.zone.size()
	var board_ids: Array[String] = []
	for card in controller.board.cards:
		if not card.is_removed() and card.location == Card.Location.BOARD:
			board_ids.append(str(card.id))

	scene._on_power("refresh")
	_check(bool(scene.get("_power_animation_active")), "Refresh starts its animation")
	_check(not scene._accepts_taps(), "input is blocked during Refresh")
	if not board_ids.is_empty():
		scene._on_card(board_ids[0])
	_check(controller.zone.size() == zone_before, "a tap during Refresh cannot act on stale board nodes")
	var visibility_probe: Dictionary = await _probe_refresh_visibility(scene, controller, board_ids)
	_check(bool(visibility_probe["ok"]),
		"every Refresh card stays visible at every sampled frame (worst frame %d, width %.3f, missing=%s)" % [
			int(visibility_probe["frame"]), float(visibility_probe["worst_ratio"]), str(visibility_probe["missing"])
		])
	_check(not bool(scene.get("_power_animation_active")), "Refresh animation completes")
	_check(scene._accepts_taps(), "input is re-enabled after Refresh")
	_check(controller.deck_a.remaining_count() == deck_a_count and controller.deck_b.remaining_count() == deck_b_count,
		"Refresh keeps both support-deck counts unchanged")
	var matched_nodes := 0
	for card in controller.board.cards:
		if card.is_removed() or card.location != Card.Location.BOARD:
			continue
		var node := scene._board_nodes.get(str(card.id)) as Button
		_check(node != null, "board card %s has a rendered node" % card.id)
		if node == null:
			continue
		matched_nodes += 1
		_check(str(node.get_meta("card_type", "")) == str(card.type),
			"board card %s shows its refreshed face" % card.id)
		var expected: Rect2 = scene._board_card_rect(card)
		_check(node.get_global_rect().position.distance_to(expected.position) < 1.5,
			"board card %s ends at its refreshed position" % card.id)
		_check(node.modulate.a > 0.99, "board card %s is visible after the handoff" % card.id)
	_check(matched_nodes == board_ids.size(), "the refreshed board keeps the same card IDs")
	var audio = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("end_refresh_sound"):
		_check(bool(scene.get("_refresh_end_sound_called")), "Refresh calls end_refresh_sound after the last landing")
	var full_red_landings := _count_full_red_impacts(scene)
	_check(full_red_landings > 0 and full_red_landings <= 10,
		"Refresh caps full red impact FX at 10 visible landings (got %d)" % full_red_landings)
	await _wait_for_cleanup(scene, "Refresh")

func _probe_refresh_visibility(scene, controller: GameController, board_ids: Array[String]) -> Dictionary:
	var frame := 0
	var worst_ratio := INF
	var worst_frame := -1
	var worst_id := ""
	var missing: Array[String] = []
	while bool(scene.get("_refresh_animation_active")):
		var layer: Node = scene.find_child("FxLayer", true, false)
		var ghosts: Dictionary = {}
		if layer != null:
			for child in layer.get_children():
				if child is Node2D and child.has_meta("power_card_id"):
					ghosts[str(child.get_meta("power_card_id", ""))] = child
		if frame == 0:
			print("REFRESH PROBE first_frame active=%s layer=%s children=%d ghosts=%d" % [
				str(scene.get("_refresh_animation_active")), str(layer), layer.get_child_count() if layer != null else -1, ghosts.size()
			])
			if layer != null:
				for i in mini(12, layer.get_child_count()):
					var child := layer.get_child(i)
					print("REFRESH PROBE child=%s class=%s id=%s" % [str(child.name), child.get_class(), str(child.get_meta("power_card_id", ""))])
			for ghost_id in ghosts:
				var sample: Node2D = ghosts[ghost_id]
				var sample_face: Control = sample.get_child(0) as Control if sample.get_child_count() > 0 else null
				print("REFRESH PROBE ghost id=%s visible=%s scale=%s face=%s face_size=%s" % [ghost_id, str(sample.is_visible_in_tree()), str(sample.scale), str(sample_face), str(sample_face.size if sample_face != null else Vector2.ZERO)])
		for card_id in board_ids:
			var card: Card = controller.board.get_card(card_id)
			if card == null:
				continue
			var target: Rect2 = scene._board_card_rect(card)
			var represented := false
			var ratio := 0.0
			var node := scene._board_nodes.get(card_id) as Control
			if is_instance_valid(node) and node.is_visible_in_tree():
				var node_alpha := node.modulate.a * node.self_modulate.a
				var node_ratio := node.size.x * absf(node.scale.x) / maxf(1.0, target.size.x)
				if node_alpha > 0.9 and node_ratio > 0.15:
					represented = true
					ratio = node_ratio
			var ghost := ghosts.get(card_id) as Node2D
			if is_instance_valid(ghost) and ghost.is_visible_in_tree() and ghost.get_child_count() > 0:
				var face := ghost.get_child(0) as Control
				var ghost_alpha := ghost.modulate.a * ghost.self_modulate.a * face.modulate.a * face.self_modulate.a
				var ghost_ratio := face.size.x * absf(ghost.scale.x) / maxf(1.0, target.size.x)
				if ghost_alpha > 0.9 and ghost_ratio > 0.15:
					represented = true
					ratio = maxf(ratio, ghost_ratio)
			if not represented and not missing.has(card_id):
				missing.append(card_id)
			if ratio < worst_ratio:
				worst_ratio = ratio
				worst_frame = frame
				worst_id = card_id
		await process_frame
		frame += 1
	var ok := frame > 0 and missing.is_empty() and (worst_ratio > 0.15 or board_ids.is_empty())
	print("REFRESH VISIBILITY worst_frame=%d worst_width_ratio=%.3f card=%s missing=%s frames=%d" % [
		worst_frame, worst_ratio if worst_ratio < INF else 0.0, worst_id, str(missing), frame
	])
	return {"ok": ok, "frame": worst_frame, "worst_ratio": worst_ratio, "missing": missing}

func _undo(scene) -> void:
	var controller: GameController = scene.controller
	if controller.status != GameController.Status.PLAYING or controller.zone.size() != 0:
		return
	var selected: Card
	for action in controller.get_legal_actions():
		if action["action"] == "select_card":
			selected = controller.board.get_card(str(action["card_id"]))
			break
	if selected == null:
		_fail("Undo setup could not find a selectable board card")
		return
	controller.select_card(str(selected.id))
	controller.powers.counts["undo"] = 1
	scene.render()
	scene._on_power("undo")
	_check(await _wait_until(func(): return not bool(scene.get("_power_animation_active"))), "Undo landing animation completes")
	_check(_has_red_impact(scene), "Undo uses the red landing palette")
	_check(controller.board.get_card(str(selected.id)).location == Card.Location.BOARD,
		"Undo returns the card to its board destination")
	await _wait_for_cleanup(scene, "Undo")

func _hold(scene) -> void:
	var controller: GameController = scene.controller
	if controller.status != GameController.Status.PLAYING:
		return
	var selected_ids: Array[String] = []
	var seen_types: Dictionary = {}
	for action in controller.get_legal_actions():
		if action["action"] != "select_card":
			continue
		var card: Card = controller.board.get_card(str(action["card_id"]))
		if card == null or seen_types.has(card.type):
			continue
		seen_types[card.type] = true
		selected_ids.append(str(card.id))
		if selected_ids.size() == 3:
			break
	if selected_ids.size() < 3:
		_fail("Hold setup could not find three distinct selectable card types")
		return
	for card_id in selected_ids:
		controller.select_card(card_id)
	controller.powers.counts["hold"] = 1
	var reserve_before := controller.reserve.size()
	scene.render()
	scene._on_power("hold")
	_check(await _wait_until(func(): return not bool(scene.get("_power_animation_active"))), "Hold landing animation completes")
	_check(controller.reserve.size() == reserve_before + 3, "Hold moves the cards into Reserve")
	_check(_has_red_impact(scene), "Hold uses the red landing palette")
	await _wait_for_cleanup(scene, "Hold")

func _has_red_impact(scene) -> bool:
	var layer: Node = scene.find_child("FxLayer", true, false)
	if layer == null:
		return false
	for child in layer.get_children():
		if child is CardImpactFx and str(child.get_meta("palette", "green")) == "red":
			return true
	return false

func _count_full_red_impacts(scene) -> int:
	var layer: Node = scene.find_child("FxLayer", true, false)
	if layer == null:
		return 0
	var count := 0
	for child in layer.get_children():
		if child is CardImpactFx and str(child.get_meta("palette", "green")) == "red" and bool(child.get_meta("full", false)):
			count += 1
	return count

func _wait_for_cleanup(scene, label: String) -> void:
	await create_timer(1.5).timeout
	var clean: bool = scene.visuals_settled() and CardImpactFx.live_count == 0
	_check(clean, "%s leaves no ghosts or impact FX" % label)

func _wait_level():
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene != null and scene.name == "LevelScreen" and scene.get("controller") != null:
			return scene
	_fail("level scene did not load")
	return null

func _wait_until(condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		if condition.call():
			return true
		await process_frame
	return false

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FAIL " + message)

func _finish() -> void:
	LevelLoader.deterministic = false
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("SMOKE REFRESH OK")
		quit(0)
		return
	printerr("SMOKE REFRESH FAIL: %d problem(s)" % _failures.size())
	quit(1)
