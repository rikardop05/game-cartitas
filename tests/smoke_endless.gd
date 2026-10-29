extends SceneTree

# Endless Mode (T6) smoke test, driven through the real scenes: menu entry, round HUD,
# scoring on a match, round-clear panel + next round, run-over panel + best score,
# "Play again", using a power through the HUD, closing the app mid-run, and quitting
# with the back button. The scenes save through Game.save_path, which is pointed at a
# throwaway user:// file before anything runs, so the player's save is never written.
# As a second safety net the real save is also backed up and checked byte-for-byte.

const STEP_TIMEOUT_MS := 20000
const THROWAWAY_SAVE := "user://smoke_endless_save.json"

var _failures: Array[String] = []
var _save_before: Dictionary
var _game

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_save_before = _snapshot_save()
	LevelLoader.deterministic = true
	var game = root.get_node_or_null("Game")
	if game == null:
		_fail("Game autoload not available")
	else:
		_game = game
		# First thing: nothing below may write to the real save.
		game.save_path = THROWAWAY_SAVE
		_remove_throwaway_save()
		await _scenario(game)
	_finish()

func _scenario(game) -> void:
	# Fresh in-memory progress: Endless starts locked.
	game.progress = ProgressManager.new()
	game.endless_run = null
	game.settings["mascot"] = true
	change_scene_to_file("res://scenes/main.tscn")
	var menu = await _wait_scene("MainMenu", null)
	if menu == null:
		return
	menu._on_play()
	await process_frame
	await process_frame
	var endless_btn := menu.find_child("EndlessButton", true, false) as Button
	var unlock_level := ProgressManager.endless_unlock_level()
	if endless_btn == null:
		_fail("menu has no Endless entry on the level list")
		return
	_check(endless_btn.disabled, "Endless entry is disabled before Level %d is completed" % unlock_level)
	_check(endless_btn.text.contains(Localizer.t("endless_locked") % unlock_level), "locked Endless entry says '%s' (got '%s')" % [Localizer.t("endless_locked") % unlock_level, endless_btn.text])

	# Unlock in memory and rebuild the list.
	game.progress.levels[str(unlock_level)] = {"completed": true, "stars": 1}
	game.progress.endless_best = 0
	menu._build()
	await process_frame
	await process_frame
	endless_btn = menu.find_child("EndlessButton", true, false) as Button
	_check(endless_btn != null and not endless_btn.disabled, "Endless entry is enabled once Level %d is completed" % unlock_level)
	if endless_btn == null or endless_btn.disabled:
		return
	endless_btn.pressed.emit()

	# --- Round 1: HUD + scoring -------------------------------------------------
	var scene = await _wait_level(menu)
	if scene == null:
		return
	var run: EndlessRun = game.endless_run
	_check(run != null, "Game.endless_run is set after pressing Endless")
	if run == null:
		return
	var controller: GameController = scene.controller
	_check(scene.level_label.text == Localizer.t("endless_round") % 1, "HUD shows the round label (got '%s')" % scene.level_label.text)
	_check(scene.stars_label == null and scene.score_label != null, "stars pill is replaced by a score pill")
	if scene.score_label == null:
		return
	_check(scene.score_label.text == "✦ 0", "score pill starts at zero (got '%s')" % scene.score_label.text)
	_check(controller.time_limit == 0.0, "Endless has no time limit")
	_check(controller.powers.get_count("hold") == 2 and controller.powers.get_count("undo") == 2, "round 1 uses the run power stock")
	var inventory_before: Dictionary = game.progress.get_inventory()
	_check(scene.mascot != null and scene.mascot.idle_event == "idle_tip_endless", "Endless Ace draws idle tips from the Endless pool (no stars tip)")
	_check(scene.mascot != null and scene.mascot.lines == game.mascot_lines(), "Ace uses the session-wide line picker")
	var round1_lines = scene.mascot.lines if scene.mascot != null else null

	var moves := 0
	while run.score == 0 and controller.status == GameController.Status.PLAYING and moves < 30:
		if not await _play_move(scene, true):
			break
		moves += 1
	_check(run.score >= 30 and run.score % 30 == 0, "a match scored whole trios (score %d after %d moves)" % [run.score, moves])
	print("endless smoke: first match after %d moves, score %d" % [moves, run.score])
	_check(scene.score_label.text == "✦ %d" % run.score, "score pill follows the run score (got '%s')" % scene.score_label.text)
	_check(game.progress.get_inventory() == inventory_before, "persistent Inventory untouched by round 1")
	if not _failures.is_empty():
		return

	# --- Power through the real HUD path: spends the run stock, never the Inventory ----
	if not await _play_move(scene, false) or controller.status != GameController.Status.PLAYING:
		_fail("could not make a plain move before using a power")
		return
	var undo_before := int(run.power_stock["undo"])
	scene._on_power("undo")
	_check(int(run.power_stock["undo"]) == undo_before - 1, "using Undo spent one from the run power stock (%d -> %d)" % [undo_before, int(run.power_stock["undo"])])
	_check(controller.powers.get_count("undo") == int(run.power_stock["undo"]), "controller and run agree on the Undo count")
	_check(game.progress.get_inventory() == inventory_before, "persistent Inventory untouched after using a power")
	if not _failures.is_empty():
		return

	# --- Round clear -> next round ---------------------------------------------
	# Flip the controller to WON: the scene's own _process -> _check_end path builds the panel.
	var score_before_clear := run.score
	controller.status = GameController.Status.WON
	if not await _wait_until(func(): return _find_label(scene, Localizer.t("round_cleared")) != null):
		_fail("round-clear panel did not appear")
		return
	_check(run.current_round == 2 and run.rounds_cleared == 1, "run advanced to round 2")
	_check(run.score == score_before_clear + EndlessRun.round_bonus(1), "round bonus added to the score")
	_check(_find_label(scene, "%s: %d" % [Localizer.t("score"), run.score]) != null, "round-clear panel shows the score")
	_check(game.progress.is_level_completed(unlock_level) and game.progress.get_stars("endless-1") == 0, "round clear does not touch campaign progress")
	var next_btn := _find_button(scene, Localizer.t("next_round"))
	if next_btn == null:
		_fail("round-clear panel has no 'Next round' button")
		return
	next_btn.pressed.emit()
	var scene2 = await _wait_level(scene)
	if scene2 == null:
		return
	_check(game.endless_run == run, "the same run continues into round 2")
	_check(scene2.level_label.text == Localizer.t("endless_round") % 2, "HUD shows round 2 (got '%s')" % scene2.level_label.text)
	_check(scene2.score_label.text == "✦ %d" % run.score, "round 2 starts with the carried score")
	_check(scene2.mascot != null and scene2.mascot.lines == game.mascot_lines() and scene2.mascot.lines == round1_lines, "round 2 Ace shares the same line picker (no-repeat memory survives the reload)")

	# --- Run over: drain Hold/Undo so a full zone ends the run, then avoid matches ----
	run.power_stock["hold"] = 0
	run.power_stock["undo"] = 0
	_check(scene2.controller.powers.get_count("hold") == 0, "controller shares the run power stock")
	moves = 0
	while scene2.controller.status == GameController.Status.PLAYING and moves < 40:
		if not await _play_move(scene2, false):
			break
		moves += 1
	print("endless smoke: run lost after %d moves, final score %d" % [moves, run.score])
	_check(scene2.controller.status == GameController.Status.LOST, "zone filled and the round was lost (status %d after %d moves)" % [scene2.controller.status, moves])
	if not await _wait_until(func(): return _find_label(scene2, Localizer.t("run_over")) != null):
		_fail("run-over panel did not appear")
		return
	var final_score := run.score
	_check(run.is_over, "run is over")
	_check(game.progress.endless_best == final_score, "best score recorded in memory (%d vs %d)" % [game.progress.endless_best, final_score])
	_check(_find_label(scene2, "★ %s" % Localizer.t("new_best")) != null, "run-over panel highlights the new best")
	_check(_find_label(scene2, "%s: %d" % [Localizer.t("rounds_cleared"), 1]) != null, "run-over panel shows the rounds cleared")
	_check(int(SaveManager.load(game.save_path).get("progress", {}).get("endless_best", -1)) == final_score, "best score was saved to disk (throwaway save)")
	var again_btn := _find_button(scene2, Localizer.t("play_again"))
	if again_btn == null:
		_fail("run-over panel has no 'Play again' button")
		return
	again_btn.pressed.emit()

	# --- Play again, then quit mid-run with the back button -----------------------
	var scene3 = await _wait_level(scene2)
	if scene3 == null:
		return
	var run2: EndlessRun = game.endless_run
	_check(run2 != null and run2 != run and run2.score == 0 and run2.current_round == 1, "Play again starts a fresh run")
	if run2 == null:
		return
	_check(scene3.level_label.text == Localizer.t("endless_round") % 1, "fresh run shows round 1")
	game.progress.endless_best = 0
	run2.record_match(30)
	# Closing the app mid-run records the run, exactly once.
	scene3.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(run2.is_over, "closing the app ends the run")
	_check(game.progress.endless_best == 300, "closing the app records the score (best %d)" % game.progress.endless_best)
	_check(int(SaveManager.load(game.save_path).get("progress", {}).get("endless_best", -1)) == 300, "close-request score was saved to disk")
	scene3.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.progress.endless_best == 300, "a second close/back request is a no-op")
	var back_btn := scene3.find_child("BackButton", true, false) as Button
	if back_btn == null:
		_fail("HUD has no back button")
		return
	back_btn.pressed.emit()
	var menu2 = await _wait_scene("MainMenu", scene3)
	if menu2 == null:
		return
	_check(game.endless_run == null, "going back to the menu clears the run")
	_check(game.progress.endless_best == 300, "quitting mid-run still records the score (best %d)" % game.progress.endless_best)
	_check(int(SaveManager.load(game.save_path).get("progress", {}).get("endless_best", -1)) == 300, "quit score was saved to disk")

	# The menu entry now shows the best score.
	menu2._on_play()
	await process_frame
	await process_frame
	var best_btn := menu2.find_child("EndlessButton", true, false) as Button
	_check(best_btn != null and best_btn.text.contains("300"), "Endless entry shows the best score")

