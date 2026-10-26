class_name Terreno
extends RefCounted
## Terreno della mappa A: tipi, quote, lati speciali, costi di movimento e linea di vista (regola 8).

const E = preload("res://scripts/motore/esagoni.gd")

const BLOCCANTI := ["woods", "brush", "rough", "rubble"]
const SCOPERTI := ["clear", "road", "stream", "bridge", "ford"]
const EDIFICI := ["stone_building", "wood_building"]
const NOMI := {
	"clear": "terreno libero", "road": "strada", "cover": "copertura", "brush": "macchia",
	"woods": "bosco", "rough": "terreno accidentato", "stream": "ruscello", "bridge": "ponte",
	"stone_building": "edificio in pietra", "wood_building": "edificio in legno",
	"crater": "cratere", "rubble": "macerie",
}

var esagoni: Dictionary = {}
var lati: Dictionary = {}
## Modifiche durante la partita (crateri, macerie): esagono → tipo.
var modifiche: Dictionary = {}
var _cache_los: Dictionary = {}

var alture: Array = []

func _init(percorso := "res://data/mappa_a.json") -> void:
	var dati: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	esagoni = dati.esagoni
	lati = dati.lati
	alture = dati.get("alture_obiettivo", [])

func imposta_modifiche(m: Dictionary) -> void:
	modifiche = m
	_cache_los.clear()

func tipo(h: String) -> String:
	if modifiche.has(h):
		return str(modifiche[h])
	return str(esagoni.get(h, {}).get("t", "clear"))

func nome_tipo(h: String) -> String:
	var t := tipo(h)
	if t == "stream" and ponte(h):
		return "ponte sul ruscello"
	return NOMI.get(t, t)

func quota(h: String) -> int:
	return int(esagoni.get(h, {}).get("q", 1))

func ponte(h: String) -> bool:
	return bool(esagoni.get(h, {}).get("ponte", false)) and not modifiche.has(h)

func edificio(h: String) -> bool:
	return tipo(h) in EDIFICI

func scoperto(h: String) -> bool:
	return tipo(h) in SCOPERTI

func bloccante(h: String) -> bool:
	return tipo(h) in BLOCCANTI

## Esagoni degli estremi del ponte: entrando da qui si è sul ponte.
func capi_ponte(h: String) -> Array[String]:
	var out: Array[String] = []
	if not ponte(h):
		return out
	for v in E.vicini(h):
		if tipo(v) == "road":
			out.append(v)
	return out

func tipo_lato(a: String, b: String) -> String:
	var k := E.lato(a, b)
	if lati.has(k):
		return str(lati[k])
	# Muro: lato tra un edificio e un esagono che non fa parte dello stesso edificio.
	if edificio(a) != edificio(b):
		return "wall"
	return ""

func apertura(a: String, b: String) -> bool:
	return tipo_lato(a, b) in ["door", "window"]

## Costo in punti movimento per un soldato IN PIEDI che entra in b da a.
## Restituisce -1 se l’ingresso è vietato.
func costo_movimento(a: String, b: String) -> int:
	if not E.adiacenti(a, b):
		return -1
	var tl := tipo_lato(a, b)
	if tl == "wall":
		return -1
	var t := tipo(b)
	var c := 1
	match t:
		"rough", "brush", "woods", "rubble":
			c = 2
		"stream":
			c = 1 if (ponte(b) and a in capi_ponte(b)) else 2
	if tl in ["door", "window"]:
		c += 1
	elif tl == "crest":
		c += 1
	elif tl == "embankment" and quota(b) > quota(a):
		c += 1
	return c

## Il soldato accovacciato striscia di un solo esagono: vietato oltre i muri e nel ruscello (si entra solo in piedi).
func strisciare_possibile(a: String, b: String) -> bool:
	if costo_movimento(a, b) < 0:
		return false
	if tipo(b) == "stream" and not (ponte(b) and a in capi_ponte(b)):
		return false
	return true

