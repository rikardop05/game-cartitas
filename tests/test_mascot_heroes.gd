extends RefCounted

# Phase map, delivered portraits and per-hero expression sets for the hero mascot.
# Uses the data-only HeroRoster so it compiles in the headless runner (no Game).

const CAMPAIGN := {
	"1": "cat",
	"2": "wolf_ranger",
	"3": "boar",
	"4": "mouse",
	"5": "owl",
	"6": "frog",
	"7": "knight",
	"8": "bunny",
	"9": "wolf_knight",
	"10": "menu_wolf",
	"11": "menu_wolf",
	"12": "cat_mage",
	"13": "rhino",
	"14": "sacer",
	"15": "wolf_knight",
}
const HEROES := ["cat", "wolf_ranger", "boar", "mouse", "owl", "frog", "knight", "bunny", "wolf_knight"]
# Portraits used only by the new campaign Levels (not part of the Endless 9-hero rotation).
const NEW_PORTRAITS := ["cat_mage", "rhino", "sacer"]
const EXPRESSIONS := ["hero_bunny_thinking", "hero_bunny_sequence", "hero_bunny_bad_choice", "hero_bunny_defeat"]
# The 14 delivered 4-expression sets (12 playable heroes + whale/duck board types).
const EXPRESSION_HERO_IDS := ["cat", "wolf_ranger", "boar", "mouse", "owl", "frog", "knight", "bunny",
	"wolf_knight", "cat_mage", "rhino", "sacer", "whale", "duck"]

func test_campaign_phase_map() -> void:
	for id in CAMPAIGN:
		Assert.equals(HeroRoster.hero_for(str(id)), CAMPAIGN[id], "L%s uses %s" % [id, CAMPAIGN[id]])
	Assert.equals(HeroRoster.hero_for("99"), HeroRoster.FALLBACK_HERO, "unknown level falls back to the menu wolf")
	Assert.equals(HeroRoster.hero_for(""), HeroRoster.FALLBACK_HERO, "empty level falls back to the menu wolf")
	Assert.equals(HeroRoster.hero_for("abc"), HeroRoster.FALLBACK_HERO, "non-numeric level falls back to the menu wolf")

func test_endless_rotates_the_nine_heroes() -> void:
	var seen := {}
	for round in range(1, 10):
		var hero := HeroRoster.hero_for("", round)
		Assert.is_true(HEROES.has(hero), "round %d uses a delivered hero (%s)" % [round, hero])
		Assert.is_false(seen.has(hero), "round %d does not repeat a hero" % round)
		seen[hero] = true
	Assert.equals(seen.size(), HEROES.size(), "the first 9 Endless rounds cover every hero once")
	Assert.equals(HeroRoster.hero_for("", 10), HeroRoster.hero_for("", 1), "round 10 wraps back to round 1")
	Assert.equals(HeroRoster.hero_for("", 18), HeroRoster.hero_for("", 9), "round 18 wraps to round 9")

func test_every_hero_and_expression_asset_exists() -> void:
	for hero in HEROES:
		var path := "res://assets/ui/heroes/hero_%s.png" % hero
		Assert.is_true(FileAccess.file_exists(path), "portrait exists: %s" % path)
	for hero in NEW_PORTRAITS:
		var path := "res://assets/ui/heroes/hero_%s.png" % hero
		Assert.is_true(FileAccess.file_exists(path), "new campaign portrait exists: %s" % path)
	Assert.is_true(FileAccess.file_exists("res://assets/ui/heroes/hero_menu_wolf.png"), "fallback portrait exists")
	for expression in EXPRESSIONS:
		var path := "res://assets/ui/heroes/%s.png" % expression
		Assert.is_true(FileAccess.file_exists(path), "L8 expression exists: %s" % path)
	Assert.equals(HEROES.size() + NEW_PORTRAITS.size() + EXPRESSIONS.size() + 1, 17,
		"9 heroes + 3 new campaign portraits + 4 expressions + 1 fallback")

