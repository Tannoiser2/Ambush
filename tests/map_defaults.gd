extends SceneTree

const MapATerrain = preload("res://scripts/map_a_terrain.gd")

func _init() -> void:
	var map := MapATerrain.new()
	assert(map.data.hexes.size() == 475)
	var assumed_count := 0
	for hex_id in map.data.hexes:
		var record: Dictionary = map.data.hexes[hex_id]
		assert(record.get("elevation") != null, "Quota mancante in %s" % hex_id)
		assert(int(record.get("elevation")) >= 1 and int(record.get("elevation")) <= 3, "Quota fuori intervallo in %s" % hex_id)
		if bool(record.get("elevation_assumed", false)):
			assumed_count += 1
			assert(int(record.elevation) == 1, "La quota assunta deve essere livello 1: %s" % hex_id)
	assert(assumed_count > 0)
	print("Map defaults OK: %d hexes, %d elevations assumed at level 1." % [map.data.hexes.size(), assumed_count])
	quit()
