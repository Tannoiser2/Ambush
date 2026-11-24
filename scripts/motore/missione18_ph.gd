extends RefCounted
## Purple Heart, Missione 18 «Il mattino dopo»: rumore di cingoli all’alba, Panzer IV e granatieri da est, tre Sherman di
## rinforzo (guidati dai paragrafi finché la radio non li mette ai tuoi ordini), il Jagdpanther da servire, l’ufficiale
## sotto la Kübelwagen e la decisione finale: tenere la posizione (Condizione 5) o ripiegare a ovest (Condizione 6).

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

const INGRESSI_SHERMAN := ["B19", "F19", "K19", "N19", "R19"]
const SHERMAN := ["AA", "BB", "CC"]

var p  # Partita
var ph  # missioni_ph

func _init(partita, missioni_ph) -> void:
	p = partita
	ph = missioni_ph

func attiva() -> bool:
	return ph.attiva() and bool(p.regola("missione_18", false))

func _st() -> Dictionary:
	var st: Dictionary = ph._st()
	if not st.has("m18"):
		st.m18 = {}
	return st.m18

# ------------------------------------------------------------------ preparazione
func prepara() -> void:
	for h in p.regola("macerie_iniziali", []):
		p.s.modifiche[str(h)] = "rubble"
	p.terreno.imposta_modifiche(p.s.modifiche)
	if not p.s.has("guadi"):
		p.s.guadi = []
	for h in p.regola("guadi_iniziali", []):
		if not (str(h) in p.s.guadi):
			p.s.guadi.append(str(h))
			p.s.punti[str(h)] = "guado"
	p._applica_regole_terreno()
	p._log("info", "Macerie in %s; guadi in %s (i mezzi li attraversano con 3 PM)." % [", ".join(p.regola("macerie_iniziali", [])), ", ".join(p.regola("guadi_iniziali", []))])
	ph.munizioni_consumate()
	if bool(p.regola("ferito_casuale", false)):
		var squadra: Array = p.americani().filter(func(a): return not a.get("carro_us", false))
		if not squadra.is_empty():
			var f: Dictionary = squadra[p.rng.randi_range(0, squadra.size() - 1)]
			f.ferito = true
			p._log("dado", "%s comincia la missione ferito." % p.nome(f))
	p._log("info", "La radio è gratis: la porta il sergente A (funziona finché lui è attivo in mappa).")

