extends RefCounted

const CARD_SIZE := 48.0
const BOARD_WIDTH := 360.0
const BOARD_HEIGHT := 280.0
const CARD_COUNT := 24
const SEED := 1001

func _spec() -> BoardSpec:
	return BoardSpec.create({
		"card_count": CARD_COUNT,
		"card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH,
		"board_height": BOARD_HEIGHT,
		"layers": 1,
		"seed": SEED,
	})

func test_generates_ok() -> void:
	var result := BoardPipeline.generate(_spec())
	Assert.is_true(result.ok, "generation ok")

func test_twenty_four_unique_slots() -> void:
	var result := BoardPipeline.generate(_spec())
	Assert.is_true(result.ok, "generation ok")
	Assert.equals(result.cards.size(), CARD_COUNT, "24 cards")
	var seen := {}
	for c in result.cards:
		var key := "%d,%d" % [int(c["grid_x"]), int(c["grid_y"])]
		Assert.is_false(seen.has(key), "unique slot %s" % key)
		seen[key] = true

func test_layer0_grid_and_pixels_from_step() -> void:
	var result := BoardPipeline.generate(_spec())
	Assert.is_true(result.ok, "generation ok")
	for c in result.cards:
		Assert.equals(int(c["layer"]), 0, "all layer 0")
		Assert.is_true(c.has("grid_x") and c.has("grid_y"), "grid coords present")
		Assert.equals(c["x"], int(c["grid_x"]) * 24, "x derived from step_x 24")
		Assert.equals(c["y"], int(c["grid_y"]) * 24, "y derived from step_y 24")

func test_all_cards_within_bounds() -> void:
	var result := BoardPipeline.generate(_spec())
	Assert.is_true(result.ok, "generation ok")
	for c in result.cards:
		Assert.is_true(float(c["x"]) >= 0.0, "x >= 0")
		Assert.is_true(float(c["y"]) >= 0.0, "y >= 0")
		Assert.is_true(float(c["x"]) + CARD_SIZE <= BOARD_WIDTH, "x within board width")
		Assert.is_true(float(c["y"]) + CARD_SIZE <= BOARD_HEIGHT, "y within board height")

func test_connected_single_component() -> void:
	var result := BoardPipeline.generate(_spec())
	Assert.is_true(result.ok, "generation ok")
	Assert.equals(_component_count(result.cards), 1, "exactly one component")

func test_occupied_wider_than_tall() -> void:
	var result := BoardPipeline.generate(_spec())
	Assert.is_true(result.ok, "generation ok")
	var m: Dictionary = result.metrics
	var w := float(m.get("occupied_width", 0.0))
	var h := float(m.get("occupied_height", 0.0))
	Assert.is_true(w > h, "occupied_width %.1f > occupied_height %.1f" % [w, h])

func test_same_seed_identical_signature() -> void:
	var a := BoardPipeline.generate(_spec())
	var b := BoardPipeline.generate(_spec())
	Assert.is_true(a.ok, "first generation ok")
	Assert.is_true(b.ok, "second generation ok")
	Assert.equals(_signature(a.cards), _signature(b.cards), "same seed -> identical signature")

func test_100_seeds_all_pass_compactness_gates() -> void:
	for s in range(1, 101):
		var spec := BoardSpec.create({
			"card_count": CARD_COUNT,
			"card_size": CARD_SIZE,
			"board_width": BOARD_WIDTH,
			"board_height": BOARD_HEIGHT,
			"layers": 1,
			"seed": s,
		})
		var result := BoardPipeline.generate(spec)
		Assert.is_true(result.ok, "seed %d generation ok" % s)
		if not result.ok:
			continue
		var m: Dictionary = result.metrics
		Assert.is_true(bool(m.get("connected_layout", false)), "seed %d connected" % s)
		Assert.is_true(bool(m.get("no_large_holes", false)), "seed %d no large holes" % s)
		Assert.is_true(float(m.get("largest_hole_half_cells", 999.0)) <= 4.0, "seed %d largest hole <= 4 half-cells" % s)
		Assert.is_true(bool(m.get("no_narrow_bridges", false)), "seed %d no narrow bridges" % s)
		Assert.equals(int(m.get("narrow_bridge_count", -1)), 0, "seed %d narrow bridge count 0" % s)
		Assert.is_true(float(m.get("compact_density", 0.0)) >= 0.55, "seed %d compact density >= 0.55" % s)
		var aspect := float(m.get("occupied_aspect", 0.0))
		Assert.is_true(aspect >= 1.15 and aspect <= 2.25, "seed %d occupied_aspect %.2f in [1.15, 2.25]" % [s, aspect])

func test_narrow_vertical_spec_rejected_structured() -> void:
	var spec := BoardSpec.create({
		# 120 px = two card columns: the 18 cards fit the lattice but only as a tall
		# strip, so the aspect gate (not the spec) rejects it.
		"card_count": 18,
		"card_size": CARD_SIZE,
		"board_width": 120.0,
		"board_height": 480.0,
		"layers": 1,
		"seed": 7,
	})
	var result := BoardPipeline.generate(spec)
	Assert.is_false(result.ok, "narrow vertical board must not be returned as success")
	Assert.equals(result.error_code, BoardBuildResult.ErrorCode.COMPACTNESS_REJECTED, "structured COMPACTNESS_REJECTED")
	Assert.is_true(result.metrics.has("attempts"), "attempts metric present")
	Assert.is_true(result.metrics.has("rejection_counts"), "rejection_counts metric present")

