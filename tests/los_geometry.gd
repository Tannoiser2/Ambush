extends SceneTree
const Los = preload("res://scripts/los_geometry.gd")
const Hex = preload("res://scripts/hex_grid.gd")
const MapA = preload("res://scripts/map_a_terrain.gd")
func _initialize() -> void:
 var map := MapA.new()
 assert(map.data.hexes.size() == 475)
 assert(map.terrain("D1").terrain == "woods")
 assert(map.terrain("T8").terrain == "wood_building")
 assert(map.terrain("J3").terrain == "stream")
 assert(map.data.hexsides["T13|T14"] == "crest")
 assert(map.data.hexsides["R12|S13"] == "embankment")
 assert(map.los("T13","T14").status == "blocked")
 assert(map.los("P6","Q6").status == "clear")
 assert(map.los("A1","C2").status == "clear")
 assert(map.los("A1","C2",{"B1":"rubble"}).status == "blocked")
 assert(map.los("C1","E1").status == "unknown")
 assert(map.los("C3","E3").status == "blocked")
 assert(map.los("E3","C3").status == "blocked")
 assert(map.los("A6","C7").status == "unknown")
 assert(map.los("K13","L13").status == "unknown")
 for origin in ["A1","C3","D1","J3","K13","T8","Y19"]:
  for target in ["A1","C3","D1","J3","K13","T8","Y19"]:
   assert(map.los(origin,target).status == map.los(target,origin).status)
 var heights := {"A1":{"terrain":"clear","elevation":1,"hexside_review_pending":false},
  "B1":{"terrain":"woods","elevation":1,"hexside_review_pending":false},
  "C2":{"terrain":"clear","elevation":2,"hexside_review_pending":false}}
 assert(Los.evaluate_map_a("A1","C2",heights).status == "blocked")
 heights["B1"].terrain = "clear"
 assert(Los.evaluate_map_a("A1","C2",heights).status == "clear")
 assert(Los.evaluate_map_a("A1","C2",heights,{"A1|B1":"crest"}).status == "blocked")
 heights["B1"].elevation = 2
 assert(Los.evaluate_map_a("A1","C2",heights,{"A1|B1":"embankment"}).status == "blocked")
 assert(Los.evaluate_map_a("A1","C2",heights,{"B1|C2":"embankment"}).status == "clear")
 var slope := {"A1":{"terrain":"clear","elevation":1,"hexside_review_pending":false},
  "B1":{"terrain":"woods","elevation":2,"hexside_review_pending":false},
  "C2":{"terrain":"woods","elevation":2,"hexside_review_pending":false},
  "D2":{"terrain":"clear","elevation":3,"hexside_review_pending":false}}
 assert(Los.evaluate_map_a("A1","D2",slope).status == "clear")
 slope["B1"].terrain = "stone_building"
 assert(Los.evaluate_map_a("A1","D2",slope).status == "blocked")
 assert(Los.alternative_intervening_hexes("A1","A1") == [[]])
 assert(Los.alternative_intervening_hexes("A1","B1") == [[]])
 assert(Los.alternative_intervening_hexes("A1","C2") == [["B1"]])
 assert(Los.clear_at_same_elevation("A1","C2",{}))
 assert(not Los.clear_at_same_elevation("A1","C2",{"B1":true}))
 assert(Los.alternative_intervening_hexes("C3","A3") == [["B3"],["B2"]])
 assert(Los.clear_at_same_elevation("C3","A3",{"B3":true}))
 assert(not Los.clear_at_same_elevation("C3","A3",{"B3":true,"B2":true}))
 var border := {"A3":{"terrain":"clear","elevation":1,"hexside_review_pending":false},
  "B2":{"terrain":"clear","elevation":1,"hexside_review_pending":false},
  "B3":{"terrain":"clear","elevation":1,"hexside_review_pending":false},
  "C3":{"terrain":"clear","elevation":1,"hexside_review_pending":false}}
 assert(Los.evaluate_map_a("C3","A3",border).status == "clear")
 assert(Los.evaluate_map_a("C3","A3",border,{"B2|B3":"crest"}).status == "blocked")
 assert(Los.clear_at_same_elevation("C3","A3",{"B3":true}) == Los.clear_at_same_elevation("A3","C3",{"B3":true}))
 for col in range(25):
  for row in range(1,20):
   var a := String.chr(65+col)+str(row)
   for b in ["A1","K10","Y19"]:
    assert(map.los(a,b).status == map.los(b,a).status)
    var paths = Los.alternative_intervening_hexes(a,b)
    assert(not paths.is_empty())
    for path in paths:
     assert(path.size() <= maxi(0,Hex.distance(a,b)-1))
     for id in path:
      assert(id.length() >= 2)
    assert(Los.clear_at_same_elevation(a,b,{}) == Los.clear_at_same_elevation(b,a,{}))
 print("LOS GEOMETRY OK")
 quit()
