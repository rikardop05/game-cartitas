class_name Mascot
extends Control

# "Ace" (PT: "Ás"), the Cartitas mascot (T7.8): a small living playing card with a
# face, drawn entirely in code, plus a speech bubble that floats above it. Original
# character; no external art. Everything ignores the mouse so it never steals taps.
#
# Usage: add it as a child, give it a size (default 44x52), then call
# say("match") / say("win", {"stars": 3}) / set_mood(Mascot.Mood.SAD).
# With idle_tips on it shows a rotating "idle_tip" (see idle_event) every 10-14 s
# while visible. The line picker is the session-wide Game.mascot_lines().

enum Mood { IDLE, HAPPY, WORRIED, SAD }

const BASE_SIZE := Vector2(44.0, 52.0)
const INK := Color("#3a2410")
const CARD_FACE := Color("#fff1d2")
const SUIT_RED := Color("#c0392b")
const BLUSH := Color(1.0, 0.5, 0.45, 0.6)
const TEAR := Color("#6fb7e8")
const TIP_DELAY := Vector2(10.0, 14.0)
const BUBBLE_FONT_SIZE := 9
const BUBBLE_TEXT_MAX_WIDTH := 108.0
const BUBBLE_GAP := 6.0
const BUBBLE_TAIL_INSET := 14.0
const BUBBLE_SIDE_GAP := 5.0
const BUBBLE_SIDE_MARGIN := 4.0
const BUBBLE_MIN_SECONDS := 3.5
# Event -> minimum seconds between two bubbles of that event, so frequent events
# (every trio, every near-full zone) do not turn the mascot into a chatterbox.
const EVENT_COOLDOWNS := {"match": 8.0, "zone_warning": 6.0}
# Event -> [mood, seconds before going back to idle (0 = stay)].
const EVENT_MOODS := {
	"intro": [Mood.HAPPY, 2.0],
	"instruction": [Mood.HAPPY, 2.0],
	"round_intro": [Mood.HAPPY, 2.0],
	"match": [Mood.HAPPY, 1.8],
	"zone_warning": [Mood.WORRIED, 5.0],
	"power_used": [Mood.HAPPY, 1.5],
	"win": [Mood.HAPPY, 0.0],
	"lose": [Mood.SAD, 0.0],
}

var lines: MascotLines
var idle_tips := true
# Global rect of a free band beside the mascot. When it has an area the bubble sits to
# the right of the mascot inside it (tail pointing left) instead of above it, so the
# screen can keep the bubble off buttons and counters.
var side_bubble_bounds := Rect2()
# Global rect the bubble must stay inside while it floats above the mascot (an empty
# rect means the whole viewport). The screen sets it to the free band above Ace so the
# bubble never reaches the board.
var free_bounds := Rect2()
# Pool used by the idle-tip timer; Endless switches it to "idle_tip_endless" so the
# campaign-only tip about stars is never shown there.
var idle_event := "idle_tip"
var mood: Mood = Mood.IDLE
var bob := 0.0:
	set(value):
		bob = value
		queue_redraw()
var hop := 0.0:
	set(value):
		hop = value
		queue_redraw()
var sway := 0.0:
	set(value):
		sway = value
		queue_redraw()

var _rng := RandomNumberGenerator.new()
var _card_style := StyleBoxFlat.new()
var _bubble_root: Control
var _bubble: PanelContainer
var _bubble_label: Label
var _tail: Control
var _motion_tweens: Array[Tween] = []
var _hop_tween: Tween
var _fade_tween: Tween
var _clock := 0.0
var _last_said := {}
var _tip_in := 0.0
var _bubble_left := 0.0
var _layout_frames := 0
var _mood_left := 0.0
var _blink_in := 3.0
var _blinking := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BASE_SIZE
	size = BASE_SIZE
	_rng.randomize()
	# The session-wide picker keeps the no-repeat memory across Mascot instances.
	lines = Game.mascot_lines()
	_card_style.bg_color = CARD_FACE
	_card_style.border_color = INK
	_card_style.set_border_width_all(2)
	_card_style.set_corner_radius_all(6)
	_card_style.anti_aliasing = true

func _ready() -> void:
	_build_bubble()
	_start_motion()
	_arm_tip_timer()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		for tween in _motion_tweens:
			if tween != null and tween.is_valid():
				if is_visible_in_tree():
					tween.play()
				else:
					tween.pause()

# Shows the line for an event and sets the matching mood. Returns the Localizer
# key that was shown, or "" when nothing was said (unknown event, cooldown,
# or the mascot is hidden).
func say(event: String, context: Dictionary = {}) -> String:
	if _bubble == null or not is_visible_in_tree():
		return ""
	_apply_event_mood(event)
	if EVENT_COOLDOWNS.has(event) and _clock - float(_last_said.get(event, -1000.0)) < float(EVENT_COOLDOWNS[event]):
		return ""
	var key := lines.pick(event, context)
	if key == "":
		return ""
	_last_said[event] = _clock
	_show_bubble(Localizer.t(key))
	return key

