extends RefCounted
## Regole e operazioni dei paragrafi delle missioni di Purple Heart (13–18).
## Per ora: Missione 16 «In guardia» (deposito di carburante, commando con esplosivi, battelli d’assalto).

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

var p  # Partita
var m18  # Missione 18 «Il mattino dopo»
var berserk  # 655/689: soldati fuori di testa

func _init(partita) -> void:
	p = partita
	m18 = preload("res://scripts/motore/missione18_ph.gd").new(partita, self)
	berserk = preload("res://scripts/motore/berserk_ph.gd").new(partita)

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
	if str(o.op).begins_with("m18_"):
		return m18.op(o, ctx)
	match str(o.op):
		"berserk_de":
			berserk.tedesco(_st())
		"berserk_us":
			berserk.americano(_st())
		"artiglieria_dispersione":
			# Diagramma della dispersione dell’artiglieria (Purple Heart, pagina 31): percentuale, bersaglio 00–09.
			var r100: int = p.d10() * 10 + p.d10()
			var hd: String = p.mo.dispersione(str(o.hex), r100)
			p._log("dado", "Artiglieria su %s: percentuale %02d → %s." % [str(o.hex), r100, hd if hd != "" else "fuori mappa"])
			if hd != "":
				p._op_artiglieria_esagoni([hd])
			else:
				p._log("info", "Il colpo cade fuori mappa: si sente un’esplosione lontana.")
		"sentinella_e11":
			_sentinella_e11(ctx)
		"relitto_qui":
			_relitto(str(ctx.get("hex", "")), str(o.nome))
		"muro_sfondato":
			if not p.s.has("muri_sfondati"):
				p.s.muri_sfondati = []
			p.s.muri_sfondati.append([str(o.a), str(o.b)])
			p.terreno.muri_sfondati = p.s.muri_sfondati
			p._log("info", "Il muro tra %s e %s è sfondato: si attraversa come un lato libero." % [str(o.a), str(o.b)])
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
				var vs: Dictionary = p.veicoli.crea("vscialuppa", "scialuppa", "I14", "us")
				vs.nome = "Scialuppa"
				p._log("info", "La scialuppa rovesciata è in I14. Si porta con quattro uomini in piedi (2 esagoni per turno) fino a una spiaggia o una banchina, dove si vara; a bordo si rema di 2 esagoni per turno in due. Uscendo dal bordo ovest in scialuppa si guadagnano 10 PV.")
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
			if not _st().has("camion"):
				_st().camion = {"arrivati": 0, "attivo": "", "carico": 0}
				_nuovo_camion()
		"soldato_j":
			_soldato_j()
		_:
			return false
	return true

func test(t: Dictionary, ctx: Dictionary) -> Variant:
	var t18 = m18.test(t, ctx)
	if t18 != null:
		return t18
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
	# 503: una carica lanciata in un esagono del binario lo interrompe.
	if attiva() and tipo == "satchel" and h in _binario() and _st().has("treno"):
		distruggi_binario(h)

## 414.2: un esagono del deposito in fiamme.
func in_fiamme(h: String) -> bool:
	return attiva() and h in _st().get("deposito_distrutto", [])

## 414.2: chi entra in un esagono del deposito in fiamme fa un controllo di percezione: se fallisce muore; se riesce passa
## subito nell’esagono successivo, prono, e il suo turno finisce. Restituisce l’esagono d’uscita ("" se è morto).
func attraversa_fiamme(x: Dictionary, da: String, dopo: String) -> String:
	var h: String = x.hex
	if not p.controllo_pc(x, 0, "attraversare il deposito in fiamme"):
		p._uccidi(x, "nel deposito in fiamme")
		return ""
	var verso := dopo
	if verso == "" or not E.adiacenti(h, verso) or in_fiamme(verso) or p.terreno.costo_movimento(h, verso) < 0:
		verso = ""
		var dir: int = E.direzione(da, h) if da != "" else -1
		var dritto: String = E.vicino(h, dir) if dir >= 0 else ""
		var candidati: Array = ([dritto] if dritto != "" else []) + E.vicini(h)
		for v in candidati:
			if v != "" and v != da and not in_fiamme(v) and p.terreno.costo_movimento(h, v) >= 0:
				verso = v
				break
	if verso == "":
		verso = da
	x.hex_prec = h
	x.hex = verso
	x.postura = "prone"
	p._log("info", "%s attraversa le fiamme e si getta a terra in %s." % [p.nome(x), verso])
	p._fx("muovi", {"ids": [x.id], "da": h, "a": verso})
	return verso

## 501: il soldato J (carta US 04, guardia del deposito) in piedi in V12: da ora fa parte della squadra, consapevole e in comando nel Round 1.
func _soldato_j() -> void:
	if not p.u("J").is_empty():
		return
	var d := {"id": "J", "nome": "Guardia del deposito", "IN": 1, "PC": 3, "WS": -2, "DS": 0, "MPA": 3, "comandante": false,
		"porte": ["sar"], "munizioni": {"sar": 4}}
	var j: Dictionary = p._nuovo_americano(d)
	j.stato = "attivo"
	j.hex = "V12"
	j.postura = "standing"
	j.consapevole = true
	j.comando_r1 = true
	p.s.unita["J"] = j
	if p.fase_round() and int(p.s.round.get("n", 0)) <= 1:
		p.s.round.consapevole_extra = true
	p._log("info", "La guardia del deposito J (fucile semiautomatico, 4 caricatori) è in piedi in V12 e si unisce alla squadra.")
	p._fx("compare", {"id": "J", "a": "V12", "amico": true})