func _multi_spec(seed: int) -> BoardSpec:
	return BoardSpec.create({
		"card_count": 36,
		"card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH,
		"board_height": BOARD_HEIGHT,
		"layers": 4,
		"seed": seed,
	})

func test_layered_pyramid_50_seeds() -> void:
	for s in range(1, 51):
		var result := BoardPipeline.generate(_multi_spec(s))
		Assert.is_true(result.ok, "seed %d generation ok" % s)
		if not result.ok:
			continue
		Assert.equals(result.cards.size(), 36, "seed %d exactly 36 cards" % s)
		var m: Dictionary = result.metrics
		Assert.is_true(bool(m.get("valid_layers", false)), "seed %d valid layers" % s)
		var layer_count := int(m.get("layer_count", 0))
		Assert.equals(layer_count, 4, "seed %d layer_count exactly 4 (got %d)" % [s, layer_count])
		var per_layer: Array = m.get("cards_per_layer", [])
		for i in range(1, per_layer.size()):
			Assert.is_true(int(per_layer[i]) < int(per_layer[i - 1]), "seed %d cards_per_layer strictly decreasing" % s)

		var by_id := {}
		for c in result.cards:
			by_id[str(c["id"])] = c
		var upper := 0
		for c in result.cards:
			var layer := int(c["layer"])
			if layer == 0:
				continue
			upper += 1
			var support_ids: Array = c.get("support_ids", [])
			Assert.equals(support_ids.size(), 2, "seed %d card %s has exactly 2 supports" % [s, str(c["id"])])
			for sid in support_ids:
				var support = by_id.get(str(sid), null)
				Assert.is_true(support != null, "seed %d support %s exists" % [s, str(sid)])
				if support != null:
					Assert.equals(int(support["layer"]), layer - 1, "seed %d support %s is layer-1" % [s, str(sid)])
			if support_ids.size() == 2 and by_id.has(str(support_ids[0])) and by_id.has(str(support_ids[1])):
				var s0 = by_id[str(support_ids[0])]
				var s1 = by_id[str(support_ids[1])]
				var mid_grid_x := (float(s0["grid_x"]) + float(s1["grid_x"])) / 2.0
				var mid_grid_y := (float(s0["grid_y"]) + float(s1["grid_y"])) / 2.0
				Assert.is_true(absf(float(c["grid_x"]) - mid_grid_x) <= 1.5 and absf(float(c["grid_y"]) - mid_grid_y) <= 1.5,
					"seed %d upper uses an integer slot near the supports midpoint" % s)
				var cr := Rect2(Vector2(float(c["x"]), float(c["y"])), Vector2(CARD_SIZE, CARD_SIZE))
				for sid in support_ids:
					var sp = by_id[str(sid)]
					var sr := Rect2(Vector2(float(sp["x"]), float(sp["y"])), Vector2(CARD_SIZE, CARD_SIZE))
					var cov := BoardSpatialRules.coverage(cr, sr)
					Assert.is_true(cov >= 0.10, "seed %d support coverage >= 0.10 (got %.3f)" % [s, cov])
		Assert.is_true(upper > 0, "seed %d has upper cards" % s)
		Assert.equals(int(m.get("unsupported_cards", -1)), 0, "seed %d unsupported_cards 0" % s)
		Assert.is_true(int(m.get("support_edge_count", -1)) >= 2 * upper, "seed %d support_edge_count >= 2*upper" % s)
		Assert.is_true(int(m.get("blocking_edge_count", 0)) > 0, "seed %d blocking_edge_count > 0" % s)
		Assert.is_true(int(m.get("free_cards", 0)) > 0, "seed %d free_cards > 0" % s)
		Assert.is_true(int(m.get("blocked_cards", 0)) > 0, "seed %d blocked_cards > 0" % s)

		var base := _layer_cards(result.cards, 0)
		Assert.is_true(_real_component_count(base) == 1, "seed %d base connected" % s)
		Assert.is_true(_base_no_large_holes(base) <= 4, "seed %d base no large holes" % s)
		Assert.equals(_base_narrow_bridges(base), 0, "seed %d base no narrow bridges" % s)
		Assert.is_true(_base_density(base) >= 0.55, "seed %d base density >= 0.55 (got %.3f)" % [s, _base_density(base)])
		var base_aspect := _base_aspect(base)
		Assert.is_true(base_aspect >= 1.15 and base_aspect <= 2.25, "seed %d base aspect %.2f in [1.15, 2.25]" % [s, base_aspect])

func test_runtime_blocking_agreement() -> void:
	var result := BoardPipeline.generate(_multi_spec(SEED))
	Assert.is_true(result.ok, "generation ok")
	var cards: Array[Card] = []
	for cdata in result.cards:
		var c := Card.new(str(cdata["id"]), "cat", Vector2(float(cdata["x"]), float(cdata["y"])), int(cdata["layer"]))
		c.location = Card.Location.BOARD
		cards.append(c)
	var bm := BoardManager.new(cards)
	bm.recalculate_availability()
	for cdata in result.cards:
		var card: Card = bm.get_card(str(cdata["id"]))
		var expected := bool(cdata.get("blocked", false))
		Assert.equals(bm.is_blocked(card), expected, "blocking agreement for %s" % str(cdata["id"]))

