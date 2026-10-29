class_name VolumeRow
extends PanelContainer

# Volume row from the kit: minus, a slider bar with a draggable handle, plus, and the sound
# glyph (muted at zero) on a light plate, since the glyph is dark. Tapping the glyph mutes or
# brings back the last volume. Pieces are drawn at 2x like the rest of the menu art. Shared by
# the Options screen and the in-game settings overlay; it reads and writes the volume through
# the Game autoload and tells the owner (`changed`) so it can refresh anything that shows it.

signal changed

const VOLUME_STEP := 0.25
const SLIDER_TRACK_PX := 64

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
	box.add_child(_make_kit_icon_button("VolumeDown", "icon_minus", func(): _step_volume(-VOLUME_STEP)))
	box.add_child(_make_slider())
	box.add_child(_make_kit_icon_button("VolumeUp", "icon_plus", func(): _step_volume(VOLUME_STEP)))
	var plate := PanelContainer.new()
	plate.name = "SoundPlate"
	plate.add_theme_stylebox_override("panel", UiHelpers.kit_stylebox("panel_menu", 3, 1))
	box.add_child(plate)
	var mute := _make_kit_icon_button("SoundButton", _sound_icon_name(), _on_toggle_sound)
	mute.tooltip_text = Localizer.t("sound_label")
	plate.add_child(mute)

func _sound_icon_name() -> String:
	return "icon_sound_on" if _game.sound_enabled() else "icon_sound_off"

func _make_kit_icon_button(node_name: String, kit_name: String, callback: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.name = node_name
	btn.texture_normal = UiHelpers.kit_texture(kit_name)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
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
	var bar := UiHelpers.kit_panel("slider_bar", 4)
	bar.name = "Track"
	bar.size = Vector2(SLIDER_TRACK_PX, 16)
	bar.scale = Vector2(2, 2)
	slider.add_child(bar)
	var handle := TextureRect.new()
	handle.name = "Handle"
	handle.texture = UiHelpers.kit_texture("slider_handle")
	handle.size = Vector2(16, 16)
	handle.scale = Vector2(2, 2)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.position = Vector2(_handle_x(_game.volume()), 0)
	slider.add_child(handle)
	slider.gui_input.connect(_on_slider_input)
	return slider

# Left edge of the handle (in slider px) for a volume: the handle stays inside the bar.
func _handle_x(value: float) -> float:
	return value * float(SLIDER_TRACK_PX * 2 - 32)

func _on_slider_input(event: InputEvent) -> void:
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	var press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	if not drag and not press:
		return
	var value := clampf((event.position.x - 16.0) / float(SLIDER_TRACK_PX * 2 - 32), 0.0, 1.0)
	# Save only when the finger lifts; while dragging just move the handle and the glyph.
	var released: bool = press and not event.pressed
	_game.set_volume(value, released)
	_sync()

func _step_volume(delta: float) -> void:
	_game.set_volume(snappedf(_game.volume() + delta, VOLUME_STEP))
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
