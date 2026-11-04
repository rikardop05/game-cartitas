extends RefCounted

# Phase R: the level clock. A level must open at 00:00, so the screen holds the clock stopped at
# zero while it builds and deals the level and only then starts it (reset() + resume()). These
# checks are pure: no scene tree and no audio device needed.

func test_start_zeroes_the_clock_and_runs() -> void:
	var timer := TimerManager.new()
	timer.set_elapsed_seconds(42.0)
	timer.start()
	Assert.equals(timer.elapsed_seconds(), 0.0, "start() puts the clock back to zero")
	Assert.is_true(timer.is_running(), "start() makes the clock run")
	OS.delay_msec(5)
	Assert.is_true(timer.elapsed_seconds() > 0.0, "a running clock advances")
	timer.stop()

func test_reset_zeroes_the_clock_and_keeps_it_stopped() -> void:
	var timer := TimerManager.new()
	timer.set_elapsed_seconds(12.5)
	timer.reset()
	Assert.equals(timer.elapsed_seconds(), 0.0, "reset() puts the clock back to zero")
	Assert.is_false(timer.is_running(), "reset() leaves the clock stopped")
	OS.delay_msec(5)
	Assert.equals(timer.elapsed_seconds(), 0.0, "a stopped clock never advances, however long it waits")

func test_resume_after_reset_starts_from_zero() -> void:
	# The level screen resets the clock while the level is built and resumes it when the player
	# can play: nothing before that moment may be charged to the player.
	var timer := TimerManager.new()
	timer.start()
	OS.delay_msec(6)
	timer.reset()
	OS.delay_msec(6)
	Assert.equals(timer.elapsed_seconds(), 0.0, "the pre-play time is dropped by reset()")
	timer.resume()
	Assert.is_true(timer.is_running(), "resume() starts the held clock")
	Assert.is_true(timer.elapsed_seconds() < 0.05, "it starts from zero, not from the held time")
	timer.stop()

func test_pause_and_resume_keep_the_banked_time() -> void:
	var timer := TimerManager.new()
	timer.start()
	OS.delay_msec(6)
	timer.pause()
	var banked := timer.elapsed_seconds()
	Assert.is_true(banked > 0.0, "the played time is banked while paused")
	OS.delay_msec(6)
	Assert.equals(timer.elapsed_seconds(), banked, "a paused clock does not advance")
	timer.resume()
	Assert.is_true(timer.is_running(), "resume() continues the clock")
	Assert.is_true(timer.elapsed_seconds() >= banked, "the banked time is kept, not dropped")
	timer.stop()

func test_stop_keeps_the_final_time_and_ignores_later_resumes_until_started() -> void:
	var timer := TimerManager.new()
	timer.start()
	OS.delay_msec(6)
	timer.stop()
	var final_time := timer.elapsed_seconds()
	Assert.is_false(timer.is_running(), "stop() stops the clock")
	OS.delay_msec(6)
	Assert.equals(timer.elapsed_seconds(), final_time, "a stopped clock keeps its final time")
	timer.start()
	Assert.equals(timer.elapsed_seconds(), 0.0, "a new level still starts from zero")

func test_set_elapsed_seconds_moves_the_clock() -> void:
	var timer := TimerManager.new()
	timer.set_elapsed_seconds(90.5)
	Assert.is_true(absf(timer.elapsed_seconds() - 90.5) < 0.01, "set_elapsed_seconds() moves the clock")
	timer.stop()