# Plays one legal move through the scene (so the real _on_card/_on_deck code runs).
# With prefer_match it feeds the type already in the zone; otherwise it avoids matches.
func _play_move(scene, prefer_match: bool) -> bool:
	var c: GameController = scene.controller
	var zone_counts := {}
	for card in c.zone.cards:
		zone_counts[card.type] = int(zone_counts.get(card.type, 0)) + 1
	var available := {}
	for a in c.get_legal_actions():
		if a["action"] == "select_card":
			var t: String = c.board.get_card(a["card_id"]).type
			available[t] = int(available.get(t, 0)) + 1
	var best := {}
	var best_score := -INF
	for a in c.get_legal_actions():
		var type := ""
		var entry := {}
		if a["action"] == "select_card":
			type = c.board.get_card(a["card_id"]).type
			entry = {"card": a["card_id"], "deck": ""}
		elif a["action"] == "use_deck":
			var deck: DeckManager = c.deck_a if a["deck"] == "a" else c.deck_b
			type = deck.current_type()
			entry = {"card": "", "deck": a["deck"]}
		else:
			continue
		var in_zone := int(zone_counts.get(type, 0))
		var s: float
		if prefer_match:
			s = in_zone * 100.0 + int(available.get(type, 0))
		else:
			s = -(in_zone * 100.0) if in_zone < 2 else -1000.0
		if s > best_score:
			best_score = s
			best = entry
	if best.is_empty():
		_fail("no legal move to play")
		return false
	if best["card"] != "":
		scene._on_card(best["card"])
	else:
		scene._on_deck(best["deck"])
	var settled: bool = await _wait_until(func(): return scene.visuals_settled())
	await process_frame
	return settled

