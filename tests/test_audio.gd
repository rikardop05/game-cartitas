extends RefCounted

# Audio assets and mix: the menu and all gameplay tracks plus one-shot effects ship with the build,
# load as the expected AudioStream type, and stay inside the gain the mix gives them. The
# volume/mute mapping (Game.volume / Game.sound_enabled) is pure, so this suite needs no
# audio device nor the registered Audio autoload.

const TRACKS := [
	"res://assets/audio/music/beyond_the_walls.mp3",
	"res://assets/audio/music/castle_eudora.mp3",
	"res://assets/audio/music/magikal_dreamers.mp3",
	"res://assets/audio/music/dinasty_oro.mp3",
	"res://assets/audio/music/honor_and_glory.mp3",
	"res://assets/audio/music/welcome_my_friends.mp3",
	"res://assets/audio/music/the_great_journey.mp3",
]

func test_tracks_exist_on_disk() -> void:
	for path in TRACKS:
		Assert.is_true(FileAccess.file_exists(path), "%s exists" % path)

func test_menu_track_loops_and_gameplay_tracks_are_one_shots() -> void:
	var menu := load(AudioManager.MENU_TRACK) as AudioStream
	Assert.is_true(menu != null, "menu track loads as an AudioStream")
	if menu != null:
		AudioManager.ensure_loop(menu)
		Assert.is_true(AudioManager.stream_loops(menu), "menu track loops forever")
		Assert.is_true(menu.get_length() > 60.0, "menu track is a full track (%.1f s)" % menu.get_length())
	for path in AudioManager.GAMEPLAY_TRACKS:
		var stream := load(path) as AudioStream
		Assert.is_true(stream != null, "%s loads as an AudioStream" % path)
		if stream == null:
			continue
		Assert.is_false(AudioManager.stream_loops(stream), "%s plays once to signal track completion" % path)
		Assert.is_true(stream.get_length() > 30.0, "%s is a full gameplay track, not a stub (%.1f s)" % [path, stream.get_length()])

func test_menu_and_gameplay_use_separate_track_sets() -> void:
	Assert.equals(AudioManager.MENU_TRACK, TRACKS[0], "menu uses Beyond the Walls")
	Assert.is_true(AudioManager.GAMEPLAY_TRACKS.has(AudioManager.GAME_TRACK), "Castle Eudora is one gameplay option")
	Assert.not_equals(AudioManager.MENU_TRACK, AudioManager.GAME_TRACK, "menu and gameplay use different tracks")

func test_music_volume_follows_game_volume_without_clipping() -> void:
	Assert.is_true(absf(AudioManager.bus_db(1.0, true)) < 0.01, "full volume is unity gain (0 dB)")
	Assert.is_true(AudioManager.bus_db(0.5, true) < -5.0 and AudioManager.bus_db(0.5, true) > -7.0, "half volume is about -6 dB")
	Assert.is_true(AudioManager.bus_db(0.0, true) <= AudioManager.SILENT_DB, "zero volume is silence")
	Assert.is_true(AudioManager.bus_db(1.0, false) <= AudioManager.SILENT_DB, "mute is silence even at full volume")
	Assert.is_true(AudioManager.bus_db(-0.5, true) <= AudioManager.SILENT_DB, "a negative volume cannot raise the gain")
	Assert.is_true(AudioManager.bus_db(2.0, true) <= 0.01, "a volume above 1 is clamped, never amplified")
	Assert.is_true(AudioManager.TRACK_PEAK_DB < 0.0, "tracks keep headroom so the crossfade never clips")

func test_sfx_output_is_reduced_by_twenty_percent() -> void:
	for base_gain_db in _sfx_gains().values():
		var adjusted_db := AudioManager.sfx_output_gain_db(float(base_gain_db))
		var output_scale := db_to_linear(adjusted_db) / db_to_linear(float(base_gain_db))
		Assert.is_true(absf(output_scale - 0.8) < 0.001,
			"every one-shot effect has 0.8x output level (got %.3f)" % [output_scale])

# --- One-shot effects -------------------------------------------------------------------

func _sfx_gains() -> Dictionary:
	return {
		AudioManager.CARD_SELECT_SFX: AudioManager.CARD_SELECT_DB,
		AudioManager.DECK_DRAW_SFX: AudioManager.DECK_DRAW_DB,
		AudioManager.LEVEL_START_SFX: AudioManager.LEVEL_START_DB,
		AudioManager.TRIPLE_MATCH_SFX: AudioManager.TRIPLE_MATCH_DB,
		AudioManager.LEVEL_COMPLETE_SFX: AudioManager.LEVEL_COMPLETE_DB,
		AudioManager.LEVEL_FAILED_SFX: AudioManager.LEVEL_FAILED_DB,
		AudioManager.POWER_HOLD_SFX: AudioManager.POWER_HOLD_DB,
		AudioManager.POWER_UNDO_SFX: AudioManager.POWER_UNDO_DB,
		AudioManager.POWER_REFRESH_SFX: AudioManager.POWER_REFRESH_DB,
		AudioManager.UI_CLICK_SFX: AudioManager.UI_CLICK_DB,
		AudioManager.UI_SETTING_SFX: AudioManager.UI_SETTING_DB,
	}

