class_name CardImpactFx
extends Node2D
## One-shot landing effect of a card: squash + bounce of the card, a flash at contact, a ground
## ring, a soft halo, sideways earthy dust (behind AND in front of the bottom edge) and green/gold
## energy (sparks + rising motes). Everything is built from tweens and tiny CPUParticles2D
## systems; the root frees itself when the last part is done, so nothing runs per frame after.
##
## Usage: CardImpactFx.play(layer, card_control, config) right when the card touches down.
## `parent` must share the card's canvas; the FX is laid out from the card's bottom-centre.
## (CPUParticles2D instead of GPUParticles2D: <= 20 particles per landing, identical on every
## backend, and no first-use shader/compile hitch on gl_compatibility / mobile.)

# load(), not preload(): the scene references this script (a preload would be circular).
const SCENE_PATH := "res://scenes/fx/card_impact_fx.tscn"
static var _scene: PackedScene

## Loads the effect scene once (call at level start): no load() then happens mid-game.
static func warm() -> void:
	if _scene == null:
		_scene = load(SCENE_PATH) as PackedScene
const DUST := [
	preload("res://assets/ui/fx/impact/dust_1.png"),
	preload("res://assets/ui/fx/impact/dust_2.png"),
	preload("res://assets/ui/fx/impact/dust_3.png"),
	preload("res://assets/ui/fx/impact/dust_4.png"),
]
const SPARK := preload("res://assets/ui/fx/impact/spark.png")
const MOTE := preload("res://assets/ui/fx/impact/mote.png")
const GLOW := preload("res://assets/ui/fx/impact/glow.png")
const RIM := preload("res://assets/ui/fx/impact/rim.png")
const RING := preload("res://assets/ui/fx/impact/ring.png")
const FLASH := preload("res://assets/ui/fx/impact/flash.png")

## Reference card width the particle sizes/speeds are authored for (the zone card).
const REFERENCE_SIZE := 42.0
## Total life of the effect (the longest part: dust); the root frees itself after it.
const LIFE_SECONDS := 1.1
const SQUASH_DOWN_SECONDS := 0.08
const SQUASH_UP_SECONDS := 0.16

## Defaults; every key can be overridden per card type through `config`.
const DEFAULT_CONFIG := {
	"palette": "green",
	"full": true,                                   # false = light dust puff only
	"light_dust": false,                            # one small puff per side for a large multi-card landing
	"intensity": 1.0,                               # scales sizes, speeds and alpha
	"squash": true,                                 # squash/bounce the card itself
	"squash_depth": 0.09,                           # small, like the reference: ~1.06 x / 0.91 y at the deepest point
	"dust_color": Color(0.93, 0.84, 0.70),
	"energy_colors": [Color(1.0, 0.85, 0.35), Color(1.0, 0.97, 0.75), Color(0.6, 1.0, 0.5)],  # rising motes: gold / white / green
	"spark_colors": [Color(1.0, 0.35, 0.3), Color(1.0, 0.92, 0.9), Color(1.0, 0.6, 0.5)],     # contact sparks: ember red / white
	"ring_color": Color(0.7, 1.0, 0.55),
	"glow_color": Color(0.35, 1.0, 0.25),
	"flash_color": Color(1.0, 0.96, 0.7),
	"ring": true,                                   # soft ground ring (full only)
	"glow": true,                                   # big halo behind the card (full only)
	"flash": true,                                  # contact flash (full only)
	"rim": true,                                    # thin outline glow in front (full only)
	"glow_strength": 1.0,                           # halo alpha factor (the deal uses less: many at once)
	# Optional: draw the whole Back layer (halo, ring, most dust) inside this node, right below
	# `back_before` (a sibling), so it sits BEHIND the real slot card once the ghost hands over.
	"back_parent": null,
	"back_before": null,
	"on_done": Callable(),                          # called when the card finished its squash
}

## Refresh/Undo/Hold landings use the same effect shape with a warm crimson energy palette.
## Beige dust and the existing green default remain unchanged for all existing callers.
const RED_PALETTE := {
	"energy_colors": [Color("#ff5548"), Color("#ffb3a1"), Color("#9d1838")],
	"spark_colors": [Color("#ff4038"), Color("#fff0e9"), Color("#ff7968")],
	"ring_color": Color("#ff5961"),
	"glow_color": Color("#e9344b"),
}

static var _additive: CanvasItemMaterial
## Landings alive right now (the smoke asserts it returns to 0).
static var live_count := 0

@onready var back: Node2D = $Back
@onready var front: Node2D = $Front

