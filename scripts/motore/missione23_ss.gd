extends RefCounted
## Silver Star, Missione 23 «Sconosciuti nella notte»: all’alba nella nebbia la squadra occupa un villaggio davanti a una galleria
## (mappa F, in alto è sud). Pattuglie tedesche come segnalini (NN: 55–58, MM: 62–65) che si avvicinano alla squadra e si
## schierano quando si vedono; razzi illuminanti e fili d’inciampo; filo spinato; edifici fortificati con le mitragliatrici
## 59/66; il Panzer 67 nascosto in una casa e il 68 che arriva; il superstite americano US 06 e lo Sherman US 07 di soccorso.
## Stato in p.s.ss.m23.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

const ESAGONI_PV := ["W8", "O14", "Q16", "S13", "V14"]
const PATTUGLIE_23 := {"NN": {"g": [55, 56, 57, 58], "pm": 5, "pv": 4, "capo": 58}, "MM": {"g": [62, 63, 64, 65], "pm": 4, "pv": 5, "capo": 65}}
const PATTUGLIE_24 := {"MM": {"g": [78, 79, 80, 81], "pm": 4, "pv": 4, "capo": 81}}
var PATTUGLIE: Dictionary:
	get:
		return PATTUGLIE_24 if int(p.missione.get("id", 0)) == 24 else PATTUGLIE_23

var p  # Partita
var ss  # missioni_ss.gd

func _init(partita, modulo) -> void:
	p = partita
	ss = modulo

func attiva() -> bool:
	return ss.attiva() and int(p.missione.get("id", 0)) == 23

## Segnalini delle pattuglie: Missioni 23 e 24.
func pattuglie_attive() -> bool:
	return ss.attiva() and int(p.missione.get("id", 0)) in [23, 24]

func _st() -> Dictionary:
	var st: Dictionary = ss._st()
	if not st.has("m23"):
		st.m23 = {"pattuglie": {}, "razzi": [], "filo": [], "fortificati": [], "pv_esagoni": [], "corrente": ""}
	return st.m23

# ------------------------------------------------------------------ terreno: razzi, filo spinato, edifici fortificati
func regole_terreno() -> void:
	if not attiva():
		return
	if not p.s.has("muri_sfondati"):
		p.s.muri_sfondati = [["T15", "S16"], ["Q16", "R16"], ["Q14", "R13"]]
		p.terreno.muri_sfondati = p.s.muri_sfondati
	for c in _st().razzi:
		p.terreno.illuminati[str(c)] = true
		for h in E.vicini(str(c)):
			p.terreno.illuminati[str(h)] = true

func fine_round() -> void:
	if not attiva():
		return
	if not _st().razzi.is_empty():
		_st().razzi = []
		p._applica_regole_terreno()
		p._log("info", "Il razzo illuminante si spegne.")

## Razzo illuminante su h (con l’esagono e i sei intorno): chi è illuminato fa un controllo di percezione, se riesce si butta a
## terra. Restituisce gli illuminati.
func razzo(h: String) -> Array:
	_st().razzi.append(h)
	p._applica_regole_terreno()
	p._fx("esplosione", {"a": h})
	var illuminati: Array = []
	for x in p.americani() + p.tedeschi():
		if p.attivo(x) and p.in_mappa(x) and (x.hex == h or E.distanza(x.hex, h) == 1):
			illuminati.append(x)
	p._log("info", "Un razzo illuminante si accende sopra %s: l’esagono e i sei intorno sono illuminati." % h)
	for x in illuminati:
		if p.controllo_pc(x, 0, "sotto il razzo illuminante"):
			x.postura = "prone"
	return illuminati

## 625/629: un tedesco nascosto spara a un illuminato.
func tiro_nascosto(arma: String, mirato: bool, ws: int, gittata: String) -> void:
	var lista: Array = p.americani_attivi_in_mappa().filter(func(a): return p.terreno.illuminati.has(a.hex))
	if lista.is_empty():
		return
	var a: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	var base: int = {"corta": 6, "media": 4, "lunga": 2}.get(gittata, 3) + ws + (2 if mirato else 0) - (2 if a.postura == "prone" else 0)
	var r: int = p.d10()
	p._log("dado", "Un tedesco nascosto spara a %s: serve 0–%d, esce %d." % [p.nome(a), maxi(0, base - 1), r])
	if r < base:
		p._applica_danno(a, T.lettera_danno(T.ARMI[arma].danni, p.d10()), {})
	else:
		p._log("info", "Mancato.")

