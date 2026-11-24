extends RefCounted
## Purple Heart 655/689: un soldato «fuori di testa» (tedesco o americano). Due turni per Round (uno se ferito), immune al
## panico, +2 all’abilità nell’assalto; a ogni turno, se nell’esagono c’è un nemico attivo, assalta per uccidere; altrimenti
## si alza, spara un tiro rapido al bersaglio più vicino (non se è ferito) e corre verso il nemico attivo più vicino usando
## metà dei punti movimento (tutti se non ha armi), senza mai cadere prono e senza granate.
## Un americano fuori di testa si ferma placcandolo: un compagno che comincia il turno nel suo esagono o ci entra tira un dado.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

var p  # Partita

func _init(partita) -> void:
	p = partita

## 655: un tedesco a caso (non a bordo di un mezzo) va fuori di testa. Una volta sola.
func tedesco(st: Dictionary) -> void:
	if st.get("berserk_de", false):
		p._log("info", "L’evento è già avvenuto: nessun effetto.")
		return
	var l: Array = p.tedeschi_attivi().filter(func(g): return p.attivo(g) and p.in_mappa(g) and str(g.get("veicolo", "")) == "" and not g.get("cane", false))
	if l.is_empty():
		p._log("info", "Nessun tedesco può andare fuori di testa.")
		return
	st.berserk_de = true
	var g: Dictionary = l[p.rng.randi_range(0, l.size() - 1)]
	g.berserk = true
	g.panico = false
	p._log("tedesco", "Il %s va fuori di testa e carica gli americani!" % p.nome(g))

## 689: un americano a caso (non un comandante) va fuori di testa. Una volta sola.
func americano(st: Dictionary) -> void:
	if st.get("berserk_us", false):
		p._log("info", "L’evento è già avvenuto: nessun effetto.")
		return
	var l: Array = p.americani_attivi_in_mappa().filter(func(a): return not a.get("comandante", false) and not a.get("carro_us", false) \
		and p.veicoli.di(a).is_empty() and not a.get("senza_carta", false))
	if l.is_empty():
		p._log("info", "Nessun soldato può andare fuori di testa.")
		return
	st.berserk_us = true
	var a: Dictionary = l[p.rng.randi_range(0, l.size() - 1)]
	a.berserk = true
	a.panico = false
	p._log("info", "%s va fuori di testa e carica i tedeschi! Finché resta così si muove da solo; un compagno può placcarlo." % p.nome(a))

func turni(x: Dictionary, es: Dictionary) -> Dictionary:
	if x.get("berserk", false) and p.attivo(x):
		return {"turni": 1 if x.ferito else 2, "panico": false, "rosso": false}
	return es

## Turno di un tedesco fuori di testa (ia = tedeschi.gd). true se l’ha gestito.
func turno_tedesco(ia, g: Dictionary) -> bool:
	if not g.get("berserk", false):
		return false
	_turno(g, p.americani_attivi_in_mappa().filter(func(a): return not a.get("in_jagd", false)), ia)
	return true

## Turno di un americano fuori di testa: finisce quando non ci sono più tedeschi attivi.
func turno_americano(a: Dictionary) -> void:
	var nemici: Array = p.tedeschi_attivi().filter(func(g): return p.attivo(g) and not g.get("fuori_mappa_ph", false))
	if nemici.is_empty():
		a.berserk = false
		p._log("info", "Non ci sono più tedeschi attivi: %s torna in sé." % p.nome(a))
		return
	_turno(a, nemici, null)

