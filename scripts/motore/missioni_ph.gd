extends RefCounted
## Regole e operazioni dei paragrafi delle missioni di Purple Heart (13–18).
## Per ora: Missione 16 «In guardia» (deposito di carburante, commando con esplosivi, battelli d’assalto).

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

var p  # Partita

func _init(partita) -> void:
	p = partita

func attiva() -> bool:
	return str(p.missione.get("libro", "")) == "ph"

func deposito() -> Array:
	return p.missione.get("regole", {}).get("deposito", [])

func _st() -> Dictionary:
	if not p.s.has("ph"):
		p.s.ph = {"esplosivi": {}, "barche": {}, "deposito_distrutto": [], "entrati": false, "fine_esplosivi": false, "difusi": 0}
	return p.s.ph

# ------------------------------------------------------------------ operazioni
func op(o: Dictionary, ctx: Dictionary) -> bool:
	if not attiva():
		return false
	match str(o.op):
		"imbarca":
			_imbarca(o)
		"barca":
			p.ia.ph.barca(o, ctx)
		"pianta_esplosivo":
			_pianta(ctx)
		"esplosivo_a_tempo":
			_esplosivo_a_tempo()
		"disinnesco_pc":
			_disinnesco_pc()
		"fine_esplosivi":
			_st().fine_esplosivi = true
			p._log("info", "D’ora in poi la missione finisce solo quando non restano tedeschi attivi e tutti gli esplosivi sono stati disinnescati o sono saltati.")
		"telefono":
			_st().telefono = int(p.s.condizione)
			p._log("info", "In J8 squilla un telefono: rispondi entrando in J8 durante questa Condizione.")
		"al_prossimo_round":
			var n := int(p.s.get("round", {}).get("n", 0)) if p.fase_round() else 0
			var st := _st()
			if not st.has("pendenti"):
				st.pendenti = []
			st.pendenti.append({"p": str(o.p), "round": n + (2 if n == 0 else 1)})
			p._log("info", "All’inizio del prossimo Round, prima del controllo degli eventi casuali, si legge il paragrafo %s." % o.p)
		"cani":
			_cani(ctx)
		"mappa_d":
			_mappa_d()
		"faro_ruota":
			_faro_ruota()
		"deposito_navale":
			_deposito_navale(ctx)
		"porta_cannone":
			_st()["porta_" + str(o.hex)] = true
			if not p.s.has("da_leggere"):
				p.s.da_leggere = {}
			p.s.da_leggere[str(o.hex)] = "672"
		"magazzino":
			_st().magazzino = true
			p._log("info", "Con una carica da demolizione piazzata nel deposito munizioni (azione «Fai saltare il cannone»), cannone e bunker saltano.")
		"attiva_eboat":
			var solo: Array = ctx.get("solo", [67, 68])
			var coppie: Array = [[67, "G15"], [68, "F15"]].filter(func(x): return int(x[0]) in solo)
			p._op_attiva({"op": "activate", "g": coppie, "stance": "crouching", "adv": o.get("adv", null), "two": [], "us_two": false,
				"aware": false, "reaction": null, "rounds": true}, ctx)
		"eboat_662":
			_eboat_662(ctx)
		"auto_comando":
			if p.veicoli.v("vauto13").is_empty():
				p.veicoli.crea("vauto13", "auto_comando", "I14", "us")
				p._log("info", "In I14 c’è un’auto comando abbandonata: le chiavi sono nel cruscotto e il serbatoio è pieno.")
		"scialuppa":
			if p.veicoli.v("vscialuppa").is_empty():
				var vs: Dictionary = p.veicoli.crea("vscialuppa", "chiatta", "I18", "us")
				vs.nome = "Scialuppa"
				p._log("info", "La scialuppa rovesciata è stata trascinata sulla spiaggia in I18: ci sta tutta la squadra. Uscendo dal bordo ovest in scialuppa si guadagnano 10 PV.")
		"esplosione_prematura":
			_esplosione_prematura()
		"esplosivo_us_casuale":
			var lista: Array = _st().get("cariche_us", {}).keys()
			if not lista.is_empty():
				_detona_us(lista[p.rng.randi_range(0, lista.size() - 1)])
		"incendio_adiacente":
			_incendio_adiacente()
		"cane_recupera":
			_cane_recupera()
		"serbatoi":
			_serbatoi()
		"deposito_esplode":
			_deposito_esplode()
		"arresa_casuale":
			var gl: Array = p.tedeschi_attivi().filter(func(g): return p.in_mappa(g) and str(g.get("veicolo", "")) == "" and not g.get("cane", false))
			if not gl.is_empty():
				var gx: Dictionary = gl[p.rng.randi_range(0, gl.size() - 1)]
				gx.stato = "arreso"
				gx.turni = 0
				gx.slot = "inattivo"
				p._log("info", "Il %s si arrende." % p.nome(gx))
		"solo_testo":
			p._log("info", str(o.get("testo", "In questa versione l’evento non ha effetti.")))
		"camion":
			p._log("info", "La colonna di camion è in arrivo, ma in questa versione i camion non entrano in mappa: la difesa del deposito resta il compito della squadra.")
		_:
			return false
	return true