# ------------------------------------------------------------------ linea di vista
func _interseca_segmenti(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var r := p2 - p1
	var s := q2 - q1
	var den := r.cross(s)
	if absf(den) < 1e-9:
		return false
	var t := (q1 - p1).cross(s) / den
	var u := (q1 - p1).cross(r) / den
	return t > 1e-6 and t < 1.0 - 1e-6 and u > 0.02 and u < 0.98

func _collineare_sovrapposto(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
	var r := p2 - p1
	if absf(r.cross(q1 - p1)) > 1e-4 * r.length() or absf(r.cross(q2 - p1)) > 1e-4 * r.length():
		return false
	var l2 := r.length_squared()
	var t1 := (q1 - p1).dot(r) / l2
	var t2 := (q2 - p1).dot(r) / l2
	return maxf(t1, t2) > 1e-6 and minf(t1, t2) < 1.0 - 1e-6

func _attraversa_esagono(p1: Vector2, p2: Vector2, h: String) -> bool:
	# Interno dell’esagono leggermente ristretto: chi lo sfiora lungo un lato non lo attraversa.
	var c := E.centro(h)
	# distanza del centro dal segmento
	var seg := p2 - p1
	var t := clampf((c - p1).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var d := (p1 + seg * t).distance_to(c)
	if d > 1.0:
		return false
	if d < 0.86:
		return true
	var v := E.vertici(h, 0.995)
	for i in 6:
		if _interseca_segmenti(p1, p2, v[i], v[(i + 1) % 6]):
			return true
	return false

## Esagoni attraversati e lati incrociati dalla linea tra i centri di a e b.
func percorso_vista(a: String, b: String) -> Dictionary:
	var p1 := E.centro(a)
	var p2 := E.centro(b)
	var attraversati: Array[String] = []
	var lati_incrociati: Array[String] = []
	var bisecati: Array = []
	var seg := p2 - p1
	var l2 := seg.length_squared()
	var c0 := mini(E.colonna(a), E.colonna(b)) - 1
	var c1 := maxi(E.colonna(a), E.colonna(b)) + 1
	var r0 := mini(E.riga(a), E.riga(b)) - 1
	var r1 := maxi(E.riga(a), E.riga(b)) + 1
	var candidati: Array[String] = []
	for c in range(maxi(c0, 0), mini(c1, E.COLONNE - 1) + 1):
		for r in range(maxi(r0, 1), mini(r1, E.RIGHE) + 1):
			var h := E.da(c, r)
			var cc := E.centro(h)
			var t := clampf((cc - p1).dot(seg) / l2, 0.0, 1.0)
			var d := (p1 + seg * t).distance_to(cc)
			if d > 1.05:
				continue
			candidati.append(h)
			if h != a and h != b and _attraversa_esagono(p1, p2, h):
				attraversati.append(h)
	var visti := {}
	for h in candidati:
		for d in 6:
			var n := E.vicino(h, d)
			if n == "":
				continue
			var k := E.lato(h, n)
			if visti.has(k):
				continue
			visti[k] = true
			var s := E.segmento_lato(h, d)
			if _interseca_segmenti(p1, p2, s[0], s[1]):
				lati_incrociati.append(k)
			elif h != a and h != b and n != a and n != b and _collineare_sovrapposto(p1, p2, s[0], s[1]):
				bisecati.append([h, n])
	return {"esagoni": attraversati, "lati": lati_incrociati, "bisecati": bisecati}

func _blocca_esagono(h: String, a: String, b: String) -> String:
	var qa := quota(a)
	var qb := quota(b)
	var qh := quota(h)
	var basso := mini(qa, qb)
	var alto := maxi(qa, qb)
	if qh > alto:
		return "il terreno in %s è più alto di entrambi" % h
	if qh < basso:
		return ""
	if bloccante(h):
		if qa == qb:
			if qh >= qa:
				return "%s (%s) blocca la vista" % [NOMI.get(tipo(h), tipo(h)), h]
		else:
			if (E.adiacenti(h, a) and qh >= qa) or (E.adiacenti(h, b) and qh >= qb):
				return "%s (%s) adiacente blocca la vista" % [NOMI.get(tipo(h), tipo(h)), h]
	elif edificio(h):
		if qa == qb:
			return "l’edificio in %s blocca la vista" % h
		var basso_h := a if qa < qb else b
		var alto_h := b if qa < qb else a
		if E.distanza(h, basso_h) <= E.distanza(h, alto_h):
			return "l’edificio in %s blocca la vista" % h
	return ""

## Lato dell’esagono h attraversato dalla linea verso l’altro estremo (per edifici).
func _lato_di_uscita(h: String, altro: String) -> Array[String]:
	var p1 := E.centro(h)
	var p2 := E.centro(altro)
	var out: Array[String] = []
	for d in 6:
		var n := E.vicino(h, d)
		if n == "":
			continue
		var s := E.segmento_lato(h, d)
		var r := p2 - p1
		var den := r.cross(s[1] - s[0])
		if absf(den) < 1e-9:
			continue
		var t := (s[0] - p1).cross(s[1] - s[0]) / den
		var u := (s[0] - p1).cross(r) / den
		if t > 0.0 and u >= -0.01 and u <= 1.01:
			out.append(n)
	return out

## Verifica la vista da/verso un soldato in un edificio (regola 8/2, edifici).
func _vista_edificio(h: String, altro: String, postura_h: String, postura_altro: String) -> String:
	if not edificio(h):
		return ""
	if edificio(altro) and E.adiacenti(h, altro) and tipo_lato(h, altro) == "":
		return ""  # stesso edificio, esagoni interni contigui
	var uscite := _lato_di_uscita(h, altro)
	var ok := false
	for n in uscite:
		var tl := tipo_lato(h, n)
		if tl == "door":
			ok = true
		elif tl == "window":
			if postura_h == "prone":
				continue
			if postura_h == "crouching" and n == altro and postura_altro in ["crouching", "prone"]:
				continue
			ok = true
		elif tl == "" and edificio(n):
			ok = true
	if not ok:
		return "i muri di %s impediscono la vista" % h
	return ""

## Linea di vista tra due esagoni con le posture degli osservatori. Restituisce {ok, motivo}.
func vista(a: String, b: String, postura_a := "standing", postura_b := "standing") -> Dictionary:
	if a == "" or b == "" or not E.valido(a) or not E.valido(b):
		return {"ok": false, "motivo": "fuori mappa"}
	if a == b:
		return {"ok": true, "motivo": ""}
	var chiave := "%s>%s>%s>%s" % [a, b, postura_a, postura_b]
	if _cache_los.has(chiave):
		return _cache_los[chiave]
	var r := _calcola_vista(a, b, postura_a, postura_b)
	_cache_los[chiave] = r
	return r

func _calcola_vista(a: String, b: String, postura_a: String, postura_b: String) -> Dictionary:
	var m := _vista_edificio(a, b, postura_a, postura_b)
	if m == "":
		m = _vista_edificio(b, a, postura_b, postura_a)
	if m != "":
		return {"ok": false, "motivo": m}
	if E.adiacenti(a, b):
		var tl := tipo_lato(a, b)
		if tl == "crest":
			return {"ok": false, "motivo": "una cresta separa i due esagoni"}
		return {"ok": true, "motivo": ""}
	var p := percorso_vista(a, b)
	for h in p.esagoni:
		var mot := _blocca_esagono(h, a, b)
		if mot != "":
			return {"ok": false, "motivo": mot}
	for coppia in p.bisecati:
		var m1 := _blocca_esagono(coppia[0], a, b)
		var m2 := _blocca_esagono(coppia[1], a, b)
		if m1 != "" and m2 != "":
			return {"ok": false, "motivo": m1}
	var qa := quota(a)
	var qb := quota(b)
	for k in p.lati:
		var tl := str(lati.get(k, ""))
		if tl == "crest":
			return {"ok": false, "motivo": "una cresta blocca la vista"}
		if tl == "embankment" and qa != qb:
			var parti: PackedStringArray = k.split("|")
			var livello := maxi(quota(parti[0]), quota(parti[1]))
			var alto_h := a if qa > qb else b
			if livello > mini(qa, qb) and not (alto_h in [parti[0], parti[1]]):
				return {"ok": false, "motivo": "una scarpata blocca la vista"}
	return {"ok": true, "motivo": ""}

func vede(a: String, b: String, postura_a := "standing", postura_b := "standing") -> bool:
	return bool(vista(a, b, postura_a, postura_b).ok)
