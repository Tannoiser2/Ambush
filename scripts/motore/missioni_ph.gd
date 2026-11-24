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
		"relitto":
			_relitto(str(o.hex), str(o.nome))
		"leggi_entrando":
			if not p.s.has("da_leggere"):
				p.s.da_leggere = {}
			p.s.da_leggere[str(o.hex)] = str(o.p)
		"bottino":
			_bottino(str(o.hex) if o.get("hex") != null else str(ctx.get("hex", "")), o.oggetti)
		"collina_505":
			if not _st().has("collina"):
				_st().collina = "attesa"
				p._log("info", "Annotato: quando un soldato occupa la cima di una collina di livello 4 si legge il paragrafo 519.")
		"sergente_519":
			_sergente_519()
		"chiuse":
			_st().chiuse = {"hex": str(o.hex), "azioni": 0, "aperte": false}
			p.s.punti[str(o.hex)] = "comandi chiuse"
			p._log("info", "I comandi delle chiuse sono in %s: entra nell’esagono e usa l’azione «Apri le chiuse»." % o.hex)
		"piena":
			_st().piena = {"indice": 0, "fuori": false}
			p._log("info", "La piena parte dalla diga in N5 e scende il letto del fiume.")
			if not p.fase_round():
				p._inizia_round_da_attivazione([], {"adv": null, "two": [], "us_two": false}, "")
		"colonna_ph":
			_colonna(o, ctx)
		"attesa_598":
			_st().attesa_598 = int(p.s.get("round", {}).get("n", 0)) + 1 if p.fase_round() else 1
		"regole_fine_15":
			_st().pv_uscita = int(o.uscita)
			_st().fine_senza_tedeschi = true
		"inciampo_vigna":
			_inciampo_vigna()
		"macerie":
			p.s.modifiche[str(o.hex)] = "rubble"
			p.terreno.imposta_modifiche(p.s.modifiche)
		"radio_618":
			_st().radio_618 = int(_st().get("radio_618", 0)) + 1
			var nr: int = int(_st().radio_618)
			if nr <= 3:
				p._log("info", ["La radio gracchia: «Che diavolo state aspettando? Raggiungete J8 di corsa!»",
					"Il comandante minaccia di degradare il sergente.",
					"Ultimo avviso: senza la vittoria il sergente torna a casa caporale e tutta la squadra fa quattro settimane di corvé!"][nr - 1])
		"superstiti":
			_superstiti(o.ids, str(ctx.get("hex", "")))
		"ripiegamento_14":
			if not _st().get("ripiegamento", false):
				_st().ripiegamento = true
				_st().pv_uscita_us = 2
				p._log("info", "Ripiegamento: ogni soldato che esce dal bordo nord (Y1–Y19) vale 2 PV; gli incapacitati portati fuori non costano PV.")
		"artiglieria_383":
			var c: int = p.d10() + p.d10() + 2
			var r: int = p.d10() + p.d10()
			p._log("dado", "Artiglieria: colonna %d, riga %d." % [c, r])
			if c < 1 or c > 25 or r < 1 or r > 19:
				p._log("info", "Il colpo cade fuori dalla mappa.")
			else:
				p._op_artiglieria_esagoni(["%s%d" % [char(64 + c), r]])
		"pc_tutti":
			var riusciti := 0
			for a in p.americani_attivi_in_mappa():
				if p.controllo_pc(a, 0):
					riusciti += 1
					ctx.ultimo_pc = a.id
			p._esegui(o.ok if riusciti > 0 else o.ko, ctx)
		"treno_in_arrivo":
			if not p.fase_round():
				p._inizia_round_da_attivazione([], {"adv": "de", "two": [], "us_two": false}, "")
				_st().treno_round = 2
			else:
				_st().treno_round = int(p.s.round.get("n", 0)) + 1
			p._log("info", "Il treno arriverà all’inizio del Round %d, al posto del controllo degli eventi casuali." % int(_st().treno_round))
		"treno":
			_avvia_treno()
		"louvre":
			if not _st().get("louvre", false):
				_st().louvre = true
				p._esegui([{"op": "sighting", "s": 9}, {"op": "vp", "n": 10, "why": "tesori del Louvre"}], ctx)
		"cratere_hex":
			p.s.modifiche[str(o.hex)] = "crater"
			p.terreno.imposta_modifiche(p.s.modifiche)
		"reazione_nums":
			for num in o.nums:
				var gr: Dictionary = p.u("g%d" % int(num))
				if not gr.is_empty() and p.attivo(gr):
					gr.reazione = str(o.r)
			p._log("tedesco", "Reazione speciale %s per i tedeschi %s." % [str(o.r), ", ".join(o.nums.map(func(x): return str(int(x))))])
		"ferma_g":
			p.ia.ferma()
		"niente_controlli_round":
			_st().niente_controlli_round = true
		"resa_generale":
			for g in p.tedeschi_attivi():
				if p.attivo(g) and p.in_mappa(g):
					g.stato = "arreso"
					g.turni = 0
					g.slot = "inattivo"
			p._pv(5, "tutti i tedeschi si arrendono")
			_st().fine_modo = 1
			p._calcola_fine("obiettivo")
		"tedesco_sotto_ponte":
			_tedesco_sotto_ponte(ctx)
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
	if t.has("tedeschi_o_s6"):
		var in_mappa: bool = p.tedeschi_attivi().any(func(g): return p.attivo(g) and p.in_mappa(g))
		return (in_mappa and bool(p.s.avvistamenti[6])) == bool(t.tedeschi_o_s6)
	if t.has("ponti_distrutti"):
		return p.ponti().all(func(h): return not p.ponte_intatto(h)) == bool(t.ponti_distrutti)
	if t.has("ponte_ok"):
		return p.ponte_intatto(str(t.ponte_ok))
	if t.has("ponte_minato"):
		return _st().get("timer_ponti", {}).has(str(t.ponte_minato)) or int(p.ponte_stato(str(t.ponte_minato)).cariche) > 0
	if t.has("tutti_attivi_ponti"):
		var tutti: bool = p.americani().filter(func(a): return not a.get("senza_carta", false)).all(func(a): return p.attivo(a))
		return (tutti and p.ponti().all(func(h): return not p.ponte_intatto(h))) == bool(t.tutti_attivi_ponti)
	if t.has("ponte_s9"):
		return ponte_s9() == bool(t.ponte_s9)
	if t.has("fiume_allagato"):
		return bool(_st().get("piena", {}).get("fuori", false)) == bool(t.fiume_allagato)
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
	if attiva() and bool(p.regola("diga", false)):
		_prepara_15()
	if attiva() and bool(p.regola("fine_ponti_17", false)):
		_prepara_17()
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
	if attiva() and bool(p.missione.tedeschi.get(str(int(g.get("num", 0))), {}).get("un_turno", false)) and int(es.get("turni", 0)) > 1:
		return {"turni": 1, "panico": es.get("panico", false)}
	return es