func test(t: Dictionary, ctx: Dictionary) -> Variant:
	if not attiva():
		return null
	if t.has("g_esplosivo"):
		var g: Dictionary = p.u(ctx.get("g", ""))
		if g.is_empty() or int(g.get("esplosivi", 0)) <= 0 or _st().esplosivi.has(g.hex):
			return false
		for x in p.unita_in(g.hex, "de"):
			if x.id != g.id and p.attivo(x) and int(x.get("esplosivi", 0)) > 0:
				return false
		return true
	if t.has("deposito_entrati"):
		return bool(_st().entrati) == bool(t.deposito_entrati)
	if t.has("deposito_attivi_max"):
		return _attivi_nel_deposito() <= int(t.deposito_attivi_max)
	if t.has("esplosivo_mezzo_us"):
		return _esplosivo_mezzo_con_us() != ""
	if t.has("esplosivo_intero_edificio"):
		return _esplosivi_interi_in_edificio().size() > 0
	if t.has("nw_fiume"):
		return bool(_st().get("nw_fiume", false)) == bool(t.nw_fiume)
	if t.has("barca_mossa"):
		var g2: Dictionary = p.u(ctx.get("g", ""))
		return not g2.is_empty() and p.ia.ph.barca_gia_mossa(g2)
	return null

func _attivi_nel_deposito() -> int:
	var n := 0
	for g in p.tedeschi_attivi():
		if p.in_mappa(g) and g.hex in deposito():
			n += 1
	return n

# ------------------------------------------------------------------ battelli
func _imbarca(o: Dictionary) -> void:
	var st := _st()
	var id := "b%d" % (st.barche.size() + 1)
	st.barche[id] = {"hex": str(o.hex), "mossa": ""}
	for n in o.g:
		var g: Dictionary = p.u("g%d" % int(n))
		if not g.is_empty() and p.in_mappa(g):
			g.barca = id
			g.hex = str(o.hex)
			g.postura = "crouching"
	p.s.oggetti[str(o.hex)] = p.s.oggetti.get(str(o.hex), []) + [{"tipo": "barca", "id": id}]
	p._log("info", "Un battello d’assalto tedesco è in %s." % o.hex)

func occupanti(id: String) -> Array:
	return p.tedeschi_attivi().filter(func(g): return str(g.get("barca", "")) == id and p.in_mappa(g))

func sposta_barca(id: String, h: String) -> void:
	var b: Dictionary = _st().barche[id]
	var da: String = b.hex
	var lista: Array = p.s.oggetti.get(da, [])
	lista = lista.filter(func(x): return not (x.get("tipo", "") == "barca" and x.get("id", "") == id))
	if lista.is_empty():
		p.s.oggetti.erase(da)
	else:
		p.s.oggetti[da] = lista
	b.hex = h
	p.s.oggetti[h] = p.s.oggetti.get(h, []) + [{"tipo": "barca", "id": id}]
	var ids: Array = []
	for g in occupanti(id):
		g.hex_prec = g.hex
		g.hex = h
		ids.append(g.id)
	p._log("tedesco", "Il battello d’assalto risale il fiume fino a %s." % h)
	p._fx("muovi", {"ids": ids, "da": da, "a": h})

