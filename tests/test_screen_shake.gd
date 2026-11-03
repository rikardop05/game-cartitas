extends RefCounted

# Phase Q: combo camera shake. The pure rules (combo window, trauma ladder, decay, amplitude) are
# checked without a scene tree; the transform test drives advance() by hand on a plain Control.

const EPS := 0.0001

# --- Combo window ------------------------------------------------------------------------

func test_combo_window_chains_matches_and_resets() -> void:
	Assert.equals(ScreenShake.next_combo(0, INF), 1, "the first match starts combo 1")
	Assert.equals(ScreenShake.next_combo(0, 0.0), 1, "a fresh instance is still combo 1")
	Assert.equals(ScreenShake.next_combo(1, 0.2), 2, "a match right after the previous one chains")
	Assert.equals(ScreenShake.next_combo(4, ScreenShake.COMBO_WINDOW_S), 5,
		"the window is inclusive at its edge")
	Assert.equals(ScreenShake.next_combo(4, ScreenShake.COMBO_WINDOW_S + 0.01), 1,
		"a match after the window starts a new combo")
	Assert.equals(ScreenShake.next_combo(9, 30.0), 1, "a long pause always restarts the combo")

# --- Trauma ladder, ceiling and decay ----------------------------------------------------

func test_trauma_ladder_is_monotonic_and_capped() -> void:
	Assert.equals(ScreenShake.trauma_for(0), 0.0, "combo 0 adds no trauma")
	Assert.is_true(absf(ScreenShake.trauma_for(1) - ScreenShake.COMBO_TRAUMA[0]) < EPS,
		"combo 1 adds the first ladder step")
	var previous := -1.0
	for level in range(1, 9):
		var trauma := ScreenShake.trauma_for(level)
		Assert.is_true(trauma >= previous, "the ladder never shrinks (level %d)" % level)
		Assert.is_true(trauma <= ScreenShake.TRAUMA_CEILING + EPS,
			"no step exceeds the ceiling (level %d: %.2f)" % [level, trauma])
		previous = trauma
	Assert.is_true(absf(ScreenShake.trauma_for(5) - ScreenShake.trauma_for(12)) < EPS,
		"levels past the ladder repeat its last step")
	Assert.is_true(ScreenShake.COMBO_TRAUMA.size() >= 3, "the ladder has room to grow")

func test_stacked_matches_never_pass_the_ceiling() -> void:
	var host := Node.new()
	var shake := ScreenShake.attach(host, null)
	var seen := 0
	for i in 12:
		shake.add_match()
		seen += 1
		Assert.is_true(shake.trauma <= ScreenShake.TRAUMA_CEILING + EPS,
			"a 12-match combo stays under the ceiling (%.3f)" % shake.trauma)
	Assert.equals(seen, 12, "every match was counted")
	Assert.equals(shake.combo_level(), 12, "the combo level keeps climbing")
	Assert.is_true(absf(shake.trauma - ScreenShake.TRAUMA_CEILING) < EPS,
		"a long combo sits exactly on the ceiling")
	host.queue_free()

func test_trauma_decays_to_zero() -> void:
	Assert.is_true(absf(ScreenShake.decayed(0.6, 0.2) - (0.6 - ScreenShake.TRAUMA_DECAY_PER_S * 0.2)) < EPS,
		"decay is linear in time")
	Assert.equals(ScreenShake.decayed(0.1, 1.0), 0.0, "decay never goes negative")
	Assert.equals(ScreenShake.decayed(0.5, 0.0), 0.5, "no time passes, no decay")
	Assert.equals(ScreenShake.decayed(0.5, -2.0), 0.5, "a negative delta is ignored")
	Assert.is_true(ScreenShake.TRAUMA_DECAY_PER_S > 0.0, "trauma always comes back down")

# --- Shake amplitude ---------------------------------------------------------------------

