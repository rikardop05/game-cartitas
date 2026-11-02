class_name LevelLayout
extends RefCounted

## Responsive logical-pixel layout for the game HUD and its touch controls.
## Rectangles are recomputed from the expanded viewport (the content-scale size remains
## the orientation's design minimum); art can intentionally overlap the board, controls cannot.

const FRAME_MARGIN := 12.0
const LAND_FRAME_ASPECT := 1.74

static func compute(viewport_size: Vector2) -> Dictionary:
	var size := Vector2(maxf(1.0, viewport_size.x), maxf(1.0, viewport_size.y))
	if size.x >= size.y:
		return _landscape(size)
	return _portrait(size)

static func _portrait(size: Vector2) -> Dictionary:
	var w := size.x
	var h := size.y
	var edge := 8.0
	var card_side := minf(58.0, maxf(32.0, (w - 48.0) / 4.0))
	var zone_gap := 6.0
	var zone_cols := 4
	var zone_row_width := zone_cols * card_side + (zone_cols - 1) * zone_gap
	var zone_height := card_side * 2.0 + 18.0
	var reserve_height := 48.0
	var reserve := Rect2(edge, h - reserve_height - edge, w - edge * 2.0, reserve_height)
	var zone := Rect2(edge, reserve.position.y - zone_height - 7.0, w - edge * 2.0, zone_height)
	var power_height := 58.0
	var powers := Rect2(edge, zone.position.y - power_height - 6.0, w - edge * 2.0, power_height)
	var clock_height := 36.0
	var clock := Rect2((w - 104.0) * 0.5, powers.position.y - clock_height - 4.0, 104.0, clock_height)
	var board_top := 80.0
	var board_bottom := clock.position.y + 18.0
	var board := Rect2(edge, board_top, w - edge * 2.0, maxf(80.0, board_bottom - board_top))
	var deck_side := 58.0
	var deck_y := powers.position.y
	var deck_a := Rect2(edge, deck_y, deck_side, deck_side)
	var deck_b := Rect2(w - edge - deck_side, deck_y, deck_side, deck_side)
	var panel_left := deck_a.end.x + 7.0
	var panel_right := deck_b.position.x - 7.0
	powers = Rect2(panel_left, deck_y, maxf(64.0, panel_right - panel_left), power_height)
	var powers_inner := powers.grow(-5.0)
	var button_gap := 2.0
	var button_width := (powers_inner.size.x - button_gap * 2.0) / 3.0
	var power_buttons: Array[Rect2] = []
	for index in 3:
		power_buttons.append(Rect2(
			powers_inner.position.x + index * (button_width + button_gap),
			powers_inner.position.y,
			button_width,
			powers_inner.size.y))
	var zone_cards := Rect2(
		(w - zone_row_width) * 0.5,
		zone.position.y + 8.0,
		zone_row_width,
		card_side * 2.0 + zone_gap)
	var reserve_inner := reserve.grow(-5.0)
	var plaque := Rect2((w - 90.0) * 0.5, 39.0, 90.0, 36.0)
	var logo := Rect2((w - 112.0) * 0.5, 1.0, 112.0, 43.0)
	var back := Rect2(4.0, 7.0, 32.0, 32.0)
	var sound := Rect2(42.0, 7.0, 32.0, 32.0)
	var help := Rect2(w - 76.0, 7.0, 32.0, 32.0)
	var gear := Rect2(w - 40.0, 6.0, 32.0, 32.0)
	var title := Rect2()
	var stopwatch := Rect2(2.0, 2.0, 32.0, 32.0)
	var score := Rect2(edge, clock.position.y, 84.0, 32.0)
	var instruction := Rect2(w - 82.0, board.position.y + 8.0, 74.0, 82.0)
	var mascot := Rect2(0.0, board.position.y + 12.0, minf(116.0, w * 0.32), maxf(80.0, board.size.y - 24.0))
	var frame_inner := board.grow(-FRAME_MARGIN)
	var rects := {
		"back": back,
		"sound": sound,
		"logo": logo,
		"plaque": plaque,
		"help": help,
		"gear": gear,
		"level_title": title,
		"clock_pill": clock,
		"stopwatch_in_pill": stopwatch,
		"score_pill": score,
		"board_frame": board,
		"board_inner": frame_inner,
		"deck_a": deck_a,
		"deck_b": deck_b,
		"powers": powers,
		"powers_inner": powers_inner,
		"reserve": reserve,
		"reserve_inner": reserve_inner,
		"zone": zone,
		"zone_cards": zone_cards,
		"mascot_area": mascot,
		"instruction_area": instruction,
	}
	var interactive: Array[Rect2] = [back, sound, help, gear, deck_a, deck_b, reserve, zone_cards, board]
	interactive.append_array(power_buttons)
	return {
		"orientation": "portrait",
		"viewport": size,
		"hud": Rect2(Vector2.ZERO, size),
		"header_height": plaque.end.y + 3.0,
		"rects": rects,
		"interactive": interactive,
		"power_buttons": power_buttons,
		"zone_columns": zone_cols,
		"zone_card_size": Vector2(card_side, card_side),
		"zone_h_separation": zone_gap,
		"zone_v_separation": zone_gap,
		"clock_text_inset": 34.0,
	}