static func play(parent: Node, card: Control, config: Dictionary = {}) -> CardImpactFx:
	if parent == null or not is_instance_valid(parent) or card == null or not is_instance_valid(card):
		return null
	var cfg := DEFAULT_CONFIG.duplicate()
	if str(config.get("palette", "green")) == "red":
		cfg.merge(RED_PALETTE, true)
	cfg.merge(config, true)
	var xf := card.get_global_transform()
	var scale_xy := xf.get_scale()
	var size_px := Vector2(card.size.x * absf(scale_xy.x), card.size.y * absf(scale_xy.y))
	var fx := _instance()
	fx.set_meta("palette", str(cfg.get("palette", "green")))
	fx.set_meta("full", bool(cfg["full"]))
	live_count += 1
	fx.tree_exited.connect(_on_gone)
	if parent is CanvasItem:
		# Same absolute depth as a sibling card: Back (-1) goes behind it, Front (+1) over it.
		fx.z_index = card.z_index
	parent.add_child(fx)
	fx.set_meta("born_msec", Time.get_ticks_msec())
	fx.global_position = xf * Vector2(card.size.x * 0.5, card.size.y)
	fx._reparent_back(cfg)
	fx._build(size_px, cfg)
	if bool(cfg["squash"]):
		fx._squash_card(card, cfg)
	return fx

static func _instance() -> CardImpactFx:
	warm()
	return _scene.instantiate() as CardImpactFx

static func _on_gone() -> void:
	live_count -= 1

func _reparent_back(cfg: Dictionary) -> void:
	var bp = cfg["back_parent"]
	if bp == null or not is_instance_valid(bp):
		return
	back.reparent(bp, true)
	back.z_index = 0
	var before = cfg["back_before"]
	if before != null and is_instance_valid(before) and before.get_parent() == bp:
		bp.move_child(back, before.get_index())
	# The relocated layer lives and dies with this effect.
	tree_exiting.connect(back.queue_free)

func _build(size_px: Vector2, cfg: Dictionary) -> void:
	var k: float = clampf(size_px.x / REFERENCE_SIZE, 0.7, 2.5) * float(cfg["intensity"])
	var full := bool(cfg["full"])
	var dust_tint: Color = cfg["dust_color"]
	var picks := [0, 1, 2, 3]
	picks.shuffle()
	var half_w := size_px.x * 0.5
	# Dust: mostly sideways from the base, behind the card; a little in front of the bottom edge.
	var behind: int = 1 if bool(cfg["light_dust"]) else (4 if full else 3)
	_dust(back, DUST[picks[0]], Vector2(-1, -0.18), behind, k, dust_tint, half_w, 1.0)
	_dust(back, DUST[picks[1]], Vector2(1, -0.18), behind, k, dust_tint, half_w, 1.0)
	if full:
		_dust(back, DUST[picks[2]], Vector2(0, -1), 2, k, dust_tint, half_w, 0.7)
		_dust(front, DUST[picks[3]], Vector2(-1, 0.0), 2, k, dust_tint, half_w, 0.8, 0.06, true)
		_dust(front, DUST[picks[0]], Vector2(1, 0.0), 2, k, dust_tint, half_w, 0.8, 0.06, true)
	if not full:
		_finish_after(LIFE_SECONDS * 0.85)
		return
	_sparks(k, cfg["spark_colors"], half_w)
	_motes(k, cfg["energy_colors"], size_px)
	if bool(cfg["ring"]):
		_ring(cfg["ring_color"], half_w)
	if bool(cfg["glow"]):
		_glow(cfg["glow_color"], size_px, float(cfg["glow_strength"]))
	if bool(cfg["flash"]):
		_flash(cfg["flash_color"], size_px)
	if bool(cfg["rim"]):
		_rim(cfg["glow_color"], size_px)
	_finish_after(LIFE_SECONDS)

func _finish_after(seconds: float) -> void:
	var t := create_tween()
	t.tween_interval(seconds)
	t.tween_callback(queue_free)

static func _add_mat() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive

static func _fade_ramp(peak: float, color: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), Color(color, peak), Color(color, 0.0)])
	return g

static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	return c

## Gradient sampled at random per particle: the energy colours.
static func _color_pick_ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / float(maxi(1, colors.size() - 1)))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	return g

static var no_particles := DisplayServer.get_name() == "headless"