func uscita(a: Dictionary, h: String) -> void:
	if not attiva():
		return
	if int(_st().get("pv_uscita_us", 0)) > 0 and E.colonna(h) == 24 and not a.get("superstite_ph", false) and p.attivo(a):
		p._pv(int(_st().pv_uscita_us), "%s esce dal bordo nord" % p.nome(a))
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
	p._log("info", "Nessun cane può riprendersi: vedi 485.")
	p.leggi("485", {})

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
	_avanza_piena()
	_timer_ponti()
	var nt := int(_st().get("treno_round", 0))
	if nt > 0 and int(p.s.round.get("n", 0)) >= nt:
		_st().treno_round = 0
		_st().salta_evento = true
		p.leggi("486", {})
	elif str(_st().get("treno", {}).get("stato", "")) == "attivo":
		_muovi_treno(12)
	var n598 := int(_st().get("attesa_598", 0))
	if n598 > 0 and int(p.s.round.get("n", 0)) >= n598 + 1:
		_st().attesa_598 = 0
		_st().salta_evento = true
		p.leggi("598", {})
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
	if str(_st().get("collina", "")) == "attesa":
		for a in p.americani_attivi_in_mappa():
			if p.terreno.quota(a.hex) >= 4 and str(a.get("veicolo", "")) == "":
				_st().collina = "fatto"
				p._log("info", "%s raggiunge la cima della collina in %s." % [p.nome(a), a.hex])
				p.leggi("519", {"hex": a.hex, "ids": [a.id]})
				break
	if int(_st().get("attesa_598", 0)) > 0 and p.fase_round():
		var g4: Dictionary = p.u("g4")
		var g6: Dictionary = p.u("g6")
		if not (p.attivo(g4) and p.in_mappa(g4)) and not (p.attivo(g6) and p.in_mappa(g6)):
			_st().attesa_598 = 0
			p._log("info", "Le motociclette sono fuori combattimento: arriva il resto della colonna.")
			p.leggi("598", {})
	if bool(p.regola("fine_ponti_17", false)):
		_controlla_17()
		if p.s.fase == "fine":
			return
	if bool(_st().get("fine_senza_tedeschi", false)) and int(p.s.condizione) >= 2 and p.s.fase != "fine" and not round_obbligati():
		var in_mappa: Array = p.tedeschi_attivi().filter(func(g): return p.attivo(g) and p.in_mappa(g))
		if in_mappa.is_empty() and int(_st().get("attesa_598", 0)) == 0:
			p._log("info", "Non restano tedeschi attivi in mappa: la missione termina.")
			p._calcola_fine("obiettivo")
			return
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

