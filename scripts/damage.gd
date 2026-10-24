class_name AmbushDamage
extends RefCounted
## Weapons Chart: exploding grenade indoors, damage die read from 0 to 9.
const GRENADE_INDOORS := ["P", "P", "P", "X", "X", "W", "W", "I", "I", "K"]

static func grenade_indoors(roll: int, prone: bool) -> String:
	assert(roll >= 0 and roll <= 9)
	var result: String = GRENADE_INDOORS[roll]
	return "P" if result == "X" and prone else "W" if result == "X" else result