func _dust(layer: Node2D, tex: Texture2D, dir: Vector2, amount: int, k: float, tint: Color, half_w: float, weight: float, delay: float = 0.06, strip: bool = false) -> void:
	if no_particles:
		return
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = 0.85
	p.one_shot = true
	p.explosiveness = 0.6
	p.randomness = 0.6
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(half_w * 0.85, 1.5)
	p.position = Vector2(0, -2.0 * k)
	p.direction = dir
	p.spread = 22.0
	p.initial_velocity_min = 50.0 * k * weight
	p.initial_velocity_max = 110.0 * k * weight
	p.damping_min = 95.0
	p.damping_max = 130.0
	p.gravity = Vector2(0, -14.0 * k)
	p.angle_min = -40.0
	p.angle_max = 40.0
	p.angular_velocity_min = -30.0
	p.angular_velocity_max = 30.0
	p.scale_amount_min = 0.22 * k
	p.scale_amount_max = 0.4 * k
	p.scale_amount_curve = _curve([Vector2(0, 0.55), Vector2(1, 1.6)])
	if strip:
		# The strip in front of the bottom edge: small, flat, no rise, so it only brushes the lowest ~15 %.
		p.position = Vector2(0, 1.5 * k)
		p.gravity = Vector2.ZERO
		p.scale_amount_min = 0.08 * k
		p.scale_amount_max = 0.14 * k
		p.scale_amount_curve = _curve([Vector2(0, 0.8), Vector2(1, 1.3)])
		p.color_ramp = _fade_ramp(0.4, tint)
	else:
		p.color_ramp = _fade_ramp(0.6 * weight, tint)
	layer.add_child(p)
	# The cloud builds up just after the contact flash and lingers (reference: peaks ~0.4 s).
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(p.set.bind("emitting", true))

func _sparks(k: float, colors: Array, half_w: float) -> void:
	if no_particles:
		return
	var p := CPUParticles2D.new()
	p.texture = SPARK
	p.material = _add_mat()
	p.amount = 9
	p.lifetime = 0.42
	p.one_shot = true
	p.explosiveness = 0.95
	p.randomness = 0.5
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(half_w * 0.9, 1.0)
	p.direction = Vector2(0, -1)
	p.spread = 88.0
	p.initial_velocity_min = 70.0 * k
	p.initial_velocity_max = 150.0 * k
	p.damping_min = 120.0
	p.damping_max = 190.0
	p.gravity = Vector2(0, 150.0 * k)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.28 * k
	p.scale_amount_max = 0.55 * k
	p.scale_amount_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.15)])
	p.color_initial_ramp = _color_pick_ramp(colors)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.0)])
	p.color_ramp = fade
	front.add_child(p)
	p.emitting = true

func _motes(k: float, colors: Array, size_px: Vector2) -> void:
	if no_particles:
		return
	var p := CPUParticles2D.new()
	p.texture = MOTE
	p.material = _add_mat()
	p.amount = 7
	p.lifetime = 0.58
	p.one_shot = true
	p.explosiveness = 0.5
	p.randomness = 0.7
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size_px.x * 0.4, size_px.y * 0.15)
	p.position = Vector2(0, -size_px.y * 0.18)
	p.direction = Vector2(0, -1)
	p.spread = 30.0
	p.initial_velocity_min = 22.0 * k
	p.initial_velocity_max = 54.0 * k
	p.damping_min = 30.0
	p.damping_max = 60.0
	p.scale_amount_min = 0.12 * k
	p.scale_amount_max = 0.24 * k
	p.scale_amount_curve = _curve([Vector2(0, 0.6), Vector2(0.3, 1.0), Vector2(1, 0.3)])
	p.color_initial_ramp = _color_pick_ramp(colors)
	p.color_ramp = _fade_ramp(0.9, Color.WHITE)
	front.add_child(p)
	p.emitting = true

