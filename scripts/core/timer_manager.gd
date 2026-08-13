class_name TimerManager
extends RefCounted

var _elapsed_msec: int = 0
var _running: bool = false
var _last_tick: int = 0

func start() -> void:
	_running = true
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
