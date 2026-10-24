class_name AmbushMapATerrain
extends RefCounted
const Los = preload("res://scripts/los_geometry.gd")
var data: Dictionary

func _init() -> void:
 data = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_a_terrain.json"))

func terrain(hex_id: String) -> Dictionary:
 return data.hexes.get(hex_id,{})

func los(a: String, b: String) -> Dictionary:
 return Los.evaluate_map_a(a,b,data.hexes,data.get("hexsides",{}))