# Shows a ready-made line (not drawn from a pool) for `seconds` (0 = by its length).
# `event` only picks the mood. Returns false when nothing was shown.
func say_text(text: String, seconds: float = 0.0, event: String = "") -> bool:
	if _bubble == null or not is_visible_in_tree() or text == "":
		return false
	_apply_event_mood(event)
	_show_bubble(text, seconds)
	return true

# Global rect of the bubble while it is on screen (empty rect when hidden).
func bubble_global_rect() -> Rect2:
	# Still invisible (alpha 0) while the bubble waits to be laid out and placed.
	if _bubble == null or _bubble_root == null or not _bubble_root.visible or _bubble_root.modulate.a < 0.99:
		return Rect2()
	return Rect2(_bubble.global_position, _bubble.size)

# Text for an event without showing a bubble (used by the end-screen panel).
func localized_line(event: String, context: Dictionary = {}) -> String:
	var key := lines.pick(event, context)
	return Localizer.t(key) if key != "" else ""

# duration > 0 returns to Mood.IDLE after that many seconds.
func set_mood(new_mood: Mood, duration: float = 0.0) -> void:
	mood = new_mood
	_mood_left = duration if new_mood != Mood.IDLE else 0.0
	queue_redraw()
	if new_mood == Mood.HAPPY and is_inside_tree():
		_hop()

func hide_bubble() -> void:
	_bubble_left = 0.0
	_layout_frames = 0
	if _bubble_root == null or not _bubble_root.visible:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bubble_root, "modulate:a", 0.0, 0.2)
	_fade_tween.tween_callback(func(): _bubble_root.visible = false)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	_update_blink(delta)
	if _mood_left > 0.0:
		_mood_left -= delta
		if _mood_left <= 0.0:
			set_mood(Mood.IDLE)
	if _layout_frames > 0:
		_layout_frames -= 1
		_bubble.reset_size()
		if _layout_frames == 0:
			_place_bubble()
		return
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			hide_bubble()
			_arm_tip_timer()
	elif idle_tips:
		_tip_in -= delta
		if _tip_in <= 0.0:
			if say(idle_event) == "":
				_arm_tip_timer()

func _apply_event_mood(event: String) -> void:
	if EVENT_MOODS.has(event):
		var entry: Array = EVENT_MOODS[event]
		set_mood(entry[0], float(entry[1]))

func _arm_tip_timer() -> void:
	_tip_in = _rng.randf_range(TIP_DELAY.x, TIP_DELAY.y)

func _update_blink(delta: float) -> void:
	_blink_in -= delta
	if _blink_in > 0.0:
		return
	_blinking = not _blinking
	_blink_in = 0.12 if _blinking else _rng.randf_range(2.5, 5.0)
	queue_redraw()

