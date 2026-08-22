class_name MoveResult
extends RefCounted

enum Reason {
	OK,
	NOT_PLAYING,
	CARD_NOT_FOUND,
	CARD_NOT_AVAILABLE,
	ZONE_OVERFLOW,
	ZONE_FULL,
	DECK_INVALID,
	DECK_EMPTY,
	NO_POWER,
	ZONE_EMPTY,
	NOT_IN_RESERVE,
	NOTHING_TO_UNDO,
}

const LEGACY_MESSAGES := {
	Reason.OK: "",
	Reason.NOT_PLAYING: "not_playing",
	Reason.CARD_NOT_FOUND: "card_not_found",
	Reason.CARD_NOT_AVAILABLE: "card_not_available",
	Reason.ZONE_OVERFLOW: "clearing_zone_full",
	Reason.ZONE_FULL: "zone_full",
	Reason.DECK_INVALID: "invalid_deck",
	Reason.DECK_EMPTY: "deck_empty",
	Reason.NO_POWER: "no_power",
	Reason.ZONE_EMPTY: "zone_empty",
	Reason.NOT_IN_RESERVE: "card_not_in_reserve",
	Reason.NOTHING_TO_UNDO: "nothing_to_undo",
}

var ok: bool = false
var reason: Reason = Reason.OK
var defeat: bool = false
var matched_ids: Array[String] = []
var status: int = 0

func _init(p_ok: bool = false, p_reason: Reason = Reason.OK, p_status: int = 0, p_defeat: bool = false) -> void:
	ok = p_ok
	reason = p_reason
	status = p_status
	defeat = p_defeat

func message() -> String:
	return LEGACY_MESSAGES[reason]

func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"message": message(),
		"defeat": defeat,
		"matched_ids": matched_ids,
		"status": status,
	}