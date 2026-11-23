extends RefCounted
const E = preload("res://scripts/motore/esagoni.gd")
## Paragrafi d’azione dei tedeschi propri di Purple Heart (quelli identici al gioco base usano tedeschi.gd).

var t  # tedeschi.gd
var _sbarca := false

func _init(tedeschi) -> void:
	t = tedeschi

func _ph():
	return t.p.ph

## Esegue il paragrafo n se è di Purple Heart; false per lasciarlo al gioco base.
func esegui(n: int) -> bool:
	var g: Dictionary = t._g
	match n:
		509:
			if str(g.get("barca", "")) != "":
				esegui(513)
			else:
				var d: int = t.p.d10()
				var x: int = 868 if d <= 2 else (867 if d <= 5 else (866 if d == 6 else (865 if d == 7 else (864 if d == 8 else 800))))
				t.p._log("dado", "Dado %d: il %s esegue %d." % [d, t.p.nome(g), x])
				t.esegui(x)
		513:
			var bid := str(g.get("barca", ""))
			if bid != "" and bool(_ph()._st().barche.get(bid, {}).get("danneggiata", false)):
				t.imposta_reazione({"g": g.id}, "C")
			elif bid != "" and _ph().occupanti(bid).size() <= 1:
				t.imposta_reazione({"g": g.id}, "A")
			else:
				esegui(522)
		522:
			_muovi_barca(g)
		531:
			if str(g.get("barca", "")) != "":
				sbarca(g)
			else:
				var b: Array = t.bersagli(g)
				if b.size() >= 3:
					t.esegui(801)
				elif not b.is_empty():
					if t._alzati():
						t._tiri_rapidi()
						t._mp = int(t.p.effettivo_mpa(g)) / 2
						t._muovi_rapido(false)
						t._prono_se_libero()
				else:
					t.esegui(868)
		538:
			if str(g.get("barca", "")) != "":
				sbarca(g)
			elif int(t.p.s.condizione) <= 3:
				esegui(549)
			else:
				esegui(556)
		549:
			var b2: Array = t.bersagli(g)
			if b2.size() >= 3:
				t.esegui(801)
			elif not b2.is_empty():
				t._tiri_rapidi()
				t._mp = int(t.p.effettivo_mpa(g)) / 2
				t._muovi_rapido(false)
				t._prono_se_libero()
			else:
				t.esegui(868)
		556:
			if _altro_tedesco_in_vista(g):
				t.esegui(866)
			else:
				t._arrenditi()
		576:
			var qui: Array = t.p.unita_in(g.hex, "us").filter(func(a): return t.p.attivo(a))
			if not qui.is_empty():
				t._assalta(qui[0])
			elif t.p.terreno.edificio(g.hex):
				t.esegui(816)
			else:
				t.esegui(868)
		_:
			return false
	return true

func _altro_tedesco_in_vista(g: Dictionary) -> bool:
	for x in t.p.tedeschi_attivi():
		if x.id != g.id and t.p.in_mappa(x) and t.p.terreno.vede(g.hex, x.hex):
			return true
	return false

func barca_gia_mossa(g: Dictionary) -> bool:
	var bid := str(g.get("barca", ""))
	if bid == "":
		return false
	return str(_ph()._st().barche[bid].get("mossa", "")) == _turno_corrente()

func _turno_corrente() -> String:
	var r: Dictionary = t.p.s.get("round", {})
	return "%d-%s" % [int(r.get("n", 0)), str(r.get("slot_azione", ""))]

## 522: il battello si muove (lento 4 esagoni, veloce 6) seguendo i riferimenti della carta.
func _muovi_barca(g: Dictionary) -> void:
	var bid := str(g.get("barca", ""))
	if bid == "":
		t.esegui(868)
		return
	if barca_gia_mossa(g):
		t.esegui(801)
		return
	var occ: Array = _ph().occupanti(bid)
	if occ.size() < 2:
		t.p._log("tedesco", "Il battello non si muove: a bordo c’è un solo tedesco.")
		return
	var minacciati: bool = bool(_ph()._st().barche[bid].get("colpita", false)) or not t.bersagli(g).is_empty()
	var veloce: bool = minacciati and occ.size() >= 4
	_ph()._st().barche[bid].mossa = _turno_corrente()
	t._mp = 6 if veloce else 4
	t.p._log("tedesco", "Il battello d’assalto parte %s." % ("veloce" if veloce else "lento"))
	_sbarca = false
	var passi := 0
	while passi < 8 and t._mp > 0 and str(g.get("barca", "")) == bid and t.p.in_mappa(g):
		passi += 1
		var rif: String = t.p.movimento_rosso(_ph()._st().barche[bid].hex)
		if rif == "" or rif == "USCITA":
			break
		if rif.is_valid_int() and rif.length() == 3:
			var prima: String = _ph()._st().barche[bid].hex
			t.p.leggi(rif, {"g": g.id, "hex": prima})
			if _ph()._st().barche[bid].hex == prima:
				break
		else:
			if t.p.terreno.tipo(rif) in ["stream", "water"]:
				_ph().sposta_barca(bid, rif)
				t._mp -= 1
			else:
				break
	t.ferma()

## «Sbarca»: il tedesco scende nell’esagono indicato dal paragrafo di movimento del battello.
func sbarca(g: Dictionary) -> void:
	var bid := str(g.get("barca", ""))
	var h: String = _ph()._st().barche[bid].hex
	var rif: String = t.p.movimento_rosso(h)
	_sbarca = true
	if rif.is_valid_int() and rif.length() == 3:
		t.p.leggi(rif, {"g": g.id, "hex": h})
	elif rif != "" and rif != "USCITA":
		_scendi(g, rif)
	_sbarca = false
	t.ferma()

func _scendi(g: Dictionary, h: String) -> void:
	var da: String = g.hex
	g.erase("barca")
	g.hex_prec = da
	g.hex = h
	g.postura = "prone"
	t.p._log("tedesco", "Il %s sbarca in %s e si butta a terra." % [t.p.nome(g), h])
	t.p._fx("muovi", {"ids": [g.id], "da": da, "a": h})

## Op «barca» dei paragrafi di movimento del fiume: {sbarco: esagono, barca: esagono, solo: [numeri], resta: bool}.
func barca(o: Dictionary, ctx: Dictionary) -> void:
	var g: Dictionary = t.p.u(ctx.get("g", ""))
	if g.is_empty():
		return
	var bid := str(g.get("barca", ""))
	if bid == "":
		# Un tedesco a terra che legge un riferimento del fiume: entra nell’esagono di sbarco.
		if str(o.get("sbarco", "")) != "":
			t.entra_da_paragrafo(ctx, str(o.sbarco))
		return
	var obbligato: bool = int(g.num) in o.get("solo", [])
	if _sbarca or obbligato:
		if obbligato and not _sbarca and t.bersagli(g).size() >= 2:
			t.esegui(801)
			return
		_scendi(g, str(o.sbarco))
		t.ferma()
		return
	if str(o.get("barca", "")) != "":
		_ph().sposta_barca(bid, str(o.barca))
		t._mp -= 1
