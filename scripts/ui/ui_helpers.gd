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
static var _card_texture_cache_lru: Array[String] = []
static var _frame_cache: Dictionary = {}
static var _frame_cache_lru: Array[String] = []
static var _alpha_bounds_cache: Dictionary = {}
static var _alpha_bounds_cache_lru: Array[String] = []
static var _shadow_cache: Dictionary = {}
static var _shadow_cache_lru: Array[String] = []
const CARD_TEXTURE_CACHE_LIMIT := 64
const FRAME_CACHE_LIMIT := 64
const ALPHA_BOUNDS_CACHE_LIMIT := 64
const SHADOW_CACHE_LIMIT := 48

static func _cache_touch(order: Array[String], key: String) -> void:
	order.erase(key)
	order.append(key)

static func _cache_store(cache: Dictionary, order: Array[String], key: String, value: Variant, limit: int) -> void:
	cache[key] = value
	_cache_touch(order, key)
	while order.size() > limit:
		var expired: String = order.pop_front()
		cache.erase(expired)

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
# and pixelated it once the window upscaled the result). Imported mipmaps are preferred; a runtime
# fallback keeps unconfigured or generated art usable. Cached per type.
static func card_texture(type: String) -> Texture2D:
	return hires_texture("res://assets/cards/card_%s.png" % type)

# Any painted (not pixel-art) picture at full resolution: loaded once and cached by path, null when
# the file is missing. Imports provide mipmaps; unconfigured textures keep a runtime fallback.
static func hires_texture(path: String) -> Texture2D:
	if _card_texture_cache.has(path):
		_cache_touch(_card_texture_cache_lru, path)
		return _card_texture_cache[path]
	else:
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			var source := load(path) as Texture2D
			if source is CompressedTexture2D:
				# Imported PNGs carry mipmaps in their .import settings. Do not read the full
				# compressed image back to CPU just to check a property already known here.
				texture = source
			else:
				var image := source.get_image() if source != null else null
				if image != null:
					if image.has_mipmaps():
						texture = source
					else:
						image = image.duplicate()
						if image.is_compressed():
							image.decompress()
						image.generate_mipmaps()
						texture = ImageTexture.create_from_image(image)
				else:
					texture = source
		_cache_store(_card_texture_cache, _card_texture_cache_lru, path, texture, CARD_TEXTURE_CACHE_LIMIT)
		return texture

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

# Imported PNGs sometimes retain 1-4/255 alpha noise around painted panels. Image.get_used_rect()
# includes that fringe, so 9-slices treat the whole source as content and squeeze the visible
# border inward. Cache the thresholded visible bounds by texture path; use alpha > 16/255.
static func _visible_alpha_rect(image: Image, cache_key: String) -> Rect2i:
	if _alpha_bounds_cache.has(cache_key):
		_cache_touch(_alpha_bounds_cache_lru, cache_key)
		return _alpha_bounds_cache[cache_key]
	var w := image.get_width()
	var h := image.get_height()
	var threshold := 16
	var top := 0
	while top < h and not _alpha_row_visible(image, top, threshold):
		top += 1
	var bottom := h - 1
	while bottom >= top and not _alpha_row_visible(image, bottom, threshold):
		bottom -= 1
	var left := 0
	while left < w and not _alpha_column_visible(image, left, top, bottom, threshold):
		left += 1
	var right := w - 1
	while right >= left and not _alpha_column_visible(image, right, top, bottom, threshold):
		right -= 1
	var bounds := image.get_used_rect()
	if right >= left and bottom >= top:
		bounds = Rect2i(left, top, right - left + 1, bottom - top + 1)
	_cache_store(_alpha_bounds_cache, _alpha_bounds_cache_lru, cache_key, bounds, ALPHA_BOUNDS_CACHE_LIMIT)
	return bounds

static func _alpha_row_visible(image: Image, y: int, threshold: int) -> bool:
	for x in image.get_width():
		if roundi(image.get_pixel(x, y).a * 255.0) > threshold:
			return true
	return false

