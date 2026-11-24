extends RefCounted
## Silver Star, Missione 24 «Il blues del mulattiere»: ottobre 1943, vicino a Napoli. La squadra scarica sei muli carichi di
## rifornimenti dalla chiatta in K8 (mezze mappe G e H, in alto è ovest), li porta verso il fronte (uscita a nord fra Y10 e Y14),
## poi prosegue sulla mappa F (in alto è nord) fino all’angolo nord-est (W1–Y3). I muli si guidano a mano (uno o due per soldato),
## si spaventano e possono essere rubati; i tedeschi nella reazione speciale M sparano prima ai muli. Stato in p.s.ss.m24.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

const MAX_MULI := 6

var p  # Partita
var ss  # missioni_ss.gd

func _init(partita, modulo) -> void:
	p = partita
	ss = modulo

func attiva() -> bool:
	return ss.attiva() and int(p.missione.get("id", 0)) == 24

func _st() -> Dictionary:
	var st: Dictionary = ss._st()
	if not st.has("m24"):
		st.m24 = {"muli": [], "parte": 1, "modo": "", "scaricati": 0}
	return st.m24

# ------------------------------------------------------------------ muli
func muli() -> Array:
	return _st().muli

func muli_attivi() -> Array:
	return muli().filter(func(m): return str(m.stato) in ["attivo", "ferito"])

func muli_in(h: String) -> Array:
	return muli_attivi().filter(func(m): return str(m.hex) == h)

func muli_di(a: Dictionary) -> Array:
	return muli_attivi().filter(func(m): return str(m.guida) == str(a.id))

func incustoditi() -> Array:
	return muli_attivi().filter(func(m): return str(m.guida) == "" and str(m.get("rubato", "")) == "")

## 179: si scaricano i muli dalla chiatta in K8 (serve un americano in K8). 0–8 riesce; 9 il mulo scivola.
func scarica_muli() -> void:
	var presenti: Array = p.americani_attivi_in_mappa().filter(func(a): return a.hex == "K8")
	if presenti.is_empty():
		p._log("info", "Per scaricare i muli serve un soldato in K8.")
		return
	var tentativi := 0
	while int(_st().scaricati) < MAX_MULI and tentativi < 12:
		tentativi += 1
		var r: int = p.d10()
		var id := "mulo%d" % (muli().size() + 1)
		if r <= 8:
			muli().append({"id": id, "hex": "K8", "stato": "attivo", "guida": "", "panico": -1, "percorso": ["K8"]})
			_st().scaricati = int(_st().scaricati) + 1
			p._log("dado", "Dado %d: un mulo scende dalla chiatta in K8." % r)
			continue
		var r2: int = p.d10()
		if r2 <= 2:
			p._log("danno", "Dado %d: un mulo scivola dalla passerella e annega con il suo carico." % r2)
		elif r2 <= 5:
			p._log("danno", "Dado %d: un mulo ricade sulla chiatta e si ferisce gravemente." % r2)
		else:
			p._log("danno", "Dado %d: un mulo cade in K8 e si ferisce gravemente." % r2)
			for a in presenti:
				if not p.controllo_pc(a, 0, "per evitare il mulo che cade"):
					p._danno_esplosione(a, T.ARMI.pistol.danni)
		p._pv(-1, "mulo perso allo scarico")
	p._log("info", "Muli scaricati in K8: %d. Ogni soldato può guidarne uno o due (bottone «Prendi i muli»); al massimo 4 muli per esagono." % int(_st().scaricati))

func puo_prendere(a: Dictionary) -> bool:
	return attiva() and p.attivo(a) and a.lato == "us" and not incustoditi().filter(func(m): return str(m.hex) == str(a.hex)).is_empty() \
		and muli_di(a).size() < 2

func prendi(a: Dictionary) -> String:
	if not puo_prendere(a):
		return "Non ci sono muli incustoditi qui (o ne guida già due)."
	var presi := 0
	for m in incustoditi():
		if str(m.hex) == str(a.hex) and muli_di(a).size() < 2:
			m.guida = a.id
			presi += 1
	p._log("azione", "%s prende la corda di %d mul%s." % [p.nome(a), presi, "o" if presi == 1 else "i"])
	return ""

func puo_lasciare(a: Dictionary) -> bool:
	return attiva() and not muli_di(a).is_empty()

func lascia(a: Dictionary) -> String:
	for m in muli_di(a):
		m.guida = ""
	p._log("azione", "%s lascia la corda dei muli." % p.nome(a))
	return ""