func niente_pv_incapacitati() -> bool:
	return attiva() and (bool(_st().get("fine_senza_tedeschi", false)) or int(_st().get("fine_modo", 0)) in [1, 2])

func niente_controlli_round() -> bool:
	return attiva() and bool(_st().get("niente_controlli_round", false))

func salta_evento() -> bool:
	if attiva() and bool(_st().get("salta_evento", false)):
		_st().salta_evento = false
		p._log("info", "Al posto del controllo degli eventi casuali arriva il resto della colonna (paragrafo 598).")
		return true
	return false

## Missione 15: i Round continuano finché la piena non è uscita dalla mappa.
func round_obbligati() -> bool:
	if not attiva():
		return false
	if str(_st().get("treno", {}).get("stato", "")) == "attivo" or int(_st().get("treno_round", 0)) > 0:
		return true
	var pn: Dictionary = _st().get("piena", {})
	return not pn.is_empty() and not bool(pn.get("fuori", false))

func blocca_fine() -> bool:
	return attiva() and _st().fine_esplosivi and not _st().esplosivi.is_empty()

func righe_fine(righe: Array) -> int:
	if not attiva():
		return 0
	var tot_s := 0
	for x in p.americani():
		if x.get("superstite_ph", false) and (x.stato == "uscito" or x.get("uscito", false)):
			righe.append(["Superstite %s portato in salvo" % x.id, 2])
			tot_s += 2
	if bool(p.regola("fine_ponti_17", false)):
		return tot_s + _righe_fine_17(righe)
	if deposito().is_empty():
		return tot_s
	var distrutti: int = _st().deposito_distrutto.size()
	var intatti: int = deposito().size() - distrutti
	righe.append(["Esagoni del deposito intatti (%d)" % intatti, intatti])
	if distrutti > 0:
		righe.append(["Esagoni del deposito distrutti (%d)" % distrutti, -2 * distrutti])
	return tot_s + intatti - 2 * distrutti

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

# ================================================================== Missione 15 «Ritorno a casa»
const LETTO_15 := ["N6", "O7", "P7", "Q8", "R8", "S9", "S10", "T10", "U11", "V11", "W12", "X12", "X13", "X14", "Y15"]
## Munizioni consumate prima della missione: perdita per dado 0–9 (-99: esaurite).
const MUN_CARICATORI := [0, 0, 0, -1, -1, -2, -2, -3, -3, -99]
const MUN_GRANATE := [0, 0, 0, 0, 0, -1, -1, -2, -99, -99]
const MUN_BAZOOKA := [0, 0, 0, 0, 0, 0, -1, -2, -3, -99]
const MUN_CARICHE := [0, 0, 0, 0, 0, 0, 0, 0, 0, -1]

## Diga in N5: vi si entra e se ne esce solo da O5 e M6.
func regole_terreno() -> void:
	if attiva() and bool(p.regola("diga", false)):
		p.terreno.accessi["N5"] = ["O5", "M6"]

