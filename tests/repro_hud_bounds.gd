extends SceneTree

# Deterministic full-scene repro for HUD/container overflow in both canonical
# mobile viewports. Read-only: loads Level 6 with its fixed profile seed, then
# Endless round 1 (seeded by the round number under LevelLoader.deterministic),
# and verifies the save file is byte-identical before/after the run.
#
# Layout contract (see LevelScreen): the screen is a "Layout" of kit pieces at fixed
# positions: Hud (back chevron, title, clock plate + stopwatch badge, stars plaque or
# score plate, help, settings gear, sound toggle),
# BoardFrame (darkened window + Board), DeckA / DeckB (kit slots), Reserve, ClearingZone and
# Powers, plus MascotArea (a spacer). Landscape follows the owner's mockup (positions are
# asserted below), portrait stacks the same pieces. The regions never overlap, blocked
# cards are dimmed by depth, and the instruction bubble (Ace's, or the standalone one
# when the mascot is off) stays clear of the cards and the controls.

const LEVEL_ID := "6"
const EPSILON := 0.01
const COMMON_REQUIRED := ["Layout", "Hud", "BoardFrame", "DeckA", "DeckB", "Reserve", "ClearingZone", "Powers", "MascotArea", "BackButton", "HelpButton", "SettingsButton", "SoundButton", "ClockPill", "Stopwatch"]
const LANDSCAPE_EXTRA := []
const PORTRAIT_EXTRA := []
# Regions that must never overlap each other (MascotArea is a spacer; the mascot has its own checks).
const DISJOINT_REGIONS := ["Hud", "BoardFrame", "DeckA", "DeckB", "ClearingZone", "Reserve", "Powers"]
# Where each kit piece sits (global px): the owner's mockup in landscape, the stacked layout in portrait.
const EXPECTED_RECTS := {
	"landscape": {
		"BoardFrame": Rect2(96, 62, 464, 208), "Powers": Rect2(571, 62, 64, 128),
		"DeckA": Rect2(18, 201, 64, 64), "DeckB": Rect2(571, 201, 64, 64),
		"Reserve": Rect2(18, 280, 148, 56), "ClearingZone": Rect2(172, 280, 464, 64),
		"ClockPill": Rect2(241, 14, 64, 32), "BackButton": Rect2(19, 11, 32, 30),
	},
	"portrait": {
		"BoardFrame": Rect2(4, 46, 352, 192), "Powers": Rect2(4, 396, 352, 64),
		"DeckA": Rect2(4, 248, 64, 64), "DeckB": Rect2(292, 248, 64, 64),
		"Reserve": Rect2(74, 248, 212, 64), "ClearingZone": Rect2(4, 322, 352, 64),
	},
}
const BUBBLE_WAIT_MS := 3500
const THROWAWAY_SAVE := "user://repro_hud_bounds_save.json"
const VIEWS := [
	{"name": "landscape-640x360", "orientation": "landscape", "window": Vector2i(640, 360), "extra": LANDSCAPE_EXTRA, "endless": false, "mascot": true},
	{"name": "portrait-360x640", "orientation": "portrait", "window": Vector2i(360, 640), "extra": PORTRAIT_EXTRA, "endless": false, "mascot": true},
	{"name": "endless-landscape-640x360", "orientation": "landscape", "window": Vector2i(640, 360), "extra": LANDSCAPE_EXTRA, "endless": true, "mascot": true},
	{"name": "endless-portrait-360x640", "orientation": "portrait", "window": Vector2i(360, 640), "extra": PORTRAIT_EXTRA, "endless": true, "mascot": true},
	# Mascot off in Options: a standalone bubble takes Ace's place.
	{"name": "nomascot-landscape-640x360", "orientation": "landscape", "window": Vector2i(640, 360), "extra": LANDSCAPE_EXTRA, "endless": false, "mascot": false},
	{"name": "nomascot-portrait-360x640", "orientation": "portrait", "window": Vector2i(360, 640), "extra": PORTRAIT_EXTRA, "endless": false, "mascot": false},
]

