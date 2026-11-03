extends SceneTree

# QA capture for the card impact FX (Phase M). Needs a GPU/windowed run. Writes to user://qa_shots:
#  impact_<orientation>_zone_sheet.png   one zone landing at ~0, .1, .2, .35, .6, .9 s after contact (crops, 3x)
#  impact_<orientation>_deal_sheet.png   the initial deal at a few instants (full frames, half size)
# Timings are taken from wall-clock ticks (a capture costs a few frames), so each frame is labelled
# in the log with its real offset after contact.
const OUT_DIR := "user://qa_shots"
const CASES := [
	{"tag": "portrait", "level": "6", "orientation": "portrait", "window": Vector2i(720, 1280)},
	{"tag": "landscape", "level": "6", "orientation": "landscape", "window": Vector2i(1280, 720)},
]
const ZONE_OFFSETS := [0.0, 0.1, 0.2, 0.35, 0.6, 0.9]
const DEAL_INSTANTS := [0.25, 0.55, 0.9, 1.3]
const CROP := 150

var _game
var _prev: Node
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = root.get_node_or_null("Game")
	_game.save_path = "user://qa_impact_save.json"
	LevelLoader.deterministic = true
	for case in CASES:
		await _deal(case)
		await _zone(case)
	_game.save_path = SaveManager.DEFAULT_PATH
	print("QA IMPACT DONE dir=%s" % ProjectSettings.globalize_path(OUT_DIR))
	for f in _failures:
		printerr("QA IMPACT FAIL: " + f)
	quit(0 if _failures.is_empty() else 1)

func _open(case: Dictionary):
	_game.progress = ProgressManager.new()
	_game.endless_run = null
	_game.current_level_id = str(case["level"])
	_game.settings["orientation"] = str(case["orientation"])
	_game.settings["mascot"] = true
	_game.apply_orientation()
	root.size = case["window"]
	_prev = current_scene
	change_scene_to_file("res://scenes/level.tscn")
	for i in 240:
		await process_frame
		var scene = current_scene
		if scene != null and scene != _prev and scene.name == "LevelScreen" and scene.get("controller") != null and scene.get("_dealing") != null:
			return scene
	_failures.append("level did not load")
	return null

func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _deal(case: Dictionary) -> void:
	var scene = await _open(case)
	if scene == null:
		return
	var t0 := Time.get_ticks_msec()
	var frames: Array[Image] = []
	for instant in DEAL_INSTANTS:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < instant:
			await process_frame
		var img := await _grab()
		print("QA IMPACT deal %s frame at %.2fs" % [case["tag"], float(Time.get_ticks_msec() - t0) / 1000.0])
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		frames.append(img)
	_sheet(frames, "impact_%s_deal_sheet" % case["tag"], frames.size())

func _zone(case: Dictionary) -> void:
	var scene = await _open(case)
	if scene == null:
		return
	# Let the deal and intro finish, then drop the intro overlay.
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 4800:
		await process_frame
	var overlay: Node = scene.find_child("IntroOverlay", true, false)
	if overlay != null:
		overlay.queue_free()
	await process_frame
	var c: GameController = scene.controller
	var tapped := false
	var tapped_id := ""
	for a in c.get_legal_actions():
		if a["action"] == "select_card":
			tapped_id = a["card_id"]
			scene._on_card(tapped_id)
			tapped = true
			break
	if not tapped:
		_failures.append("no card to tap")
		return
	var slot := scene._zone_child_rect(maxi(0, scene._zone_index_of(tapped_id))) as Rect2
	var xf := root.get_final_transform()
	var centre := xf * slot.get_center()
	var crop_px := int(CROP * xf.get_scale().x)
	# Slow motion: a capture costs ~100 ms of wall clock, so run the game at 1/8 speed and
	# convert; every frame then lands within ~15 ms (game time) of its wanted offset.
	const SLOW := 0.125
	Engine.time_scale = SLOW
	var tap_ms := Time.get_ticks_msec()
	var contact := float(scene.FLIGHT_SECONDS)
	var frames: Array[Image] = []
	var frames_raw: Array[Image] = []
	for offset in ZONE_OFFSETS:
		while float(Time.get_ticks_msec() - tap_ms) / 1000.0 * SLOW < contact + offset:
			await process_frame
		var img := await _grab()
		print("QA IMPACT zone %s frame at contact%+.2fs (wanted +%.2f)" % [case["tag"], float(Time.get_ticks_msec() - tap_ms) / 1000.0 * SLOW - contact, offset])
		var rect := Rect2i(Vector2i(centre) - Vector2i(crop_px / 2, int(crop_px * 0.6)), Vector2i(crop_px, crop_px))
		rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		frames_raw.append(img)
		var crop := img.get_region(rect)
		crop.resize(450, 450, Image.INTERPOLATE_BILINEAR)
		frames.append(crop)
	Engine.time_scale = 1.0
	# Pixel check: the landed card (centre region) 0.6 s after contact vs the same card once every
	# effect is gone: mean luminance must differ by < 8 % (no wash/haze left over the art).
	await _wait_s(2.0)
	var base_img := await _grab()
	var centre_rect := Rect2i(Vector2i(centre) - Vector2i(crop_px / 8, int(crop_px * 0.25)), Vector2i(crop_px / 4, crop_px / 4))
	var base_lum := luminance_of(base_img, centre_rect)
	var fx_lum := luminance_of(frames_raw[3], centre_rect)
	var delta := absf(fx_lum - base_lum) / maxf(0.001, base_lum)
	print("QA IMPACT pixel check %s: card centre luminance +0.6s=%.3f settled=%.3f delta=%.1f%%" % [case["tag"], fx_lum, base_lum, delta * 100.0])
	if delta >= 0.08:
		_failures.append("%s: card centre differs %.1f%% from the plain art at +0.6 s" % [case["tag"], delta * 100.0])
	_sheet(frames, "impact_%s_zone_sheet" % case["tag"], 3)

func _sheet(frames: Array[Image], name: String, columns: int) -> void:
	if frames.is_empty():
		return
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var rows := ceili(float(frames.size()) / float(columns))
	var sheet := Image.create(w * columns, h * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in frames.size():
		var f := frames[i]
		f.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((i % columns) * w, (i / columns) * h))
	var err := sheet.save_png("%s/%s.png" % [OUT_DIR, name])
	if err != OK:
		_failures.append("could not save " + name)
	print("QA IMPACT SHEET %s %dx%d" % [name, sheet.get_width(), sheet.get_height()])

func _wait_s(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await process_frame

static func luminance_of(img: Image, rect: Rect2i) -> float:
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var total := 0.0
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return total / maxf(1.0, float(n))
