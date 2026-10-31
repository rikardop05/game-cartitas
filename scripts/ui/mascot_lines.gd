class_name MascotLines
extends RefCounted

# Line picker for the mascots (legacy bear/whale/duck hosts and the neutral "hero"
# family every hero portrait uses). Pure logic, no nodes: it only
# returns Localizer keys, so it can be tested headless with a seeded
# RandomNumberGenerator. Each pool is a shuffle bag: every line is used once before
# any repeats, and the line that was just shown from that pool is never picked again
# right after a refill. Bags and last lines are tracked per character AND per pool,
# so interleaving events (or hosts) never causes a repeat. One instance lives for the
# whole session (Game.mascot_lines()), so the memory survives scene reloads.

const CHARACTERS := ["bear", "whale", "duck"]
const DEFAULT_CHARACTER := "bear"
# Every playable hero speaks with this neutral family: the hero id only changes the
# portrait (see Mascot), never the voice, so no proper names leak into the game.
const HERO_CHARACTER := "hero"
const EVENTS := ["intro", "idle_tip", "idle_tip_endless", "match", "zone_warning", "power_used", "win", "lose", "round_intro"]

const POOLS := {
	# Gruff mobster boss: short, threatening-but-friendly.
	"bear": {
		"intro": ["npc_bear_intro_1", "npc_bear_intro_2", "npc_bear_intro_3"],
		"round_intro": ["npc_bear_round_1", "npc_bear_round_2", "npc_bear_round_3"],
		# The last tip is the campaign-only one (stars); Endless leaves it out.
		"idle_tip": ["npc_bear_tip_1", "npc_bear_tip_2", "npc_bear_tip_3", "npc_bear_tip_4"],
		"idle_tip_endless": ["npc_bear_tip_1", "npc_bear_tip_2", "npc_bear_tip_3"],
		"match": ["npc_bear_match_1", "npc_bear_match_2", "npc_bear_match_3"],
		"zone_warning": ["npc_bear_warn_1", "npc_bear_warn_2", "npc_bear_warn_3"],
		"power_used": ["npc_bear_power_1", "npc_bear_power_2", "npc_bear_power_3"],
		"win_1": ["npc_bear_win1_1", "npc_bear_win1_2", "npc_bear_win1_3"],
		"win_2": ["npc_bear_win2_1", "npc_bear_win2_2", "npc_bear_win2_3"],
		"win_3": ["npc_bear_win3_1", "npc_bear_win3_2", "npc_bear_win3_3"],
		"lose": ["npc_bear_lose_1", "npc_bear_lose_2", "npc_bear_lose_3"],
		"lose_timeout": ["npc_bear_timeout_1", "npc_bear_timeout_2", "npc_bear_timeout_3"],
	},
	# Pompous sea captain: formal, dramatic.
	"whale": {
		"intro": ["npc_whale_intro_1", "npc_whale_intro_2", "npc_whale_intro_3"],
		"round_intro": ["npc_whale_round_1", "npc_whale_round_2", "npc_whale_round_3"],
		"idle_tip": ["npc_whale_tip_1", "npc_whale_tip_2", "npc_whale_tip_3", "npc_whale_tip_4"],
		"idle_tip_endless": ["npc_whale_tip_1", "npc_whale_tip_2", "npc_whale_tip_3"],
		"match": ["npc_whale_match_1", "npc_whale_match_2", "npc_whale_match_3"],
		"zone_warning": ["npc_whale_warn_1", "npc_whale_warn_2", "npc_whale_warn_3"],
		"power_used": ["npc_whale_power_1", "npc_whale_power_2", "npc_whale_power_3"],
		"win_1": ["npc_whale_win1_1", "npc_whale_win1_2", "npc_whale_win1_3"],
		"win_2": ["npc_whale_win2_1", "npc_whale_win2_2", "npc_whale_win2_3"],
		"win_3": ["npc_whale_win3_1", "npc_whale_win3_2", "npc_whale_win3_3"],
		"lose": ["npc_whale_lose_1", "npc_whale_lose_2", "npc_whale_lose_3"],
		"lose_timeout": ["npc_whale_timeout_1", "npc_whale_timeout_2", "npc_whale_timeout_3"],
	},
	# Cynical film-noir detective: deadpan.
	"duck": {
		"intro": ["npc_duck_intro_1", "npc_duck_intro_2", "npc_duck_intro_3"],
		"round_intro": ["npc_duck_round_1", "npc_duck_round_2", "npc_duck_round_3"],
		"idle_tip": ["npc_duck_tip_1", "npc_duck_tip_2", "npc_duck_tip_3", "npc_duck_tip_4"],
		"idle_tip_endless": ["npc_duck_tip_1", "npc_duck_tip_2", "npc_duck_tip_3"],
		"match": ["npc_duck_match_1", "npc_duck_match_2", "npc_duck_match_3"],
		"zone_warning": ["npc_duck_warn_1", "npc_duck_warn_2", "npc_duck_warn_3"],
		"power_used": ["npc_duck_power_1", "npc_duck_power_2", "npc_duck_power_3"],
		"win_1": ["npc_duck_win1_1", "npc_duck_win1_2", "npc_duck_win1_3"],
		"win_2": ["npc_duck_win2_1", "npc_duck_win2_2", "npc_duck_win2_3"],
		"win_3": ["npc_duck_win3_1", "npc_duck_win3_2", "npc_duck_win3_3"],
		"lose": ["npc_duck_lose_1", "npc_duck_lose_2", "npc_duck_lose_3"],
		"lose_timeout": ["npc_duck_timeout_1", "npc_duck_timeout_2", "npc_duck_timeout_3"],
	},
	# Neutral voice for every hero portrait: no proper names, same tips for all.
	"hero": {
		"intro": ["hero_intro_1", "hero_intro_2", "hero_intro_3"],
		"round_intro": ["mascot_round_1", "mascot_round_2", "mascot_round_3"],
		"idle_tip": [
			"mascot_tip_1", "mascot_tip_2", "mascot_tip_3", "mascot_tip_4",
			"mascot_tip_5", "mascot_tip_6", "mascot_tip_7", "mascot_tip_8",
			"mascot_tip_9", "mascot_tip_10", "mascot_tip_11",
		],
		"idle_tip_endless": [
			"mascot_tip_1", "mascot_tip_2", "mascot_tip_3", "mascot_tip_4",
			"mascot_tip_5", "mascot_tip_6", "mascot_tip_7", "mascot_tip_8",
			"mascot_tip_9", "mascot_tip_10",
		],
		"match": ["mascot_match_1", "mascot_match_2", "mascot_match_3", "mascot_match_4"],
		"zone_warning": ["mascot_warn_1", "mascot_warn_2", "mascot_warn_3", "mascot_warn_4"],
		"power_used": ["mascot_power_1", "mascot_power_2", "mascot_power_3", "mascot_power_4"],
		"win_1": ["mascot_win1_1", "mascot_win1_2", "mascot_win1_3"],
		"win_2": ["mascot_win2_1", "mascot_win2_2", "mascot_win2_3"],
		"win_3": ["mascot_win3_1", "mascot_win3_2", "mascot_win3_3"],
		"lose": ["mascot_lose_1", "mascot_lose_2", "mascot_lose_3", "mascot_lose_4"],
		"lose_timeout": ["mascot_timeout_1", "mascot_timeout_2", "mascot_timeout_3"],
	},
}

