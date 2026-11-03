class_name VolumeRow
extends PanelContainer

# Volume row from the kit: the painted Bar_adjust track with its Regulagem handle (drag or
# tap anywhere on the bar to set the volume) and the sound glyph (muted at zero) on a light
# plate, since the glyph is dark. Tapping the glyph mutes or brings back the last volume.
# Pieces are drawn at 2x like the rest of the menu art. Shared by the Options screen and the
# in-game settings overlay; it reads and writes the volume through the Game autoload and
# tells the owner (`changed`) so it can refresh anything that shows it.

signal changed

const SLIDER_TRACK_PX := 64
const SLIDER_TRACK_WIDTH := SLIDER_TRACK_PX * 2  # 128 px design width of the painted bar
const V2_KIT_DIR := "res://assets/ui/kit/v2/"
const V2_VOLUME_TRACK_ART := V2_KIT_DIR + "Bar_adjust.png"
const V2_VOLUME_HANDLE_ART := V2_KIT_DIR + "Regulagem_botton.png"
# Regulagem_botton.png is 52x119: the TextureRect keeps its aspect inside a 16x16 box drawn
# at 2x, so the visible handle is ~14 x 32 design px centred in a 32 x 32 box.
const HANDLE_ART_WIDTH := 52.0
const HANDLE_ART_HEIGHT := 119.0
const HANDLE_BOX_SIZE := 16.0
const HANDLE_SCALE := 2.0
const HANDLE_BOX_PX := HANDLE_BOX_SIZE * HANDLE_SCALE
const HANDLE_DRAWN_WIDTH := HANDLE_BOX_PX * (HANDLE_ART_WIDTH / HANDLE_ART_HEIGHT)
const HANDLE_INSET := (HANDLE_BOX_PX - HANDLE_DRAWN_WIDTH) * 0.5
# Inner groove of Bar_adjust.png (841x152), measured by pixel analysis: the dark-brown
# hole spans x=218..651, between the painted '-' (right edge ~177) and '+' (left edge ~694).
# Stored as fractions of the art width so the mapping always follows the art.
const GROOVE_LEFT := 218.0 / 841.0
const GROOVE_RIGHT := 651.0 / 841.0
# A press this close (fraction of the travel) to an end snaps to 0 / 1. It also absorbs the
# float32 rounding of the input position: a click exactly on the mute boundary would
# otherwise land a hair above zero and read as "sound on" at volume ~0.
const END_SNAP := 0.02

# Looked up at call time: naming the `Game` autoload here would stop this script compiling in
# the headless test runner (autoloads are not registered while it loads suites).
var _game

func _init(height: int = 42) -> void:
	_game = (Engine.get_main_loop() as SceneTree).root.get_node("Game")
	name = "VolumeRow"
	custom_minimum_size = Vector2(280, height)
	tooltip_text = Localizer.t("sound_label")
	var style := UiHelpers.kit_stylebox("panel_reserve", 6, 8)
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	add_theme_stylebox_override("panel", style)
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.add_child(_make_slider())
	var mute := _make_kit_icon_button("SoundButton", _sound_icon_name(), _on_toggle_sound)
	mute.tooltip_text = Localizer.t("sound_label")
	box.add_child(mute)

func _sound_icon_name() -> String:
	return "icon_sound_on" if _game.sound_enabled() else "icon_sound_off"