func test_removing_single_upper_blocker_unblocks() -> void:
	var result := BoardPipeline.generate(_multi_spec(SEED))
	Assert.is_true(result.ok, "generation ok")
	var cards: Array[Card] = []
	for cdata in result.cards:
		var c := Card.new(str(cdata["id"]), "cat", Vector2(float(cdata["x"]), float(cdata["y"])), int(cdata["layer"]))
		c.location = Card.Location.BOARD
		cards.append(c)
	var bm := BoardManager.new(cards)
	bm.recalculate_availability()
	var found := false
	for c in cards:
		if not bm.is_blocked(c):
			continue
		var blockers: Array[Card] = []
		for o in cards:
			if o == c:
				continue
			if o.layer <= c.layer:
				continue
			if BoardSpatialRules.blocks(c.get_display_rect(), o.get_display_rect()):
				blockers.append(o)
		if blockers.size() == 1:
			var blocker := blockers[0]
			blocker.state = Card.State.REMOVED
			blocker.location = Card.Location.CLEARING_ZONE
			bm.recalculate_availability()
			Assert.equals(c.state, Card.State.AVAILABLE, "%s unblocked after only blocker %s removed" % [c.id, blocker.id])
			found = true
			break
	Assert.is_true(found, "found a card with exactly one blocker to remove")

func test_metrics_bbox_computed_from_first_card() -> void:
	var spec := BoardSpec.create({
		"card_count": 24, "card_size": CARD_SIZE,
		"board_width": 480.0, "board_height": 400.0,
		"layers": 1, "seed": SEED,
	})
	var result := BoardPipeline.generate(spec)
	Assert.is_true(result.ok, "generation ok")
	var min_gx := int(result.cards[0]["grid_x"])
	var max_gx := min_gx
	var min_gy := int(result.cards[0]["grid_y"])
	var max_gy := min_gy
	for c in result.cards:
		var gx := int(c["grid_x"])
		var gy := int(c["grid_y"])
		min_gx = mini(min_gx, gx)
		max_gx = maxi(max_gx, gx)
		min_gy = mini(min_gy, gy)
		max_gy = maxi(max_gy, gy)
	Assert.is_true(min_gx > 0 and min_gy > 0, "fixture min (%d,%d) > 0 catches the min=0 init bug" % [min_gx, min_gy])
	var exp_w := float(max_gx - min_gx) * 24.0 + CARD_SIZE
	var exp_h := float(max_gy - min_gy) * 24.0 + CARD_SIZE
	var m: Dictionary = result.metrics
	var got_w := float(m.get("occupied_width", 0.0))
	var got_h := float(m.get("occupied_height", 0.0))
	Assert.is_true(absf(got_w - exp_w) < 0.01, "occupied_width %.1f == first-card bbox %.1f" % [got_w, exp_w])
	Assert.is_true(absf(got_h - exp_h) < 0.01, "occupied_height %.1f == first-card bbox %.1f" % [got_h, exp_h])
	Assert.is_true(absf(float(m.get("occupied_aspect", 0.0)) - exp_w / exp_h) < 0.01, "occupied_aspect from first-card bbox")

func test_compactness_metrics_reflect_base_layer() -> void:
	var result := BoardPipeline.generate(_multi_spec(SEED))
	Assert.is_true(result.ok, "generation ok")
	var base := _layer_cards(result.cards, 0)
	var m: Dictionary = result.metrics
	Assert.is_true(absf(float(m.get("compact_density", 0.0)) - _base_density(base)) < 0.001,
		"compact_density reflects base layer only")
	Assert.equals(int(m.get("largest_hole_half_cells", -1)), _base_no_large_holes(base),
		"largest_hole_half_cells reflects base layer only")
	Assert.equals(int(m.get("hole_count", -1)), _base_hole_count(base), "hole_count reflects base layer only")

func test_spec_rejects_impossible_layers() -> void:
	var too_few := BoardSpec.create({
		"card_count": 8, "card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH, "board_height": BOARD_HEIGHT,
		"layers": 4, "seed": 1,
	})
	var v1 := too_few.validate()
	Assert.is_false(v1["valid"], "card_count too small for 4 strictly-decreasing layers is rejected")
	var too_many := BoardSpec.create({
		"card_count": 3, "card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH, "board_height": BOARD_HEIGHT,
		"layers": 4, "seed": 1,
	})
	var v2 := too_many.validate()
	Assert.is_false(v2["valid"], "layers greater than card_count is rejected")

func test_geometric_support_builds_compact_three_two_layers() -> void:
	var spec := BoardSpec.create({
		"card_count": 5, "card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH, "board_height": BOARD_HEIGHT,
		"layers": 2, "seed": 7,
	})
	var result := BoardPipeline.generate(spec)
	Assert.is_true(result.ok, "geometric search builds the compact 3/2 pyramid")
	if result.ok:
		Assert.equals(result.cards.size(), 5, "all five cards are generated")
		Assert.equals(result.metrics.get("cards_per_layer", []), [3, 2], "legacy 3/2 targets are preserved")
		Assert.is_true(bool(result.metrics.get("valid_layers", false)), "geometric supports pass the layer gate")

