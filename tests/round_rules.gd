extends SceneTree
const Rules = preload("res://scripts/round_rules.gd")
func _initialize() -> void:
 for initiative in range(6):
  for roll in range(10):
   var german = Rules.turn_result(initiative,roll,false,false,false)
   assert(german.turns in [0,1,2])
   assert(german.panic == (roll in Rules.PANIC[initiative]))
   var us = Rules.turn_result(initiative,roll,true,true,false)
   assert(us.turns == german.turns)
   assert(us.panic == german.panic)
 assert(Rules.turn_result(3,6,true,false,false).panic)
 assert(not Rules.turn_result(3,6,true,true,false).panic)
 assert(Rules.turn_result(4,2,true,true,true).turns == 1)
 var squad: Array = [
  {"id":"A","hex":"A1","status":"active","initiative":4,"commander":true},
  {"id":"B","hex":"B1","status":"active","initiative":1,"commander":false},
  {"id":"C","hex":"E1","status":"active","initiative":1,"commander":false}
 ]
 assert(Rules.in_command(squad[0],squad))
 assert(Rules.in_command(squad[1],squad))
 assert(not Rules.in_command(squad[2],squad))
 print("ROUND RULES OK")
 quit()