# ------------------------------------------------------------------ operazioni
func op(o: Dictionary, ctx: Dictionary) -> bool:
	match str(o.op):
		"m18_rumore":
			if not p.fase_round():
				p._inizia_round_da_attivazione([], {"adv": null, "two": [], "us_two": false}, "")
				p.s.round.tutti_consapevoli = true
				_st().arrivo_512 = 2
			else:
				_st().arrivo_512 = int(p.s.round.get("n", 0)) + 1
			p._log("info", "I Round iniziano anche senza tedeschi in mappa: all’inizio del Round %d, al posto degli eventi, si legge il 512." % int(_st().arrivo_512))
		"m18_panzer":
			_panzer(o, ctx)
		"m18_ufficiale":
			_st().ufficiale = str(ctx.get("hex", ""))
			if not p.s.has("scelte"):
				p.s.scelte = {}
			p.s.scelte["663"] = "Accendi la sigaretta all’ufficiale (663)"
			p.s.scelte["677"] = "Rifiuta la sigaretta (677)"
			p.s.scelte["m18resa"] = "Arrenditi all’ufficiale: la missione finisce"
		"m18_sigaretta":
			_togli_scelte_ufficiale()
			var h: String = str(_st().get("ufficiale", ""))
			var chi: Array = p.unita_in(h, "us").filter(func(a): return not a.get("carro_us", false))
			if chi.is_empty():
				p._log("info", "Nessun soldato è rimasto accanto all’ufficiale.")
				return true
			var a: Dictionary = chi[0]
			for x in chi:
				if int(x.PC) > int(a.PC):
					a = x
			p.leggi("677" if p.controllo_pc(a, 0, "la sigaretta") else "673", {"hex": h, "ids": [a.id]})
		"m18_luger":
			_togli_scelte_ufficiale()
			ph._bottino(str(_st().get("ufficiale", ctx.get("hex", ""))), [{"arma": "pistol"}])
		"m18_esplosione_kubel":
			_togli_scelte_ufficiale()
			var hk: String = str(_st().get("ufficiale", ""))
			p._fx("esplosione", {"a": hk, "grande": true})
			for x in p.unita_in(hk):
				if p.attivo(x):
					p._uccidi(x, "nell’esplosione della Kübelwagen")
		"m18_resa":
			_togli_scelte_ufficiale()
			p._log("fine", "La squadra si arrende: passerà il resto della guerra in un campo di prigionia.")
			_st().resa = true
			p._calcola_fine("resa")
		"m18_relitto_jagd":
			ph._relitto(str(o.hex), "Jagdpanther distrutto")
			_st().jagd_hex = str(o.hex)
		"m18_jagdpanther":
			_st().jagd = {"hex": str(_st().get("jagd_hex", ctx.get("hex", ""))), "colpi": 4, "carico": false, "equipaggio": []}
			p._log("info", "Il Jagdpanther in %s si può servire: entra con due soldati nell’esagono e usa «Sali sul Jagdpanther»." % _st().jagd.hex)
		"m18_caduti":
			_caduti(o)
		"m18_caduto_tedesco":
			var hc: String = str(ctx.get("hex", ""))
			var items: Array = [{"arma": "bolt"}, {"mun": "bolt", "n": 1}]
			var d: int = p.d10()
			p._log("dado", "Perquisizione del tedesco caduto in %s: dado %d → %s." % [hc, d, "una granata" if d <= 4 else "nessuna granata"])
			if d <= 4:
				items.append({"mun": "granata", "n": 1})
			ph._bottino(hc, items)
		"m18_sherman":
			_sherman()
		"m18_decisione":
			_st().decisione = true
			if not p.s.has("scelte"):
				p.s.scelte = {}
			p.s.scelte["992"] = "Decisione: tieni la posizione (992)"
			p.s.scelte["994"] = "Decisione: ripiega a ovest (994)"
			p._log("info", "All’inizio del prossimo Round, al posto della fase degli eventi, devi decidere: tenere la posizione o ripiegare.")
		"m18_tieni":
			_decisa("tieni")
		"m18_ripiega":
			_decisa("ripiega")
		"m18_radio_312":
			if _st().get("sherman_ai_ordini", false):
				p._log("info", "Gli Sherman sono già ai tuoi ordini: nessun evento.")
			elif p.radio_presidiata():
				p.leggi("318", {})
			else:
				_st().attesa_318 = true
				p._log("info", "La radio non è presidiata: il 318 si legge appena (e se) torna a esserlo.")
		"m18_sherman_comando":
			_sherman_ai_ordini()
		"m18_981":
			_981()
		"m18_880":
			var gm: Dictionary = p.u(str(ctx.get("g", "")))
			if not gm.is_empty() and gm.lato == "de":
				p.ia.imposta_reazione(ctx, "B")
			if ctx.get("veicolo", false):
				ctx.verso_veicolo = ""
			else:
				p.ia.ferma()
		_:
			return false
	return true

func _togli_scelte_ufficiale() -> void:
	for k in ["663", "677", "m18resa"]:
		p.s.get("scelte", {}).erase(k)

# ------------------------------------------------------------------ test dei paragrafi
func test(t: Dictionary, ctx: Dictionary):
	if t.has("us_est_fiume"):
		return _us_a_est(false) == bool(t.us_est_fiume)
	if t.has("comandante_us"):
		var c: bool = p.americani_attivi_in_mappa().any(func(a): return a.get("comandante", false) and not a.get("carro_us", false))
		return c == bool(t.comandante_us)
	if t.has("veicolo_lato"):
		var v: Dictionary = p.veicoli.v(str(ctx.get("veicolo_id", "")))
		return bool(ctx.get("veicolo", false)) and not v.is_empty() and str(v.lato) == str(t.veicolo_lato)
	if t.has("m18_guado"):
		var v2: Dictionary = p.veicoli.v(str(ctx.get("veicolo_id", "")))
		if not bool(ctx.get("veicolo", false)) or v2.is_empty():
			return false
		if v2.lato == "de":
			return _us_a_est(str(t.m18_guado) == "si")
		return _mezzi_tedeschi_a_est()
	if t.has("us_a_est_hex"):
		var h: String = str(ctx.get("hex", ""))
		return p.americani_attivi_in_mappa().any(func(a): return E.riga(a.hex) < E.riga(h)) == bool(t.us_a_est_hex)
	if t.has("senza_bersagli"):
		var g: Dictionary = p.u(str(ctx.get("g", "")))
		if g.is_empty():
			return true
		return p.veicoli.bersagli_carro(g).is_empty() == bool(t.senza_bersagli)
	return null

