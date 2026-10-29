class_name BoardBuildResult
extends RefCounted

enum ErrorCode { OK, SPEC_INVALID, OUT_OF_CELLS, BUDGET_EXHAUSTED, COMPACTNESS_REJECTED, UPPER_LAYER_REJECTED }

var ok: bool = false
var cards: Array[Dictionary] = []
var metrics: Dictionary = {}
var error_code: int = ErrorCode.OK
var error_message: String = ""