func dopo_movimento(ids: Array) -> void:
	if not attiva():
		return
	for id in ids:
		var a: Dictionary = p.u(str(id))
		if a.is_empty() or a.lato != "us":
			continue
		var h: String = str(a.hex)
		if h in ESAGONI_PV and not (h in _st().pv_esagoni):
			_st().pv_esagoni.append(h)
			p._pv(1, "squadra in %s" % h)
		if p.fase_round() and h in _st().filo and str(a.get("veicolo", "")) == "":
			a.postura = "prone"
			p._log("info", "%s entra nel filo spinato e si butta a terra." % p.nome(a))
		var da: String = str(a.get("hex_prec", ""))
		if p.fase_round() and da in _st().filo and da != h and str(a.get("veicolo", "")) == "":
			if p.d10() == 0:
				p._log("danno", "%s resta impigliato nel filo spinato e si ferisce." % p.nome(a))
				p._applica_danno(a, "W", {})
	_dopo_movimento_pattuglie(ids)

func _dopo_movimento_pattuglie(ids: Array) -> void:
	if p.s.fase == "operazioni" and not ids.is_empty():
		_muovi_pattuglie(1, str(ids[0]))

## Filo spinato: nei Round +1 PM per entrare (solo americani a piedi).
func costo_passo(a: Dictionary, verso: String, base: int) -> int:
	if not attiva() or base < 0 or a.lato != "us" or not p.fase_round() or str(a.get("veicolo", "")) != "":
		return base
	return base + 1 if verso in _st().filo else base

func mod_tiro(tiratore: Dictionary, bersaglio: Dictionary, mods: Array) -> void:
	if attiva() and str(bersaglio.get("hex", "")) in _st().fortificati and tiratore.hex != bersaglio.hex:
		mods.append(["edificio fortificato", -2])

# ------------------------------------------------------------------ pattuglie (385, 389, 492, 620, 380, 383)
func piazza_pattuglia(nome: String, h: String) -> void:
	_st().pattuglie[nome] = {"hex": h}
	p._log("info", "Segnalino pattuglia %s in %s: si avvicina alla squadra a ogni esagono percorso da un americano (nei Round di %d PM a turno). Non si può attaccare." % [nome, h, int(PATTUGLIE[nome].pm)])

func _americano_piu_vicino(h: String) -> Dictionary:
	var migliore := {}
	for a in p.americani_attivi_in_mappa():
		if migliore.is_empty() or E.distanza(a.hex, h) < E.distanza(migliore.hex, h):
			migliore = a
	return migliore

func _vede(h_oss: String, h_ber: String) -> bool:
	return p.terreno.vede(h_oss, h_ber, "standing", "standing")

## Ogni segnalino avanza di n esagoni verso l’americano attivo più vicino; se ne vede uno, 620. Poi, se l’americano mosso vede un
## segnalino, 492.
func _muovi_pattuglie(n: int, mosso: String) -> void:
	for nome in _st().pattuglie.keys():
		var pt: Dictionary = _st().pattuglie[nome]
		for i in n:
			var bers := _americano_piu_vicino(str(pt.hex))
			if bers.is_empty() or E.distanza(pt.hex, bers.hex) <= 1:
				break
			var linea: Array = E.linea(str(pt.hex), str(bers.hex))
			if linea.size() < 2:
				break
			var prossimo := str(linea[1])
			if p.terreno.costo_movimento(str(pt.hex), prossimo) < 0:
				var alt: Array = E.vicini(str(pt.hex)).filter(func(x): return p.terreno.costo_movimento(str(pt.hex), str(x)) >= 0 \
					and E.distanza(str(x), bers.hex) < E.distanza(str(pt.hex), bers.hex))
				if alt.is_empty():
					break
				prossimo = str(alt[0])
			pt.hex = prossimo
		if not _st().pattuglie.has(nome):
			continue
		var visti: Array = p.americani_attivi_in_mappa().filter(func(a): return _vede(str(pt.hex), a.hex))
		if not visti.is_empty():
			_st().corrente = nome
			p.leggi("525" if int(p.missione.id) == 24 else "620", {"hex": pt.hex, "ids": []})
			continue
		var a: Dictionary = p.u(mosso)
		if not a.is_empty() and a.lato == "us" and p.attivo(a) and _vede(a.hex, str(pt.hex)):
			_st().corrente = nome
			p.leggi("741" if int(p.missione.id) == 24 else "492", {"hex": pt.hex, "ids": [a.id]})