## Chi guida i muli fa solo tiri rapidi e non usa bazooka, BAR, mitragliatrice né assalti: prima lascia la corda.
func blocca_tiro(a: Dictionary, tipo: String, mirato: bool) -> String:
	if not attiva() or muli_di(a).is_empty():
		return ""
	if tipo in ["bazooka", "ar", "lmg", "mmg"]:
		return "Per usare quest’arma deve prima lasciare la corda dei muli."
	if mirato:
		return "Chi guida i muli spara solo di rapido."
	return ""

## I muli seguono chi li guida (non nei dirupi, al massimo 4 per esagono); un soldato fuori combattimento lascia la corda.
func dopo_movimento(ids: Array) -> void:
	if not attiva():
		return
	for id in ids:
		var a: Dictionary = p.u(str(id))
		if a.is_empty() or a.lato != "us":
			continue
		for m in muli_di(a):
			if int(m.get("panico", -1)) == int(p.s.get("round_tot", 0)):
				m.guida = ""
				continue
			if p.terreno.tipo(a.hex) == "cliff" or muli_in(a.hex).size() >= 4:
				m.guida = ""
				p._log("info", "Il mulo non può seguire %s in %s: resta in %s, incustodito." % [p.nome(a), a.hex, m.hex])
				continue
			m.hex = a.hex
			m.percorso.append(a.hex)
	ss.m23._dopo_movimento_pattuglie(ids)
	_controlla_guide()

func _controlla_guide() -> void:
	for m in muli_attivi():
		if str(m.guida) == "":
			continue
		var a: Dictionary = p.u(str(m.guida))
		if a.is_empty() or not p.attivo(a) or a.ferito or str(a.hex) != str(m.hex):
			m.guida = ""

## Danni a un mulo colpito (527): 0–3 niente, 4–7 si spaventa, 8 ferito, 9 incapacitato (e con un altro 9 il carico esplode).
func colpisci_mulo(m: Dictionary) -> void:
	var r: int = p.d10()
	if r <= 3:
		p._log("dado", "Il mulo colpito (%d): nessun effetto." % r)
	elif r <= 7:
		m.panico = int(p.s.get("round_tot", 0))
		p._log("dado", "Il mulo colpito (%d) si spaventa: non si muove per il resto del Round." % r)
	elif r == 8 and str(m.stato) != "ferito":
		m.stato = "ferito"
		p._log("danno", "Il mulo è ferito (%d): si muoverà al massimo di 2 PM a turno." % r)
	else:
		m.stato = "incapacitato"
		m.guida = ""
		p._log("danno", "Il mulo è fuori combattimento (%d)." % r)
		if r == 9 and p.d10() == 9:
			m.stato = "morto"
			p._fx("esplosione", {"a": m.hex})
			p._log("danno", "Il carico del mulo esplode!")
			for x in p.americani() + p.tedeschi():
				if p.attivo(x) and x.hex == m.hex:
					p._danno_esplosione(x, T.CARICA_FUORI)

## Reazione speciale M: i tedeschi sparano prima ai muli (se il mulo è il bersaglio più vicino).
func tiro_ai_muli(t, g: Dictionary) -> bool:
	if not attiva() or str(g.get("reazione", "")) != "M":
		return false
	var visti: Array = muli_attivi().filter(func(m): return str(m.get("rubato", "")) == "" and p.terreno.vede(g.hex, str(m.hex), g.postura, "standing"))
	if visti.is_empty():
		return false
	visti.sort_custom(func(a, b): return E.distanza(g.hex, a.hex) < E.distanza(g.hex, b.hex))
	var m: Dictionary = visti[0]
	var soldati: Array = t.bersagli(g)
	if not soldati.is_empty() and E.distanza(g.hex, soldati[0].hex) < E.distanza(g.hex, m.hex):
		return false
	t._accovacciati()
	var r: int = p.d10()
	var serve := 5 - mini(4, E.distanza(g.hex, m.hex) / 3) + int(g.WS)
	p._log("tedesco", "Il %s spara al mulo in %s: serve 0–%d, esce %d." % [p.nome(g), m.hex, maxi(0, serve - 1), r])
	if r < serve:
		colpisci_mulo(m)
	t._prono_se_libero()
	return true