func test_real_connectivity_full_graph_single_component() -> void:
	for s in range(1, 11):
		var result := BoardPipeline.generate(_multi_spec(s))
		Assert.is_true(result.ok, "seed %d generation ok" % s)
		if not result.ok:
			continue
		var comps := _real_component_count(result.cards)
		Assert.equals(comps, 1, "seed %d full graph (same-layer + support edges) is one component" % s)
		var m: Dictionary = result.metrics
		Assert.equals(int(m.get("component_count", -1)), 1, "seed %d metrics component_count == 1" % s)
		Assert.is_true(bool(m.get("connected_layout", false)), "seed %d connected_layout true" % s)

func test_stack_identity_and_support_preserved() -> void:
	var result := BoardPipeline.generate(_multi_spec(SEED))
	Assert.is_true(result.ok, "generation ok")
	var by_id := {}
	for c in result.cards:
		by_id[str(c["id"])] = c
	var found_stack := false
	for i in result.cards.size():
		for j in range(i + 1, result.cards.size()):
			var a: Dictionary = result.cards[i]
			var b: Dictionary = result.cards[j]
			if int(a["layer"]) == int(b["layer"]):
				continue
			if int(a["grid_x"]) == int(b["grid_x"]) and int(a["grid_y"]) == int(b["grid_y"]):
				found_stack = true
				Assert.not_equals(str(a["id"]), str(b["id"]), "stacked cards keep distinct ids")
				var upper: Dictionary
				if int(a["layer"]) > int(b["layer"]):
					upper = a
				else:
					upper = b
				for sid in upper.get("support_ids", []):
					var support = by_id.get(str(sid), null)
					Assert.is_true(support != null, "stacked upper support %s exists" % str(sid))
					if support != null:
						Assert.equals(int(support["layer"]), int(upper["layer"]) - 1,
							"stacked upper support resolves to layer-1 (not the coincident card)")
	Assert.is_true(found_stack, "expected at least one upper/lower x/y coincidence in the fixture")

func test_multilayer_signature_determinism() -> void:
	for s in range(1, 11):
		var a := BoardPipeline.generate(_multi_spec(s))
		var b := BoardPipeline.generate(_multi_spec(s))
		Assert.is_true(a.ok and b.ok, "seed %d generation ok" % s)
		if a.ok and b.ok:
			Assert.equals(_full_signature(a.cards), _full_signature(b.cards),
				"seed %d multilayer signature (layer/support_ids/blocked) identical" % s)

func test_board_spatial_rule_sharp_threshold() -> void:
	Assert.is_true(BoardSpatialRules.at_or_above_threshold(0.1), "coverage 0.10 is at threshold (blocks)")
	Assert.is_false(BoardSpatialRules.at_or_above_threshold(0.09999995), "coverage 0.09999995 does NOT block")
	var covered := Rect2(Vector2(0, 0), Vector2(CARD_SIZE, CARD_SIZE))
	var above := Rect2(Vector2(40, 0), Vector2(CARD_SIZE, CARD_SIZE))
	Assert.is_true(BoardSpatialRules.blocks(covered, above), "coverage 0.167 above threshold blocks")
	var just_below := Rect2(Vector2(43.20001, 0), Vector2(CARD_SIZE, CARD_SIZE))
	var cov_below := BoardSpatialRules.coverage(covered, just_below)
	Assert.is_true(cov_below < 0.1, "coverage %.8f below threshold" % cov_below)
	Assert.is_false(BoardSpatialRules.blocks(covered, just_below), "coverage just below 0.10 does NOT block")

func test_strict_threshold_48x64_next_representable_not_block() -> void:
	# This is the next float32 offset above the value stored for literal 43.2.
	# Its geometric overlap is representably below 10% and must not block.
	var covered := Rect2(0, 0, 48, 64)
	var next_offset := 43.200004577636719
	var covering := Rect2(next_offset, 0, 48, 64)
	var cov := BoardSpatialRules.coverage(covered, covering)
	Assert.is_true(cov < 0.1, "48x64 next-offset coverage %.10f < 0.10" % cov)
	Assert.is_false(BoardSpatialRules.blocks(covered, covering), "next representable below-threshold geometry must not block")
	Assert.is_false(BoardSpatialRules.at_or_above_threshold(0.09999995), "pure threshold 0.09999995 not blocking")
	Assert.is_true(BoardSpatialRules.at_or_above_threshold(0.1), "pure threshold exactly 0.10 blocks")
	var exact := Rect2(0, 0, 100, 100)
	var covering_exact := Rect2(90, 0, 100, 100)
	Assert.is_true(BoardSpatialRules.blocks(exact, covering_exact), "exactly 0.10 coverage blocks")

func test_threshold_no_round_promotes_below_limit() -> void:
	# The threshold decision must be a direct comparison: coverage rounding at a
	# ~1e-12 quantum would promote a coverage value just below the boundary.
	Assert.is_false(BoardSpatialRules.at_or_above_threshold(0.0999999999997),
		"coverage just below 0.10 (0.1 - 3e-13) is not promoted by rounding")
	Assert.is_true(BoardSpatialRules.at_or_above_threshold(0.1), "exactly 0.10 blocks")
	Assert.is_false(BoardSpatialRules.at_or_above_threshold(0.09999995), "0.09999995 does not block")

