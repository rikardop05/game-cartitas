extends SceneTree

# Level smoke: the scene loads, and (Phase R) the level clock is at zero -- or at the full limit
# for a countdown level -- on the frame the player can actually play. That holds for a new level,
# the next level from the victory panel, a retry and the next Endless round.
#
# Regression it locks: the clock used to be started by GameController.start_level() while the
# screen was still building/prewarming the level (and could be re-started by a focus change during
# the deal), so every level opened with the setup seconds already counted (00:01-00:02 instead of
# 00:00) and the player could never track their own time.

const THROWAWAY_SAVE := "user://smoke_level_save.json"
const STEP_TIMEOUT_MS := 20000
# The clock may only advance by the few ms between "play starts" and the next frame we look at it.
const START_EPSILON := 0.05
# Value painted into the clock while the deal runs: nothing before the first playable frame may
# survive into the player's time.
const INJECTED_BIAS := 5.0

var _failures: Array[String] = []
var _game: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_game = root.get_node_or_null("Game")
	if _game == null:
		printerr("SMOKE FAIL: Game autoload not available")
		quit(1)
		return
	_game.save_path = THROWAWAY_SAVE
	_remove_throwaway_save()
	await _scenario()
	_game.save_path = SaveManager.DEFAULT_PATH
	_remove_throwaway_save()
	if _failures.is_empty():
		print("SMOKE OK")
		quit(0)
		return
	for failure in _failures:
		printerr("SMOKE FAIL: " + failure)
	quit(1)

func _scenario() -> void:
	LevelLoader.deterministic = true
	_game.endless_run = null
	_game.settings["orientation"] = "landscape"
	_game.apply_orientation()
	root.size = Vector2i(640, 360)

	# --- 1. A brand new level -------------------------------------------------------------
	var level_one = await _open_level("1", null, false)
	if level_one == null:
		return
	var first_clock: float = await _playable_clock(level_one)
	_check(first_clock <= START_EPSILON,
		"a new level starts its clock at zero (%.3f s at the first playable frame)" % first_clock)
	_check(_clock_text(level_one) == _expected_start_text(level_one),
		"the HUD shows the start time immediately (%s)" % _clock_text(level_one))
	_check(level_one.controller.timer.is_running(), "the clock runs once the player can play")
	_check(level_one.mascot != null and level_one.mascot.visible, "the hero is always visible")
	_check_refresh_sounds()

	# --- 2. The next level from the victory panel ------------------------------------------
	level_one.controller.status = GameController.Status.WON
	if not await _wait_until(func(): return level_one.find_child("VictoryContinue", true, false) != null):
		_fail("level 1 has no VictoryContinue button")
		return
	(level_one.find_child("VictoryContinue", true, false) as Button).pressed.emit()
	var level_two = await _open_next(level_one, true)
	if level_two == null:
		return
	_check_closed(await _playable_clock(level_two), "the next level")

	# --- 3. Retry -------------------------------------------------------------------------
	_game.restart_level()
	var retried = await _open_next(level_two, true)
	if retried == null:
		return
	_check_closed(await _playable_clock(retried), "a retry")

	# --- 4. The next Endless round --------------------------------------------------------
	_game.endless_run = null
	_game.start_endless()
	var round_one = await _open_next(retried, true)
	if round_one == null:
		return
	_check_closed(await _playable_clock(round_one), "Endless round 1")
	if round_one.get("_endless") == null:
		_fail("endless round 1 does not know the run")
		return
	round_one.controller.status = GameController.Status.WON
	if not await _wait_until(func(): return round_one.find_child("VictoryContinue", true, false) != null):
		_fail("Endless round 1 has no continue button")
		return
	(round_one.find_child("VictoryContinue", true, false) as Button).pressed.emit()
	var round_two = await _open_next(round_one, true)
	if round_two == null:
		return
	_check_closed(await _playable_clock(round_two), "Endless round 2")

# --- helpers ------------------------------------------------------------------------------

# Phase S1: Refresh plays two sounds at once (the activation one-shot plus the longer shuffle on
# its own voice) and end_refresh_sound() stops the shuffle, safely twice.
func _check_refresh_sounds() -> void:
	var audio = root.get_node_or_null("Audio")
	if audio == null:
		_fail("Audio autoload not available for the refresh sounds")
		return
	audio.play_power("refresh")
	var shuffle_player: AudioStreamPlayer = audio.get("_refresh_player")
	_check(shuffle_player != null and shuffle_player.playing, "the refresh shuffle starts on its own voice")
	if shuffle_player != null and shuffle_player.stream != null:
		_check(shuffle_player.stream.resource_path == AudioManager.REFRESH_SHUFFLE_SFX,
			"the shuffle voice plays refresh_shuffle.wav (%s)" % shuffle_player.stream.resource_path)
	var activate := 0
	for voice in audio.get("_sfx_players"):
		if voice.playing and voice.stream != null and voice.stream.resource_path == AudioManager.POWER_ACTIVATE_SFX:
			activate += 1
	_check(activate >= 1, "the refresh activation plays at the same time (%d voice)" % activate)
	audio.end_refresh_sound(0.0)
	_check(shuffle_player != null and not shuffle_player.playing, "end_refresh_sound stops the shuffle")
	audio.end_refresh_sound(0.0)
	_check(shuffle_player == null or not shuffle_player.playing, "calling end_refresh_sound twice is safe")

# Opens a level from the menu-level API and returns the ready LevelScreen.
func _open_level(level_id: String, previous, bias_while_dealing: bool):
	_game.start_level(level_id)
	return await _open_next(previous, bias_while_dealing)

# Waits for the next LevelScreen; optionally paints a bogus clock value while the deal runs, so a
# level that carries pre-play time over can never pass by luck.
func _open_next(previous, bias_while_dealing: bool):
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene == null or scene == previous or scene.name != "LevelScreen":
			continue
		if scene.get("controller") == null:
			continue
		if bias_while_dealing and scene.is_dealing():
			scene.controller.timer.set_elapsed_seconds(INJECTED_BIAS)
			return scene
		return scene
	_fail("the level scene did not load")
	return null

# Frame at which the deal is over: the player can play from here on.
func _playable_clock(scene) -> float:
	var over: bool = await _wait_until(func(): return not scene.is_dealing())
	if not over:
		_fail("the deal never finished")
		return INF
	return scene.controller.timer.elapsed_seconds()

func _clock_text(scene) -> String:
	var label: Label = scene.get("timer_label")
	return label.text if label != null else ""

func _expected_start_text(scene) -> String:
	var controller = scene.controller
	var start: float = controller.time_limit if controller.time_limit > 0.0 else 0.0
	return scene.call("_format_time", start)

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS " + message)
		return
	_fail(message)

func _check_closed(clock: float, context: String) -> void:
	_check(clock <= START_EPSILON,
		"%s starts its clock at zero (%.3f s at the first playable frame)" % [context, clock])

func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL " + message)

func _wait_until(condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		if condition.call():
			return true
		await process_frame
	return false

func _remove_throwaway_save() -> void:
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
