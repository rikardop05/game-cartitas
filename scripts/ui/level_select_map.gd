extends Control

const MAP_PATH := "res://assets/ui/map/world_map.png"
const MAP_SOURCE_SIZE := Vector2(1552.0, 886.0)
const BACK_ICON_ART := "res://assets/ui/kit/v2/icon_back.png"
const NODE_SIZE := Vector2(48.0, 48.0)
const LOCK_BADGE_SOURCE_DIAMETER := 82.0
const STAR_SIZE := Vector2(34.0, 13.0)
const ENDLESS_SOURCE_CENTER := Vector2(1422.0, 220.0)
const LEVEL_COUNT := 30
const CAMPAIGN_LEVEL_COUNT := 15
const NODE_CENTERS: Array[Vector2] = [
	Vector2(0.126, 0.837), Vector2(0.210, 0.823), Vector2(0.297, 0.799),
	Vector2(0.381, 0.797), Vector2(0.442, 0.747), Vector2(0.496, 0.690),
	Vector2(0.575, 0.655), Vector2(0.653, 0.664), Vector2(0.738, 0.684),
	Vector2(0.845, 0.679), Vector2(0.863, 0.579), Vector2(0.800, 0.450),
	Vector2(0.886, 0.429), Vector2(0.912, 0.359), Vector2(0.863, 0.291),
	Vector2(0.786, 0.314), Vector2(0.660, 0.421), Vector2(0.570, 0.428),
	Vector2(0.505, 0.501), Vector2(0.412, 0.547), Vector2(0.296, 0.514),
	Vector2(0.199, 0.488), Vector2(0.118, 0.489), Vector2(0.350, 0.253),
	Vector2(0.413, 0.205), Vector2(0.487, 0.184), Vector2(0.578, 0.208),
	Vector2(0.686, 0.194), Vector2(0.773, 0.174), Vector2(0.855, 0.158),
]
static var _back_icon_texture_cache: Texture2D = null

var _map_viewport: Control
var _map_art: TextureRect
var _endless_button: Button
var _node_buttons: Array[Button] = []
var _star_art: Array[TextureRect] = []
var _lock_marks: Array[Control] = []
var _map_scale: float = 1.0
var _map_position := Vector2.ZERO
var _drag_active := false
var _drag_start := Vector2.ZERO
var _drag_origin := Vector2.ZERO

func _ready() -> void:
	theme = UiHelpers.warm_theme()
	_build_scene()
	resized.connect(_layout_map)
	call_deferred("_layout_map")

func _build_scene() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "MapBackdrop"
	backdrop.color = Color("#26352c")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_map_viewport = Control.new()
	_map_viewport.name = "MapViewport"
	_map_viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_viewport.clip_contents = true
	_map_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_viewport.gui_input.connect(_on_map_input)
	add_child(_map_viewport)

	_map_art = TextureRect.new()
	_map_art.name = "WorldMapArt"
	_map_art.texture = UiHelpers.hires_texture(MAP_PATH)
	_map_art.set_meta("source_path", MAP_PATH)
	_map_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_art.stretch_mode = TextureRect.STRETCH_SCALE
	_map_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_map_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_viewport.add_child(_map_art)

	# A small leaf-toned brush mark conceals the screenshot's lone translate badge.
	var stray_icon_cover := Panel.new()
	stray_icon_cover.name = "MapStrayIconCover"
	stray_icon_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover_style := StyleBoxFlat.new()
	cover_style.bg_color = Color("#506b3d", 0.86)
	cover_style.border_color = Color("#73874a", 0.72)
	cover_style.set_border_width_all(1)
	cover_style.set_corner_radius_all(7)
	stray_icon_cover.add_theme_stylebox_override("panel", cover_style)
	_map_viewport.add_child(stray_icon_cover)
	stray_icon_cover.set_meta("map_fraction", Vector2(0.7178, 0.8126))
	stray_icon_cover.set_meta("map_patch_size", Vector2(40.0, 32.0))

	for i in LEVEL_COUNT:
		var level_id := i + 1
		var button := Button.new()
		button.name = "LevelNode%02d" % level_id
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.tooltip_text = _node_tooltip(level_id)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		button.add_theme_font_size_override("font_size", 1)
		button.disabled = not _is_level_available(level_id)
		if not button.disabled:
			button.pressed.connect(_on_level_pressed.bind(level_id))
		_map_viewport.add_child(button)
		_node_buttons.append(button)

		var stars := TextureRect.new()
		stars.name = "LevelStars%02d" % level_id
		stars.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stars.stretch_mode = TextureRect.STRETCH_SCALE
		stars.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_viewport.add_child(stars)
		_star_art.append(stars)

		var lock_mark: Control = null
		if button.disabled:
			lock_mark = _make_lock_mark("LockedLevel%02d" % level_id, Vector2.ONE * LOCK_BADGE_SOURCE_DIAMETER)
			_map_viewport.add_child(lock_mark)
		_lock_marks.append(lock_mark)

	_endless_button = _make_endless_button()
	_map_viewport.add_child(_endless_button)
	_refresh_stars()
	_make_header()

