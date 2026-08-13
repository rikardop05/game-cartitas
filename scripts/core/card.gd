class_name Card
extends RefCounted

enum State { HIDDEN, AVAILABLE, SELECTED, MATCHED, REMOVED }
enum Source { BOARD, DECK_A, DECK_B }
enum Location { BOARD, CLEARING_ZONE, RESERVE }

const SIZE := Vector2(64, 64)

var id: String = ""
var type: String = ""
var position: Vector2 = Vector2.ZERO
var layer: int = 0
var state: int = State.HIDDEN
var source: int = Source.BOARD
var location: int = Location.BOARD

func _init(p_id: String = "", p_type: String = "", p_position: Vector2 = Vector2.ZERO, p_layer: int = 0) -> void:
	id = p_id
	type = p_type
	position = p_position
	layer = p_layer

func get_rect() -> Rect2:
	return Rect2(position, SIZE)

func is_removed() -> bool:
	return state == State.REMOVED

func is_active() -> bool:
	return state != State.REMOVED
