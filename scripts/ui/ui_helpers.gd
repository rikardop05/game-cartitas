class_name UiHelpers
extends RefCounted

const WARM_BACKGROUND := Color("#c78454")
const BUTTON_BACKGROUND := Color(0.16, 0.10, 0.08, 0.78)
const BUTTON_BORDER := Color("#f3d28d")
const TEXT_PRIMARY := Color("#fff1d2")
const TEXT_MUTED := Color("#f0c98e")
const GOLD := Color("#ffe36e")

static var _font_cache: SystemFont = null
static var _card_texture_cache: Dictionary = {}
static var _frame_cache: Dictionary = {}
static var _shadow_cache: Dictionary = {}

static func symbol_font() -> SystemFont:
	if _font_cache == null:
		_font_cache = SystemFont.new()
		_font_cache.font_names = PackedStringArray(["Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji", "Arial"])
	return _font_cache

# Card art standard: assets/cards/card_<type>.png, square, high resolution (>= 512 px, ideally
# a multiple of 64 such as 960, frame included). The UI is drawn at the PHYSICAL screen size
# (stretch mode canvas_items), so a 46 px logical card is 90+ real pixels; the art is kept at
# full resolution with mipmaps and drawn with trilinear filtering, letting the GPU scale it to
# whatever size the screen needs instead of pre-shrinking it to logical pixels (which blurred
# and pixelated it once the window upscaled the result). Mipmaps are built here, so any
# delivered PNG works without import tweaks. Cached per type.
static func card_texture(type: String) -> Texture2D:
	return hires_texture("res://assets/cards/card_%s.png" % type)

# Any painted (not pixel-art) picture at full resolution: loaded once, mipmaps generated, cached
# by path, null when the file is missing. Draw it with TEXTURE_FILTER_LINEAR_WITH_MIPMAPS.
static func hires_texture(path: String) -> Texture2D:
	if not _card_texture_cache.has(path):
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			var source := load(path) as Texture2D
			var image := source.get_image() if source != null else null
			if image != null:
				image = image.duplicate()
				if image.is_compressed():
					image.decompress()
				if not image.has_mipmaps():
					image.generate_mipmaps()
				texture = ImageTexture.create_from_image(image)
			else:
				texture = source
		_card_texture_cache[path] = texture
	return _card_texture_cache[path]

# HUD art (assets/ui/hud/<name>.png): the star plaque states and the stopwatch/gear icons.
static func hud_texture(name: String) -> Texture2D:
	return hires_texture(HUD_DIR + name + ".png")

# True when `type` has a painted card face (assets/cards/card_<type>.png); the others keep the
# emoji placeholder.
static func has_card_art(type: String) -> bool:
	return card_texture(type) != null

static func warm_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", TEXT_PRIMARY)
	# Labels may sit straight on the painted background (menu titles).
	t.set_color("font_outline_color", "Label", Color(0.14, 0.07, 0.03, 0.92))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = BUTTON_BACKGROUND
		style.border_color = BUTTON_BORDER
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.content_margin_left = 12
		style.content_margin_right = 12
		match state:
			"hover":
				style.bg_color = BUTTON_BACKGROUND.lightened(0.12)
			"pressed":
				style.bg_color = BUTTON_BACKGROUND.darkened(0.2)
			"disabled":
				style.bg_color.a = 0.4
				style.border_color.a = 0.35
			"focus":
				style.bg_color = Color(0, 0, 0, 0)
		t.set_stylebox(state, "Button", style)
	t.set_color("font_color", "Button", TEXT_PRIMARY)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", TEXT_MUTED)
	t.set_color("font_disabled_color", "Button", Color(TEXT_PRIMARY, 0.45))
	return t

# Full-screen painted background for the orientation, calmed by a filter shader so
# the cards and HUD stay readable. Falls back to the flat warm colour without art.
const KIT_DIR := "res://assets/ui/kit/"
const HUD_DIR := "res://assets/ui/hud/"
# Levels from this one on use the second (autumn) background set.
const AUTUMN_FROM_LEVEL := 4
# Castle fallback for L8+ when no per-Level scene is delivered (L7-15 always ship one).
const CASTLE_FROM_LEVEL := 8
const CASTLE_LANDSCAPE := "res://assets/ui/background_castle.png"
const CASTLE_PORTRAIT := "res://assets/ui/background_castle_portrait.png"
# From L7 on every Level has its own painted scene in assets/ui/backgrounds/level_NN.png,
# with a _portrait crop. Endless (999) clamps to the last one (the endgame scene).
const LEVEL_BACKGROUND_DIR := "res://assets/ui/backgrounds/"
const LEVEL_BACKGROUND_FROM := 7
const LEVEL_BACKGROUND_MAX := 15

