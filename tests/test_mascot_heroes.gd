extends RefCounted

# Phase map, delivered portraits and L8 expression frames for the hero mascot.
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
}
const HEROES := ["cat", "wolf_ranger", "boar", "mouse", "owl", "frog", "knight", "bunny", "wolf_knight"]
const EXPRESSIONS := ["hero_bunny_thinking", "hero_bunny_sequence", "hero_bunny_bad_choice", "hero_bunny_defeat"]

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
	Assert.is_true(FileAccess.file_exists("res://assets/ui/heroes/hero_menu_wolf.png"), "fallback portrait exists")
	for expression in EXPRESSIONS:
		var path := "res://assets/ui/heroes/%s.png" % expression
		Assert.is_true(FileAccess.file_exists(path), "L8 expression exists: %s" % path)
	Assert.equals(HEROES.size() + EXPRESSIONS.size() + 1, 14, "9 heroes + 4 expressions + 1 fallback")

func test_bunny_expression_for_each_mood() -> void:
	Assert.equals(HeroRoster.bunny_expression_for(0), "hero_bunny_thinking", "idle uses thinking")
	Assert.equals(HeroRoster.bunny_expression_for(1), "hero_bunny_sequence", "happy uses sequence")
	Assert.equals(HeroRoster.bunny_expression_for(2), "hero_bunny_bad_choice", "worried uses bad choice")
	Assert.equals(HeroRoster.bunny_expression_for(3), "hero_bunny_defeat", "sad uses defeat")
	for expression in EXPRESSIONS:
		Assert.is_true(FileAccess.file_exists("res://assets/ui/heroes/%s.png" % expression), "%s exists" % expression)

func test_portrait_control_is_a_full_body_box() -> void:
	var ratio := HeroRoster.BASE_SIZE.y / HeroRoster.BASE_SIZE.x
	Assert.is_true(absf(ratio - 1.5) < 0.02, "BASE_SIZE is 2:3 (got %.3f)" % ratio)
	Assert.is_true(HeroRoster.BASE_SIZE.y > 55.0, "the hero is taller than the old 55 px NPC box")
	Assert.is_true(HeroRoster.BASE_SIZE.x > 46.0, "the hero is wider than the old 46 px NPC box")
	Assert.equals(HeroRoster.DEFAULT_HERO, HeroRoster.FALLBACK_HERO, "the default portrait is the fallback hero")
