class_name AmbushLosGeometry
extends RefCounted
## Geometric hex line only; terrain, elevations, crests and apertures are separate rules.
const Hex = preload("res://scripts/hex_grid.gd")

static func _cube_round(q: float, r: float, s: float) -> Vector3i:
 var qi := roundi(q)
 var ri := roundi(r)
 var si := roundi(s)
 var dq := absf(qi-q)
 var dr := absf(ri-r)
 var ds := absf(si-s)
 if dq > dr and dq > ds: qi = -ri-si
 elif dr > ds: ri = -qi-si
 else: si = -qi-ri
 return Vector3i(qi,ri,si)

static func _id(c: Vector3i) -> String:
 var row := c.y + (c.x-(c.x&1))/2 + 1
 return String.chr(65+c.x) + str(row)

static func _path(a: String, b: String, bias: float) -> Array[String]:
 var result: Array[String] = []
 var ac := Hex.cube(a)
 var bc := Hex.cube(b)
 var steps := Hex.distance(a,b)
 if steps == 0: return []
 for i in range(steps+1):
  var t := float(i)/steps
  var c := _cube_round(lerpf(ac.x,bc.x,t)+bias,lerpf(ac.y,bc.y,t)+bias,lerpf(ac.z,bc.z,t)-2*bias)
  var id := _id(c)
  # Keep off-map intermediate hexes: dropping them could create a false clear LOS.
  if id != a and id != b: result.append(id)
 return result

static func alternative_intervening_hexes(a: String, b: String) -> Array:
 if not Hex.valid(a) or not Hex.valid(b): return []
 var left := _path(a,b,0.000001)
 var right := _path(a,b,-0.000001)
 return [left] if left == right else [left,right]

static func clear_at_same_elevation(a: String, b: String, blocking: Dictionary) -> bool:
 # Exact bisection has two paths: one unblocked side is sufficient (8/1).
 for path in alternative_intervening_hexes(a,b):
  var path_clear := true
  for id in path:
   if not Hex.valid(id) or bool(blocking.get(id,false)):
    path_clear = false
    break
  if path_clear: return true
 return false

static func evaluate_map_a(a: String, b: String, hexes: Dictionary, hexsides: Dictionary = {}) -> Dictionary:
 var forward: Dictionary=_evaluate_map_a_direction(a,b,hexes,hexsides)
 var reverse: Dictionary=_evaluate_map_a_direction(b,a,hexes,hexsides)
 if forward.status!=reverse.status:
  return {"status":"unknown","reason":"La geometria dei lati richiede revisione per una LOS simmetrica."}
 return forward

static func _evaluate_map_a_direction(a: String, b: String, hexes: Dictionary, hexsides: Dictionary) -> Dictionary:
 if not Hex.valid(a) or not Hex.valid(b): return {"status":"unknown","reason":"Esagono non valido."}
 if not hexes.has(a) or not hexes.has(b): return {"status":"unknown","reason":"Terreno non catalogato."}
 if a == b: return {"status":"clear","reason":"Stesso esagono."}
 var possible := alternative_intervening_hexes(a,b)
 if possible.size() == 2:
  var left: Array = possible[0]
  var right: Array = possible[1]
  for i in mini(left.size(),right.size()):
   if Hex.distance(str(left[i]),str(right[i])) == 1 and str(hexsides.get(_hexside_key(str(left[i]),str(right[i])),"")) == "crest":
    return {"status":"blocked","reason":"La LOS segue il lato di cresta fra %s e %s." % [left[i],right[i]]}
 var unknown := false
 var reasons: Array[String] = []
 for intervening in possible:
  var path: Array[String] = [a]
  path.append_array(intervening)
  path.append(b)
  var result := _evaluate_map_a_path(path,hexes,hexsides)
  if result.status == "clear": return result
  if result.status == "unknown": unknown = true
  reasons.append(str(result.reason))
 return {"status":"unknown" if unknown else "blocked", "reason":" / ".join(reasons)}

static func _hexside_key(a: String, b: String) -> String:
 return a + "|" + b if a < b else b + "|" + a

static func _is_building(hex: Dictionary) -> bool:
 return str(hex.get("terrain","" )).ends_with("_building") or str(hex.get("building","")) in ["wood","stone"]

static func _opening(hexsides: Dictionary,a: String,b: String) -> bool:
 return str(hexsides.get(_hexside_key(a,b),"")) in ["door","window"]