## Nei Round i segnalini si muovono all’inizio di ogni Round.
func inizio_round() -> void:
	if not pattuglie_attive():
		return
	for nome in _st().pattuglie.keys():
		_muovi_pattuglie_round(nome)
	if not attiva():
		return
	if _st().get("leggi_316", false):
		_st().leggi_316 = false
		p.leggi("316", {})

func _muovi_pattuglie_round(nome: String) -> void:
	var pm := int(PATTUGLIE[nome].pm)
	var salva: Dictionary = _st().pattuglie
	var solo := {nome: salva[nome]}
	_st().pattuglie = solo
	_muovi_pattuglie(pm, "")
	if solo.has(nome):
		salva[nome] = solo[nome]
	else:
		salva.erase(nome)
	_st().pattuglie = salva

## Americani che vedono il segnalino corrente.
func osservatori() -> Array:
	var nome: String = _st().corrente
	if not _st().pattuglie.has(nome):
		return []
	var h: String = _st().pattuglie[nome].hex
	return p.americani_attivi_in_mappa().filter(func(a): return _vede(a.hex, h))

## 380/383: la pattuglia corrente si schiera intorno al segnalino.
func schiera_pattuglia(adv: String) -> void:
	var nome: String = _st().corrente
	if not _st().pattuglie.has(nome):
		return
	var h: String = _st().pattuglie[nome].hex
	_st().pattuglie.erase(nome)
	var r: int = p.d10()
	while r >= 8:
		r = p.d10()
	var diagramma := 1 + r / 2
	var posti: Array = [h] + E.vicini(h).filter(func(x): return E.valido(str(x)) and p.terreno.costo_movimento(h, str(x)) >= 0)
	var coppie: Array = []
	var nums: Array = PATTUGLIE[nome].g
	for i in nums.size():
		coppie.append([int(nums[i]), str(posti[(i + diagramma) % posti.size()]) if i > 0 else h])
	p._log("dado", "Dado %d: diagramma %d per la pattuglia %s." % [r, diagramma, nome])
	p._op({"op": "activate", "g": coppie, "stance": "crouching", "adv": adv, "two": [], "us_two": false, "aware": false,
		"reaction": "", "rounds": true}, {})
	p._pv(int(PATTUGLIE[nome].pv), "pattuglia %s in mappa" % nome)
	for n in nums:
		var g: Dictionary = p.u("g%d" % int(n))
		if g.is_empty():
			continue
		var bonus: int = 2 if not p.unita_in(g.hex, "us").is_empty() else (1 if not p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) == 1).is_empty() else 0)
		if not p.controllo_pc(g, bonus, "consapevolezza della pattuglia"):
			g.sorpreso_ss = true

# ------------------------------------------------------------------ azioni delle pattuglie (730, 735, 739, 762)
func turno_pattuglia(t, g: Dictionary, n: int) -> void:
	var num := int(g.num)
	if n == 739 or n == 735:
		var qui: Array = p.unita_in(g.hex, "us")
		if not qui.is_empty():
			t._assalta(t._bersaglio_assalto())
			return
		if n == 739 and int(g.munizioni.get("granata", 0)) > 0:
			var vicini: Array = t.bersagli(g).filter(func(a): return E.distanza(a.hex, g.hex) <= 6)
			if not vicini.is_empty():
				var d := E.distanza(vicini[0].hex, g.hex)
				if d <= 3:
					t._accovacciati()
				else:
					t._alzati()
				if t._lancia_granata(6):
					t._prono_se_libero()
					return
		n = 730 if num in [62, 63, 64, 65] else 762
	var qui2: Array = p.unita_in(g.hex, "us")
	if not qui2.is_empty():
		t._assalta(t._bersaglio_assalto())
		return
	var adiac: Array = p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) == 1)
	var compagni: Array = []
	for nome in PATTUGLIE:
		if num in PATTUGLIE[nome].g:
			compagni = PATTUGLIE[nome].g
	var fuori: int = compagni.filter(func(x): return not p.attivo(p.u("g%d" % int(x)))).size()
	if not adiac.is_empty():
		if n == 730 and int(g.WS) <= 0 and int(g.munizioni.get("granata", 0)) > 0:
			t._accovacciati()
			if t._lancia_granata(1):
				t._prono_se_libero()
				return
		t._assalta(adiac[0], true)
		return
	if fuori >= 2:
		var vicino := _americano_piu_vicino(g.hex)
		if not vicino.is_empty():
			var via: Array = E.vicini(g.hex).filter(func(x): return E.distanza(str(x), vicino.hex) > E.distanza(g.hex, vicino.hex))
			if not via.is_empty():
				t._corri_verso(str(via[0]))
		if t.bersagli(g).is_empty() and (vicino.is_empty() or E.distanza(vicino.hex, g.hex) > 6):
			ss.m20._togli(g, 0, "")
			p._log("tedesco", "Il %s si ritira e sparisce." % p.nome(g))
		return
	var visti: Array = t.bersagli(g)
	if not visti.is_empty():
		t._accovacciati()
		t._miglior_tiro("vicino")
		t._prono_se_libero()
		return
	var v2 := _americano_piu_vicino(g.hex)
	if not v2.is_empty():
		t._corri_verso(v2.hex)
		t._prono_se_libero()