## «A est del fiume»: in alto (righe sopra il fiume nella stessa colonna).
func est_del_fiume(h: String) -> bool:
	if h == "":
		return false
	var righe: Array = []
	for x in p.terreno.esagoni:
		if E.colonna(x) == E.colonna(h) and p.terreno.esagoni[x].get("t", "") == "stream":
			righe.append(E.riga(x))
	return not righe.is_empty() and E.riga(h) < righe.min()

## Americani attivi a est del fiume; con_mezzi conta anche i mezzi americani (Sherman, jeep).
func _us_a_est(con_mezzi: bool) -> bool:
	for a in p.americani_attivi_in_mappa():
		if a.get("in_jagd", false):
			continue
		if a.get("carro_us", false) and not con_mezzi:
			continue
		if est_del_fiume(a.hex):
			return true
	if con_mezzi:
		for v in p.veicoli.tutti():
			if v.lato == "us" and p.veicoli.attivo(v) and est_del_fiume(str(v.hex)):
				return true
	return false

func _mezzi_tedeschi_a_est() -> bool:
	for v in p.veicoli.tutti():
		if v.lato == "de" and p.veicoli.attivo(v) and not v.get("fuori_mappa_ph", false) and est_del_fiume(str(v.hex)):
			return true
	return false

# ------------------------------------------------------------------ Round
func inizio_round() -> void:
	if not attiva():
		return
	var n := int(p.s.round.get("n", 0))
	var a512 := int(_st().get("arrivo_512", 0))
	if a512 > 0 and n >= a512:
		_st().arrivo_512 = 0
		_st().salta_evento = "512"
	if _st().get("decisione", false):
		_st().salta_evento = "decisione"

func salta_evento() -> bool:
	if not attiva():
		return false
	var se: String = str(_st().get("salta_evento", ""))
	if se == "":
		return false
	_st().salta_evento = ""
	if se == "512":
		p._log("info", "Al posto del controllo degli eventi casuali: paragrafo 512.")
		p.leggi("512", {})
	else:
		p._log("info", "Al posto della fase degli eventi si prende la decisione.")
	return true

## La decisione (306/990) deve essere presa prima di proseguire nel Round.
func decisione_pendente() -> bool:
	return attiva() and bool(_st().get("decisione", false))

func round_obbligati() -> bool:
	if not attiva():
		return false
	if int(_st().get("arrivo_512", 0)) > 0:
		return true
	return _sherman_in_gioco_ia() or decisione_pendente()

func _decisa(modo: String) -> void:
	_st().decisione = false
	_st().modo = modo
	for k in ["992", "994"]:
		p.s.get("scelte", {}).erase(k)
	p.missione.vittoria_pv = 36 if modo == "tieni" else 30
	p._log("info", "Decisione presa: %s. Servono %d PV per vincere." % ["si tiene la posizione" if modo == "tieni" else "si ripiega verso ovest", int(p.missione.vittoria_pv)])

func modo() -> String:
	return str(_st().get("modo", ""))

func vittoria_pv() -> int:
	return {"tieni": 36, "ripiega": 30}.get(modo(), 0)

func uscita_vietata(h: String) -> bool:
	return attiva() and modo() != "ripiega"

## Uscita dal bordo ovest dopo l’ordine di ripiegare: +2 PV per soldato o mezzo attivo.
func uscita(a: Dictionary, h: String) -> void:
	if not attiva() or modo() != "ripiega" or not p.attivo(a) or E.riga(h) != 19:
		return
	if a.get("carro_us", false):
		p._pv(2, "%s esce dal bordo ovest" % p.nome(a))
		return
	p._pv(2, "%s esce dal bordo ovest" % p.nome(a))