func _make_header() -> void:
	var header := PanelContainer.new()
	header.name = "MapHeader"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 54.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.10, 0.84)
	style.border_color = Color("#c49a55", 0.8)
	style.border_width_bottom = 2
	header.add_theme_stylebox_override("panel", style)
	add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	header.add_child(row)

	var back := Button.new()
	back.name = "BackButton"
	back.tooltip_text = Localizer.t("back")
	back.set_meta("label", Localizer.t("back"))
	back.set_meta("source_path", BACK_ICON_ART)
	back.custom_minimum_size = Vector2(42.0, 40.0)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var back_icon := TextureRect.new()
	back_icon.name = "BackIcon"
	back_icon.texture = _cropped_back_icon()
	back_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	back_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	back_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_icon.offset_left = 4.0
	back_icon.offset_top = 2.0
	back_icon.offset_right = -4.0
	back_icon.offset_bottom = -2.0
	back.add_child(back_icon)
	if back_icon.texture == null:
		back.text = "‹"
		back.add_theme_font_size_override("font_size", 28)
	back.mouse_entered.connect(func(): back_icon.modulate = Color(1.14, 1.08, 0.90))
	back.mouse_exited.connect(func(): back_icon.modulate = Color.WHITE)
	back.button_down.connect(func():
		back_icon.position.y = 1.0
		back_icon.modulate = Color(0.78, 0.78, 0.78))
	back.button_up.connect(func():
		back_icon.position.y = 0.0
		back_icon.modulate = Color(1.14, 1.08, 0.90) if back.is_hovered() else Color.WHITE)
	back.pressed.connect(_on_back)
	row.add_child(back)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(title_stack)
	var title := Label.new()
	title.name = "MapTitle"
	title.text = Localizer.t("select_level")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiHelpers.TEXT_PRIMARY)
	title_stack.add_child(title)
	var status := Label.new()
	status.name = "MapStatus"
	status.text = "Levels 16–30 · Em breve" if Localizer.current == "pt" else "Levels 16–30 · Coming soon"
	status.add_theme_font_size_override("font_size", 9)
	status.add_theme_color_override("font_color", UiHelpers.TEXT_MUTED)
	title_stack.add_child(status)

	var total_stars := UiHelpers.symbol_label(UiHelpers.total_stars_text(), 14)
	total_stars.name = "TotalStars"
	total_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_stars.add_theme_color_override("font_color", UiHelpers.GOLD)
	row.add_child(total_stars)