func test_bunny_expression_for_each_mood() -> void:
	Assert.equals(HeroRoster.bunny_expression_for(0), "hero_bunny_thinking", "idle uses thinking")
	Assert.equals(HeroRoster.bunny_expression_for(1), "hero_bunny_sequence", "happy uses sequence")
	Assert.equals(HeroRoster.bunny_expression_for(2), "hero_bunny_bad_choice", "worried uses bad choice")
	Assert.equals(HeroRoster.bunny_expression_for(3), "hero_bunny_defeat", "sad uses defeat")
	for expression in EXPRESSIONS:
		Assert.is_true(FileAccess.file_exists("res://assets/ui/heroes/%s.png" % expression), "%s exists" % expression)

func test_every_delivered_set_has_four_existing_frames_and_bounds() -> void:
	Assert.equals(HeroRoster.EXPRESSIONS.size(), 14, "14 delivered expression sets")
	for hero in EXPRESSION_HERO_IDS:
		Assert.is_true(HeroRoster.has_expressions(hero), "%s has an expression set" % hero)
		var frames: Array = HeroRoster.EXPRESSIONS.get(hero, [])
		Assert.equals(frames.size(), 4, "%s has four expressions" % hero)
		for mood in 4:
			var file: String = HeroRoster.EXPRESSION_FILES[mood]
			var path := HeroRoster.expression_for(hero, mood)
			Assert.is_true(path.ends_with(file + ".png"), "%s mood %d maps to %s (got %s)" % [hero, mood, file, path])
			Assert.is_true(FileAccess.file_exists(path), "%s mood %d exists: %s" % [hero, mood, path])
			Assert.equals(path, str(frames[mood]), "%s mood %d uses its table entry" % [hero, mood])
			var bounds := HeroRoster.expression_bounds(hero, mood)
			Assert.is_true(bounds.size.x > 0 and bounds.size.y > 0,
				"%s mood %d has alpha bounds (%s)" % [hero, mood, str(bounds)])

func test_every_table_hero_is_a_known_hero_id() -> void:
	for hero in HeroRoster.EXPRESSIONS:
		Assert.is_true(HeroRoster.is_known_hero(hero), "table hero %s is a known HeroRoster id" % hero)
	for extra in HeroRoster.EXTRA_HEROES:
		Assert.is_true(HeroRoster.is_known_hero(extra), "extra set hero %s is a known id" % extra)

func test_every_playable_hero_has_a_set_and_the_fallback_keeps_the_tint() -> void:
	var playable: Array = []
	playable.append_array(HeroRoster.HEROES)
	for id in HeroRoster.CAMPAIGN_OVERRIDES.values():
		if not playable.has(id):
			playable.append(id)
	for hero in playable:
		Assert.is_true(HeroRoster.is_known_hero(hero), "%s is a known hero" % hero)
		Assert.is_true(HeroRoster.has_expressions(hero), "%s has a delivered expression set" % hero)
	Assert.is_false(HeroRoster.has_expressions(HeroRoster.FALLBACK_HERO),
		"the menu wolf fallback has no set and keeps the tint behaviour")
	Assert.equals(HeroRoster.expression_for(HeroRoster.FALLBACK_HERO, 1), "",
		"a hero without a set has no expression path")

func test_portrait_control_is_a_full_body_box() -> void:
	var ratio := HeroRoster.BASE_SIZE.y / HeroRoster.BASE_SIZE.x
	Assert.is_true(absf(ratio - 1.5) < 0.02, "BASE_SIZE is 2:3 (got %.3f)" % ratio)
	Assert.is_true(HeroRoster.BASE_SIZE.y > 55.0, "the hero is taller than the old 55 px NPC box")
	Assert.is_true(HeroRoster.BASE_SIZE.x > 46.0, "the hero is wider than the old 46 px NPC box")
	Assert.equals(HeroRoster.DEFAULT_HERO, HeroRoster.FALLBACK_HERO, "the default portrait is the fallback hero")
