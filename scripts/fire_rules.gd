class_name AmbushFireRules
extends RefCounted
## Pure fire-table lookup. The caller must establish legal target and clear LOS first.
const LOCATION := {
 "open": {"standing":1,"crouching":0,"prone":-1},
 "cover": {"standing":0,"crouching":-1,"prone":-3},
 "brush": {"standing":0,"crouching":-1,"prone":-2},
 "rough": {"standing":-1,"crouching":-2,"prone":-3},
 "crater": {"standing":-1,"crouching":-2,"prone":-3},
 "rubble": {"standing":-1,"crouching":-2,"prone":-3},
 "woods": {"standing":-2,"crouching":-3,"prone":-4},
 "interior_aperture_distant": {"standing":-2,"crouching":-4},
 "interior_aperture_adjacent_or_closed": {"standing":-1,"crouching":-2,"prone":-3}
}
const NAMES := {
 "Pistola":"pistol", "Pistola Luger":"pistol", "Carabina":"carbine",
 "Fucile a otturatore":"bolt_rifle", "Fucile semiautomatico":"semi_auto_rifle",
 "Fucile a otturatore con ottica":"scoped_bolt_rifle", "Mitra":"submachinegun",
 "Pistola mitragliatrice":"machine_pistol", "Fucile automatico":"automatic_rifle"
}
var weapons: Dictionary
func _init() -> void:
 weapons = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons_base.json")).weapons

func weapon(name: String) -> Dictionary:
 return weapons.get(NAMES.get(name,name),{})

func base_chance(name: String, distance: int) -> int:
 var w := weapon(name)
 if w.is_empty() or distance < 0: return -1
 if distance == 0: return 8
 if distance == 1: return 7
 if distance > int(w.range[2]): return -1
 if distance <= int(w.range[0]): return 5
 if distance <= int(w.range[1]): return 4
 return 3

func hit_chance(name: String, distance: int, ws: int, terrain: String, stance: String, snap: bool=false, wounded: bool=false, additional_targets: int=0, inside_car: bool=false, target_wall: bool=false) -> int:
 var w := weapon(name)
 if w.is_empty() or not LOCATION.has(terrain) or not LOCATION[terrain].has(stance): return -1
 var base := base_chance(name,distance)
 if base < 0: return -1
 var chance := base + ws + int(LOCATION[terrain][stance])
 if snap: chance -= 2
 if wounded: chance -= 1
 if inside_car: chance -= 2
 if target_wall: chance += 4
 if bool(w.automatic) and not snap: chance += maxi(0,additional_targets)
 return clampi(chance,0,8)

func damage(name: String, roll: int) -> String:
 var w := weapon(name)
 if w.is_empty() or roll < 0 or roll > 9: return ""
 return str(w.damage[roll])

func jammed(name: String, percentile: int, snap: bool) -> bool:
 var w := weapon(name)
 if w.is_empty() or percentile < 0 or percentile > 99: return false
 return percentile <= int(w.jam_snap if snap else w.jam_aimed)

func spent_clip(name: String, percentile: int) -> bool:
 var w := weapon(name)
 if w.is_empty() or percentile < 0 or percentile > 99: return false
 return percentile <= int(w.ammo)

func resolve_fire(name: String, distance: int, ws: int, terrain: String, stance: String, snap: bool, wounded: bool, jam_roll: int, hit_roll: int, damage_roll: int, ammo_roll: int) -> Dictionary:
 var chance := hit_chance(name,distance,ws,terrain,stance,snap,wounded)
 if chance < 0 or jam_roll < 0 or jam_roll > 99 or hit_roll < 0 or hit_roll > 9 or damage_roll < 0 or damage_roll > 9 or ammo_roll < 0 or ammo_roll > 99: return {}
 if jammed(name,jam_roll,snap): return {"result":"jammed","chance":chance,"damage":"","clip_spent":false}
 var hit := hit_roll == 0 or (hit_roll != 9 and hit_roll <= chance)
 return {"result":"hit" if hit else "miss", "chance":chance, "damage":damage(name,damage_roll) if hit else "", "clip_spent":spent_clip(name,ammo_roll)}
