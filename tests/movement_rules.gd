extends SceneTree
const Move = preload("res://scripts/movement_rules.gd")
const MapA = preload("res://scripts/map_a_terrain.gd")
func _initialize() -> void:
 var map := MapA.new()
 assert(Move.cost("A1","B1","standing",4,map.data.hexes,map.data.hexsides).points == 1)
 assert(Move.cost("A1","B1","crouching",4,map.data.hexes,map.data.hexsides).points == 4)
 assert(Move.cost("A1","A2","standing",4,map.data.hexes,map.data.hexsides).points == 1)
 assert(Move.cost("A1","C1","standing",4,map.data.hexes,map.data.hexsides).status == "invalid")
 var hexes := {"A1":{"terrain":"clear","elevation":1,"hexside_review_pending":false},
  "B1":{"terrain":"woods","elevation":2,"hexside_review_pending":false}}
 assert(Move.cost("A1","B1","standing",4,hexes,{}).points == 2)
 assert(Move.cost("A1","B1","standing",4,hexes,{"A1|B1":"crest"}).points == 3)
 assert(Move.cost("A1","B1","standing",4,hexes,{"A1|B1":"embankment"}).points == 3)
 assert(Move.cost("B1","A1","standing",4,hexes,{"A1|B1":"embankment"}).points == 1)
 hexes["B1"].terrain = "stream"
 assert(Move.cost("A1","B1","crouching",4,hexes,{}).status == "invalid")
 hexes["B1"].terrain = "stone_building"
 assert(Move.cost("A1","B1","standing",4,hexes,{}).status == "unknown")
 print("MOVEMENT RULES OK")
 quit()
