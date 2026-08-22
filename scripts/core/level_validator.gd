class_name LevelValidator
extends RefCounted

const MAX_OVERLAP := 0.75
const OVERLAP_EPSILON := 0.001

static func validate(level: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var cards = level.get("cards", [])
	var ids := {}
	var type_counts := {}

	if not (cards is Array) or cards.size() == 0:
		errors.append("level has no cards")

	var card_size := float(level.get("card_size", 48.0))

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

	_validate_spatial(level, cards, card_size, errors)
	_validate_available(level, cards, card_size, errors)

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

	var time_limit = float(level.get("time_limit", 0.0))
	if time_limit > 0.0 and thresholds.has("two_stars") and time_limit <= float(thresholds["two_stars"]):
		errors.append("time_limit must be greater than two_stars")

	for deck in ["deck_a", "deck_b"]:
		if not level.has(deck) or not (level[deck] is Array):
			errors.append("missing %s" % deck)

	return {"valid": errors.is_empty(), "errors": errors}

static func _validate_spatial(level: Dictionary, cards: Array, card_size: float, errors: Array[String]) -> void:
	var width := float(level.get("board_width", 0.0))
	var height := float(level.get("board_height", 0.0))
	if width > 0.0 and height > 0.0:
		for cdata in cards:
			var id := str(cdata.get("id", ""))
			var x := float(cdata.get("x", -1.0))
			var y := float(cdata.get("y", -1.0))
			if x < 0.0 or x + card_size > width + 0.01:
				errors.append("card %s out of bounds horizontally" % id)
			if y < 0.0 or y + card_size > height + 0.01:
				errors.append("card %s out of bounds vertically" % id)

	var layer0_seen := {}
	for cdata in cards:
		if int(cdata.get("layer", 0)) != 0:
			continue
		var key := "%d,%d" % [int(cdata.get("x", 0)), int(cdata.get("y", 0))]
		if layer0_seen.has(key):
			errors.append("layer-0 cards stacked silently at %s" % key)
		layer0_seen[key] = true

	for i in cards.size():
		var cdata = cards[i]
		var rect := _card_rect(cdata, card_size)
		var cov := 0.0
		for j in cards.size():
			if i == j:
				continue
			var odata = cards[j]
			if int(odata.get("layer", 0)) <= int(cdata.get("layer", 0)):
				continue
			cov = maxf(cov, _overlap_frac(rect, _card_rect(odata, card_size), card_size))
		if cov > MAX_OVERLAP + OVERLAP_EPSILON:
			errors.append("card %s overlaps a covering card by %.2f (max %.2f)" % [str(cdata.get("id", "")), cov, MAX_OVERLAP])

static func _validate_available(level: Dictionary, cards: Array, card_size: float, errors: Array[String]) -> void:
	var available := 0
	for i in cards.size():
		var cdata = cards[i]
		var c_rect := _card_rect(cdata, card_size)
		var blocked := false
		for j in cards.size():
			if j == i:
				continue
			var odata = cards[j]
			if int(odata.get("layer", 0)) <= int(cdata.get("layer", 0)):
				continue
			if c_rect.intersects(_card_rect(odata, card_size)):
				blocked = true
				break
		if not blocked:
			available += 1
	if available < 1:
		errors.append("level has no available cards")

static func _card_rect(cdata, card_size: float) -> Rect2:
	return Rect2(Vector2(float(cdata.get("x", 0)), float(cdata.get("y", 0))), Vector2(card_size, card_size))

static func _overlap_frac(a: Rect2, b: Rect2, card_size: float) -> float:
	var ix := maxf(0.0, minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x))
	var iy := maxf(0.0, minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y))
	return (ix * iy) / maxf(1.0, card_size * card_size)