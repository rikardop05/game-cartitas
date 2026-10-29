extends RefCounted

# Mascot line picker (T7.8): pure logic, driven by a seeded rng.

const DRAWS := 60

func _picker(seed_value: int = 7) -> MascotLines:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return MascotLines.new(rng)

func _contexts() -> Array:
	return [
		{"event": "intro", "context": {}},
		{"event": "idle_tip", "context": {}},
		{"event": "idle_tip_endless", "context": {}},
		{"event": "match", "context": {}},
		{"event": "zone_warning", "context": {}},
		{"event": "power_used", "context": {}},
		{"event": "round_intro", "context": {}},
		{"event": "win", "context": {"stars": 1}},
		{"event": "win", "context": {"stars": 2}},
		{"event": "win", "context": {"stars": 3}},
		{"event": "lose", "context": {}},
		{"event": "lose", "context": {"timeout": true}},
	]

func test_every_event_returns_a_localized_key() -> void:
	var lines := _picker()
	for entry in _contexts():
		for i in DRAWS:
			var key := lines.pick(entry["event"], entry["context"])
			var strings: Dictionary = Localizer.STRINGS.get(key, {})
			Assert.is_true(key != "", "%s %s returns a key" % [entry["event"], str(entry["context"])])
			Assert.is_true(strings.has("en") and str(strings["en"]) != "", "%s has en text" % key)
			Assert.is_true(strings.has("pt") and str(strings["pt"]) != "", "%s has pt text" % key)

func test_every_pool_line_exists_in_both_languages() -> void:
	for id in MascotLines.POOLS:
		Assert.is_true(MascotLines.POOLS[id].size() > 1, "pool %s has more than one line" % id)
		for key in MascotLines.POOLS[id]:
			var strings: Dictionary = Localizer.STRINGS.get(key, {})
			Assert.is_true(strings.has("en") and strings.has("pt"), "%s has en and pt" % key)

func test_declared_events_all_have_a_pool() -> void:
	for event in MascotLines.EVENTS:
		Assert.is_true(MascotLines.pool_id(event, {"stars": 2}) != "", "event %s has a pool" % event)

func test_never_repeats_the_previous_line_of_a_pool() -> void:
	for seed_value in [1, 2, 3, 99]:
		var lines := _picker(seed_value)
		for entry in _contexts():
			var previous := ""
			for i in DRAWS:
				var key := lines.pick(entry["event"], entry["context"])
				Assert.not_equals(key, previous, "no immediate repeat for %s (seed %d, draw %d)" % [entry["event"], seed_value, i])
				previous = key

# Regression: one shared "last line" let a pool repeat itself after other pools were drawn
# in between (idle_tip X, a match pick, then an idle_tip refill could start with X again).
func test_interleaved_pools_never_repeat_their_own_previous_line() -> void:
	var entries := _contexts()
	for seed_value in range(1, 41):
		var lines := _picker(seed_value)
		var chooser := RandomNumberGenerator.new()
		chooser.seed = seed_value * 7919
		var last := {}
		var repeats := 0
		for i in 600:
			var entry: Dictionary = entries[chooser.randi_range(0, entries.size() - 1)]
			var id := MascotLines.pool_id(entry["event"], entry["context"])
			var key := lines.pick(entry["event"], entry["context"])
			if last.get(id, "") == key:
				repeats += 1
			last[id] = key
		Assert.equals(repeats, 0, "no pool repeated its previous line when interleaved (seed %d)" % seed_value)

func test_endless_tips_leave_out_the_campaign_only_tip() -> void:
	var tips: Array = MascotLines.POOLS["idle_tip"]
	var endless: Array = MascotLines.POOLS["idle_tip_endless"]
	Assert.is_true(tips.has("mascot_tip_11"), "the campaign pool keeps the stars tip")
	Assert.is_false(endless.has("mascot_tip_11"), "the Endless pool has no stars tip")
	Assert.equals(endless.size(), tips.size() - 1, "the Endless pool is the campaign pool minus that tip")
	for key in endless:
		Assert.is_true(tips.has(key), "%s is also a campaign tip" % key)
	var lines := _picker()
	for i in 200:
		Assert.not_equals(lines.pick("idle_tip_endless"), "mascot_tip_11", "Endless never says the stars tip (draw %d)" % i)

func test_every_line_is_used_before_any_repeats() -> void:
	var lines := _picker()
	var pool: Array = MascotLines.POOLS["idle_tip"]
	var seen := {}
	for i in pool.size():
		seen[lines.pick("idle_tip")] = true
	Assert.equals(seen.size(), pool.size(), "a full rotation shows every tip once")

func test_win_lines_differ_by_stars() -> void:
	var lines := _picker()
	var by_stars := {}
	for stars in [1, 2, 3]:
		by_stars[stars] = []
		for i in 20:
			var key := lines.pick("win", {"stars": stars})
			if not by_stars[stars].has(key):
				by_stars[stars].append(key)
	for a in [1, 2, 3]:
		for b in [1, 2, 3]:
			if a < b:
				for key in by_stars[a]:
					Assert.is_false(by_stars[b].has(key), "win line %s is not shared by %d and %d stars" % [key, a, b])
	Assert.equals(MascotLines.pool_id("win", {"stars": 0}), "win_1", "stars below 1 clamp to the 1-star pool")
	Assert.equals(MascotLines.pool_id("win", {"stars": 9}), "win_3", "stars above 3 clamp to the 3-star pool")

func test_timeout_defeat_has_its_own_lines() -> void:
	var lines := _picker()
	var plain := lines.pick("lose")
	var timed := lines.pick("lose", {"timeout": true})
	Assert.not_equals(plain, timed, "timeout loss uses a different pool")
	Assert.is_true(MascotLines.POOLS["lose_timeout"].has(timed), "timeout key comes from lose_timeout")

func test_same_seed_gives_the_same_sequence() -> void:
	var a := _picker(1234)
	var b := _picker(1234)
	for i in DRAWS:
		Assert.equals(a.pick("idle_tip"), b.pick("idle_tip"), "idle_tip draw %d matches" % i)
		Assert.equals(a.pick("win", {"stars": 3}), b.pick("win", {"stars": 3}), "win draw %d matches" % i)

func test_different_seeds_change_the_order() -> void:
	var a := _picker(1)
	var b := _picker(2)
	var first_a: Array = []
	var first_b: Array = []
	for i in 11:
		first_a.append(a.pick("idle_tip"))
		first_b.append(b.pick("idle_tip"))
	Assert.not_equals(first_a, first_b, "seeds shuffle the tip order differently")

func test_unknown_event_returns_empty_string() -> void:
	var lines := _picker()
	Assert.equals(lines.pick("nope"), "", "unknown event")
	Assert.equals(lines.pick(""), "", "empty event")
	Assert.equals(MascotLines.pool_id("nope"), "", "unknown pool id")

# The start-of-level instruction is not a pool line: the level screen has Ace (or a standalone
# bubble) say Localizer's "instruction" key, so it must exist in both languages and stay short
# enough for the narrow free area it is shown in.
func test_instruction_line_is_localized_and_short() -> void:
	var strings: Dictionary = Localizer.STRINGS.get("instruction", {})
	for lang in ["en", "pt"]:
		Assert.is_true(strings.has(lang) and str(strings[lang]) != "", "instruction has %s text" % lang)
		Assert.is_true(str(strings[lang]).length() <= 60, "instruction (%s) fits a short bubble" % lang)
