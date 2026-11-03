class_name AudioManager
extends Node

# Owns the background music and the audio buses. The menu plays Beyond the Walls on a loop;
# gameplay uses a persisted shuffle-bag of six one-shot tracks. Music belongs to this autoload,
# not the current Level scene, so finishing, retrying or changing Levels never restarts it.
#
# The volume/mute the player already controls (Game.volume / Game.sound_enabled) is applied to
# the Music bus on Game.volume_changed (with a slow fallback poll), so the Options slider and
# the in-game sound button act on the music immediately without the UI knowing about this node.
#
# The node is an autoload ("Audio"). Scenes only declare intent:
#   Audio.play_menu(self)     # crossfade to the menu track
#   Audio.play_gameplay(self) # start gameplay music only when entering from the menu
#   Audio.release(self)       # retained as a no-op for existing scene exit hooks

signal track_changed(path: String)

const MENU_TRACK := "res://assets/audio/music/beyond_the_walls.mp3"
const GAME_TRACK := "res://assets/audio/music/castle_eudora.mp3"
# Campaign/Endless shuffle bag. Beyond the Walls is menu-only, so it is not here.
const GAMEPLAY_TRACKS: Array[String] = [
	GAME_TRACK,
	"res://assets/audio/music/magikal_dreamers.mp3",
	"res://assets/audio/music/dinasty_oro.mp3",
	"res://assets/audio/music/honor_and_glory.mp3",
	"res://assets/audio/music/welcome_my_friends.mp3",
	"res://assets/audio/music/the_great_journey.mp3",
]
# Legacy compatibility index retained alongside the new persisted bag/last-track state.
const ROTATION_SETTING := "music_rotation"
const MUSIC_BAG_SETTING := "music_bag"
const LAST_GAMEPLAY_TRACK_SETTING := "music_last_track"

# One-shot effects. The gains trim the delivered files to a common perceived level; both keep
# their peak below -6 dB so a click never clips on top of the music.
const CARD_SELECT_SFX := "res://assets/audio/sfx/card_select.wav"
const DECK_DRAW_SFX := "res://assets/audio/sfx/deck_draw.wav"
const LEVEL_COMPLETE_SFX := "res://assets/audio/sfx/level_complete.wav"
const LEVEL_FAILED_SFX := "res://assets/audio/sfx/level_failed.wav"
const POWER_HOLD_SFX := "res://assets/audio/sfx/power_hold.wav"
const POWER_UNDO_SFX := "res://assets/audio/sfx/power_undo.wav"
const POWER_REFRESH_SFX := "res://assets/audio/sfx/power_refresh.wav"
const LEVEL_START_SFX := "res://assets/audio/sfx/level_start.wav"
const TRIPLE_MATCH_SFX := "res://assets/audio/sfx/triple_match.wav"
const UI_CLICK_SFX := "res://assets/audio/sfx/ui_click.wav"
const UI_SETTING_SFX := "res://assets/audio/sfx/ui_setting.wav"
const CARD_SELECT_DB := 8.0
const DECK_DRAW_DB := 2.0
const LEVEL_COMPLETE_DB := -4.0
const LEVEL_FAILED_DB := 2.0
const POWER_HOLD_DB := -4.0
const POWER_UNDO_DB := 7.0
const POWER_REFRESH_DB := 20.0
const LEVEL_START_DB := 14.0
const TRIPLE_MATCH_DB := -6.0
const UI_CLICK_DB := 2.0
const UI_SETTING_DB := 2.0

const FADE_SECONDS := 0.8
# Safety poll for volume/mute changes that bypass Game.set_volume (a test or tool that
# writes settings["volume"] directly). Normal changes arrive through volume_changed.
const VOLUME_POLL_SECONDS := 0.25
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
# Round-robin voices, so quick successive taps overlap instead of cutting each other off.
const SFX_VOICES := 3
# Uniform 20% reduction on the one-shot output; music levels are unaffected.
const SFX_VOLUME_SCALE := 0.8
# Music players never peak at 0 dB: two tracks overlap while crossfading, so this headroom
# (plus the limiter on Master) is what keeps the sum from clipping.
const TRACK_PEAK_DB := -2.0
# Anything at or below this is inaudible; used for the start/end of every fade and for mute.
const SILENT_DB := -80.0

