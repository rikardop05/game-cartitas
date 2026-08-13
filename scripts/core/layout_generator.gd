class_name LayoutGenerator
extends RefCounted

const CARD := 64.0

static func generate(types: Array, count: int, params: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(params.get("seed", 1))
	var layers := maxi(1, int(params.get("layers", 2)))
	var width := float(params.get("width", 240))
	var height := float(params.get("height", 200))
	var card := float(params.get("card_size", CARD))

	var flat: Array = []
	for t in types:
		for i in count:
			flat.append(str(t))
	_shuffle(flat, rng)

	var result: Array = []
	var by_layer := {}
	var counter := 0
	for i in flat.size():
		var layer := _layer_for_index(i, flat.size(), layers)
		var pos := Vector2.ZERO
		if layer == 0:
			pos = _scatter_pos(rng, by_layer.get(0, []), width, height, card)
		else:
			pos = _overlap_pos(rng, by_layer, layer, width, height, card)
		counter += 1
		result.append({
			"id": "c%d" % counter,
			"type": flat[i],
			"x": int(round(pos.x)),
			"y": int(round(pos.y)),
			"layer": layer,
		})
		if not by_layer.has(layer):
			by_layer[layer] = []
		by_layer[layer].append(Rect2(pos, Vector2(card, card)))
	return result

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _layer_for_index(index: int, n: int, layers: int) -> int:
	if layers <= 1:
		return 0
	var weights: Array = []
	var total := 0.0
	for l in layers:
		var w := 1.0 / pow(1.6, l)
		weights.append(w)
		total += w
	var acc := 0.0
	for l in layers:
		acc += weights[l] / total
		if index < int(n * acc):
			return l
	return layers - 1

static func _scatter_pos(rng: RandomNumberGenerator, existing: Array, width: float, height: float, card: float) -> Vector2:
	for attempt in 12:
		var p := Vector2(rng.randf_range(0, maxf(0, width - card)), rng.randf_range(0, maxf(0, height - card)))
		var ok := true
		for r in existing:
			if r.has_point(p + Vector2(card, card) * 0.5):
				ok = false
				break
		if ok:
			return p
	return Vector2(rng.randf_range(0, maxf(0, width - card)), rng.randf_range(0, maxf(0, height - card)))

static func _overlap_pos(rng: RandomNumberGenerator, by_layer: Dictionary, layer: int, width: float, height: float, card: float) -> Vector2:
	var lower: Array = []
	for l in layer:
		lower.append_array(by_layer.get(l, []))
	if lower.is_empty():
		return Vector2(rng.randf_range(0, maxf(0, width - card)), rng.randf_range(0, maxf(0, height - card)))
	var anchor: Rect2 = lower[rng.randi_range(0, lower.size() - 1)]
	for attempt in 20:
		var dx := rng.randf_range(-card * 0.75, card * 0.75)
		var dy := rng.randf_range(-card * 0.75, card * 0.75)
		if maxf(absf(dx), absf(dy)) < card * 0.2:
			continue
		var p := anchor.position + Vector2(dx, dy)
		p.x = clampf(p.x, 0, maxf(0, width - card))
		p.y = clampf(p.y, 0, maxf(0, height - card))
		return p
	return anchor.position + Vector2(card * 0.5, card * 0.5)
