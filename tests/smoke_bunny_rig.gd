extends SceneTree

# Dedicated smoke for the delivered Bunny idle rig: the scene loads, its Idle animation
# plays, the polygons are valid (the shipped Ear R had an out-of-range polygon group),
# and the Mascot switches between the rig (L8 idle / Endless) and the painted expression
# frames (HAPPY / WORRIED / SAD).

const RIG_SCENE := "res://assets/ui/heroes/bunny_rig/bunny_rig.tscn"
const RIG_POLYGONS_MIN := 10

var _fails: Array[String] = []
var _polygon_checked := 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)
		printerr("BUNNY RIG FAIL: " + message)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	_check(ResourceLoader.exists(RIG_SCENE), "rig scene exists: " + RIG_SCENE)
	var packed := load(RIG_SCENE) as PackedScene
	_check(packed != null, "rig scene loads as PackedScene")
	if packed == null:
		_finish()
		return
	var rig := packed.instantiate() as Node2D
	_check(rig != null, "rig root is Node2D")
	if rig == null:
		_finish()
		return
	var anim := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check(anim != null, "rig has an AnimationPlayer")
	if anim != null:
		_check(anim.has_animation("Idle"), "rig has the Idle animation")
		_check(str(anim.autoplay) == "Idle", "Idle is the autoplay animation (got %s)" % anim.autoplay)
		if anim.has_animation("Idle"):
			_check(absf(anim.get_animation("Idle").length - 4.0) < 0.1, "Idle is ~4 s")
	_audit_polygons(rig)
	_check(_polygon_checked >= RIG_POLYGONS_MIN,
		"rig has at least %d visible polygons (got %d)" % [RIG_POLYGONS_MIN, _polygon_checked])
	var bounds := _rig_bounds(rig)
	_check(bounds.size.x > 0.0 and bounds.size.y > 0.0, "rig bounds are non-empty (%s)" % str(bounds.size))
	rig.free()

	# L8 idle: the Mascot must show the rig and start the Idle animation.
	var game = root.get_node_or_null("Game")
	if game == null:
		_check(false, "Game autoload missing")
		_finish()
		return
	game.endless_run = null
	game.current_level_id = "8"
	# Load dynamically: the Mascot script references the Game autoload, which must already
	# exist when the script compiles (a preloaded class would compile before autoloads).
	var mascot_script: Script = load("res://scripts/ui/mascot.gd")
	_check(mascot_script != null, "mascot script loads")
	if mascot_script == null:
		_finish()
		return
	var mascot = mascot_script.new()
	root.add_child(mascot)
	mascot.size = HeroRoster.BASE_SIZE * 1.8
	await _frames(2)
	_check(bool(mascot.get("_rig_active")), "L8 idle activates the rig")
	var idle_rig := mascot.get("_rig") as Node2D
	_check(idle_rig != null and idle_rig.is_inside_tree(), "the rig is in the scene tree")
	if idle_rig != null:
		var ap := idle_rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_check(ap != null and ap.is_playing(), "the Idle animation is playing")
		_check(idle_rig.scale.y > 0.0, "the rig is scaled to the mascot (%s)" % str(idle_rig.scale))
	mascot.set_mood(1)  # HAPPY
	_check(not bool(mascot.get("_rig_active")), "L8 happy keeps the painted frame, not the rig")
	_check(str(mascot.get("frame_id")) == "hero_bunny_sequence", "L8 happy frame is sequence (got %s)" % mascot.get("frame_id"))
	mascot.set_mood(2)  # WORRIED
	_check(not bool(mascot.get("_rig_active")), "L8 worried keeps the painted frame, not the rig")
	mascot.set_mood(3)  # SAD
	_check(not bool(mascot.get("_rig_active")), "L8 sad keeps the painted frame, not the rig")
	mascot.set_mood(0)  # IDLE
	_check(bool(mascot.get("_rig_active")), "L8 idle returns to the rig")
	mascot.queue_free()
	await _frames(1)
	_finish()

func _audit_polygons(node: Node) -> void:
	if node is Polygon2D:
		var poly := node as Polygon2D
		if poly.visible and not poly.polygon.is_empty():
			_polygon_checked += 1
			var bad := false
			for group in poly.polygons:
				for index in group:
					if index < 0 or index >= poly.polygon.size():
						bad = true
			_check(not bad, "polygon %s has only valid vertex indices" % poly.name)
	for child in node.get_children():
		_audit_polygons(child)

func _rig_bounds(rig: Node2D) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var stack: Array[Node] = [rig]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Polygon2D:
			var poly := node as Polygon2D
			if poly.visible and not poly.polygon.is_empty():
				var xf := Transform2D.IDENTITY
				var cur: Node = poly
				while cur != null and cur != rig:
					if cur is Node2D:
						xf = (cur as Node2D).transform * xf
					cur = cur.get_parent()
				for p in poly.polygon:
					var q: Vector2 = xf * p
					lo = lo.min(q)
					hi = hi.max(q)
		for child in node.get_children():
			if child is Node2D:
				stack.append(child)
	return Rect2(lo, hi - lo)

func _finish() -> void:
	if _fails.is_empty():
		print("SMOKE BUNNY RIG OK")
		quit(0)
		return
	printerr("SMOKE BUNNY RIG RED: %d failure(s)" % _fails.size())
	quit(1)