# ------------------------------------------------------------------ 717: i camion del carburante (carta US 05)
const CAMION_INGRESSO := "A3"
const CAMION_CARICO := "U14"

func _nuovo_camion() -> void:
	var c: Dictionary = _st().camion
	if int(c.arrivati) >= 3:
		p._log("info", "Tutti e tre i camion sono passati.")
		return
	if CAMION_CARICO in _st().deposito_distrutto:
		p._log("info", "Il deposito in U14 è distrutto: i tedeschi hanno impedito il rifornimento, non arrivano altri camion.")
		c.arrivati = 3
		return
	c.arrivati = int(c.arrivati) + 1
	var id := "T%d" % int(c.arrivati)
	var d := {"id": id, "nome": "Camionista", "IN": 1, "PC": 0, "WS": -2, "DS": 6, "MPA": 3, "comandante": false,
		"porte": ["pistol"], "munizioni": {"pistol": 2}}
	var a: Dictionary = p._nuovo_americano(d)
	a.stato = "attivo"
	a.hex = CAMION_INGRESSO
	a.postura = "crouching"
	a.consapevole = true
	a.autista_camion = true
	a.lettera = "AA"
	p.s.unita[id] = a
	var v: Dictionary = p.veicoli.crea("vcamion%d" % int(c.arrivati), "camion", CAMION_INGRESSO, "us")
	v.nome = "Camion %d" % int(c.arrivati)
	v.carico = false
	v.azioni_carico = 0
	p.s.imbarco = true
	p.veicoli.sali(a, v)
	p.s.imbarco = false
	c.attivo = id
	p._log("info", "Il %s (autista %s) entra in %s: va riempito in U14 (4 azioni) e riportato fuori da A3." % [v.nome, id, CAMION_INGRESSO])
	p._fx("compare", {"id": id, "a": CAMION_INGRESSO, "amico": true})

func camion_di(a: Dictionary) -> Dictionary:
	var v: Dictionary = p.veicoli.di(a)
	return v if not v.is_empty() and v.modello == "camion" else {}

func puo_caricare(a: Dictionary) -> bool:
	var v := camion_di(a)
	return attiva() and not v.is_empty() and p.veicoli.attivo(v) and v.hex == CAMION_CARICO and not v.get("carico", false) \
		and not (CAMION_CARICO in _st().deposito_distrutto)

## Un’azione di carico (4 in tutto); nelle Operazioni il carico si completa con un controllo degli eventi casuali.
func carica_camion(a: Dictionary) -> String:
	if not puo_caricare(a):
		return "Il camion si carica solo in U14, con il deposito intatto."
	var v := camion_di(a)
	if not p.fase_round():
		v.azioni_carico = 4
		p.evento_casuale({"hex": v.hex, "ids": [a.id]})
	else:
		v.azioni_carico = int(v.azioni_carico) + 1
	p._log("azione", "Rifornimento del %s: %d azioni su 4." % [v.nome, mini(4, int(v.azioni_carico))])
	if int(v.azioni_carico) >= 4:
		v.carico = true
		p.s.punti[CAMION_CARICO] = "carburante caricato"
		p._log("info", "Il %s è pieno di carburante: riportalo fuori da A3." % v.nome)
	return ""

## Il camion esce da A3: +2 PV se carico; poi arriva il successivo.
func camion_uscito(a: Dictionary) -> void:
	var v := camion_di(a)
	if v.is_empty():
		return
	if v.get("carico", false):
		p._pv(2, "%s esce carico di carburante" % v.nome)
		_st().camion.carico = int(_st().camion.get("carico", 0)) + 1
	v.stato = "uscito"
	v.hex = ""
	_nuovo_camion()

## Camion fuori uso: −2 PV e arriva il successivo.
func camion_fuori_uso(v: Dictionary) -> void:
	if not attiva() or v.get("modello", "") != "camion" or v.get("contato", false):
		return
	v.contato = true
	p._pv(-2, "%s messo fuori uso" % v.nome)
	for x in p.veicoli.occupanti(v):
		x.autista_camion = false
	_nuovo_camion()

func righe_camion(righe: Array) -> int:
	if not _st().has("camion"):
		return 0
	for v in p.veicoli.tutti():
		if v.modello == "camion" and p.veicoli.attivo(v) and v.get("carico", false) and str(v.hex) != "":
			righe.append(["Camion carico ancora in mappa", 1])
			return 1
	return 0

