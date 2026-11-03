class_name HeroRoster
extends RefCounted

# Data-only hero roster: campaign phase map, Endless rotation and the per-hero expression
# sets (thinking / sequence / bad_choice / defeat). Kept free of Game/Node references so the
# headless test runner can load it (the Mascot class itself is only compiled inside a
# running game with autoloads).

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

# Extra delivered sets for board types that are not part of the 9-hero Endless rotation
# (they have no base portrait yet). Their expressions are ready for when a Level uses them.
const EXTRA_HEROES := ["whale", "duck"]
const EXPRESSION_FILES := ["thinking", "sequence", "bad_choice", "defeat"]

# Every hero with a delivered 4-expression set, indexed by Mascot.Mood
# (0 IDLE -> thinking, 1 HAPPY -> sequence, 2 WORRIED -> bad_choice, 3 SAD -> defeat).
# Bunny reuses the existing cropped game frames (the new folder copies are uncropped and
# carry a faint alpha haze); every other hero uses expressions/<hero_id>/<mood>.png.
const EXPRESSIONS := {
	"cat": [
		"res://assets/ui/heroes/expressions/cat/thinking.png",
		"res://assets/ui/heroes/expressions/cat/sequence.png",
		"res://assets/ui/heroes/expressions/cat/bad_choice.png",
		"res://assets/ui/heroes/expressions/cat/defeat.png",
	],
	"wolf_ranger": [
		"res://assets/ui/heroes/expressions/wolf_ranger/thinking.png",
		"res://assets/ui/heroes/expressions/wolf_ranger/sequence.png",
		"res://assets/ui/heroes/expressions/wolf_ranger/bad_choice.png",
		"res://assets/ui/heroes/expressions/wolf_ranger/defeat.png",
	],
	"boar": [
		"res://assets/ui/heroes/expressions/boar/thinking.png",
		"res://assets/ui/heroes/expressions/boar/sequence.png",
		"res://assets/ui/heroes/expressions/boar/bad_choice.png",
		"res://assets/ui/heroes/expressions/boar/defeat.png",
	],
	"mouse": [
		"res://assets/ui/heroes/expressions/mouse/thinking.png",
		"res://assets/ui/heroes/expressions/mouse/sequence.png",
		"res://assets/ui/heroes/expressions/mouse/bad_choice.png",
		"res://assets/ui/heroes/expressions/mouse/defeat.png",
	],
	"owl": [
		"res://assets/ui/heroes/expressions/owl/thinking.png",
		"res://assets/ui/heroes/expressions/owl/sequence.png",
		"res://assets/ui/heroes/expressions/owl/bad_choice.png",
		"res://assets/ui/heroes/expressions/owl/defeat.png",
	],
	"frog": [
		"res://assets/ui/heroes/expressions/frog/thinking.png",
		"res://assets/ui/heroes/expressions/frog/sequence.png",
		"res://assets/ui/heroes/expressions/frog/bad_choice.png",
		"res://assets/ui/heroes/expressions/frog/defeat.png",
	],
	"knight": [
		"res://assets/ui/heroes/expressions/knight/thinking.png",
		"res://assets/ui/heroes/expressions/knight/sequence.png",
		"res://assets/ui/heroes/expressions/knight/bad_choice.png",
		"res://assets/ui/heroes/expressions/knight/defeat.png",
	],
	"bunny": [
		"res://assets/ui/heroes/hero_bunny_thinking.png",
		"res://assets/ui/heroes/hero_bunny_sequence.png",
		"res://assets/ui/heroes/hero_bunny_bad_choice.png",
		"res://assets/ui/heroes/hero_bunny_defeat.png",
	],
	"wolf_knight": [
		"res://assets/ui/heroes/expressions/wolf_knight/thinking.png",
		"res://assets/ui/heroes/expressions/wolf_knight/sequence.png",
		"res://assets/ui/heroes/expressions/wolf_knight/bad_choice.png",
		"res://assets/ui/heroes/expressions/wolf_knight/defeat.png",
	],
	"cat_mage": [
		"res://assets/ui/heroes/expressions/cat_mage/thinking.png",
		"res://assets/ui/heroes/expressions/cat_mage/sequence.png",
		"res://assets/ui/heroes/expressions/cat_mage/bad_choice.png",
		"res://assets/ui/heroes/expressions/cat_mage/defeat.png",
	],
	"rhino": [
		"res://assets/ui/heroes/expressions/rhino/thinking.png",
		"res://assets/ui/heroes/expressions/rhino/sequence.png",
		"res://assets/ui/heroes/expressions/rhino/bad_choice.png",
		"res://assets/ui/heroes/expressions/rhino/defeat.png",
	],
	"sacer": [
		"res://assets/ui/heroes/expressions/sacer/thinking.png",
		"res://assets/ui/heroes/expressions/sacer/sequence.png",
		"res://assets/ui/heroes/expressions/sacer/bad_choice.png",
		"res://assets/ui/heroes/expressions/sacer/defeat.png",
	],
	"whale": [
		"res://assets/ui/heroes/expressions/whale/thinking.png",
		"res://assets/ui/heroes/expressions/whale/sequence.png",
		"res://assets/ui/heroes/expressions/whale/bad_choice.png",
		"res://assets/ui/heroes/expressions/whale/defeat.png",
	],
	"duck": [
		"res://assets/ui/heroes/expressions/duck/thinking.png",
		"res://assets/ui/heroes/expressions/duck/sequence.png",
		"res://assets/ui/heroes/expressions/duck/bad_choice.png",
		"res://assets/ui/heroes/expressions/duck/defeat.png",
	],
}