static func _alpha_column_visible(image: Image, x: int, top: int, bottom: int, threshold: int) -> bool:
	for y in range(top, bottom + 1):
		if roundi(image.get_pixel(x, y).a * 255.0) > threshold:
			return true
	return false

# 9-slice a painted frame that has a transparent centre, showing only its visible
# border: crops the alpha bounding box, fits it and caps the border thickness (so a
# thick painted bevel never eats the play area). Returns the fitted texture, the
# 9-slice margins and the real inner hole, in target-local px. Cached by texture
# path, target size and border cap.
static func alpha_nine_patch(texture: Texture2D, target_size: Vector2, max_border: float = 8.0) -> Dictionary:
	var key := "%s|%.0fx%.0f|%.1f|x%.2f" % [
		texture.resource_path if texture != null else "",
		target_size.x, target_size.y, max_border, ui_oversample(),
	]
	if _frame_cache.has(key):
		_cache_touch(_frame_cache_lru, key)
		return _frame_cache[key]
	var image := _editable_image(texture)
	if image == null or target_size.x <= 0.0 or target_size.y <= 0.0:
		return {}
	var bounds_key := texture.resource_path if texture != null else ""
	if bounds_key.is_empty() and texture != null:
		bounds_key = str(texture.get_instance_id())
	var used := _visible_alpha_rect(image, bounds_key)
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
	result.merge(_hires_nine_patch(crop, Vector2(fitted.get_width(), fitted.get_height()), result["margins"]))
	_cache_store(_frame_cache, _frame_cache_lru, key, result, FRAME_CACHE_LIMIT)
	return result

# 9-slice a painted panel with fixed proportional margins: the texture is cropped
# to its alpha bounding box, fitted to the target height (preserving its aspect),
# and the margins are scaled with it. Use this for panels whose corner ornaments
# must not be cut (the reserve field, the powers board). `margin_ratio` is
# (left, top, right, bottom) as fractions of the CROPPED texture size.
static func trimmed_nine_patch(texture: Texture2D, target_size: Vector2, margin_ratio: Rect2, cache_key: String = "", smart_bake: bool = false) -> Dictionary:
	var source_key := cache_key if not cache_key.is_empty() else (texture.resource_path if texture != null else "")
	var key := "trim|%s|%.0fx%.0f|%s|x%.2f|%s" % [source_key, target_size.x, target_size.y, str(margin_ratio), ui_oversample(), str(smart_bake)]
	if _frame_cache.has(key):
		_cache_touch(_frame_cache_lru, key)
		return _frame_cache[key]
	var image := _editable_image(texture)
	if image == null or target_size.x <= 0.0 or target_size.y <= 0.0:
		return {}
	var bounds_key := source_key
	if bounds_key.is_empty() and texture != null:
		bounds_key = str(texture.get_instance_id())
	var used := _visible_alpha_rect(image, bounds_key)
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
	if smart_bake:
		result.merge(_baked_nine_patch(crop, target_size, result["margins"], Vector2(fitted.get_width(), fitted.get_height())))
	else:
		result.merge(_hires_nine_patch(crop, Vector2(fitted.get_width(), fitted.get_height()), result["margins"]))
	_cache_store(_frame_cache, _frame_cache_lru, key, result, FRAME_CACHE_LIMIT)
	return result

# How many real pixels one design pixel covers right now: the window is drawn with the
# canvas_items stretch, so a 64 px design panel is 128+ real px on a 2x window. Painted
# 9-slices baked at design size would be upscaled by the GPU (blurry), so they are also
# baked at this factor and drawn scaled back down (see nine_patch_rect). 1..4.
# Tests pin the factor here (a headless SceneTree script has no main loop yet); 0 = measure the window.
static var oversample_override := 0.0