func tedesco_uscito(x: Dictionary, h: String) -> void:
	if attiva() and modo() == "ripiega" and h != "" and E.riga(h) == 19:
		p._pv(-2, "%s esce dal bordo ovest" % p.nome(x))

func niente_pv_incapacitati() -> bool:
	return attiva() and modo() == "tieni"

func controlla() -> void:
	if not attiva() or p.s.fase == "fine":
		return
	if vittoria_pv() > 0:
		p.missione.vittoria_pv = vittoria_pv()
	if _st().get("attesa_318", false) and p.radio_presidiata():
		_st().attesa_318 = false
		p.leggi("318", {})
	_jagd_equipaggio()
	if modo() == "tieni" and p.tedeschi_attivi().filter(func(g): return p.attivo(g) and not g.get("fuori_mappa_ph", false)).is_empty() and not _sherman_in_gioco_ia():
		p._log("info", "Non ci sono più tedeschi attivi in mappa: la missione termina.")
		p._calcola_fine("obiettivo")
		return
	if modo() == "ripiega":
		var fanti: Array = p.americani_attivi_in_mappa().filter(func(a): return not a.get("carro_us", false))
		if fanti.is_empty():
			p._log("info", "Non ci sono più americani attivi in mappa: la missione termina.")
			p._calcola_fine("ritirata")

func righe_fine(righe: Array) -> int:
	if not attiva():
		return 0
	var tot := 0
	if modo() == "tieni":
		var n := 0
		for a in p.americani_attivi_in_mappa():
			if est_del_fiume(a.hex) and not a.get("in_jagd", false):
				n += 1
		for v in p.veicoli.tutti():
			if v.lato == "us" and p.veicoli.attivo(v) and est_del_fiume(str(v.hex)) and not str(v.id).begins_with("vsh"):
				n += 1
		if n > 0:
			righe.append(["Americani attivi (soldati e mezzi) a est del fiume (%d)" % n, n])
			tot += n
	return tot

# ------------------------------------------------------------------ Panzer IV
func _panzer(o: Dictionary, ctx: Dictionary) -> void:
	var coppie: Array = []
	for i in 4:
		coppie.append([57 + i, str(o.hex[i])])
	p._op_attiva({"op": "activate", "g": coppie, "stance": "crouching", "adv": null, "two": [57, 58, 59, 60], "us_two": false,
		"aware": false, "reaction": null, "rounds": true}, ctx)
	var fuori: bool = bool(o.get("fuori", false))
	for i in 4:
		var g: Dictionary = p.u("g%d" % (57 + i))
		var v: Dictionary = p.veicoli.di(g)
		if g.is_empty() or v.is_empty():
			continue
		v.fronte = 4  # verso ovest (in basso)
		if fuori:
			g.fuori_mappa_ph = true
			v.fuori_mappa_ph = true
	if not fuori:
		for a in p.americani():
			if p.attivo(a) or a.stato == "fuori":
				a.consapevole = true
		if p.fase_round():
			p.s.round.tutti_consapevoli = true
		p._log("info", "Il rumore dei carri sveglia tutti: gli americani sono consapevoli.")
	else:
		p._log("info", "I quattro Panzer IV aspettano fuori mappa accanto ad A5: entrano al loro primo turno.")

## Un mezzo fuori mappa (Panzer accanto ad A5, Sherman accanto al bordo ovest) entra al suo primo turno pagando l’esagono.
func entra_dal_bordo(veic: Dictionary) -> int:
	if not veic.get("fuori_mappa_ph", false):
		return 0
	veic.fuori_mappa_ph = false
	for x in p.veicoli.occupanti(veic):
		x.erase("fuori_mappa_ph")
	var c: int = int(T.COSTO_VEICOLO.get(p.terreno.tipo(str(veic.hex)), 1))
	p._log("tedesco" if veic.lato == "de" else "info", "%s entra in mappa in %s (%d PM)." % [p.veicoli.nome_art(veic), veic.hex, c])
	p._fx("compare", {"id": p.veicoli.autista(veic).get("id", ""), "a": veic.hex, "amico": veic.lato == "us"})
	return maxi(1, c)