var _failures: Array[String] = []
var _failure_keys := {}
var _save_before: Dictionary
var _view_name := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	LevelLoader.deterministic = true
	_save_before = _snapshot_save()
	var game = root.get_node_or_null("Game")
	if game == null:
		_fail("infrastructure", "Game autoload missing")
		_finish()
		return
	var mascot_before: bool = bool(game.settings.get("mascot", true))
	var sound_before: bool = bool(game.settings.get("sound", true))
	var save_path_before: String = game.save_path
	# Powers and the sound toggle persist through Game.save_path: keep them off the real save.
	game.save_path = THROWAWAY_SAVE
	for view in VIEWS:
		await _run_view(game, view)
	# In-memory only (never set_mascot(), which would persist to the user save).
	game.settings["mascot"] = mascot_before
	game.settings["sound"] = sound_before
	game.save_path = save_path_before
	if FileAccess.file_exists(THROWAWAY_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(THROWAWAY_SAVE))
	_finish()

func _run_view(game, view: Dictionary) -> void:
	_view_name = str(view["name"])
	var required: Array = COMMON_REQUIRED + view["extra"]
	var landscape: bool = view["orientation"] == "landscape"
	# Do not call Game.set_orientation(): it persists settings to the user save.
	game.settings["orientation"] = view["orientation"]
	game.settings["mascot"] = bool(view["mascot"])
	game.apply_orientation()
	root.size = view["window"]
	for i in 3:
		await process_frame

	var endless: bool = view["endless"]
	if endless:
		game.start_endless()
	else:
		game.endless_run = null
		game.current_level_id = LEVEL_ID
		change_scene_to_file("res://scenes/level.tscn")
	var scene = await _wait_for_level_scene()
	if scene == null:
		_fail("infrastructure", "LevelScreen did not become ready")
		return

	var nodes := _required_nodes(scene, required)
	if nodes.size() != required.size():
		return
	var stable_frames := await _wait_for_stable_layout(scene, required)
	if stable_frames < 3:
		_fail("infrastructure", "HUD layout did not stabilize")

	var viewport_bounds := Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
	var controller = scene.get("controller")
	var board := scene.find_child("Board", true, false) as Control
	if endless:
		_verify_endless_round(game, scene, controller, board)
	else:
		_verify_deterministic_seed(controller, board)

	print("HUD BOUNDS REPRO view=%s level=%s viewport=%s stable_frames=%d" % [
		_view_name, "endless-1" if endless else LEVEL_ID, str(viewport_bounds), stable_frames,
	])

	# Exact hierarchy contracts: every piece sits inside the Layout, the Board inside its window.
	for node_name in required:
		if node_name != "Layout":
			_assert_inside(nodes[node_name], nodes["Layout"].get_global_rect(), "container:%s-in-Layout" % node_name)
	_assert_inside(board, nodes["BoardFrame"].get_global_rect(), "container:Board-in-BoardFrame")
	for node_name in EXPECTED_RECTS[view["orientation"]]:
		var expected: Rect2 = EXPECTED_RECTS[view["orientation"]][node_name]
		var actual: Rect2 = nodes[node_name].get_global_rect()
		if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
			_fail("position:%s" % node_name, "rect=%s expected=%s" % [str(actual), str(expected)])
	_assert_regions_disjoint(nodes)
	_assert_top_bar(nodes, landscape, endless)
	_assert_sound_toggle(game, scene, nodes["SoundButton"])

	# Every visible Control under the HUD must stay inside the viewport. This is
	# the user-visible bottom-clipping invariant, independent of parent layout.
	_audit_viewport_descendants(nodes["Layout"], viewport_bounds, scene)
	_audit_clip_ancestors(nodes["Layout"], scene)

	# Relevant visual groups must also contain their own descendants.
	for owner_name in ["BoardFrame", "DeckA", "DeckB", "Reserve", "ClearingZone", "Powers", "Hud"]:
		var owner: Control = nodes[owner_name]
		_audit_subtree_against(owner, owner.get_global_rect(), "visual-vs-%s" % owner_name, scene, false)

	if scene.find_child("InstructionOverlay", true, false) != null:
		_fail("instruction", "the instruction strip over the cards (InstructionOverlay) is back")
	_assert_blocked_cards_dimmed(scene, controller)

	var zone := scene.get("zone_container") as Control
	_assert_zone_single_row(zone, scene)
	_assert_action_button(scene.get("deck_a_btn") as Button, "deck_a_btn", viewport_bounds, nodes["Layout"], scene)
	_assert_action_button(scene.get("deck_b_btn") as Button, "deck_b_btn", viewport_bounds, nodes["Layout"], scene)
	var power_buttons: Dictionary = scene.get("power_buttons")
	for power_name in PowerManager.POWERS:
		_assert_action_button(power_buttons.get(power_name) as Button, "power:%s" % power_name, viewport_bounds, nodes["Layout"], scene)
	await _assert_instruction_bubble(scene, nodes, bool(view["mascot"]), viewport_bounds)