func test_threshold_geometric_at_real_size() -> void:
	var covered := Rect2(0, 0, 48, 48)
	var boundary_offset := Vector2(43.2, 0).x
	var next_offset := Vector2(43.200004577636719, 0).x
	Assert.is_true(next_offset > boundary_offset, "A and the next representable offset B remain distinct")
	Assert.is_true(BoardSpatialRules.blocks(covered, Rect2(boundary_offset, 0, 48, 48)),
		"A: mathematical 10% boundary blocks after float32 storage")
	Assert.is_false(BoardSpatialRules.blocks(covered, Rect2(next_offset, 0, 48, 48)),
		"B: next representable offset with overlap below 10% does not block")

func test_threshold_next_offset_remains_below_after_translation() -> void:
	var covered := Rect2(0.00001, 0, 48, 48)
	var covering := Rect2(43.20001220703125, 0, 48, 48)
	var cov := BoardSpatialRules.coverage(covered, covering)
	Assert.is_true(cov < 0.1, "translated next-offset coverage %.10f remains below 0.10" % cov)
	Assert.is_false(BoardSpatialRules.blocks(covered, covering),
		"translated next representable offset below threshold is not promoted")

func test_layers_strict_feasible_10_4() -> void:
	var spec := BoardSpec.create({
		"card_count": 10, "card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH, "board_height": BOARD_HEIGHT,
		"layers": 4, "seed": 5,
	})
	var v := spec.validate()
	Assert.is_true(v["valid"], "10 cards / 4 layers is feasible")
	var result := BoardPipeline.generate(spec)
	Assert.is_true(result.ok, "10 cards / 4 layers generates")
	if result.ok:
		var m: Dictionary = result.metrics
		Assert.equals(int(m.get("layer_count", 0)), 4, "exactly 4 layers")
		var per_layer: Array = m.get("cards_per_layer", [])
		Assert.equals(per_layer.size(), 4, "four layers reported")
		for i in range(1, per_layer.size()):
			Assert.is_true(int(per_layer[i]) < int(per_layer[i - 1]), "strictly decreasing pyramid")
		var total := 0
		for c in result.cards:
			total += 1
		Assert.equals(total, 10, "sum is 10")
		Assert.is_true(int(per_layer[0]) == 4 and int(per_layer[1]) == 3 and int(per_layer[2]) == 2 and int(per_layer[3]) == 1,
			"10/4 uses the exact triangular targets [4,3,2,1] (got %s)" % str(per_layer))

func test_layers_minimum_pyramid_has_compact_geometric_supports() -> void:
	var spec := BoardSpec.create({
		"card_count": 10, "card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH, "board_height": BOARD_HEIGHT,
		"layers": 4, "seed": 5,
	})
	var result := BoardPipeline.generate(spec)
	Assert.is_true(result.ok, "minimum 4-layer pyramid generates")
	var m: Dictionary = result.metrics
	Assert.is_true(float(m.get("compact_density", 0.0)) >= 0.55,
		"minimum pyramid base passes the normal density gate")
	# The single full-card row is the only base without same-layer overlap that can
	# carry the whole staircase, so the aspect gate is waived for this case only.
	Assert.is_true(float(m.get("occupied_aspect", 0.0)) >= 1.0, "minimum pyramid base is a wide row")
	Assert.is_true(bool(m.get("no_large_holes", false)), "minimum pyramid base passes the normal holes gate")
	Assert.is_true(bool(m.get("no_narrow_bridges", false)), "minimum pyramid base passes the normal bridges gate")
	var base := _layer_cards(result.cards, 0)
	Assert.equals(_real_component_count(base), 1, "minimum pyramid base is connected")
	var by_id := {}
	for c in result.cards:
		by_id[str(c["id"])] = c
	var upper_count := 0
	for c in result.cards:
		var layer := int(c["layer"])
		if layer == 0:
			continue
		upper_count += 1
		var support_ids: Array = c.get("support_ids", [])
		Assert.equals(support_ids.size(), 2, "upper card %s has exactly two supports" % str(c["id"]))
		var upper_rect := Rect2(Vector2(float(c["x"]), float(c["y"])), Vector2(CARD_SIZE, CARD_SIZE))
		for support_id in support_ids:
			var support = by_id.get(str(support_id), null)
			Assert.is_true(support != null, "support %s exists" % str(support_id))
			if support == null:
				continue
			Assert.equals(int(support["layer"]), layer - 1, "support belongs to immediately lower layer")
			var support_rect := Rect2(Vector2(float(support["x"]), float(support["y"])), Vector2(CARD_SIZE, CARD_SIZE))
			var coverage := BoardSpatialRules.coverage(upper_rect, support_rect)
			Assert.is_true(BoardSpatialRules.at_or_above_threshold(coverage),
				"upper card %s overlaps support %s at the shared threshold" % [str(c["id"]), str(support_id)])
	Assert.equals(upper_count, 6, "triangular minimum has all six upper cards")