# ------------------------------------------------------------------ americani: superstite US 06 e Sherman US 07
func superstite(h: String) -> void:
	if not p.u("J").is_empty():
		return
	var d := {"id": "J", "nome": "Superstite", "IN": 2, "PC": 3, "WS": 1, "DS": 6, "MPA": 4, "comandante": false,
		"porte": ["sar", "bazooka"], "munizioni": {"sar": 2, "bazooka": 2, "granata": 1}}
	var z: Dictionary = p._nuovo_americano(d)
	z.stato = "attivo"
	z.hex = h
	z.postura = "prone"
	z.consapevole = true
	for w in z.armi:
		w.preparata = w.tipo != "bazooka"
	p.s.unita["J"] = z
	p._fx("compare", {"id": "J", "a": h, "amico": true})
	p._log("info", "Il superstite di una pattuglia americana (US 06) si unisce alla squadra in %s." % h)

func sherman(h: String) -> void:
	if not p.u("AA").is_empty():
		return
	var riga: Dictionary = p.missione.get("carri_us", {}).get("7", {}).get("carro", {}).get("righe", {}).get("5", {})
	var z: Dictionary = ss.m21._nuovo_us("AA", "Sherman", riga, h, ["cannone", "mmg"], {"cannone": 20, "mmg": 10})
	z.num = 7
	z.carro_us = true
	var v: Dictionary = p.veicoli.crea("vsh7", "sherman", h, "us")
	v.nome = "Sherman"
	v.equipaggio = 5
	v.chiuso = false
	v.cannone_pronto = false
	v.primo_turno = 944
	v.pv_distrutto_us = 3
	z.veicolo = v.id
	v.occupanti.append("AA")
	p._log("info", "Lo Sherman US 07 entra in %s: non è ai tuoi ordini e segue i riferimenti neri delle carte." % h)

# ------------------------------------------------------------------ fine
func controlla() -> void:
	if not attiva() or p.s.fase == "fine":
		return
	if str(_st().get("modo", "")) == "":
		return
	if not (bool(p.s.avvistamenti[7]) and bool(p.s.avvistamenti[8])):
		return
	var de: Array = p.tedeschi().filter(func(g): return p.attivo(g) and p.in_mappa(g))
	if de.is_empty() and int(p.s.condizione) == 3:
		p._log("info", "s7 e s8 sono avvenuti e non ci sono tedeschi attivi: la missione termina.")
		p._calcola_fine("obiettivo")

func blocca_fine() -> bool:
	return attiva() and not p.americani_attivi_in_mappa().is_empty()