# ------------------------------------------------------------------ esplosivi (619)
func _pianta(ctx: Dictionary) -> void:
	var g: Dictionary = p.u(ctx.get("g", ""))
	if g.is_empty():
		return
	if p.ia._mp < int(p.effettivo_mpa(g)):
		# 840: si è già mosso in questo turno; si ferma e piazzerà la carica al prossimo turno.
		p.ia.ferma()
		p._log("tedesco", "Il %s si ferma in %s: piazzerà l’esplosivo al prossimo turno." % [p.nome(g), g.hex])
		return
	g.esplosivi = int(g.get("esplosivi", 0)) - 1
	_st().esplosivi[g.hex] = 2
	g.postura = "crouching"
	p.ia.ferma()
	p.s.oggetti[g.hex] = p.s.oggetti.get(g.hex, []) + [{"tipo": "esplosivo"}]
	p._log("tedesco", "Il %s si accovaccia e piazza un esplosivo a tempo in %s!" % [p.nome(g), g.hex])
	if not _st().fine_esplosivi:
		op({"op": "fine_esplosivi"}, ctx)

func esplosivo(h: String) -> int:
	return int(_st().esplosivi.get(h, 0))

## Azione americana: un’azione gira l’esplosivo sul lato 1, la seconda lo toglie (+2 PV).
func disinnesca(a: Dictionary) -> String:
	var h: String = a.hex
	var lato := esplosivo(h)
	if lato == 0:
		return "Qui non c’è un esplosivo."
	if lato == 2:
		_st().esplosivi[h] = 1
		p._log("azione", "%s comincia a disinnescare l’esplosivo in %s (manca ancora un’azione)." % [p.nome(a), h])
	else:
		_togli_esplosivo(h)
		_st().difusi = int(_st().difusi) + 1
		p._pv(2, "esplosivo disinnescato in %s" % h)
		p._log("azione", "%s stacca il detonatore: l’esplosivo in %s è disinnescato." % [p.nome(a), h])
	return ""

func _togli_esplosivo(h: String) -> void:
	_st().esplosivi.erase(h)
	var lista: Array = p.s.oggetti.get(h, []).filter(func(x): return x.get("tipo", "") != "esplosivo")
	if lista.is_empty():
		p.s.oggetti.erase(h)
	else:
		p.s.oggetti[h] = lista

func _esplosivi_interi_in_edificio() -> Array:
	var out: Array = []
	for h in _st().esplosivi:
		if int(_st().esplosivi[h]) == 2 and p.terreno.edificio(h):
			out.append(h)
	return out

func _esplosivo_mezzo_con_us() -> String:
	for h in _st().esplosivi:
		if int(_st().esplosivi[h]) == 1 and p.terreno.edificio(h):
			for a in p.unita_in(h, "us"):
				if p.attivo(a):
					return h
	return ""

## 651: un esplosivo sul lato 2 salta.
func _esplosivo_a_tempo() -> void:
	var lista := _esplosivi_interi_in_edificio()
	if lista.is_empty():
		for h in _st().esplosivi:
			if int(_st().esplosivi[h]) == 2:
				lista.append(h)
	if lista.is_empty():
		return
	var h: String = lista[p.rng.randi_range(0, lista.size() - 1)]
	p._log("info", "La spoletta a tempo arriva a zero: l’esplosivo in %s salta!" % h)
	esplodi(h)

## 660: il soldato con la percezione più alta prova a staccare il detonatore.
func _disinnesco_pc() -> void:
	var h := _esplosivo_mezzo_con_us()
	if h == "":
		return
	var migliore: Dictionary = {}
	for a in p.unita_in(h, "us"):
		if p.attivo(a) and (migliore.is_empty() or int(a.PC) > int(migliore.PC)):
			migliore = a
	if p.controllo_pc(migliore, 0, "disinnescare l’esplosivo all’ultimo istante"):
		_togli_esplosivo(h)
		_st().difusi = int(_st().difusi) + 1
		p._pv(2, "esplosivo disinnescato in %s" % h)
		p._log("info", "%s stacca il detonatore un attimo prima che scatti!" % p.nome(migliore))
	else:
		p._log("info", "Troppo tardi: l’esplosivo in %s salta!" % h)
		esplodi(h)