func test_layers_impossible_9_4_invalid() -> void:
	var spec := BoardSpec.create({
		"card_count": 9, "card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH, "board_height": BOARD_HEIGHT,
		"layers": 4, "seed": 5,
	})
	var v := spec.validate()
	Assert.is_false(v["valid"], "9 cards cannot form a strictly-decreasing 4-layer pyramid")
	var result := BoardPipeline.generate(spec)
	Assert.is_false(result.ok, "impossible layers not returned as success")
	Assert.equals(result.error_code, BoardBuildResult.ErrorCode.SPEC_INVALID,
		"9/4 uses SPEC_INVALID (got %d)" % result.error_code)

func test_layers_strict_feasible_6_2() -> void:
	var spec := BoardSpec.create({
		"card_count": 6, "card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH, "board_height": BOARD_HEIGHT,
		"layers": 2, "seed": 3,
	})
	var result := BoardPipeline.generate(spec)
	Assert.is_true(result.ok, "6 cards / 2 layers generates")
	if result.ok:
		Assert.equals(result.cards.size(), 6, "sum is 6")
		var m: Dictionary = result.metrics
		Assert.equals(int(m.get("layer_count", 0)), 2, "exactly 2 layers")
		var per_layer: Array = m.get("cards_per_layer", [])
		Assert.equals(per_layer.size(), 2, "two layers reported")
		Assert.is_true(int(per_layer[0]) > int(per_layer[1]), "strict pyramid (base > upper)")
		var total := 0
		for c in result.cards:
			total += 1
			Assert.is_true(int(c["layer"]) < 2, "no extra layers")
		Assert.equals(total, 6, "no silently dropped cards")

func test_layers_impossible_returns_invalid_spec() -> void:
	var spec := BoardSpec.create({
		"card_count": 2, "card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH, "board_height": BOARD_HEIGHT,
		"layers": 2, "seed": 1,
	})
	var v := spec.validate()
	Assert.is_false(v["valid"], "2 cards cannot form a strictly-decreasing 2-layer pyramid")
	var result := BoardPipeline.generate(spec)
	Assert.is_false(result.ok, "impossible layers not returned as success")
	Assert.equals(result.error_code, BoardBuildResult.ErrorCode.SPEC_INVALID,
		"impossible layers uses SPEC_INVALID (got %d)" % result.error_code)

func test_upper_failure_code_reflects_real_gate_not_stale() -> void:
	# The layer build can complete (base 4 + L1 2) in this narrow board, but the
	# base compactness gate (aspect) always fails. Even if an early attempt fails
	# the build, the final failure code must reflect the real gate that the best
	# complete candidate hit — never a stale UPPER_LAYER_REJECTED.
	var spec := BoardSpec.create({
		"card_count": 6, "card_size": CARD_SIZE,
		"board_width": 96.0, "board_height": 480.0,
		"layers": 2, "seed": 11,
	})
	var result := BoardPipeline.generate(spec)
	Assert.is_false(result.ok, "narrow board does not generate a valid pyramid")
	Assert.equals(result.error_code, BoardBuildResult.ErrorCode.COMPACTNESS_REJECTED,
		"final code reflects the real compactness gate (got %d)" % result.error_code)
	Assert.is_true(int(result.metrics.get("total_cards", 0)) >= 1, "best candidate reported")

func test_geometric_support_board_component_count_real() -> void:
	var spec := BoardSpec.create({
		"card_count": 5, "card_size": CARD_SIZE,
		"board_width": BOARD_WIDTH, "board_height": BOARD_HEIGHT,
		"layers": 2, "seed": 9,
	})
	var result := BoardPipeline.generate(spec)
	Assert.is_true(result.ok, "two-support geometric placement completes the 3/2 board")
	var m: Dictionary = result.metrics
	Assert.equals(int(m.get("component_count", 0)), 1, "completed geometric-support board has one real component")
	Assert.equals(int(m.get("total_cards", 0)), 5, "completed board reports all cards")

func test_same_layer_cards_never_overlap_and_sit_on_the_half_card_grid() -> void:
	for s in range(1, 41):
		var result := BoardPipeline.generate(_multi_spec(s))
		Assert.is_true(result.ok, "seed %d generation ok" % s)
		if not result.ok:
			continue
		Assert.equals(int(result.metrics.get("same_layer_overlaps", -1)), 0, "seed %d metrics report no same-layer overlap" % s)
		for i in result.cards.size():
			var a: Dictionary = result.cards[i]
			Assert.equals(fposmod(float(a["x"]), 24.0), 0.0, "seed %d card %s x on the half-card grid" % [s, str(a["id"])])
			Assert.equals(fposmod(float(a["y"]), 24.0), 0.0, "seed %d card %s y on the half-card grid" % [s, str(a["id"])])
			if int(a["layer"]) == 0:
				Assert.equals(fposmod(float(a["x"]) - float(result.cards[0]["x"]), 48.0), 0.0, "seed %d base card %s on the full-card lattice (x)" % [s, str(a["id"])])
				Assert.equals(fposmod(float(a["y"]) - float(result.cards[0]["y"]), 48.0), 0.0, "seed %d base card %s on the full-card lattice (y)" % [s, str(a["id"])])
			for j in range(i + 1, result.cards.size()):
				var b: Dictionary = result.cards[j]
				if int(a["layer"]) != int(b["layer"]):
					continue
				var overlap := absf(float(a["x"]) - float(b["x"])) < CARD_SIZE and absf(float(a["y"]) - float(b["y"])) < CARD_SIZE
				Assert.is_false(overlap, "seed %d cards %s and %s overlap on layer %d" % [s, str(a["id"]), str(b["id"]), int(a["layer"])])