func test_amplitude_grows_with_trauma_and_stays_within_the_maxima() -> void:
	Assert.equals(ScreenShake.amplitude_for(0.0), 0.0, "no trauma, no movement")
	Assert.is_true(absf(ScreenShake.amplitude_for(0.6) - 0.36) < EPS, "amplitude is trauma squared")
	Assert.is_true(absf(ScreenShake.amplitude_for(1.5) - 1.0) < EPS, "amplitude is clamped to 1")
	var single := ScreenShake.offset_for(ScreenShake.trauma_for(1), Vector2.ONE).length()
	var combo := ScreenShake.offset_for(ScreenShake.trauma_for(4), Vector2.ONE).length()
	var ceiling := ScreenShake.offset_for(ScreenShake.TRAUMA_CEILING, Vector2.ONE).length()
	Assert.is_true(single < combo, "a combo shakes harder than a single match (%.2f -> %.2f px)" % [single, combo])
	Assert.is_true(combo <= ceiling + EPS, "a combo never out-shakes the ceiling")
	Assert.is_true(ceiling <= ScreenShake.SHAKE_MAX_OFFSET_PX * 2.0, "both axes stay inside the max offset")
	Assert.is_true(ScreenShake.rotation_for(1.0, 1.0) <= deg_to_rad(ScreenShake.SHAKE_MAX_ROT_DEG) + EPS,
		"rotation never exceeds its maximum")

# --- Signal (the future combo-SFX hook) --------------------------------------------------

func test_combo_signal_reports_each_level_and_the_expiry() -> void:
	var host := Node.new()
	var shake := ScreenShake.attach(host, null)
	var levels: Array[int] = []
	shake.combo_changed.connect(func(level: int) -> void: levels.append(level))
	shake.add_match()
	shake.advance(0.4)
	shake.add_match()
	shake.advance(0.4)
	shake.add_match()
	Assert.equals(levels, [1, 2, 3] as Array[int], "each match reports its combo level")
	Assert.equals(shake.combo_level(), 3, "combo level 3 is running")
	shake.advance(ScreenShake.COMBO_WINDOW_S + 0.1)
	Assert.equals(levels, [1, 2, 3, 0] as Array[int], "the combo expiring reports level 0 once")
	Assert.equals(shake.combo_level(), 0, "the combo is cleared after the window")
	shake.advance(1.0)
	Assert.equals(levels, [1, 2, 3, 0] as Array[int], "level 0 is not repeated every frame")
	host.queue_free()

# --- Transform on the content container --------------------------------------------------

func test_rest_transform_is_restored_exactly() -> void:
	var host := Node.new()
	var target := Control.new()
	target.size = Vector2(640.0, 360.0)
	target.position = Vector2(3.0, 5.0)
	host.add_child(target)
	var shake := ScreenShake.attach(host, target)
	Assert.is_true(shake.target == target, "the shake targets the content container")

	# Nothing moves while there is no trauma (the layout keeps owning the rest position).
	shake.advance(0.2)
	Assert.equals(target.position, Vector2(3.0, 5.0), "no match, no movement")
	Assert.equals(target.rotation, 0.0, "no match, no rotation")

	shake.add_match()
	shake.advance(1.0 / 60.0)
	var moved := target.position.distance_to(Vector2(3.0, 5.0))
	Assert.is_true(moved > 0.0, "a match nudges the content (%.3f px)" % moved)
	Assert.is_true(moved <= ScreenShake.SHAKE_MAX_OFFSET_PX * 1.5, "the nudge stays small (%.3f px)" % moved)
	Assert.is_true(absf(target.rotation) <= deg_to_rad(ScreenShake.SHAKE_MAX_ROT_DEG) + EPS,
		"the rotation stays tiny")

	var guard := 0
	while shake.trauma > 0.0 and guard < 600:
		shake.advance(1.0 / 60.0)
		guard += 1
	Assert.equals(shake.trauma, 0.0, "trauma decays to exactly 0")
	Assert.equals(target.position, Vector2(3.0, 5.0), "the rest position is restored exactly")
	Assert.equals(target.rotation, 0.0, "the rest rotation is restored exactly")

	# A second shake of the same container must not drift it.
	shake.add_match()
	guard = 0
	while shake.trauma > 0.0 and guard < 600:
		shake.advance(1.0 / 60.0)
		guard += 1
	Assert.equals(target.position, Vector2(3.0, 5.0), "repeated shakes never drift the layout")
	Assert.equals(target.rotation, 0.0, "repeated shakes leave no rotation behind")

	# A held combo keeps shaking: the trauma of the next match starts from the ceiling.
	var combo_before := shake.combo_level()
	shake.add_match()
	shake.add_match()
	Assert.equals(shake.combo_level(), combo_before + 2, "two quick matches extend the combo")
	Assert.is_true(shake.trauma > ScreenShake.trauma_for(1), "the second match adds to the first")
	host.queue_free()
