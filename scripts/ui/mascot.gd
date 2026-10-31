class_name Mascot
extends Control

# A full-body hero portrait (assets/ui/heroes/) plus a speech bubble that floats
# above or beside it. The portrait is fixed per Level / Endless round by hero_for(),
# so the screens never have to choose one. The voice is always the neutral "hero"
# line family, so the same lines fit every portrait. Everything ignores the mouse so
# it never steals taps.
#
# Usage: add it as a child, give it a size (default 64x96), then call
# say("match") / say("win", {"stars": 3}) / set_mood(Mascot.Mood.SAD).
# With idle_tips on it shows a rotating "idle_tip" (see idle_event) every 10-14 s
# while visible. The line picker is the session-wide Game.mascot_lines().

enum Mood { IDLE, HAPPY, WORRIED, SAD }

# Layout box and roster live in HeroRoster (data-only, testable headless).
const BASE_SIZE := HeroRoster.BASE_SIZE
const HEROES := HeroRoster.HEROES
const FALLBACK_HERO := HeroRoster.FALLBACK_HERO
const DEFAULT_CHARACTER := HeroRoster.DEFAULT_HERO
const HERO_DIR := HeroRoster.HERO_DIR
const BUNNY_LEVEL := HeroRoster.BUNNY_LEVEL
const INK := Color("#3a2410")
const CARD_FACE := Color("#fff1d2")
# Common heroes show mood with a subtle tint only; the character never moves.
const WORRIED_TINT := Color(0.84, 0.88, 0.99)
const SAD_TINT := Color(0.72, 0.74, 0.80)
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
# rect means the whole viewport). The screen sets it to the free band above the
# mascot so the bubble never reaches the board.
var free_bounds := Rect2()
# Pool used by the idle-tip timer; Endless switches it to "idle_tip_endless" so the
# campaign-only tip about stars is never shown there.
var idle_event := "idle_tip"
var mood: Mood = Mood.IDLE
# Hero id ("cat", "wolf_ranger", ...): only the portrait changes, the voice stays neutral.
var character := DEFAULT_CHARACTER:
	set(value):
		var id := str(value)
		character = id if (HEROES.has(id) or id == FALLBACK_HERO) else DEFAULT_CHARACTER
		if _texture_ready:
			_load_texture()
		queue_redraw()

var _rng := RandomNumberGenerator.new()
var _level_id := ""
var _endless := false
# File stem of the portrait currently drawn ("hero_bunny_sequence", ...), for checks.
var frame_id := ""
var _texture_ready := false
var _texture: Texture2D
var _bubble_root: Control
var _bubble: PanelContainer
var _bubble_label: Label
var _tail: Control
var _fade_tween: Tween
var _clock := 0.0
var _last_said := {}
var _tip_in := 0.0
var _bubble_left := 0.0
var _layout_frames := 0
var _mood_left := 0.0

# Portrait for a campaign Level (L1..L9 map directly; L10/L11 and unknown ids use
# the menu wolf) or an Endless round (the 9 heroes rotate from round 1).
static func hero_for(level_id: String, endless_round: int = 0) -> String:
	return HeroRoster.hero_for(level_id, endless_round)

# Compatibility alias for older call sites.
static func character_for(level_id: String, endless_round: int = 0) -> String:
	return HeroRoster.hero_for(level_id, endless_round)

# L8 bunny swaps the portrait itself; the other heroes keep one portrait + tint/dip.
static func bunny_expression_for(mood: Mood) -> String:
	return HeroRoster.bunny_expression_for(int(mood))

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BASE_SIZE
	size = BASE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_rng.randomize()
	# The session-wide picker keeps the no-repeat memory across Mascot instances.
	lines = Game.mascot_lines()
	_level_id = Game.current_level_id
	_endless = Game.endless_run != null
	var endless_round := 0
	if Game.endless_run != null:
		endless_round = Game.endless_run.current_round
	character = hero_for(_level_id, endless_round)
	_texture_ready = true
	_load_texture()

func _ready() -> void:
	_build_bubble()
	_arm_tip_timer()

