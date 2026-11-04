class_name TimerManager
extends RefCounted

var _elapsed_msec: int = 0
var _running: bool = false
var _last_tick: int = 0

func start() -> void:
	_elapsed_msec = 0
	_running = true
	_last_tick = Time.get_ticks_msec()

# Puts the clock back to 0 and leaves it stopped. The Level screen resets it while it builds and
# deals the level, then resumes() it on the first playable frame, so the build/prewarm/deal time is
# never charged to the player and every level really opens at 00:00.
func reset() -> void:
	_elapsed_msec = 0
	_running = false
	_last_tick = Time.get_ticks_msec()

func _update() -> void:
	if _running:
		var now := Time.get_ticks_msec()
		_elapsed_msec += now - _last_tick
		_last_tick = now

func pause() -> void:
	_update()
	_running = false

func resume() -> void:
	if not _running:
		_running = true
		_last_tick = Time.get_ticks_msec()

func stop() -> void:
	_update()
	_running = false

func is_running() -> bool:
	return _running

func elapsed_seconds() -> float:
	_update()
	return _elapsed_msec / 1000.0

func set_elapsed_seconds(seconds: float) -> void:
	_elapsed_msec = int(seconds * 1000)
