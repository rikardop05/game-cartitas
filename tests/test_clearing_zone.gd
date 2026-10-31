extends RefCounted

func _card(p_id: String, p_type: String) -> Card:
	return Card.new(p_id, p_type)

func test_add_and_capacity() -> void:
	var z := ClearingZoneManager.new(3)
	Assert.is_false(z.is_full(), "not full at start")
	z.add(_card("a", "cat"))
	z.add(_card("b", "cat"))
	z.add(_card("c", "wolf"))
	Assert.is_true(z.is_full(), "full at capacity")
	Assert.equals(z.count_of_type("cat"), 2, "counts cat")

func test_resolve_matches_removes_exactly_three() -> void:
	var z := ClearingZoneManager.new(7)
	for i in 4:
		z.add(_card("c%d" % i, "cat"))
	z.add(_card("d", "wolf"))
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
	z.add(_card("b", "wolf"))
	z.add(_card("c", "owl"))
	z.add(_card("d", "whale"))
	var taken := z.take_last(2)
	Assert.equals(taken[0].id, "c", "first taken is c")
	Assert.equals(taken[1].id, "d", "second taken is d")
	Assert.equals(z.size(), 2, "two remain")

func test_insert_after_last_same_type() -> void:
	var z := ClearingZoneManager.new(7)
	z.add(_card("a", "cat"))
	z.add(_card("b", "wolf"))
	z.add(_card("c", "cat"))
	Assert.equals(z.cards.map(func(c): return c.id), ["a", "c", "b"], "cat lands right after the last cat")

func test_insert_at_end_for_new_type() -> void:
	var z := ClearingZoneManager.new(7)
	z.add(_card("a", "cat"))
	z.add(_card("b", "wolf"))
	z.add(_card("c", "owl"))
	Assert.equals(z.cards.map(func(c): return c.id), ["a", "b", "c"], "new type appended")

func test_add_returns_insertion_index() -> void:
	var z := ClearingZoneManager.new(7)
	Assert.equals(z.add(_card("a", "cat")), 0, "empty zone inserts at 0")
	Assert.equals(z.add(_card("b", "wolf")), 1, "new type appends")
	Assert.equals(z.add(_card("c", "cat")), 1, "same type lands after the last cat")
	Assert.equals(z.insertion_index_for("wolf"), 3, "new type index is the zone size")
	Assert.equals(z.insertion_index_for("cat"), 2, "after the last cat")

func test_insert_groups_cards_of_the_same_type() -> void:
	var z := ClearingZoneManager.new(7)
	z.add(_card("a", "cat"))
	z.add(_card("b", "wolf"))
	z.add(_card("c", "cat"))
	Assert.equals(z.cards.map(func(c): return c.type), ["cat", "cat", "wolf"], "cats stay together")

func test_remove_most_recent_removes_mid_row_card() -> void:
	var z := ClearingZoneManager.new(7)
	z.add(_card("a", "cat"))
	z.add(_card("b", "wolf"))
	z.add(_card("c", "cat"))
	Assert.equals(z.cards.map(func(c): return c.id), ["a", "c", "b"], "c sits mid-row")
	var removed := z.remove_most_recent()
	Assert.equals(removed.id, "c", "newest card removed, not the last in row order")
	Assert.equals(z.cards.map(func(c): return c.id), ["a", "b"], "the rest keep their order")

func test_remove_most_recent_null_on_empty_zone() -> void:
	var z := ClearingZoneManager.new(7)
	Assert.is_true(z.remove_most_recent() == null, "nothing to remove")

func test_remove_most_recent_skips_matched_cards() -> void:
	var z := ClearingZoneManager.new(7)
	z.add(_card("a", "cat"))
	z.add(_card("b", "cat"))
	z.add(_card("d", "wolf"))
	z.add(_card("c", "cat"))
	var matched := z.resolve_matches("cat")
	Assert.equals(matched.size(), 3, "three cats matched away")
	Assert.equals(z.size(), 1, "only the dog is left")
	var removed := z.remove_most_recent()
	Assert.equals(removed.id, "d", "the matched cats are skipped")
	Assert.equals(z.size(), 0, "zone empty")
