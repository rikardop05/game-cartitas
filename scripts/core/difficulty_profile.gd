class_name DifficultyProfile
extends RefCounted

# Parametric progression for the shipped levels. Each row is a full
# LevelConfig for a difficulty. Future levels (12+) are added by appending a
# row here - no code changes required anywhere else.
# Boards are WIDE with many SMALL cards (about 2:1, like the reference): the base layer
# grows from 5x3 at L1 to 12x7 at L11 and the upper layers are stacked pyramidally on it;
# the renderer caps a board card at LevelConfig.MAX_BOARD_CARD_PX.
# Row fields: board_types = the symbols on the board; board_cards = the board card total
# (a multiple of 3); the per-type board counts are derived from the Support Deck pool
# (LevelConfig._derive_board_counts) so every type's board+deck total stays a multiple
# of 3 while the deck itself never holds 3 of one type;
# columns x rows = largest base-layer grid in whole cards; layers = pyramid height;
# layer_ratio (optional, default 0.5) = share each upper layer holds of the layer
# below (BoardPipeline.layer_targets) - lower means more cards free at the start;
# aspect_min (optional, default 1.15) = narrowest base (width / height) accepted -
# L5+ ask for clearly wide bases; free_ratio[_min/_max] = wanted share of free cards
# at the start; complexity = informative 1..11 rating; seed = base seed.
const LEVELS := {
	1: {
		"board_types": ["cat", "wolf", "owl", "mouse", "gem", "crystal"],
		"board_cards": 15,
		"columns": 5,
		"rows": 3,
		"layers": 2,
		"layer_ratio": 0.5,
		"free_ratio": 0.52,
		"free_ratio_min": 0.40,
		"free_ratio_max": 0.65,
		"complexity": 1.0,
		"seed": 1001,
	},
	2: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "gem"],
		"board_cards": 30,
		"columns": 7,
		"rows": 4,
		"layers": 2,
		"layer_ratio": 0.5,
		"free_ratio": 0.48,
		"free_ratio_min": 0.35,
		"free_ratio_max": 0.60,
		"complexity": 2.0,
		"seed": 2001,
	},
	3: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "frog", "boar"],
		"board_cards": 36,
		"columns": 7,
		"rows": 4,
		"layers": 3,
		"layer_ratio": 0.5,
		"aspect_min": 1.5,
		"free_ratio": 0.36,
		"free_ratio_min": 0.25,
		"free_ratio_max": 0.48,
		"complexity": 3.0,
		"seed": 3001,
	},
	4: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "frog", "boar", "duck"],
		"board_cards": 45,
		"columns": 8,
		"rows": 4,
		"layers": 3,
		"layer_ratio": 0.5,
		"aspect_min": 1.6,
		"free_ratio": 0.35,
		"free_ratio_min": 0.25,
		"free_ratio_max": 0.48,
		"complexity": 4.0,
		"seed": 4001,
	},
	5: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "frog", "boar", "duck", "leaf"],
		"board_cards": 60,
		"columns": 9,
		"rows": 5,
		"layers": 3,
		"layer_ratio": 0.5,
		"aspect_min": 1.6,
		"free_ratio": 0.33,
		"free_ratio_min": 0.22,
		"free_ratio_max": 0.46,
		"complexity": 5.0,
		"seed": 5012,
	},
	6: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "frog", "boar", "duck", "leaf"],
		"board_cards": 69,
		"columns": 9,
		"rows": 5,
		"layers": 3,
		"layer_ratio": 0.55,
		"aspect_min": 1.6,
		"free_ratio": 0.32,
		"free_ratio_min": 0.21,
		"free_ratio_max": 0.45,
		"complexity": 6.0,
		"seed": 6001,
	},
	7: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "frog", "boar", "duck", "leaf", "heart", "gem", "crystal"],
		"board_cards": 81,
		"columns": 9,
		"rows": 5,
		"layers": 3,
		"layer_ratio": 0.55,
		"aspect_min": 1.6,
		"free_ratio": 0.31,
		"free_ratio_min": 0.20,
		"free_ratio_max": 0.44,
		"complexity": 7.0,
		"seed": 7001,
	},
	8: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "frog", "boar", "duck", "leaf", "heart", "gem", "crystal"],
		"board_cards": 81,
		"columns": 9,
		"rows": 5,
		"layers": 4,
		"layer_ratio": 0.55,
		"aspect_min": 1.6,
		"free_ratio": 0.29,
		"free_ratio_min": 0.18,
		"free_ratio_max": 0.42,
		"complexity": 8.0,
		"seed": 8001,
	},
	9: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "frog", "boar", "duck", "leaf", "heart", "gem", "crystal"],
		"board_cards": 126,
		"columns": 12,
		"rows": 6,
		"layers": 4,
		"layer_ratio": 0.5,
		"aspect_min": 1.6,
		"free_ratio": 0.30,
		"free_ratio_min": 0.18,
		"free_ratio_max": 0.42,
		"complexity": 9.0,
		"seed": 9001,
	},
	10: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "frog", "boar", "duck", "leaf", "heart", "gem", "crystal"],
		"board_cards": 132,
		"columns": 12,
		"rows": 6,
		"layers": 4,
		"layer_ratio": 0.5,
		"aspect_min": 1.6,
		"free_ratio": 0.29,
		"free_ratio_min": 0.17,
		"free_ratio_max": 0.41,
		"complexity": 10.0,
		"seed": 10002,
	},
	11: {
		"board_types": ["cat", "wolf", "owl", "whale", "mouse", "frog", "boar", "duck", "leaf", "heart", "gem", "crystal"],
		"board_cards": 144,
		"columns": 13,
		"rows": 7,
		"layers": 4,
		"layer_ratio": 0.6,
		"aspect_min": 1.6,
		"free_ratio": 0.29,
		"free_ratio_min": 0.17,
		"free_ratio_max": 0.41,
		"complexity": 11.0,
		"seed": 11004,
	},
}

static func max_level() -> int:
	return LEVELS.size()

static func for_level(n: int) -> LevelConfig:
	var params: Dictionary = LEVELS.get(int(n), {})
	if params.is_empty():
		return null
	return LevelConfig.create(params)