# ------------------------------------------------------------------ caduti della battaglia (s8)
func _caduti(o: Dictionary) -> void:
	ph._relitto(str(o.semicingolato), "Semicingolato distrutto")
	if not p.s.has("da_leggere"):
		p.s.da_leggere = {}
	for h in o.tedeschi:
		if str(h) != str(o.cerca):
			p.s.da_leggere[str(h)] = "c18"
		if not p.s.punti.has(str(h)):
			p.s.punti[str(h)] = "tedesco caduto"
	p.s.da_leggere[str(o.cerca)] = "310,c18" if str(o.cerca) in o.tedeschi else "310"
	p._log("info", "Tedeschi caduti in %s: entrando in ciascun esagono lo si perquisisce. Nell’esagono %s c’è altro equipaggiamento (310)." % [", ".join(o.tedeschi), o.cerca])

# ------------------------------------------------------------------ 981: munizioni finite
func _981() -> void:
	var cand: Array = []
	for g in p.tedeschi():
		if not (p.attivo(g) and p.in_mappa(g)) or not (g.id in p.s.round.get("sparato_prec", [])):
			continue
		for w in g.armi:
			if w.tipo != "pzf" and not w.get("rotta", false) and T.ARMI.has(w.tipo) and T.ARMI[w.tipo].has("gittate"):
				cand.append([g, w])
	if cand.is_empty():
		p._log("info", "Nel Round precedente nessuna arma tedesca ha sparato: nessun effetto.")
		return
	var x: Array = cand[p.rng.randi_range(0, cand.size() - 1)]
	var g: Dictionary = x[0]
	var w: Dictionary = x[1]
	g.armi.erase(w)
	p._log("info", "Il %s ha finito le munizioni (%s)." % [p.nome(g), T.ARMI[w.tipo].nome.to_lower()])
	var altre: Array = g.armi.filter(func(a): return a.tipo != "pzf" and not a.get("rotta", false) and T.ARMI.get(a.tipo, {}).has("gittate"))
	if altre.is_empty() and str(g.get("reazione", "")) != "S":
		g.reazione = "A"
		g.senza_armi_18 = true
		p._log("tedesco", "Senza altre armi personali il %s passa alla reazione speciale A." % p.nome(g))

## Un tedesco in reazione A che trova una nuova arma la lascia.
func arma_trovata(g: Dictionary) -> void:
	if g.get("senza_armi_18", false) and str(g.get("reazione", "")) == "A":
		g.erase("senza_armi_18")
		g.reazione = ""
		p._log("tedesco", "Il %s ha una nuova arma: toglie la reazione speciale A." % p.nome(g))

# ------------------------------------------------------------------ Sherman di rinforzo
func _sherman() -> void:
	if not p.s.unita.get("AA", {}).is_empty():
		return
	if not p.fase_round():
		p._inizia_round_da_attivazione([], {"adv": null, "two": [], "us_two": false}, "")
	var dati: Dictionary = p.missione.get("carri_us", {})
	var ing: String = _ingresso_sherman()
	var nomi: Array = []
	for i in 3:
		var id: String = SHERMAN[i]
		var carta: Dictionary = dati.get(str(i + 1), {})
		var riga: Dictionary = carta.get("carro", {}).get("righe", {}).get("5", {})
		var d := {"id": id, "nome": "Sherman", "IN": int(riga.get("IN", 4)), "PC": int(riga.get("PC", 6)), "WS": int(riga.get("WS", 1)),
			"DS": int(riga.get("DS", 6)), "MPA": 6, "comandante": false, "porte": ["cannone", "mmg"], "munizioni": {"cannone": 20, "mmg": 10}}
		var z: Dictionary = p._nuovo_americano(d)
		z.num = i + 1
		z.stato = "fuori"
		z.carro_us = true
		z.ia_sherman = true
		z.consapevole = true
		z.postura = "crouching"
		z.ingresso_18 = ing
		p.s.unita[id] = z
		var v: Dictionary = p.veicoli.crea("vsh%d" % (i + 1), "sherman", "", "us")
		v.equipaggio = 5
		v.chiuso = false
		v.cannone_pronto = true
		v.fronte = 1
		v.primo_turno = 944
		v.fuori_mappa_ph = true
		p.s.imbarco = true
		z.veicolo = v.id
		v.occupanti.append(id)
		p.s.imbarco = false
		for a in z.armi:
			a.preparata = true
		nomi.append(id)
	_st().sherman = true
	p._log("info", "Tre Sherman (%s) aspettano fuori mappa accanto a %s: entrano appena ricevono un turno. Puoi cambiare l’esagono d’ingresso finché non sono entrati." % [", ".join(nomi), ing])
	p._fx("compare", {"id": "AA", "a": "", "amico": true})