func ponte_s9() -> bool:
	return str(p.s.modifiche.get("S9", "")) != "water"

func _prepara_15() -> void:
	for h in LETTO_15:
		if h != "S9":
			p.s.modifiche[h] = "cover"
	p.s.modifiche["N5"] = "clear"
	p.s.punti["N5"] = "diga"
	p.terreno.imposta_modifiche(p.s.modifiche)
	p._log("info", "La diga è in N5; il letto del fiume da N6 a Y15 è asciutto e vale come copertura (il ponte in S9 è intatto).")
	if bool(p.regola("munizioni_consumate", false)):
		for a in p.americani():
			for k in a.munizioni.keys():
				if int(a.munizioni[k]) <= 0:
					continue
				var tab: Array = MUN_GRANATE if k == "granata" else (MUN_BAZOOKA if k == "bazooka" else (MUN_CARICHE if k == "satchel" else MUN_CARICATORI))
				var d: int = p.d10()
				var perdita: int = int(tab[d])
				if perdita == 0:
					continue
				var prima := int(a.munizioni[k])
				a.munizioni[k] = 0 if perdita == -99 else maxi(0, prima + perdita)
				var cosa: String = "granate" if k == "granata" else ("razzi del bazooka" if k == "bazooka" else ("cariche" if k == "satchel" else "caricatori (" + str(T.ARMI.get(k, {}).get("breve", k)) + ")"))
				p._log("dado", "Munizioni consumate da %s, %s: dado %d → %d su %d." % [p.nome(a), cosa, d, int(a.munizioni[k]), prima])

func _relitto(h: String, nome: String) -> void:
	p.s.punti[h] = nome
	p._log("info", "%s in %s." % [nome, h])

func _bottino(h: String, oggetti: Array) -> void:
	if h == "":
		return
	var testi: Array = []
	for o in oggetti:
		if o.has("arma"):
			p._lascia_oggetto(h, {"tipo": str(o.arma), "inceppata": false, "rotta": false, "preparata": false, "catturata": false})
			testi.append(str(T.ARMI.get(str(o.arma), {}).get("nome", o.arma)))
		else:
			for i in int(o.get("n", 1)):
				p._lascia_oggetto(h, {"tipo": "mun:" + str(o.mun)})
			testi.append("%d × %s" % [int(o.get("n", 1)), "granata" if str(o.mun) == "granata" else ("razzo" if str(o.mun) == "bazooka" else "caricatore " + str(T.ARMI.get(str(o.mun), {}).get("breve", o.mun)))])
	p._log("info", "In %s si possono raccogliere: %s." % [h, ", ".join(testi)])

func _sergente_519() -> void:
	var a: Dictionary = p.u("A")
	if not a.is_empty() and p.attivo(a):
		var d: int = p.d10()
		var tot: int = d + int(a.PC)
		p._log("dado", "Il sergente valuta la situazione: %d + PC %d = %d." % [d, int(a.PC), tot])
		p.leggi("532" if tot >= 10 else "550", {})
	else:
		p.leggi("550", {})

## Colonna motorizzata: ogni mezzo con il suo autista (primo della lista) e i passeggeri, in reazione speciale W.
func _colonna(o: Dictionary, ctx: Dictionary) -> void:
	var h := str(o.hex)
	var coppie: Array = []
	for m in o.mezzi:
		coppie.append([int(m[1]), h])
		for x in m[2]:
			coppie.append([int(x), h])
	p._op_attiva({"op": "activate", "g": coppie, "stance": "crouching", "adv": "de", "two": o.get("two", []), "us_two": false,
		"aware": false, "reaction": str(o.get("reazione", "W")), "rounds": true}, ctx)
	p.s.imbarco = true
	for m in o.mezzi:
		var vid := "v%d" % int(m[1])
		if not p.veicoli.v(vid).is_empty():
			continue
		var veic: Dictionary = p.veicoli.crea(vid, str(m[0]), h, "de")
		for num in [int(m[1])] + Array(m[2]):
			var g: Dictionary = p.u("g%d" % int(num))
			if not g.is_empty() and p.attivo(g) and g.hex == h:
				p.veicoli.sali(g, veic)
		p._log("attivazione", "%s entra in %s con a bordo %s." % [p.veicoli.nome_art(veic), h, ", ".join(p.veicoli.occupanti(veic).map(func(x): return str(int(x.num))))])
	p.s.imbarco = false
	_st().colonna = true