## 432: tiro americano mancato contro un tedesco nel battello d’assalto: dado dispari, colpito il battello; penetrazione leggera =
## danneggiato (affonda all’inizio del prossimo Round), media o pesante = distrutto con tutti gli occupanti.
func tiro_mancato_barca(b: Dictionary, arma: String) -> void:
	var bid := str(b.get("barca", ""))
	if not attiva() or bid == "" or not _st().barche.has(bid):
		return
	var bc: Dictionary = _st().barche[bid]
	bc.colpita = true
	var d: int = p.d10()
	if d % 2 == 0:
		p._log("dado", "Colpo mancato sul battello: %d, pari → nessun effetto." % d)
		return
	var rp: int = p.d10()
	var pen: String = T.penetrazione(arma, rp)
	p._log("dado", "Colpo mancato sul battello: %d, dispari → colpito; penetrazione %d → %s." % [d, rp, {"-": "nessuna", "L": "leggera", "M": "media", "H": "pesante"}[pen]])
	if pen == "L":
		if not bc.get("danneggiata", false):
			bc.danneggiata = true
			bc.affonda_round = int(p.s.get("round", {}).get("n", 0)) + 1
			p._log("danno", "Il battello d’assalto è danneggiato: affonderà all’inizio del prossimo Round.")
	elif pen != "-":
		affonda_barca(bid, true, "distrutto dal colpo")

## 432.6: il bazooka spara al battello stesso (mezzo piccolo allo scoperto): qualunque penetrazione lo affonda e gli occupanti
## tirano sulla colonna «granata dentro».
func bazooka_su_barca(bid: String) -> void:
	for g in occupanti(bid):
		p._danno_esplosione(g, T.GRANATA_DENTRO)
	affonda_barca(bid, false, "colpito dal bazooka")

## Il battello affonda: gli occupanti finiscono proni nell’esagono di sbarco della carta (o muoiono se distrutto).
func affonda_barca(bid: String, uccidi: bool, perche: String) -> void:
	var bc: Dictionary = _st().barche.get(bid, {})
	if bc.is_empty():
		return
	var h: String = str(bc.hex)
	var sbarco: String = _sbarco_di(h)
	p._log("danno", "Il battello d’assalto in %s affonda (%s)." % [h, perche])
	p._fx("esplosione", {"a": h})
	for g in occupanti(bid):
		g.erase("barca")
		if uccidi:
			p._uccidi(g, "nel battello distrutto")
			continue
		if sbarco != "":
			g.hex_prec = g.hex
			g.hex = sbarco
		g.postura = "prone"
		g.turni = 0
		if p.fase_round():
			g.slot = "completo"
		p._log("tedesco", "Il %s raggiunge la riva in %s, a terra." % [p.nome(g), g.hex])
	var lista: Array = p.s.oggetti.get(h, []).filter(func(x): return not (x.get("tipo", "") == "barca" and x.get("id", "") == bid))
	if lista.is_empty():
		p.s.oggetti.erase(h)
	else:
		p.s.oggetti[h] = lista
	_st().barche.erase(bid)

## Esagono di sbarco indicato dalla carta Condizione per il battello in h (paragrafo con l’op «barca»).
func _sbarco_di(h: String) -> String:
	var rif: String = p.movimento_rosso(h)
	if rif.is_valid_int() and p.paragrafi.has(rif):
		for o in p.paragrafi[rif].ops:
			if str(o.get("op", "")) == "barca" and str(o.get("sbarco", "")) != "":
				return str(o.sbarco)
	for v in E.vicini(h):
		if not (p.terreno.tipo(v) in ["stream", "water"]) and p.terreno.costo_movimento(h, v) >= 0:
			return v
	return ""

func affonda_barche_danneggiate() -> void:
	if not attiva():
		return
	var n := int(p.s.get("round", {}).get("n", 0))
	for bid in _st().barche.keys():
		var bc: Dictionary = _st().barche[bid]
		if bc.get("danneggiata", false) and n >= int(bc.get("affonda_round", 0)):
			affonda_barca(bid, false, "danneggiato, imbarca acqua")

## Un tiro mancato contro un tedesco nel deposito: 0–3 il carburante esplode (414).
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
	if m18.attiva():
		m18.prepara()
	if not attiva() or not bool(p.regola("atterraggio_ph", false)):
		return
	var cassa: Dictionary = _prepara_cassa_lancio()
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
	_cassa_lancio(cassa, terreni)
	if persi > 0:
		p._pv(-2 * persi, "soldati persi nel lancio")