## Esplosione di una carica (o del carburante): muore chi è nell’esagono, chi è accanto subisce danni da granata al chiuso.
func esplodi(h: String) -> void:
	_togli_esplosivo(h)
	p._fx("esplosione", {"a": h, "grande": true})
	for x in p.unita_in(h):
		if p.attivo(x) or x.stato in ["ferito", "incapacitato"]:
			p._uccidi(x, "nell’esplosione")
	if p.terreno.edificio(h) and not p.s.modifiche.has(h):
		p.s.modifiche[h] = "rubble"
		p.terreno.imposta_modifiche(p.s.modifiche)
		p.s.oggetti[h] = p.s.oggetti.get(h, []) + [{"tipo": "incendio"}]
		p._log("info", "L’edificio in %s brucia." % h)
	if h in deposito() and not (h in _st().deposito_distrutto):
		_st().deposito_distrutto.append(h)
		p._log("info", "Il carburante del deposito in %s prende fuoco!" % h)
	for v in E.vicini(h):
		for x in p.unita_in(v):
			if not p.attivo(x):
				continue
			if p.controllo_pc(x, 0, "buttarsi a terra per l’esplosione"):
				x.postura = "prone"
			p._danno_esplosione(x, T.GRANATA_DENTRO)
	if _st().esplosivi.has(h):
		_togli_esplosivo(h)

# ------------------------------------------------------------------ agganci della partita
## Ogni esplosione nel deposito fa saltare il carburante (414).
func esplosione(tipo: String, h: String) -> void:
	if attiva() and h in deposito() and not (h in _st().deposito_distrutto):
		esplodi(h)

## Un tiro americano mancato contro un tedesco nel deposito: 0–3 il carburante esplode (414).
func tiro_mancato(b: Dictionary) -> void:
	if not attiva() or b.is_empty() or not (str(b.get("hex", "")) in deposito()):
		return
	if str(b.hex) in _st().deposito_distrutto:
		return
	var d: int = p.d10()
	p._log("dado", "Colpo mancato nel deposito: dado %d (0–3 il carburante esplode)." % d)
	if d <= 3:
		esplodi(str(b.hex))

# ================================================================== Missione 13 «Dispersi»
## Lancio (controllo della qualità dell’atterraggio) prima della missione.
func dopo_nuova() -> void:
	if not attiva() or not bool(p.regola("atterraggio_ph", false)):
		return
	var terreni := ["libero", "libero", "libero", "libero", "macchia", "macchia", "macchia", "bosco", "bosco", "fiume"]
	var persi := 0
	for a in p.americani():
		var t: String = terreni[p.d10()]
		var d: int = p.d10()
		var esito := "atterraggio buono"
		match t:
			"libero":
				if d == 9:
					a.ferito = true
					esito = "atterraggio duro: ferito"
			"macchia":
				if d == 9:
					if p.d10() <= 4:
						a.ferito = true
						esito = "atterraggio duro: ferito"
					else:
						a.stato = "incapacitato"
						esito = "atterraggio duro: incapacitato"
			"bosco":
				if d >= 5:
					var d2: int = p.d10()
					if d2 in [7, 8]:
						a.ferito = true
						esito = "finisce tra i rami: ferito"
					elif d2 == 9:
						if p.d10() <= 4:
							a.ferito = true
							esito = "finisce tra i rami: ferito"
						else:
							a.stato = "incapacitato"
							esito = "finisce tra i rami: incapacitato"
			"fiume":
				if d == 9:
					if p.d10() <= 4:
						esito = "sfiora il fiume e atterra sulla riva"
					else:
						a.stato = "morto"
						a.armi = []
						esito = "cade nel fiume e annega"
		if a.stato in ["incapacitato", "morto"]:
			persi += 1
		p._log("dado", "Lancio di %s (%s): %s." % [p.nome(a), t, esito])
	var c: int = p.d10()
	if c == 9:
		p._log("info", "La cassa delle armi è andata perduta (in questa versione la squadra tiene il suo equipaggiamento).")
	if persi > 0:
		p._pv(-2 * persi, "soldati persi nel lancio")

