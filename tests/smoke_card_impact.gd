extends SceneTree

# Card fall + impact FX smoke (Phase M), driven through the real level scene:
# the initial deal finishes with every board card at its exact layout position, scale 1 and
# input enabled (the timer starts after it); five rapid taps make overlapping zone landings; a
# deck draw lands too; then no FX node is left, the zone is clean and a card still works.
# Saves go to a throwaway file; the real save is never touched.

const STEP_TIMEOUT_MS := 20000
const THROWAWAY_SAVE := "user://smoke_card_impact_save.json"

var _failures: Array[String] = []
var _game

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	LevelLoader.deterministic = true
	_game = root.get_node_or_null("Game")
	if _game == null:
		_fail("Game autoload not available")
	else:
		_game.save_path = THROWAWAY_SAVE
		await _scenarios()
		change_scene_to_file("res://scenes/main.tscn")
		await create_timer(0.6).timeout
	_finish()

func _scenarios() -> void:
	_game.progress = ProgressManager.new()
	_game.endless_run = null
	_game.current_level_id = "6"
	change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_level()
	if scene == null:
		return
	var c: GameController = scene.controller

	print("card impact: initial deal")
	_check(scene._dealing, "the deal is running right after the level is built")
	_check(not c.timer.is_running(), "the gameplay timer waits for the deal")
	var started := Time.get_ticks_msec()
	var done: bool = await _wait_until(func(): return not scene._dealing)
	_check(done, "the deal finishes")
	_check(float(Time.get_ticks_msec() - started) / 1000.0 <= 2.0, "the deal takes at most ~2 s")
	_check(c.timer.is_running(), "the gameplay timer runs once the deal is over")
	await _wait_ms(450)  # the last landing's squash
	var before := {}
	for id in scene._board_nodes:
		var node := scene._board_nodes[id] as Button
		before[id] = node.position
		_check(node.scale.is_equal_approx(Vector2.ONE), "board card %s ends at scale 1 (got %s)" % [id, str(node.scale)])
		_check(is_equal_approx(node.modulate.a, 1.0), "board card %s ends opaque" % id)
		_check(node.mouse_filter == Control.MOUSE_FILTER_STOP, "board card %s accepts input after the deal" % id)
	scene.render()  # lays every card out at its layout position again
	for id in before:
		var node := scene._board_nodes[id] as Button
		_check(node.position.is_equal_approx(before[id]), "board card %s ended exactly on its layout position (%s vs %s)" % [id, str(before[id]), str(node.position)])
	await _wait_until(func(): return CardImpactFx.live_count == 0)
	_check(CardImpactFx.live_count == 0, "no deal FX is left (%d)" % CardImpactFx.live_count)

	print("card impact: five rapid taps + deck draw")
	var tapped := 0
	for a in c.get_legal_actions():
		if tapped >= 5:
			break
		if a["action"] == "select_card":
			scene._on_card(a["card_id"])
			tapped += 1
	_check(tapped == 5, "five board cards could be tapped (%d)" % tapped)
	await process_frame
	await _wait_ms(150)
	var drew := false
	for a in c.get_legal_actions():
		if a["action"] == "use_deck":
			scene._on_deck(a["deck"])
			drew = true
			break
	_check(drew or c.zone.is_full() or c.status != GameController.Status.PLAYING, "a deck card could be drawn")
	await _wait_ms(250)  # the first flights have touched down
	_check(CardImpactFx.live_count > 0 or c.status != GameController.Status.PLAYING, "landings are playing FX")
	# The art must stay readable: 150 ms after contact nothing additive may sit in FRONT of the card
	# except the thin outline rim (peak <= 0.35); the big halo lives behind it.
	var watch_until := Time.get_ticks_msec() + 1700
	var checked := 0
	while Time.get_ticks_msec() < watch_until:
		await process_frame
		var layer: Node = scene.find_child("FxLayer", true, false)
		if layer == null:
			continue
		for fx in layer.get_children():
			if not (fx is CardImpactFx) or not fx.has_meta("born_msec"):
				continue
			if Time.get_ticks_msec() - int(fx.get_meta("born_msec")) < 150:
				continue
			for node in fx.front.get_children():
				if node is Sprite2D and (node.material as CanvasItemMaterial) != null:
					checked += 1
					var alpha: float = node.modulate.a
					if node.name == "Rim":
						_check(alpha <= 0.36, "the rim stays at or below 0.35 alpha (%.2f)" % alpha)
					else:
						_check(alpha < 0.02, "no additive %s covers the card 150 ms after contact (alpha %.2f)" % [node.name, alpha])
	_check(checked > 0, "the additive-front assertion actually looked at some FX nodes")
	var settled: bool = await _wait_until(func(): return scene.visuals_settled() and CardImpactFx.live_count == 0)
	_check(settled, "no ghost / FX node is left ~1.5 s after the last landing")
	_check(scene._hidden_cards.is_empty(), "no zone slot is still hidden")
	for slot in scene.zone_container.get_children():
		_check(is_equal_approx((slot as Control).modulate.a, 1.0), "zone slots are opaque again")
	var fx_layer: Node = scene.find_child("FxLayer", true, false)
	_check(fx_layer == null or fx_layer.get_child_count() == 0, "the FX layer is empty")

	await _pixel_check(scene)

	print("card impact: input still works")
	if c.status == GameController.Status.PLAYING:
		var zone_before := c.zone.size()
		var moved := false
		for a in c.get_legal_actions():
			if a["action"] == "select_card":
				scene._on_card(a["card_id"])
				moved = true
				break
		if moved:
			_check(c.zone.size() != zone_before or c.status != GameController.Status.PLAYING or c.zone.is_full(), "a later tap still moves a card")
			await _wait_ms(1800)
			_check(CardImpactFx.live_count == 0, "FX of the last tap are gone")