var _players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _streams: Dictionary = {}
var _active := -1
var _fade: Tween
var _game: Node
var _last_bus_db := INF
var _volume_timer: Timer
var _active_track_path := ""
var _music_bag: Array[String] = []
var _last_gameplay_track := ""
var _music_rng := RandomNumberGenerator.new()
# True from the menu->game transition until the game->menu transition.
var _gameplay_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_rng.randomize()
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_ensure_master_limiter()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = MUSIC_BUS
		player.volume_db = SILENT_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.finished.connect(_on_music_finished.bind(i))
		add_child(player)
		_players.append(player)
	for i in SFX_VOICES:
		var sfx := AudioStreamPlayer.new()
		sfx.name = "Sfx%d" % i
		sfx.bus = SFX_BUS
		sfx.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(sfx)
		_sfx_players.append(sfx)
	_sync_volume()
	_bind_volume()
	_restore_music_state()

# Volume/mute is event driven: Game.volume_changed applies the slider/HUD changes at once.
# A slow timer stays as a fallback for direct settings writes (tests/tools), replacing the
# old per-frame _process poll.
func _bind_volume() -> void:
	_game = get_node_or_null("/root/Game")
	if _game != null and _game.has_signal("volume_changed"):
		var handler := Callable(self, "_on_volume_changed")
		if not _game.is_connected("volume_changed", handler):
			_game.connect("volume_changed", handler)
	if _volume_timer == null:
		_volume_timer = Timer.new()
		_volume_timer.name = "VolumePoll"
		_volume_timer.wait_time = VOLUME_POLL_SECONDS
		_volume_timer.one_shot = false
		_volume_timer.autostart = true
		_volume_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		_volume_timer.timeout.connect(_sync_volume)
		add_child(_volume_timer)

func _on_volume_changed(_volume: float, _enabled: bool) -> void:
	_sync_volume()

# Release the cached streams with the scene tree, so a clean quit leaves no resource in use.
func _exit_tree() -> void:
	if _game != null and is_instance_valid(_game) and _game.has_signal("volume_changed"):
		var handler := Callable(self, "_on_volume_changed")
		if _game.is_connected("volume_changed", handler):
			_game.disconnect("volume_changed", handler)
	if _volume_timer != null and is_instance_valid(_volume_timer):
		_volume_timer.stop()
	_kill_fade()
	for player in _players + _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_players.clear()
	_sfx_players.clear()
	_streams.clear()

# --- Intent from the scenes -------------------------------------------------------------

func play_menu(_owner: Node = null) -> void:
	var menu_already_active := _active_track_path == MENU_TRACK and _active_player_is_playing()
	_gameplay_active = false
	if menu_already_active:
		return
	_play(MENU_TRACK)

# Level scenes are recreated for victories, retries and Endless rounds. Those calls leave the
# current gameplay stream and playback head untouched; only entering from the menu starts music.
func play_gameplay(_owner: Node = null) -> void:
	if _gameplay_active and GAMEPLAY_TRACKS.has(_active_track_path) and _active_player_is_playing():
		return
	_gameplay_active = true
	_play(_next_gameplay_track())

