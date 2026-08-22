class_name LevelSnapshot
extends RefCounted

var status: int = 0
var level_id: String = ""
var board_cards: Array[Card] = []
var clearing_capacity: int = 0
var zone_cards: Array[Card] = []
var reserve_cards: Array[Card] = []
var deck_a_type: String = ""
var deck_a_remaining: int = 0
var deck_b_type: String = ""
var deck_b_remaining: int = 0
var power_counts: Dictionary = {}
var elapsed_seconds: float = 0.0
var time_limit: float = 0.0
var time_remaining: float = INF
var stars: int = 0
var current_stars: int = 0
var legal_actions: Array = []