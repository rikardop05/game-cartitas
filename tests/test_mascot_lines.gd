extends RefCounted

# Mascot line picker (legacy bear / whale / duck + neutral hero): pure logic,
# driven by a seeded rng.

const DRAWS := 60

func _picker(seed_value: int = 7, for_character: String = "") -> MascotLines:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return MascotLines.new(rng, for_character) if for_character != "" else MascotLines.new(rng)

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

func _pools(host: String) -> Dictionary:
	return MascotLines.POOLS[host]

func test_every_event_returns_a_localized_key() -> void:
	for host in MascotLines.CHARACTERS:
		var lines := _picker(7, host)
		for entry in _contexts():
			for i in DRAWS:
				var key := lines.pick(entry["event"], entry["context"])
				var strings: Dictionary = Localizer.STRINGS.get(key, {})
				Assert.is_true(key != "", "%s %s returns a key for %s" % [entry["event"], str(entry["context"]), host])
				Assert.is_true(key.begins_with("npc_%s_" % host), "%s speaks its own family for %s" % [key, host])
				Assert.is_true(strings.has("en") and str(strings["en"]) != "", "%s has en text" % key)
				Assert.is_true(strings.has("pt") and str(strings["pt"]) != "", "%s has pt text" % key)

func test_every_pool_line_exists_in_both_languages() -> void:
	for host in MascotLines.CHARACTERS:
		var pools := _pools(host)
		for id in pools:
			Assert.is_true(pools[id].size() > 1, "pool %s/%s has more than one line" % [host, id])
			for key in pools[id]:
				Assert.is_true(str(key).begins_with("npc_%s_" % host), "%s belongs to %s" % [key, host])
				var strings: Dictionary = Localizer.STRINGS.get(key, {})
				Assert.is_true(strings.has("en") and strings.has("pt"), "%s has en and pt" % key)

func test_declared_events_all_have_a_pool() -> void:
	for event in MascotLines.EVENTS:
		Assert.is_true(MascotLines.pool_id(event, {"stars": 2}) != "", "event %s has a pool" % event)

func test_every_character_covers_the_required_events() -> void:
	for host in MascotLines.CHARACTERS:
		for event in ["intro", "round_intro", "idle_tip", "idle_tip_endless", "match", "zone_warning", "power_used", "win_1", "win_2", "win_3", "lose", "lose_timeout"]:
			Assert.is_true(_pools(host).has(event), "%s has a %s pool" % [host, event])

func test_each_character_returns_its_own_line_family() -> void:
	var seen := {}
	for host in MascotLines.CHARACTERS:
		var lines := _picker(11, host)
		var family := {}
		for entry in _contexts():
			for i in 8:
				family[lines.pick(entry["event"], entry["context"])] = true
		for key in family:
			Assert.is_true(str(key).begins_with("npc_%s_" % host), "%s speaks only as %s" % [key, host])
			Assert.is_false(seen.has(key), "%s is not shared with another character" % key)
			seen[key] = true

func test_unknown_character_falls_back_to_the_default_host() -> void:
	var fallback_pools := MascotLines.pools_for("goblin")
	Assert.equals(fallback_pools, MascotLines.POOLS[MascotLines.DEFAULT_CHARACTER], "an unknown character uses the default pools")
	var picker := MascotLines.new(RandomNumberGenerator.new(), "goblin")
	Assert.equals(picker.character, MascotLines.DEFAULT_CHARACTER, "the picker normalizes an unknown character")
	for entry in _contexts():
		for i in 12:
			var key := picker.pick(entry["event"], entry["context"], "goblin")
			Assert.is_true(key.begins_with("npc_%s_" % MascotLines.DEFAULT_CHARACTER), "%s falls back safely" % key)
			var strings: Dictionary = Localizer.STRINGS.get(key, {})
			Assert.is_true(strings.has("en") and strings.has("pt"), "%s has en and pt" % key)

func test_never_repeats_the_previous_line_of_a_pool() -> void:
	for seed_value in [1, 2, 3, 99]:
		for host in MascotLines.CHARACTERS:
			var lines := _picker(seed_value, host)
			for entry in _contexts():
				var previous := ""
				for i in DRAWS:
					var key := lines.pick(entry["event"], entry["context"])
					Assert.not_equals(key, previous, "no immediate repeat for %s/%s (seed %d, draw %d)" % [host, entry["event"], seed_value, i])
					previous = key

