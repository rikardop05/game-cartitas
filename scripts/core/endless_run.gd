class_name EndlessRun
extends RefCounted

# One Endless run: a sequence of rounds, each a normal Level built from a
# DifficultyProfile board. Pure logic. The UI feeds build_round_level() into
# LevelValidator / GameController.start_level(level, power_stock) unchanged.

const START_DIFFICULTY := 3
const CLEARING_CAPACITY := 7
const POINTS_PER_CARD := 10
const ROUND_BONUS_PER_ROUND := 100
const GRANT_EVERY_ROUNDS := 3
const GRANT_ROTATION := ["hold", "undo", "refresh"]
const START_POWER_STOCK := {"hold": 2, "undo": 2, "refresh": 1}
const MIN_DECK_CARDS := 6
const MAX_DECK_CARDS := 15
# Endless has no timeout; thresholds only exist because the validator requires them.
const TIME_THRESHOLDS := {"three_stars": 600, "two_stars": 1200}

var current_round: int = 1
var score: int = 0
var rounds_cleared: int = 0
var is_over: bool = false
# Per-run power stock, shared with GameController across rounds. Never the persistent Inventory.
var power_stock: Dictionary = START_POWER_STOCK.duplicate()

var _rng := RandomNumberGenerator.new()
var _result: Dictionary = {}

func _init() -> void:
	_rng.randomize()

# Round N plays profile START_DIFFICULTY + N - 1; past the last profile it stays on the last one.
static func difficulty_for_round(n: int) -> int:
	return clampi(START_DIFFICULTY + n - 1, 1, DifficultyProfile.max_level())

# 6 cards early, +3 every two rounds, capped at 15.
static func deck_card_count(n: int) -> int:
	return clampi(MIN_DECK_CARDS + 3 * ((maxi(n, 1) - 1) / 2), MIN_DECK_CARDS, MAX_DECK_CARDS)

static func round_bonus(n: int) -> int:
	return ROUND_BONUS_PER_ROUND * n

# Returns a level dictionary ready for LevelValidator / GameController, or {"error": ...}.
func build_round_level(board_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var difficulty := difficulty_for_round(current_round)
	var config := DifficultyProfile.for_level(difficulty)
	if config == null:
		return {"error": "no difficulty profile for endless round %d" % current_round}
	if LevelLoader.deterministic:
		_rng.seed = current_round
	var level := {
		"id": "endless-%d" % current_round,
		"difficulty": difficulty,
		"clearing_capacity": CLEARING_CAPACITY,
		"deck": _build_deck(config.board_types, deck_card_count(current_round)),
		"time_thresholds": TIME_THRESHOLDS.duplicate(),
		"rewards": [],
	}
	return LevelLoader.resolve(level, board_size)

# Call with matched_ids.size() from each GameController move result. Returns the points added.
func record_match(card_count: int) -> int:
	if is_over or card_count <= 0:
		return 0
	var points := card_count * POINTS_PER_CARD
	score += points
	return points

# Call when GameController reports a win. Returns {"bonus", "granted": [{"type", "quantity"}], "round": new round}.
func complete_round() -> Dictionary:
	if is_over:
		return {"bonus": 0, "granted": [], "round": current_round}
	var bonus := round_bonus(current_round)
	score += bonus
	rounds_cleared += 1
	current_round += 1
	var granted: Array = []
	if rounds_cleared % GRANT_EVERY_ROUNDS == 0:
		var power: String = GRANT_ROTATION[(rounds_cleared / GRANT_EVERY_ROUNDS - 1) % GRANT_ROTATION.size()]
		power_stock[power] = int(power_stock.get(power, 0)) + 1
		granted.append({"type": power, "quantity": 1})
	return {"bonus": bonus, "granted": granted, "round": current_round}

# Ends the run (defeat or quit). Pass the ProgressManager to record the local best in
# memory; the caller saves it to disk. Idempotent: a second call returns the first result.
func end_run(progress: ProgressManager = null) -> Dictionary:
	if is_over:
		return _result.duplicate()
	is_over = true
	var new_best := false
	if progress != null:
		new_best = progress.record_endless_result(score, rounds_cleared)
	_result = {"score": score, "rounds_cleared": rounds_cleared, "new_best": new_best}
	return _result.duplicate()

# Distinct types first (shuffled), repeating only if the profile has fewer types than trios.
func _build_deck(board_types: Array[String], card_count: int) -> Array:
	var pool: Array = board_types.duplicate()
	_shuffle(pool)
	var deck: Array = []
	for i in card_count / 3:
		var t: String = pool[i % pool.size()]
		for k in 3:
			deck.append(t)
	return deck

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