# ------------------------------------------------------------------ operazioni e test
func op(o: Dictionary, ctx: Dictionary) -> bool:
	if not attiva():
		return false
	match str(o.op):
		"ss23_pattuglia":
			var r: int = p.d10()
			var tab: Array = o.tab
			while str(tab[r]) == "":
				r = p.d10()
			p._log("dado", "Dado %d." % r)
			piazza_pattuglia(str(o.nome), str(tab[r]))
			if p.s.fase == "operazioni" or p.fase_round():
				_muovi_pattuglie(0, "")
		"ss23_schiera_pattuglia":
			schiera_pattuglia(str(o.adv))
		"ss23_pc_osservatori":
			var oss := osservatori()
			var riusciti: Array = oss.filter(func(a): return p.controllo_pc(a, 0, "riconoscere la pattuglia"))
			for a in riusciti:
				a.consapevole = true
			for x in (o.ok if not riusciti.is_empty() else o.ko):
				p._op(x, ctx)
		"ss23_razzo":
			var h: String = str(ctx.get("hex", "")) if str(o.get("hex", "")) == "@hex" else str(o.get("hex", ""))
			if o.has("tab"):
				var r2: int = p.d10()
				while str(o.tab[r2]) == "":
					r2 = p.d10()
				h = str(o.tab[r2])
				p._log("dado", "Dado %d: il razzo cade in %s." % [r2, h])
			var ill := razzo(h)
			for x in (o.con if not ill.is_empty() else o.get("senza", [])):
				p._op(x, ctx)
			if ill.is_empty():
				_st().razzi.erase(h)
				p._applica_regole_terreno()
		"ss23_tiro_nascosto":
			var r3: int = p.d10()
			tiro_nascosto(str(o.arma), r3 >= 7, int(o.ws), str(o.gittata))
			_st().razzi = []
			p._applica_regole_terreno()
		"ss23_filo":
			for hf in o.hex:
				if not (str(hf) in _st().filo):
					_st().filo.append(str(hf))
			p._log("info", "Filo spinato in %s (vedi 731)." % ", ".join(o.hex))
		"ss23_fortificato":
			var hf2: String = str(o.hex)
			if not (hf2 in _st().fortificati):
				_st().fortificati.append(hf2)
			p._op({"op": "activate", "g": [[59, hf2], [66, hf2]], "stance": "crouching", "adv": o.get("adv", null),
				"two": o.get("two", []), "us_two": bool(o.get("us_two", false)), "aware": false, "reaction": "", "rounds": true}, ctx)
			p._log("info", "Edificio fortificato in %s (porta verso %s): le mitragliatrici 59 e 66 sono dentro." % [hf2, str(o.porta)])
		"ss23_panzer":
			p._op({"op": "activate", "g": [[67, str(o.hex)]], "stance": "crouching", "adv": o.get("adv", null), "two": o.get("two", []),
				"us_two": bool(o.get("us_two", false)), "aware": false, "reaction": "", "rounds": true}, ctx)
			var v: Dictionary = p.veicoli.v("v67")
			if not v.is_empty():
				v.fronte = E.direzione(str(o.hex), str(o.verso))
		"ss23_panzer68":
			var h4: String = str(o.hex)
			if o.has("tab"):
				var r4: int = p.d10()
				var scelta: Array = o.tab[0] if r4 <= 2 else (o.tab[1] if r4 <= 5 else o.tab[2])
				h4 = str(scelta[0])
				p._log("dado", "Dado %d: il Panzer 68 entra in %s." % [r4, h4])
			p._op({"op": "activate", "g": [[68, h4]], "stance": "crouching", "adv": null, "two": o.get("two", []), "us_two": false,
				"aware": false, "reaction": "", "rounds": true}, ctx)
			ss.m21._consapevolezza(h4)
		"ss23_superstite":
			var h5: String = str(ctx.get("hex", "")) if str(o.hex) == "@hex" else str(o.hex)
			superstite(h5)
		"ss23_sherman":
			var r5: int = p.d10()
			sherman("B19" if r5 % 2 == 1 else "A8")
			_st().leggi_316 = not bool(p.s.avvistamenti[6])
		"ss23_sherman_bloccato":
			var vs: Dictionary = p.veicoli.v("vsh7")
			if p.veicoli.attivo(vs):
				vs.immobilizzato = true
				p._log("info", "Gli arbusti si impigliano nei cingoli: lo Sherman resta bloccato in %s (ma spara ancora)." % vs.hex)
		"ss23_modo":
			_st().modo = str(o.modo)
			p.missione.vittoria_pv = int(o.pv)
		"ss23_tracce":
			if _st().get("tracce_" + str(o.k), false):
				return true
			_st()["tracce_" + str(o.k)] = true
			p._log("info", str(o.testo))
		"ss23_togli_se_nessuno":
			var g: Dictionary = p.u(str(ctx.get("g", "")))
			if not g.is_empty() and p.americani_attivi_in_mappa().filter(func(a): return p.vede_unita(g, a)).is_empty():
				ss.m20._togli(g, 0, "")
				p._log("tedesco", "Il %s sparisce nella galleria." % p.nome(g))
		"ss23_rientra":
			var h6: String = str(ctx.get("hex", "")) if str(o.hex) == "@hex" else str(o.hex)
			var rientrati := 0
			for n in [39, 69]:
				var gg: Dictionary = p.u("g%d" % n)
				if not gg.is_empty() and str(gg.stato) == "rimosso":
					gg.stato = "attivo"
					gg.hex = h6
					gg.postura = "crouching"
					rientrati += 1
					p._log("attivazione", "Il %s rientra in mappa in %s." % [p.nome(gg), h6])
			if rientrati > 0:
				ss.m21.op_comune({"op": "ss_inizia_round"}, ctx)
				p._op({"op": "ss_vantaggio", "lato": str(o.adv)}, ctx)
		"ss_scelte_23":
			for k in ["328", "329"]:
				p.s.get("scelte", {}).erase(k)
		"ss_galleria":
			pass
		"ss_granata_difettosa_c":
			ss.m21._granata_difettosa()
		"ss22_torrente_scivola":
			if _st().get("s370", false):
				return true
			var l: Array = (p.americani() + p.tedeschi()).filter(func(x): return p.attivo(x) and p.in_mappa(x) and p.terreno.tipo(x.hex) == "stream")
			if l.is_empty():
				p._log("info", "Nessuno è nel torrente: nessun evento.")
				return true
			_st().s370 = true
			var y: Dictionary = l[p.rng.randi_range(0, l.size() - 1)]
			if not p.controllo_pc(y, 0, "scivola sui sassi del torrente") and int(y.munizioni.get("granata", 0)) > 0:
				y.munizioni.granata = int(y.munizioni.granata) - 1
				p._log("info", "%s perde una granata nel torrente." % p.nome(y))
		_:
			return ss.m21.op_comune(o, ctx)
	return true