# Regression: one shared "last line" let a pool repeat itself after other pools were drawn
# in between (idle_tip X, a match pick, then an idle_tip refill could start with X again).
func test_interleaved_pools_never_repeat_their_own_previous_line() -> void:
	var entries := _contexts()
	for seed_value in range(1, 41):
		for host in MascotLines.CHARACTERS:
			var lines := _picker(seed_value, host)
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
			Assert.equals(repeats, 0, "no pool repeated its previous line when interleaved (%s, seed %d)" % [host, seed_value])

# Two hosts share one session picker: their bags must not interfere.
func test_one_picker_keeps_characters_independent() -> void:
	var lines := _picker(21)
	for i in 40:
		var bear := lines.pick("idle_tip", {}, "bear")
		var whale := lines.pick("idle_tip", {}, "whale")
		Assert.is_true(bear.begins_with("npc_bear_"), "%s is a bear line" % bear)
		Assert.is_true(whale.begins_with("npc_whale_"), "%s is a whale line" % whale)

func test_endless_tips_leave_out_the_campaign_only_tip() -> void:
	for host in MascotLines.CHARACTERS:
		var stars_tip := "npc_%s_tip_4" % host
		var tips: Array = _pools(host)["idle_tip"]
		var endless: Array = _pools(host)["idle_tip_endless"]
		Assert.is_true(tips.has(stars_tip), "%s keeps the stars tip in the campaign" % host)
		Assert.is_false(endless.has(stars_tip), "%s leaves the stars tip out of Endless" % host)
		Assert.equals(endless.size(), tips.size() - 1, "%s's Endless pool is the campaign pool minus that tip" % host)
		for key in endless:
			Assert.is_true(tips.has(key), "%s is also a campaign tip" % key)
		var lines := _picker(7, host)
		for i in 200:
			Assert.not_equals(lines.pick("idle_tip_endless"), stars_tip, "%s never says the stars tip in Endless (draw %d)" % [host, i])

func test_every_line_is_used_before_any_repeats() -> void:
	for host in MascotLines.CHARACTERS:
		var lines := _picker(7, host)
		var pool: Array = _pools(host)["idle_tip"]
		var seen := {}
		for i in pool.size():
			seen[lines.pick("idle_tip")] = true
		Assert.equals(seen.size(), pool.size(), "%s's full rotation shows every tip once" % host)

func test_win_lines_differ_by_stars() -> void:
	for host in MascotLines.CHARACTERS:
		var lines := _picker(7, host)
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
						Assert.is_false(by_stars[b].has(key), "%s win line %s is not shared by %d and %d stars" % [host, key, a, b])
	Assert.equals(MascotLines.pool_id("win", {"stars": 0}), "win_1", "stars below 1 clamp to the 1-star pool")
	Assert.equals(MascotLines.pool_id("win", {"stars": 9}), "win_3", "stars above 3 clamp to the 3-star pool")

func test_timeout_defeat_has_its_own_lines() -> void:
	for host in MascotLines.CHARACTERS:
		var lines := _picker(7, host)
		var plain := lines.pick("lose")
		var timed := lines.pick("lose", {"timeout": true})
		Assert.not_equals(plain, timed, "%s timeout loss uses a different pool" % host)
		Assert.is_true(_pools(host)["lose_timeout"].has(timed), "%s timeout key comes from lose_timeout" % host)

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
	for i in 4:
		first_a.append(a.pick("idle_tip"))
		first_b.append(b.pick("idle_tip"))
	for i in 3:
		first_a.append(a.pick("match"))
		first_b.append(b.pick("match"))
	Assert.not_equals(first_a, first_b, "seeds shuffle the tip order differently")

func test_unknown_event_returns_empty_string() -> void:
	var lines := _picker()
	Assert.equals(lines.pick("nope"), "", "unknown event")
	Assert.equals(lines.pick(""), "", "empty event")
	Assert.equals(MascotLines.pool_id("nope"), "", "unknown pool id")