# Visible (alpha > 8) bounds of each expression frame, in its own texture pixels. Mascot
# maps them onto the base portrait's drawn box so the character keeps the same height and
# foot line across moods (the base portraits have no transparent margin: bbox = full image).
const EXPRESSION_BOUNDS := {
	"cat": [
		Rect2i(1, 5, 364, 611),
		Rect2i(0, 6, 366, 610),
		Rect2i(9, 6, 366, 611),
		Rect2i(14, 6, 389, 612),
	],
	"wolf_ranger": [
		Rect2i(9, 3, 342, 636),
		Rect2i(4, 3, 337, 636),
		Rect2i(2, 2, 357, 637),
		Rect2i(5, 3, 383, 636),
	],
	"boar": [
		Rect2i(9, 3, 477, 683),
		Rect2i(66, 5, 501, 690),
		Rect2i(7, 11, 480, 688),
		Rect2i(35, 21, 538, 683),
	],
	"mouse": [
		Rect2i(6, 49, 387, 541),
		Rect2i(17, 0, 359, 540),
		Rect2i(27, 41, 349, 544),
		Rect2i(10, 58, 392, 543),
	],
	"owl": [
		Rect2i(6, 2, 341, 579),
		Rect2i(11, 10, 368, 578),
		Rect2i(11, 2, 359, 578),
		Rect2i(5, 3, 409, 578),
	],
	"frog": [
		Rect2i(2, 11, 458, 612),
		Rect2i(8, 2, 546, 664),
		Rect2i(3, 26, 485, 635),
		Rect2i(5, 2, 508, 609),
	],
	"knight": [
		Rect2i(6, 9, 315, 616),
		Rect2i(69, 4, 331, 616),
		Rect2i(63, 10, 317, 615),
		Rect2i(45, 4, 327, 615),
	],
	"bunny": [
		Rect2i(0, 0, 940, 1518),
		Rect2i(0, 0, 1006, 1516),
		Rect2i(0, 0, 962, 1517),
		Rect2i(0, 0, 1012, 1506),
	],
	"wolf_knight": [
		Rect2i(3, 19, 467, 694),
		Rect2i(16, 9, 584, 704),
		Rect2i(59, 16, 486, 694),
		Rect2i(24, 38, 486, 675),
	],
	"cat_mage": [
		Rect2i(9, 4, 347, 606),
		Rect2i(0, 1, 461, 796),
		Rect2i(0, 4, 319, 602),
		Rect2i(0, 3, 382, 605),
	],
	"rhino": [
		Rect2i(9, 5, 504, 695),
		Rect2i(15, 6, 529, 694),
		Rect2i(25, 6, 504, 695),
		Rect2i(25, 9, 479, 690),
	],
	"sacer": [
		Rect2i(0, 1, 394, 905),
		Rect2i(0, 1, 394, 903),
		Rect2i(0, 0, 371, 904),
		Rect2i(0, 0, 397, 899),
	],
	"whale": [
		Rect2i(3, 9, 474, 689),
		Rect2i(27, 2, 572, 702),
		Rect2i(7, 2, 482, 687),
		Rect2i(5, 2, 515, 696),
	],
	"duck": [
		Rect2i(4, 10, 447, 703),
		Rect2i(83, 2, 503, 701),
		Rect2i(13, 2, 459, 702),
		Rect2i(40, 2, 482, 696),
	],
}

# Moods mirror Mascot.Mood: IDLE=0, HAPPY=1, WORRIED=2, SAD=3.
const BUNNY_FRAMES := {
	0: "hero_bunny_thinking",
	1: "hero_bunny_sequence",
	2: "hero_bunny_bad_choice",
	3: "hero_bunny_defeat",
}
# Large defeat-screen plates. Everything without a dedicated plate uses the archer;
# the screen falls back to the archer file if the mapped PNG is missing.
const DEFEAT_ART_BY_HERO := {
	"bunny": "defeat_bunny.png",
	"cat": "defeat_cat.png",
	"cat_mage": "defeat_cat.png",
	"sacer": "defeat_sacer.png",
}
const DEFEAT_FALLBACK_ART := "defeat_archer.png"

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

# Every hero id the Mascot may be set to: the 9 campaign/Endless heroes, the L12-15
# overrides, the fallback and the extra board-type sets (whale/duck).
static func is_known_hero(hero_id: String) -> bool:
	var id := str(hero_id)
	return HEROES.has(id) or id == FALLBACK_HERO or EXTRA_HEROES.has(id) or CAMPAIGN_OVERRIDES.values().has(id)

static func has_expressions(hero_id: String) -> bool:
	return EXPRESSIONS.has(str(hero_id))

# Path of the frame for a mood (0 IDLE .. 3 SAD), or "" when the hero has no set.
static func expression_for(hero_id: String, mood: int) -> String:
	var frames: Array = EXPRESSIONS.get(str(hero_id), [])
	if frames.is_empty():
		return ""
	return str(frames[clampi(mood, 0, frames.size() - 1)])

# Visible (alpha > 8) bounds of that frame, in its own texture pixels; Rect2i() if unknown.
static func expression_bounds(hero_id: String, mood: int) -> Rect2i:
	var bounds: Array = EXPRESSION_BOUNDS.get(str(hero_id), [])
	if bounds.is_empty():
		return Rect2i()
	return bounds[clampi(mood, 0, bounds.size() - 1)]

static func defeat_character_file(hero_id: String) -> String:
	return str(DEFEAT_ART_BY_HERO.get(hero_id, DEFEAT_FALLBACK_ART))

static func texture_path(hero_or_frame: String) -> String:
	return HERO_DIR % hero_or_frame