func _start_motion() -> void:
	# Idle bob and a slight sway, looping for as long as the mascot lives.
	var bob_tween := create_tween().set_loops()
	bob_tween.tween_property(self, "bob", -1.6, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(self, "bob", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var sway_tween := create_tween().set_loops()
	sway_tween.tween_property(self, "sway", 0.04, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway_tween.tween_property(self, "sway", -0.04, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion_tweens = [bob_tween, sway_tween]
	if not is_visible_in_tree():
		for tween in _motion_tweens:
			tween.pause()

func _hop() -> void:
	if _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()
	_hop_tween = create_tween()
	_hop_tween.tween_property(self, "hop", -4.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(self, "hop", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# ---------------------------------------------------------------- speech bubble

func _build_bubble() -> void:
	_bubble_root = Control.new()
	_bubble_root.name = "BubbleRoot"
	_bubble_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_root.z_index = 10
	_bubble_root.visible = false
	add_child(_bubble_root)

	_bubble = PanelContainer.new()
	_bubble.name = "Bubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_FACE
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.anti_aliasing = true
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble_root.add_child(_bubble)

	_bubble_label = Label.new()
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble_label.add_theme_font_size_override("font_size", BUBBLE_FONT_SIZE)
	_bubble_label.add_theme_color_override("font_color", INK)
	_bubble.add_child(_bubble_label)

	# The tail is a sibling drawn after the bubble so it can cover the bubble's
	# bottom border and read as one speech-bubble shape.
	_tail = Control.new()
	_tail.name = "BubbleTail"
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.draw.connect(_draw_tail)
	_bubble_root.add_child(_tail)

func _show_bubble(text: String, seconds: float = 0.0) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_bubble_label.text = text
	var font := _bubble_label.get_theme_default_font()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FONT_SIZE).x
	_bubble_label.custom_minimum_size = Vector2(clampf(text_width + 2.0, 36.0, _bubble_text_max_width()), 0.0)
	_bubble_label.size = Vector2.ZERO
	_bubble.reset_size()
	# Hidden until laid out: autowrap needs a frame or two to settle its height.
	_bubble_root.modulate.a = 0.0
	_bubble_root.visible = true
	_layout_frames = 3
	_bubble_left = seconds if seconds > 0.0 else maxf(BUBBLE_MIN_SECONDS, 0.06 * text.length() + 1.5)

func _side_mode() -> bool:
	return side_bubble_bounds.has_area()

func _bubble_text_max_width() -> float:
	if not _side_mode():
		if free_bounds.has_area():
			# Narrow free band: wrap inside it (minus the bubble's padding and border).
			return clampf(free_bounds.size.x - 14.0, 36.0, BUBBLE_TEXT_MAX_WIDTH)
		return BUBBLE_TEXT_MAX_WIDTH
	# Room between the mascot and the band's right edge, minus the bubble's padding and border.
	var room := side_bubble_bounds.end.x - (global_position.x + size.x + BUBBLE_SIDE_GAP) - 14.0
	return maxf(BUBBLE_TEXT_MAX_WIDTH, room)

func _place_bubble() -> void:
	var bounds := get_viewport_rect().size
	var global_target: Vector2
	if _side_mode():
		global_target = Vector2(
			global_position.x + size.x + BUBBLE_SIDE_GAP,
			side_bubble_bounds.end.y - _bubble.size.y)  # bottom-aligned, next to Ace's head
		global_target.y = clampf(global_target.y, side_bubble_bounds.position.y, maxf(side_bubble_bounds.position.y, side_bubble_bounds.end.y - _bubble.size.y))
	else:
		global_target = global_position + Vector2(size.x * 0.5 - BUBBLE_TAIL_INSET, -_bubble.size.y - BUBBLE_GAP)
	# Keep the whole bubble inside the viewport (or the free band), wherever the mascot sits.
	var area := Rect2(Vector2(3.0, 3.0), bounds - Vector2(6.0, 6.0))
	if not _side_mode() and free_bounds.has_area():
		area = free_bounds
	global_target.x = clampf(global_target.x, area.position.x, maxf(area.position.x, area.end.x - _bubble.size.x))
	global_target.y = clampf(global_target.y, area.position.y, maxf(area.position.y, area.end.y - _bubble.size.y))
	_bubble.position = global_target - global_position
	_tail.queue_redraw()
	# Fully opaque at once: a fade-in made the bubble read as see-through over the HUD.
	_bubble_root.modulate.a = 1.0

func _draw_tail() -> void:
	if _side_mode():
		var base_x := _bubble.position.x + 2.0
		var mid_y := clampf(size.y * 0.25, _bubble.position.y + 8.0, _bubble.position.y + _bubble.size.y - 8.0)
		var tip_side := Vector2(_bubble.position.x - BUBBLE_SIDE_GAP + 1.0, mid_y)
		var top_side := Vector2(base_x, mid_y - 4.0)
		var bottom_side := Vector2(base_x, mid_y + 4.0)
		_tail.draw_colored_polygon(PackedVector2Array([top_side, bottom_side, tip_side]), CARD_FACE)
		_tail.draw_polyline(PackedVector2Array([top_side, tip_side, bottom_side]), INK, 2.0, true)
		return
	var tip_x := clampf(size.x * 0.5, _bubble.position.x + 10.0, _bubble.position.x + _bubble.size.x - 10.0)
	var base_y := _bubble.position.y + _bubble.size.y - 2.0
	var left := Vector2(tip_x - 4.0, base_y)
	var right := Vector2(tip_x + 4.0, base_y)
	var tip := Vector2(size.x * 0.5, base_y + 2.0 + BUBBLE_GAP - 1.0)
	_tail.draw_colored_polygon(PackedVector2Array([left, right, tip]), CARD_FACE)
	_tail.draw_polyline(PackedVector2Array([left, tip, right]), INK, 2.0, true)

# ------------------------------------------------------------------- the drawing

func _draw() -> void:
	var s := size / BASE_SIZE
	var pivot := Vector2(22.0, 50.0) * s
	# Soft shadow stays on the floor while the card bobs above it.
	draw_set_transform_matrix(Transform2D.IDENTITY.scaled(s))
	var shadow := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		shadow.append(Vector2(22.0 + cos(a) * 13.0, 51.0 + sin(a) * 2.2))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.22))
	var xf := Transform2D.IDENTITY.scaled(s)
	xf = xf.translated(-pivot).rotated(sway).translated(pivot)
	xf = xf.translated(Vector2(0.0, (bob + hop) * s.y))
	draw_set_transform_matrix(xf)
	_draw_card()
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_card() -> void:
	# Legs and arms first, so the card body covers where they attach.
	draw_rect(Rect2(13.0, 42.0, 6.0, 8.0), INK)
	draw_rect(Rect2(25.0, 42.0, 6.0, 8.0), INK)
	var arms := _arm_points()
	for i in 2:
		draw_line(arms[i][0], arms[i][1], INK, 3.0, true)
		draw_circle(arms[i][1], 2.0, INK)
	_card_style.draw(get_canvas_item(), Rect2(5.0, 3.0, 34.0, 41.0))
	# Corner index: an "A" with a red diamond, like the ace it is.
	draw_string(get_theme_default_font(), Vector2(8.5, 14.0), "A", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, INK)
	_draw_diamond(Vector2(11.0, 18.5), 2.6)
	_draw_diamond(Vector2(33.0, 38.5), 2.6)
	_draw_face()

func _draw_diamond(center: Vector2, radius: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius * 1.2), center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius * 1.2), center + Vector2(-radius, 0.0),
	]), SUIT_RED)

