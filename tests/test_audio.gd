extends RefCounted

# Audio assets and mix: both music tracks and the four one-shot effects ship with the build,
# load as the expected AudioStream type, and stay inside the gain the mix gives them. The
# volume/mute mapping (Game.volume / Game.sound_enabled) is pure, so this suite needs no
# audio device nor the registered Audio autoload.

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
	Assert.is_true(absf(AudioManager.bus_db(1.0, true)) < 0.01, "full volume is unity gain (0 dB)")
	Assert.is_true(AudioManager.bus_db(0.5, true) < -5.0 and AudioManager.bus_db(0.5, true) > -7.0, "half volume is about -6 dB")
	Assert.is_true(AudioManager.bus_db(0.0, true) <= AudioManager.SILENT_DB, "zero volume is silence")
	Assert.is_true(AudioManager.bus_db(1.0, false) <= AudioManager.SILENT_DB, "mute is silence even at full volume")
	Assert.is_true(AudioManager.bus_db(-0.5, true) <= AudioManager.SILENT_DB, "a negative volume cannot raise the gain")
	Assert.is_true(AudioManager.bus_db(2.0, true) <= 0.01, "a volume above 1 is clamped, never amplified")
	Assert.is_true(AudioManager.TRACK_PEAK_DB < 0.0, "tracks keep headroom so the crossfade never clips")

# --- One-shot effects -------------------------------------------------------------------

func _sfx_gains() -> Dictionary:
	return {
		AudioManager.CARD_SELECT_SFX: AudioManager.CARD_SELECT_DB,
		AudioManager.DECK_DRAW_SFX: AudioManager.DECK_DRAW_DB,
		AudioManager.LEVEL_START_SFX: AudioManager.LEVEL_START_DB,
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
		var peak_db := _peak_db(wav) + float(_sfx_gains()[path])
		Assert.is_true(peak_db < -3.0, "%s peaks at %.1f dB with its gain (never clips)" % [path, peak_db])

func _peak_db(wav: AudioStreamWAV) -> float:
	var peak := 0
	var data := wav.data
	for i in range(0, data.size() - 1, 2):
		peak = maxi(peak, absi(int(data.decode_s16(i))))
	if peak == 0:
		return -INF
	return linear_to_db(float(peak) / 32768.0)