func turni_tedesco(g: Dictionary, es: Dictionary) -> Dictionary:
	if attiva() and g.get("cane", false):
		return {"turni": 1 if g.ferito else 2, "panico": false}
	return es

func uscita(a: Dictionary, h: String) -> void:
	if not attiva():
		return
	var v: Dictionary = p.veicoli.di(a)
	if not v.is_empty() and v.id == "vscialuppa" and E.colonna(h) == 0 and not _st().get("scialuppa_uscita", false):
		_st().scialuppa_uscita = true
		p._pv(10, "la squadra raggiunge la flotta in scialuppa")

func _cani(ctx: Dictionary) -> void:
	var g61: Dictionary = p.u("g61")
	var h: String = g61.hex if not g61.is_empty() and g61.hex != "" else str(ctx.get("hex", ""))
	for n in [91, 92]:
		var c: Dictionary = p._crea_tedesco(n, h, "standing")
		c.cane = true
	p._log("attivazione", "Due cani da guardia in %s!" % h)

func _cane_recupera() -> void:
	if _st().get("cane_recuperato", false):
		return
	for n in [91, 92]:
		var c: Dictionary = p.u("g%d" % n)
		if not c.is_empty() and c.stato == "incapacitato":
			_st().cane_recuperato = true
			c.stato = "attivo"
			c.ferito = true
			c.slot = "completo"
			p._log("info", "Un cane da guardia si rialza, ferito, e riparte all’attacco!")
			return
	p._log("info", "Nessun cane può riprendersi (il treno del paragrafo 486 non è previsto in questa missione).")

## 495: la mezza mappa D sopra la mappa A.
func _mappa_d() -> void:
	p.cambia_mappa("AD")
	var st := _st()
	st.faro = {"hex": "E11", "dir": 3, "attivo": true}
	for x in [["U14", "antenna"], ["E11", "faro"], ["W12", "cannone_costiero"], ["X12", "cannone_costiero"]]:
		p.s.oggetti[x[0]] = p.s.oggetti.get(x[0], []) + [{"tipo": x[1]}]
	_illumina()

const DIREZIONI := ["nord", "est", "sud", "ovest"]

## 604/632/648: il faro ruota di 90° in senso orario, se non sta illuminando un americano attivo.
func _faro_ruota() -> void:
	var f: Dictionary = _st().get("faro", {})
	if f.is_empty() or not f.attivo:
		return
	for a in p.americani_attivi_in_mappa():
		if p.terreno.illuminati.has(a.hex):
			p._log("info", "Il faro resta puntato verso %s: illumina %s." % [DIREZIONI[int(f.dir)], p.nome(a)])
			return
	f.dir = (int(f.dir) + 1) % 4
	p._log("info", "Il faro ruota verso %s." % DIREZIONI[int(f.dir)])
	_illumina()

func faro_illumina() -> Dictionary:
	var out := {}
	var f: Dictionary = _st().get("faro", {})
	if f.is_empty() or not f.get("attivo", false) or p.s.modifiche.has(str(f.hex)):
		return out
	var c0 := E.centro(str(f.hex))
	var verso: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][int(f.dir)]
	for h in p.terreno.esagoni:
		var d := E.centro(h) - c0
		if h == f.hex or d.length() < 0.1:
			continue
		if d.normalized().dot(verso) < 0.5:
			continue
		if p.terreno.vede(str(f.hex), h):
			out[h] = true
	return out

func _illumina() -> void:
	var il := faro_illumina()
	for h in _st().get("fuoco_visibile", {}):
		il[h] = true
	p.terreno.illuminati = il
	p.terreno._cache_los.clear()

