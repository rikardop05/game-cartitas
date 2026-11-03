extends RefCounted
const GameScript := preload("res://scripts/game.gd")

const CLIENT_AREAS := [
	Vector2i(1904, 993), # 1920x1080 work area minus Windows decorations.
	Vector2i(2544, 1353), # 2560x1440 work area minus Windows decorations.
	Vector2i(540, 960),
	Vector2i(600, 1080),
	Vector2i(720, 1280),
	Vector2i(320, 180),
]

func test_fit_window_keeps_orientation_ratio_and_stays_inside_work_area() -> void:
	for landscape in [false, true]:
		var aspect := 16.0 / 9.0 if landscape else 9.0 / 16.0
		for usable in CLIENT_AREAS:
			var fitted: Vector2i = GameScript.fit_window(usable, landscape)
			Assert.is_true(fitted.x > 0 and fitted.y > 0,
				"%s %s: fitted window has positive dimensions (%s)" % [str(usable), str(landscape), str(fitted)])
			Assert.is_true(fitted.x <= usable.x and fitted.y <= usable.y,
				"%s %s: fitted window %s stays inside client area" % [str(usable), str(landscape), str(fitted)])
			Assert.is_true(absf(float(fitted.x) / float(fitted.y) - aspect) < 0.01,
				"%s %s: fitted window keeps %s aspect (%s)" % [str(usable), str(landscape), str(aspect), str(fitted)])
			Assert.is_true(fitted.x == usable.x or fitted.y == usable.y,
				"%s %s: fitted window uses the limiting work-area edge" % [str(usable), str(landscape)])

func test_portrait_window_fit_on_a_1080p_work_area() -> void:
	var usable := Vector2i(1904, 993)
	var fitted: Vector2i = GameScript.fit_window(usable, false)
	Assert.equals(fitted, Vector2i(558, 993), "portrait maximizes inside a 1920x1080 screen work area")

func test_landscape_window_fit_on_a_1080p_work_area() -> void:
	var usable := Vector2i(1904, 993)
	var fitted: Vector2i = GameScript.fit_window(usable, true)
	Assert.equals(fitted, Vector2i(1765, 993), "landscape maximizes inside a 1920x1080 screen work area")
