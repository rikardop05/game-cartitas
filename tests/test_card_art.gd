extends RefCounted

# Card faces: 11 of the 12 types have painted square art (art 960 px, frame included); crystal
# keeps the emoji placeholder until its art arrives. Update both lists when art is added.
const WITH_ART := ["boar", "cat", "duck", "frog", "gem", "heart", "leaf", "mouse", "owl", "whale", "wolf"]
const PLACEHOLDER := ["crystal"]

func test_every_type_is_either_art_or_placeholder() -> void:
	var listed: Array = WITH_ART + PLACEHOLDER
	listed.sort()
	var all_types: Array = CardTypeRegistry.all_types()
	all_types.sort()
	Assert.equals(listed, all_types, "art + placeholder lists cover exactly the registry types")

func test_mapped_types_have_a_square_hi_res_texture() -> void:
	for type in WITH_ART:
		var texture := UiHelpers.card_texture(type)
		Assert.is_true(texture != null, "%s has card art" % type)
		if texture != null:
			Assert.is_true(texture.get_width() == texture.get_height() and texture.get_width() >= 64, "%s art is square and at least 64 px (got %s)" % [type, str(texture.get_size())])
		Assert.is_true(UiHelpers.has_card_art(type), "%s reports art" % type)

func test_unmapped_types_fall_back_to_placeholder() -> void:
	for type in PLACEHOLDER:
		Assert.is_true(UiHelpers.card_texture(type) == null, "%s has no art yet" % type)
		Assert.is_false(UiHelpers.has_card_art(type), "%s uses the placeholder" % type)
		Assert.is_true(CardTypeRegistry.symbol(type) != "", "%s still has an emoji symbol" % type)
	Assert.is_true(UiHelpers.card_texture("no_such_type") == null, "unknown type has no art")

func test_art_keeps_full_resolution_with_mipmaps() -> void:
	# Art must not be pre-shrunk to logical card pixels: the GPU scales it to the physical size.
	for type in WITH_ART:
		var texture := UiHelpers.card_texture(type)
		if texture == null:
			continue
		var image := texture.get_image()
		Assert.is_true(image != null and image.has_mipmaps(), "%s art has mipmaps for clean downscaling" % type)
		Assert.is_true(texture.get_width() >= 480, "%s art stays high resolution (got %d px)" % [type, texture.get_width()])
	Assert.is_true(UiHelpers.card_texture("owl") == UiHelpers.card_texture("owl"), "card art is cached per type")

func test_card_shadows_are_cached_per_card_face() -> void:
	# Generated ImageTextures have an empty resource_path; the shadow cache must key them
	# by identity, otherwise every card reuses the first card's silhouette.
	var heart := UiHelpers.card_texture("heart")
	var gem := UiHelpers.card_texture("gem")
	var leaf := UiHelpers.card_texture("leaf")
	Assert.is_true(heart != null and gem != null and leaf != null, "heart/gem/leaf art exist")
	var sh := UiHelpers.shadow_texture(heart, 2.0, 0.35)
	var sg := UiHelpers.shadow_texture(gem, 2.0, 0.35)
	var sl := UiHelpers.shadow_texture(leaf, 2.0, 0.35)
	Assert.is_true(sh != null and sg != null and sl != null, "card shadows are generated")
	Assert.is_true(sh != sg and sh != sl and sg != sl, "different card faces get different shadows")
	Assert.is_true(UiHelpers.shadow_texture(heart, 2.0, 0.35) == sh, "the same face/shape is cached")