func test_sfx_exist_and_load_as_one_shots() -> void:
	for path in _sfx_gains():
		Assert.is_true(FileAccess.file_exists(path), "%s exists" % path)
		var stream := load(path) as AudioStream
		Assert.is_true(stream != null, "%s loads as an AudioStream" % path)
		if stream == null:
			continue
		Assert.is_true(stream is AudioStreamWAV, "%s is a plain WAV effect" % path)
		var length := stream.get_length()
		Assert.is_true(length > 0.2 and length < 6.0, "%s is a short effect (%.2f s)" % [path, length])
		if stream is AudioStreamWAV:
			Assert.equals((stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s does not loop" % path)

func test_sfx_peak_plus_its_gain_keeps_headroom() -> void:
	for path in _sfx_gains():
		var wav := load(path) as AudioStreamWAV
		if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
			continue
		var peak_db := _peak_db(wav) + AudioManager.sfx_output_gain_db(float(_sfx_gains()[path]))
		Assert.is_true(peak_db < -3.0, "%s peaks at %.1f dB with its gain (never clips)" % [path, peak_db])

func _peak_db(wav: AudioStreamWAV) -> float:
	var peak := 0
	var data := wav.data
	for i in range(0, data.size() - 1, 2):
		peak = maxi(peak, absi(int(data.decode_s16(i))))
	if peak == 0:
		return -INF
	return linear_to_db(float(peak) / 32768.0)

# --- Campaign/Endless music rotation -------------------------------------------------------

func test_gameplay_rotation_has_six_distinct_tracks() -> void:
	Assert.equals(AudioManager.GAMEPLAY_TRACKS.size(), 6, "the rotation has six tracks")
	Assert.is_false(AudioManager.GAMEPLAY_TRACKS.has(AudioManager.MENU_TRACK), "Beyond the Walls stays menu-only")
	var seen := {}
	for path in AudioManager.GAMEPLAY_TRACKS:
		Assert.is_true(FileAccess.file_exists(path), "%s exists" % path)
		Assert.is_false(seen.has(path), "%s appears once" % path)
		seen[path] = true

func test_shuffle_bag_uses_every_track_once_before_refill_and_no_boundary_repeat() -> void:
	var bag := AudioManager.build_shuffle_bag(AudioManager.GAMEPLAY_TRACKS, 77123)
	Assert.equals(bag.size(), AudioManager.GAMEPLAY_TRACKS.size(), "first shuffle bag contains six tracks")
	var seen := {}
	for path in bag:
		Assert.is_true(AudioManager.GAMEPLAY_TRACKS.has(path), "%s belongs to the gameplay set" % path)
		Assert.is_false(seen.has(path), "%s appears only once in a bag" % path)
		seen[path] = true
	Assert.equals(seen.size(), AudioManager.GAMEPLAY_TRACKS.size(), "all six tracks play before the bag refills")
	var next_bag := AudioManager.build_shuffle_bag(AudioManager.GAMEPLAY_TRACKS, 9917, bag.back())
	Assert.not_equals(next_bag.front(), bag.back(), "a refill never starts with the previous bag's last track")
	Assert.equals(next_bag.size(), AudioManager.GAMEPLAY_TRACKS.size(), "refill still contains every gameplay track")

func test_shuffle_bag_is_deterministic_with_a_seeded_rng() -> void:
	var previous := AudioManager.GAMEPLAY_TRACKS[3]
	var bag_a := AudioManager.build_shuffle_bag(AudioManager.GAMEPLAY_TRACKS, 20261102, previous)
	var bag_b := AudioManager.build_shuffle_bag(AudioManager.GAMEPLAY_TRACKS, 20261102, previous)
	Assert.equals(bag_a, bag_b, "the same seed and previous track reproduce the same bag")
	Assert.not_equals(bag_a[0], previous, "seeded bag still avoids an immediate repeat")

func test_first_shuffle_pick_is_not_fixed_to_one_level_one_track() -> void:
	var first_tracks := {}
	for seed_value in range(1, 80):
		var bag := AudioManager.build_shuffle_bag(AudioManager.GAMEPLAY_TRACKS, seed_value)
		if not bag.is_empty():
			first_tracks[bag[0]] = true
	Assert.is_true(first_tracks.size() > 1, "different seeds allow Level 1 to start with different gameplay tracks")

func test_gameplay_tracks_end_so_the_rotation_can_advance() -> void:
	var menu := load(AudioManager.MENU_TRACK) as AudioStream
	Assert.is_true(AudioManager.stream_loops(menu), "the menu track loops forever")
	for path in AudioManager.GAMEPLAY_TRACKS:
		var stream := load(path) as AudioStream
		Assert.is_true(stream != null, "%s loads" % path)
		Assert.is_false(AudioManager.stream_loops(stream), "%s plays once so the rotation advances on finished" % path)
