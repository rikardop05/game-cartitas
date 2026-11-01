class_name HeroRoster
extends RefCounted

# Data-only hero roster: campaign phase map, Endless rotation and the L8 expression
# frames. Kept free of Game/Node references so the headless test runner can load it
# (the Mascot class itself is only compiled inside a running game with autoloads).

const HEROES := ["cat", "wolf_ranger", "boar", "mouse", "owl", "frog", "knight", "bunny", "wolf_knight"]
# Levels 12-15 heroes. L15 closes the campaign with the wolf knight; the new portraits do
# not join the Endless rotation (it keeps its 9-hero cycle).
const CAMPAIGN_OVERRIDES := {
	"12": "cat_mage",
	"13": "rhino",
	"14": "sacer",
	"15": "wolf_knight",
}
const FALLBACK_HERO := "menu_wolf"
const DEFAULT_HERO := FALLBACK_HERO
const BUNNY_LEVEL := 8
# 2:3 full-body portraits (the old NPC mascot box was 46x55).
const BASE_SIZE := Vector2(96.0, 144.0)
const HERO_DIR := "res://assets/ui/heroes/%s.png"

# Moods mirror Mascot.Mood: IDLE=0, HAPPY=1, WORRIED=2, SAD=3.
const BUNNY_FRAMES := {
	0: "hero_bunny_thinking",
	1: "hero_bunny_sequence",
	2: "hero_bunny_bad_choice",
	3: "hero_bunny_defeat",
}

static func hero_for(level_id: String, endless_round: int = 0) -> String:
	if endless_round > 0:
		return HEROES[posmod(endless_round - 1, HEROES.size())]
	var level := int(level_id) if level_id.is_valid_int() else 0
	if CAMPAIGN_OVERRIDES.has(str(level)):
		return str(CAMPAIGN_OVERRIDES[str(level)])
	if level >= 1 and level <= HEROES.size():
		return HEROES[level - 1]
	return FALLBACK_HERO

static func bunny_expression_for(mood: int) -> String:
	return str(BUNNY_FRAMES.get(mood, BUNNY_FRAMES[0]))

static func texture_path(hero_or_frame: String) -> String:
	return HERO_DIR % hero_or_frame