func _make_kit_icon_button(node_name: String, kit_name: String, callback: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.name = node_name
	btn.texture_normal = UiHelpers.kit_texture(kit_name)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	btn.custom_minimum_size = Vector2(32, 32)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(callback)
	btn.button_down.connect(func(): btn.modulate = Color(0.8, 0.8, 0.8))
	btn.button_up.connect(func(): btn.modulate = Color.WHITE)
	return btn

# The kit's 48 px bar is stretched to SLIDER_TRACK_PX keeping its rounded ends (9-slice),
# then drawn at 2x; the handle slides from the left end (muted) to the right end (full).
func _make_slider() -> Control:
	var slider := Control.new()
	slider.name = "VolumeSlider"
	slider.custom_minimum_size = Vector2(SLIDER_TRACK_PX * 2, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.tooltip_text = Localizer.t("sound_label")
	var track_texture := UiHelpers.hires_texture(V2_VOLUME_TRACK_ART)
	var bar: Control
	if track_texture != null:
		var track_data := UiHelpers.trimmed_nine_patch(
			track_texture, Vector2(SLIDER_TRACK_PX * 2.0, 32.0),
			Rect2(0.06, 0.10, 0.06, 0.10), "volume_track")
		var v2_bar := UiHelpers.nine_patch_rect(track_data, Vector2(SLIDER_TRACK_PX * 2.0, 32.0))
		v2_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v2_bar.set_meta("source_path", V2_VOLUME_TRACK_ART)
		bar = v2_bar
	else:
		var fallback_bar := Panel.new()
		var fallback_style := StyleBoxFlat.new()
		fallback_style.bg_color = Color("#5a4130")
		fallback_style.set_corner_radius_all(8)
		fallback_bar.add_theme_stylebox_override("panel", fallback_style)
		fallback_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar = fallback_bar
	bar.name = "Track"
	if track_texture == null:
		bar.size = Vector2(SLIDER_TRACK_PX * 2.0, 32.0)
	slider.add_child(bar)
	var handle := TextureRect.new()
	handle.name = "Handle"
	var handle_texture := UiHelpers.hires_texture(V2_VOLUME_HANDLE_ART)
	if handle_texture == null:
		handle_texture = UiHelpers.kit_texture("icon_accept")
		handle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		handle.set_meta("source_path", V2_VOLUME_HANDLE_ART)
		handle.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	handle.texture = handle_texture
	handle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	handle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	handle.size = Vector2(HANDLE_BOX_SIZE, HANDLE_BOX_SIZE)
	handle.scale = Vector2(HANDLE_SCALE, HANDLE_SCALE)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.position = Vector2(_handle_x(_game.volume()), 0)
	slider.add_child(handle)
	slider.gui_input.connect(_on_slider_input)
	return slider

# --- Value <-> position mapping (pure, so the headless suite can check it) --------------

static func groove_left_px() -> float:
	return float(SLIDER_TRACK_WIDTH) * GROOVE_LEFT

static func groove_right_px() -> float:
	return float(SLIDER_TRACK_WIDTH) * GROOVE_RIGHT

# Box position (slider px) of the handle for a volume. The VISIBLE handle travels only
# inside the groove: at 0 its left edge sits at the groove's left end, at 1 its right edge
# sits at the groove's right end (HANDLE_INSET keeps the transparent box overhang out).
static func handle_left_for(value: float) -> float:
	var travel := maxf(0.0, groove_right_px() - groove_left_px() - HANDLE_DRAWN_WIDTH)
	var drawn_left := groove_left_px() + clampf(value, 0.0, 1.0) * travel
	return drawn_left - HANDLE_INSET

# Volume for a click/drag x inside the slider: the handle is centred under the pointer.
# Presses on the painted '-' / '+' (outside the groove) clamp to 0 / 1, and a press within
# END_SNAP of an end snaps to it so mute/full are stable.
static func value_for_x(x: float) -> float:
	var travel := maxf(0.0001, groove_right_px() - groove_left_px() - HANDLE_DRAWN_WIDTH)
	var drawn_centre := groove_left_px() + HANDLE_DRAWN_WIDTH * 0.5
	var value := clampf((x - drawn_centre) / travel, 0.0, 1.0)
	if value <= END_SNAP:
		return 0.0
	if value >= 1.0 - END_SNAP:
		return 1.0
	return value

# Left edge of the handle's box (slider px) for a volume.
func _handle_x(value: float) -> float:
	return handle_left_for(value)

func _on_slider_input(event: InputEvent) -> void:
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	var press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	if not drag and not press:
		return
	var value := value_for_x(event.position.x)
	# Save only when the finger lifts; while dragging just move the handle and the glyph.
	var released: bool = press and not event.pressed
	_game.set_volume(value, released)
	_sync()

func _on_toggle_sound() -> void:
	_game.set_sound(not _game.sound_enabled())
	_sync()

# Moves the handle and the glyph to the current volume.
func _sync() -> void:
	var handle := find_child("Handle", true, false) as Control
	if handle != null:
		handle.position.x = _handle_x(_game.volume())
	var mute := find_child("SoundButton", true, false) as TextureButton
	if mute != null:
		mute.texture_normal = UiHelpers.kit_texture(_sound_icon_name())
	changed.emit()