## Missione 13: niente fucili semiautomatici né mitragliatrici medie; ogni soldato si lancia con una sola casella d’armi e
## tutte le sue munizioni; bazooka, BAR, cariche e razzi vanno nella cassa (al massimo 4 caselle d’armi e 8 di munizioni).
func _prepara_cassa_lancio() -> Dictionary:
	var cassa := {"armi": [], "mun": {}}
	var porte := 0
	var scatole := 0
	for a in p.americani():
		for w in a.armi.duplicate():
			if w.tipo == "sar":
				w.tipo = "carbine"
				a.munizioni["carbine"] = int(a.munizioni.get("carbine", 0)) + int(a.munizioni.get("sar", 0))
				a.munizioni.erase("sar")
				p._log("info", "%s: niente fucili semiautomatici nel lancio, prende una carabina." % p.nome(a))
			elif w.tipo == "mmg":
				a.armi.erase(w)
				a.munizioni.erase("mmg")
	for a in p.americani():
		for w in a.armi.duplicate():
			if not (w.tipo in ["bazooka", "ar", "satchel"]):
				continue
			a.armi.erase(w)
			var pw: int = int(T.ARMI[w.tipo].get("porte", 1))
			if porte + pw <= 4:
				porte += pw
				cassa.armi.append({"arma": w, "da": a.id})
			else:
				p._log("info", "La cassa è piena: %s di %s resta a terra." % [T.ARMI[w.tipo].nome.to_lower(), p.nome(a)])
			for k in ([w.tipo] if w.tipo != "satchel" else []):
				var n: int = int(a.munizioni.get(k, 0))
				a.munizioni.erase(k)
				var entra: int = mini(n, 8 - scatole)
				if entra > 0 and porte <= 4 and cassa.armi.any(func(x): return x.arma == w):
					cassa.mun[k] = int(cassa.mun.get(k, 0)) + entra
					cassa.mun_da = cassa.get("mun_da", {})
					cassa.mun_da[k] = a.id
					scatole += entra
		# chi resta senz’armi si lancia con una carabina (una casella d’armi)
		if a.armi.filter(func(w): return T.ARMI.get(w.tipo, {}).has("gittate")).is_empty():
			a.armi.append({"tipo": "carbine", "inceppata": false, "rotta": false, "preparata": false, "catturata": false})
			a.munizioni["carbine"] = maxi(int(a.munizioni.get("carbine", 0)), 4)
		# una sola casella d’armi addosso durante il lancio
		while porte_lancio(a) > 1:
			var w2: Dictionary = a.armi.back()
			a.armi.erase(w2)
	var nomi: Array = cassa.armi.map(func(x): return T.ARMI[x.arma.tipo].nome.to_lower())
	p._log("info", "Nella cassa delle armi: %s; munizioni: %s." % [", ".join(nomi) if not nomi.is_empty() else "niente", JSON.stringify(cassa.mun)])
	return cassa

func porte_lancio(a: Dictionary) -> int:
	var n := 0
	for w in a.armi:
		n += int(T.ARMI.get(w.tipo, {}).get("porte", 1))
	return n

## Dove atterra la cassa: nel fiume si perde; altrimenti 0–8 la squadra la trova (9 persa). Il contenuto, e le armi di chi è
## stato messo fuori combattimento dal lancio (non annegato), va a chi ha caselle libere, prima al proprietario.
func _cassa_lancio(cassa: Dictionary, terreni: Array) -> void:
	var t: String = terreni[p.d10()]
	var trovata := false
	if t == "fiume":
		p._log("dado", "La cassa delle armi finisce nel fiume: persa con tutto il contenuto.")
	else:
		var c: int = p.d10()
		trovata = c <= 8
		p._log("dado", "La cassa delle armi atterra (%s): dado %d → %s." % [t, c, "la squadra la trova" if trovata else "perduta"])
	var pool: Array = []
	var mun := {}
	if trovata:
		pool = cassa.armi.duplicate()
		mun = cassa.mun.duplicate()
	for a in p.americani():
		if a.stato == "incapacitato":
			for w in a.armi:
				pool.append({"arma": w, "da": ""})
			for k in a.munizioni:
				mun[k] = int(mun.get(k, 0)) + int(a.munizioni[k])
			a.armi = []
			a.munizioni = {}
	var squadra: Array = p.americani().filter(func(a): return a.stato != "morto" and a.stato != "incapacitato")
	if squadra.is_empty():
		return
	for x in pool:
		var w: Dictionary = x.arma
		var pw: int = int(T.ARMI[w.tipo].get("porte", 1))
		var chi: Dictionary = p.u(str(x.da))
		if chi.is_empty() or not (chi in squadra) or p.porte_usate(chi) + pw > p.porte_massime(chi):
			chi = {}
			for a in squadra:
				if p.porte_usate(a) + pw <= p.porte_massime(a):
					chi = a
					break
		if chi.is_empty():
			p._log("info", "Nessuno può portare %s: resta indietro." % T.ARMI[w.tipo].nome.to_lower())
			continue
		chi.armi.append(w)
		p._log("info", "%s prende %s." % [p.nome(chi), T.ARMI[w.tipo].nome.to_lower()])
	for k in mun:
		var pref: Dictionary = p.u(str(cassa.get("mun_da", {}).get(k, "")))
		var dest: Array = squadra.filter(func(a): return a.armi.any(func(w): return w.tipo == k or (k == "granata")))
		if dest.is_empty():
			continue
		var chi2: Dictionary = pref if pref in dest else dest[0]
		chi2.munizioni[k] = int(chi2.munizioni.get(k, 0)) + int(mun[k])

func turni_tedesco(g: Dictionary, es: Dictionary) -> Dictionary:
	if attiva() and g.get("berserk", false):
		return berserk.turni(g, es)
	if attiva() and g.get("cane", false):
		return {"turni": 1 if g.ferito else 2, "panico": false}
	if attiva() and bool(p.missione.tedeschi.get(str(int(g.get("num", 0))), {}).get("un_turno", false)) and int(es.get("turni", 0)) > 1:
		return {"turni": 1, "panico": es.get("panico", false)}
	return es

## Unità americane che agiscono da sole nella casella corrente (Sherman guidati della Missione 18, soldati fuori di testa).
func turni_automatici(n: int) -> bool:
	if not attiva():
		return false
	var agito: bool = m18.turni_sherman(n)
	for a in p.americani():
		if p.s.fase != "round":
			break
		if a.get("berserk", false) and p.attivo(a) and int(a.turni) == n and a.slot == "turni":
			berserk.turno_americano(a)
			p._consuma_turno(a)
			agito = true
	return agito