static func _landscape(size: Vector2) -> Dictionary:
	var w := size.x
	var h := size.y
	var edge := 8.0
	var header_height := 48.0
	var reserve_height := 54.0
	var bottom_y := h - reserve_height - edge
	var reserve_width := minf(168.0, maxf(132.0, w * 0.27))
	var reserve := Rect2(edge, bottom_y, reserve_width, reserve_height)
	var zone_height := 62.0
	var zone := Rect2(reserve.end.x + 8.0, bottom_y - 8.0, maxf(100.0, w - reserve.end.x - 8.0 - edge), zone_height)
	var deck_side := 58.0
	var powers_x := w - edge - 64.0
	var board_x := maxf(112.0, w * 0.22)
	var board_right := powers_x - 12.0
	var available_width := maxf(180.0, board_right - board_x)
	var available_height := maxf(150.0, bottom_y - header_height - 16.0)
	# More vertical viewport space should grow the play window instead of leaving a dead band.
	# The 9-sliced painted border keeps its corners while the center adapts toward square at 4:3.
	var aspect_progress := clampf((w / h - 4.0 / 3.0) / (16.0 / 9.0 - 4.0 / 3.0), 0.0, 1.0)
	var frame_aspect := lerpf(1.15, LAND_FRAME_ASPECT, aspect_progress)
	var board_height := minf(available_height, available_width / frame_aspect)
	var board_width := available_width if board_height >= available_height - 0.01 else board_height * frame_aspect
	var board := Rect2(board_x, header_height + (available_height - board_height) * 0.5, board_width, board_height)
	var powers_height := minf(156.0, maxf(104.0, board.size.y * 0.72))
	var powers := Rect2(powers_x, board.position.y + 8.0, 64.0, powers_height)
	var powers_inner := powers.grow(-5.0)
	var power_gap := 2.0
	var power_height := (powers_inner.size.y - power_gap * 2.0) / 3.0
	var power_buttons: Array[Rect2] = []
	for index in 3:
		power_buttons.append(Rect2(
			powers_inner.position.x,
			powers_inner.position.y + index * (power_height + power_gap),
			powers_inner.size.x,
			power_height))
	var deck_y := board.end.y - deck_side
	var deck_a := Rect2(edge, deck_y, deck_side, deck_side)
	var deck_b := Rect2(w - edge - deck_side, deck_y, deck_side, deck_side)
	var card_side := minf(58.0, maxf(32.0, (zone.size.x - 12.0) / 7.0))
	var zone_gap := 2.0
	var zone_row_width := card_side * 7.0 + zone_gap * 6.0
	var zone_cards := Rect2(
		zone.position.x + (zone.size.x - zone_row_width) * 0.5,
		zone.position.y + (zone.size.y - card_side) * 0.5,
		zone_row_width,
		card_side)
	var clock := Rect2(46.0, 6.0, 106.0, 36.0)
	var plaque := Rect2((w - 90.0) * 0.5, 6.0, 90.0, 36.0)
	var logo := Rect2(w - 240.0, 2.0, 100.0, 40.0)
	var back := Rect2(6.0, 8.0, 32.0, 32.0)
	var help := Rect2(w - 128.0, 8.0, 32.0, 32.0)
	var gear := Rect2(w - 90.0, 6.0, 32.0, 32.0)
	var sound := Rect2(w - 48.0, 6.0, 32.0, 32.0)
	var title := Rect2()
	var stopwatch := Rect2(2.0, 2.0, 32.0, 32.0)
	var score := Rect2(clock.end.x + 6.0, 6.0, 84.0, 32.0)
	var instruction := Rect2(board.position.x + 12.0, board.position.y + 10.0, minf(180.0, board.size.x - 24.0), 58.0)
	var mascot := Rect2(0.0, board.position.y + 8.0, minf(148.0, board.position.x), maxf(80.0, board.size.y - 16.0))
	var frame_inner := board.grow(-FRAME_MARGIN)
	var rects := {
		"back": back,
		"sound": sound,
		"logo": logo,
		"plaque": plaque,
		"help": help,
		"gear": gear,
		"level_title": title,
		"clock_pill": clock,
		"stopwatch_in_pill": stopwatch,
		"score_pill": score,
		"board_frame": board,
		"board_inner": frame_inner,
		"deck_a": deck_a,
		"deck_b": deck_b,
		"powers": powers,
		"powers_inner": powers_inner,
		"reserve": reserve,
		"reserve_inner": reserve.grow(-5.0),
		"zone": zone,
		"zone_cards": zone_cards,
		"mascot_area": mascot,
		"instruction_area": instruction,
	}
	var interactive: Array[Rect2] = [back, help, gear, sound, deck_a, deck_b, reserve, zone_cards, board]
	interactive.append_array(power_buttons)
	return {
		"orientation": "landscape",
		"viewport": size,
		"hud": Rect2(0.0, 0.0, w, header_height),
		"header_height": header_height,
		"rects": rects,
		"interactive": interactive,
		"power_buttons": power_buttons,
		"zone_columns": 7,
		"zone_card_size": Vector2(card_side, card_side),
		"zone_h_separation": zone_gap,
		"zone_v_separation": zone_gap,
		"clock_text_inset": 34.0,
	}