## 526: il deposito della marina (l’edificio con l’esagono letto).
func _deposito_navale(ctx: Dictionary) -> void:
	var h: String = ctx.get("hex", "")
	if h == "" or _st().has("deposito_navale"):
		return
	var dep: Array = [h]
	var i := 0
	while i < dep.size():
		for v in E.vicini(dep[i]):
			if p.terreno.edificio(v) and not (v in dep) and p.terreno.tipo_lato(dep[i], v) == "":
				dep.append(v)
		i += 1
	_st().deposito_navale = dep
	for a in p.americani_attivi_in_mappa():
		if a.hex in dep:
			a.esplosivi_ph = int(a.get("esplosivi_ph", 0)) + 2
	p._log("info", "Il deposito della marina occupa %s. Chi è dentro prende gli esplosivi al plastico (2 a testa); si possono prendere entrando nel deposito." % ", ".join(dep))

func nel_deposito_navale(a: Dictionary) -> bool:
	return attiva() and a.hex in _st().get("deposito_navale", []) and not (a.hex in _st().get("deposito_distrutto", []))

func prendi_esplosivi(a: Dictionary) -> void:
	a.esplosivi_ph = int(a.get("esplosivi_ph", 0)) + 2
	p._log("azione", "%s prende due cariche di esplosivo al plastico." % p.nome(a))

## Esplosivo americano: nei Round lato 2, al Round dopo lato 1, al successivo salta; nelle Operazioni salta quando nessun americano è vicino.
func piazza_esplosivo_us(a: Dictionary) -> void:
	a.esplosivi_ph = int(a.get("esplosivi_ph", 0)) - 1
	var cariche: Dictionary = _st().get("cariche_us", {})
	cariche[a.hex] = 2 if p.fase_round() else 0
	_st().cariche_us = cariche
	p.s.oggetti[a.hex] = p.s.oggetti.get(a.hex, []) + [{"tipo": "carica_us"}]
	p._log("azione", "%s piazza un esplosivo al plastico in %s%s." % [p.nome(a), a.hex, " (salta all’inizio del secondo Round)" if p.fase_round() else " (salta quando la squadra si è allontanata)"])

func fai_saltare_cannone(a: Dictionary) -> String:
	if not (a.hex in ["W12", "X12"]) or not _st().get("magazzino", false):
		return "Bisogna essere nel bunker di un cannone costiero dopo averne trovato il deposito munizioni."
	var sc: Dictionary = p.arma_di(a, "satchel")
	if int(a.munizioni.get("satchel", 0)) <= 0 and sc.is_empty():
		return "Serve una carica da demolizione."
	if not sc.is_empty():
		a.armi.erase(sc)
	elif int(a.munizioni.get("satchel", 0)) > 0:
		a.munizioni.satchel = int(a.munizioni.satchel) - 1
	var cariche: Dictionary = _st().get("cariche_us", {})
	cariche[a.hex] = 2 if p.fase_round() else 0
	_st().cariche_us = cariche
	p._log("azione", "%s piazza la carica nel deposito munizioni del cannone in %s." % [p.nome(a), a.hex])
	return ""

func _detona_us(h: String) -> void:
	_st().cariche_us.erase(h)
	var lista: Array = p.s.oggetti.get(h, []).filter(func(x): return x.get("tipo", "") != "carica_us")
	if lista.is_empty():
		p.s.oggetti.erase(h)
	else:
		p.s.oggetti[h] = lista
	p._log("info", "L’esplosivo in %s salta!" % h)
	if h in ["W12", "X12"] and not _st().get("cannone_" + h, false):
		_st()["cannone_" + h] = true
		p._pv(4, "cannone costiero distrutto in %s" % h)
		p.s.oggetti[h] = p.s.oggetti.get(h, []).filter(func(x): return x.get("tipo", "") != "cannone_costiero") + [{"tipo": "incendio"}]
		for x in p.unita_in(h):
			if p.attivo(x):
				p._uccidi(x, "nell’esplosione del deposito munizioni")
		for v in E.vicini(h):
			for x in p.unita_in(v):
				if p.attivo(x):
					p._incapacita(x)
		return
	var era_edificio: bool = p.terreno.edificio(h)
	var f: Dictionary = _st().get("faro", {})
	if not f.is_empty() and h == str(f.hex):
		f.attivo = false
		p._log("info", "Il faro è distrutto.")
	if h in ["J13", "K14"] or E.distanza(h, "J13") <= 1 or E.distanza(h, "K14") <= 1:
		_serbatoi()
	if h == "U14":
		_st().antenna_distrutta = true
	for veic in p.s.get("veicoli", {}).values():
		if str(veic.hex) == h and p.veicoli.attivo(veic):
			p.veicoli.disabilita(veic, "esplosivo al plastico")
	esplodi(h)
	if era_edificio:
		p._pv(2, "edificio distrutto in %s" % h)
		if h in _st().get("deposito_navale", []):
			_deposito_esplode()
	_illumina()

