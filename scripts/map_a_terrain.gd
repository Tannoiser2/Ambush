class_name AmbushMapATerrain
extends RefCounted
const Los = preload("res://scripts/los_geometry.gd")
var data: Dictionary

func _init() -> void:
 data = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_a_terrain.json"))

func terrain(hex_id: String, overrides: Dictionary = {}) -> Dictionary:
 var base: Dictionary = data.hexes.get(hex_id,{})
 if base.is_empty() or not overrides.has(hex_id): return base
 var result: Dictionary = base.duplicate(true)
 result.terrain = str(overrides[hex_id])
 result.classification = "event_override"
 return result

func los(a: String, b: String, overrides: Dictionary = {}) -> Dictionary:
 if overrides.is_empty(): return Los.evaluate_map_a(a,b,data.hexes,data.get("hexsides",{}))
 var hexes: Dictionary = data.hexes.duplicate(true)
 for id in overrides:
  if hexes.has(id): hexes[id].terrain = str(overrides[id])
 return Los.evaluate_map_a(a,b,hexes,data.get("hexsides",{}))