func _make_endless_button() -> Button:
	var button := Button.new()
	button.name = "EndlessButton"
	button.custom_minimum_size = Vector2(112.0, 38.0)
	button.size = button.custom_minimum_size
	button.text = "∞  " + Localizer.t("endless")
	button.tooltip_text = Localizer.t("endless_tip") if Game.progress.is_endless_unlocked() else (
		"%s %s" % [Localizer.t("endless"), Localizer.t("endless_locked") % ProgressManager.endless_unlock_level()])
	button.disabled = not Game.progress.is_endless_unlocked()
	if Game.progress.is_endless_unlocked() and Game.progress.endless_best > 0:
		button.text += "  ★ %s" % (Localizer.t("endless_best") % Game.progress.endless_best)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#fff0c0"))
	button.add_theme_color_override("font_disabled_color", Color("#c2b9a5"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color("#3b332b", 0.94)
		plate.border_color = Color("#c79a45", 0.95)
		plate.set_border_width_all(2)
		plate.set_corner_radius_all(9)
		plate.content_margin_left = 6
		plate.content_margin_right = 6
		if state == "hover":
			plate.bg_color = Color("#59452b", 0.96)
		elif state == "pressed":
			plate.bg_color = Color("#29241f", 0.96)
		elif state == "disabled":
			plate.bg_color = Color("#282a25", 0.78)
			plate.border_color = Color("#998b6f", 0.55)
		elif state == "focus":
			plate.bg_color = Color("#463a2d", 0.98)
		button.add_theme_stylebox_override(state, plate)
	button.pressed.connect(_on_endless_pressed)
	if button.disabled:
		var lock := _make_lock_mark("EndlessLock", Vector2(20.0, 20.0))
		button.add_child(lock)
		lock.position = Vector2(4.0, 9.0)
	return button

func _make_lock_mark(node_name: String, mark_size: Vector2) -> Control:
	var mark := Control.new()
	mark.name = node_name
	mark.set_meta("source_diameter", LOCK_BADGE_SOURCE_DIAMETER)
	mark.custom_minimum_size = mark_size
	mark.size = mark_size
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func():
		var current_size := mark.size
		var center := current_size * 0.5
		# Opaque fill masks the painted node number completely; the badge scales with the map.
		mark.draw_circle(center, current_size.x * 0.48, Color(0.035, 0.055, 0.06, 1.0))
		mark.draw_arc(center, current_size.x * 0.48, 0.0, TAU, 24, Color(0.78, 0.65, 0.39, 0.9), 1.2, true)
		var line := maxf(1.6, current_size.x * 0.075)
		mark.draw_arc(center + Vector2(0, -1), current_size.x * 0.20, PI, TAU, 16, Color("#f2d99a"), line)
		var body := Rect2(center.x - current_size.x * 0.22, center.y - current_size.y * 0.03, current_size.x * 0.44, current_size.y * 0.32)
		mark.draw_rect(body, Color("#f2d99a"))
		mark.draw_circle(center + Vector2(0, current_size.y * 0.075), maxf(1.0, current_size.x * 0.035), Color("#554630")))
	return mark

func _cropped_back_icon() -> Texture2D:
	if _back_icon_texture_cache != null:
		return _back_icon_texture_cache
	var source := UiHelpers.hires_texture(BACK_ICON_ART)
	if source == null:
		return null
	var image := source.get_image()
	if image == null:
		return source
	if image.is_compressed():
		image.decompress()
	var threshold := 24
	var left := image.get_width()
	var top := image.get_height()
	var right := -1
	var bottom := -1
	for y in image.get_height():
		for x in image.get_width():
			if roundi(image.get_pixel(x, y).a * 255.0) <= threshold:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	if right < left or bottom < top:
		return source
	var crop := AtlasTexture.new()
	crop.atlas = source
	crop.region = Rect2(left, top, right - left + 1, bottom - top + 1)
	crop.filter_clip = true
	_back_icon_texture_cache = crop
	return _back_icon_texture_cache

func _is_level_available(level_id: int) -> bool:
	return level_id <= CAMPAIGN_LEVEL_COUNT and LevelLoader.level_exists(level_id) and Game.progress.is_level_unlocked(level_id)

func _node_tooltip(level_id: int) -> String:
	if level_id > CAMPAIGN_LEVEL_COUNT:
		return "%s %d · %s" % [Localizer.t("level"), level_id, "Em breve" if Localizer.current == "pt" else "Coming soon"]
	if not Game.progress.is_level_unlocked(level_id):
		return "%s %d · %s" % [Localizer.t("level"), level_id, Localizer.t("locked")]
	return "%s %d · %d ★" % [Localizer.t("level"), level_id, Game.progress.get_stars(str(level_id))]

func _layout_map() -> void:
	if not is_instance_valid(_map_viewport) or not is_instance_valid(_map_art):
		return
	var viewport_size := _map_viewport.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var portrait := viewport_size.y > viewport_size.x
	var scale_x := viewport_size.x / MAP_SOURCE_SIZE.x
	var scale_y := viewport_size.y / MAP_SOURCE_SIZE.y
	_map_scale = maxf(scale_x, scale_y) if portrait else minf(scale_x, scale_y)
	var displayed_size := MAP_SOURCE_SIZE * _map_scale
	if portrait:
		var focus_id := clampi(Game.progress.get_unlocked_level(), 1, CAMPAIGN_LEVEL_COUNT)
		var focus_center := _source_center(focus_id)
		_map_position = Vector2(
			clampf(viewport_size.x * 0.5 - focus_center.x * _map_scale, viewport_size.x - displayed_size.x, 0.0),
			(viewport_size.y - displayed_size.y) * 0.5)
	else:
		_map_position = (viewport_size - displayed_size) * 0.5
	_map_art.position = _map_position
	_map_art.size = displayed_size
	var cover: Panel = _map_viewport.get_node("MapStrayIconCover") as Panel
	var cover_fraction: Vector2 = cover.get_meta("map_fraction")
	var cover_size: Vector2 = cover.get_meta("map_patch_size") * _map_scale
	cover.size = cover_size
	cover.position = _map_position + cover_fraction * displayed_size - cover_size * 0.5
	for index in LEVEL_COUNT:
		var level_id := index + 1
		var center := _map_position + _source_center(level_id) * _map_scale
		var button := _node_buttons[index]
		button.position = center - NODE_SIZE * 0.5
		var stars := _star_art[index]
		stars.size = STAR_SIZE
		stars.position = center + Vector2(-STAR_SIZE.x * 0.5, NODE_SIZE.y * 0.31)
		var mark := _lock_marks[index]
		if is_instance_valid(mark):
			var badge_size := Vector2.ONE * LOCK_BADGE_SOURCE_DIAMETER * _map_scale
			mark.custom_minimum_size = badge_size
			mark.size = badge_size
			mark.queue_redraw()
			mark.position = center - mark.size * 0.5
	if is_instance_valid(_endless_button):
		_endless_button.position = _map_position + ENDLESS_SOURCE_CENTER * _map_scale - _endless_button.size * 0.5

func _source_center(level_id: int) -> Vector2:
	return NODE_CENTERS[level_id - 1] * MAP_SOURCE_SIZE

func _on_map_input(event: InputEvent) -> void:
	if _map_viewport.size.x >= _map_viewport.size.y:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_active = true
			_drag_start = event.position
			_drag_origin = _map_position
			_map_viewport.accept_event()
		elif _drag_active:
			_drag_active = false
			_map_viewport.accept_event()
	elif event is InputEventMouseMotion and _drag_active:
		_map_position.x = _drag_origin.x + event.position.x - _drag_start.x
		_clamp_map_pan()
		_layout_map_at_current_offset()
		_map_viewport.accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_drag_active = true
			_drag_start = event.position
			_drag_origin = _map_position
		else:
			_drag_active = false
		_map_viewport.accept_event()
	elif event is InputEventScreenDrag and _drag_active:
		_map_position.x = _drag_origin.x + event.position.x - _drag_start.x
		_clamp_map_pan()
		_layout_map_at_current_offset()
		_map_viewport.accept_event()

func _layout_map_at_current_offset() -> void:
	if _map_art == null:
		return
	_map_art.position = _map_position
	var cover: Panel = _map_viewport.get_node("MapStrayIconCover") as Panel
	var cover_fraction: Vector2 = cover.get_meta("map_fraction")
	var cover_size: Vector2 = cover.get_meta("map_patch_size") * _map_scale
	cover.size = cover_size
	cover.position = _map_position + cover_fraction * (MAP_SOURCE_SIZE * _map_scale) - cover_size * 0.5
	for index in LEVEL_COUNT:
		var center := _map_position + _source_center(index + 1) * _map_scale
		_node_buttons[index].position = center - NODE_SIZE * 0.5
		_star_art[index].position = center + Vector2(-STAR_SIZE.x * 0.5, NODE_SIZE.y * 0.31)
		var mark := _lock_marks[index]
		if is_instance_valid(mark):
			var badge_size := Vector2.ONE * LOCK_BADGE_SOURCE_DIAMETER * _map_scale
			mark.custom_minimum_size = badge_size
			mark.size = badge_size
			mark.queue_redraw()
			mark.position = center - mark.size * 0.5
	if is_instance_valid(_endless_button):
		_endless_button.position = _map_position + ENDLESS_SOURCE_CENTER * _map_scale - _endless_button.size * 0.5

func _refresh_stars() -> void:
	for index in _star_art.size():
		var level_id := index + 1
		var earned_stars := Game.progress.get_stars(str(level_id)) if level_id <= CAMPAIGN_LEVEL_COUNT else 0
		var stars := _star_art[index]
		stars.visible = earned_stars > 0
		if earned_stars > 0:
			var star_count := clampi(earned_stars, 1, 3)
			stars.texture = UiHelpers.hud_texture("stars_%d" % star_count)
			stars.set_meta("source_path", "res://assets/ui/hud/stars_%d.png" % star_count)

func _clamp_map_pan() -> void:
	var min_x := _map_viewport.size.x - MAP_SOURCE_SIZE.x * _map_scale
	_map_position.x = clampf(_map_position.x, min_x, 0.0)

func _on_level_pressed(level_id: int) -> void:
	if _is_level_available(level_id):
		Game.start_level(str(level_id))

func _on_endless_pressed() -> void:
	if Game.progress.is_endless_unlocked():
		Game.start_endless()

func _on_back() -> void:
	Game.go_to_menu()
