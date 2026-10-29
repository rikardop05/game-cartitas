class_name MascotLines
extends RefCounted

# Line picker for the mascot "Ace" (T7.8). Pure logic, no nodes: it only returns
# Localizer keys, so it can be tested headless with a seeded RandomNumberGenerator.
# Each pool is a shuffle bag: every line is used once before any repeats, and the
# line that was just shown from that pool is never picked again right after a refill.
# The last line is tracked per pool, so interleaving events never causes a repeat.
# One instance lives for the whole session (Game.mascot_lines()), so the memory
# survives scene reloads.

const EVENTS := ["intro", "idle_tip", "idle_tip_endless", "match", "zone_warning", "power_used", "win", "lose", "round_intro"]

const POOLS := {
	"intro": ["mascot_intro_1", "mascot_intro_2", "mascot_intro_3", "mascot_intro_4"],
	"round_intro": ["mascot_round_1", "mascot_round_2", "mascot_round_3"],
	"idle_tip": [
		"mascot_tip_1", "mascot_tip_2", "mascot_tip_3", "mascot_tip_4", "mascot_tip_5", "mascot_tip_6",
		"mascot_tip_7", "mascot_tip_8", "mascot_tip_9", "mascot_tip_10", "mascot_tip_11",
	],
	# Endless has no stars and no timeout, so the campaign-only tip (11) is left out.
	"idle_tip_endless": [
		"mascot_tip_1", "mascot_tip_2", "mascot_tip_3", "mascot_tip_4", "mascot_tip_5", "mascot_tip_6",
		"mascot_tip_7", "mascot_tip_8", "mascot_tip_9", "mascot_tip_10",
	],
	"match": ["mascot_match_1", "mascot_match_2", "mascot_match_3", "mascot_match_4"],
	"zone_warning": ["mascot_warn_1", "mascot_warn_2", "mascot_warn_3", "mascot_warn_4"],
	"power_used": ["mascot_power_1", "mascot_power_2", "mascot_power_3", "mascot_power_4"],
	"win_1": ["mascot_win1_1", "mascot_win1_2", "mascot_win1_3"],
	"win_2": ["mascot_win2_1", "mascot_win2_2", "mascot_win2_3"],
	"win_3": ["mascot_win3_1", "mascot_win3_2", "mascot_win3_3"],
	"lose": ["mascot_lose_1", "mascot_lose_2", "mascot_lose_3", "mascot_lose_4"],
	"lose_timeout": ["mascot_timeout_1", "mascot_timeout_2", "mascot_timeout_3"],
}

var _rng: RandomNumberGenerator
var _bags := {}
var _last := {}  # pool id -> last line shown from it

func _init(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	else:
		_rng = rng

# Maps an event (+ context) to its pool. "win" uses context.stars (1..3),
# "lose" uses context.timeout (true when the clock ran out). Unknown events
# have no pool and return "".
static func pool_id(event: String, context: Dictionary = {}) -> String:
	match event:
		"win":
			return "win_%d" % clampi(int(context.get("stars", 1)), 1, 3)
		"lose":
			return "lose_timeout" if bool(context.get("timeout", false)) else "lose"
	return event if event != "" and POOLS.has(event) else ""

# Returns the Localizer key to show, or "" for an unknown event.
func pick(event: String, context: Dictionary = {}) -> String:
	var id := pool_id(event, context)
	if id == "":
		return ""
	var bag: Array = _bags.get(id, [])
	if bag.is_empty():
		bag = _refill(POOLS[id], str(_last.get(id, "")))
	var line: String = bag.pop_back()
	_bags[id] = bag
	_last[id] = line
	return line

# Fisher-Yates with the injected rng (Array.shuffle would use the global one).
# Lines are popped from the back, so the back must not be the previous line.
func _refill(pool: Array, last: String) -> Array:
	var bag: Array = pool.duplicate()
	for i in range(bag.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
	if bag.size() > 1 and bag.back() == last:
		var front = bag[0]
		bag[0] = bag.back()
		bag[bag.size() - 1] = front
	return bag
