extends SceneTree

const PROBE_SECONDS := 3.0
const PROBE_SAVE := "user://menu_frame_probe_save.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := root.get_node_or_null("Game")
	if game == null:
		printerr("MENU FRAME PROBE FAIL: Game autoload is unavailable")
		quit(1)
		return
	var original_save_path: String = game.save_path
	game.save_path = PROBE_SAVE
	_remove_probe_save()
	game.settings["orientation"] = "landscape"
	game.apply_orientation()
	root.size = Vector2i(1280, 720)
	for _frame in 4:
		await process_frame
	change_scene_to_file("res://scenes/main.tscn")
	var menu: Control
	for _frame in 180:
		await process_frame
		if current_scene != null and current_scene.name == "MainMenu":
			menu = current_scene as Control
			break
	if menu == null:
		printerr("MENU FRAME PROBE FAIL: main menu did not load")
		game.save_path = original_save_path
		_remove_probe_save()
		quit(1)
		return
	var frame_times_ms: Array[float] = []
	var started_usec := Time.get_ticks_usec()
	var last_frame_usec := started_usec
	while float(Time.get_ticks_usec() - started_usec) / 1_000_000.0 < PROBE_SECONDS:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_times_ms.append(float(now_usec - last_frame_usec) / 1000.0)
		last_frame_usec = now_usec
	frame_times_ms.sort()
	var total_ms := 0.0
	for frame_ms in frame_times_ms:
		total_ms += frame_ms
	var average_ms := total_ms / float(maxi(1, frame_times_ms.size()))
	var p95_index := clampi(int(ceil(frame_times_ms.size() * 0.95)) - 1, 0, frame_times_ms.size() - 1)
	var percentile_95 := frame_times_ms[p95_index]
	var worst_ms: float = frame_times_ms[frame_times_ms.size() - 1]
	var vsync_mode := DisplayServer.window_get_vsync_mode()
	print("MENU FRAME PROBE duration=%.2fs frames=%d avg=%.2fms (%.1f fps) p95=%.2fms worst=%.2fms max_fps=%d vsync=%d display_hz=%.1f" % [
		float(Time.get_ticks_usec() - started_usec) / 1_000_000.0,
		frame_times_ms.size(), average_ms, 1000.0 / maxf(0.001, average_ms), percentile_95, worst_ms,
		Engine.max_fps, vsync_mode, DisplayServer.screen_get_refresh_rate(),
	])
	game.save_path = original_save_path
	_remove_probe_save()
	quit(0)

func _remove_probe_save() -> void:
	for path in [PROBE_SAVE, PROBE_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
