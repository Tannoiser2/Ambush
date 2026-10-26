class_name Esagoni
extends RefCounted
## Geometria della griglia della mappa A: colonne A–Y, righe 1–19, esagoni con lato piatto
## in alto e colonne dispari (B, D, …) spostate di mezzo esagono verso il basso.

const COLONNE := 25
const RIGHE := 19
const SQRT3 := 1.7320508075688772

static var _tutti: Array[String] = []
static var _centri: Dictionary = {}
static var _vicini: Dictionary = {}

static func valido(id: String) -> bool:
	if id.length() < 2 or id.length() > 3:
		return false
	var c := id.unicode_at(0)
	if c < 65 or c > 89:
		return false
	var r := id.substr(1)
	return r.is_valid_int() and int(r) >= 1 and int(r) <= RIGHE and str(int(r)) == r

static func colonna(id: String) -> int:
	return id.unicode_at(0) - 65

static func riga(id: String) -> int:
	return int(id.substr(1))

static func da(col: int, rig: int) -> String:
	if col < 0 or col >= COLONNE or rig < 1 or rig > RIGHE:
		return ""
	return "%s%d" % [char(65 + col), rig]

static func tutti() -> Array[String]:
	if _tutti.is_empty():
		for c in COLONNE:
			for r in range(1, RIGHE + 1):
				_tutti.append(da(c, r))
	return _tutti

## Numero dell’esagono come nel regolamento (M18 = 1318): ordina per colonna, poi riga.
static func numero(id: String) -> int:
	return (colonna(id) + 1) * 100 + riga(id)

static func cubo(id: String) -> Vector3i:
	var q := colonna(id)
	var r := riga(id) - 1 - (q - (q & 1)) / 2
	return Vector3i(q, r, -q - r)

static func distanza(a: String, b: String) -> int:
	if a == "" or b == "" or not valido(a) or not valido(b):
		return 999
	var d := cubo(a) - cubo(b)
	return maxi(absi(d.x), maxi(absi(d.y), absi(d.z)))

## Sei direzioni in senso orario a partire da nord.
static func vicino(id: String, dir: int) -> String:
	var lista = _vicini.get(id)
	if lista == null:
		lista = []
		for d in 6:
			lista.append(_vicino_calc(id, d))
		_vicini[id] = lista
	return lista[dir]

static func _vicino_calc(id: String, dir: int) -> String:
	var q := colonna(id)
	var r := riga(id)
	var pari := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
	var dispari := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
	var d: Vector2i = (dispari if q & 1 else pari)[dir]
	return da(q + d.x, r + d.y)

static func vicini(id: String) -> Array[String]:
	var out: Array[String] = []
	for d in 6:
		var v := vicino(id, d)
		if v != "":
			out.append(v)
	return out

static func adiacenti(a: String, b: String) -> bool:
	return distanza(a, b) == 1

static func direzione(a: String, b: String) -> int:
	for d in 6:
		if vicino(a, d) == b:
			return d
	return -1

static func lato(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

## Centro in unità astratte (raggio esagono = 1).
static func centro(id: String) -> Vector2:
	var c = _centri.get(id)
	if c != null:
		return c
	var v := _centro_calc(id)
	_centri[id] = v
	return v

static func _centro_calc(id: String) -> Vector2:
	var q := colonna(id)
	var r := riga(id) - 1
	return Vector2(1.5 * q, SQRT3 * (r + 0.5 * float(q & 1)))

## Vertici dell’esagono (lato piatto in alto): angoli 0°, 60°, … 300°.
static func vertici(id: String, scala := 1.0) -> PackedVector2Array:
	var c := centro(id)
	var out := PackedVector2Array()
	for i in 6:
		var ang := deg_to_rad(60.0 * i)
		out.append(c + Vector2(cos(ang), sin(ang)) * scala)
	return out

## Lato in comune tra esagono e il vicino in direzione dir: coppia di vertici.
## Direzioni: 0 N (vertici 4–5), 1 NE (5–0), 2 SE (0–1), 3 S (1–2), 4 SO (2–3), 5 NO (3–4).
static func segmento_lato(id: String, dir: int) -> PackedVector2Array:
	var v := vertici(id)
	var coppie := [[4, 5], [5, 0], [0, 1], [1, 2], [2, 3], [3, 4]]
	return PackedVector2Array([v[coppie[dir][0]], v[coppie[dir][1]]])

## Esagono che contiene un punto (unità astratte).
static func a_punto(p: Vector2) -> String:
	var q := roundi(p.x / 1.5)
	var migliore := ""
	var dmin := 1e9
	for dq in [-1, 0, 1]:
		var c: int = q + dq
		if c < 0 or c >= COLONNE:
			continue
		var r0 := roundi(p.y / SQRT3 - 0.5 * float(c & 1)) + 1
		for dr in [-1, 0, 1]:
			var id := da(c, r0 + dr)
			if id == "":
				continue
			var d := centro(id).distance_squared_to(p)
			if d < dmin:
				dmin = d
				migliore = id
	return migliore if dmin <= 1.05 else ""
