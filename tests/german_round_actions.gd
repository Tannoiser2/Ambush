extends SceneTree
const Game = preload("res://scripts/game.gd")
const Rules = preload("res://scripts/round_rules.gd")
func _initialize() -> void:
 var game=Game.new()
 game.new_game(7)
 game.state.phase="rounds"
 game.state.round_setup={"number":1}
 game.state.enemies=[{"id":"1","letter":"Q","status":"active","stance":"standing","wounded":false,"panicked":false}]
 game.state.round_track={"german":{"1":{"turns":2}},"us":{},"order":[{"side":"de","turns":2,"ids":["1"]}],"bucket_index":0}
 assert(game.resolve_german_action("1",800))
 assert(game.state.enemies[0].stance=="prone")
 assert(game.state.round_track.german["1"].turns==1)
 var soldier={"id":"A","name":"A","status":"active","wounded":false,"stance":"standing","mp":4,"port_boxes":["",""]}
 game.state.squad=[soldier]
 game.state.round_track.us={"A":{"turns":1,"panic":false}}
 game.apply_soldier_damage(soldier,"P")
 assert(game.state.round_track.us.A.panic)
 assert(soldier.stance=="standing")
 assert(game.state.round_track.us.A.turns==0)
 game.apply_soldier_damage(soldier,"W")
 assert(soldier.wounded and game.state.round_track.us.A.turns==0)
 print("GERMAN ROUND ACTIONS OK")
 quit()