## 529: un mulo incustodito si spaventa e scappa.
func mulo_scappa() -> void:
	var lista := incustoditi()
	if lista.is_empty():
		p._log("info", "Nessun mulo incustodito: nessun evento.")
		return
	var m: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	var r: int = p.d10()
	if r >= 7:
		m.panico = int(p.s.get("round_tot", 0))
		p._log("dado", "Dado %d: il mulo in %s si impunta e non si muove per questo Round." % [r, m.hex])
		return
	var verso: String
	if r == 6:
		var perc: Array = m.percorso
		verso = str(perc[maxi(0, perc.size() - 3)])
	else:
		verso = E.vicino(str(m.hex), r)
	if verso == "" or not E.valido(verso) or p.terreno.costo_movimento(str(m.hex), verso) < 0:
		p._log("dado", "Dado %d: il mulo in %s scalcia ma resta dov’è." % [r, m.hex])
		return
	if p.terreno.tipo(verso) == "cliff":
		p._log("danno", "Il mulo cade dal dirupo in %s." % verso)
		colpisci_mulo(m)
	for x in p.americani_attivi_in_mappa():
		if x.hex == verso and not p.controllo_pc(x, 0, "il mulo imbizzarrito"):
			p._danno_esplosione(x, T.ARMI.pistol.danni)
	m.hex = verso
	m.percorso.append(verso)
	p._log("dado", "Dado %d: il mulo imbizzarrito scappa in %s." % [r, verso])

## 500: un mulo spaventato calpesta chi è a terra nel suo esagono.
func mulo_calpesta() -> void:
	var esagoni := {}
	for m in muli_attivi():
		for a in p.americani_attivi_in_mappa() + p.tedeschi_attivi():
			if a.hex == m.hex and a.postura == "prone":
				esagoni[m.hex] = true
	if esagoni.is_empty():
		p._log("info", "Nessun soldato a terra accanto a un mulo: nessun evento.")
		return
	var h: String = esagoni.keys()[p.rng.randi_range(0, esagoni.size() - 1)]
	p._log("info", "Un mulo si spaventa in %s e scalcia." % h)
	for a in p.americani_attivi_in_mappa() + p.tedeschi_attivi():
		if a.hex == h and not p.controllo_pc(a, 0, "per scansarsi dal mulo"):
			p._danno_esplosione(a, T.ARMI.pistol.danni)

## 747: un tedesco in un esagono con muli incustoditi ne porta via due verso U19 o Y17.
func ruba_muli(t, g: Dictionary) -> bool:
	if not attiva():
		return false
	var qui: Array = incustoditi().filter(func(m): return str(m.hex) == str(g.hex))
	var suoi: Array = muli_attivi().filter(func(m): return str(m.get("rubato", "")) == g.id)
	if qui.is_empty() and suoi.is_empty():
		return false
	for m in qui:
		if suoi.size() < 2:
			m.rubato = g.id
			suoi.append(m)
			p._log("tedesco", "Il %s prende la corda di un mulo e lo porta via." % p.nome(g))
	var meta := "U19" if E.distanza(g.hex, "U19") <= E.distanza(g.hex, "Y17") else "Y17"
	if g.hex == meta:
		ss.m20._togli(g, 0, "")
		p._pv(-1, "tedesco uscito")
		for m in suoi:
			m.stato = "rubato"
			p._pv(-2, "mulo portato via dai tedeschi")
		p._log("tedesco", "Il %s esce dalla mappa con %d mul%s." % [p.nome(g), suoi.size(), "o" if suoi.size() == 1 else "i"])
		return true
	t._corri_verso(meta)
	for m in suoi:
		m.hex = g.hex
	return true

func inizio_round() -> void:
	if not attiva():
		return
	_controlla_guide()
	for m in muli_attivi():
		var g: Dictionary = p.u(str(m.get("rubato", "")))
		if not g.is_empty():
			if p.attivo(g):
				m.hex = g.hex
			else:
				m.rubato = ""

# ------------------------------------------------------------------ cambio di mappa e uscite
## 631: dalle mezze mappe G e H alla mappa F; la squadra e i muli entrano fra A19 e C19.
func passa_alla_mappa_f() -> void:
	if int(_st().parte) == 2:
		return
	_st().parte = 2
	for g in p.tedeschi():
		if p.attivo(g) and p.in_mappa(g):
			g.stato = "rimosso"
			g.hex = ""
			if int(g.num) in [72, 73]:
				g.tolto_parte1 = true
	_st().erase("pattuglie_prima")
	ss.m23._st().pattuglie = {}
	p.cambia_mappa("F")
	var ingressi := ["A19", "B19", "C19"]
	var i := 0
	for a in p.americani():
		if a.stato == "uscito_parte1" or (p.attivo(a) and p.in_mappa(a)):
			a.stato = "attivo" if a.stato == "uscito_parte1" else a.stato
			a.hex = ingressi[i % 3]
			i += 1
	for m in muli():
		if str(m.stato) == "uscito_parte1":
			m.stato = "attivo"
			var guida: Dictionary = p.u(str(m.guida))
			m.hex = guida.hex if not guida.is_empty() else "A19"
			m.percorso = [m.hex]
	p._applica_regole_terreno()
	p._log("info", "Si passa alla mappa F (in alto è nord): la squadra e i muli entrano fra A19 e C19.")

