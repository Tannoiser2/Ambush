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
		613, 626:
			var vg: Dictionary = t.p.veicoli.di(g)
			var nb: int = t.bersagli(g).size()
			if vg.is_empty() or not t.p.veicoli.attivo(vg):
				esegui(620)
			elif bool(vg.get("bersagliato", false)) or vg.stato != "attivo":
				esegui(620)
			elif n == 613:
				t.esegui(620 if nb >= 3 else (828 if nb > 0 else 814))
			else:
				t.esegui(802 if nb >= 3 else (801 if nb > 0 else 840))
		620:
			var vg2: Dictionary = t.p.veicoli.di(g)
			if not vg2.is_empty():
				t.p.veicoli.scendi(g)
				t._mp = maxi(0, t._mp - 1)
				t.p._log("tedesco", "Il %s scende %s." % [t.p.nome(g), t.p.veicoli.di_art(vg2)])
			g.reazione = ""
			t._muovi_rapido(false)
			if t.p.in_mappa(g) and t.p.terreno.scoperto(g.hex) and not t.bersagli(g).is_empty():
				t._prono()
		322:
			var vede := false
			for x in t.p.tedeschi_attivi():
				if x.id != g.id and t.p.in_mappa(x) and t.p.terreno.vede(g.hex, x.hex):
					vede = true
					break
			t.esegui(658 if vede else 809)
		324, 326, 327, 328:
			var g12: Dictionary = t.p.u("g12")
			if not g12.is_empty() and t.p.attivo(g12) and t.p.in_mappa(g12) and t.p.terreno.vede(g.hex, g12.hex):
				esegui(635)
			else:
				t.esegui({324: 866, 326: 867, 327: 800, 328: 863}[n])
		635:
			var g12b: Dictionary = t.p.u("g12")
			var c12: bool = not g12b.is_empty() and t.p.attivo(g12b) and t.p.in_mappa(g12b)
			var b: Array = t.bersagli(g)
			if c12 and g12b.hex == g.hex and not b.is_empty():
				esegui(640)
			elif c12 and g12b.hex == g.hex:
				t.esegui(809)
			elif c12 and t.p.terreno.vede(g.hex, g12b.hex) and not b.is_empty():
				esegui(650)
			else:
				esegui(665)
		640:
			var g12c: Dictionary = t.p.u("g12")
			t._accovacciati()
			if not g12c.is_empty() and g12c.postura != "prone":
				t.p.imposta_postura(g12c, "prone")
				t._mp = maxi(0, t._mp - 1)
				t.p._log("tedesco", "Il %s spinge a terra il feldmaresciallo." % t.p.nome(g))
				g._snap_forzato = true
			t._miglior_tiro("vicino")
		650:
			t._accovacciati()
			t._miglior_tiro("vicino")
			t._prono_se_libero()
		658:
			var guardie: Array = t.p.unita_in(g.hex, "de").filter(func(x): return x.id != g.id and t.p.attivo(x) and int(x.get("num", 0)) >= 13)
			if not guardie.is_empty() and not t.bersagli(g).is_empty():
				if t._cedi_turno(1):
					t._prono()
				else:
					t.esegui(802)
			elif not guardie.is_empty():
				t.esegui(809)
			else:
				var meta := ""
				for x in t.p.tedeschi_attivi():
					if x.id != g.id and t.p.in_mappa(x) and E.distanza(x.hex, g.hex) <= 3 and (meta == "" or E.distanza(x.hex, g.hex) < E.distanza(meta, g.hex)):
						meta = x.hex
				if meta != "":
					t._corri_verso(meta)
				else:
					t._muovi_rapido(false)
				t._prono()
		665:
			var g12d: Dictionary = t.p.u("g12")
			if not g12d.is_empty() and t.p.attivo(g12d) and t.p.in_mappa(g12d) and t._corri_verso(g12d.hex):
				t._accovacciati()
			elif not g12d.is_empty() and t.p.attivo(g12d) and t.p.in_mappa(g12d):
				if not t.p.terreno.scoperto(g.hex):
					t._prono()
			else:
				t._muovi_rapido(false, true)
		675:
			var altri: Array = t.p.unita_in(g.hex, "de").filter(func(x): return x.id != g.id and t.p.attivo(x))
			var us: Array = t.p.unita_in(g.hex, "us").filter(func(x): return t.p.attivo(x))
			if not altri.is_empty() or us.size() == 1:
				t.esegui(839)
			elif us.size() >= 2:
				t._arrenditi()
			else:
				t.esegui(802)
		680:
			var g12e: Dictionary = t.p.u("g12")
			t.esegui(833 if not g12e.is_empty() and g12e.hex == g.hex and t.p.attivo(g12e) else 812)
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
		391:
			_cane(g)
		403, 411, 428:
			if _cani_attivi():
				if n == 403:
					t._accovacciati()
					t._miglior_tiro("vicino")
				elif n == 411:
					t._accovacciati()
					t._tiri_rapidi()
			elif t.bersagli(g).is_empty():
				t.rimuovi_evasivo(g)
			else:
				t._muovi_rapido(false)
				if n == 411 and t.p.in_mappa(g) and t.bersagli(g).is_empty():
					t.rimuovi_evasivo(g)
				else:
					t._prono()
		573, 877:
			var vis: Array = t.bersagli(g)
			var vicino: Array = t.p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) <= 6)
			if n == 877 and not vis.is_empty():
				t.esegui(815)
			elif int(g.munizioni.get("granata", 0)) > 0 and (not vis.is_empty() or not vicino.is_empty()):
				if t._alzati():
					t.mo._granata_su(g, (vis[0] if not vis.is_empty() else vicino[0]).hex)
					t._prono_se_libero()
			elif not vis.is_empty():
				t.esegui(801)
			elif n == 573:
				t._accovacciati()
			else:
				t._prono()
		711:
			var qui: Array = t.p.unita_in(g.hex, "us").filter(func(a): return t.p.attivo(a))
			if qui.size() >= 2:
				t._arrenditi()
			elif t._alzati():
				t._miglior_tiro("vicino")
				t._prono_se_libero()
		869:
			if int(g.munizioni.get("granata", 0)) > 0 and t._bersagli_entro(3):
				t._accovacciati()
				var b: Array = t.bersagli(g)
				if not b.is_empty():
					t.mo._granata_su(g, b[0].hex)
				t._prono_se_libero()
			else:
				t.esegui(801)
		883:
			if not t.bersagli(g).is_empty() and t._alzati():
				t._tiri_rapidi()
			else:
				t._prono()
		884:
			if t._alzati():
				t._miglior_tiro("facile")
				t._prono_se_libero()
		895:
			var st: Dictionary = _ph()._st()
			if t.bersagli(g).is_empty() and not st.get("antenna_distrutta", false) and not st.get("allarme_dato", false):
				st.allarme_dato = true
				t.p._pv(-10, "il tedesco %d avvisa il comando dello sbarco" % int(g.num))
				t.p._log("info", "Il tedesco %d trasmette al comando: l’invasione è cominciata!" % int(g.num))
		874:
			t._arrenditi()
		_:
			return false
	return true