static func build_shuffle_bag(track_paths: Array[String], seed_value: int, previous_track: String = "") -> Array[String]:
	var bag: Array[String] = []
	for path in track_paths:
		bag.append(path)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(bag.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := bag[index]
		bag[index] = bag[swap_index]
		bag[swap_index] = temporary
	# A new cycle must not start with the last track from the previous bag.
	if bag.size() > 1 and bag[0] == previous_track:
		var swap_index := rng.randi_range(1, bag.size() - 1)
		var temporary := bag[0]
		bag[0] = bag[swap_index]
		bag[swap_index] = temporary
	return bag

func _active_player_is_playing() -> bool:
	return _active >= 0 and _active < _players.size() and _players[_active].playing

func _next_gameplay_track() -> String:
	if _music_bag.is_empty():
		_music_bag = build_shuffle_bag(GAMEPLAY_TRACKS, _music_rng.randi(), _last_gameplay_track)
	if _music_bag.is_empty():
		return GAME_TRACK
	_last_gameplay_track = _music_bag.pop_front()
	_persist_music_state()
	return _last_gameplay_track

func _restore_music_state() -> void:
	var settings: Variant = _game.get("settings") if _game != null else null
	if not (settings is Dictionary):
		return
	var saved_settings := settings as Dictionary
	_last_gameplay_track = str(saved_settings.get(LAST_GAMEPLAY_TRACK_SETTING, ""))
	if not GAMEPLAY_TRACKS.has(_last_gameplay_track):
		var legacy_index := int(saved_settings.get(ROTATION_SETTING, -1))
		_last_gameplay_track = GAMEPLAY_TRACKS[legacy_index] if legacy_index >= 0 and legacy_index < GAMEPLAY_TRACKS.size() else ""
	_music_bag.clear()
	var saved_bag: Variant = saved_settings.get(MUSIC_BAG_SETTING, [])
	if saved_bag is Array:
		for entry in saved_bag:
			var path := str(entry)
			if GAMEPLAY_TRACKS.has(path) and not _music_bag.has(path):
				_music_bag.append(path)

func _persist_music_state() -> void:
	if _game == null or not is_instance_valid(_game):
		_game = get_node_or_null("/root/Game")
	if _game == null:
		return
	var settings: Variant = _game.get("settings")
	if not (settings is Dictionary):
		return
	var saved_settings := settings as Dictionary
	saved_settings[MUSIC_BAG_SETTING] = _music_bag.duplicate()
	saved_settings[LAST_GAMEPLAY_TRACK_SETTING] = _last_gameplay_track
	saved_settings[ROTATION_SETTING] = GAMEPLAY_TRACKS.find(_last_gameplay_track)
	_game.call("save_progress")

func current_track_path() -> String:
	return _active_track_path

func active_music_player() -> AudioStreamPlayer:
	return _players[_active] if _active >= 0 and _active < _players.size() else null

func remaining_gameplay_tracks() -> Array[String]:
	return _music_bag.duplicate()

# The Audio autoload owns the finished-signal chain across all scene changes.
func _on_music_finished(player_index: int) -> void:
	if not _gameplay_active or player_index != _active or not GAMEPLAY_TRACKS.has(_active_track_path):
		return
	_play(_next_gameplay_track())

# Existing scene exit hooks still call release(), but music lifetime belongs to this autoload.
func release(_owner: Node) -> void:
	pass

# A card picked from the Board (the heavy stone landing in the Clearing Zone).
func play_card_select() -> void:
	_play_sfx(CARD_SELECT_SFX, CARD_SELECT_DB)

# A card drawn from a Support Deck into the Clearing Zone.
func play_deck_draw() -> void:
	_play_sfx(DECK_DRAW_SFX, DECK_DRAW_DB)

# Three matching cards completed: they vanish from the Clearing Zone.
func play_match() -> void:
	_play_sfx(TRIPLE_MATCH_SFX, TRIPLE_MATCH_DB)

# The Level or Round title card, right as the board appears.
func play_level_start() -> void:
	_play_sfx(LEVEL_START_SFX, LEVEL_START_DB)

# A Level or Round won, whatever the number of stars.
func play_level_complete() -> void:
	_play_sfx(LEVEL_COMPLETE_SFX, LEVEL_COMPLETE_DB)

# A Level lost (time out or an unwinnable board).
func play_level_failed() -> void:
	_play_sfx(LEVEL_FAILED_SFX, LEVEL_FAILED_DB)

# A Power button: Hold and Undo have their own activation sound, Refresh the shuffle one.
func play_power(power: String) -> void:
	match power:
		"refresh":
			_play_sfx(POWER_REFRESH_SFX, POWER_REFRESH_DB)
		"undo":
			_play_sfx(POWER_UNDO_SFX, POWER_UNDO_DB)
		_:
			_play_sfx(POWER_HOLD_SFX, POWER_HOLD_DB)

# Any button of the menu screens (main menu, Level selector, Options).
func play_ui_click() -> void:
	_play_sfx(UI_CLICK_SFX, UI_CLICK_DB)

# The gear that opens the in-game settings during a Level or Round.
func play_ui_setting() -> void:
	_play_sfx(UI_SETTING_SFX, UI_SETTING_DB)

# --- Mixing ----------------------------------------------------------------------------

# Bus gain in dB for a 0..1 volume and a mute flag. Pure, so the headless suite can check the
# mapping without an audio device.
static func bus_db(volume: float, enabled: bool) -> float:
	if not enabled:
		return SILENT_DB
	var clamped := clampf(volume, 0.0, 1.0)
	if clamped <= 0.0:
		return SILENT_DB
	return linear_to_db(clamped)

# Makes an imported track loop forever. Kept static and defensive: the importer may already have
# set the flag, and the audio files are MP3 (WAV would need loop_mode instead).
static func ensure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

static func stream_loops(stream: AudioStream) -> bool:
	if stream is AudioStreamMP3:
		return (stream as AudioStreamMP3).loop
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	return false

static func sfx_output_gain_db(base_gain_db: float) -> float:
	return base_gain_db + linear_to_db(SFX_VOLUME_SCALE)

# --- Internals -------------------------------------------------------------------------

func _play(path: String) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	# Public intent methods handle same-state no-ops; this guard also protects an in-flight
	# crossfade from restarting the same stream if called twice.
	for i in _players.size():
		var playing := _players[i]
		if playing.stream == stream and playing.playing:
			_active = i
			_active_track_path = path
			_fade_in(playing)
			return
	var old := _active
	var next := 1 - old if old >= 0 else 0
	_active = next
	_active_track_path = path
	_kill_fade()
	var player := _players[next]
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(player, "volume_db", TRACK_PEAK_DB, FADE_SECONDS)
	if old >= 0 and old != next:
		var fading := _players[old]
		_fade.tween_property(fading, "volume_db", SILENT_DB, FADE_SECONDS)
		_fade.chain().tween_callback(fading.stop)
	track_changed.emit(path)

# Plays one short effect on the next SFX voice; the SFX bus carries the player's volume/mute.
func _play_sfx(path: String, volume_db: float) -> void:
	if _sfx_players.is_empty():
		return
	var stream := _load_stream(path)
	if stream == null:
		return
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = sfx_output_gain_db(volume_db)
	player.play()

# Brings `player` back to full music level and fades out any other track that was still
# audible (a crossfade interrupted by the player coming back to the previous screen).
func _fade_in(player: AudioStreamPlayer) -> void:
	_kill_fade()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(player, "volume_db", TRACK_PEAK_DB, FADE_SECONDS)
	for other in _players:
		if other == player or not other.playing:
			continue
		_fade.tween_property(other, "volume_db", SILENT_DB, FADE_SECONDS)
		_fade.chain().tween_callback(other.stop)

func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null

func _load_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: track not found: %s" % path)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: could not load track: %s" % path)
		return null
	# Only the menu track loops. Gameplay tracks must reach their end so the rotation can
	# advance on the players' `finished` signal (the importer may have set loop either way).
	if path == MENU_TRACK:
		ensure_loop(stream)
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_streams[path] = stream
	return stream

