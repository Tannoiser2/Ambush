extends SceneTree
const Fire = preload("res://scripts/fire_rules.gd")
func _initialize() -> void:
 var f = Fire.new()
 var mission: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/mission_01.json"))
 for unit in mission.squad:
  assert(not f.weapon(unit.weapon).is_empty())
 var german_cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/german_cards_m1.json")).cards
 for card in german_cards.values():
  for carried in card.weapons:
   if carried != "Granata": assert(not f.weapon(carried).is_empty())
 assert(f.weapons.size() == 8)
 for w in f.weapons.values():
  assert(w.damage.size() == 10)
  assert(w.range[0] < w.range[1])
 assert(f.base_chance("Fucile semiautomatico",0) == 8)
 assert(f.base_chance("Fucile semiautomatico",1) == 7)
 assert(f.base_chance("Fucile semiautomatico",8) == 4)
 assert(f.base_chance("Pistola",21) == -1)
 assert(f.hit_chance("Fucile semiautomatico",8,-1,"open","standing",true) == 2)
 assert(f.damage("Fucile semiautomatico",4) == "W")
 assert(f.damage("Fucile automatico",9) == "K")
 assert(f.hit_chance("Fucile automatico",5,0,"open","standing",false,false,2) == 8)
 assert(f.hit_chance("Pistola",4,0,"woods","prone",true) == 0)
 assert(f.jammed("Fucile automatico",10,true))
 assert(not f.jammed("Fucile automatico",11,true))
 assert(f.spent_clip("Carabina",25))
 assert(not f.spent_clip("Carabina",26))
 var jam = f.resolve_fire("Carabina",5,0,"open","standing",false,false,5,0,9,0)
 assert(jam.result == "jammed" and not jam.clip_spent)
 var hit = f.resolve_fire("Fucile semiautomatico",8,-1,"open","standing",true,false,12,1,4,17)
 assert(hit.result == "hit" and hit.chance == 2 and hit.damage == "W" and hit.clip_spent)
 var miss = f.resolve_fire("Fucile semiautomatico",8,-1,"open","standing",true,false,12,9,4,26)
 assert(miss.result == "miss" and miss.damage == "" and not miss.clip_spent)
 print("FIRE RULES OK")
 quit()