# Windowed runs only (the headless renderer has no pixels): the landed card's centre at +0.6 s after
# contact must be within 8 % luminance of the same card once every effect is gone.
func _pixel_check(scene) -> void:
	if DisplayServer.get_name() == "headless":
		print("card impact: pixel check skipped (headless renderer); qa_impact_capture runs it windowed")
		return
	var c: GameController = scene.controller
	if c.status != GameController.Status.PLAYING or c.zone.is_full():
		return
	var id := ""
	for a in c.get_legal_actions():
		if a["action"] == "select_card":
			id = a["card_id"]
			scene._on_card(id)
			break
	if id == "":
		return
	var contact := float(scene.FLIGHT_SECONDS)
	await _wait_ms(int((contact + 0.6) * 1000.0))
	var rect: Rect2 = scene._zone_child_rect(maxi(0, scene._zone_index_of(id)))
	var xf := root.get_final_transform()
	var centre := xf * rect.get_center()
	var half := int(rect.size.x * xf.get_scale().x * 0.2)
	var region := Rect2i(Vector2i(centre) - Vector2i(half, half), Vector2i(half * 2, half * 2))
	await RenderingServer.frame_post_draw
	var with_fx := _luminance(root.get_texture().get_image(), region)
	await _wait_ms(1800)
	await RenderingServer.frame_post_draw
	var plain := _luminance(root.get_texture().get_image(), region)
	var delta := absf(with_fx - plain) / maxf(0.001, plain)
	_check(delta < 0.08, "card centre at +0.6 s differs %.1f%% from the plain art (limit 8%%)" % [delta * 100.0])

func _luminance(img: Image, rect: Rect2i) -> float:
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var total := 0.0
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var col := img.get_pixel(x, y)
			total += 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b
			n += 1
	return total / maxf(1.0, float(n))

func _wait_level():
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < STEP_TIMEOUT_MS:
		await process_frame
		var scene = current_scene
		if scene == null or scene.name != "LevelScreen":
			continue
		var frame := scene.find_child("BoardFrame", true, false) as Control
		if scene.get("controller") != null and frame != null and frame.size.x > 0.0:
			await process_frame
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

func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	LevelLoader.deterministic = false
	for path in [THROWAWAY_SAVE, THROWAWAY_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _game != null:
		_game.save_path = SaveManager.DEFAULT_PATH
	if _failures.is_empty():
		print("SMOKE CARD IMPACT OK")
		quit(0)
		return
	printerr("SMOKE CARD IMPACT FAIL: %d problem(s)" % _failures.size())
	for failure in _failures.slice(0, 30):
		printerr("  " + failure)
	quit(1)
