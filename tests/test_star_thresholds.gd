extends RefCounted

# Star thresholds scale with the cards a level asks the player to clear (board + decks):
# about 1.5 s per card for three stars and 2.6 s for two, so a fast clean run is needed for
# 3 stars and a normal one earns 2.

const THREE_RANGE := Vector2(1.3, 1.8)
const TWO_RANGE := Vector2(2.3, 3.0)

func test_thresholds_follow_the_card_count() -> void:
	for id in LevelLoader.load_all_level_ids():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LevelLoader.level_path(id)))
		var config := DifficultyProfile.for_level(int(data["difficulty"]))
		var cards: int = config.board_cards() + data.get("deck", []).size()
		var three: float = float(data["time_thresholds"]["three_stars"])
		var two: float = float(data["time_thresholds"]["two_stars"])
		Assert.is_true(three / cards >= THREE_RANGE.x and three / cards <= THREE_RANGE.y, "level %s: 3 stars at %.2f s/card" % [id, three / cards])
		Assert.is_true(two / cards >= TWO_RANGE.x and two / cards <= TWO_RANGE.y, "level %s: 2 stars at %.2f s/card" % [id, two / cards])
		Assert.is_true(three < two, "level %s: 3-star time below 2-star time" % id)
		if data.has("time_limit"):
			Assert.is_true(float(data["time_limit"]) > two, "level %s: time limit above the 2-star time" % id)
