extends SceneTree

const MAX_FRAMES := 120

var _frames := 0
var _started := false
var _phase := 0
var _phase_frames := 0

func _process(_delta: float) -> bool:
	_frames += 1
	_phase_frames += 1
	if not _started:
		_started = true
		change_scene_to_file("res://scenes/main.tscn")
		return false
	if _frames >= MAX_FRAMES:
		printerr("SMOKE FAIL: timeout at phase %d" % _phase)
		quit(1)
		return false
	var scene := current_scene
	if scene == null:
		printerr("SMOKE FAIL: no current scene")
		quit(1)
		return false
	match _phase:
		0:
			if _phase_frames < 6:
				return false
			if scene.name != "MainMenu":
				printerr("SMOKE FAIL: expected MainMenu, got %s" % scene.name)
				quit(1)
				return false
			var texts := _texts(scene)
			for exp in [Localizer.t("title"), Localizer.t("play"), Localizer.t("options"), Localizer.t("quit")]:
				if not texts.has(exp):
					printerr("SMOKE FAIL: menu missing '%s'" % exp)
					quit(1)
					return false
			_press_button(scene, Localizer.t("play"))
			_phase = 1
			_phase_frames = 0
		1:
			if _phase_frames < 6:
				return false
			if scene.name != "MainMenu":
				printerr("SMOKE FAIL: expected MainMenu after Play, got %s" % scene.name)
				quit(1)
				return false
			var texts2 := _texts(scene)
			if not texts2.has(Localizer.t("select_level")):
				printerr("SMOKE FAIL: levels screen missing heading '%s'" % Localizer.t("select_level"))
				quit(1)
				return false
			var level_buttons := 0
			for node in _nodes(scene):
				if node is Button and (node as Button).text.begins_with("Level"):
					level_buttons += 1
			if level_buttons == 0:
				printerr("SMOKE FAIL: no level buttons found")
				quit(1)
				return false
			print("SMOKE OK")
			quit(0)
	return false

func _texts(node: Node) -> Array:
	var out: Array = []
	for n in _nodes(node):
		if n is Label:
			out.append((n as Label).text)
		elif n is Button:
			out.append((n as Button).text)
	return out

func _nodes(node: Node) -> Array:
	var out: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for child in n.get_children():
			stack.append(child)
	return out

func _press_button(node: Node, text: String) -> void:
	for n in _nodes(node):
		if n is Button and (n as Button).text == text:
			(n as Button).pressed.emit()
			return