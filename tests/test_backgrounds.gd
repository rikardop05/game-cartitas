extends RefCounted

# Background set per level and orientation: meadow 1-3, autumn 4-7, castle 8+ (and
# Endless, passed as 999), with the dedicated castle portrait crop.

func test_meadow_for_early_levels_and_menu() -> void:
	Assert.is_true(UiHelpers.background_path(true, 0).ends_with("background_menu.png"), "menu landscape uses the city")
	Assert.is_true(UiHelpers.background_path(false, 0).ends_with("background_portrait.png"), "menu portrait keeps the portrait background")
	for level in [1, 2, 3]:
		Assert.is_true(UiHelpers.background_path(true, level).ends_with("background.png"), "L%d landscape meadow" % level)
		Assert.is_true(UiHelpers.background_path(false, level).ends_with("background_portrait.png"), "L%d portrait meadow" % level)

func test_autumn_for_levels_4_to_7() -> void:
	for level in [4, 5, 6, 7]:
		Assert.is_true(UiHelpers.background_path(true, level).ends_with("background_autumn.png"), "L%d landscape autumn" % level)
		Assert.is_true(UiHelpers.background_path(false, level).ends_with("background_autumn.png"), "L%d portrait autumn" % level)

func test_castle_for_levels_8_to_11_and_endless() -> void:
	for level in [8, 9, 10, 11, 999]:
		Assert.is_true(UiHelpers.background_path(true, level).ends_with("background_castle.png"), "L%d landscape castle" % level)
		Assert.is_true(UiHelpers.background_path(false, level).ends_with("background_castle_portrait.png"), "L%d portrait castle" % level)

func test_background_files_exist() -> void:
	for path in [
		UiHelpers.background_path(true, 0), UiHelpers.background_path(false, 0),
		UiHelpers.background_path(true, 1), UiHelpers.background_path(false, 1),
		UiHelpers.background_path(true, 4), UiHelpers.background_path(true, 8),
		UiHelpers.background_path(false, 8),
	]:
		Assert.is_true(FileAccess.file_exists(path), "background exists: %s" % path)
