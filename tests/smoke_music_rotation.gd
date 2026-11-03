extends SceneTree

# Gameplay music must survive Level/victory/retry scene changes. It only changes when a track
# finishes or the player switches between the menu and gameplay; all state is isolated to a
# throwaway save so this smoke never alters the player's progress or music bag.

const THROWAWAY_SAVE := "user://smoke_music_rotation_save.json"
const STEP_TIMEOUT_MS := 20000
const POSITION_ADVANCE_SECONDS := 0.3
const POSITION_EPSILON := 0.04

var _failures: Array[String] = []
var _save_before: Dictionary
var _game: Node
var _audio: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_save_before = _snapshot_save()
	_game = root.get_node_or_null("Game")
	_audio = root.get_node_or_null("Audio")
	if _game == null or _audio == null:
		_fail("Game or Audio autoload unavailable")
		_finish()
		return
	_game.save_path = THROWAWAY_SAVE
	_remove_throwaway_save()
	_game.progress = ProgressManager.new()
	_game.endless_run = null
	# Start this run from a clean, persisted bag; the Audio autoload itself remains alive.
	_game.settings[AudioManager.MUSIC_BAG_SETTING] = []
	_game.settings[AudioManager.LAST_GAMEPLAY_TRACK_SETTING] = ""
	_game.settings.erase(AudioManager.ROTATION_SETTING)
	_audio.call("_restore_music_state")
	await _scenario()
	_finish()

func _scenario() -> void:
	_audio.play_menu()
	change_scene_to_file("res://scenes/main.tscn")
	var menu = await _wait_scene("MainMenu", null)
	if menu == null:
		return
	_check(_audio.current_track_path() == AudioManager.MENU_TRACK, "menu starts Beyond the Walls")
	var menu_player := _audio.active_music_player() as AudioStreamPlayer
	_check(menu_player != null and menu_player.playing, "menu track player is active")
	if menu_player == null:
		return
	await _wait_seconds(POSITION_ADVANCE_SECONDS)
	var menu_position := menu_player.get_playback_position()
	await _wait_seconds(POSITION_ADVANCE_SECONDS)
	_check(menu_player.get_playback_position() > menu_position + POSITION_EPSILON,
		"menu loop advances its playback position")

	_game.start_level("1")
	var level_one = await _wait_level(menu)
	if level_one == null:
		return
	var gameplay_track: String = _audio.current_track_path()
	var gameplay_player_index := int(_audio.get("_active"))
	var gameplay_player := _audio.active_music_player() as AudioStreamPlayer
	_check(AudioManager.GAMEPLAY_TRACKS.has(gameplay_track), "Level 1 starts one track from the gameplay bag")
	_check(gameplay_track != AudioManager.MENU_TRACK, "gameplay crossfades away from the menu track")
	_check(bool(_audio.get("_gameplay_active")), "Audio autoload owns gameplay music independently of the Level scene")
	_check(gameplay_player != null and gameplay_player.playing, "gameplay player is active")
	_check(_saved_music_state_is_valid(gameplay_track), "the selected track and remaining bag are persisted")
	if gameplay_player == null:
		return
	await _wait_seconds(POSITION_ADVANCE_SECONDS)
	var before_level_win := gameplay_player.get_playback_position()

	level_one.controller.status = GameController.Status.WON
	if not await _wait_until(func(): return level_one.find_child("VictoryContinue", true, false) != null):
		_fail("Level 1 victory panel did not appear")
		return
	_check(_game.progress.is_level_completed("1"), "winning Level 1 records its progress before Level 2")
	var next_level_button := level_one.find_child("VictoryContinue", true, false) as Button
	if next_level_button == null:
		_fail("Level 1 victory has no Next Level button")
		return
	next_level_button.pressed.emit()
	var level_two = await _wait_level(level_one)
	if level_two == null:
		return
	var level_win_continuity := await _assert_continuity(
		gameplay_track, gameplay_player_index, gameplay_player, before_level_win, "Level 1 win -> Level 2")
	_check(level_win_continuity, "gameplay music continues unchanged after a Level win")
	var before_retry := gameplay_player.get_playback_position()

	_game.restart_level()
	var level_two_retry = await _wait_level(level_two)
	if level_two_retry == null:
		return
	var retry_continuity := await _assert_continuity(
		gameplay_track, gameplay_player_index, gameplay_player, before_retry, "Level 2 retry")
	_check(retry_continuity, "gameplay music continues unchanged across retry")

	level_two_retry.controller.status = GameController.Status.LOST
	if not await _wait_until(func(): return level_two_retry.find_child("DefeatRetry", true, false) != null):
		_fail("Level 2 defeat panel did not appear")
		return
	var defeat_retry := level_two_retry.find_child("DefeatRetry", true, false) as Button
	if defeat_retry == null:
		_fail("defeat panel has no retry button")
		return
	var before_defeat_retry := gameplay_player.get_playback_position()
	defeat_retry.pressed.emit()
	var level_two_after_defeat = await _wait_level(level_two_retry)
	if level_two_after_defeat == null:
		return
	var defeat_retry_continuity := await _assert_continuity(
		gameplay_track, gameplay_player_index, gameplay_player, before_defeat_retry, "defeat -> retry")
	_check(defeat_retry_continuity, "gameplay music continues unchanged across defeat and retry")

	var level_back := level_two_after_defeat.find_child("BackButton", true, false) as Button
	if level_back == null:
		_fail("Level HUD has no BackButton")
		return
	level_back.pressed.emit()
	var menu_after_game = await _wait_scene("MainMenu", level_two_after_defeat)
	if menu_after_game == null:
		return
	_check(_audio.current_track_path() == AudioManager.MENU_TRACK, "returning to the menu crossfades to Beyond the Walls")
	var menu_player_after_game := _audio.active_music_player() as AudioStreamPlayer
	_check(menu_player_after_game != null and menu_player_after_game.playing,
		"menu player starts after the gameplay-to-menu transition")
	await _wait_seconds(POSITION_ADVANCE_SECONDS)
	if menu_player_after_game != null:
		_check(menu_player_after_game.get_playback_position() > 0.05,
			"menu track starts at its own playback position")

	_game.start_level("1")
	var level_after_menu = await _wait_level(menu_after_game)
	if level_after_menu == null:
		return
	var gameplay_after_menu: String = _audio.current_track_path()
	_check(AudioManager.GAMEPLAY_TRACKS.has(gameplay_after_menu), "returning from menu starts a gameplay track")
	_check(gameplay_after_menu != AudioManager.MENU_TRACK, "menu-to-game crossfade replaces the menu track")
	_check(bool(_audio.get("_gameplay_active")), "gameplay mode is active after the menu transition")
	_check(_saved_music_state_is_valid(gameplay_after_menu), "the resumed shuffle-bag state persists")

