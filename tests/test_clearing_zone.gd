extends RefCounted

func _card(p_id: String, p_type: String) -> Card:
	return Card.new(p_id, p_type)

func test_add_and_capacity() -> void:
	var z := ClearingZoneManager.new(3)
	Assert.is_false(z.is_full(), "not full at start")
	z.add(_card("a", "cat"))
	z.add(_card("b", "cat"))
	z.add(_card("c", "dog"))
	Assert.is_true(z.is_full(), "full at capacity")
	Assert.equals(z.count_of_type("cat"), 2, "counts cat")

func test_resolve_matches_removes_exactly_three() -> void:
	var z := ClearingZoneManager.new(7)
	for i in 4:
		z.add(_card("c%d" % i, "cat"))
	z.add(_card("d", "dog"))
	var matched := z.resolve_matches("cat")
	Assert.equals(matched.size(), 3, "removed 3")
	Assert.equals(z.size(), 2, "one cat + one dog remain")
	for m in matched:
		Assert.equals(m.state, Card.State.REMOVED, "matched card is REMOVED")

func test_resolve_less_than_three_returns_empty() -> void:
	var z := ClearingZoneManager.new(7)
	z.add(_card("a", "cat"))
	z.add(_card("b", "cat"))
	var matched := z.resolve_matches("cat")
	Assert.equals(matched.size(), 0, "no trio")
	Assert.equals(z.size(), 2, "cards remain")

func test_take_last_preserves_order() -> void:
	var z := ClearingZoneManager.new(7)
	z.add(_card("a", "cat"))
	z.add(_card("b", "dog"))
	z.add(_card("c", "bird"))
	z.add(_card("d", "fish"))
	var taken := z.take_last(2)
	Assert.equals(taken[0].id, "c", "first taken is c")
	Assert.equals(taken[1].id, "d", "second taken is d")
	Assert.equals(z.size(), 2, "two remain")