# A piece of the pixel-art UI kit (assets/ui/kit/<name>.png), or null if missing.
static func kit_texture(name: String) -> Texture2D:
	var path := KIT_DIR + name + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# 9-slice stylebox from a kit piece, for PanelContainers/buttons of any size. `margin` is
# the frame thickness in source pixels; content_margin pads the children inside it.
static func kit_stylebox(name: String, margin: int = 5, content_margin: int = 6) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = kit_texture(name)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style

# One region of a painted kit piece as a texture, for NinePatchRect frames that must scale
# their corners instead of drawing them at source size.
static func atlas_texture(name: String, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = kit_texture(name)
	atlas.region = region
	return atlas

# 9-slice rect from a kit piece, for decorative frames drawn at an exact size.
static func kit_panel(name: String, margin: int = 5) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.texture = kit_texture(name)
	panel.patch_margin_left = margin
	panel.patch_margin_top = margin
	panel.patch_margin_right = margin
	panel.patch_margin_bottom = margin
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

# Decodes a Texture2D into an editable RGBA image (decompressing imported PNGs).
static func _editable_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	return image

# 9-slice a painted frame that has a transparent centre, showing only its visible
# border: crops the alpha bounding box, fits it and caps the border thickness (so a
# thick painted bevel never eats the play area). Returns the fitted texture, the
# 9-slice margins and the real inner hole, in target-local px. Cached by texture
# path, target size and border cap.
static func alpha_nine_patch(texture: Texture2D, target_size: Vector2, max_border: float = 8.0) -> Dictionary:
	var key := "%s|%.0fx%.0f|%.1f" % [
		texture.resource_path if texture != null else "",
		target_size.x, target_size.y, max_border,
	]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var image := _editable_image(texture)
	if image == null or target_size.x <= 0.0 or target_size.y <= 0.0:
		return {}
	var used := image.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return {}
	var crop := image.get_region(used)
	var w := crop.get_width()
	var h := crop.get_height()
	var threshold := 16
	var cy := h / 2
	var cx := w / 2
	var left := _opaque_run(crop, Vector2i(1, 0), 0, cy, threshold)
	var right := _opaque_run(crop, Vector2i(-1, 0), w - 1, cy, threshold)
	var top := _opaque_run(crop, Vector2i(0, 1), cx, 0, threshold)
	var bottom := _opaque_run(crop, Vector2i(0, -1), cx, h - 1, threshold)
	# A solid picture (no transparent centre) is not a frame: keep a proportional
	# margin so the picture is never cropped into a fake border.
	if left >= w / 2 or right >= w / 2 or top >= h / 2 or bottom >= h / 2:
		left = maxi(1, w / 12)
		right = left
		top = maxi(1, h / 12)
		bottom = top
	var scale := target_size.y / float(h)
	var thickest := float(maxi(maxi(left, right), maxi(top, bottom))) * scale
	if max_border > 0.0 and thickest > max_border:
		scale *= max_border / thickest
	var fitted := crop.duplicate()
	fitted.resize(maxi(2, roundi(w * scale)), maxi(2, roundi(h * scale)), Image.INTERPOLATE_BILINEAR)
	fitted.generate_mipmaps()
	var ml := clampi(roundi(left * scale), 1, fitted.get_width() / 2)
	var mr := clampi(roundi(right * scale), 1, fitted.get_width() / 2)
	var mt := clampi(roundi(top * scale), 1, fitted.get_height() / 2)
	var mb := clampi(roundi(bottom * scale), 1, fitted.get_height() / 2)
	var inner := Rect2(
		ml, mt,
		maxf(1.0, target_size.x - ml - mr),
		maxf(1.0, target_size.y - mt - mb),
	)
	var result := {
		"texture": ImageTexture.create_from_image(fitted),
		"margins": Rect2i(ml, mt, mr, mb),
		"inner": inner,
		"source_bounds": used,
	}
	_frame_cache[key] = result
	return result

# 9-slice a painted panel with fixed proportional margins: the texture is cropped
# to its alpha bounding box, fitted to the target height (preserving its aspect),
# and the margins are scaled with it. Use this for panels whose corner ornaments
# must not be cut (the reserve field, the powers board). `margin_ratio` is
# (left, top, right, bottom) as fractions of the CROPPED texture size.
static func trimmed_nine_patch(texture: Texture2D, target_size: Vector2, margin_ratio: Rect2, cache_key: String = "") -> Dictionary:
	var source_key := cache_key if not cache_key.is_empty() else (texture.resource_path if texture != null else "")
	var key := "trim|%s|%.0fx%.0f|%s" % [source_key, target_size.x, target_size.y, str(margin_ratio)]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var image := _editable_image(texture)
	if image == null or target_size.x <= 0.0 or target_size.y <= 0.0:
		return {}
	var used := image.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return {}
	var crop := image.get_region(used)
	var w := crop.get_width()
	var h := crop.get_height()
	var scale := target_size.y / float(h)
	var fitted: Image = crop.duplicate()
	fitted.resize(maxi(2, roundi(w * scale)), maxi(2, roundi(target_size.y)), Image.INTERPOLATE_BILINEAR)
	fitted.generate_mipmaps()
	var fw := fitted.get_width()
	var fh := fitted.get_height()
	var max_x := maxi(1, fw / 2 - 1)
	var max_y := maxi(1, fh / 2 - 1)
	var ml := clampi(roundi(fw * margin_ratio.position.x), 1, max_x)
	var mt := clampi(roundi(fh * margin_ratio.position.y), 1, max_y)
	var mr := clampi(roundi(fw * margin_ratio.size.x), 1, max_x)
	var mb := clampi(roundi(fh * margin_ratio.size.y), 1, max_y)
	if ml + mr >= int(target_size.x):
		ml = maxi(1, int(target_size.x) / 4)
		mr = ml
	if mt + mb >= int(target_size.y):
		mt = maxi(1, int(target_size.y) / 4)
		mb = mt
	var inner := Rect2(
		ml, mt,
		maxf(1.0, target_size.x - ml - mr),
		maxf(1.0, target_size.y - mt - mb),
	)
	var result := {
		"texture": ImageTexture.create_from_image(fitted),
		"margins": Rect2i(ml, mt, mr, mb),
		"inner": inner,
		"source_bounds": used,
	}
	_frame_cache[key] = result
	return result

static var _rotated_cache: Dictionary = {}

# A painted picture rotated 90 degrees and cached (used to lay the tall powers
# board sideways in portrait without squashing its corner ornaments).
static func rotated_texture(path: String, clockwise: bool = true) -> Texture2D:
	var key := "%s|%s" % [path, str(clockwise)]
	if _rotated_cache.has(key):
		return _rotated_cache[key]
	var source := hires_texture(path)
	var image := _editable_image(source)
	if image == null:
		return source
	image.rotate_90(ClockDirection.CLOCKWISE if clockwise else ClockDirection.COUNTERCLOCKWISE)
	image.generate_mipmaps()
	var result := ImageTexture.create_from_image(image)
	_rotated_cache[key] = result
	return result

static func _opaque_run(image: Image, step: Vector2i, start_x: int, start_y: int, threshold: int) -> int:
	var run := 0
	var x := start_x
	var y := start_y
	while x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		if roundi(image.get_pixel(x, y).a * 255.0) <= threshold:
			break
		run += 1
		x += step.x
		y += step.y
	return run

# A soft drop shadow pre-rendered from a picture's alpha: downscaled, blurred with
# two separable box passes and cached, so drawing it costs one textured quad instead
# of nine texture taps per pixel every frame.
static func shadow_texture(texture: Texture2D, softness: float, strength: float) -> Texture2D:
	if texture == null:
		return null
	# Generated ImageTextures (card art) have an empty resource_path; key those by
	# instance id so different cards never reuse the first card's silhouette.
	var source_key := texture.resource_path
	if source_key.is_empty():
		source_key = str(texture.get_instance_id())
	var key := "%s|%.1f|%.2f" % [source_key, softness, strength]
	if _shadow_cache.has(key):
		return _shadow_cache[key]
	var image := _editable_image(texture)
	if image == null:
		return null
	var w := image.get_width()
	var h := image.get_height()
	var scale := minf(1.0, 256.0 / float(maxi(w, h)))
	if scale < 1.0:
		w = maxi(1, roundi(w * scale))
		h = maxi(1, roundi(h * scale))
		image.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var radius := clampi(roundi(softness * scale), 1, 8)
	var alpha := _blur_alpha(image, radius)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var a := clampf(alpha[y * w + x] * strength, 0.0, 1.0)
			if a > 0.002:
				out.set_pixel(x, y, Color(0.04, 0.02, 0.01, a))
	var result := ImageTexture.create_from_image(out)
	_shadow_cache[key] = result
	return result

static func _blur_alpha(image: Image, radius: int) -> PackedFloat32Array:
	var w := image.get_width()
	var h := image.get_height()
	var src := PackedFloat32Array()
	src.resize(w * h)
	for y in h:
		for x in w:
			src[y * w + x] = image.get_pixel(x, y).a
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	for _pass in 2:
		for y in h:
			for x in w:
				var total := 0.0
				for k in range(-radius, radius + 1):
					total += src[y * w + clampi(x + k, 0, w - 1)]
				tmp[y * w + x] = total / float(radius * 2 + 1)
		for y in h:
			for x in w:
				var total := 0.0
				for k in range(-radius, radius + 1):
					total += tmp[clampi(y + k, 0, h - 1) * w + x]
				src[y * w + x] = total / float(radius * 2 + 1)
	return src

# Kit-plate style for list/option rows (9-sliced, so any width works) with hover/press tints.
static func apply_plate_style(btn: Button, tint := Color.WHITE) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := kit_stylebox("panel_reserve", 6, 8)
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		var shade := tint
		match state:
			"hover":
				shade = tint.lightened(0.15)
			"pressed":
				shade = tint.darkened(0.2)
			"disabled":
				shade = Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7, 0.8)
		style.modulate_color = shade
		btn.add_theme_stylebox_override(state, style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

# `level` picks the background set: 1-3 the meadow, 4-7 the autumn town, 8+ (and
# Endless, passed as 999) the castle; 0 (menus) uses the meadow. The castle has a
# dedicated portrait crop, so each orientation gets the right source.
static func background_path(landscape: bool, level: int = 0) -> String:
	# The main menu has its own landscape city; portrait keeps the painted portrait.
	if level <= 0 and landscape and ResourceLoader.exists("res://assets/ui/background_menu.png"):
		return "res://assets/ui/background_menu.png"
	# Levels 7-15 ship their own painted backdrop (portrait variant included). Endless
	# (999) uses the last campaign one, the endgame scene, so runs stay coherent.
	if level >= LEVEL_BACKGROUND_FROM:
		var number := mini(level, LEVEL_BACKGROUND_MAX)
		var suffix := "" if landscape else "_portrait"
		var scene := "%slevel_%02d%s.png" % [LEVEL_BACKGROUND_DIR, number, suffix]
		if ResourceLoader.exists(scene):
			return scene
		var scene_landscape := "%slevel_%02d.png" % [LEVEL_BACKGROUND_DIR, number]
		if ResourceLoader.exists(scene_landscape):
			return scene_landscape
	if level >= CASTLE_FROM_LEVEL:
		var castle := CASTLE_LANDSCAPE if landscape else CASTLE_PORTRAIT
		if ResourceLoader.exists(castle):
			return castle
		if ResourceLoader.exists(CASTLE_LANDSCAPE):
			return CASTLE_LANDSCAPE
	if level >= AUTUMN_FROM_LEVEL and ResourceLoader.exists("res://assets/ui/background_autumn.png"):
		return "res://assets/ui/background_autumn.png"
	return "res://assets/ui/background.png" if landscape else "res://assets/ui/background_portrait.png"

static func make_background(landscape: bool, level: int = 0) -> Control:
	var path := background_path(landscape, level)
	if not ResourceLoader.exists(path):
		var flat := ColorRect.new()
		flat.color = WARM_BACKGROUND
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return flat
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = load(path) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Painted art, not pixel art: linear filtering keeps the blur smooth when scaled.
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/ui/background_filter.gdshader")
	var menu := level <= 0
	# Menu: almost no blur, high brightness/saturation, tiny tint/vignette. Gameplay:
	# lighter than before so the delivered art stays defined, still calm enough for cards.
	mat.set_shader_parameter("blur_texels", 0.30 if menu else 0.60)
	mat.set_shader_parameter("brightness", 0.90 if menu else 0.82)
	mat.set_shader_parameter("saturation", 0.95 if menu else 0.90)
	mat.set_shader_parameter("tint_strength", 0.05 if menu else 0.08)
	mat.set_shader_parameter("vignette_strength", 0.25 if menu else 0.35)
	bg.material = mat
	return bg

# Dark outline + drop shadow for text drawn straight over the painted background.
static func add_text_shadow(label: Label, outline := 4) -> void:
	label.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.03, 0.92))
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

static func total_stars_text() -> String:
	# Looked up at call time: naming the `Game` autoload here would stop this script compiling
	# in the headless test runner (autoloads are not registered while it loads suites).
	var game: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Game")
	return "★ %d/%d" % [game.progress.total_stars(), LevelLoader.load_all_level_ids().size() * 3]

static func symbol_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", symbol_font())
	return label