# The top bar: chevron at the left, the title, the clock plate with the stopwatch badge stuck on
# its left end, the stars plaque (campaign) or score plate (Endless), then help, the settings
# gear and the sound toggle, all inside the Hud, in that order and without touching each other.
func _assert_top_bar(nodes: Dictionary, landscape: bool, endless: bool) -> void:
	var hud: Rect2 = nodes["Hud"].get_global_rect()
	var back: Rect2 = nodes["BackButton"].get_global_rect()
	var title: Rect2 = nodes["Hud"].find_child("Title", true, false).get_global_rect()
	var clock: Rect2 = nodes["ClockPill"].get_global_rect()
	var stopwatch: Rect2 = nodes["Stopwatch"].get_global_rect()
	var help: Rect2 = nodes["HelpButton"].get_global_rect()
	var gear: Rect2 = nodes["SettingsButton"].get_global_rect()
	var sound: Rect2 = nodes["SoundButton"].get_global_rect()
	var second := nodes["Hud"].find_child("StarsPill", true, false) as Control
	if second == null:
		second = nodes["Hud"].find_child("ScorePill", true, false) as Control
	if second == null:
		_fail("hud", "second plate (StarsPill/ScorePill) missing")
		return
	var plate: Rect2 = second.get_global_rect()
	# The badge is part of the clock: its left edge starts the clock group.
	var clock_group := clock.merge(stopwatch)
	var row := [["back", back], ["title", title], ["stopwatch+clock", clock_group], ["second plate", plate], ["help", help], ["gear", gear], ["sound", sound]]
	for item in row:
		if _max_overflow(_overflow(item[1], hud)) > EPSILON:
			_fail("hud-in-bar", "%s %s is outside the Hud %s" % [item[0], str(item[1]), str(hud)])
	for i in row.size() - 1:
		if row[i][1].end.x > row[i + 1][1].position.x + EPSILON:
			_fail("hud-order", "%s %s overlaps or follows %s %s" % [row[i][0], str(row[i][1]), row[i + 1][0], str(row[i + 1][1])])
	# The plates sit side by side in the middle of the bar (the clock plate itself, not the badge).
	var middle := (clock.position.x + plate.end.x) * 0.5
	var viewport_middle := hud.size.x * 0.5
	if absf(middle - viewport_middle) > (16.0 if landscape else 2.0):
		_fail("hud-centre", "plates are centred on x=%.1f, the screen on x=%.1f" % [middle, viewport_middle])
	# Stopwatch: a 30-34 px tall badge centred on the plate, its right part over the plate's left edge.
	if stopwatch.size.y < 30.0 or stopwatch.size.y > 34.0:
		_fail("stopwatch", "badge height %.1f is not 30-34 px" % stopwatch.size.y)
	if absf(stopwatch.get_center().y - clock.get_center().y) > 1.0:
		_fail("stopwatch", "badge %s is not centred vertically on the plate %s" % [str(stopwatch), str(clock)])
	if not (stopwatch.position.x < clock.position.x and stopwatch.end.x > clock.position.x + 8.0 and stopwatch.end.x < clock.end.x):
		_fail("stopwatch", "badge %s does not overlap the plate's left end %s" % [str(stopwatch), str(clock)])
	# The time text stays fully readable: inside the plate, clear of the badge.
	var label := nodes["ClockPill"].get_child(0) as Label
	var text_rect := label.get_global_rect()
	var text_width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	var text_left := text_rect.get_center().x - text_width * 0.5
	var text_right := text_rect.get_center().x + text_width * 0.5
	if text_left < stopwatch.end.x - 1.0 or text_right > clock.end.x:
		_fail("stopwatch", "the time text (%.1f-%.1f) is covered by the badge (ends %.1f) or leaves the plate (ends %.1f)" % [text_left, text_right, stopwatch.end.x, clock.end.x])
	# Campaign plaque: the art's aspect ratio (1024x409), 90x36 in landscape and 70x28 in portrait.
	if not endless:
		var expected := Vector2(90, 36) if landscape else Vector2(70, 28)
		if not plate.size.is_equal_approx(expected):
			_fail("plaque", "stars plaque is %s, expected %s" % [str(plate.size), str(expected)])
		if absf(plate.size.x / plate.size.y - 1024.0 / 409.0) > 0.08:
			_fail("plaque", "stars plaque %s is not in the art's 1024:409 ratio" % str(plate.size))
	# The gear has the sound toggle's footprint and is drawn like the other painted art.
	if not gear.size.is_equal_approx(sound.size):
		_fail("gear", "gear %s and sound toggle %s differ in size" % [str(gear.size), str(sound.size)])
	var gear_icon := nodes["SettingsButton"].get_node_or_null("Icon") as TextureRect
	if gear_icon == null or gear_icon.texture == null or gear_icon.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		_fail("gear", "the gear icon is missing or not drawn with mipmaps + trilinear filtering")

