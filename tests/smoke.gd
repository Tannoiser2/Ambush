extends SceneTree
const Game = preload("res://scripts/game.gd")
func _initialize() -> void:
 var g = Game.new()
 g.new_game(123)
 assert(g.state.condition == 1)
 assert(g.dispatch({"type":"move","soldier":"A","hex":"A1"}).ok)
 assert(g.soldier("A").hex == "A1")
 assert(g.state.blocked == "")
 assert(not g.dispatch({"type":"move","soldier":"A","hex":"T8"}).ok)
 var snap = g.snapshot()
 var restored = Game.new()
 assert(restored.restore(JSON.parse_string(JSON.stringify(snap))))
 assert(restored.soldier("A").hex == "A1")
 assert(Game.check_success(0,-5))
 assert(not Game.check_success(9,20))
 var card = g.mission.conditions["1"]
 assert(card.hexes.size() == 475)
 assert(card.events.size() == 19)
 assert(card.hexes["A1"] == "EVENT")
 assert(card.hexes["A2"] == "EVENT")
 assert(card.hexes["G10"] == "s3:328")
 var second = g.mission.conditions["2"]
 assert(second.hexes.size() == 475)
 assert(second.events.size() == 19)
 assert(second.hexes["G10"] == "s3:328")
 assert(second.hexes["M3"] == "s5:192")
 var encounter = Game.new()
 encounter.new_game(77)
 encounter.state.squad[0].hex = "G10"
 encounter.state.context_hex = "G10"
 encounter.state.trigger_soldier = "A"
 encounter.read_reference("s3:328")
 assert("s3" in encounter.state.sightings)
 assert(encounter.soldier("K").hex == "G10")
 var prior_log = encounter.state.log.size()
 encounter.read_reference("s3:328")
 assert(encounter.state.log.size() == prior_log + 1)
 var third = g.mission.conditions["3"]
 assert(third.hexes.size() == 475)
 assert(third.events.size() == 19)
 assert(third.hexes["G10"] == "s3:328")
 print("SMOKE OK")
 quit()
