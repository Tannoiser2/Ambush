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
		var same_hex: bool = unit.get("hex", "") != "" and other.get("hex", "") == unit.get("hex", "")
		var nearby: bool = unit.get("hex", "") != "" and other.get("hex", "") != "" and Hex.distance(str(unit.hex), str(other.hex)) <= 2
		if same_hex or (nearby and (bool(unit.get("commander", false)) or bool(other.get("commander", false)))):
			rating += int(other.get("initiative", 0))
	return rating >= 5

static func turn_result(initiative: int, roll: int, is_us: bool, command: bool, wounded: bool) -> Dictionary:
	if initiative < 0 or initiative > 5 or roll < 0 or roll > 9: return {}
	if roll in PANIC[initiative] or (is_us and not command and roll in RED[initiative]):
		return {"turns": 0, "panic": true, "red": roll in RED[initiative]}
	var turns := 2 if roll in TWO_TURNS[initiative] else 1
	if wounded: turns = mini(turns, 1)
	return {"turns": turns, "panic": false, "red": roll in RED[initiative]}