# The sound toggle flips Game.sound_enabled() and its icon, and no sound is made while it is off.
func _assert_sound_toggle(game, scene, button: Button) -> void:
	if button.get_signal_connection_list(&"pressed").is_empty():
		_fail("sound", "SoundButton has no pressed connection")
		return
	var icon := button.get_node_or_null("Icon") as TextureRect
	if icon == null:
		_fail("sound", "SoundButton has no Icon")
		return
	var was_on: bool = game.sound_enabled()
	var texture_before := icon.texture
	button.pressed.emit()
	if game.sound_enabled() == was_on:
		_fail("sound", "pressing the toggle did not change Game.sound_enabled()")
	if icon.texture == texture_before:
		_fail("sound", "the icon did not change with the toggle")
	game.set_sound(false)
	scene.set("_sfx_player", null)
	scene.call("_play_sfx", "select")
	if scene.get("_sfx_player") != null:
		_fail("sound", "_play_sfx played with the sound off")
	game.set_sound(true)
	scene.call("_play_sfx", "select")
	if scene.get("_sfx_player") == null:
		_fail("sound", "_play_sfx did not play with the sound on")
	# The view starts with the sound as it found it.
	game.set_sound(was_on)
	icon.texture = scene.call("_sound_texture")

# The main layout regions are laid side by side or stacked: no two may share any area.
func _assert_regions_disjoint(nodes: Dictionary) -> void:
	for i in DISJOINT_REGIONS.size():
		for j in range(i + 1, DISJOINT_REGIONS.size()):
			var a: Rect2 = nodes[DISJOINT_REGIONS[i]].get_global_rect()
			var b: Rect2 = nodes[DISJOINT_REGIONS[j]].get_global_rect()
			if a.grow(-EPSILON).intersects(b.grow(-EPSILON)):
				_fail("overlap", "%s %s overlaps %s %s" % [DISJOINT_REGIONS[i], str(a), DISJOINT_REGIONS[j], str(b)])