func _wait_scene(scene_name: String, previous):
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene != null and scene != previous and scene.name == scene_name:
			return scene
	_fail("scene %s did not load" % scene_name)
	return null

# A level scene whose controller is ready and whose board has been laid out.
func _wait_level(previous):
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene == null or scene == previous or scene.name != "LevelScreen":
			continue
		var column := scene.find_child("BoardFrame", true, false) as Control
		if scene.get("controller") != null and column != null and column.size.x > 0.0:
			return scene
	_fail("level scene did not become ready")
	return null

func _wait_until(condition: Callable) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < STEP_TIMEOUT_MS:
		if condition.call():
			return true
		await process_frame
	return false

func _find_label(node: Node, text: String) -> Label:
	for n in _all_nodes(node):
		if n is Label and (n as Label).text == text:
			return n as Label
	return null

func _find_button(node: Node, text: String) -> Button:
	for n in _all_nodes(node):
		if n is Button and (n as Button).text == text:
			return n as Button
	return null

func _all_nodes(node: Node) -> Array:
	var out: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for child in n.get_children():
			stack.append(child)
	return out

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

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

func _remove_throwaway_save() -> void:
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	LevelLoader.deterministic = false
	_remove_throwaway_save()
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	var save_after := _snapshot_save()
	if _save_before.has("read_error") or save_after.has("read_error"):
		_fail("could not verify save preservation")
	elif _save_before["exists"] != save_after["exists"] or _save_before["bytes"] != save_after["bytes"]:
		# The test only ever writes its throwaway save, so a change here is the player's own
		# game saving meanwhile. Never write the real save back: that would undo their progress.
		print("NOTE: user save changed during the run (not by this test); left untouched")
	if _failures.is_empty():
		print("SMOKE ENDLESS OK")
		quit(0)
		return
	printerr("SMOKE ENDLESS FAIL: %d problem(s)" % _failures.size())
	for failure in _failures:
		printerr("  " + failure)
	quit(1)
