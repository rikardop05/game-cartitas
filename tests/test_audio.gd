extends RefCounted

# Background music: both tracks ship with the build, load as looping AudioStreams, and the mix
# maps the player's volume/mute (Game.volume / Game.sound_enabled) onto the Music bus.
# Loaded straight from disk (not through the autoload), so the headless suite needs no audio
# device nor a registered Audio singleton.

const TRACKS := [
	"res://assets/audio/music/beyond_the_walls.mp3",
	"res://assets/audio/music/castle_eudora.mp3",
]

func test_tracks_exist_on_disk() -> void:
	for path in TRACKS:
		Assert.is_true(FileAccess.file_exists(path), "%s exists" % path)

func test_tracks_load_and_loop() -> void:
	for path in TRACKS:
		var stream := load(path) as AudioStream
		Assert.is_true(stream != null, "%s loads as an AudioStream" % path)
		if stream == null:
			continue
		AudioManager.ensure_loop(stream)
		Assert.is_true(AudioManager.stream_loops(stream), "%s is set to loop forever" % path)
		Assert.is_true(stream.get_length() > 60.0, "%s is a full track, not a stub (%.1f s)" % [path, stream.get_length()])

func test_menu_plays_beyond_the_walls_and_gameplay_plays_castle_eudora() -> void:
	Assert.equals(AudioManager.MENU_TRACK, TRACKS[0], "menu uses Beyond the Walls")
	Assert.equals(AudioManager.GAME_TRACK, TRACKS[1], "gameplay uses Castle Eudora")
	Assert.not_equals(AudioManager.MENU_TRACK, AudioManager.GAME_TRACK, "menu and gameplay use different tracks")

func test_music_volume_follows_game_volume_without_clipping() -> void:
	Assert.is_true(absf(AudioManager.music_db(1.0, true)) < 0.01, "full volume is unity gain (0 dB)")
	Assert.is_true(AudioManager.music_db(0.5, true) < -5.0 and AudioManager.music_db(0.5, true) > -7.0, "half volume is about -6 dB")
	Assert.is_true(AudioManager.music_db(0.0, true) <= AudioManager.SILENT_DB, "zero volume is silence")
	Assert.is_true(AudioManager.music_db(1.0, false) <= AudioManager.SILENT_DB, "mute is silence even at full volume")
	Assert.is_true(AudioManager.music_db(-0.5, true) <= AudioManager.SILENT_DB, "a negative volume cannot raise the gain")
	Assert.is_true(AudioManager.music_db(2.0, true) <= 0.01, "a volume above 1 is clamped, never amplified")
	Assert.is_true(AudioManager.TRACK_PEAK_DB < 0.0, "tracks keep headroom so the crossfade never clips")
