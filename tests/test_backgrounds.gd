extends RefCounted

# Background set per level and orientation: meadow 1-3, autumn 4-6, then a painted scene
# per Level from L7 on (assets/ui/backgrounds/level_NN.png + _portrait). Endless (999)
# uses the last campaign scene (L15), the endgame. The castle stays as the fallback when
# a per-Level file is missing.

func test_meadow_for_early_levels_and_menu() -> void:
	Assert.is_true(UiHelpers.background_path(true, 0).ends_with("background_menu.png"), "menu landscape uses the city")
	Assert.is_true(UiHelpers.background_path(false, 0).ends_with("background_portrait.png"), "menu portrait keeps the portrait background")
	for level in [1, 2, 3]:
		Assert.is_true(UiHelpers.background_path(true, level).ends_with("background.png"), "L%d landscape meadow" % level)
		Assert.is_true(UiHelpers.background_path(false, level).ends_with("background_portrait.png"), "L%d portrait meadow" % level)

func test_autumn_for_levels_4_to_6() -> void:
	for level in [4, 5, 6]:
		Assert.is_true(UiHelpers.background_path(true, level).ends_with("background_autumn.png"), "L%d landscape autumn" % level)
		Assert.is_true(UiHelpers.background_path(false, level).ends_with("background_autumn.png"), "L%d portrait autumn" % level)

func test_per_level_scenes_for_7_to_15() -> void:
	for level in range(7, 16):
		Assert.is_true(
			UiHelpers.background_path(true, level).ends_with("backgrounds/level_%02d.png" % level),
			"L%d landscape scene" % level)
		Assert.is_true(
			UiHelpers.background_path(false, level).ends_with("backgrounds/level_%02d_portrait.png" % level),
			"L%d portrait scene" % level)

func test_endless_uses_the_endgame_scene() -> void:
	Assert.is_true(UiHelpers.background_path(true, 999).ends_with("backgrounds/level_15.png"), "Endless landscape uses L15")
	Assert.is_true(UiHelpers.background_path(false, 999).ends_with("backgrounds/level_15_portrait.png"), "Endless portrait uses L15")

func test_background_files_exist() -> void:
	for path in [
		UiHelpers.background_path(true, 0), UiHelpers.background_path(false, 0),
		UiHelpers.background_path(true, 1), UiHelpers.background_path(false, 1),
		UiHelpers.background_path(true, 4), UiHelpers.background_path(true, 6),
		UiHelpers.background_path(true, 7), UiHelpers.background_path(false, 7),
		UiHelpers.background_path(true, 12), UiHelpers.background_path(false, 12),
		UiHelpers.background_path(true, 15), UiHelpers.background_path(false, 15),
		UiHelpers.background_path(true, 999), UiHelpers.background_path(false, 999),
	]:
		Assert.is_true(FileAccess.file_exists(path), "background exists: %s" % path)