func _turno(x: Dictionary, nemici: Array, ia) -> void:
	p._log("tedesco" if x.lato == "de" else "info", "%s, fuori di testa, agisce da solo." % p.nome(x))
	p._fx("attore", {"id": x.id, "a": x.hex})
	var qui: Array = nemici.filter(func(n): return n.hex == x.hex)
	if not qui.is_empty():
		_assalto(x, qui)
		return
	if x.postura != "standing":
		p.imposta_postura(x, "standing")
	var armi: Array = p.armi_da_fuoco(x).filter(func(w): return T.ARMI.get(w.tipo, {}).has("gittate") and not (w.tipo in ["bazooka", "pzf", "pzb", "cannone"]))
	if not x.ferito and not armi.is_empty():
		var vis: Array = nemici.filter(func(n): return p.vede_unita(x, n))
		vis.sort_custom(func(a, b): return E.distanza(a.hex, x.hex) < E.distanza(b.hex, x.hex))
		for b in vis:
			for w in armi:
				if p.probabilita_tiro(x, w, b, false).ok:
					p.risolvi_tiro(x, w, b, false)
					break
			break
	if not p.in_mappa(x):
		return
	var mp: int = int(p.effettivo_mpa(x))
	if not armi.is_empty():
		mp = mp / 2
	_corri_verso_nemico(x, nemici, mp)
	var ora: Array = nemici.filter(func(n): return p.attivo(n) and n.hex == x.hex)
	if not ora.is_empty() and x.lato == "us":
		_assalto(x, ora)

func _assalto(x: Dictionary, qui: Array) -> void:
	var facile: Dictionary = qui[0]
	for n in qui:
		if T.indice_postura(n.postura) < T.indice_postura(facile.postura) or n.ferito:
			facile = n
	if x.postura != "standing":
		p.imposta_postura(x, "standing")
	p.risolvi_assalto(x, facile, "uccidi", false)

## Corre verso il nemico attivo più vicino pagando il terreno, senza entrare in terreno vietato (scelte a dado).
func _corri_verso_nemico(x: Dictionary, nemici: Array, mp: int) -> void:
	var passi := 0
	while mp > 0 and p.in_mappa(x) and passi < 12:
		passi += 1
		var vicino: Dictionary = {}
		for n in nemici:
			if p.attivo(n) and p.in_mappa(n) and (vicino.is_empty() or E.distanza(n.hex, x.hex) < E.distanza(vicino.hex, x.hex)):
				vicino = n
		if vicino.is_empty() or vicino.hex == x.hex:
			return
		var scelte: Array = []
		var dmin := 999
		for v in E.vicini(x.hex):
			var c: int = p.terreno.costo_movimento(x.hex, v)
			if c < 0 or c > mp:
				continue
			var d: int = E.distanza(v, vicino.hex)
			if d < dmin:
				dmin = d
				scelte = [v]
			elif d == dmin:
				scelte.append(v)
		if scelte.is_empty() or dmin >= E.distanza(x.hex, vicino.hex) + 1:
			return
		var verso: String = scelte[p.rng.randi_range(0, scelte.size() - 1)]
		mp -= p.terreno.costo_movimento(x.hex, verso)
		var da: String = x.hex
		x.hex = verso
		p._log("tedesco" if x.lato == "de" else "info", "%s corre in %s." % [p.nome(x), verso])
		p._fx("muovi", {"ids": [x.id], "da": da, "a": verso})
		if x.lato == "us":
			p.segna_passaggio_ponte(da, verso)
		if not p.unita_in(verso, "de" if x.lato == "us" else "us").is_empty():
			return

## Placcaggio (689): un compagno che comincia il turno nell’esagono o ci entra. true se l’americano torna in sé.
func placca(chi: Dictionary, b: Dictionary) -> bool:
	if not b.get("berserk", false) or chi.id == b.id or chi.hex != b.hex:
		return false
	var d: int = p.d10()
	if d >= 8:
		p._log("dado", "%s prova a placcare %s: %d → placcaggio fallito." % [p.nome(chi), p.nome(b), d])
		return false
	var d2: int = p.d10()
	if d2 <= 2:
		p._log("dado", "%s placca %s (%d), ma lui è ancora fuori di testa (%d)." % [p.nome(chi), p.nome(b), d, d2])
		return false
	b.berserk = false
	p.imposta_postura(chi, "prone")
	p.imposta_postura(b, "prone")
	p._log("dado", "%s placca %s (%d, %d): torna in sé. Entrambi a terra." % [p.nome(chi), p.nome(b), d, d2])
	return true