static func ui_oversample() -> float:
	if oversample_override > 0.0:
		return oversample_override
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 1.0
	var design := Vector2(tree.root.content_scale_size)
	var real := Vector2(tree.root.size)
	if design.x <= 0.0 or design.y <= 0.0 or real.x <= 0.0 or real.y <= 0.0:
		return 1.0
	var factor := maxf(real.x / design.x, real.y / design.y)
	# Snap up to half steps so small window jitters reuse the cache.
	return clampf(ceilf(factor * 2.0) / 2.0, 1.0, 4.0)

# The oversampled copy of a 9-slice: the same crop resized to `design_size` times the
# oversample factor (never above the source resolution), margins scaled to match. Adds
# hires_texture / hires_margins / oversample; empty when no oversampling is needed.
static func _hires_nine_patch(crop: Image, design_size: Vector2, margins: Rect2i) -> Dictionary:
	if design_size.x <= 0.0 or design_size.y <= 0.0:
		return {}
	var factor := minf(ui_oversample(), minf(crop.get_width() / design_size.x, crop.get_height() / design_size.y))
	if factor <= 1.01:
		return {}
	var hires: Image = crop.duplicate()
	hires.resize(maxi(2, roundi(design_size.x * factor)), maxi(2, roundi(design_size.y * factor)), Image.INTERPOLATE_LANCZOS)
	hires.generate_mipmaps()
	var hw := hires.get_width()
	var hh := hires.get_height()
	return {
		"hires_texture": ImageTexture.create_from_image(hires),
		"hires_margins": Rect2i(
			clampi(roundi(margins.position.x * factor), 1, hw / 2),
			clampi(roundi(margins.position.y * factor), 1, hh / 2),
			clampi(roundi(margins.size.x * factor), 1, hw / 2),
			clampi(roundi(margins.size.y * factor), 1, hh / 2)),
		"oversample": factor,
	}

# Opt-in bake for panels whose target aspect is far from the art's (the Clearing Zone bar, the
# Reserve strip), used instead of _hires_nine_patch. The picture is composed per slice at exactly
# `target_size * factor` px and drawn 1:1, so nothing is stretched by the GPU:
#  - corners: ONE copy at the fit scale (<= 1 source texel per px),
#  - edges: ONE copy; thickness fixed, and along their length either the centred native-scale
#    crop of the strip (when the strip is longer than needed: its ornament appears once,
#    unscaled) or the whole strip stretched lengthwise (a uniform bar does not blur),
#  - centre: ONE uniform "cover" crop of the source centre, no tiling or mirroring, magnified at
#    most 1.5x (past that the crop is stretched and `centre_over_cap` reports it: it needs a
#    taller / wider source asset).
# Adds hires_texture / hires_margins / oversample and the info tests/test_nine_patch_sharpness.gd
# reads: mag_corner, mag_edge (thickness), mag_centre (baked texels per source px, per axis).
const BAKE_CENTRE_MAX_MAG := 1.5
const BAKE_FEATHER_PX := 28

# Feathers the cropped `piece` (edited in place) into `whole` (the same slice squeezed to fit):
# whole at the borders of the cropped axes, piece from BAKE_FEATHER_PX px inside (smoothstep), so
# the crop never jumps against the neighbouring slices. Only the feather bands are touched.
static func _feather_blend(whole: Image, piece: Image, feather_x: bool, feather_y: bool) -> void:
	var w := piece.get_width()
	var h := piece.get_height()
	var span := mini(BAKE_FEATHER_PX, mini(w if feather_x else 9999, h if feather_y else 9999) / 2)
	if span < 1:
		return
	for y in h:
		var dy := mini(y, h - 1 - y) if feather_y else span
		var full_row := dy < span
		var xs: Array = []
		if full_row:
			xs = range(w)
		elif feather_x:
			xs = range(span) + range(w - span, w)
		for x in xs:
			var dx := mini(x, w - 1 - x) if feather_x else span
			var d := mini(dx, dy)
			var t := float(d) / float(span)
			t = t * t * (3.0 - 2.0 * t)
			piece.set_pixel(x, y, whole.get_pixel(x, y).lerp(piece.get_pixel(x, y), t))

