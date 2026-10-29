extends RefCounted

func _make() -> BoardManager:
	var a := Card.new("a", "cat", Vector2(0, 0), 0)
	var b := Card.new("b", "dog", Vector2(80, 0), 0)
	var c := Card.new("c", "bird", Vector2(0, 0), 1)
	var cards: Array[Card] = [a, b, c]
	for x in cards:
		x.location = Card.Location.BOARD
	var bm := BoardManager.new(cards)
	bm.recalculate_availability()
	return bm

func test_blocked_card_is_hidden() -> void:
	var bm := _make()
	Assert.equals(bm.get_card("a").state, Card.State.HIDDEN, "a blocked by c")
	Assert.equals(bm.get_card("b").state, Card.State.AVAILABLE, "b available")
	Assert.equals(bm.get_card("c").state, Card.State.AVAILABLE, "c available (top layer)")

func test_unblock_after_removal() -> void:
	var bm := _make()
	var c := bm.get_card("c")
	c.state = Card.State.REMOVED
	c.location = Card.Location.CLEARING_ZONE
	bm.recalculate_availability()
	Assert.equals(bm.get_card("a").state, Card.State.AVAILABLE, "a unblocked after c removed")

func test_same_layer_separated_cards_do_not_block() -> void:
	var a := Card.new("a", "cat", Vector2(0, 0), 0)
	var b := Card.new("b", "dog", Vector2(50, 0), 0)
	var cards: Array[Card] = [a, b]
	for x in cards:
		x.location = Card.Location.BOARD
	var bm := BoardManager.new(cards)
	bm.recalculate_availability()
	Assert.equals(a.state, Card.State.AVAILABLE, "same layer does not block")

func test_cards_outside_display_bounds_do_not_block() -> void:
	var lower := Card.new("lower", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(50, 0), 1)
	var bm := BoardManager.new([lower, higher])
	bm.recalculate_availability()
	Assert.equals(lower.state, Card.State.AVAILABLE, "higher card outside visible bounds does not block")

func test_remaining_count() -> void:
	var bm := _make()
	Assert.equals(bm.remaining_count(), 3, "3 active cards")

func test_partial_cover_blocks() -> void:
	var lower := Card.new("lower", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(40, 0), 1)
	var bm := BoardManager.new([lower, higher])
	bm.recalculate_availability()
	Assert.equals(lower.state, Card.State.HIDDEN, "partially covered card blocked")
	Assert.equals(higher.state, Card.State.AVAILABLE, "covering card available")

func test_one_card_covering_several() -> void:
	var higher := Card.new("top", "cat", Vector2(0, 0), 1)
	var a := Card.new("a", "dog", Vector2(0, 0), 0)
	var b := Card.new("b", "bird", Vector2(30, 0), 0)
	var bm := BoardManager.new([higher, a, b])
	bm.recalculate_availability()
	Assert.equals(higher.state, Card.State.AVAILABLE, "top available")
	Assert.equals(a.state, Card.State.HIDDEN, "a blocked by top")
	Assert.equals(b.state, Card.State.HIDDEN, "b blocked by top")

func test_removal_unblocks_several() -> void:
	var higher := Card.new("top", "cat", Vector2(0, 0), 1)
	var a := Card.new("a", "dog", Vector2(0, 0), 0)
	var b := Card.new("b", "bird", Vector2(30, 0), 0)
	var bm := BoardManager.new([higher, a, b])
	bm.recalculate_availability()
	higher.state = Card.State.REMOVED
	higher.location = Card.Location.CLEARING_ZONE
	bm.recalculate_availability()
	Assert.equals(a.state, Card.State.AVAILABLE, "a unblocked after top removed")
	Assert.equals(b.state, Card.State.AVAILABLE, "b unblocked after top removed")

func test_multi_layer_depth_chain() -> void:
	var base := Card.new("base", "cat", Vector2(0, 0), 0)
	var mid := Card.new("mid", "dog", Vector2(0, 0), 1)
	var top := Card.new("top", "bird", Vector2(0, 0), 2)
	var bm := BoardManager.new([base, mid, top])
	bm.recalculate_availability()
	Assert.equals(top.state, Card.State.AVAILABLE, "top available")
	Assert.equals(mid.state, Card.State.HIDDEN, "mid blocked by top")
	Assert.equals(base.state, Card.State.HIDDEN, "base blocked by mid/top")
	top.state = Card.State.REMOVED
	top.location = Card.Location.CLEARING_ZONE
	bm.recalculate_availability()
	Assert.equals(mid.state, Card.State.AVAILABLE, "mid unblocked after top removed")
	Assert.equals(base.state, Card.State.HIDDEN, "base still blocked by mid")
	mid.state = Card.State.REMOVED
	mid.location = Card.Location.CLEARING_ZONE
	bm.recalculate_availability()
	Assert.equals(base.state, Card.State.AVAILABLE, "base unblocked after mid removed")