# Applies the player's volume/mute to the Music bus. Driven by Game.volume_changed and by a
# slow fallback timer (see _bind_volume), never by a per-frame poll.
func _sync_volume() -> void:
	if _game == null or not is_instance_valid(_game):
		_game = get_node_or_null("/root/Game")
	var enabled := true
	var volume := 1.0
	if _game != null and is_instance_valid(_game):
		enabled = bool(_game.call("sound_enabled"))
		volume = float(_game.call("volume"))
	var db := bus_db(volume, enabled)
	if is_equal_approx(db, _last_bus_db):
		return
	_last_bus_db = db
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, db)

func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	index = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	AudioServer.set_bus_volume_db(index, 0.0)
	return index

# Last safety net: even with the per-track headroom, a transient overlap must not clip.
func _ensure_master_limiter() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	for i in AudioServer.get_bus_effect_count(master):
		var effect := AudioServer.get_bus_effect(master, i)
		if effect is AudioEffectHardLimiter or effect is AudioEffectLimiter:
			return
	var limiter: AudioEffect = null
	if ClassDB.class_exists("AudioEffectHardLimiter"):
		limiter = AudioEffectHardLimiter.new()
		limiter.set("ceiling_db", -0.5)
	elif ClassDB.class_exists("AudioEffectLimiter"):
		limiter = AudioEffectLimiter.new()
	if limiter != null:
		AudioServer.add_bus_effect(master, limiter)