## Ingresso suggerito: il punto del bordo ovest più vicino alla squadra.
func _ingresso_sherman() -> String:
	var migliore := "K19"
	var dmin := 999
	var squadra: Array = p.americani_attivi_in_mappa().filter(func(a): return not a.get("carro_us", false))
	for h in INGRESSI_SHERMAN:
		var tot := 0
		for a in squadra:
			tot += E.distanza(a.hex, h)
		if squadra.is_empty():
			tot = E.distanza(h, "K15")
		if tot < dmin:
			dmin = tot
			migliore = h
	return migliore

## Comando dell’interfaccia: sposta l’ingresso di uno Sherman ancora fuori mappa al punto successivo.
func cambia_ingresso(id: String) -> String:
	var z: Dictionary = p.u(id)
	if z.is_empty() or z.stato != "fuori":
		return ""
	var i: int = INGRESSI_SHERMAN.find(str(z.get("ingresso_18", "K19")))
	z.ingresso_18 = INGRESSI_SHERMAN[(i + 1) % INGRESSI_SHERMAN.size()]
	return str(z.ingresso_18)

func sherman_da_piazzare() -> Array:
	if not attiva():
		return []
	return SHERMAN.filter(func(id): return not p.u(id).is_empty() and p.u(id).stato == "fuori")

func _sherman_in_gioco_ia() -> bool:
	for id in SHERMAN:
		var z: Dictionary = p.u(id)
		if not z.is_empty() and z.get("ia_sherman", false) and (p.attivo(z) or z.stato == "fuori"):
			return true
	return false

func _sherman_ai_ordini() -> void:
	if _st().get("sherman_ai_ordini", false):
		p._log("info", "L’evento è già avvenuto: nessun evento.")
		return
	_st().sherman_ai_ordini = true
	for id in SHERMAN:
		var z: Dictionary = p.u(id)
		if not z.is_empty():
			z.ia_sherman = false
	p._log("info", "Gli Sherman passano ai tuoi ordini: da ora li muovi e li fai sparare come vuoi (come lo Sherman Z).")

func sherman_ia(a: Dictionary) -> bool:
	return a.get("ia_sherman", false)

## Turni degli Sherman guidati dai paragrafi nella casella americana corrente. true se qualcuno ha agito.
func turni_sherman(n: int) -> bool:
	if not attiva():
		return false
	var agito := false
	for id in SHERMAN:
		var z: Dictionary = p.u(id)
		if z.is_empty() or not z.get("ia_sherman", false) or int(z.turni) != n or z.slot != "turni":
			continue
		if not (p.attivo(z) or z.stato == "fuori"):
			continue
		_turno_sherman(z)
		p._consuma_turno(z)
		agito = true
		if p.s.fase != "round":
			break
	return agito

func _turno_sherman(z: Dictionary) -> void:
	var v: Dictionary = p.veicoli.di(z)
	if v.is_empty() or not p.veicoli.attivo(v):
		return
	if z.stato == "fuori":
		z.stato = "attivo"
		z.hex = str(z.get("ingresso_18", "K19"))
		v.hex = z.hex
	p.veicoli.turno_carro(p.ia, z, v)

# ------------------------------------------------------------------ il Jagdpanther (599)
func jagd() -> Dictionary:
	return _st().get("jagd", {})

func puo_salire_jagd(a: Dictionary) -> bool:
	var j: Dictionary = jagd()
	return attiva() and not j.is_empty() and a.hex == str(j.hex) and not a.get("in_jagd", false) and not a.get("carro_us", false) \
		and j.equipaggio.size() < 2

