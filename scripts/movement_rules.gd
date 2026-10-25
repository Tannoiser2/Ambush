class_name AmbushMovementRules
extends RefCounted
## Soldier costs from the original Player Aid Screen, Movement Point Cost Chart.
const Hex = preload("res://scripts/hex_grid.gd")
const COST := {"clear":1,"road":1,"cover":1,"rough":2,"brush":2,
 "woods":2,"crater":1,"rubble":2,"stream":2}

static func cost(a: String, b: String, stance: String, mpa: int,
 hexes: Dictionary, hexsides: Dictionary) -> Dictionary:
 if not Hex.valid(b) or (a != "" and (not Hex.valid(a) or Hex.distance(a,b) != 1)):
  return {"status":"invalid","reason":"Serve un esagono adiacente valido."}
 if stance == "prone": return {"status":"invalid","reason":"Un soldato prono non può muoversi."}
 if not hexes.has(b) or (a != "" and not hexes.has(a)):
  return {"status":"unknown","reason":"Terreno non catalogato."}
 var target: Dictionary = hexes[b]
 var terrain: String = str(target.get("terrain",""))
 if terrain.ends_with("_building"):
  return {"status":"unknown","reason":"Lato d'ingresso e apertura dell'edificio non verificati."}
 if terrain == "stream" and stance != "standing":
  return {"status":"invalid","reason":"Il ruscello si attraversa solo in piedi."}
 if not COST.has(terrain):
  return {"status":"unknown","reason":"Costo del terreno non verificato."}
 var points: int = int(COST[terrain])
 if a != "":
  var key: String = a + "|" + b if a < b else b + "|" + a
  var side: String = str(hexsides.get(key,""))
  if side == "":
   if bool(hexes[a].get("hexside_review_pending",true)) or bool(target.get("hexside_review_pending",true)):
    return {"status":"unknown","reason":"Lato d'esagono non ancora verificato."}
  elif side == "crest": points += 1
  elif side == "embankment":
   var from_level := int(hexes[a].get("elevation",1) if hexes[a].get("elevation") != null else 1)
   var to_level := int(target.get("elevation",1) if target.get("elevation") != null else 1)
   if to_level > from_level: points += 1
  elif side != "none":
   return {"status":"unknown","reason":"Costo del lato d'esagono non verificato."}
 if stance == "crouching": points = mpa
 if points > mpa: return {"status":"invalid","reason":"Punti movimento insufficienti."}
 return {"status":"legal","points":points,"reason":"Costo dalla tabella originale."}
