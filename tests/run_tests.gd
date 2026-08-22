extends SceneTree

const SUITE_PATHS := [
	"res://tests/test_card.gd",
	"res://tests/test_clearing_zone.gd",
	"res://tests/test_board.gd",
	"res://tests/test_deck.gd",
	"res://tests/test_game_controller.gd",
	"res://tests/test_move_result.gd",
	"res://tests/test_level_snapshot.gd",
	"res://tests/test_progress.gd",
"res://tests/test_level.gd",
	"res://tests/test_integration.gd",
	"res://tests/test_layout.gd",
	"res://tests/test_difficulty_profile.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_envelope.gd",
]

func _init() -> void:
	var total := 0
	var failed := 0
	var load_failures := 0
	for path in SUITE_PATHS:
		var suite_name: String = path.get_file().get_basename()
		var suite_script: GDScript = load(path)
		if suite_script == null or not suite_script.can_instantiate():
			load_failures += 1
			failed += 1
			print("ERROR  %s - failed to load/compile suite script" % suite_name)
			continue
		var suite: RefCounted = suite_script.new()
		if suite == null or not is_instance_valid(suite):
			load_failures += 1
			failed += 1
			print("ERROR  %s - suite could not be instantiated" % suite_name)
			continue
		var test_methods: Array[String] = []
		for method in suite.get_method_list():
			var mname: String = String(method["name"])
			if mname.begins_with("test_"):
				test_methods.append(mname)
		if test_methods.is_empty():
			load_failures += 1
			failed += 1
			print("ERROR  %s - no test_ methods found (invalid suite)" % suite_name)
			continue
		for mname in test_methods:
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
	if load_failures > 0:
		print("ERROR: %d suite(s) failed to load" % load_failures)
	print("RESULTS: %d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