func agisce_da_solo(a: Dictionary) -> bool:
	return attiva() and (m18.sherman_ia(a) or (a.get("berserk", false) and p.attivo(a)))

func uscita(a: Dictionary, h: String) -> void:
	if not attiva():
		return
	m18.uscita(a, h)
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
	p._applica_regole_terreno()
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

## Esagono del faro ancora acceso ("" se spento o distrutto).
func faro_hex() -> String:
	var f: Dictionary = _st().get("faro", {}) if attiva() else {}
	if f.is_empty() or not f.get("attivo", false) or p.s.modifiche.has(str(f.hex)):
		return ""
	return str(f.hex)

## 648 (3–4): la sentinella 61 uscita con un movimento evasivo torna, accovacciata al piano superiore del faro E11, in reazione A.
func _sentinella_e11(ctx: Dictionary) -> void:
	var g61: Dictionary = p.u("g61")
	var intatto: bool = not p.s.modifiche.has("E11") and not p.s.oggetti.get("E11", []).any(func(x): return x.get("tipo", "") == "incendio")
	if g61.is_empty() or g61.stato != "rimosso" or not intatto or p.s.get("no_rientro", false):
		p.leggi("443", ctx)
		return
	p._op_attiva({"op": "activate", "g": [[61, "E11"]], "stance": "crouching", "adv": null, "two": [], "us_two": false,
		"aware": false, "reaction": "A", "rounds": true}, ctx)
	g61 = p.u("g61")
	if p.terreno.ha_piani("E11"):
		g61.piano = 1
	g61.reazione_fissa = "A"
	p._log("tedesco", "La sentinella 61 è tornata: è al piano superiore del faro in E11, in reazione speciale A fino alla fine.")

func spegni_faro(perche: String) -> void:
	var f: Dictionary = _st().get("faro", {})
	if f.is_empty() or not f.get("attivo", false):
		return
	f.attivo = false
	p._log("danno", "Il faro è distrutto (%s): il fascio si spegne." % perche)
	_illumina()
	p.terreno._cache_los.clear()

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

## All’inizio di ciascuno dei due turni del Round (prima di ogni azione): la piena avanza di 4 esagoni (565), il treno di 6 (493).
func inizio_turno(_t: int) -> void:
	if not attiva():
		return
	_timer_ponti()
	_avanza_piena()

## 493: il treno ha due turni per Round e si muove (6 esagoni) prima degli altri tedeschi, nella casella tedesca di ciascun turno
## secondo il vantaggio; se la casella tedesca di quel turno è vuota si muove comunque al suo posto. c = [turno, lato] o [] a fine Round.
func casella_treno(c: Array) -> void:
	if not attiva() or str(_st().get("treno", {}).get("stato", "")) != "attivo" or not p.s.has("round"):
		return
	var r: Dictionary = p.s.round
	if not r.has("treno_mosso"):
		r.treno_mosso = []
	var de_prima: bool = str(r.get("vantaggio", "")) == "de"
	for t in [2, 1]:
		if t in r.treno_mosso:
			continue
		var ora: bool = c.is_empty() or int(c[0]) < t or (int(c[0]) == t and (str(c[1]) == "de" or de_prima))
		if not ora:
			return
		r.treno_mosso.append(t)
		p._log("info", "Turno del treno (%d° turno del Round)." % (3 - t))
		_muovi_treno(6)
		if str(_st().get("treno", {}).get("stato", "")) != "attivo":
			return

func inizio_round() -> void:
	if not attiva():
		return
	affonda_barche_danneggiate()
	m18.inizio_round()
	var nt := int(_st().get("treno_round", 0))
	if nt > 0 and int(p.s.round.get("n", 0)) >= nt:
		_st().treno_round = 0
		_st().salta_evento = true
		p.leggi("486", {})
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
	m18.controlla()
	if p.s.fase == "fine":
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
	return attiva() and (m18.niente_pv_incapacitati() or bool(_st().get("fine_senza_tedeschi", false)) or int(_st().get("fine_modo", 0)) in [1, 2])

func niente_controlli_round() -> bool:
	return attiva() and bool(_st().get("niente_controlli_round", false))

func salta_evento() -> bool:
	if m18.salta_evento():
		return true
	if attiva() and bool(_st().get("salta_evento", false)):
		_st().salta_evento = false
		p._log("info", "Al posto del controllo degli eventi casuali arriva il resto della colonna (paragrafo 598).")
		return true
	return false

## Missione 15: i Round continuano finché la piena non è uscita dalla mappa.
func round_obbligati() -> bool:
	if not attiva():
		return false
	if m18.round_obbligati():
		return true
	if str(_st().get("treno", {}).get("stato", "")) == "attivo" or int(_st().get("treno_round", 0)) > 0:
		return true
	var pn: Dictionary = _st().get("piena", {})
	return not pn.is_empty() and not bool(pn.get("fuori", false))

func blocca_fine() -> bool:
	return attiva() and _st().fine_esplosivi and not _st().esplosivi.is_empty()

