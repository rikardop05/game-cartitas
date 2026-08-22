class_name BoardLayout
extends RefCounted

# Single source of scale for rendering the board. Cards are generated in
# logical space (see LayoutGenerator._geometry); this function maps logical
# positions onto a target container with one uniform scale. Nothing snaps to a
# fixed pitch here — the logical spacing is preserved, so distinct slots never
# collapse onto the same cell. When the fitted scale would fall below
# min_scale (LevelConfig.MIN_CARD_SCALE), it is clamped UP to the floor and
# scale_limited is reported so the caller can expose a layout warning instead
# of silently rendering tiny cards. `margin` reserves logical space (e.g. the
# renderer's depth-cue layer offset) so edge cards never clip the container.
static func compute(positions: Array, container: Vector2, card_size: float, min_scale: float = 1.0, margin: Vector2 = Vector2.ZERO) -> Dictionary:
	if positions.is_empty():
		return {"scale": 1.0, "offset": Vector2.ZERO, "origin": Vector2.ZERO, "span_x": 0.0, "span_y": 0.0, "scale_limited": false}
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	for p in positions:
		var v: Vector2 = p
		minx = minf(minx, v.x)
		maxx = maxf(maxx, v.x)
		miny = minf(miny, v.y)
		maxy = maxf(maxy, v.y)
	var span_x := maxx - minx
	var span_y := maxy - miny
	var total_x := span_x + card_size + margin.x
	var total_y := span_y + card_size + margin.y
	var scale := 1.0
	if container.x > 0.0 and container.y > 0.0 and total_x > 0.0 and total_y > 0.0:
		scale = minf(container.x / total_x, container.y / total_y)
	var scale_limited := false
	if scale < min_scale:
		scale = min_scale
		scale_limited = true
	scale = clampf(scale, 0.01, 2.5)
	var offset := Vector2(
		(container.x - total_x * scale) / 2.0,
		(container.y - total_y * scale) / 2.0
	)
	return {
		"scale": scale,
		"offset": offset,
		"origin": Vector2(minx, miny),
		"span_x": span_x,
		"span_y": span_y,
		"scale_limited": scale_limited,
	}