# Blocked cards are dimmed (shader material) and darker the deeper they sit; available
# cards are untouched. Depth comes from the screen itself, the brightness from its table.
func _assert_blocked_cards_dimmed(scene, controller) -> void:
	var board := scene.find_child("Board", true, false) as Control
	if board == null or controller == null:
		return
	var depths: Dictionary = scene.call("_blocked_depths")
	var cards: Array = []
	for card in controller.board.cards:
		if not card.is_removed() and card.location == Card.Location.BOARD:
			cards.append(card)
	cards.sort_custom(func(a, b): return a.layer < b.layer)
	if cards.size() != board.get_child_count():
		_fail("dim", "board has %d nodes for %d cards" % [board.get_child_count(), cards.size()])
		return
	var brightness_by_depth := {}
	var blocked := 0
	for i in cards.size():
		var node := board.get_child(i) as Button
		var face := node.get_child(0) as Control
		var depth: int = int(depths.get(cards[i].id, 0))
		var available: bool = cards[i].state == Card.State.AVAILABLE
		if available != (depth == 0):
			_fail("dim", "card %s available=%s but depth=%d" % [cards[i].id, str(available), depth])
		if depth == 0:
			if face.material != null or node.disabled:
				_fail("dim", "available card %s is dimmed or disabled" % cards[i].id)
			continue
		blocked += 1
		if not node.disabled:
			_fail("dim", "blocked card %s is clickable" % cards[i].id)
		var material := face.material as ShaderMaterial
		if material == null:
			_fail("dim", "blocked card %s (depth %d) has no dim material" % [cards[i].id, depth])
			continue
		brightness_by_depth[depth] = float(material.get_shader_parameter("brightness"))
	var previous := 1.0
	var depth_keys: Array = brightness_by_depth.keys()
	depth_keys.sort()
	for depth in depth_keys:
		var brightness: float = brightness_by_depth[depth]
		if brightness >= previous or brightness > 0.5:
			_fail("dim", "depth %d brightness %.2f is not darker than the shallower depths (%.2f)" % [depth, brightness, previous])
		previous = brightness
	print("  dim check: %d blocked card(s), brightness by depth %s" % [blocked, str(brightness_by_depth)])

# Instruction line at level/round start: Ace's bubble (or the standalone one with the mascot
# off) must show up, stay inside the viewport and keep clear of the board, the powers, the
# decks, the Reserve, the Clearing Zone, the HUD and Ace itself.
func _assert_instruction_bubble(scene, nodes: Dictionary, mascot_on: bool, viewport_bounds: Rect2) -> void:
	var mascot = scene.get("mascot")
	if mascot_on != (mascot != null):
		_fail("mascot", "mascot presence %s does not follow the Options toggle (%s)" % [str(mascot != null), str(mascot_on)])
		return
	var bubble := Rect2()
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < BUBBLE_WAIT_MS:
		await process_frame
		var rect := Rect2()
		if mascot != null:
			rect = mascot.bubble_global_rect()
		else:
			var standalone := scene.find_child("InstructionBubble", true, false) as Control
			if standalone != null and standalone.modulate.a >= 0.99:
				rect = standalone.get_global_rect()
		if rect.has_area() and rect.size.y > 14.0:
			bubble = rect
			await process_frame
			break
	if not bubble.has_area():
		_fail("bubble", "the instruction bubble never appeared")
		return
	var inner := viewport_bounds.grow(-2.0)
	if _max_overflow(_overflow(bubble, inner)) > EPSILON:
		_fail("bubble-viewport", "bubble=%s viewport=%s" % [str(bubble), str(viewport_bounds)])
	var avoid := {}
	for region in ["Hud", "BoardFrame", "Powers", "Reserve", "ClearingZone"]:
		avoid[region] = nodes[region].get_global_rect()
	avoid["deck_a"] = (scene.get("deck_a_btn") as Control).get_global_rect()
	avoid["deck_b"] = (scene.get("deck_b_btn") as Control).get_global_rect()
	if mascot != null:
		avoid["mascot"] = Rect2(mascot.global_position, mascot.size)
	for key in avoid:
		if bubble.intersects(avoid[key]):
			_fail("bubble-overlap", "bubble %s overlaps %s %s" % [str(bubble), key, str(avoid[key])])
	if mascot != null:
		var ace := Rect2(mascot.global_position, mascot.size)
		for key in ["BoardFrame", "Powers", "Reserve", "ClearingZone", "Hud"]:
			if ace.intersects(nodes[key].get_global_rect()):
				_fail("mascot-overlap", "mascot %s overlaps %s %s" % [str(ace), key, str(nodes[key].get_global_rect())])
		for deck in ["deck_a_btn", "deck_b_btn"]:
			if ace.intersects((scene.get(deck) as Control).get_global_rect()):
				_fail("mascot-overlap", "mascot %s overlaps %s" % [str(ace), deck])