func test_upper_cards_sit_half_a_card_off_their_two_supports() -> void:
	for s in range(1, 21):
		var result := BoardPipeline.generate(_multi_spec(s))
		Assert.is_true(result.ok, "seed %d generation ok" % s)
		if not result.ok:
			continue
		var by_id := {}
		for c in result.cards:
			by_id[str(c["id"])] = c
		var exact_midpoints := 0
		var upper := 0
		for c in result.cards:
			if int(c["layer"]) == 0:
				continue
			upper += 1
			var supports: Array = c["support_ids"]
			var mid := Vector2.ZERO
			for sid in supports:
				mid += Vector2(float(by_id[str(sid)]["x"]), float(by_id[str(sid)]["y"]))
			mid /= 2.0
			if mid.is_equal_approx(Vector2(float(c["x"]), float(c["y"]))):
				exact_midpoints += 1
		Assert.is_true(upper > 0, "seed %d has upper cards" % s)
		Assert.is_true(float(exact_midpoints) >= float(upper) * 0.6,
			"seed %d: most upper cards sit exactly between their supports (%d of %d)" % [s, exact_midpoints, upper])

func test_layer_targets_shrink_strictly_and_keep_the_total() -> void:
	Assert.equals(BoardPipeline.layer_targets(36, 4), [19, 10, 5, 2], "36 cards / 4 layers")
	Assert.equals(BoardPipeline.layer_targets(9, 2, 0.3), [7, 2], "a smaller ratio keeps more cards on the base")
	Assert.equals(BoardPipeline.layer_targets(10, 4), [4, 3, 2, 1], "the minimum pyramid is the triangular staircase")
	Assert.equals(BoardPipeline.layer_targets(9, 4), [], "9 cards cannot form 4 layers")
	for count in range(6, 40):
		for layers in range(1, 5):
			var targets := BoardPipeline.layer_targets(count, layers)
			if targets.is_empty():
				continue
			var total := 0
			for i in targets.size():
				total += int(targets[i])
				Assert.is_true(int(targets[i]) > 0, "%d/%d layer %d is not empty" % [count, layers, i])
				if i > 0:
					Assert.is_true(int(targets[i]) < int(targets[i - 1]), "%d/%d layers strictly decrease" % [count, layers])
			Assert.equals(total, count, "%d/%d keeps the exact total" % [count, layers])

func _layer_cards(cards: Array, layer: int) -> Array:
	var out := []
	for c in cards:
		if int(c["layer"]) == layer:
			out.append(c)
	return out

func _base_density(cards: Array) -> float:
	var covered := {}
	var min_x := 1000000
	var max_x := -1000000
	var min_y := 1000000
	var max_y := -1000000
	for c in cards:
		var gx := int(c["grid_x"])
		var gy := int(c["grid_y"])
		for dx in 2:
			for dy in 2:
				var x := gx + dx
				var y := gy + dy
				covered["%d,%d" % [x, y]] = true
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	var bbox := float(max_x - min_x + 1) * float(max_y - min_y + 1)
	return float(covered.size()) / bbox if bbox > 0.0 else 0.0

func _base_aspect(cards: Array) -> float:
	var min_gx := 1000000
	var max_gx := -1000000
	var min_gy := 1000000
	var max_gy := -1000000
	for c in cards:
		min_gx = mini(min_gx, int(c["grid_x"]))
		max_gx = maxi(max_gx, int(c["grid_x"]))
		min_gy = mini(min_gy, int(c["grid_y"]))
		max_gy = maxi(max_gy, int(c["grid_y"]))
	var w := float(max_gx - min_gx) * 24.0 + CARD_SIZE
	var h := float(max_gy - min_gy) * 24.0 + CARD_SIZE
	return w / h if h > 0.0 else 0.0

func _base_no_large_holes(cards: Array) -> int:
	return _base_holes(cards)["largest"]

func _base_hole_count(cards: Array) -> int:
	return _base_holes(cards)["count"]