func righe_fine(righe: Array) -> int:
	if not attiva():
		return 0
	var tot_s: int = m18.righe_fine(righe) + righe_camion(righe)
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
	if attiva() and str(_st().get("treno", {}).get("stato", "")) == "attivo":
		p.terreno.treno = {}
		for hx in _posizioni_treno():
			if str(hx) != "":
				p.terreno.treno[str(hx)] = true
	if attiva() and bool(p.regola("diga", false)):
		p.terreno.accessi["N5"] = ["O5", "M6"]
	# 337/356/367: l’edificio di X14 ha un piano superiore (il cecchino 50).
	if attiva() and bool(p.regola("fine_ponti_17", false)):
		p.terreno.torri["X14"] = 1
	# 648: il faro di E11 ha un piano superiore (la sentinella 61 può tornarci).
	if attiva() and _st().has("faro") and not p.s.modifiche.has("E11"):
		p.terreno.torri["E11"] = 1

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
	munizioni_consumate()

## Munizioni consumate nei combattimenti dei giorni prima (Missioni 15 e 18): un dado per soldato e tipo di munizione.
func munizioni_consumate() -> void:
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
	if mg_jeep_scelta():
		_monta_mg_jeep()

## Missione 14: si può montare una mitragliatrice media sulla jeep (in questa versione al posto del BAR di G, perché la squadra
## non compra l’equipaggiamento). La spara il passeggero 1, gli altri passeggeri (non l’autista) la assistono.
func mg_jeep_possibile() -> bool:
	return attiva() and bool(p.regola("mg_jeep_opzionale", false)) and p.s.fase == "schieramento"

func mg_jeep_scelta() -> bool:
	return attiva() and bool(_st().get("mg_jeep", false))

func scegli_mg_jeep(si: bool) -> void:
	_st().mg_jeep = si

func _monta_mg_jeep() -> void:
	var v: Dictionary = p.veicoli.v("vjeep1")
	if v.is_empty() or v.has("mg"):
		return
	var g: Dictionary = p.u("G")
	var colpi := 5
	if not g.is_empty():
		for w in g.armi.duplicate():
			if w.tipo == "ar":
				g.armi.erase(w)
				colpi = maxi(colpi, int(g.munizioni.get("ar", 0)))
				g.munizioni.erase("ar")
				break
		if g.armi.filter(func(w): return T.ARMI.get(w.tipo, {}).has("gittate")).is_empty():
			g.armi.append({"tipo": "pistol", "inceppata": false, "rotta": false, "preparata": false, "catturata": false})
			g.munizioni["pistol"] = 2
	v.mg = {"tipo": "mmg", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false, "montata": true,
		"solo_passeggero1": true}
	v.mg_munizioni = colpi
	p._log("info", "Sulla jeep 1 c’è una mitragliatrice media montata (%d caricatori): la spara il passeggero 1." % colpi)

func radio_portata() -> bool:
	return attiva() and bool(p.regola("radio_portata_ph", false))

func radio_funziona() -> bool:
	var a: Dictionary = p.u("A")
	return not a.is_empty() and p.attivo(a) and p.in_mappa(a) and not _st().get("radio_distrutta", false)

## Purple Heart 5: se chi porta la radio è ferito, incapacitato o ucciso, con 25 o meno sui percentuali la radio è distrutta.
func radio_colpita(x: Dictionary, l: String) -> void:
	if not radio_portata() or x.get("id", "") != "A" or not (l in ["W", "I", "K"]) or _st().get("radio_distrutta", false):
		return
	var r: int = p.d10() * 10 + p.d10()
	if r <= 25:
		_st().radio_distrutta = true
		p._log("dado", "La radio del sergente: percentuale %02d → distrutta." % r)
	else:
		p._log("dado", "La radio del sergente: percentuale %02d → intatta." % r)

func tedesco_uscito(x: Dictionary, h: String) -> void:
	m18.tedesco_uscito(x, h)
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
## Purple Heart 17: le spolette si regolano fino a 4 turni; le cariche saltano all’inizio del turno indicato, prima di ogni azione.
func arma_ponte(h: String, turni: int) -> void:
	var tp: Dictionary = _st().get("timer_ponti", {})
	tp[h] = {"round": 1 if turni > 0 else 0, "turni": turni}
	_st().timer_ponti = tp
	if turni > 0:
		p._log("azione", "Spoletta del ponte in %s: salta all’inizio del %s." % [h, "prossimo turno" if turni == 1 else "%d° turno da ora" % turni])
	else:
		p._log("azione", "Cariche del ponte in %s innescate: saltano appena la squadra si è allontanata." % h)

func ponte_armato(h: String) -> bool:
	return _st().get("timer_ponti", {}).has(h)

## 503: carica piazzata sul binario con la spoletta (1–4 turni; nelle Operazioni salta quando la squadra si è allontanata).
func arma_binario(h: String, turni: int) -> void:
	var cb: Dictionary = _st().get("cariche_binario", {})
	cb[h] = turni
	_st().cariche_binario = cb
	p.s.punti[h] = "carica sul binario"
	p._log("azione", "Carica piazzata sul binario in %s: %s." % [h, "salta tra %d turn%s" % [turni, "o" if turni == 1 else "i"] if turni > 0 else "salta appena la squadra si è allontanata"])

func _cariche_binario(nelle_operazioni: bool) -> void:
	var cb: Dictionary = _st().get("cariche_binario", {})
	for h in cb.keys():
		if nelle_operazioni:
			if int(cb[h]) == 0 and p.americani_attivi_in_mappa().all(func(a): return E.distanza(a.hex, h) > 1):
				cb.erase(h)
				_scoppio_binario(h)
		elif int(cb[h]) > 0:
			cb[h] = int(cb[h]) - 1
			if int(cb[h]) <= 0:
				cb.erase(h)
				_scoppio_binario(h)

