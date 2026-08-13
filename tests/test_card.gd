extends RefCounted

func test_initial_state_is_hidden() -> void:
	var c := Card.new("c1", "cat")
	Assert.equals(c.state, Card.State.HIDDEN, "new card is HIDDEN")
	Assert.equals(c.type, "cat", "type set")
	Assert.equals(c.id, "c1", "id set")

func test_rect_uses_size_and_position() -> void:
	var c := Card.new("c1", "cat", Vector2(10, 20), 1)
	Assert.equals(c.get_rect(), Rect2(10, 20, 64, 64), "rect from position")

func test_is_removed_and_active() -> void:
	var c := Card.new("c1", "cat")
	Assert.is_false(c.is_removed(), "not removed initially")
	Assert.is_true(c.is_active(), "active initially")
	c.state = Card.State.REMOVED
	Assert.is_true(c.is_removed(), "removed after state change")
	Assert.is_false(c.is_active(), "not active when removed")
