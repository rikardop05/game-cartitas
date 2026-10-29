extends RefCounted

# Shared board invariants for the suites that test generated levels, expressed
# only through public data (level["cards"]) and BoardSpatialRules.

static func _rect(card: Dictionary, card_size: float) -> Rect2:
	return Rect2(Vector2(float(card["x"]), float(card["y"])), Vector2(card_size, card_size))

# Cards on the same layer whose rectangles overlap (touching edges are fine).
static func same_layer_overlaps(cards: Array, card_size: float) -> int:
	var overlaps := 0
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			if int(cards[i]["layer"]) != int(cards[j]["layer"]):
				continue
			var a := _rect(cards[i], card_size)
			var b := _rect(cards[j], card_size)
			if a.position.x < b.end.x - 0.01 and b.position.x < a.end.x - 0.01 and a.position.y < b.end.y - 0.01 and b.position.y < a.end.y - 0.01:
				overlaps += 1
	return overlaps

# Cards that are not on the quarter-card lattice (upper layers) or the full-card
# lattice of the base (layer 0, measured from the base's own top-left card).
static func off_grid(cards: Array, card_size: float) -> int:
	var origin := base_origin(cards)
	var count := 0
	for c in cards:
		var step := card_size if int(c["layer"]) == 0 else card_size / 4.0
		var dx := absf(float(c["x"]) - origin.x) / step
		var dy := absf(float(c["y"]) - origin.y) / step
		if absf(dx - roundf(dx)) > 0.001 or absf(dy - roundf(dy)) > 0.001:
			count += 1
	return count

# Top-left corner of the base layer's bounding box.
static func base_origin(cards: Array) -> Vector2:
	var origin := Vector2(INF, INF)
	for c in cards:
		if int(c["layer"]) == 0:
			origin.x = minf(origin.x, float(c["x"]))
			origin.y = minf(origin.y, float(c["y"]))
	return origin

# Bounding box of the base layer (card_size included), the footprint of the whole pile.
static func base_bounds(cards: Array, card_size: float) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for c in cards:
		if int(c["layer"]) != 0:
			continue
		low.x = minf(low.x, float(c["x"]))
		low.y = minf(low.y, float(c["y"]))
		high.x = maxf(high.x, float(c["x"]) + card_size)
		high.y = maxf(high.y, float(c["y"]) + card_size)
	return Rect2(low, high - low)