func test_board_manager_uses_shared_spatial_rule() -> void:
	var lower := Card.new("lower", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(40, 0), 1)
	var bm := BoardManager.new([lower, higher])
	var covered := lower.get_display_rect()
	var covering := higher.get_display_rect()
	Assert.equals(BoardSpatialRules.blocks(covered, covering), bm.is_blocked(lower),
		"BoardManager.is_blocked agrees with BoardSpatialRules.blocks (above 0.10)")
	Assert.is_true(bm.is_blocked(lower), "coverage above 0.10 blocks at runtime")
	var low_just := Card.new("low_just", "cat", Vector2(0, 0), 0)
	var hi_just := Card.new("hi_just", "dog", Vector2(44, 0), 1)
	var bm2 := BoardManager.new([low_just, hi_just])
	Assert.equals(BoardSpatialRules.blocks(low_just.get_display_rect(), hi_just.get_display_rect()),
		bm2.is_blocked(low_just), "sub-threshold agreement below 0.10")
	Assert.is_false(bm2.is_blocked(low_just), "coverage just below 0.10 does NOT block at runtime")
	Assert.is_false(BoardSpatialRules.at_or_above_threshold(0.09999995), "coverage 0.09999995 is NOT at threshold")
	Assert.is_true(BoardSpatialRules.at_or_above_threshold(0.1), "coverage 0.10 IS at threshold")

func test_coverage_below_threshold_does_not_block() -> void:
	var lower := Card.new("lower", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(44, 0), 1)
	var bm := BoardManager.new([lower, higher])
	bm.recalculate_availability()
	Assert.equals(lower.state, Card.State.AVAILABLE, "coverage 0.083 < 0.10 does not block")
	Assert.equals(higher.state, Card.State.AVAILABLE, "covering card available")

func test_coverage_at_threshold_blocks() -> void:
	var lower := Card.new("lower", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(43.0, 0), 1)
	var bm := BoardManager.new([lower, higher])
	bm.recalculate_availability()
	Assert.equals(lower.state, Card.State.HIDDEN, "coverage 0.104 >= 0.10 blocks")
	Assert.equals(higher.state, Card.State.AVAILABLE, "covering card available")

func test_coverage_above_threshold_blocks() -> void:
	var lower := Card.new("lower", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(40, 0), 1)
	var bm := BoardManager.new([lower, higher])
	bm.recalculate_availability()
	Assert.equals(lower.state, Card.State.HIDDEN, "coverage 0.167 > 0.10 blocks")

func test_removing_single_threshold_blocker_unblocks() -> void:
	var lower := Card.new("lower", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(40, 0), 1)
	var bm := BoardManager.new([lower, higher])
	bm.recalculate_availability()
	Assert.equals(lower.state, Card.State.HIDDEN, "covered before removal")
	higher.state = Card.State.REMOVED
	higher.location = Card.Location.CLEARING_ZONE
	bm.recalculate_availability()
	Assert.equals(lower.state, Card.State.AVAILABLE, "unblocked immediately after only blocker removed")

func test_coverage_just_below_threshold_does_not_block() -> void:
	var lower := Card.new("lower", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(43.200024, 0), 1)
	var bm := BoardManager.new([lower, higher])
	bm.recalculate_availability()
	Assert.equals(lower.state, Card.State.AVAILABLE, "coverage 0.0999995 < 0.10 does not block")

func test_removed_target_never_blocked() -> void:
	var target := Card.new("target", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(0, 0), 1)
	var bm := BoardManager.new([target, higher])
	Assert.is_true(bm.is_blocked(target), "active covered target is blocked")
	target.state = Card.State.REMOVED
	Assert.is_false(bm.is_blocked(target), "removed target is never blocked")

func test_target_outside_board_never_blocked() -> void:
	var target := Card.new("target", "cat", Vector2(0, 0), 0)
	var higher := Card.new("higher", "dog", Vector2(0, 0), 1)
	var bm := BoardManager.new([target, higher])
	Assert.is_true(bm.is_blocked(target), "board target is blocked while covered")
	target.location = Card.Location.CLEARING_ZONE
	Assert.is_false(bm.is_blocked(target), "target outside board is never blocked")
