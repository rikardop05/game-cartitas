class_name LevelValidator
extends RefCounted

static func validate(level: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var cards = level.get("cards", [])
	var ids := {}
	var type_counts := {}

	if not (cards is Array) or cards.size() == 0:
		errors.append("level has no cards")

	for cdata in cards:
		var id := str(cdata.get("id", ""))
		if id == "":
			errors.append("card missing id")
		elif ids.has(id):
			errors.append("duplicate card id: %s" % id)
		else:
			ids[id] = true
		var type := str(cdata.get("type", ""))
		if type == "":
			errors.append("card %s missing type" % id)
		type_counts[type] = int(type_counts.get(type, 0)) + 1

	for deck in ["deck_a", "deck_b"]:
		var deck_arr = level.get(deck, [])
		if not (deck_arr is Array):
			errors.append("missing %s" % deck)
			continue
		for t in deck_arr:
			var ts := str(t)
			type_counts[ts] = int(type_counts.get(ts, 0)) + 1

	for t in type_counts:
		if int(type_counts[t]) % 3 != 0:
			errors.append("type '%s' has %d cards total (not a multiple of 3)" % [t, int(type_counts[t])])

	if int(level.get("clearing_capacity", 0)) <= 0:
		errors.append("clearing_capacity must be > 0")

	var thresholds = level.get("time_thresholds", {})
	if not thresholds.has("three_stars") or not thresholds.has("two_stars"):
		errors.append("missing time_thresholds (three_stars/two_stars)")

	for deck in ["deck_a", "deck_b"]:
		if not level.has(deck) or not (level[deck] is Array):
			errors.append("missing %s" % deck)

	return {"valid": errors.is_empty(), "errors": errors}
