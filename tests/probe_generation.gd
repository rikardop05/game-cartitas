extends SceneTree

# Load-time + generation-quality probe. Loads every parametric level headless
# and asserts: no load error, validator passes, solvable, and that total
# generation stays under the 1.5s budget when possible.

const BoardChecks = preload("res://tests/board_checks.gd")
const LOAD_BUDGET_MS := 1500

func _init() -> void:
	# Profile seeds keep the budget measurement reproducible in CI.
	LevelLoader.deterministic = true
	var total_generation_ms := 0
	var total_wall_ms := 0
	var started_all := Time.get_ticks_msec()
	for id in LevelLoader.load_all_level_ids():
		var started := Time.get_ticks_msec()
		var level: Dictionary = LevelLoader.load_level(id)
		var wall := Time.get_ticks_msec() - started
		total_wall_ms += wall
		if level.has("error"):
			printerr("PROBE FAIL: level %s error: %s" % [id, str(level["error"])])
			quit(1)
			return
		var metrics: Dictionary = level["generation_metrics"]
		var gen_ms := int(metrics.get("generation_time_ms", 0))
		total_generation_ms += gen_ms
		var v := LevelValidator.validate(level)
		if not v["valid"]:
			printerr("PROBE FAIL: level %s invalid: %s" % [id, str(v["errors"])])
			quit(1)
			return
		if not SolvabilityChecker.is_solvable(level):
			printerr("PROBE FAIL: level %s not solvable" % id)
			quit(1)
			return
		# Same structural bar as the suites: grid-aligned, supported, no overlap.
		var problems := BoardChecks.problems(level)
		if not problems.is_empty():
			printerr("PROBE FAIL: level %s board structure: %s" % [id, str(problems)])
			quit(1)
			return
		print("L%s gen=%dms wall=%dms attempts=%d seed=%d cards=%d layers=%s free=%d(%.2f,%s) board=%.0fx%.0f portrait=%s landscape=%s (card %.1f/%.1fpx)" % [
			id, gen_ms, wall, int(metrics.get("attempts", 0)), int(metrics.get("seed_used", 0)),
			(level["cards"] as Array).size(), str(metrics.get("cards_per_layer", [])),
			int(metrics.get("free_cards", 0)), float(metrics.get("free_ratio", 0)), str(metrics.get("free_ratio_ok", false)),
			float(level["board_width"]), float(level["board_height"]),
			str(metrics.get("fits_portrait", false)), str(metrics.get("fits_landscape", false)),
			float(metrics.get("min_card_px_portrait", 0)), float(metrics.get("min_card_px_landscape", 0)),
		])
	var total_wall := Time.get_ticks_msec() - started_all
	print("TOTAL generation=%dms wall=%dms (budget %dms)" % [total_generation_ms, total_wall, LOAD_BUDGET_MS])
	if total_generation_ms > LOAD_BUDGET_MS:
		printerr("PROBE FAIL: total generation %dms exceeds budget %dms" % [total_generation_ms, LOAD_BUDGET_MS])
		quit(1)
		return
	print("PROBE GENERATION OK")
	quit(0)