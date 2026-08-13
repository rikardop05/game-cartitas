extends SceneTree

const SUITES := [
	preload("res://tests/test_card.gd"),
	preload("res://tests/test_clearing_zone.gd"),
	preload("res://tests/test_board.gd"),
	preload("res://tests/test_deck.gd"),
	preload("res://tests/test_game_controller.gd"),
	preload("res://tests/test_progress.gd"),
	preload("res://tests/test_level.gd"),
	preload("res://tests/test_integration.gd"),
	preload("res://tests/test_layout.gd"),
]

func _init() -> void:
	var total := 0
	var failed := 0
	for suite_script in SUITES:
		var suite: RefCounted = suite_script.new()
		var suite_name: String = suite_script.resource_path.get_file().get_basename()
		for method in suite.get_method_list():
			var mname: String = method["name"]
			if not mname.begins_with("test_"):
				continue
			Assert.clear()
			total += 1
			suite.call(mname)
			if Assert.failures.is_empty():
				print("PASS  %s.%s" % [suite_name, mname])
			else:
				failed += 1
				for f in Assert.failures:
					print("FAIL  %s.%s - %s" % [suite_name, mname, f])
	print("")
	print("RESULTS: %d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
