class_name Assert
extends RefCounted

static var failures: Array[String] = []

static func clear() -> void:
	failures.clear()

static func _record(message: String) -> void:
	failures.append(message)

static func is_true(condition: bool, message: String) -> void:
	if not condition:
		_record(message)

static func is_false(condition: bool, message: String) -> void:
	if condition:
		_record(message)

static func equals(actual, expected, message: String) -> void:
	if not _values_equal(actual, expected):
		_record("%s — expected %s, got %s" % [message, str(expected), str(actual)])

static func not_equals(actual, unexpected, message: String) -> void:
	if _values_equal(actual, unexpected):
		_record("%s — value should not equal %s" % [message, str(unexpected)])

static func _values_equal(a, b) -> bool:
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _values_equal(a[i], b[i]):
				return false
		return true
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k):
				return false
			if not _values_equal(a[k], b[k]):
				return false
		return true
	return a == b