func _scoppio_binario(h: String) -> void:
	p._fx("esplosione", {"a": h, "grande": true})
	for x in p.unita_in(h):
		if p.attivo(x):
			p._danno_esplosione(x, T.CARICA_DENTRO)
	if p.s.punti.get(h, "") == "carica sul binario":
		p.s.punti.erase(h)
	distruggi_binario(h)

func _timer_ponti() -> void:
	_cariche_binario(false)
	var tp: Dictionary = _st().get("timer_ponti", {})
	for h in tp.keys():
		if int(tp[h].get("turni", 0)) <= 0:
			continue
		tp[h].turni = int(tp[h].turni) - 1
		if int(tp[h].turni) <= 0:
			tp.erase(h)
			p.distruggi_ponte(h, "cariche a tempo")

## Sotto il ponte (17): chi sta sui sostegni si vede come accovacciato sul ponte; ferito o in panico, cade nel fiume se il dado
## supera la sua IN (altrimenti va nel panico e perde il turno).
func sotto_ponte_colpito(x: Dictionary, l: String) -> void:
	if not x.get("sotto_ponte", false) or not (l in ["P", "W"]) or not p.attivo(x):
		return
	var d: int = p.d10()
	if d > int(x.IN):
		p._log("dado", "%s, sotto il ponte, perde la presa (%d > IN %d): cade nel fiume ed è travolto." % [p.nome(x), d, int(x.IN)])
		x.erase("sotto_ponte")
		p._uccidi(x, "caduto nel fiume")
	else:
		p._log("dado", "%s, sotto il ponte, si aggrappa ai sostegni (%d ≤ IN %d): va nel panico e perde il turno." % [p.nome(x), d, int(x.IN)])
		if p.fase_round():
			x.panico = true
			x.turni = 0
			x.slot = "panico"

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
	p.terreno.treno = {}
	var trn: Dictionary = _st().get("treno", {})
	if str(trn.get("stato", "")) == "attivo":
		for hx in _posizioni_treno():
			if str(hx) != "":
				p.terreno.treno[str(hx)] = true
	p.terreno._cache_los.clear()
	for h in p.s.punti.keys():
		if str(p.s.punti[h]) in ["locomotiva", "vagone merci", "cisterna"]:
			p.s.punti.erase(h)
	var tr: Dictionary = _st().get("treno", {})
	var pos: Array = tr.get("relitti", _posizioni_treno()) if str(tr.get("stato", "")) == "deragliato" else _posizioni_treno()
	for i in pos.size():
		if str(pos[i]) != "":
			p.s.punti[str(pos[i])] = str(tr.pezzi[i]) if tr.stato == "attivo" else ("vagone rovesciato" if tr.pezzi[i] != "cisterna" else "cisterna rovesciata")

func _muovi_treno(passi: int) -> void:
	var tr: Dictionary = _st().treno
	if str(tr.get("stato", "")) != "attivo":
		return
	var b := _binario()
	# 503/506: se il treno comincia il turno con un pezzo su un binario o un ponte distrutto, deraglia.
	var pos0 := _posizioni_treno()
	for i in pos0.size():
		if pos0[i] != "" and _binario_rotto(pos0[i]):
			_deraglia(i, "comincia il turno su un binario interrotto")
			return
	for k in passi:
		tr.idx = int(tr.idx) + 1
		var pos := _posizioni_treno()
		if pos.all(func(x): return x == ""):
			tr.stato = "uscito"
			_segna_treno()
			p._log("info", "Il treno esce dalla mappa.")
			_fine_treno()
			return
		# la locomotiva che entra in un binario o un ponte distrutto, o un vagone che entra in un ponte distrutto
		for i in pos.size():
			var h: String = pos[i]
			if h == "":
				continue
			# a ogni passo ogni pezzo entra in un nuovo esagono del binario
			if (i == 0 and _binario_rotto(h)) or (p.ponti().has(h) and not p.ponte_intatto(h)):
				_deraglia(i, "entra in %s" % ("un ponte distrutto" if p.ponti().has(h) else "un binario distrutto"))
				return
		for i in pos.size():
			var h2: String = pos[i]
			if h2 == "":
				continue
			for a in p.unita_in(h2, "us").filter(func(x): return p.attivo(x)):
				if p.controllo_pc(a, 0, "scansarsi dal treno"):
					for v in E.vicini(h2):
						if not (v in b) and p.terreno.costo_movimento(h2, v) >= 0:
							a.hex = v
							p._log("info", "%s si butta di lato in %s." % [p.nome(a), v])
							break
				else:
					p._uccidi(a, "travolto dal treno")
	_segna_treno()
	p._log("info", "Il treno avanza: la locomotiva è in %s." % (_posizioni_treno()[0] if _posizioni_treno()[0] != "" else "fuori mappa"))

func _binario_rotto(h: String) -> bool:
	return h in _st().get("binari_distrutti", []) or (p.ponti().has(h) and not p.ponte_intatto(h))

