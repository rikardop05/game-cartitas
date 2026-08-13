extends RefCounted

func test_draw_and_empty() -> void:
	var d := DeckManager.new(["cat", "dog", "bird"])
	Assert.equals(d.current_type(), "cat", "top is cat")
	Assert.equals(d.remaining_count(), 3, "3 remaining")
	Assert.equals(d.draw_type(), "cat", "draw cat")
	Assert.equals(d.current_type(), "dog", "next is dog")
	Assert.equals(d.remaining_count(), 2, "2 remaining")
	d.draw_type()
	d.draw_type()
	Assert.is_true(d.is_empty(), "empty after drawing all")
	Assert.equals(d.draw_type(), "", "draw from empty returns empty string")

func test_return_type() -> void:
	var d := DeckManager.new(["cat", "dog"])
	d.draw_type()
	d.return_type()
	Assert.equals(d.current_type(), "cat", "returned to top")

func test_shuffle_remaining_preserves_drawn() -> void:
	var d := DeckManager.new(["a", "b", "c", "d", "e"])
	d.draw_type()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	d.shuffle_remaining(rng)
	Assert.equals(d.card_types[0], "a", "drawn card stays at index 0")
	Assert.equals(d.remaining_count(), 4, "still 4 remaining")
	var remaining: Array = d.card_types.slice(1)
	remaining.sort()
	Assert.equals(remaining, ["b", "c", "d", "e"], "same multiset preserved")
