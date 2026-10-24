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
  if id != a and id != b and Hex.valid(id): result.append(id)
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
   if bool(blocking.get(id,false)):
    path_clear = false
    break
  if path_clear: return true
 return false