func _esplosione_prematura() -> void:
	var lista: Array = _st().get("cariche_us", {}).keys()
	if lista.is_empty():
		return
	var pd: int = p.percentuale()
	p._log("dado", "Percentuale %02d (75 o più: un esplosivo salta in anticipo)." % pd)
	if pd >= 75:
		_detona_us(lista[p.rng.randi_range(0, lista.size() - 1)])

## 616: tutto il deposito della marina esplode.
func _deposito_esplode() -> void:
	if _st().get("deposito_esploso", false):
		return
	_st().deposito_esploso = true
	var dep: Array = _st().get("deposito_navale", [])
	p._log("info", "Il deposito della marina esplode tutto insieme!")
	for h in dep:
		for x in p.unita_in(h):
			if p.attivo(x) or x.stato in ["ferito", "incapacitato"]:
				p._uccidi(x, "nell’esplosione del deposito")
		if not p.s.modifiche.has(h):
			p.s.modifiche[h] = "rubble"
			p.s.oggetti[h] = p.s.oggetti.get(h, []) + [{"tipo": "incendio"}]
			p._pv(2, "edificio distrutto in %s" % h)
	p.terreno.imposta_modifiche(p.s.modifiche)
	for h in p.terreno.esagoni:
		if h in dep:
			continue
		var dmin := 99
		for d in dep:
			dmin = mini(dmin, E.distanza(h, d))
		if dmin == 1:
			for x in p.unita_in(h):
				if p.attivo(x):
					p._incapacita(x)
		elif dmin == 2:
			for x in p.unita_in(h):
				if p.attivo(x):
					p._danno_esplosione(x, T.GRANATA_FUORI)

## 725: i serbatoi di carburante esplodono.
func _serbatoi() -> void:
	if _st().get("serbatoi_esplosi", false):
		return
	_st().serbatoi_esplosi = true
	p._log("info", "I due serbatoi di carburante esplodono con una forza tremenda!")
	for t in ["J13", "K14"]:
		p.s.oggetti[t] = p.s.oggetti.get(t, []) + [{"tipo": "incendio"}]
	for x in p.s.unita.values():
		if not p.attivo(x) or not p.in_mappa(x):
			continue
		var d: int = mini(E.distanza(x.hex, "J13"), E.distanza(x.hex, "K14"))
		if d <= 6:
			x.postura = "prone"
			x.turni = 0
		if d <= 2:
			if p.terreno.edificio(x.hex):
				p._danno_esplosione(x, T.GRANATA_DENTRO)
			else:
				p._danno_esplosione(x, T.GRANATA_DENTRO)
	for h in p.terreno.esagoni:
		if p.terreno.edificio(h) and mini(E.distanza(h, "J13"), E.distanza(h, "K14")) <= 2:
			p.s.modifiche[h] = "rubble"
	p.terreno.imposta_modifiche(p.s.modifiche)
	var vis := {}
	for h in p.terreno.esagoni:
		if p.terreno.vede("J13", h) or p.terreno.vede("K14", h):
			vis[h] = true
	_st().fuoco_visibile = vis
	_illumina()

## 648 (1–2): un edificio accanto a un edificio in fiamme prende fuoco ed esplode.
func _incendio_adiacente() -> void:
	var candidati: Array = []
	for h in p.s.oggetti:
		if p.s.oggetti[h].any(func(x): return x.get("tipo", "") == "incendio"):
			for v in E.vicini(h):
				if p.terreno.edificio(v) and not (v in candidati):
					candidati.append(v)
	if candidati.is_empty():
		p._log("info", "Nessun edificio accanto a un incendio: nessun effetto.")
		return
	var h2: String = candidati[p.rng.randi_range(0, candidati.size() - 1)]
	esplodi(h2)
	p._pv(2, "edificio distrutto in %s" % h2)
	if h2 in _st().get("deposito_navale", []):
		_deposito_esplode()