# Default host for pick() calls without an explicit character.
var character := DEFAULT_CHARACTER

var _rng: RandomNumberGenerator
var _bags := {}
var _last := {}  # "character/pool id" -> last line shown from it

func _init(rng: RandomNumberGenerator = null, for_character: String = DEFAULT_CHARACTER) -> void:
	if rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	else:
		_rng = rng
	if CHARACTERS.has(for_character) or for_character == HERO_CHARACTER:
		character = for_character

# Maps an event (+ context) to its pool. "win" uses context.stars (1..3),
# "lose" uses context.timeout (true when the clock ran out). Unknown events
# have no pool and return "".
static func pool_id(event: String, context: Dictionary = {}) -> String:
	match event:
		"win":
			return "win_%d" % clampi(int(context.get("stars", 1)), 1, 3)
		"lose":
			return "lose_timeout" if bool(context.get("timeout", false)) else "lose"
	return event if event != "" and POOLS[DEFAULT_CHARACTER].has(event) else ""

# Pool for a character (the hero family, a legacy NPC host, or the default fallback).
static func pools_for(for_character: String) -> Dictionary:
	var id := str(for_character)
	if id == HERO_CHARACTER or CHARACTERS.has(id):
		return POOLS[id]
	return POOLS[DEFAULT_CHARACTER]

# Returns the Localizer key to show, or "" for an unknown event. `for_character`
# overrides the picker's default host (the mascot passes its own).
func pick(event: String, context: Dictionary = {}, for_character: String = "") -> String:
	var id := pool_id(event, context)
	if id == "":
		return ""
	var host := for_character if for_character != "" else character
	if host != HERO_CHARACTER and not CHARACTERS.has(host):
		host = DEFAULT_CHARACTER
	var pool: Array = POOLS[host][id]
	var key := "%s/%s" % [host, id]
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag = _refill(pool, str(_last.get(key, "")))
	var line: String = bag.pop_back()
	_bags[key] = bag
	_last[key] = line
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