## Uscite: nella prima parte dal bordo nord Y10–Y14 (con il 175), nella terza Condizione dall’angolo nord-est W1–Y3.
func uscita_ammessa(h: String) -> bool:
	if not attiva():
		return false
	if int(_st().parte) == 1:
		return bool(_st().get("letto175", false)) and h in ["Y10", "Y11", "Y12", "Y13", "Y14"]
	return str(_st().modo) == "consegna" and h in ["W1", "X1", "Y1", "Y2", "Y3"]

func dopo_uscita(a: Dictionary) -> void:
	if not attiva():
		return
	for m in muli_di(a):
		m.stato = "uscito_parte1" if int(_st().parte) == 1 else "uscito"
	if int(_st().parte) == 1:
		a.stato = "uscito_parte1"
		var restano: Array = p.americani_attivi_in_mappa()
		if restano.is_empty():
			var lasciati: Array = muli_attivi()
			if not lasciati.is_empty():
				p._pv(-5 * lasciati.size(), "muli lasciati indietro")
				for m in lasciati:
					m.stato = "perso"
			for n in [72, 73]:
				var g: Dictionary = p.u("g%d" % n)
				if not g.is_empty() and p.attivo(g) and p.in_mappa(g):
					p._pv(1, "tedesco %d ancora attivo" % n)
			p.leggi("631", {})

func righe_fine(righe: Array) -> int:
	if not attiva() or str(_st().modo) != "consegna":
		return 0
	var tot := 0
	var usciti: int = p.americani().filter(func(a): return a.stato == "uscito").size()
	var muli_usciti: int = muli().filter(func(m): return str(m.stato) == "uscito").size()
	var muli_rimasti: int = muli_attivi().size()
	var de: int = p.tedeschi().filter(func(g): return p.attivo(g) and p.in_mappa(g)).size()
	if usciti > 0:
		righe.append(["Americani usciti dall’angolo nord-est", usciti])
		tot += usciti
	if muli_usciti > 0:
		righe.append(["Muli consegnati", 2 * muli_usciti])
		tot += 2 * muli_usciti
	if de > 0:
		righe.append(["Tedeschi attivi rimasti in mappa", de])
		tot += de
	if muli_rimasti > 0:
		righe.append(["Muli rimasti in mappa", -2 * muli_rimasti])
		tot -= 2 * muli_rimasti
	return tot

func controlla() -> void:
	if not attiva() or p.s.fase == "fine":
		return
	if str(_st().modo) == "consegna" and p.americani_attivi_in_mappa().is_empty():
		p._calcola_fine("ritirata")

func blocca_fine() -> bool:
	return attiva() and not p.americani_attivi_in_mappa().is_empty()

