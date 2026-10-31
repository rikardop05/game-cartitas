class_name AudioManager
extends Node

# Owns the two background tracks and the audio buses. The menu plays Beyond the Walls; the
# Level screen (campaign and Endless alike) plays Castle Eudora. Both loop forever and are
# swapped with a short crossfade, so the change of scene never cuts to silence.
#
# The volume/mute the player already controls (Game.volume / Game.sound_enabled) is applied to
# the Music bus and re-read every frame, so the Options slider and the in-game sound button act
# on the music immediately without the UI knowing about this node.
#
# The node is an autoload ("Audio"). Scenes only declare intent:
#   Audio.play_menu(self)     # main menu
#   Audio.play_gameplay(self) # Level screen
#   Audio.release(self)       # from _exit_tree; ignored if another scene claimed in the meantime
# The owner token is what keeps release() from cutting the music of the scene that replaced it.

signal track_changed(path: String)

const MENU_TRACK := "res://assets/audio/music/beyond_the_walls.mp3"
const GAME_TRACK := "res://assets/audio/music/castle_eudora.mp3"

const FADE_SECONDS := 0.8
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
# Music players never peak at 0 dB: two tracks overlap while crossfading, so this headroom
# (plus the limiter on Master) is what keeps the sum from clipping.
const TRACK_PEAK_DB := -2.0
# Anything at or below this is inaudible; used for the start/end of every fade and for mute.
const SILENT_DB := -80.0

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _active := -1
var _current_path := ""
var _owner_id := 0
var _fade: Tween
var _game: Node
var _last_bus_db := INF

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_ensure_master_limiter()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = MUSIC_BUS
		player.volume_db = SILENT_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)
	_sync_volume()

func _process(_delta: float) -> void:
	_sync_volume()

# Release the cached streams with the scene tree, so a clean quit leaves no resource in use.
func _exit_tree() -> void:
	_kill_fade()
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_players.clear()
	_streams.clear()

# --- Intent from the scenes -------------------------------------------------------------

func play_menu(owner: Node = null) -> void:
	_play(MENU_TRACK, owner)

func play_gameplay(owner: Node = null) -> void:
	_play(GAME_TRACK, owner)

# Gives the audio up, but only when this scene still owns it: a scene that already claimed
# it (the one replacing this one, whichever order the tree frees them in) is untouched.
# The fade-out is deferred by a frame, so a scene that takes over in the same frame (next
# Level, retry, next Endless round, back to the menu) cancels it and the track never stops.
func release(owner: Node) -> void:
	if owner == null or _owner_id != owner.get_instance_id():
		return
	_owner_id = 0
	call_deferred("_release_if_unclaimed")

func _release_if_unclaimed() -> void:
	if _owner_id != 0:
		return
	_current_path = ""
	if _active < 0 or _players[_active] == null or not _players[_active].playing:
		return
	_kill_fade()
	_fade = create_tween()
	_fade.tween_property(_players[_active], "volume_db", SILENT_DB, FADE_SECONDS)
	_fade.tween_callback(_players[_active].stop)

# The track currently playing (or fading in), "" when silent.
func current_track() -> String:
	return _current_path

func is_playing() -> bool:
	return _active >= 0 and _players[_active] != null and _players[_active].playing

# --- Mixing ----------------------------------------------------------------------------

# Music bus gain in dB for a 0..1 volume and a mute flag. Pure, so the headless suite can
# check the mapping without an audio device.
static func music_db(volume: float, enabled: bool) -> float:
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

# --- Internals -------------------------------------------------------------------------

func _play(path: String, owner: Node) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	# The track already playing (or fading in) is kept exactly where it is: moving from one
	# Level to the next, retrying or starting the next Endless round must not restart the song.
	for i in _players.size():
		var playing := _players[i]
		if playing.stream == stream and playing.playing:
			_owner_id = owner.get_instance_id() if owner != null else 0
			_current_path = path
			_active = i
			_fade_in(playing)
			return
	var old := _active
	var next := 1 - old if old >= 0 else 0
	_current_path = path
	_active = next
	_owner_id = owner.get_instance_id() if owner != null else 0
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
	ensure_loop(stream)
	_streams[path] = stream
	return stream

# Re-reads the player's volume/mute every frame. The UI writes it through the Game autoload;
# polling here is what lets the slider and the HUD sound button act mid-track.
func _sync_volume() -> void:
	if _game == null or not is_instance_valid(_game):
		_game = get_node_or_null("/root/Game")
	var enabled := true
	var volume := 1.0
	if _game != null and is_instance_valid(_game):
		enabled = bool(_game.call("sound_enabled"))
		volume = float(_game.call("volume"))
	var db := music_db(volume, enabled)
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