func _wait_for_level_scene():
	for i in 60:
		await process_frame
		var scene = current_scene
		if scene == null or scene.name != "LevelScreen":
			continue
		var controller = scene.get("controller")
		var layout := scene.find_child("Layout", true, false) as Control
		var frame := scene.find_child("BoardFrame", true, false) as Control
		if controller != null and layout != null and frame != null and frame.size.x > 0.0:
			return scene
	return null

func _wait_for_stable_layout(scene, required: Array) -> int:
	var previous := ""
	var consecutive := 0
	for i in 60:
		await process_frame
		var current := _layout_signature(scene, required)
		if current == previous and current != "":
			consecutive += 1
		else:
			consecutive = 0
			previous = current
		if consecutive >= 3:
			return consecutive
	return consecutive

func _layout_signature(scene, required: Array) -> String:
	var parts: Array[String] = []
	for node_name in required:
		var node := scene.find_child(node_name, true, false) as Control
		if node == null:
			return ""
		var rect := node.get_global_rect()
		parts.append("%s:%.3f,%.3f,%.3f,%.3f" % [node_name, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	return "|".join(parts)

func _required_nodes(scene, required: Array) -> Dictionary:
	var out := {}
	for node_name in required:
		var node := scene.find_child(node_name, true, false) as Control
		if node == null:
			_fail("infrastructure", "required Control missing: %s" % node_name)
		else:
			out[node_name] = node
	return out

func _verify_deterministic_seed(controller, board: Control) -> void:
	# Level 6 opts out of per-attempt randomization, so two loads at the same
	# board size must agree with each other and with the scene's board.
	if controller == null or board == null:
		_fail("infrastructure", "controller or Board missing")
		return
	var resolved: Dictionary = LevelLoader.load_level(LEVEL_ID, board.size)
	var again: Dictionary = LevelLoader.load_level(LEVEL_ID, board.size)
	if resolved.has("error") or again.has("error"):
		_fail("infrastructure", "fixed-seed load failed: %s" % str(resolved.get("error", again.get("error"))))
		return
	var seed_used := int(resolved.get("generation_metrics", {}).get("seed_used", -1))
	var seed_again := int(again.get("generation_metrics", {}).get("seed_used", -2))
	if seed_used != seed_again:
		_fail("infrastructure", "non-deterministic seed: %d vs %d" % [seed_used, seed_again])
	if not _same_board(resolved["cards"], controller.board.cards):
		_fail("infrastructure", "scene board differs from fixed-seed LevelLoader output")

# Endless round 1 is seeded by its round number, so a fresh run at the same board
# size must reproduce the scene's board. Also checks the score pill replaced the stars.
func _verify_endless_round(game, scene, controller, board: Control) -> void:
	if controller == null or board == null:
		_fail("infrastructure", "controller or Board missing")
		return
	if game.endless_run == null:
		_fail("infrastructure", "Game.endless_run missing in an endless view")
		return
	var resolved: Dictionary = EndlessRun.new().build_round_level(board.size)
	if resolved.has("error"):
		_fail("infrastructure", "endless round build failed: %s" % str(resolved["error"]))
	elif not _same_board(resolved["cards"], controller.board.cards):
		_fail("infrastructure", "scene board differs from deterministic endless round 1")
	if scene.get("score_label") == null or scene.get("stars_row") != null:
		_fail("endless-hud", "expected a score pill instead of the live stars")

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
	var key := "%s|%s|%s" % [_view_name, kind, detail]
	if _failure_keys.has(key):
		return
	_failure_keys[key] = true
	_failures.append("view=%s kind=%s %s" % [_view_name, kind, detail])

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
