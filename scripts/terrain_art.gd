class_name AmbushTerrainArt
extends RefCounted

static var texture_cache: Dictionary={}

static func texture(kind: String) -> Texture2D:
	if texture_cache.has(kind):return texture_cache[kind]
	var path: String = {
		"clear":"clear_1", "clear_1":"clear_1", "clear_2":"clear_2", "clear_3":"clear_3",
		"woods":"woods", "brush":"brush", "rough":"rough",
		"stream":"stream", "cover":"cover", "road":"road", "dirt_road":"dirt_road",
		"wood_bridge":"wood_bridge", "stone_bridge":"stone_bridge", "railroad":"railroad",
		"wood_building":"wood_building", "stone_building":"stone_building"
	}.get(kind, "clear_1")
	if kind in ["crater","rubble"]:return null
	var tile: Texture2D=load("res://assets/terrain/%s.png" % path)
	texture_cache[kind]=tile
	return tile