## 503: binario interrotto (carica piazzata con la spoletta o lanciata in un esagono del binario).
func distruggi_binario(h: String) -> void:
	if not (h in _binario()) or h in _st().get("binari_distrutti", []):
		return
	if not _st().has("binari_distrutti"):
		_st().binari_distrutti = []
	_st().binari_distrutti.append(h)
	p.s.punti[h] = "binario distrutto" if not p.s.punti.has(h) else p.s.punti[h]
	p._log("info", "Il binario in %s è interrotto." % h)
	var tr: Dictionary = _st().get("treno", {})
	if str(tr.get("stato", "")) == "attivo":
		var pos := _posizioni_treno()
		var i: int = pos.find(h)
		if i >= 0:
			_deraglia(i, "il binario salta sotto il treno")

## 504: il bazooka contro un pezzo del treno (mezzo grande allo scoperto); la locomotiva con penetrazione pesante, i vagoni con media.
func colpo_treno(i: int, pen: String) -> void:
	var tr: Dictionary = _st().get("treno", {})
	if str(tr.get("stato", "")) != "attivo":
		return
	var serve: Array = ["H"] if i == 0 else ["M", "H"]
	if pen in serve:
		_deraglia(i, "%s distrutto dal bazooka" % ("la locomotiva" if i == 0 else "un vagone"))
	else:
		p._log("info", "Il colpo non basta a fermare il treno.")

func pezzo_treno_in(h: String) -> int:
	var tr: Dictionary = _st().get("treno", {})
	if str(tr.get("stato", "")) != "attivo":
		return -1
	return _posizioni_treno().find(h)

## 506: deragliamento. I pezzi davanti a quello che lo provoca si rovesciano dove sono; quello e i successivi, dal primo
## all’ultimo, scivolano: dado 0–3 est, 4–6 sud-est, 7–9 sud-ovest; dopo ogni esagono, pari prosegue, dispari si ferma; al
## terzo si ferma comunque. Si fermano in bosco, edificio (macerie), terreno accidentato, fiume o su un altro relitto; un ponte
## colpito (pari) crolla; chi è nell’esagono fa un controllo di percezione (riesce: a terra, perde i turni; fallisce: muore).
func _deraglia(da: int, perche: String) -> void:
	var tr: Dictionary = _st().treno
	tr.stato = "deragliato"
	var pos := _posizioni_treno()
	var relitti: Array = pos.duplicate()
	p._log("combattimento", "Il treno deraglia (%s)!" % perche)
	p._fx("esplosione", {"a": pos[maxi(0, da)] if pos[maxi(0, da)] != "" else pos[0], "grande": true})
	# a est = in basso (M17: in alto è ovest); sud-est = in basso a sinistra; sud-ovest = in alto a sinistra.
	var direzioni := {"est": 3, "sud-est": 4, "sud-ovest": 5}
	for i in range(da, pos.size()):
		var h: String = relitti[i]
		if h == "":
			continue
		var d: int = p.d10()
		var nome_d: String = "est" if d <= 3 else ("sud-est" if d <= 6 else "sud-ovest")
		var dir: int = int(direzioni[nome_d])
		p._log("dado", "Deragliamento di %s: dado %d → verso %s." % [tr.pezzi[i], d, nome_d])
		for passo in 3:
			var n: String = E.vicino(h, dir)
			if n == "":
				h = ""
				p._log("info", "%s finisce fuori mappa." % str(tr.pezzi[i]).capitalize())
				break
			h = n
			var t: String = p.terreno.tipo(h)
			var stop := false
			if h in relitti.slice(0, i) or h in relitti.slice(i + 1):
				stop = true
			if p.terreno.edificio(h):
				if not p.s.modifiche.has(h):
					p.s.modifiche[h] = "rubble"
				stop = true
			if t in ["woods", "rough", "stream", "water"] and not p.ponti().has(h):
				stop = true
			if p.ponti().has(h) and p.ponte_intatto(h):
				var dp: int = p.d10()
				if dp % 2 == 0:
					p._log("dado", "Il vagone colpisce il ponte in %s (%d): il ponte crolla!" % [h, dp])
					p.distruggi_ponte(h, "travolto dal treno")
				else:
					p._log("dado", "Il vagone colpisce il ponte in %s (%d): regge, ma i mezzi non passano più." % [h, dp])
					p.ponte_stato(h).bloccato = true
				stop = true
			for x in p.unita_in(h, "", false):
				if p.attivo(x):
					if p.controllo_pc(x, 0, "scansare il vagone"):
						x.postura = "prone"
						x.turni = 0
						if p.fase_round():
							x.slot = "completo"
						p._log("info", "%s si butta a terra e lo evita." % p.nome(x))
					else:
						p._uccidi(x, "travolto dal vagone")
				elif x.stato == "incapacitato":
					p._uccidi(x, "travolto dal vagone")
			if stop or passo == 2:
				break
			var dc: int = p.d10()
			if dc % 2 == 1:
				break
		relitti[i] = h
	tr.relitti = relitti
	p.terreno.imposta_modifiche(p.s.modifiche)
	_segna_treno()
	if not p.s.has("da_leggere"):
		p.s.da_leggere = {}
	for i in relitti.size():
		if relitti[i] != "" and str(tr.pezzi[i]) == "vagone merci":
			p.s.da_leggere[relitti[i]] = "595"
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
		_cariche_binario(true)
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
