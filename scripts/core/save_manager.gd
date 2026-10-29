class_name SaveManager
extends RefCounted

const DEFAULT_PATH := "user://save.json"

# Writes to a temp file first and swaps it in, so a crash mid-write never
# leaves a truncated save behind.
static func save(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var tmp_path := path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (error %d)" % [tmp_path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "	"))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("SaveManager: cannot replace %s (error %d)" % [path, err])
		return false
	return true

static func load(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("SaveManager: cannot read %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("SaveManager: ignoring unreadable save %s" % path)
		return {}
	return json.data
