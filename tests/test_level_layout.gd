extends RefCounted

const SIZES := [
	Vector2(360, 640),
	Vector2(360, 780),
	Vector2(360, 800),
	Vector2(480, 640),
	Vector2(640, 360),
	Vector2(780, 360),
	Vector2(640, 480),
]

func test_responsive_rects_fit_and_controls_do_not_overlap() -> void:
	for size in SIZES:
		var layout := LevelLayout.compute(size)
		var bounds := Rect2(Vector2.ZERO, size)
		var rects: Dictionary = layout["rects"]
		for key in rects:
			var rect: Rect2 = rects[key]
			var allowed := bounds
			if key == "clock_pill":
				# Hand-tuned landscape plank: drawn at clock_scale from its top-left corner, and the
				# transparent box may rise up to 16 px above the screen (the painted plank stays inside).
				var clock_scale := float(layout.get("clock_scale", 1.0))
				rect = Rect2(rect.position, rect.size * clock_scale)
				allowed = bounds.grow_individual(0.0, 16.0, 0.0, 0.0)
			elif key == "stopwatch_in_pill" and size.x >= size.y:
				# The hand-tuned icon rect is local to the plank and is scaled with it.
				var clock: Rect2 = rects["clock_pill"]
				var clock_scale := float(layout.get("clock_scale", 1.0))
				rect = Rect2(clock.position + rect.position * clock_scale, rect.size * clock_scale)
				allowed = bounds.grow_individual(0.0, 16.0, 0.0, 0.0)
			Assert.is_true(allowed.encloses(rect), "%s: %s (%s) is inside %s" % [str(size), str(key), str(rect), str(allowed)])
		var board: Rect2 = rects["board_frame"]
		var largest_area := 0.0
		for value in rects.values():
			var rect: Rect2 = value
			largest_area = maxf(largest_area, rect.get_area())
		Assert.equals(board.get_area(), largest_area, "%s: board frame is the largest layout rect" % str(size))
		var interactive: Array = layout["interactive"]
		for i in interactive.size():
			var a: Rect2 = interactive[i]
			Assert.is_true(a.size.x >= 32.0 and a.size.y >= 32.0,
				"%s: touch target %d is at least 32 design px (%s)" % [str(size), i, str(a.size)])
			for j in range(i + 1, interactive.size()):
				var b: Rect2 = interactive[j]
				Assert.is_false(a.intersects(b),
					"%s: interactive rects %d and %d overlap (%s / %s)" % [str(size), i, j, str(a), str(b)])
		var zone_cards: Rect2 = rects["zone_cards"]
		var zone: Rect2 = rects["zone"]
		Assert.is_true(zone.encloses(zone_cards), "%s: all zone slots fit inside the wood bar" % str(size))
		Assert.equals(int(layout["zone_columns"]), 7 if size.x >= size.y else 4,
			"%s: zone uses the orientation's intended number of columns" % str(size))

func test_expanded_height_grows_the_board_window() -> void:
	var landscape_16_9 := LevelLayout.compute(Vector2(640, 360))
	var landscape_4_3 := LevelLayout.compute(Vector2(640, 480))
	var portrait_base := LevelLayout.compute(Vector2(360, 640))
	var portrait_tall := LevelLayout.compute(Vector2(360, 800))
	Assert.is_true(landscape_4_3["rects"]["board_frame"].size.y > landscape_16_9["rects"]["board_frame"].size.y + 40.0,
		"640x480 grows the board into the extra vertical viewport")
	Assert.is_true(portrait_tall["rects"]["board_frame"].size.y > portrait_base["rects"]["board_frame"].size.y + 100.0,
		"360x800 grows the board into the extra vertical viewport")

func test_landscape_hand_tuned_hud_and_deck_tables() -> void:
	for size in [Vector2(640, 360), Vector2(780, 360), Vector2(640, 480)]:
		var layout := LevelLayout.compute(size)
		var rects: Dictionary = layout["rects"]
		var stopwatch: Rect2 = rects["stopwatch_in_pill"]
		Assert.is_true(stopwatch.is_equal_approx(LevelLayout.LANDSCAPE_STOPWATCH_RECT),
			"%s keeps the editor-tuned stopwatch rect" % str(size))
		var shade: Rect2 = layout["board_shade_target"]
		Assert.is_true(shade.position.is_equal_approx(Vector2(7.0, 7.0)) and
			shade.size.is_equal_approx(Vector2(444.055, 220.68)),
			"%s carries the editor-tuned BoardShade target" % str(size))
		var board: Rect2 = rects["board_frame"]
		var expected_y := minf(
			board.end.y - 58.0,
			size.y - 69.0 - 71.0 - LevelLayout.LANDSCAPE_DECK_A_TABLE_OFFSET.y)
		var deck_a: Rect2 = rects["deck_a"]
		var deck_b: Rect2 = rects["deck_b"]
		Assert.is_true(deck_a.size.is_equal_approx(Vector2(71.0, 71.0)) and
			deck_a.position.is_equal_approx(Vector2(8.0, expected_y) + Vector2(14.68, -2.15)),
			"%s positions the left 71x71 table at its tuned offsets" % str(size))
		Assert.is_true(deck_b.size.is_equal_approx(Vector2(71.0, 71.0)) and
			deck_b.position.is_equal_approx(Vector2(size.x - 66.0, expected_y) + Vector2(-12.14, -7.22)),
			"%s positions the right 71x71 table at its tuned offsets" % str(size))
	Assert.is_false(LevelLayout.compute(Vector2(360, 640)).has("board_shade_target"),
		"portrait keeps its previous shade layout")

func test_portrait_hero_rect_and_layer_order() -> void:
	for size in [Vector2(360, 640), Vector2(360, 780), Vector2(480, 640), Vector2(360, 800)]:
		var layout := LevelLayout.compute(size)
		var hero: Rect2 = layout["hero_rect"]
		var rects: Dictionary = layout["rects"]
		var deck: Rect2 = rects["deck_a"]
		var board: Rect2 = rects["board_frame"]
		Assert.is_true(hero.position.x < 0.0, "%s: the hero bleeds off the left edge (%s)" % [str(size), str(hero)])
		Assert.is_true(hero.end.x <= size.x * 0.34, "%s: the hero stays in the left third (%s)" % [str(size), str(hero)])
		Assert.is_true(hero.position.y > board.position.y and hero.position.y < board.end.y,
			"%s: the hero starts inside the board frame" % str(size))
		Assert.is_true(hero.end.y > deck.position.y and hero.end.y <= deck.end.y + 6.0,
			"%s: her legs end behind the left deck slot (hero %s, deck %s)" % [str(size), str(hero), str(deck)])
		Assert.is_true(LevelLayout.HERO_Z > 0 and LevelLayout.HERO_Z < LevelLayout.FOREGROUND_Z,
			"the hero layer sits between the frame (0) and the deck/powers/zone panels")
	Assert.is_false(LevelLayout.compute(Vector2(640, 360)).has("hero_rect"), "landscape has no portrait hero rect")
