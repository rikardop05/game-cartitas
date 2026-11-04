class_name ScreenShake
extends Node

## Trauma-based screen shake for the Level screen (Phase Q).
##
## One Triple Match shakes the level content a little; a fast sequence of matches grows the shake
## up to a ceiling, so a combo feels punchy without becoming nauseating. The shake is a temporary
## transform on a target Control (the layout that holds the board, Clearing Zone, decks, reserve
## and HUD): no camera, no particles, no randomness per frame — a seeded FastNoiseLite keeps the
## motion smooth and identical in headless runs.
##
## The target keeps owning its rest transform: the rest position/rotation are captured when the
## shake starts and written back exactly when trauma reaches 0. `LevelLayout` never positions the
## shaken container itself (it positions its children), so the two never fight.
##
## Future combo SFX: connect `combo_changed` (1 = single match, 0 = the combo window expired) and
## play the riser/accent there. Nothing is played today on purpose.

## Emitted on every match with the new combo level (1 = single match) and with 0 when the combo
## window ends. Hook for combo sound effects / HUD callouts.
signal combo_changed(level: int)

# Accessibility: with false the combo/blocks still run (and still emit combo_changed) but nothing
# moves on screen. No new options UI was added.
const SHAKE_ENABLED := true
# Peak offset of the shaken content, in design px (the viewport's logical units). With the
# trauma^2 curve the visible peak at the ceiling (trauma 0.6) is ~6.5 px, ~0.9 px for a single
# match: subtle, but still readable when the screen is scaled 2x on a desktop window.
const SHAKE_MAX_OFFSET_PX := 18.0
# Peak rotation in degrees around the centre of the shaken content (~0.7 deg at the ceiling).
const SHAKE_MAX_ROT_DEG := 2.0
# Trauma lost per second, so one match fades out in a bit under half a second.
const TRAUMA_DECAY_PER_S := 1.4
# Hard ceiling on trauma, so even a long combo stays tasteful.
const TRAUMA_CEILING := 0.6
# A match this soon after the previous one continues the combo; otherwise it starts a new one.
const COMBO_WINDOW_S := 2.5
# Trauma added per match by combo level (index 0 = first match); the last value repeats.
const COMBO_TRAUMA: Array[float] = [0.35, 0.42, 0.48, 0.54, 0.6]
# How fast the noise is sampled (roughly "wiggles per second" at frequency 1). Fast enough that
# even the shortest shake (a single match fades in ~0.16 s) crosses a couple of peaks instead of
# sitting on a flat stretch of the noise.
const NOISE_SPEED := 24.0
# Simplex noise peaks around ±0.6, so the samples are pushed up (and clamped to ±1) to use the
# full amplitude budget instead of a fraction of it.
const NOISE_GAIN := 1.7
const NOISE_SEED := 1337

## Current trauma, 0..1. Offset/rotation grow with trauma^2, so low trauma is barely visible.
var trauma := 0.0
## The transformed Control; the ScreenShake node only writes position/rotation while shaking.
var target: Control = null

var _combo := 0
var _since_match := INF
var _time := 0.0
var _rest_position := Vector2.ZERO
var _rest_rotation := 0.0
var _applied := false
var _noise: FastNoiseLite = null

# --- Pure rules (unit tested) -----------------------------------------------------------

## Combo level this match belongs to: the previous level + 1 while inside COMBO_WINDOW_S,
## otherwise a fresh combo starting at 1.
static func next_combo(previous: int, seconds_since_last_match: float) -> int:
	if previous <= 0 or seconds_since_last_match > COMBO_WINDOW_S:
		return 1
	return previous + 1

## Trauma added by a match at `level` (1 = single match). Monotonic and capped by the ladder.
static func trauma_for(level: int) -> float:
	if level <= 0:
		return 0.0
	return COMBO_TRAUMA[clampi(level - 1, 0, COMBO_TRAUMA.size() - 1)]

## Trauma after `delta` seconds of decay; never negative.
static func decayed(trauma_now: float, delta: float) -> float:
	return clampf(trauma_now - TRAUMA_DECAY_PER_S * maxf(delta, 0.0), 0.0, 1.0)

## Amplitude factor (0..1) applied to the maxima: trauma squared, as in the classic model.
static func amplitude_for(trauma_now: float) -> float:
	var clamped := clampf(trauma_now, 0.0, 1.0)
	return clamped * clamped

## Offset in px for a trauma and a noise sample in -1..1 on each axis.
static func offset_for(trauma_now: float, noise: Vector2) -> Vector2:
	return noise * (SHAKE_MAX_OFFSET_PX * amplitude_for(trauma_now))

## Rotation in radians for a trauma and a noise sample in -1..1.
static func rotation_for(trauma_now: float, noise: float) -> float:
	return deg_to_rad(SHAKE_MAX_ROT_DEG) * amplitude_for(trauma_now) * noise

# --- Wiring -----------------------------------------------------------------------------

## Creates the shake node under `host` and targets `target` (the layout that holds the level
## content). One line for the screen that wants it.
static func attach(host: Node, target_control: Control) -> ScreenShake:
	var shake := ScreenShake.new()
	shake.name = "ScreenShake"
	# Decay and restore even while the settings overlay pauses the tree: a freeze mid-offset
	# would leave the board crooked.
	shake.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(shake)
	shake.target = target_control
	return shake

# --- Runtime ----------------------------------------------------------------------------

## One Triple Match: grows the combo, adds its trauma and reports the new level.
func add_match() -> void:
	_combo = next_combo(_combo, _since_match)
	_since_match = 0.0
	trauma = minf(TRAUMA_CEILING, trauma + trauma_for(_combo))
	combo_changed.emit(_combo)

## Combo level of the match in progress (0 when it expired).
func combo_level() -> int:
	return _combo

## Advances the shake by `delta` seconds. `_process` calls it; the unit test calls it directly.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	_since_match += delta
	if _combo > 0 and _since_match > COMBO_WINDOW_S:
		_combo = 0
		combo_changed.emit(0)   # combo ended: future SFX hook (silence the riser here)
	trauma = decayed(trauma, delta)
	_time += delta * NOISE_SPEED
	_apply()

func _process(delta: float) -> void:
	advance(delta)

# --- Transform --------------------------------------------------------------------------

func _apply() -> void:
	if not is_instance_valid(target):
		return
	if not SHAKE_ENABLED or trauma <= 0.0:
		_restore()
		return
	if not _applied:
		_rest_position = target.position
		_rest_rotation = target.rotation
		target.pivot_offset = target.size * 0.5
		_applied = true
	var noise := Vector2(_noise_sample(0.0), _noise_sample(1000.0))
	target.position = _rest_position + offset_for(trauma, noise)
	target.rotation = _rest_rotation + rotation_for(trauma, _noise_sample(2000.0))

# Writes the exact rest transform back, so repeated shakes never drift the layout.
func _restore() -> void:
	if not _applied or not is_instance_valid(target):
		return
	target.position = _rest_position
	target.rotation = _rest_rotation
	_applied = false

func _noise_sample(axis_seed: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = NOISE_SEED
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.fractal_octaves = 1
	return clampf(_noise.get_noise_2d(_time, axis_seed) * NOISE_GAIN, -1.0, 1.0)
