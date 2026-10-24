class_name AmbushRoundRules
extends RefCounted
## Original Action Round Track: IN columns 0–5, d10 results 0–9.
## Red results affect only US soldiers outside command (rules 6/1, 6/3, 6/4).
const Hex = preload("res://scripts/hex_grid.gd")
const TWO_TURNS := [[9], [4,6], [3,5,8], [1,2,7,9], [0,2,5,6,7], [0,1,3,4,5,8]]
const PANIC := [[0,2], [1], [], [], [], []]
const RED := [[1,4,6,8,9], [3,4,5,7], [0,2,3,8], [6,7,9], [2,5], []]

static func in_command(unit: Dictionary, squad: Array) -> bool:
	if unit.get("status", "") != "active": return false
	var rating := 0
	for other in squad:
		if other.get("status", "") != "active": continue
		# Rule 6/10 treats all off-map US soldiers as occupying one hex for command.
		var same_hex: bool = other.get("hex", "") == unit.get("hex", "")
		var nearby: bool = unit.get("hex", "") != "" and other.get("hex", "") != "" and Hex.distance(str(unit.hex), str(other.hex)) <= 2
		var own_radius: bool = bool(unit.get("commander", false)) and not bool(unit.get("panicked", false))
		var other_radius: bool = bool(other.get("commander", false)) and not bool(other.get("panicked", false))
		if same_hex or (nearby and (own_radius or other_radius)):
			rating += int(other.get("initiative", 0))
	return rating >= 5

static func turn_result(initiative: int, roll: int, is_us: bool, command: bool, wounded: bool) -> Dictionary:
	if initiative < 0 or initiative > 5 or roll < 0 or roll > 9: return {}
	if roll in PANIC[initiative] or (is_us and not command and roll in RED[initiative]):
		return {"turns": 0, "panic": true, "red": roll in RED[initiative]}
	var turns := 2 if roll in TWO_TURNS[initiative] else 1
	if wounded: turns = mini(turns, 1)
	return {"turns": turns, "panic": false, "red": roll in RED[initiative]}

static func assign_turns(squad: Array, enemies: Array, awareness: Dictionary, us_die: int, german_die: int, forced_advantage: String = "roll", german_two_turns: Array = [], us_two_turns: bool = false) -> Dictionary:
	if us_die < 0 or us_die > 9 or german_die < 0 or german_die > 9: return {}
	if forced_advantage not in ["roll", "us", "de"]: return {}
	var advantage := forced_advantage if forced_advantage != "roll" else "us" if us_die > german_die else "de"
	var us: Dictionary = {}
	var german: Dictionary = {}
	for unit in squad:
		if unit.get("status", "") != "active": continue
		var id: String = str(unit.id)
		if not bool(awareness.get(id, false)):
			us[id] = {"turns":0,"panic":false,"unaware":true}
			continue
		var assigned := turn_result(int(unit.initiative),us_die,true,in_command(unit,squad),bool(unit.get("wounded", false)))
		if assigned.is_empty(): return {}
		if us_two_turns and not assigned.panic:
			assigned.turns = 1 if bool(unit.get("wounded", false)) else 2
		assigned.unaware = false
		us[id] = assigned
	for unit in enemies:
		if unit.get("status", "active") != "active": continue
		var id: String = str(unit.id)
		var assigned := turn_result(int(unit.initiative),german_die,false,false,bool(unit.get("wounded", false)))
		if assigned.is_empty(): return {}
		if id in german_two_turns:
			assigned.turns = 1 if bool(unit.get("wounded", false)) else 2
			assigned.panic = false
		german[id] = assigned
	var order: Array[Dictionary] = []
	for turns in [2,1]:
		for side in [advantage,"de" if advantage == "us" else "us"]:
			var ids: Array[String] = []
			var group: Dictionary = us if side == "us" else german
			for id in group:
				if int(group[id].turns) == turns: ids.append(id)
			if side == "de":
				ids.sort_custom(func(a: String,b: String):
					var letter_a := ""
					var letter_b := ""
					for enemy in enemies:
						if str(enemy.id) == a: letter_a = str(enemy.get("letter", ""))
						if str(enemy.id) == b: letter_b = str(enemy.get("letter", ""))
					return letter_a < letter_b)
			order.append({"side":side,"turns":turns,"ids":ids})
	return {"advantage":advantage,"us_die":us_die,"german_die":german_die,"us":us,"german":german,"order":order}