func _inciampo_vigna() -> void:
	if _st().get("inciampo", false):
		return
	var lista: Array = p.americani_attivi_in_mappa().filter(func(a): return a.postura == "standing" and p.terreno.tipo(a.hex) == "vineyard")
	if lista.is_empty():
		p._log("info", "Nessun soldato in piedi in una vigna: nessun evento.")
		return
	_st().inciampo = true
	var a: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	p._log("info", "%s inciampa tra i filari e cade." % p.nome(a))
	var rd: int = p.d10()
	var l: String = T.lettera_danno(T.ARMI.pistol.danni, rd)
	p._log("dado", "Danno della caduta (colonna Pistola): %d → %s" % [rd, p._nome_danno(l)])
	p._applica_danno(a, l, {})

## Missione 14: superstiti della squadra 2, incapacitati e senza carta.
func _superstiti(ids: Array, h: String) -> void:
	if h == "" or _st().get("superstiti_fatto", false):
		return
	_st().superstiti_fatto = true
	for id in ids:
		if not p.u(str(id)).is_empty():
			continue
		var x: Dictionary = p._nuovo_americano({"id": str(id), "nome": "Superstite", "IN": 0, "PC": 0, "WS": 0, "DS": 0, "MPA": 0,
			"comandante": false, "porte": [], "munizioni": {}})
		x.stato = "incapacitato"
		x.hex = h
		x.postura = "prone"
		x.senza_carta = true
		x.ferito = true
		x.superstite_ph = true
		p.s.unita[str(id)] = x
		p._fx("compare", {"id": str(id), "a": h, "amico": true})
	p._log("info", "Superstiti in %s: %s. Trascinali fuori dal bordo nord con la squadra: 2 PV ciascuno." % [h, ", ".join(ids)])

## Missione 14: la squadra entra in Y7 sulle due jeep, quattro uomini per jeep.
func dopo_ingresso(esagoni: Array) -> void:
	if not attiva() or int(p.regola("jeep_caricate", 0)) <= 0 or p.s.get("veicoli", {}).has("vjeep1"):
		return
	var h: String = str(esagoni[0])
	var squadra: Array = p.americani().filter(func(a): return p.attivo(a) and a.hex == h)
	p.s.imbarco = true
	for i in int(p.regola("jeep_caricate", 0)):
		var v: Dictionary = p.veicoli.crea("vjeep%d" % (i + 1), "jeep", h, "us")
		v.nome = "Jeep %d" % (i + 1)
		for k in 4:
			var j: int = i * 4 + k
			if j < squadra.size():
				p.veicoli.sali(squadra[j], v)
		p._log("info", "La %s entra in %s con %s." % [v.nome, h, ", ".join(p.veicoli.occupanti(v).map(func(x): return x.id))])
	p.s.imbarco = false

func radio_portata() -> bool:
	return attiva() and bool(p.regola("radio_portata_ph", false))

func radio_funziona() -> bool:
	var a: Dictionary = p.u("A")
	return not a.is_empty() and p.attivo(a) and p.in_mappa(a)

func tedesco_uscito(x: Dictionary, h: String) -> void:
	if not attiva() or int(_st().get("pv_uscita", 0)) <= 0 or h == "":
		return
	p._pv(-int(_st().pv_uscita), "%s esce dalla mappa" % p.nome(x))

## Chiuse della diga: 4 azioni nei Round (anche di più soldati); nelle Operazioni un controllo degli eventi casuali.
func apri_chiuse(a: Dictionary) -> String:
	var ch: Dictionary = _st().get("chiuse", {})
	if ch.is_empty() or a.hex != str(ch.hex):
		return "I comandi delle chiuse non sono in questo esagono."
	if bool(ch.aperte):
		return "Le chiuse sono già aperte."
	if p.fase_round():
		ch.azioni = int(ch.azioni) + 1
		p._log("azione", "%s lavora ai comandi delle chiuse (%d/4)." % [p.nome(a), int(ch.azioni)])
		if int(ch.azioni) < 4:
			return ""
	else:
		p._log("azione", "%s manovra i comandi delle chiuse: intanto si fa un controllo degli eventi casuali." % p.nome(a))
		p.evento_casuale({"hex": a.hex})
	ch.aperte = true
	p.s.punti.erase(str(ch.hex))
	p.leggi("565", {"hex": a.hex})
	return ""