func _base_holes(cards: Array) -> Dictionary:
	var covered := {}
	var raster_w := 0
	var raster_h := 0
	for c in cards:
		var gx := int(c["grid_x"])
		var gy := int(c["grid_y"])
		for dx in 2:
			for dy in 2:
				covered["%d,%d" % [gx + dx, gy + dy]] = true
				raster_w = maxi(raster_w, gx + dx + 1)
				raster_h = maxi(raster_h, gy + dy + 1)
	var exterior := {}
	var stack: Array[Vector2i] = []
	for x in raster_w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, raster_h - 1))
	for y in raster_h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(raster_w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		var key := "%d,%d" % [p.x, p.y]
		if covered.has(key) or exterior.has(key):
			continue
		exterior[key] = true
		for d in _ortho():
			var n := p + d
			if n.x < 0 or n.x >= raster_w or n.y < 0 or n.y >= raster_h:
				continue
			var nk := "%d,%d" % [n.x, n.y]
			if not covered.has(nk) and not exterior.has(nk):
				stack.append(n)
	var hole_count := 0
	var largest := 0
	var visited := {}
	for y in raster_h:
		for x in raster_w:
			var key := "%d,%d" % [x, y]
			if covered.has(key) or exterior.has(key) or visited.has(key):
				continue
			hole_count += 1
			var size := 0
			var hstack: Array[Vector2i] = [Vector2i(x, y)]
			visited[key] = true
			while not hstack.is_empty():
				var hp: Vector2i = hstack.pop_back()
				size += 1
				for d in _ortho():
					var hn := hp + d
					if hn.x < 0 or hn.x >= raster_w or hn.y < 0 or hn.y >= raster_h:
						continue
					var hk := "%d,%d" % [hn.x, hn.y]
					if not covered.has(hk) and not exterior.has(hk) and not visited.has(hk):
						visited[hk] = true
						hstack.append(hn)
			largest = maxi(largest, size)
	return {"largest": largest, "count": hole_count}

func _base_narrow_bridges(cards: Array) -> int:
	var n := cards.size()
	if n < 3:
		return 0
	var pos := {}
	for i in n:
		pos["%d,%d" % [int(cards[i]["grid_x"]), int(cards[i]["grid_y"])]] = i
	var adj: Array = []
	adj.resize(n)
	for i in n:
		var list: Array[int] = []
		var gx := int(cards[i]["grid_x"])
		var gy := int(cards[i]["grid_y"])
		for delta in _moves():
			var j: int = pos.get("%d,%d" % [gx + delta.x, gy + delta.y], -1)
			if j >= 0:
				list.append(int(j))
		adj[i] = list
	var bridges := 0
	for v in n:
		var visited := {}
		var groups: Array[int] = []
		for s in n:
			if s == v or visited.has(s):
				continue
			var count := 0
			var stack: Array[int] = [s]
			visited[s] = true
			while not stack.is_empty():
				var cur: int = stack.pop_back()
				count += 1
				for nb in adj[cur]:
					if nb == v or visited.has(nb):
						continue
					visited[nb] = true
					stack.append(nb)
			groups.append(count)
		var big := 0
		for g in groups:
			if g >= 3:
				big += 1
		if big >= 2:
			bridges += 1
	return bridges

func _real_component_count(cards: Array) -> int:
	if cards.is_empty():
		return 0
	var grid_idx := {}
	var by_id := {}
	for i in cards.size():
		var c = cards[i]
		grid_idx["%d:%d,%d" % [int(c["layer"]), int(c["grid_x"]), int(c["grid_y"])]] = i
		by_id[str(c["id"])] = i
	var adj: Array = []
	adj.resize(cards.size())
	for i in cards.size():
		adj[i] = []
	for i in cards.size():
		var c = cards[i]
		var layer := int(c["layer"])
		for delta in _moves():
			var j: int = grid_idx.get("%d:%d,%d" % [layer, int(c["grid_x"]) + delta.x, int(c["grid_y"]) + delta.y], -1)
			if j >= 0 and j != i:
				(adj[i] as Array).append(j)
		for sid in c.get("support_ids", []):
			if by_id.has(str(sid)):
				var k: int = by_id[str(sid)]
				if not (adj[i] as Array).has(k):
					(adj[i] as Array).append(k)
				if not (adj[k] as Array).has(i):
					(adj[k] as Array).append(i)
	var visited := {}
	var comps := 0
	for i in cards.size():
		if visited.has(i):
			continue
		comps += 1
		var stack: Array[int] = [i]
		visited[i] = true
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			for nb in adj[cur]:
				if not visited.has(nb):
					visited[nb] = true
					stack.append(nb)
	return comps

func _full_signature(cards: Array) -> Array:
	var sig: Array = []
	for c in cards:
		var support: Array = []
		for sid in c.get("support_ids", []):
			support.append(str(sid))
		support.sort()
		sig.append("%d,%d,%d,%s,%s" % [int(c["layer"]), int(c["grid_x"]), int(c["grid_y"]), str(support), str(bool(c.get("blocked", false)))])
	sig.sort()
	return sig

func _component_count(cards: Array) -> int:
	var index := {}
	for i in cards.size():
		var c = cards[i]
		index["%d,%d" % [int(c["grid_x"]), int(c["grid_y"])]] = i
	var visited := {}
	var comps := 0
	for i in cards.size():
		if visited.has(i):
			continue
		comps += 1
		var stack: Array[int] = [i]
		visited[i] = true
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			var cc = cards[cur]
			for delta in _moves():
				var key := "%d,%d" % [int(cc["grid_x"]) + delta.x, int(cc["grid_y"]) + delta.y]
				if index.has(key):
					var j: int = index[key]
					if not visited.has(j):
						visited[j] = true
						stack.append(j)
	return comps

func _moves() -> Array:
	return [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

func _ortho() -> Array[Vector2i]:
	return [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _signature(cards: Array) -> Array:
	var sig: Array = []
	for c in cards:
		sig.append("%d,%d" % [int(c["grid_x"]), int(c["grid_y"])])
	sig.sort()
	return sig