func sali_jagd(a: Dictionary) -> String:
	var j: Dictionary = jagd()
	if not puo_salire_jagd(a):
		return "Nel Jagdpanther non c’è posto."
	j.equipaggio.append(a.id)
	a.in_jagd = true
	a.postura = "crouching"
	if j.equipaggio.size() == 2:
		_arma_jagd(j)
	p._log("azione", "%s sale sul Jagdpanther (%d/2)." % [p.nome(a), j.equipaggio.size()])
	return ""

func scendi_jagd(a: Dictionary) -> void:
	var j: Dictionary = jagd()
	if j.is_empty() or not (a.id in j.equipaggio):
		return
	j.equipaggio.erase(a.id)
	a.erase("in_jagd")
	_togli_armi_jagd(j)
	p._log("azione", "%s scende dal Jagdpanther." % p.nome(a))

## Con due uomini a bordo il cannone (4 colpi, scarico) e la mitragliatrice di scafo sono armi di squadra (abilità −1).
func _arma_jagd(j: Dictionary) -> void:
	for id in j.equipaggio:
		var a: Dictionary = p.u(id)
		if a.is_empty() or a.armi.any(func(w): return w.get("jagd", false)):
			continue
		a.armi.append({"tipo": "cannone", "inceppata": false, "rotta": false, "preparata": bool(j.carico), "catturata": false, "jagd": true})
		a.armi.append({"tipo": "mmg", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "jagd": true})
		a.munizioni["cannone"] = int(j.colpi)
		a.munizioni["mmg"] = maxi(int(a.munizioni.get("mmg", 0)), 5)

func _togli_armi_jagd(j: Dictionary) -> void:
	for x in p.americani():
		for w in x.armi.duplicate():
			if w.get("jagd", false):
				if w.tipo == "cannone":
					j.carico = bool(w.preparata)
					j.colpi = int(x.munizioni.get("cannone", j.colpi))
					x.munizioni.erase("cannone")
				x.armi.erase(w)

## Equipaggio che non è più nell’esagono o non è attivo: scende.
func _jagd_equipaggio() -> void:
	var j: Dictionary = jagd()
	if j.is_empty():
		return
	for id in j.equipaggio.duplicate():
		var a: Dictionary = p.u(id)
		if a.is_empty() or not p.attivo(a) or a.hex != str(j.hex):
			if not a.is_empty():
				a.erase("in_jagd")
			j.equipaggio.erase(id)
			_togli_armi_jagd(j)
	# munizioni del cannone condivise tra i due serventi
	var colpi := int(j.colpi)
	for id in j.equipaggio:
		var a: Dictionary = p.u(id)
		colpi = mini(colpi, int(a.munizioni.get("cannone", colpi)))
	j.colpi = colpi
	for id in j.equipaggio:
		p.u(id).munizioni["cannone"] = colpi

## Il cannone e la mitragliatrice di scafo del Jagdpanther (casamatta rivolta a est, in alto) sparano solo verso il fronte.
func fronte_jagd(a: Dictionary, h: String) -> bool:
	var j: Dictionary = jagd()
	if j.is_empty() or not a.get("in_jagd", false) or h == str(j.hex):
		return true
	var verso: Vector2 = E.centro(h) - E.centro(str(j.hex))
	return rad_to_deg(absf(Vector2(0, -1).angle_to(verso))) <= 60.0

## Un colpo del cannone del Jagdpanther: si scarica e resta un colpo in meno (condiviso dai due serventi).
func sparato_jagd(arma: Dictionary) -> void:
	var j: Dictionary = jagd()
	if j.is_empty():
		return
	arma.preparata = false
	j.carico = false
	j.colpi = maxi(0, int(j.colpi) - 1)
	for id in j.equipaggio:
		var a: Dictionary = p.u(id)
		a.munizioni["cannone"] = int(j.colpi)
		for w in a.armi:
			if w.get("jagd", false) and w.tipo == "cannone":
				w.preparata = false
	p._log("info", "Restano %d colpi per il cannone del Jagdpanther." % int(j.colpi))