func puo_aprire_chiuse(a: Dictionary) -> bool:
	var ch: Dictionary = _st().get("chiuse", {})
	return attiva() and not ch.is_empty() and not bool(ch.aperte) and a.get("hex", "") == str(ch.hex)

func _avanza_piena() -> void:
	var pn: Dictionary = _st().get("piena", {})
	if pn.is_empty() or bool(pn.get("fuori", false)):
		return
	for k in 4:
		var i := int(pn.indice)
		if i >= LETTO_15.size():
			pn.fuori = true
			p.s.punti.erase(LETTO_15[LETTO_15.size() - 1])
			p._log("info", "La piena esce dalla mappa.")
			p.leggi("542", {})
			return
		var h: String = LETTO_15[i]
		pn.indice = i + 1
		p.s.modifiche[h] = "water"
		for x in p.s.unita.values():
			if str(x.get("hex", "")) == h and x.stato in ["attivo", "incapacitato"]:
				x.stato = "morto"
				p._log("danno", "%s è travolto dalla piena." % p.nome(x))
		for v in p.veicoli.in_esagono(h):
			if v.stato == "attivo":
				p.veicoli.disabilita(v, "travolto dalla piena")
		if h == "S9":
			p._log("info", "La piena travolge il ponte in S9.")
		if i > 0:
			p.s.punti.erase(LETTO_15[i - 1])
		p.s.punti[h] = "piena"
	p.terreno.imposta_modifiche(p.s.modifiche)
	p._log("info", "La piena avanza fino a %s." % LETTO_15[int(pn.indice) - 1])

# ================================================================== Missione 17 «Sul filo del rasoio»
func _prepara_17() -> void:
	for h in p.regola("macerie_iniziali", []):
		p.s.modifiche[str(h)] = "rubble"
	p.terreno.imposta_modifiche(p.s.modifiche)
	var n := int(p.regola("cariche_gratis", 0))
	var dati: Array = []
	for i in n:
		var squadra: Array = p.americani().filter(func(a): return p.porte_usate(a) < p.porte_massime(a))
		if squadra.is_empty():
			break
		squadra.sort_custom(func(a, b): return p.porte_usate(a) < p.porte_usate(b))
		var a: Dictionary = squadra[0]
		a.armi.append({"tipo": "satchel", "inceppata": false, "rotta": false, "preparata": false, "catturata": false})
		dati.append(a.id)
	p._log("info", "Gli edifici a ovest del fiume sono macerie. Cariche da demolizione gratis a: %s." % ", ".join(dati))

## Piazzate le cariche necessarie, il timer fa saltare il ponte all’inizio del Round indicato (0: nelle Operazioni, appena la squadra si allontana).
func arma_ponte(h: String, rounds: int) -> void:
	var tp: Dictionary = _st().get("timer_ponti", {})
	var n := int(p.s.get("round", {}).get("n", 0)) if p.fase_round() else 0
	tp[h] = {"round": n + rounds if rounds > 0 else 0}
	_st().timer_ponti = tp
	if rounds > 0:
		p._log("azione", "Timer del ponte in %s: salta all’inizio del Round %d." % [h, n + rounds])
	else:
		p._log("azione", "Cariche del ponte in %s innescate: saltano appena la squadra si è allontanata." % h)

func ponte_armato(h: String) -> bool:
	return _st().get("timer_ponti", {}).has(h)

func _timer_ponti() -> void:
	var tp: Dictionary = _st().get("timer_ponti", {})
	var n := int(p.s.round.get("n", 0))
	for h in tp.keys():
		if int(tp[h].round) > 0 and n >= int(tp[h].round):
			tp.erase(h)
			p.distruggi_ponte(h, "cariche a tempo")