# Upper cards (layer > 0).
static func upper_cards(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		if int(c["layer"]) > 0:
			out.append(c)
	return out

# Share of the upper cards that have a same-layer card exactly side by side with
# them on the same row (horizontal = true) or the same column (false). A straight
# run of cards is what made the old front layers look tidy.
static func adjacent_run_ratio(cards: Array, card_size: float, horizontal: bool) -> float:
	var upper := upper_cards(cards)
	if upper.is_empty():
		return 0.0
	var hits := 0
	for a in upper:
		for b in upper:
			if a == b or int(a["layer"]) != int(b["layer"]):
				continue
			var along := absf(float(a["x"]) - float(b["x"])) if horizontal else absf(float(a["y"]) - float(b["y"]))
			var across := absf(float(a["y"]) - float(b["y"])) if horizontal else absf(float(a["x"]) - float(b["x"]))
			if across < 0.5 and absf(along - card_size) < 0.5:
				hits += 1
				break
	return float(hits) / float(upper.size())

# Share of the upper cards in a straight run on either axis.
static func straight_run_ratio(cards: Array, card_size: float) -> float:
	var upper := upper_cards(cards)
	if upper.is_empty():
		return 0.0
	var hits := 0
	for a in upper:
		for b in upper:
			if a == b or int(a["layer"]) != int(b["layer"]):
				continue
			var dx := absf(float(a["x"]) - float(b["x"]))
			var dy := absf(float(a["y"]) - float(b["y"]))
			if (dy < 0.5 and absf(dx - card_size) < 0.5) or (dx < 0.5 and absf(dy - card_size) < 0.5):
				hits += 1
				break
	return float(hits) / float(upper.size())

# Length of the longest chain of same-layer cards exactly side by side on one row or column.
static func longest_run(cards: Array, card_size: float) -> int:
	var best := 1 if not upper_cards(cards).is_empty() else 0
	for a in upper_cards(cards):
		for horizontal in [true, false]:
			var length := 1
			var cursor: Dictionary = a
			while true:
				var next: Dictionary = {}
				for b in cards:
					if int(b["layer"]) != int(a["layer"]):
						continue
					var dx := float(b["x"]) - float(cursor["x"])
					var dy := float(b["y"]) - float(cursor["y"])
					var along := dx if horizontal else dy
					var across := dy if horizontal else dx
					if absf(across) < 0.5 and absf(along - card_size) < 0.5:
						next = b
						break
				if next.is_empty():
					break
				length += 1
				cursor = next
			best = maxi(best, length)
	return best

# Distinct fractional positions (in quarter cards, 0-3) of the cards of one layer
# relative to the base's top-left corner, on the x axis or the y axis.
static func offset_classes(cards: Array, layer: int, card_size: float, horizontal: bool) -> Array:
	var origin := base_origin(cards)
	var seen := {}
	for c in cards:
		if int(c["layer"]) != layer:
			continue
		var value := (float(c["x"]) - origin.x) if horizontal else (float(c["y"]) - origin.y)
		seen[posmod(roundi(value / (card_size / 4.0)), 4)] = true
	var out: Array = seen.keys()
	out.sort()
	return out

# Which horizontal thirds and vertical halves of the base footprint hold the centre
# of at least one card of the given layers (empty = every upper layer).
static func region_hits(cards: Array, card_size: float, layers: Array = []) -> Dictionary:
	var bounds := base_bounds(cards, card_size)
	var thirds := {}
	var halves := {}
	for c in cards:
		var layer := int(c["layer"])
		if layer == 0 or (not layers.is_empty() and not layers.has(layer)):
			continue
		var cx := (float(c["x"]) + card_size / 2.0 - bounds.position.x) / bounds.size.x
		var cy := (float(c["y"]) + card_size / 2.0 - bounds.position.y) / bounds.size.y
		thirds[clampi(floori(cx * 3.0), 0, 2)] = true
		halves[clampi(floori(cy * 2.0), 0, 1)] = true
	return {"thirds": thirds.size(), "halves": halves.size()}

# Share of the upper cards that are the only blocker of at least one card of the
# layer right below: removing such a card frees something, so tapping the front
# cards keeps opening the pile.
static func releasing_ratio(cards: Array, card_size: float) -> float:
	var upper := upper_cards(cards)
	if upper.is_empty():
		return 0.0
	var releasing := {}
	for c in cards:
		var blockers: Array = []
		for o in cards:
			if BoardSpatialRules.blocks_with_layers(_rect(c, card_size), _rect(o, card_size), int(c["layer"]), int(o["layer"])):
				blockers.append(str(o["id"]))
		if blockers.size() == 1:
			releasing[blockers[0]] = true
	return float(releasing.size()) / float(upper.size())

# Free cards per layer at the start, base first.
static func free_per_layer(cards: Array, card_size: float) -> Array:
	var out: Array = []
	for _l in layer_counts(cards).size():
		out.append(0)
	for c in cards:
		var blocked := false
		for o in cards:
			if BoardSpatialRules.blocks_with_layers(_rect(c, card_size), _rect(o, card_size), int(c["layer"]), int(o["layer"])):
				blocked = true
				break
		if not blocked:
			out[int(c["layer"])] = int(out[int(c["layer"])]) + 1
	return out

# Upper-layer cards NOT resting on at least two cards of the layer right below
# (each covered at the shared 10%-area threshold).
static func unsupported(cards: Array, card_size: float) -> Array:
	var bad: Array = []
	for c in cards:
		if int(c["layer"]) == 0:
			continue
		var supports := 0
		for o in cards:
			if int(o["layer"]) != int(c["layer"]) - 1:
				continue
			if BoardSpatialRules.at_or_above_threshold(BoardSpatialRules.coverage(_rect(c, card_size), _rect(o, card_size))):
				supports += 1
		if supports < 2:
			bad.append(str(c["id"]))
	return bad

# Cards not blocked at the start, by the single shared blocking rule.
static func free_cards(cards: Array, card_size: float) -> int:
	var free := 0
	for c in cards:
		var blocked := false
		for o in cards:
			if BoardSpatialRules.blocks_with_layers(_rect(c, card_size), _rect(o, card_size), int(c["layer"]), int(o["layer"])):
				blocked = true
				break
		if not blocked:
			free += 1
	return free

# Cards per layer, base first.
static func layer_counts(cards: Array) -> Array:
	var counts := {}
	var top := 0
	for c in cards:
		counts[int(c["layer"])] = int(counts.get(int(c["layer"]), 0)) + 1
		top = maxi(top, int(c["layer"]))
	var out: Array = []
	for l in range(top + 1):
		out.append(int(counts.get(l, 0)))
	return out

# Every structural problem of a resolved level's board, as readable strings.
static func problems(level: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var cards: Array = level.get("cards", [])
	var card_size := float(level.get("card_size", 48.0))
	if cards.is_empty():
		out.append("no cards")
		return out
	var n := same_layer_overlaps(cards, card_size)
	if n > 0:
		out.append("%d same-layer overlaps" % n)
	n = off_grid(cards, card_size)
	if n > 0:
		out.append("%d cards off the base lattice / upper quarter-card lattice" % n)
	var bad := unsupported(cards, card_size)
	if not bad.is_empty():
		out.append("unsupported upper cards: %s" % str(bad))
	var counts := layer_counts(cards)
	for i in range(1, counts.size()):
		if int(counts[i]) >= int(counts[i - 1]) or int(counts[i]) == 0:
			out.append("layers do not shrink strictly: %s" % str(counts))
			break
	var bounds := base_bounds(cards, card_size)
	for c in upper_cards(cards):
		if float(c["x"]) < bounds.position.x - 0.01 or float(c["y"]) < bounds.position.y - 0.01 				or float(c["x"]) + card_size > bounds.end.x + 0.01 or float(c["y"]) + card_size > bounds.end.y + 0.01:
			out.append("upper card %s sticks out of the base footprint" % str(c["id"]))
			break
	var width := float(level.get("board_width", 0.0))
	var height := float(level.get("board_height", 0.0))
	for c in cards:
		if float(c["x"]) < 0.0 or float(c["y"]) < 0.0 or float(c["x"]) + card_size > width + 0.01 or float(c["y"]) + card_size > height + 0.01:
			out.append("card %s outside the %sx%s board" % [str(c["id"]), width, height])
			break
	return out

static func signature(level: Dictionary) -> Array:
	var sig := []
	for c in level["cards"]:
		sig.append([str(c["type"]), int(c["x"]), int(c["y"]), int(c["layer"])])
	return sig
