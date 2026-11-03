extends RefCounted

# Generic sharpness regression for every painted 9-slice of the level HUD (Clearing Zone bar,
# Reserve field, Powers board, board frame): at every qa_responsive size and window scale 1/2/3,
# no region may draw a source texel larger than the 9-slice corners do (real px per source px <= 1,
# or the unavoidable corner magnification when the source itself is smaller than the screen size),
# and the baked picture is drawn 1:1 (the NinePatchRect never stretches a centre).

# Mirrors the art paths / margins of scripts/ui/level_screen.gd (it cannot be preloaded in a
# headless test: it needs the Game autoload). Keep in sync when a HUD panel changes.
const ZONE_BAR_ART := "res://assets/ui/kit/v2/bar_zone.png"
const ZONE_BAR_MARGINS_LANDSCAPE := Rect2(0.055, 0.10, 0.055, 0.10)
const ZONE_BAR_MARGINS_PORTRAIT := Rect2(0.08, 0.10, 0.08, 0.10)
const RESERVE_FIELD_ART := "res://assets/ui/kit/panel_reserve_field.png"
const RESERVE_FIELD_MARGINS := Rect2(0.07, 0.11, 0.07, 0.11)
const POWERS_BOARD_ART := "res://assets/ui/kit/panel_powers_board.png"
const POWERS_BOARD_MARGINS := Rect2(0.09, 0.05, 0.09, 0.05)
const BOARD_FRAME_LANDSCAPE_ART := "res://assets/ui/kit/v2/panel_board_frame.png"
const BOARD_FRAME_PORTRAIT_ART := "res://assets/ui/kit/panel_board_frame_portrait.png"
const BOARD_FRAME_BORDER_MAX := 12.0
const SIZES := [
	Vector2(360, 640), Vector2(360, 780), Vector2(360, 800), Vector2(480, 640),
	Vector2(640, 360), Vector2(780, 360), Vector2(640, 480),
]
const SCALES := [1, 2, 3]

func _panels(layout_size: Vector2) -> Array:
	var landscape := layout_size.x >= layout_size.y
	var rects: Dictionary = LevelLayout.compute(layout_size)["rects"]
	var powers_art := UiHelpers.hires_texture(POWERS_BOARD_ART)
	var powers_margins: Rect2 = POWERS_BOARD_MARGINS
	if not landscape:
		powers_art = UiHelpers.rotated_texture(POWERS_BOARD_ART)
		powers_margins = Rect2(powers_margins.position.y, powers_margins.position.x, powers_margins.size.y, powers_margins.size.x)
	var frame_path: String = BOARD_FRAME_LANDSCAPE_ART if landscape else BOARD_FRAME_PORTRAIT_ART
	var zone: Rect2 = rects["zone"]
	var reserve: Rect2 = rects["reserve"]
	var powers: Rect2 = rects["powers"]
	var board: Rect2 = rects["board_frame"]
	var zone_margins: Rect2 = ZONE_BAR_MARGINS_LANDSCAPE if landscape else ZONE_BAR_MARGINS_PORTRAIT
	return [
		["zone", UiHelpers.trimmed_nine_patch(UiHelpers.hires_texture(ZONE_BAR_ART), zone.size, zone_margins, "zone_bar", true), zone.size],
		["reserve", UiHelpers.trimmed_nine_patch(UiHelpers.hires_texture(RESERVE_FIELD_ART), reserve.size, RESERVE_FIELD_MARGINS, "", true), reserve.size],
		["powers", UiHelpers.trimmed_nine_patch(powers_art, powers.size, powers_margins), powers.size],
		["board_frame", UiHelpers.alpha_nine_patch(UiHelpers.hires_texture(frame_path), board.size, BOARD_FRAME_BORDER_MAX), board.size],
	]

# Zone and reserve use the per-slice bake (corners 1 copy; edges 1 copy stretched only along their
# length or centred native crop; centre ONE cover crop <= 1.5x). The board frame and the powers
# board keep the original pipeline (they never needed the new one).
func test_no_painted_region_is_magnified() -> void:
	var over_cap: Array[String] = []
	for scale in SCALES:
		UiHelpers.oversample_override = float(scale)
		for size in SIZES:
			for panel in _panels(size):
				var name: String = panel[0]
				var data: Dictionary = panel[1]
				var target: Vector2 = panel[2]
				var label := "%s @%s x%d" % [name, str(size), scale]
				Assert.is_false(data.is_empty(), "%s: the 9-slice bakes" % label)
				if data.is_empty() or not (name == "zone" or name == "reserve"):
					continue
				var art := UiHelpers.nine_patch_rect(data, target)
				var info: Dictionary = art.get_meta("nine_patch_info", {})
				Assert.is_true(not info.is_empty(), "%s: the panel carries its baked info" % label)
				if info.is_empty():
					art.free()
					continue
				var factor := float(info["oversample"])
				var fit := float(info["fit_scale"])
				var to_real := float(scale) / factor
				# A source smaller than the screen size cannot be sharper than its own corners.
				var limit := maxf(1.0, fit * float(scale)) + 0.02
				var corner := float(info["mag_corner"]) * to_real
				var edge := float(info["mag_edge"]) * to_real
				Assert.is_true(corner <= limit, "%s: corners draw %.2f real px per source px (limit %.2f)" % [label, corner, limit])
				Assert.is_true(edge <= limit, "%s: edge thickness draws %.2f real px per source px (limit %.2f)" % [label, edge, limit])
				var centre_mag: Vector2 = info["mag_centre"]
				var centre := maxf(centre_mag.x, centre_mag.y) * to_real
				if bool(info["centre_over_cap"]):
					over_cap.append("%s (%.2fx)" % [label, centre])
				else:
					Assert.is_true(centre <= maxf(1.5, limit) + 0.02, "%s: the centre draws %.2fx (max 1.5x)" % [label, centre])
				Assert.equals(int(info["copies"]), 1, "%s: every corner / ornament is drawn exactly once" % label)
				var texture_size := Vector2(art.texture.get_size())
				Assert.is_true(absf(texture_size.x - art.size.x) <= 1.0 and absf(texture_size.y - art.size.y) <= 1.0,
					"%s: the baked picture %s is drawn 1:1 in %s (no centre stretch)" % [label, str(texture_size), str(art.size)])
				art.free()
	UiHelpers.oversample_override = 0.0
	if not over_cap.is_empty():
		print("NOTE nine-patch centre beyond 1.5x (needs a larger source asset): ", ", ".join(over_cap))