static func _baked_nine_patch(crop: Image, target_size: Vector2, margins: Rect2i, fitted_size: Vector2) -> Dictionary:
	if target_size.x <= 0.0 or target_size.y <= 0.0 or fitted_size.x <= 0.0 or fitted_size.y <= 0.0:
		return {}
	var w := crop.get_width()
	var h := crop.get_height()
	var sx := fitted_size.x / float(w)
	var sy := fitted_size.y / float(h)
	var factor := clampf(minf(ui_oversample(), 1.0 / maxf(sx, sy)), 1.0, 4.0)
	var out_w := maxi(2, roundi(target_size.x * factor))
	var out_h := maxi(2, roundi(target_size.y * factor))
	var kx := sx * factor
	var ky := sy * factor
	var sl := clampi(roundi(margins.position.x / sx), 1, w / 2 - 1)
	var st := clampi(roundi(margins.position.y / sy), 1, h / 2 - 1)
	var sr := clampi(roundi(margins.size.x / sx), 1, w / 2 - 1)
	var sb := clampi(roundi(margins.size.y / sy), 1, h / 2 - 1)
	var dl := maxi(1, roundi(sl * kx))
	var dt := maxi(1, roundi(st * ky))
	var dr := maxi(1, roundi(sr * kx))
	var db := maxi(1, roundi(sb * ky))
	if dl + dr > out_w - 2:
		var f := float(out_w - 2) / float(dl + dr)
		dl = maxi(1, floori(dl * f))
		dr = maxi(1, floori(dr * f))
	if dt + db > out_h - 2:
		var f2 := float(out_h - 2) / float(dt + db)
		dt = maxi(1, floori(dt * f2))
		db = maxi(1, floori(db * f2))
	var src_x := [0, sl, w - sr, w]
	var src_y := [0, st, h - sb, h]
	var dst_x := [0, dl, out_w - dr, out_w]
	var dst_y := [0, dt, out_h - db, out_h]
	var source: Image = crop.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	var baked := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	var mag_corner := 0.0
	var mag_edge := 0.0
	var mag_centre := Vector2.ZERO
	var over_cap := false
	for row in 3:
		for col in 3:
			var src := Rect2i(src_x[col], src_y[row], src_x[col + 1] - src_x[col], src_y[row + 1] - src_y[row])
			var dst := Rect2i(dst_x[col], dst_y[row], dst_x[col + 1] - dst_x[col], dst_y[row + 1] - dst_y[row])
			if src.size.x < 1 or src.size.y < 1 or dst.size.x < 1 or dst.size.y < 1:
				continue
			var part := Rect2(src)
			if col == 1 and row == 1:
				# Centre: uniform cover crop, magnification capped.
				var need_x := float(dst.size.x) / float(src.size.x)
				var need_y := float(dst.size.y) / float(src.size.y)
				var u := maxf(need_x, need_y)
				if u > BAKE_CENTRE_MAX_MAG:
					u = BAKE_CENTRE_MAX_MAG
					over_cap = true
				var cw := minf(float(src.size.x), float(dst.size.x) / u)
				var ch := minf(float(src.size.y), float(dst.size.y) / u)
				part = Rect2(Vector2(src.position) + (Vector2(src.size) - Vector2(cw, ch)) * 0.5, Vector2(cw, ch))
				mag_centre = Vector2(float(dst.size.x) / cw, float(dst.size.y) / ch)
			elif col == 1:
				# Top / bottom edge: runs along x.
				if float(dst.size.x) <= float(src.size.x) * kx:
					var len_x := float(dst.size.x) / kx
					part = Rect2(Vector2(src.position.x + (src.size.x - len_x) * 0.5, src.position.y), Vector2(len_x, src.size.y))
				mag_edge = maxf(mag_edge, float(dst.size.y) / float(src.size.y))
			elif row == 1:
				# Left / right edge: runs along y.
				if float(dst.size.y) <= float(src.size.y) * ky:
					var len_y := float(dst.size.y) / ky
					part = Rect2(Vector2(src.position.x, src.position.y + (src.size.y - len_y) * 0.5), Vector2(src.size.x, len_y))
				mag_edge = maxf(mag_edge, float(dst.size.x) / float(src.size.x))
			else:
				mag_corner = maxf(mag_corner, maxf(float(dst.size.x) / float(src.size.x), float(dst.size.y) / float(src.size.y)))
			var region := Rect2i(Vector2i(roundi(part.position.x), roundi(part.position.y)),
				Vector2i(maxi(1, roundi(part.size.x)), maxi(1, roundi(part.size.y))))
			region = region.intersection(Rect2i(0, 0, w, h))
			var piece: Image = source.get_region(region)
			if piece.get_width() != dst.size.x or piece.get_height() != dst.size.y:
				piece.resize(dst.size.x, dst.size.y, Image.INTERPOLATE_LANCZOS)
			var crop_x := part.size.x < float(src.size.x) - 0.5
			var crop_y := part.size.y < float(src.size.y) - 0.5
			if crop_x or crop_y:
				# The crop skips source content, so its borders would jump against the neighbouring
				# slices (lighting / vignette): feather them into the whole slice squeezed to fit.
				var whole: Image = source.get_region(src)
				whole.resize(dst.size.x, dst.size.y, Image.INTERPOLATE_LANCZOS)
				_feather_blend(whole, piece, crop_x, crop_y)
			baked.blit_rect(piece, Rect2i(Vector2i.ZERO, dst.size), dst.position)
	baked.generate_mipmaps()
	return {
		"hires_texture": ImageTexture.create_from_image(baked),
		"hires_margins": Rect2i(dl, dt, dr, db),
		"oversample": factor,
		"mag_corner": mag_corner,
		"mag_edge": mag_edge,
		"mag_centre": mag_centre,
		"centre_over_cap": over_cap,
		"copies": 1,
		"baked_size": Vector2i(out_w, out_h),
		"fit_scale": maxf(sx, sy),
	}

