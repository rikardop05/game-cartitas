extends RefCounted

# Defeat composition data: roster mapping, localised art files and the v2 end plates.
# The scene itself is covered by smoke_defeat.gd; this suite stays data-only/headless.

const DEFEAT_DIR := "res://assets/ui/defeat/"
const LOCALISED := ["defeat_title_pt.png", "defeat_title_en.png",
	"defeat_retry_pt.png", "defeat_retry_en.png",
	"defeat_quit_pt.png", "defeat_quit_en.png"]

func test_roster_maps_to_the_expected_defeat_art() -> void:
	Assert.equals(HeroRoster.defeat_character_file("bunny"), "defeat_bunny.png", "bunny plate")
	Assert.equals(HeroRoster.defeat_character_file("cat"), "defeat_cat.png", "cat plate")
	Assert.equals(HeroRoster.defeat_character_file("cat_mage"), "defeat_cat.png", "cat mage uses the cat plate")
	Assert.equals(HeroRoster.defeat_character_file("sacer"), "defeat_sacer.png", "sacer plate")
	for hero in ["wolf_ranger", "boar", "mouse", "owl", "frog", "knight", "wolf_knight", "rhino", "menu_wolf"]:
		Assert.equals(HeroRoster.defeat_character_file(hero), "defeat_archer.png", "%s falls back to archer" % hero)

func test_campaign_levels_use_the_roster_mapping() -> void:
	Assert.equals(HeroRoster.defeat_character_file(HeroRoster.hero_for("1")), "defeat_cat.png", "L1 cat")
	Assert.equals(HeroRoster.defeat_character_file(HeroRoster.hero_for("8")), "defeat_bunny.png", "L8 bunny")
	Assert.equals(HeroRoster.defeat_character_file(HeroRoster.hero_for("12")), "defeat_cat.png", "L12 cat mage")
	Assert.equals(HeroRoster.defeat_character_file(HeroRoster.hero_for("14")), "defeat_sacer.png", "L14 sacer")
	Assert.equals(HeroRoster.defeat_character_file(HeroRoster.hero_for("15")), "defeat_archer.png", "L15 archer fallback")

func test_defeat_assets_exist() -> void:
	for file_name in ["defeat_panel.png", "defeat_bunny.png", "defeat_cat.png", "defeat_sacer.png", "defeat_archer.png"] + LOCALISED:
		Assert.is_true(FileAccess.file_exists(DEFEAT_DIR + file_name), "missing %s" % file_name)

func test_v2_end_plates_exist() -> void:
	for file_name in ["Continuar_.png", "Layer 1.png", "Layer 2.png", "Layer 3.png",
			"config_2.png", "Configu.png", "Config_Icon.png", "interrog.png",
			"Bar_adjust.png", "Regulagem_botton.png", "panel_board_frame.png",
			"bar_zone.png", "card_available_frame.png"]:
		Assert.is_true(FileAccess.file_exists("res://assets/ui/kit/v2/" + file_name),
			"missing v2 %s" % file_name)
