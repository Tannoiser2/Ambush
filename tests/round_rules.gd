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
 var enemies: Array = [
  {"id":"34","letter":"X","status":"active","initiative":4,"wounded":false},
  {"id":"25","letter":"N","status":"active","initiative":4,"wounded":false}
 ]
 var placed = Rules.assign_turns(squad,enemies,{"A":true,"B":false,"C":true},2,9,"de",["34"],false)
 assert(placed.advantage == "de")
 assert(placed.us["A"].turns == 2)
 assert(placed.us["B"].unaware)
 assert(placed.german["34"].turns == 2)
 assert(placed.german["25"].turns == 1)
 assert(placed.order[0].side == "de" and placed.order[0].ids == ["34"])
 var sequence = Rules.start_action_sequence(placed)
 assert(Rules.current_turn_bucket(sequence) == {"side":"de","turns":2,"ids":["34"]})
 assert(not Rules.spend_turn(sequence,"us","A"))
 assert(Rules.spend_turn(sequence,"de","34"))
 assert(Rules.current_turn_bucket(sequence) == {"side":"us","turns":2,"ids":["A"]})
 assert(Rules.spend_turn(sequence,"us","A"))
 assert(Rules.current_turn_bucket(sequence) == {"side":"de","turns":1,"ids":["25","34"]})
 assert(Rules.spend_turn(sequence,"de","25"))
 assert(Rules.spend_turn(sequence,"de","34"))
 assert(Rules.spend_turn(sequence,"us","A"))
 assert(Rules.spend_turn(sequence,"us","C"))
 assert(Rules.current_turn_bucket(sequence).is_empty())
 assert(not Rules.spend_turn(sequence,"us","A"))
 var tie = Rules.assign_turns(squad,enemies,{"A":true},5,5)
 assert(tie.advantage == "de")
 var us_exception = Rules.assign_turns(squad,enemies,{"A":true},3,0,"us",[],true)
 assert(us_exception.us["A"].turns == 2)
 assert(us_exception.order[0].side == "us")
 assert(not Rules.in_command(squad[2],squad))
 squad[0].hex = ""
 squad[1].hex = ""
 assert(Rules.in_command(squad[0],squad))
 assert(Rules.in_command(squad[1],squad))
 squad[0].pc = 4
 squad[1].pc = 3
 squad[2].pc = 2
 assert(Rules.awareness_phase(squad,{},1,["A"],{"A":4}) == {"A":true,"B":false,"C":false})
 assert(Rules.awareness_phase(squad,{},1,["A"],{"A":9},"B") == {"A":false,"B":true,"C":false})
 assert(Rules.awareness_phase(squad,{},1,["A"],{"A":0})["A"])
 assert(Rules.awareness_phase(squad,{},1,["A"],{}) == {})
 assert(Rules.awareness_phase(squad,{"A":true},2,[],{"B":3,"C":9}) == {"A":true,"B":true,"C":false})
 assert(Rules.awareness_phase(squad,{},3,[],{}) == {"A":true,"B":true,"C":true})
 squad[2].status = "killed"
 assert(not Rules.awareness_phase(squad,{},3,[],{}).has("C"))
 print("ROUND RULES OK")
 quit()