func test(t: Dictionary, ctx: Dictionary):
	if not attiva():
		return null
	if t.has("ss23_fortificato"):
		for h in t.ss23_fortificato:
			if str(h) in _st().fortificati:
				return true
		return false
	if t.has("ss23_tolto"):
		for n in t.ss23_tolto:
			var g: Dictionary = p.u("g%d" % int(n))
			if not g.is_empty() and str(g.stato) == "rimosso":
				return true
		return false
	if t.has("ss23_inattivi"):
		for n in t.ss23_inattivi:
			var g2: Dictionary = p.u("g%d" % int(n))
			if g2.is_empty() or p.attivo(g2):
				return false
		return true
	if t.has("ss23_comandante"):
		return not p.americani_attivi_in_mappa().filter(func(a): return a.get("comandante", false)).is_empty()
	if t.has("ss23_piu"):
		# [colonna/riga, soglia, confronto]: più americani a sud della riga data che a ovest della colonna data.
		var sud := 0
		var ovest := 0
		for a in p.americani_attivi_in_mappa():
			if E.riga(a.hex) <= int(t.ss23_piu[0]):
				sud += 1
			if E.colonna(a.hex) <= E.colonna(str(t.ss23_piu[1]) + "1"):
				ovest += 1
		return sud > ovest
	if t.has("ss23_us_entro"):
		var h: String = str(ctx.get("hex", "")) if str(t.ss23_us_entro[0]) == "@hex" else str(t.ss23_us_entro[0])
		var n2 := 0
		for a in p.americani_attivi_in_mappa():
			if E.distanza(a.hex, h) <= int(t.ss23_us_entro[1]):
				n2 += 1
		return n2 >= int(t.ss23_us_entro[2])
	if t.has("ss23_us_vista"):
		var g3: Dictionary = p.u(str(ctx.get("g", "")))
		return not g3.is_empty() and not p.americani_attivi_in_mappa().filter(func(a): return p.vede_unita(g3, a)).is_empty()
	if t.has("in_rounds"):
		return p.fase_round() == bool(t.in_rounds)
	if t.has("g_hex"):
		var gh: Dictionary = p.u(str(ctx.get("g", "")))
		var hh: String = str(gh.get("hex", "")) if not gh.is_empty() else str(ctx.get("hex", ""))
		return hh == str(t.g_hex)
	if t.has("ss_dispari"):
		return (int(p.s.get("round", {}).get("numero_azione", p.d10())) % 2 == 1) == bool(t.ss_dispari)
	return null