## 662: due motosiluranti in fuga; se un americano qui ha un’azione, la prima si arrende.
func _eboat_662(ctx: Dictionary) -> void:
	var h: String = ctx.get("hex", "H14")
	var pronto := false
	for a in p.unita_in(h, "us"):
		if p.attivo(a) and (not p.fase_round() or int(a.turni) > 0):
			pronto = true
	if pronto:
		p._pv(5, "la motosilurante in G15 si arrende e viene affondata")
		p.leggi("643", {"hex": h, "solo": [68]})
	else:
		p.leggi("643", {"hex": h})

func inizio_round() -> void:
	if not attiva():
		return
	var cariche: Dictionary = _st().get("cariche_us", {})
	for h in cariche.keys():
		if int(cariche[h]) == 2:
			cariche[h] = 1
		elif int(cariche[h]) == 1:
			_detona_us(h)
	if not _st().has("pendenti"):
		return
	var n := int(p.s.round.get("n", 0))
	var ora: Array = _st().pendenti.filter(func(x): return int(x.round) <= n)
	_st().pendenti = _st().pendenti.filter(func(x): return int(x.round) > n)
	for x in ora:
		p.leggi(str(x.p), {})

func controlla() -> void:
	if not attiva():
		return
	var cariche: Dictionary = _st().get("cariche_us", {})
	if not p.fase_round():
		for h in cariche.keys():
			if int(cariche[h]) == 0 and p.americani_attivi_in_mappa().all(func(a): return E.distanza(a.hex, h) > 1):
				_detona_us(h)
	if _st().has("faro") or _st().has("fuoco_visibile"):
		_illumina()
	if bool(p.regola("atterraggio_ph", false)) and not _st().get("nw_fiume", false):
		for a in p.americani_attivi_in_mappa():
			var r := E.riga(a.hex)
			var minimo := 99
			for h in p.terreno.esagoni:
				if E.riga(h) == r and p.terreno.tipo(h) == "stream":
					minimo = mini(minimo, E.colonna(h))
			if E.colonna(a.hex) < minimo and minimo < 99:
				_st().nw_fiume = true
	if not _st().entrati:
		for g in p.tedeschi_attivi():
			if p.in_mappa(g) and g.hex in deposito():
				_st().entrati = true
				p._log("info", "I commando sono entrati nel deposito.")
				break
	var tel = _st().get("telefono", null)
	if tel != null and int(tel) == int(p.s.condizione):
		for a in p.americani():
			if p.attivo(a) and a.hex == "J8":
				_st().erase("telefono")
				p.leggi("381", {"hex": "J8", "ids": [a.id]})
				break

func blocca_fine() -> bool:
	return attiva() and _st().fine_esplosivi and not _st().esplosivi.is_empty()

func righe_fine(righe: Array) -> int:
	if not attiva() or deposito().is_empty():
		return 0
	var distrutti: int = _st().deposito_distrutto.size()
	var intatti: int = deposito().size() - distrutti
	righe.append(["Esagoni del deposito intatti (%d)" % intatti, intatti])
	if distrutti > 0:
		righe.append(["Esagoni del deposito distrutti (%d)" % distrutti, -2 * distrutti])
	return intatti - 2 * distrutti

## Schieramento della Missione 16: almeno due uomini entro 10 esagoni da ogni angolo.
func verifica_schieramento() -> String:
	var angoli: Array = p.missione.get("regole", {}).get("angoli", [])
	for c in angoli:
		var n := 0
		for a in p.americani():
			if a.stato == "attivo" and a.hex != "" and E.distanza(a.hex, str(c)) <= 10:
				n += 1
		if n < 2:
			return "Servono almeno due soldati entro 10 esagoni dall’angolo %s." % c
	return ""