func _tedesco_sotto_ponte(ctx: Dictionary) -> void:
	var g: Dictionary = p.u(str(ctx.get("g", "")))
	if g.is_empty():
		return
	var h: String = g.hex
	var us: Array = p.unita_in(h, "us").filter(func(x): return p.attivo(x))
	if p.ponti().has(h) and (ponte_armato(h) or int(p.ponte_stato(h).cariche) > 0):
		if not us.is_empty():
			p.ia._assalta(us[0])
		else:
			var st: Dictionary = p.ponte_stato(h)
			st.cariche = maxi(0, int(st.cariche) - 1)
			_st().get("timer_ponti", {}).erase(h)
			p._log("tedesco", "Il %s getta nel fiume una carica del ponte in %s: il ponte non è più minato." % [p.nome(g), h])
		p.ia.ferma()
	else:
		ctx.verso = "Q10"
		p.ia.entra_da_paragrafo(ctx, "Q10")
		g.reazione = "Q"

# ------------------------------------------------------------------ il treno
func _avvia_treno() -> void:
	if _st().has("treno"):
		return
	var vagoni := ["vagone merci", "vagone merci", "vagone merci", "cisterna"]
	for i in range(vagoni.size() - 1, 0, -1):
		var j: int = p.rng.randi_range(0, i)
		var x = vagoni[i]
		vagoni[i] = vagoni[j]
		vagoni[j] = x
	_st().treno = {"pezzi": ["locomotiva"] + vagoni, "idx": 0, "stato": "attivo"}
	if not p.fase_round():
		p._inizia_round_da_attivazione([], {"adv": "de", "two": [], "us_two": false}, "")
	_segna_treno()
	p._log("info", "Il treno entra in %s: locomotiva, poi %s." % [_binario()[0], ", ".join(vagoni)])

func _binario() -> Array:
	return p.regola("binario", [])

func _posizioni_treno() -> Array:
	var tr: Dictionary = _st().get("treno", {})
	var out: Array = []
	var b := _binario()
	for i in tr.pezzi.size():
		var k: int = int(tr.idx) - i
		out.append(b[k] if k >= 0 and k < b.size() else "")
	return out

func _segna_treno() -> void:
	for h in p.s.punti.keys():
		if str(p.s.punti[h]) in ["locomotiva", "vagone merci", "cisterna"]:
			p.s.punti.erase(h)
	var tr: Dictionary = _st().get("treno", {})
	var pos := _posizioni_treno()
	for i in pos.size():
		if pos[i] != "":
			p.s.punti[pos[i]] = str(tr.pezzi[i]) if tr.stato == "attivo" else ("vagone rovesciato" if tr.pezzi[i] != "cisterna" else "cisterna rovesciata")

func _muovi_treno(passi: int) -> void:
	var tr: Dictionary = _st().treno
	var b := _binario()
	for k in passi:
		tr.idx = int(tr.idx) + 1
		var pos := _posizioni_treno()
		if pos.all(func(x): return x == ""):
			tr.stato = "uscito"
			_segna_treno()
			p._log("info", "Il treno esce dalla mappa.")
			_fine_treno()
			return
		for i in pos.size():
			var h: String = pos[i]
			if h == "":
				continue
			if p.ponti().has(h) and not p.ponte_intatto(h):
				_deraglia()
				return
			for a in p.unita_in(h, "us").filter(func(x): return p.attivo(x)):
				if p.controllo_pc(a, 0):
					for v in E.vicini(h):
						if not (v in b) and p.terreno.costo_movimento(h, v) >= 0:
							a.hex = v
							p._log("info", "%s si butta di lato in %s." % [p.nome(a), v])
							break
				else:
					p._uccidi(a, "travolto dal treno")
	_segna_treno()
	p._log("info", "Il treno avanza: la locomotiva è in %s." % (_posizioni_treno()[0] if _posizioni_treno()[0] != "" else "fuori mappa"))