# Shows the line for an event and sets the matching mood. Returns the Localizer
# key that was shown, or "" when nothing was said (unknown event, cooldown,
# or the mascot is hidden).
func say(event: String, context: Dictionary = {}) -> String:
	if _bubble == null or not is_visible_in_tree():
		return ""
	_apply_event_mood(event)
	if EVENT_COOLDOWNS.has(event) and _clock - float(_last_said.get(event, -1000.0)) < float(EVENT_COOLDOWNS[event]):
		return ""
	# The portrait's id never reaches the picker: every hero uses the neutral family.
	var key := lines.pick(event, context, MascotLines.HERO_CHARACTER)
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
	var key := lines.pick(event, context, MascotLines.HERO_CHARACTER)
	return Localizer.t(key) if key != "" else ""

# duration > 0 returns to Mood.IDLE after that many seconds.
func set_mood(new_mood: Mood, duration: float = 0.0) -> void:
	mood = new_mood
	_mood_left = duration if new_mood != Mood.IDLE else 0.0
	_apply_mood_look()
	queue_redraw()

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

func _is_bunny_level8() -> bool:
	return not _endless and character == "bunny" and str(_level_id).to_int() == BUNNY_LEVEL

func _apply_mood_look() -> void:
	if _is_bunny_level8():
		# The L8 expression frames carry the mood; the character itself stays still.
		self_modulate = Color.WHITE
		_load_texture()
		queue_redraw()
		return
	match mood:
		Mood.WORRIED:
			self_modulate = WORRIED_TINT
		Mood.SAD:
			self_modulate = SAD_TINT
		_:
			self_modulate = Color.WHITE
	queue_redraw()

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
			side_bubble_bounds.end.y - _bubble.size.y)  # bottom-aligned, next to the mascot's head
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
	# Static floor shadow; the character itself never bobs, sways or hops.
	var shadow_center := Vector2(size.x * 0.5, size.y - 1.5 * s.y)
	var shadow := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		shadow.append(shadow_center + Vector2(cos(a) * 13.0 * s.x, sin(a) * 2.2 * s.y))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.22))
	var rect := _sprite_rect()
	if _texture != null:
		draw_texture_rect(_texture, rect, false)
	else:
		_draw_placeholder(rect)

# Bottom-centre, aspect preserved: the art is never squashed, whatever the control size.
func _sprite_rect() -> Rect2:
	var source := Vector2(3.0, 4.0) if _texture == null else _texture.get_size()
	var k := minf(size.x / source.x, size.y / source.y)
	var drawn := source * k
	return Rect2(Vector2((size.x - drawn.x) * 0.5, size.y - drawn.y), drawn)

func _load_texture() -> void:
	# L8 bunny swaps the frame by mood; every other hero keeps one portrait. Missing
	# art falls back to the menu wolf and then to any delivered hero, never blank.
	var order: Array = []
	if _is_bunny_level8():
		order.append(bunny_expression_for(mood))
	order.append("hero_%s" % character)
	order.append("hero_%s" % FALLBACK_HERO)
	for id in HEROES:
		order.append("hero_%s" % id)
	_texture = null
	frame_id = ""
	for name in order:
		var texture := UiHelpers.hires_texture(HERO_DIR % name)
		if texture != null:
			_texture = texture
			frame_id = name
			break
	queue_redraw()

# Last resort when no hero portrait exists: a simple silhouette, still visible.
func _draw_placeholder(rect: Rect2) -> void:
	var body := rect.grow(-rect.size.x * 0.08)
	draw_rect(body, Color("#8a6647"))
	draw_rect(Rect2(body.position + Vector2(body.size.x * 0.08, body.size.y * 0.04), Vector2(body.size.x * 0.84, body.size.y * 0.4)), Color("#a37b58"))
	draw_circle(body.position + Vector2(body.size.x * 0.32, body.size.y * 0.24), body.size.x * 0.07, INK)
	draw_circle(body.position + Vector2(body.size.x * 0.68, body.size.y * 0.24), body.size.x * 0.07, INK)
	draw_line(body.position + Vector2(body.size.x * 0.3, body.size.y * 0.42), body.position + Vector2(body.size.x * 0.7, body.size.y * 0.42), INK, 1.5, true)