static func _evaluate_map_a_path(path: Array[String], hexes: Dictionary, hexsides: Dictionary) -> Dictionary:
 for id in path:
  if not hexes.has(id): return {"status":"unknown","reason":"Terreno non catalogato: " + id}
 for i in range(path.size()-1):
  if str(hexsides.get(_hexside_key(path[i],path[i+1]),"")) == "crest":
   return {"status":"blocked","reason":"Cresta fra %s e %s." % [path[i],path[i+1]]}
 var start: Dictionary = hexes[path.front()]
 var finish: Dictionary = hexes[path.back()]
 if path.size() == 2 and Hex.distance(path.front(),path.back()) == 1:
  var direct_side: String = str(hexsides.get(_hexside_key(path.front(),path.back()),""))
  if direct_side in ["door","window"]:
   return {"status":"clear","reason":"Apertura verificata nel lato dell'edificio."}
  if _is_building(start) or _is_building(finish):
   return {"status":"unknown","reason":"Parete dell'edificio senza apertura verificata."}
  if direct_side not in ["","none","embankment"]:
   return {"status":"unknown","reason":"Lato d'esagono non classificato."}
  if direct_side == "" and (bool(start.get("hexside_review_pending",true)) or bool(finish.get("hexside_review_pending",true))):
   return {"status":"unknown","reason":"Lato d'esagono da verificare."}
  return {"status":"clear","reason":"Esagoni adiacenti senza lato bloccante."}
 for i in path.size():
  if not _is_building(hexes[path[i]]): continue
  var has_entry: bool=i==0 or _opening(hexsides,path[i],path[i-1])
  var has_exit: bool=i==path.size()-1 or _opening(hexsides,path[i],path[i+1])
  if not has_entry or not has_exit:
   if i>0 and i<path.size()-1:
    return {"status":"blocked","reason":"Edificio senza aperture sulla LOS in %s." % path[i]}
   return {"status":"unknown","reason":"Apertura porta/finestra mancante o non verificata nell'edificio %s." % path[i]}
 if start.get("elevation") == null or finish.get("elevation") == null:
  return {"status":"unknown","reason":"Quota dell'esagono di partenza o arrivo non verificata."}
 var start_level := int(start.elevation)
 var finish_level := int(finish.elevation)
 var same_level := start_level == finish_level
 var lower := mini(start_level,finish_level)
 var higher := maxi(start_level,finish_level)
 var unresolved := ""
 for i in range(1,path.size()-1):
  var id: String = path[i]
  var terrain: Dictionary = hexes[id]
  if terrain.get("elevation") == null:
   unresolved = "Quota intermedia non verificata: " + id
   continue
  var level := int(terrain.elevation)
  if level > higher:
   return {"status":"blocked","reason":"Quota superiore in " + id}
  var kind := str(terrain.get("terrain", ""))
  var building: bool = _is_building(terrain)
  var building_open: bool=building and _opening(hexsides,path[i-1],id) and _opening(hexsides,id,path[i+1])
  if same_level and level >= start_level and (kind in ["woods","brush","rough","rubble"] or (kind in ["wood_building","stone_building"] and not building_open)):
   return {"status":"blocked","reason":"Terreno bloccante in " + id}
  if not same_level and kind in ["woods","brush","rough","rubble"]:
   if (i == 1 and level == start_level) or (i == path.size()-2 and level == finish_level):
    return {"status":"blocked","reason":"Terreno adiacente alla stessa quota in " + id}
  if not same_level and building and not building_open and level >= lower:
   var distance_low := i if start_level == lower else path.size()-1-i
   var distance_high := path.size()-1-i if start_level == lower else i
   if distance_low <= distance_high:
    return {"status":"blocked","reason":"Edificio vicino alla quota inferiore in " + id}
 if unresolved != "": return {"status":"unknown","reason":unresolved}
 for i in range(path.size()-1):
  var side: String = str(hexsides.get(_hexside_key(path[i],path[i+1]),""))
  if side == "embankment" and not same_level:
   var side_height := maxi(int(hexes[path[i]].elevation),int(hexes[path[i+1]].elevation))
   var adjacent_high: bool = path[i] == (path.front() if start_level == higher else path.back()) or path[i+1] == (path.front() if start_level == higher else path.back())
   if side_height > lower and not adjacent_high:
    return {"status":"blocked","reason":"Scarpata fra %s e %s." % [path[i],path[i+1]]}
  if side == "":
   if bool(hexes[path[i]].get("hexside_review_pending",true)) or bool(hexes[path[i+1]].get("hexside_review_pending",true)):
    return {"status":"unknown","reason":"Lato d'esagono da verificare fra %s e %s." % [path[i],path[i+1]]}
  elif side not in ["none","embankment","door","window"]:
   return {"status":"unknown","reason":"Lato d'esagono da verificare fra %s e %s." % [path[i],path[i+1]]}
 return {"status":"clear","reason":"Terreno e lati verificati per questa LOS."}