func _deraglia() -> void:
	var tr: Dictionary = _st().treno
	tr.idx = int(tr.idx) - 1
	tr.stato = "deragliato"
	_segna_treno()
	p._fx("esplosione", {"a": _posizioni_treno()[0], "grande": true})
	p._log("combattimento", "Il treno entra nel ponte distrutto e deraglia! Locomotiva e vagoni si rovesciano.")
	var pos := _posizioni_treno()
	if not p.s.has("da_leggere"):
		p.s.da_leggere = {}
	for i in pos.size():
		if pos[i] != "" and str(tr.pezzi[i]) == "vagone merci":
			p.s.da_leggere[pos[i]] = "595"
	_fine_treno()

func _fine_treno() -> void:
	if int(p.s.condizione) < 3:
		p.cambia_condizione(3)

# ------------------------------------------------------------------ fine della missione
func _controlla_17() -> void:
	# il 23 assiste la mitragliatrice del 22 finché il 22 è attivo nel suo esagono, poi passa alla reazione X
	for g in p.tedeschi():
		var ass := int(p.missione.tedeschi.get(str(int(g.num)), {}).get("assiste", 0))
		if ass > 0 and p.attivo(g) and p.in_mappa(g) and str(g.get("reazione", "")) == "":
			var mg: Dictionary = p.u("g%d" % ass)
			if mg.is_empty() or not p.attivo(mg) or mg.hex != g.hex:
				g.reazione = "X"
				p._log("tedesco", "Il %s non ha più la mitragliatrice da assistere: reazione speciale X." % p.nome(g))
	# borsa sigillata del corriere SS (53)
	var g53: Dictionary = p.u("g53")
	if not g53.is_empty() and not p.attivo(g53) and str(g53.get("hex", "")) != "" and not _st().get("borsa", false):
		_st().borsa = true
		p._lascia_oggetto(g53.hex, {"tipo": "documenti", "n": 0, "par": "652"})
		p._log("info", "Il corriere SS è fuori combattimento: la sua borsa sigillata è a terra in %s." % g53.hex)
	# cariche innescate nelle Operazioni
	if not p.fase_round():
		var tp: Dictionary = _st().get("timer_ponti", {})
		for h in tp.keys():
			if int(tp[h].round) == 0 and p.americani_attivi_in_mappa().all(func(a): return E.distanza(a.hex, h) > 1):
				tp.erase(h)
				p.distruggi_ponte(h, "cariche innescate")
	if int(p.s.condizione) < 3 or p.s.fase == "fine" or round_obbligati():
		return
	var g_attivi: Array = p.tedeschi_attivi().filter(func(g): return p.attivo(g) and p.in_mappa(g))
	var us: Array = p.americani_attivi_in_mappa()
	if us.is_empty():
		return
	var tutti_fatti: bool = p.ponti().all(func(h): return not p.ponte_intatto(h) or ponte_armato(h))
	var cariche := 0
	for a in p.americani():
		cariche += a.armi.filter(func(w): return w.tipo == "satchel").size()
	if g_attivi.is_empty() and (tutti_fatti or cariche == 0):
		_st().fine_modo = 1
		p._log("info", "Nessun tedesco attivo e tutti i ponti minati o distrutti (o finite le cariche): la missione termina.")
		p._calcola_fine("obiettivo")
		return
	if p.ponti().all(func(h): return not p.ponte_intatto(h)):
		var vista := false
		for a in us:
			for g in g_attivi:
				if p.vede_unita(a, g) or p.vede_unita(g, a):
					vista = true
		if not vista:
			_st().fine_modo = 2
			p._log("info", "I tre ponti sono distrutti e nessuno si vede più: la missione termina.")
			p._calcola_fine("obiettivo")

func _righe_fine_17(righe: Array) -> int:
	var tot := 0
	var distrutti := 0
	for h in p.ponti():
		if not p.ponte_intatto(h) or ponte_armato(h) or int(_st().get("fine_modo", 0)) == 1:
			distrutti += 1
	if distrutti > 0:
		righe.append(["Ponti distrutti (%d)" % distrutti, 10 * distrutti])
		tot += 10 * distrutti
	var perdite := 0
	for g in p.tedeschi():
		if g.stato in ["morto", "incapacitato", "catturato", "arreso"] and not g.get("cane", false):
			perdite += 1
	if perdite > 0:
		righe.append(["Tedeschi uccisi, catturati o incapacitati (%d)" % perdite, perdite])
		tot += perdite
	return tot
