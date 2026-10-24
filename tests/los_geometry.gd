extends SceneTree
const Los = preload("res://scripts/los_geometry.gd")
const Hex = preload("res://scripts/hex_grid.gd")
func _initialize() -> void:
 assert(Los.alternative_intervening_hexes("A1","A1") == [[]])
 assert(Los.alternative_intervening_hexes("A1","B1") == [[]])
 assert(Los.alternative_intervening_hexes("A1","C2") == [["B1"]])
 assert(Los.clear_at_same_elevation("A1","C2",{}))
 assert(not Los.clear_at_same_elevation("A1","C2",{"B1":true}))
 assert(Los.alternative_intervening_hexes("C3","A3") == [["B3"],["B2"]])
 assert(Los.clear_at_same_elevation("C3","A3",{"B3":true}))
 assert(not Los.clear_at_same_elevation("C3","A3",{"B3":true,"B2":true}))
 assert(Los.clear_at_same_elevation("C3","A3",{"B3":true}) == Los.clear_at_same_elevation("A3","C3",{"B3":true}))
 for col in range(25):
  for row in range(1,20):
   var a := String.chr(65+col)+str(row)
   for b in ["A1","K10","Y19"]:
    var paths = Los.alternative_intervening_hexes(a,b)
    assert(not paths.is_empty())
    for path in paths:
     assert(path.size() <= maxi(0,Hex.distance(a,b)-1))
     for id in path: assert(Hex.valid(id))
    assert(Los.clear_at_same_elevation(a,b,{}) == Los.clear_at_same_elevation(b,a,{}))
 print("LOS GEOMETRY OK")
 quit()