# ------------------------------------------------------------------ operazioni e test
func op(o: Dictionary, ctx: Dictionary) -> bool:
	if not attiva():
		return false
	match str(o.op):
		"ss24_muli":
			scarica_muli()
		"ss24_175":
			_st().letto175 = true
			p._log("info", "Il fronte è più vicino del previsto: la squadra e i muli escono dal bordo nord fra Y10 e Y14.")
		"ss24_631":
			passa_alla_mappa_f()
		"ss24_consegna":
			_st().modo = "consegna"
			p.missione.vittoria_pv = 21
			for n in [72, 73, 74, 75, 76]:
				var g: Dictionary = p.u("g%d" % n)
				if not g.is_empty() and p.attivo(g):
					g.reazione = "M"
		"ss24_reazione_m":
			for n in o.g:
				var g2: Dictionary = p.u("g%d" % int(n))
				if not g2.is_empty() and p.attivo(g2):
					g2.reazione = "M"
		"ss24_scappa":
			mulo_scappa()
		"ss24_calpesta":
			mulo_calpesta()
		"ss24_pattuglia":
			var r: int = p.d10()
			var tab: Array = o.tab
			ss.m23.piazza_pattuglia("MM", str(tab[r]))
			p._log("dado", "Dado %d." % r)
		"ss24_schiera_pattuglia":
			ss.m23._st().corrente = "MM"
			ss.m23.schiera_pattuglia(str(o.adv))
		"ss24_pc_osservatori":
			ss.m23._st().corrente = "MM"
			var oss: Array = ss.m23.osservatori()
			var riusciti: Array = oss.filter(func(x): return p.controllo_pc(x, 0, "riconoscere la pattuglia"))
			for x in riusciti:
				x.consapevole = true
			for x in (o.ok if not riusciti.is_empty() else o.ko):
				p._op(x, ctx)
		"ss24_rientra":
			var r2: int = p.d10()
			var h: String = str(o.tab[0]) if r2 <= 3 else (str(o.tab[1]) if r2 <= 6 else str(o.tab[2]))
			if o.has("primo_libero"):
				h = ""
				for x in o.primo_libero:
					if p.unita_in(str(x), "us").is_empty():
						h = str(x)
						break
				if h == "":
					h = str(o.primo_libero[0])
			var rientrati := 0
			for n in [72, 73]:
				var g3: Dictionary = p.u("g%d" % n)
				if not g3.is_empty() and str(g3.stato) == "rimosso":
					g3.stato = "attivo"
					g3.hex = h
					g3.postura = "crouching"
					g3.reazione = "M" if int(p.s.condizione) == 3 else ""
					rientrati += 1
					p._log("attivazione", "Il %s rientra in mappa in %s." % [p.nome(g3), h])
			if rientrati > 0:
				ss.m21.op_comune({"op": "ss_inizia_round"}, ctx)
		"ss24_tiro_nascosto":
			var lista: Array = p.americani_attivi_in_mappa().filter(func(a): return a.hex == str(ctx.get("hex", "")))
			if lista.is_empty():
				return true
			var a: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
			var r3: int = p.d10()
			var mirato: bool = p.d10() >= 7
			var serve := 2 + (2 if mirato else 0) - (2 if a.postura == "prone" else 0)
			p._log("dado", "Un tedesco nascosto spara a %s: serve 0–%d, esce %d." % [p.nome(a), maxi(0, serve - 1), r3])
			if r3 < serve:
				p._applica_danno(a, T.lettera_danno(T.ARMI.mp.danni, p.d10()), {})
		"ss_granata_difettosa_c":
			ss.m21._granata_difettosa()
		"ss22_mortaio24":
			ss.m20.attiva_mortaio(str(o.hex), "")
			if p.fase_round():
				p.s.round.get("due_turni_de", []).append_array(["g471", "g472", "g473"])
		"ss22_esce24":
			var g4: Dictionary = p.u(str(ctx.get("g", "")))
			if not g4.is_empty():
				ss.m20._togli(g4, 0, "")
				p._pv(-1, "tedesco uscito")
				p._log("tedesco", "Il %s esce dalla mappa." % p.nome(g4))
		"ss22_torrente_scivola24":
			if _st().get("s370", false):
				return true
			var l: Array = (p.americani() + p.tedeschi()).filter(func(x): return p.attivo(x) and p.in_mappa(x) and p.terreno.tipo(x.hex) == "stream")
			if l.is_empty():
				return true
			_st().s370 = true
			var y: Dictionary = l[p.rng.randi_range(0, l.size() - 1)]
			if not p.controllo_pc(y, 0, "scivola sui sassi del torrente") and int(y.munizioni.get("granata", 0)) > 0:
				y.munizioni.granata = int(y.munizioni.granata) - 1
		"ss24_g_par":
			var g5: Dictionary = p.u(str(ctx.get("g", "")))
			if not g5.is_empty():
				p.ia._g = g5
				p.ia.esegui(int(o.n))
		_:
			return ss.m21.op_comune(o, ctx)
	return true

func test(t: Dictionary, ctx: Dictionary):
	if not attiva():
		return null
	if t.has("ss24_est_di_k"):
		for a in p.americani_attivi_in_mappa():
			if E.riga(a.hex) > 0 and E.colonna(a.hex) > E.colonna("K1"):
				return true
		return false
	if t.has("ss24_incustoditi"):
		return not incustoditi().is_empty()
	if t.has("in_rounds"):
		return p.fase_round() == bool(t.in_rounds)
	if t.has("ss24_piano"):
		var a: Dictionary = p.u(str(ctx.get("ids", [""])[0])) if not ctx.get("ids", []).is_empty() else {}
		return not a.is_empty() and p.piano(a) == int(t.ss24_piano)
	if t.has("ss24_strada"):
		return p.terreno.tipo(str(ctx.get("hex", ""))) == "road"
	if t.has("ss24_us_visto"):
		var g: Dictionary = p.u(str(ctx.get("g", "")))
		return not g.is_empty() and not t_bersagli(g).is_empty()
	if t.has("ss_dispari"):
		return (int(p.s.get("round", {}).get("numero_azione", p.d10())) % 2 == 1) == bool(t.ss_dispari)
	return null

func t_bersagli(g: Dictionary) -> Array:
	return p.americani_attivi_in_mappa().filter(func(a): return p.vede_unita(g, a))