# The start-of-level instruction is not a pool line: the level screen has the mascot (or a
# standalone bubble) say Localizer's "instruction" key, so it must exist in both languages and
# stay short enough for the narrow free area it is shown in.
func test_instruction_line_is_localized_and_short() -> void:
	var strings: Dictionary = Localizer.STRINGS.get("instruction", {})
	for lang in ["en", "pt"]:
		Assert.is_true(strings.has(lang) and str(strings[lang]) != "", "instruction has %s text" % lang)
		Assert.is_true(str(strings[lang]).length() <= 60, "instruction (%s) fits a short bubble" % lang)

# --- neutral hero family ---------------------------------------------------------

func test_hero_family_covers_every_event_with_neutral_keys() -> void:
	var lines := _picker(7, MascotLines.HERO_CHARACTER)
	for entry in _contexts():
		for i in 40:
			var key: String = lines.pick(entry["event"], entry["context"])
			Assert.is_true(key != "", "hero has a line for %s" % entry["event"])
			if entry["event"] == "intro":
				Assert.is_true(key.begins_with("hero_intro_"), "hero intro uses hero_intro_* (got %s)" % key)
			else:
				Assert.is_true(key.begins_with("mascot_"), "hero %s uses a neutral mascot_* line (got %s)" % [entry["event"], key])
			var strings: Dictionary = Localizer.STRINGS.get(key, {})
			Assert.is_true(strings.has("en") and strings.has("pt"), "%s has en and pt" % key)

func test_hero_family_has_all_pools_and_uses_no_proper_names() -> void:
	var pools: Dictionary = MascotLines.pools_for(MascotLines.HERO_CHARACTER)
	for event in ["intro", "round_intro", "idle_tip", "idle_tip_endless", "match", "zone_warning", "power_used", "win_1", "win_2", "win_3", "lose", "lose_timeout"]:
		Assert.is_true(pools.has(event), "hero has a %s pool" % event)
	var forbidden := ["Ace", "Bruno", "Marlow", "Mallard"]
	for id in pools:
		for key in pools[id]:
			Assert.is_false(str(key).begins_with("npc_"), "hero never borrows an NPC key (%s)" % key)
			var strings: Dictionary = Localizer.STRINGS.get(key, {})
			for lang in ["en", "pt"]:
				var text := str(strings.get(lang, ""))
				for name in forbidden:
					Assert.is_false(text.contains(name), "%s (%s) does not use the proper name %s" % [key, lang, name])

func test_hero_intro_keys_are_neutral_and_present() -> void:
	for i in range(1, 4):
		var key := "hero_intro_%d" % i
		var strings: Dictionary = Localizer.STRINGS.get(key, {})
		Assert.is_true(strings.has("en") and strings.has("pt"), "%s exists in en and pt" % key)
		for lang in ["en", "pt"]:
			var text := str(strings[lang])
			Assert.is_true(text.length() <= 80, "%s (%s) fits a bubble" % [key, lang])
			Assert.is_false(text.contains("Ace"), "%s (%s) is neutral" % [key, lang])

func test_hero_family_does_not_repeat_and_keeps_endless_stars_tip_out() -> void:
	var lines := _picker(11, MascotLines.HERO_CHARACTER)
	for entry in _contexts():
		var previous := ""
		for i in DRAWS:
			var key: String = lines.pick(entry["event"], entry["context"])
			Assert.not_equals(key, previous, "hero %s never repeats immediately" % entry["event"])
			previous = key
	var pools: Dictionary = MascotLines.pools_for(MascotLines.HERO_CHARACTER)
	var tips: Array = pools["idle_tip"]
	var endless: Array = pools["idle_tip_endless"]
	Assert.is_true(tips.has("mascot_tip_11"), "hero keeps the stars tip in the campaign")
	Assert.is_false(endless.has("mascot_tip_11"), "hero leaves the stars tip out of Endless")
	Assert.equals(endless.size(), tips.size() - 1, "hero's Endless tips are the campaign tips minus that one")
	for i in 200:
		Assert.not_equals(lines.pick("idle_tip_endless"), "mascot_tip_11", "hero never says the stars tip in Endless")