func _assert_continuity(track: String, player_index: int, player: AudioStreamPlayer, old_position: float, context: String) -> bool:
	if not _check(_audio.current_track_path() == track, "%s keeps the same track" % context):
		return false
	if not _check(int(_audio.get("_active")) == player_index and _audio.active_music_player() == player,
			"%s keeps the same AudioStreamPlayer" % context):
		return false
	if not _check(player.playing, "%s keeps the player running" % context):
		return false
	await _wait_seconds(POSITION_ADVANCE_SECONDS)
	return _check(player.get_playback_position() > old_position + POSITION_EPSILON,
		"%s advances the same player's playback position (%.3f -> %.3f)" % [
			context, old_position, player.get_playback_position(),
		])

func _saved_music_state_is_valid(expected_track: String) -> bool:
	var saved := SaveManager.load(THROWAWAY_SAVE)
	var settings: Dictionary = saved.get("settings", {})
	var bag: Array = settings.get(AudioManager.MUSIC_BAG_SETTING, [])
	return str(settings.get(AudioManager.LAST_GAMEPLAY_TRACK_SETTING, "")) == expected_track \
		and not bag.has(expected_track) \
		and bag.size() <= AudioManager.GAMEPLAY_TRACKS.size() - 1

func _wait_scene(scene_name: String, previous):
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene != null and scene != previous and scene.name == scene_name:
			return scene
	_fail("scene %s did not load" % scene_name)
	return null

func _wait_level(previous):
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene == null or scene == previous or scene.name != "LevelScreen":
			continue
		if scene.get("controller") != null:
			return scene
	_fail("LevelScreen did not load")
	return null

func _wait_until(condition: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < STEP_TIMEOUT_MS:
		if condition.call():
			return true
		await process_frame
	return false

func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _check(ok: bool, message: String) -> bool:
	if ok:
		print("PASS " + message)
		return true
	_fail(message)
	return false

func _fail(message: String) -> void:
	_failures.append(message)

func _snapshot_save() -> Dictionary:
	var exists := FileAccess.file_exists(SaveManager.DEFAULT_PATH)
	var bytes := PackedByteArray()
	if exists:
		var file := FileAccess.open(SaveManager.DEFAULT_PATH, FileAccess.READ)
		if file == null:
			return {"exists": true, "bytes": bytes, "read_error": FileAccess.get_open_error()}
		bytes = file.get_buffer(file.get_length())
	return {"exists": exists, "bytes": bytes}

func _remove_throwaway_save() -> void:
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	_remove_throwaway_save()
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	var after := _snapshot_save()
	if _save_before.has("read_error") or after.has("read_error"):
		_fail("could not verify save preservation")
	elif _save_before["exists"] != after["exists"] or _save_before["bytes"] != after["bytes"]:
		_fail("the real save changed during the test")
	if _failures.is_empty():
		print("SMOKE MUSIC CONTINUITY OK")
		quit(0)
		return
	for failure in _failures:
		printerr("SMOKE MUSIC CONTINUITY FAIL: " + failure)
	quit(1)
