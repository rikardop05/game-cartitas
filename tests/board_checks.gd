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

# Cards that are not on the half-card grid.
static func off_grid(cards: Array, card_size: float) -> int:
	var count := 0
	for c in cards:
		if not is_zero_approx(fposmod(float(c["x"]), card_size / 2.0)) or not is_zero_approx(fposmod(float(c["y"]), card_size / 2.0)):
			count += 1
	return count

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
		out.append("%d cards off the half-card grid" % n)
	var bad := unsupported(cards, card_size)
	if not bad.is_empty():
		out.append("unsupported upper cards: %s" % str(bad))
	var counts := layer_counts(cards)
	for i in range(1, counts.size()):
		if int(counts[i]) >= int(counts[i - 1]) or int(counts[i]) == 0:
			out.append("layers do not shrink strictly: %s" % str(counts))
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
