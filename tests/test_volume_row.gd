extends RefCounted

# Unit tests for the volume row's value <-> handle-position mapping. The handle must travel
# only inside the painted groove of Bar_adjust.png: at 0 its left edge touches the groove's
# left end, at 1 its right edge touches the groove's right end. Pure math, no nodes/autoloads.

const EPS := 0.001

func test_zero_puts_the_handle_left_edge_at_the_groove_left() -> void:
	var left := VolumeRow.groove_left_px()
	var drawn_left := VolumeRow.handle_left_for(0.0) + VolumeRow.HANDLE_INSET
	Assert.is_true(absf(drawn_left - left) < EPS,
		"0.0: drawn left %.3f sits at the groove left %.3f" % [drawn_left, left])

func test_full_puts_the_handle_right_edge_at_the_groove_right() -> void:
	var right := VolumeRow.groove_right_px()
	var drawn_right := VolumeRow.handle_left_for(1.0) + VolumeRow.HANDLE_INSET + VolumeRow.HANDLE_DRAWN_WIDTH
	Assert.is_true(absf(drawn_right - right) < EPS,
		"1.0: drawn right %.3f sits at the groove right %.3f" % [drawn_right, right])

func test_half_puts_the_handle_centre_at_the_groove_centre() -> void:
	var expected := (VolumeRow.groove_left_px() + VolumeRow.groove_right_px()) * 0.5
	var drawn_centre := VolumeRow.handle_left_for(0.5) + VolumeRow.HANDLE_INSET + VolumeRow.HANDLE_DRAWN_WIDTH * 0.5
	Assert.is_true(absf(drawn_centre - expected) < EPS,
		"0.5: handle centre %.3f sits at the groove centre %.3f" % [drawn_centre, expected])

func test_clicks_round_trip_and_outside_presses_clamp() -> void:
	for value in [0.0, 0.5, 1.0]:
		var x := VolumeRow.handle_left_for(value) + VolumeRow.HANDLE_BOX_PX * 0.5
		Assert.is_true(absf(VolumeRow.value_for_x(x) - value) < EPS,
			"a click on the handle centre at %.1f maps back to %.1f" % [value, VolumeRow.value_for_x(x)])
	Assert.equals(VolumeRow.value_for_x(0.0), 0.0, "a press on the painted '-' area snaps to 0")
	Assert.equals(VolumeRow.value_for_x(VolumeRow.SLIDER_TRACK_WIDTH), 1.0, "a press on the painted '+' area snaps to 1")

# Vector2 stores float32: a click exactly on the mute boundary can arrive a hair above zero.
# The END_SNAP absorbs that rounding (and a ±1 px wobble) so the left edge really mutes.
func test_left_edge_click_still_mutes_with_float32_rounding() -> void:
	var centre := VolumeRow.handle_left_for(0.0) + VolumeRow.HANDLE_BOX_PX * 0.5
	for offset in [-1.0, -0.01, 0.0, 0.01, 1.0]:
		Assert.equals(VolumeRow.value_for_x(centre + offset), 0.0,
			"a left-edge click %+0.2f px from the boundary still mutes" % offset)