func _arm_points() -> Array:
	var left := Vector2(6.0, 28.0)
	var right := Vector2(38.0, 28.0)
	match mood:
		Mood.HAPPY:
			return [[left, Vector2(1.0, 21.0)], [right, Vector2(43.0, 21.0)]]
		Mood.WORRIED:
			return [[left, Vector2(2.0, 26.0)], [right, Vector2(42.0, 26.0)]]
		Mood.SAD:
			return [[left, Vector2(2.5, 36.0)], [right, Vector2(41.5, 36.0)]]
	return [[left, Vector2(1.5, 34.0)], [right, Vector2(42.5, 34.0)]]

func _draw_face() -> void:
	var eye_y := 26.0
	var eye_xs := [16.0, 28.0]
	for x in eye_xs:
		var eye := Vector2(x, eye_y)
		match mood:
			Mood.HAPPY:
				draw_arc(eye + Vector2(0.0, 1.5), 3.0, PI, TAU, 10, INK, 2.0, true)
			_:
				if _blinking and mood == Mood.IDLE:
					draw_line(eye + Vector2(-2.6, 0.0), eye + Vector2(2.6, 0.0), INK, 2.0, true)
				else:
					draw_circle(eye, 2.6 if mood == Mood.WORRIED else 2.4, INK)
					draw_circle(eye + Vector2(0.8, -0.9), 0.8, CARD_FACE)
	match mood:
		Mood.IDLE:
			draw_arc(Vector2(22.0, 31.5), 5.0, PI * 0.2, PI * 0.8, 10, INK, 2.0, true)
		Mood.HAPPY:
			draw_circle(Vector2(11.0, 31.5), 2.4, BLUSH)
			draw_circle(Vector2(33.0, 31.5), 2.4, BLUSH)
			var mouth := PackedVector2Array()
			for i in 9:
				var a := PI * float(i) / 8.0
				mouth.append(Vector2(22.0 + cos(a) * 5.0, 31.0 + sin(a) * 5.0))
			draw_colored_polygon(mouth, INK)
			draw_circle(Vector2(22.0, 34.8), 2.0, Color("#e8737a"))
		Mood.WORRIED:
			draw_line(Vector2(11.0, 21.0), Vector2(18.0, 19.0), INK, 1.6, true)
			draw_line(Vector2(26.0, 19.0), Vector2(33.0, 21.0), INK, 1.6, true)
			draw_polyline(PackedVector2Array([
				Vector2(17.0, 35.0), Vector2(19.5, 33.2), Vector2(22.0, 35.0),
				Vector2(24.5, 33.2), Vector2(27.0, 35.0),
			]), INK, 1.8, true)
			draw_circle(Vector2(35.0, 20.0), 1.9, TEAR)
			draw_colored_polygon(PackedVector2Array([Vector2(35.0, 16.0), Vector2(33.4, 19.4), Vector2(36.6, 19.4)]), TEAR)
		Mood.SAD:
			draw_line(Vector2(11.0, 22.0), Vector2(18.0, 19.5), INK, 1.6, true)
			draw_line(Vector2(26.0, 19.5), Vector2(33.0, 22.0), INK, 1.6, true)
			draw_arc(Vector2(22.0, 39.0), 5.0, PI * 1.2, PI * 1.8, 10, INK, 2.0, true)
			draw_circle(Vector2(13.0, 31.0), 1.5, TEAR)
			draw_line(Vector2(13.0, 28.5), Vector2(13.0, 30.0), TEAR, 1.5, true)
