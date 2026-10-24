class_name AmbushHex
extends RefCounted
## Odd columns are shifted down: A1 and B1 share an edge; B1 and C2 share an edge.
static func valid(id: String) -> bool:
	if id.length() < 2 or id.length() > 3: return false
	if id.unicode_at(0) < 65 or id.unicode_at(0) > 89: return false
	var row := id.substr(1)
	return row.is_valid_int() and int(row) >= 1 and int(row) <= 19 and str(int(row)) == row
static func is_entry(id: String) -> bool:
	return valid(id) and id.unicode_at(0) <= 74 and int(id.substr(1)) == 1
static func cube(id: String) -> Vector3i:
	var q := id.unicode_at(0)-65
	var r := int(id.substr(1))-1-(q-(q&1))/2
	return Vector3i(q,r,-q-r)
static func distance(a: String,b: String) -> int:
	if not valid(a) or not valid(b): return 999
	var d := cube(a)-cube(b)
	return maxi(absi(d.x),maxi(absi(d.y),absi(d.z)))
static func center(id: String) -> Vector2:
	var q := id.unicode_at(0)-65
	var row := int(id.substr(1))-1
	# Original image: 8800×6400. Centers measured against A1/A19/Y1.
	return Vector2(307.0 + q*270.8, 272.0 + row*314.0 + (q&1)*157.0)