func _sprite(tex: Texture2D, color: Color, parent: Node2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.modulate = color
	s.material = _add_mat()
	parent.add_child(s)
	return s

func _ring(color: Color, half_w: float) -> void:
	var s := _sprite(RING, Color(color, 0.0), back)
	var end_w := (half_w * 2.0 * 1.9) / 128.0
	s.scale = Vector2(end_w * 0.25, end_w * 0.25 * 0.38)
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale", Vector2(end_w, end_w * 0.38), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.32, 0.04)
	t.chain().tween_property(s, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)

func _glow(color: Color, size_px: Vector2, strength: float) -> void:
	# The dominant effect: a large soft additive halo (radius ~1.5x the card), drawn BEHIND the card.
	# Scale and alpha run as two independent tweens so the whole halo is gone by 0.4 s.
	var s := _sprite(GLOW, Color(color, 0.0), back)
	s.position = Vector2(0, -size_px.y * 0.5)
	var end_s := (maxf(size_px.x, size_px.y) * 3.3) / 128.0
	s.scale = Vector2(end_s * 0.55, end_s * 0.55)
	s.create_tween().tween_property(s, "scale", Vector2(end_s, end_s), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.6 * strength, 0.05)
	t.tween_property(s, "modulate:a", 0.0, 0.33).set_ease(Tween.EASE_OUT)

func _flash(color: Color, size_px: Vector2) -> void:
	var s := _sprite(FLASH, Color(color, 0.0), front)
	s.position = Vector2(0, -size_px.y * 0.08)
	var end_s := (size_px.x * 1.5) / 128.0
	s.scale = Vector2(end_s * 0.5, end_s * 0.5)
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale", Vector2(end_s, end_s), 0.07).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.95, 0.02)
	t.chain().tween_property(s, "modulate:a", 0.0, 0.06)

## Thin glow along the card outline, in FRONT (the big halo stays behind): peak <= 0.35, gone by 0.3 s.
func _rim(color: Color, size_px: Vector2) -> void:
	var s := _sprite(RIM, Color(color, 0.0), front)
	s.name = "Rim"
	s.position = Vector2(0, -size_px.y * 0.5)
	s.scale = Vector2(size_px.x * 0.5 / 51.2, size_px.y * 0.5 / 51.2) * 1.04
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.35, 0.03)
	t.tween_property(s, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_OUT)

## Lingering sparkle ring (vertical ellipse of pink/white motes) left where a card starts its drop;
## drifts up and twinkles out in ~0.45 s. `center` is global; `size` is the card width in pixels.
static func play_trail(parent: Node, center: Vector2, size: float) -> CardImpactFx:
	if parent == null or not is_instance_valid(parent):
		return null
	var fx := _instance()
	live_count += 1
	fx.tree_exited.connect(_on_gone)
	parent.add_child(fx)
	fx.global_position = center
	var points := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		points.append(Vector2(cos(a) * size * 0.5, sin(a) * size * 0.85))
	var p := CPUParticles2D.new()
	p.texture = MOTE
	p.material = _add_mat()
	p.amount = 18
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 0.35
	p.randomness = 0.5
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = points
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 26.0
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.15
	p.scale_amount_curve = _curve([Vector2(0, 0.7), Vector2(0.3, 1.0), Vector2(1, 0.2)])
	p.color_initial_ramp = _color_pick_ramp([Color(1.0, 0.55, 0.75), Color(1.0, 0.9, 0.95), Color(1.0, 0.7, 0.85)])
	p.color_ramp = _fade_ramp(0.85, Color.WHITE)
	fx.back.add_child(p)
	p.emitting = true
	fx._finish_after(0.55)
	return fx

## Squash and bounce about the card's bottom-centre; ends exactly on its base position and scale.
## State lives on this node (no lambda captures: the card can be freed under us, e.g. by a rebuild).
var _card: Control
var _base_pos := Vector2.ZERO
var _base_scale := Vector2.ONE
var _anchor := Vector2.ZERO
var _on_done := Callable()

func _squash_card(card: Control, cfg: Dictionary) -> void:
	_card = card
	_base_pos = card.position
	_base_scale = card.scale
	_anchor = _base_pos + Vector2(card.size.x * _base_scale.x * 0.5, card.size.y * _base_scale.y)
	_on_done = cfg["on_done"]
	var depth: float = float(cfg["squash_depth"]) * float(cfg["intensity"])
	var down := Vector2(1.0 + depth * 0.7, 1.0 - depth)
	var over := Vector2(1.0 - depth * 0.18, 1.0 + depth * 0.3)
	var apply := Callable(self, "_apply_squash")
	var t := create_tween()
	t.tween_method(apply, Vector2.ONE, down, SQUASH_DOWN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_method(apply, down, over, SQUASH_UP_SECONDS * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_method(apply, over, Vector2.ONE, SQUASH_UP_SECONDS * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(Callable(self, "_finish_squash"))

func _apply_squash(sq: Vector2) -> void:
	if not is_instance_valid(_card):
		return
	_card.scale = _base_scale * sq
	_card.position = _anchor - Vector2(_card.size.x * _base_scale.x * sq.x * 0.5, _card.size.y * _base_scale.y * sq.y)

func _finish_squash() -> void:
	if is_instance_valid(_card):
		_card.scale = _base_scale
		_card.position = _base_pos
	if _on_done.is_valid():
		_on_done.call()