# ------------------------------------------------------------------ cani da guardia (391)
func _cani_attivi() -> bool:
	for x in t.p.tedeschi_attivi():
		if x.get("cane", false) and t.p.in_mappa(x):
			return true
	return false

func _cane(g: Dictionary) -> void:
	var p = t.p
	var bersaglio: Dictionary = p.u(str(g.get("cane_bersaglio", "")))
	if bersaglio.is_empty() or not p.attivo(bersaglio) or bersaglio.hex != g.hex:
		var qui: Array = p.unita_in(g.hex, "us").filter(func(a): return p.attivo(a))
		bersaglio = qui[p.rng.randi_range(0, qui.size() - 1)] if not qui.is_empty() else {}
	if bersaglio.is_empty():
		var vicino: Dictionary = {}
		for a in p.americani_attivi_in_mappa():
			if vicino.is_empty() or E.distanza(a.hex, g.hex) < E.distanza(vicino.hex, g.hex):
				vicino = a
		if vicino.is_empty():
			return
		var passi := 4 if g.ferito else 6
		var assalto := E.distanza(vicino.hex, g.hex) <= (2 if g.ferito else 3)
		for i in passi:
			if g.hex == vicino.hex:
				break
			var migliore := ""
			for v in E.vicini(g.hex):
				if p.terreno.costo_movimento(g.hex, v) < 0:
					continue
				if migliore == "" or E.distanza(v, vicino.hex) < E.distanza(migliore, vicino.hex):
					migliore = v
			if migliore == "" or E.distanza(migliore, vicino.hex) >= E.distanza(g.hex, vicino.hex):
				break
			var da: String = g.hex
			g.hex = migliore
			p._fx("muovi", {"ids": [g.id], "da": da, "a": migliore})
		p._log("tedesco", "Il %s corre verso %s e arriva in %s." % [p.nome(g), p.nome(vicino), g.hex])
		if not (assalto and g.hex == vicino.hex):
			return
		bersaglio = vicino
	g.cane_bersaglio = bersaglio.id
	var d: int = p.d10()
	p._log("dado", "Il %s azzanna %s: dado %d (6–7 panico, 8 ferito, 9 incapacitato)." % [p.nome(g), p.nome(bersaglio), d])
	if d in [6, 7]:
		p._applica_danno(bersaglio, "P", {})
	elif d == 8:
		p._applica_danno(bersaglio, "W", {})
	elif d == 9:
		p._applica_danno(bersaglio, "I", {})

