extends RefCounted

# Guard against deleting or renaming art that the game still asks for. Two checks:
# 1. every concrete "res://assets/....(png|ogg|wav|mp3|ttf)" literal in the game
#    scripts/scenes must load through ResourceLoader;
# 2. the dynamic families (card_<type>, hero_<id>, stars_1..3, icon_power_*) must
#    still have every file their registries/rosters can ask for.
# Dynamic format strings (".../card_%s.png") are intentionally skipped by the literal
# scan and covered by the family tests below.

func test_literal_asset_paths_exist() -> void:
	var regex := RegEx.new()
	regex.compile("res://assets/[^\"'\\r\\n%]+\\.(?:png|ogg|wav|mp3|ttf)")
	var found := {}
	for file_path in _files_under("res://scripts", ".gd") + _files_under("res://scenes", ".tscn"):
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			Assert.is_true(false, "could not read %s" % file_path)
			continue
		var text := file.get_as_text()
		for hit in regex.search_all(text):
			var asset_path := hit.get_string()
			if found.has(asset_path):
				continue
			var line := text.substr(0, hit.get_start()).count("\n") + 1
			found[asset_path] = "%s:%d" % [file_path, line]
	# The scan must have found the known anchors, otherwise the regex silently broke.
	Assert.is_true(found.has("res://assets/ui/branding/logo_claw_and_crown.png"),
		"literal scan found the logo path")
	Assert.is_true(found.has("res://assets/audio/music/beyond_the_walls.mp3"),
		"literal scan found an audio track path")
	Assert.is_true(found.size() >= 20, "literal scan found the expected asset references (got %d)" % found.size())
	for asset_path in found:
		Assert.is_true(ResourceLoader.exists(asset_path),
			"%s references missing asset %s" % [found[asset_path], asset_path])

func test_card_art_family_exists() -> void:
	# Every type the registry offers is a claim that assets/cards/card_<type>.png exists.
	for type in CardTypeRegistry.all_types():
		var path := "res://assets/cards/card_%s.png" % type
		Assert.is_true(ResourceLoader.exists(path), "card art exists: %s" % path)

func test_hero_portrait_family_exists() -> void:
	for hero in HeroRoster.HEROES:
		var path := "res://assets/ui/heroes/hero_%s.png" % hero
		Assert.is_true(ResourceLoader.exists(path), "hero portrait exists: %s" % path)
	for hero in HeroRoster.CAMPAIGN_OVERRIDES.values():
		var path := "res://assets/ui/heroes/hero_%s.png" % hero
		Assert.is_true(ResourceLoader.exists(path), "campaign hero portrait exists: %s" % path)
	var fallback := "res://assets/ui/heroes/hero_%s.png" % HeroRoster.FALLBACK_HERO
	Assert.is_true(ResourceLoader.exists(fallback), "fallback hero portrait exists: %s" % fallback)
	for expression in HeroRoster.BUNNY_FRAMES.values():
		var path := "res://assets/ui/heroes/%s.png" % expression
		Assert.is_true(ResourceLoader.exists(path), "bunny expression exists: %s" % path)

func test_hud_and_power_icons_exist() -> void:
	for count in range(1, 4):
		var path := "res://assets/ui/hud/stars_%d.png" % count
		Assert.is_true(ResourceLoader.exists(path), "star plaque exists: %s" % path)
	Assert.is_true(ResourceLoader.exists("res://assets/ui/hud/icon_stopwatch.png"),
		"stopwatch badge exists")
	for power in PowerManager.POWERS:
		var path := "res://assets/ui/icons/icon_power_%s.png" % power
		Assert.is_true(ResourceLoader.exists(path), "power icon exists: %s" % path)

# Recursive DirAccess walk for the referenced extension (res:// paths).
func _files_under(dir_path: String, extension: String) -> Array:
	var files: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				files.append_array(_files_under(full, extension))
			elif entry.ends_with(extension):
				files.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return files