# A NinePatchRect for alpha_nine_patch / trimmed_nine_patch data filling `size` design px.
# With an oversampled bake it is laid out `oversample` times larger and scaled back down,
# so the corners keep their design size but are sampled at the real screen resolution.
# StyleBoxTexture users keep reading "texture"/"margins" (design size) unchanged.
static func nine_patch_rect(data: Dictionary, size: Vector2) -> NinePatchRect:
	var art := NinePatchRect.new()
	var hires := data.has("hires_texture")
	var factor := float(data.get("oversample", 1.0)) if hires else 1.0
	art.texture = data["hires_texture"] if hires else data.get("texture")
	var margins: Rect2i = data["hires_margins"] if hires else data.get("margins", Rect2i())
	art.patch_margin_left = margins.position.x
	art.patch_margin_top = margins.position.y
	art.patch_margin_right = margins.size.x
	art.patch_margin_bottom = margins.size.y
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size = size * factor
	art.scale = Vector2.ONE / factor
	if hires and data.has("mag_centre"):
		art.set_meta("nine_patch_info", {
			"oversample": factor, "mag_corner": data["mag_corner"], "mag_edge": data["mag_edge"],
			"mag_centre": data["mag_centre"], "centre_over_cap": data["centre_over_cap"],
			"copies": data["copies"], "baked_size": data["baked_size"], "fit_scale": data["fit_scale"],
		})
	return art

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
		_cache_touch(_shadow_cache_lru, key)
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
	_cache_store(_shadow_cache, _shadow_cache_lru, key, result, SHADOW_CACHE_LIMIT)
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

static func make_background(landscape: bool, level: int = 0, path_override: String = "") -> Control:
	var path := path_override if not path_override.is_empty() else background_path(landscape, level)
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
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