# ------------------------------------------------------------------ carri e motosiluranti
func esegui_carro(n: int, g: Dictionary, veic: Dictionary) -> bool:
	var vv = t.p.veicoli
	var b: Array = vv.bersagli_carro(g)
	match n:
		826:
			vv._guida(veic, bool(veic.get("bersagliato", false)), g)
		900:
			if b.size() >= 3 or veic.get("bersagliato", false):
				if veic.get("chiuso", false):
					vv.esegui_carro(910, g, veic)
				else:
					vv._apri_chiudi(veic, true)
			elif not b.is_empty():
				esegui_carro(903, g, veic)
			elif not veic.get("chiuso", false):
				esegui_carro(903, g, veic)
			else:
				vv._apri_chiudi(veic, false)
		901:
			vv.esegui_carro(910, g, veic)
		903:
			vv._guida(veic, false, g)
			vv._cannone_o_carica(g, veic)
			if veic.cannone_pronto and not vv._sparato_cannone:
				vv._mg(g, veic, "coax", false, 1)
			vv._mg(g, veic, "scafo", false, 0)
		733:
			vv._guida(veic, false, g)
			vv._mg(g, veic, "scafo", true, 0)
			vv._mg(g, veic, "coax", false, 1)
		736:
			vv._guida(veic, false, g)
			vv._mg(g, veic, "coax", false, 0)
			vv._mg(g, veic, "scafo", false, 0)
		747:
			vv._guida(veic, true, g)
			vv._mg(g, veic, "scafo", true, 1)
			vv._mg(g, veic, "coax", false, 0)
		758:
			vv._guida(veic, true, g)
		763:
			vv._guida(veic, false, g)
			vv._mg(g, veic, "coax", true, 0)
		776:
			vv._guida(veic, true, g)
			vv._mg(g, veic, "scafo", true, 0)
		847:
			vv._guida(veic, false, g)
		849:
			vv._guida(veic, true, g)
		873, 874:
			t.p._log("danno", "L’equipaggio della %s si arrende." % veic.nome)
			vv.disabilita(veic, "equipaggio arreso")
			g.stato = "arreso"
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
