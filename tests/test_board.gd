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
