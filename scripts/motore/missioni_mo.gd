extends RefCounted
## Regole e operazioni dei paragrafi delle missioni di Move Out! (9–12).

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

var p  # Partita

func _init(partita) -> void:
	p = partita

func attiva() -> bool:
	return str(p.missione.get("libro", "")) == "mo"

# ------------------------------------------------------------------ operazioni dei paragrafi
## Esegue un’operazione propria di Move Out!; false se l’operazione non è di qui.
func op(o: Dictionary, ctx: Dictionary) -> bool:
	match str(o.op):
		"lancio_tedeschi":
			_lancio_tedeschi(o, ctx)
		"sveglia":
			_sveglia(o)
		"atterraggio_fuori":
			_atterraggio_fuori(int(o.g), str(o.hex))
		"condizione_righe":
			var sud := false
			var nord := false
			for a in p.americani_attivi_in_mappa():
				if E.riga(a.hex) >= int(o.riga):
					sud = true
				if E.riga(a.hex) < int(o.riga):
					nord = true
			p.cambia_condizione(int(o.sud) if not sud else (int(o.nord) if not nord else int(o.altrimenti)))
		"ghiaccio":
			_ghiaccio(ctx)
		"neve":
			_neve()
		"inceppa_freddo":
			_inceppa_freddo()
		"mani_fredde":
			_mani_fredde()
		"bufera":
			_bufera()
		"assiderato":
			_assiderato()
		"riattiva":
			_riattiva(o, ctx)
		"colpo_casuale":
			_colpo_casuale()
		"caduta":
			_caduta()
		"sherman_mo":
			_sherman(str(o.hex))
		"claude":
			_claude(str(o.hex))
		"chiatta":
			_chiatta(str(o.hex))
		"chiatta_mappa_b":
			_chiatta_mappa_b(str(o.hex))
		"galleria":
			p.s.mo_galleria = true
		"botola":
			if not p.s.has("mo_botole"):
				p.s.mo_botole = []
			if not (str(o.hex) in p.s.mo_botole):
				p.s.mo_botole.append(str(o.hex))
		"prigionieri_trovati":
			_prigionieri_trovati(ctx)
		"faro":
			_faro(str(o.da), o.tab)
		"partigiano":
			_partigiano()
		"azione_tedesca":
			var ga: Dictionary = p.u(str(ctx.get("g", "")))
			if not ga.is_empty() and p.ia._g.get("id", "") == ga.id:
				p.ia._fermo = true
				p.ia.mo.esegui(int(o.n))
		"razzo":
			_razzo(o)
		"fuoco_nascosto":
			_fuoco_nascosto(o)
		"filo":
			if not p.s.has("filo"):
				p.s.filo = []
			for h in o.hex:
				if not (str(h) in p.s.filo):
					p.s.filo.append(str(h))
			p._log("info", "Filo spinato in %s." % ", ".join(o.hex))
		"crollo":
			_crollo(ctx)
		"fronte":
			_fronte(o)
		"squarcio":
			var vj: Dictionary = p.veicoli.v("v12")
			if not vj.is_empty():
				vj.squarcio = true
		"visibilita":
			p.s.vista = int(o.n)
			p._applica_regole_terreno()
			p._log("info", "Visibilità: %s." % ("piena" if int(o.n) == 0 else "%d esagoni" % int(o.n)))
		"panico_mo":
			_panico()
		"radio_inciampa":
			_radio_inciampa()
		"colonna":
			_colonna(str(o.hex))
		"due_dadi":
			var somma: int = p.d10() + p.d10()
			p._log("dado", "Due dadi: %d." % somma)
			if somma <= int(o.max):
				p.leggi(str(o.p), ctx)
			else:
				p._log("info", "Nessun evento.")
		"tutti_consapevoli":
			if p.s.has("round") and not p.s.round.is_empty():
				p.s.round.tutti_consapevoli = true
		_:
			return false
	return true

# ------------------------------------------------------------------ Missione 11: i paracadutisti
## 409: otto paracadutisti, uno a caso per esagono; poi derivano finché la carta non dice «Atterra».
func _lancio_tedeschi(o: Dictionary, ctx: Dictionary) -> void:
	var esagoni: Array = o.hex.duplicate()
	for i in range(esagoni.size() - 1, 0, -1):
		var j: int = p.rng.randi_range(0, i)
		var t = esagoni[i]
		esagoni[i] = esagoni[j]
		esagoni[j] = t
	var sentinelle: Array = p.americani_attivi_in_mappa()
	p.s.mo_allarme = "attesa"
	p.s.mo_sentinella = sentinelle[0].id if not sentinelle.is_empty() else ""
	var vivi: Array = []
	for i in o.g.size():
		var num := int(o.g[i])
		var h := str(esagoni[i % esagoni.size()])
		var g: Dictionary = p._crea_tedesco(num, h, "standing")
		if not (str(num) in p.s.attivati):
			p.s.attivati.append(str(num))
			var dati: Dictionary = p.missione.tedeschi[str(num)]
			if int(dati.pv) != 0:
				p._pv(int(dati.pv), "attivazione del tedesco %d" % num)
		p._log("attivazione", "Il %s compare tra le nuvole sopra %s." % [p.nome(g), h])
		p._fx("compare", {"id": g.id, "a": h, "paracadute": true})
		if _deriva(g):
			vivi.append(g)
	p.cambia_condizione(2)
	vivi = vivi.filter(func(x): return p.attivo(x))
	if vivi.is_empty() or p.s.fase == "fine":
		return
	if p.s.fase == "operazioni":
		p._inizia_round_da_attivazione(vivi, {"adv": null, "two": [], "us_two": false}, "")

## 423: deriva un esagono alla volta (0–6 nord-est, 7–8 nord, 9 sud-est). true se atterra in mappa.
func _deriva(g: Dictionary) -> bool:
	var h: String = g.hex
	var percorso: Array = [h]
	for i in 40:
		var r: int = p.d10()
		var verso := E.vicino(h, 1 if r <= 6 else (0 if r <= 8 else 2))
		if verso == "":
			p._log("info", "Il %s è portato dal vento fuori dalla mappa e si ritira." % p.nome(g))
			g.stato = "rimosso"
			g.hex = ""
			p._fx("sparisce", {"ids": [g.id], "da": h, "motivo": "uscito"})
			return false
		var da := h
		h = verso
		g.hex = h
		percorso.append(h)
		p._fx("muovi", {"ids": [g.id], "da": da, "a": h, "paracadute": true, "passo": i})
		if p.movimento_rosso(h) == "LAND":
			break
	p._log("azione", "%s scende col paracadute: %s." % [p.nome(g), " → ".join(percorso)])
	var esito := _atterraggio(g, _categoria(h), h)
	p._fx("atterra", {"id": g.id, "a": h})
	if esito == "" :
		g.postura = "prone"
		g.paracadute = 2
	return p.attivo(g)

func _categoria(h: String) -> String:
	if ghiacciato(h):
		return "ghiaccio"
	var t: String = p.terreno.tipo(h)
	if t in ["clear", "road"]:
		return "libero"
	if t == "woods":
		return "bosco"
	return "copertura"

func ghiacciato(h: String) -> bool:
	return str(p.terreno.esagoni.get(h, {}).get("t", "")) == "stream" and str(p.s.modifiche.get(h, "")) == "clear"

## 425: qualità dell’atterraggio. Restituisce "" se va bene o con una ferita, "fuori" se ucciso o incapacitato.
func _atterraggio(g: Dictionary, cat: String, h: String) -> String:
	var nomi := {"ghiaccio": "ruscello ghiacciato", "libero": "terreno libero", "copertura": "copertura", "bosco": "bosco"}
	var r: int = p.d10("Atterraggio di %s (%s)" % [p.nome(g), nomi[cat]])
	var danno := ""
	match cat:
		"ghiaccio":
			if r == 9:
				danno = "annega"
		"libero":
			if r == 9:
				danno = "ferito"
		"copertura":
			if r == 9:
				danno = "ferito" if p.d10("Secondo dado") <= 4 else "incapacitato"
		"bosco":
			if r >= 5:
				var r2: int = p.d10("Tra i rami")
				if r2 >= 9:
					danno = "ferito" if p.d10("Terzo dado") <= 4 else "incapacitato"
				elif r2 >= 6:
					danno = "ferito"
	match danno:
		"annega":
			if h != "":
				g.hex = h
				_rompi_ghiaccio(h)
			p._uccidi(g, "il ghiaccio cede e annega")
			return "fuori"
		"incapacitato":
			p._incapacita(g)
			return "fuori"
		"ferito":
			p._ferisci(g)
		_:
			p._log("info", "Il %s atterra bene." % p.nome(g))
	return ""

## 452–457 e 463: paracadutista atterrato fuori mappa che entra nell’esagono indicato.
func _atterraggio_fuori(num: int, h: String) -> void:
	var gid := "g%d" % num
	if not p.u(gid).is_empty():
		return
	var r: int = p.d10("Terreno dell’atterraggio fuori mappa")
	var cat := "libero" if r <= 3 else ("copertura" if r <= 6 else ("bosco" if r <= 8 else "ghiaccio"))
	var g: Dictionary = p._crea_tedesco(num, h, "standing")
	g.hex = ""
	var esito := _atterraggio(g, cat, "")
	if esito != "":
		g.hex = ""
		g.stato = "rimosso"
		p._log("info", "Il tedesco %d non entra in gioco." % num)
		return
	g.hex = h
	g.postura = "standing"
	if not (str(num) in p.s.attivati):
		p.s.attivati.append(str(num))
		var dati: Dictionary = p.missione.tedeschi[str(num)]
		if int(dati.pv) != 0:
			p._pv(int(dati.pv), "attivazione del tedesco %d" % num)
	p._log("attivazione", "Attivato il %s in %s, in piedi." % [p.nome(g), h])
	p._fx("compare", {"id": g.id, "a": h})
	if p.s.fase == "round":
		p._attivazione_durante_round(g, true)
	elif p.s.fase == "operazioni":
		p._inizia_round_da_attivazione([g], {"adv": null, "two": [num], "us_two": false}, "")

# ------------------------------------------------------------------ Missione 11: la squadra si sveglia
func _sveglia(o: Dictionary) -> void:
	if str(p.s.get("mo_allarme", "")) in ["dato", "mancato"]:
		return
	p.s.mo_allarme = "dato" if bool(o.consapevoli) else "mancato"
	for a in p.americani():
		if a.stato == "dorme":
			a.stato = "fuori"
			a.attesa = int(o.azioni)
			a.consapevole = false
	if bool(o.consapevoli):
		p.s.mo_consapevoli = true
	p._log("info", "La squadra si sveglia: ogni soldato entra in Y8 dopo %d azioni fuori mappa." % int(o.azioni))

## Controlli dopo ogni comando: allarme della sentinella, Condizione 3, attese fuori mappa.
func controlla() -> void:
	if not attiva() or p.s.fase == "fine":
		return
	if radio_portata() and p.s.fase != "schieramento":
		if not p.s.has("radio_porta"):
			p.s.radio_porta = "A"
			p._log("info", "La radio la porta %s." % p.nome(p.u("A")))
		var rp: Dictionary = p.u(str(p.s.radio_porta))
		p.s.radio_hex = rp.hex if radio_funziona() else ""
	controlla_m12()
	if sbarramento() and int(p.s.condizione) == 1 and p.s.fase != "schieramento" and not p.s.get("mo_c2", false):
		if p.tedeschi_attivi().filter(func(g): return p.in_mappa(g)).is_empty():
			_condizione_2_m10()
	if str(p.s.get("mo_allarme", "")) == "attesa":
		var sx: Dictionary = p.u(str(p.s.get("mo_sentinella", "")))
		if sx.is_empty() or not p.attivo(sx):
			p.leggi("414", {"hex": "", "ids": []})
		elif sx.hex == "T8":
			p.leggi("411", {"hex": "T8", "ids": [sx.id]})
	if str(p.s.get("mo_allarme", "")) in ["dato", "mancato"]:
		var fuori: Array = p.americani().filter(func(x): return x.stato in ["fuori", "dorme"])
		if p.s.fase == "operazioni":
			for a in fuori:
				a.attesa = 0
		if fuori.is_empty() and int(p.s.condizione) == 2 and not p.s.get("mo_c3", false):
			p.s.mo_c3 = true
			p._log("info", "L’ultimo soldato è entrato in mappa.")
			p.cambia_condizione(3)
	if p.s.fase == "operazioni":
		for a in p.americani():
			if str(a.get("bloccato", "")) != "":
				a.bloccato = ""

## Il soldato fuori mappa che deve ancora aspettare spende l’azione a prepararsi.
func prepara(a: Dictionary) -> bool:
	if a.stato != "fuori" or int(a.get("attesa", 0)) <= 0:
		return false
	a.attesa = int(a.attesa) - 1
	if int(a.attesa) > 0:
		p._log("azione", "%s si prepara fuori mappa (ancora %d azion%s prima di entrare)." % [p.nome(a), int(a.attesa), "e" if int(a.attesa) == 1 else "i"])
	else:
		p._log("azione", "%s è pronto: dalla prossima azione può entrare in Y8." % p.nome(a))
	return true

## Soldato caduto in acqua o nella neve: serve un’azione per uscirne.
func esci_bloccato(a: Dictionary) -> bool:
	var b := str(a.get("bloccato", ""))
	if b == "":
		return false
	a.bloccato = ""
	p._log("azione", "%s spende l’azione per uscire %s." % [p.nome(a), "dall’acqua" if b == "acqua" else "dal cumulo di neve"])
	return true

# ------------------------------------------------------------------ eventi d’inverno
func _rompi_ghiaccio(h: String) -> void:
	p.s.modifiche[h] = "ford"
	if not p.s.has("guadi"):
		p.s.guadi = []
	if not (h in p.s.guadi):
		p.s.guadi.append(h)
	p.terreno.imposta_modifiche(p.s.modifiche)
	p._applica_regole_terreno()
	p._log("danno", "Il ghiaccio cede in %s: ora è un guado." % h)

## 431: il ghiaccio scricchiola.
func _ghiaccio(ctx: Dictionary) -> void:
	var h: String = ctx.get("hex", "")
	if h == "":
		return
	var presenti: Array = p.unita_in(h, "us")
	if p.terreno.tipo(h) == "ford":
		for a in presenti:
			if not a.get("bagnato", false):
				a.bagnato = true
				p._log("info", "%s attraversa il guado e si bagna." % p.nome(a))
		return
	if not ghiacciato(h):
		return
	var r: int = p.d10("Il ghiaccio scricchiola") - presenti.size()
	if r > 0:
		p._log("info", "Il ghiaccio regge (%d)." % r)
		return
	_rompi_ghiaccio(h)
	for a in presenti:
		var da: String = str(a.get("hex_prec", ""))
		if p.controllo_pc(a, 0, "ghiaccio"):
			if da != "" and da != h:
				a.hex = da
				p._fx("muovi", {"ids": [a.id], "da": h, "a": da})
			a.postura = "prone"
			p._log("info", "%s si butta indietro prono in %s." % [p.nome(a), a.hex])
		else:
			a.bagnato = true
			a.bloccato = "acqua"
			a.postura = "standing"
			var perse: Array = a.armi.map(func(x): return T.ARMI.get(x.tipo, {}).get("nome", x.tipo))
			a.armi = []
			p._log("danno", "%s cade nel ruscello ghiacciato ed è bagnato%s." % [p.nome(a), "" if perse.is_empty() else ": perde " + ", ".join(perse)])
	if not p.s.turno.is_empty():
		p.s.turno.fermo = true
		p.s.turno.mp = 0

## 435: cumulo di neve (due dadi: 0, 9 o 18).
func _neve() -> void:
	var r: int = p.d10() + p.d10()
	p._log("dado", "Cumulo di neve: %d." % r)
	if not (r in [0, 9, 18]):
		p._log("info", "Nessun effetto.")
		return
	var lista: Array = p.americani_attivi_in_mappa().filter(func(a): return p.terreno.tipo(a.hex) in ["clear", "road", "brush", "rough"])
	if lista.is_empty():
		p._log("info", "Nessun soldato in terreno libero o di copertura.")
		return
	var a: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	a.postura = "prone"
	a.neve = true
	if int(a.munizioni.get("granata", 0)) > 0:
		a.munizioni.granata = int(a.munizioni.granata) - 1
	if p.s.fase == "round":
		a.bloccato = "neve"
		if not p.s.turno.is_empty() and p.s.turno.id == a.id:
			p.s.turno.fermo = true
			p.s.turno.mp = 0
	p._log("danno", "%s cade prono in un cumulo di neve e perde una granata." % p.nome(a))

## 441: arma inceppata per il freddo.
func _inceppa_freddo() -> void:
	var r: int = p.d10("Chi ha l’arma inceppata (pari tedesco, dispari americano)")
	var lista: Array = (p.tedeschi_attivi() if r % 2 == 0 else p.americani_attivi_in_mappa()).filter(func(x):
		return p.in_mappa(x) and not p.armi_da_fuoco(x).is_empty())
	if lista.is_empty():
		p._log("info", "Nessun effetto.")
		return
	var x: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	var arma: Dictionary = p.armi_da_fuoco(x)[0]
	arma.inceppata = true
	p._log("danno", "L’arma del %s si inceppa per il gelo." % p.nome(x))
	if x.postura != "prone":
		var ws := clampi(int(x.WS) - (1 if arma.get("catturata", false) else 0), -3, 2)
		var d: int = p.d10("Prova subito a sbloccarla")
		var l: String = T.DISINCEPPA[ws].substr(d, 1)
		if l == "C":
			arma.inceppata = false
			p._log("info", "La sblocca subito.")
		elif l == "B":
			arma.inceppata = false
			arma.rotta = true
			p._log("danno", "L’arma si rompe.")

## 444: un soldato prono si scalda le mani: un solo turno in questo Round.
func _mani_fredde() -> void:
	var r: int = p.d10("Chi si scalda le mani (pari americano, dispari tedesco)")
	var lista: Array = (p.americani_attivi_in_mappa() if r % 2 == 0 else p.tedeschi_attivi()).filter(func(x):
		return p.in_mappa(x) and x.postura == "prone")
	if lista.is_empty() or p.s.fase != "round":
		p._log("info", "Nessun effetto.")
		return
	var x: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	if int(x.get("turni", 0)) > 1:
		x.turni = 1
	x.mani_fredde = int(p.s.get("round_tot", 0))
	p._log("info", "%s si scalda le mani: un solo turno in questo Round." % p.nome(x))

## 447: bufera, visibilità di un esagono per questo Round (non due Round di fila).
func _bufera() -> void:
	var n := int(p.s.get("round_tot", 0))
	if p.s.fase != "round":
		p._log("info", "Fuori dai Round: nessun effetto.")
		return
	if int(p.s.get("mo_bufera", -9)) >= n - 1:
		p._log("info", "La bufera non può capitare in due Round di fila: nessun effetto.")
		return
	p.s.mo_bufera = n
	p.s.vista = 1
	p._applica_regole_terreno()
	p._log("info", "Bufera di neve: in questo Round si vede a un solo esagono.")

## Inizio di ogni Round: finisce la bufera del Round precedente.
func inizio_round() -> void:
	if not attiva():
		return
	if p.s.has("mo_bufera") and int(p.s.mo_bufera) != int(p.s.get("round_tot", 0)) and p.s.has("vista"):
		p.s.erase("vista")
		p._applica_regole_terreno()
		p._log("info", "La bufera si placa.")

## 449: un americano bagnato viene incapacitato dal freddo (una volta).
func _assiderato() -> void:
	if p.s.get("mo_assiderato", false):
		p._log("info", "È già capitato: nessun effetto.")
		return
	var lista: Array = p.americani().filter(func(a): return a.get("bagnato", false) and p.attivo(a))
	if lista.is_empty():
		p._log("info", "Nessun soldato bagnato: nessun effetto.")
		return
	p.s.mo_assiderato = true
	var a: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	p._log("danno", "%s, bagnato fradicio, è vinto dal gelo." % p.nome(a))
	p._incapacita(a)

# ================================================================== Missione 10: mortai e riattivazioni
func sbarramento() -> bool:
	return attiva() and bool(p.regola("sbarramento", false))

## Test dei paragrafi propri di Move Out!
func test(t: Dictionary, ctx: Dictionary) -> bool:
	var g: Dictionary = p.u(str(ctx.get("g", "")))
	if t.has("g_num_max"):
		return not g.is_empty() and int(g.num) <= int(t.g_num_max)
	if t.has("g_num_min"):
		return not g.is_empty() and int(g.num) >= int(t.g_num_min)
	if t.has("g_num"):
		return not g.is_empty() and int(g.num) == int(t.g_num)
	if t.has("flag"):
		return p.s.get("note", {}).has(str(t.flag))
	if t.has("in_galleria"):
		return in_galleria(ctx.get("ids", []))
	if t.has("claude_qui"):
		var h: String = str(ctx.get("hex", ""))
		var cl: Dictionary = p.u("J")
		return not cl.is_empty() and p.attivo(cl) and cl.hex == h \
			and p.unita_in(h, "us").filter(func(x): return x.id != "J").size() >= 1
	if t.has("any_s"):
		for n in t.any_s:
			if p.s.avvistamenti[int(n)]:
				return true
		return false
	if t.has("almeno_s"):
		var lista: Array = t.almeno_s
		var c := 0
		for n in lista.slice(1):
			if p.s.avvistamenti[int(n)]:
				c += 1
		return c >= int(lista[0])
	if t.has("in_round"):
		return p.fase_round()
	if t.has("spari"):
		var r: Dictionary = p.s.get("round", {})
		return not r.get("sparato", []).is_empty() or not r.get("sparato_prec", []).is_empty()
	return false

## Avvio della Missione 10: niente schieramento, i tedeschi sulla riga 19, i mortai al posto della squadra.
func inizia_sbarramento() -> void:
	p._inizio_comando()
	p.s.fase = "operazioni"
	for a in p.americani():
		if a.stato == "fuori":
			a.stato = "dorme"
	var d := {"id": "MOR", "nome": "Mortai", "IN": 3, "PC": 9, "WS": 0, "DS": 0, "MPA": 0, "comandante": false,
		"porte": [], "munizioni": {}}
	var m: Dictionary = p._nuovo_americano(d)
	m.stato = "attivo"
	m.hex = ""
	m.artiglieria = true
	m.consapevole = true
	m.lettera = "MOR"
	p.s.unita["MOR"] = m
	p.s.art_marcatori = ["", ""]
	p._log("info", "Condizione 1: la squadra osserva dalle retrovie e dirige i mortai (due colpi per turno).")
	var coppie: Array = []
	var nums: Array = []
	var iniziali: Dictionary = p.regola("tedeschi_iniziali", {})
	for k in iniziali:
		coppie.append([int(k), str(iniziali[k])])
		nums.append(int(k))
	p._op_attiva({"g": coppie, "stance": "standing", "adv": "de", "two": nums, "us_two": false, "aware": false, "reaction": null}, {})
	for vid in p.s.get("veicoli", {}):
		var v: Dictionary = p.s.veicoli[vid]
		v.chiuso = false
	p._fine_comando()

## I mortai non vanno in panico e non sono mai inconsapevoli.
func turni_artiglieria(a: Dictionary, es: Dictionary) -> Dictionary:
	if a.get("legato", false):
		return {"turni": 0, "panico": false, "rosso": false}
	if not a.get("artiglieria", false):
		return es
	return {"turni": maxi(1, int(es.get("turni", 1))), "panico": false, "rosso": false}

## Un colpo dei mortai (k = 0 o 1) verso l’esagono h.
func colpo(id: String, k: int, h: String) -> Dictionary:
	p._inizio_comando()
	var a: Dictionary = p.u(id)
	if a.is_empty() or not a.get("artiglieria", false):
		return p._errore("Solo i mortai sparano così.")
	var e: String = p.puo_agire(a)
	if e != "":
		return p._errore(e)
	if not E.valido(h):
		return p._errore("Esagono non valido.")
	var t: Dictionary = p._turno_di(a)
	if not t.has("colpi"):
		t.colpi = []
	if k in t.colpi:
		return p._errore("Il colpo %d ha già sparato in questo turno." % (k + 1))
	t.colpi.append(k)
	var prima: String = p.s.art_marcatori[k]
	var arrivo := h
	if prima == h:
		p._log("azione", "Mortai, colpo %d: si mantiene il tiro su %s." % [k + 1, h])
	elif prima != "" and E.distanza(prima, h) <= 2:
		var r: int = p.d10("Colpo %d spostato su %s (dispersione)" % [k + 1, h])
		if r >= 4:
			arrivo = E.vicino(h, [0, 1, 2, 3, 4, 5][r - 4])
		p._log("azione", "Mortai, colpo %d spostato da %s verso %s: cade in %s." % [k + 1, prima, h, arrivo if arrivo != "" else "fuori mappa"])
	else:
		var r100: int = p.d10() * 10 + p.d10()
		p._log("dado", "Colpo di aggiustamento %d su %s: %02d." % [k + 1, h, r100])
		arrivo = dispersione(h, r100)
		p._log("azione", "Mortai, colpo %d: cade in %s." % [k + 1, arrivo if arrivo != "" else "fuori mappa"])
	p.s.art_marcatori[k] = arrivo
	if arrivo != "":
		p._fx("esplosione", {"a": arrivo})
		impatto(arrivo)
	if t.colpi.size() >= 2:
		p._termina_azione(a)
	p._fine_comando()
	return {"ok": true}

## Diagramma del colpo di aggiustamento (percentuale).
static func dispersione(h: String, r: int) -> String:
	if r <= 9:
		return h
	if r <= 39:
		return E.vicino(h, int((r - 10) / 5))
	var anello: Array = [[0, 5], [0, 0], [0, 1], [1, 1], [1, 2], [2, 2], [2, 3], [3, 3], [3, 4], [4, 4], [4, 5], [5, 5]]
	var passi: Array = anello[int((r - 40) / 5)]
	var x := h
	for d in passi:
		if x == "":
			return ""
		x = E.vicino(x, int(d))
	return x

## Danni dell’impatto: granata dentro (terreno aperto) o fuori (cespugli, bosco, edifici); i carri tirano un dado.
func impatto(h: String) -> void:
	var t: String = p.terreno.tipo(h)
	var tabella: String = T.GRANATA_FUORI if (t in ["brush", "woods"] or p.terreno.edificio(h)) else T.GRANATA_DENTRO
	for v in p.veicoli.in_esagono(h):
		if p.veicoli.attivo(v):
			_impatto_carro(v)
	for x in p.unita_in(h, "de") + p.unita_in(h, "us"):
		if p.attivo(x) and x.get("veicolo", "") == "":
			p._danno_esplosione(x, tabella)

func _impatto_carro(v: Dictionary) -> void:
	var r: int = p.d10("Mortaio sul %s" % v.nome)
	var aperto: bool = not v.get("chiuso", false)
	if r == 0:
		var r2: int = p.d10("Colpo diretto!")
		if r2 % 2 == 1:
			p.veicoli.disabilita(v, "colpo diretto di mortaio")
			return
		if v.has("mitragliatrici") and v.mitragliatrici.has("scafo"):
			v.mitragliatrici.scafo.rotta = true
		else:
			v.mg_scafo_rotta = true
		p._log("danno", "La mitragliatrice di scafo del %s è distrutta." % v.nome)
		if aperto:
			p.veicoli.riduci_equipaggio(v, 1)
	elif r <= 8:
		if aperto:
			p.veicoli.riduci_equipaggio(v, 1)
		else:
			p._log("info", "Il %s è chiuso: nessun effetto." % v.nome)
	else:
		if aperto:
			p.veicoli.riduci_equipaggio(v, 2)
		else:
			p._log("info", "Il %s è chiuso: nessun effetto." % v.nome)

## Vero se un colpo dei mortai è nell’esagono h o accanto.
func artiglieria_vicina(h: String) -> bool:
	for m in p.s.get("art_marcatori", []):
		if str(m) != "" and h != "" and E.distanza(str(m), h) <= 1:
			return true
	return false

## Fine della Condizione 1: si passa alla mappa B, i mortai tacciono, la squadra entra dal bordo nord.
func _condizione_2_m10() -> void:
	p.s.mo_c2 = true
	var mor: Dictionary = p.u("MOR")
	if not mor.is_empty():
		mor.stato = "rimosso"
		mor.turni = 0
		mor.slot = ""
	p.s.art_marcatori = ["", ""]
	for g in p.tedeschi():
		if g.stato == "attivo" and g.hex != "":
			g.stato = "uscito"
			g.hex = ""
	for vid in p.s.get("veicoli", {}):
		var v: Dictionary = p.s.veicoli[vid]
		if v.stato == "attivo":
			v.stato = "uscito"
		v.hex = ""
	p.cambia_mappa(str(p.regola("mappa_2", "B")))
	for a in p.americani():
		if a.stato == "dorme":
			a.stato = "fuori"
	p._log("info", "La Condizione 1 è finita: la squadra avanza in città (mappa B) ed entra dal bordo nord, da Y1 a Y19.")
	if p.s.fase == "round":
		p._torna_operazioni()
	p.cambia_condizione(2)

func blocca_fine() -> bool:
	return sbarramento() and int(p.s.condizione) == 1

func salta_evento() -> bool:
	return sbarramento() and int(p.s.condizione) == 1

## 875–888: riattiva i tedeschi usciti dalla mappa A (chi è fuori combattimento resta fuori).
func _riattiva(o: Dictionary, ctx: Dictionary) -> void:
	var coppie: Array = []
	var nums: Array = []
	for c in o.g:
		var num := int(c[0])
		var g: Dictionary = p.u("g%d" % num)
		if not g.is_empty() and not (g.stato in ["uscito", "rimosso"]):
			continue
		if not g.is_empty():
			g.stato = "rimosso"
		var vid := "v%d" % num
		if p.s.get("veicoli", {}).has(vid):
			var v: Dictionary = p.s.veicoli[vid]
			if v.stato == "distrutto":
				continue
			p.s.veicoli.erase(vid)
		coppie.append([num, str(c[1])])
		nums.append(num)
	if coppie.is_empty():
		p._log("info", "Nessuno di questi tedeschi può rientrare.")
		p.leggi(str(o.altrimenti), ctx)
		return
	var no_r = p.s.get("no_rientro", false)
	p.s.no_rientro = false
	p._op_attiva({"g": coppie, "stance": "standing", "adv": "de", "two": nums, "us_two": false, "aware": false, "reaction": null}, ctx)
	p.s.no_rientro = no_r
	for vid in p.s.get("veicoli", {}):
		p.s.veicoli[vid].chiuso = true

## 873: colpo d’artiglieria a caso nella parte est della mappa.
func _colpo_casuale() -> void:
	var col: int = p.d10("Colonna del colpo") + 15
	var riga: int = p.d10() + p.d10()
	p._log("dado", "Riga del colpo: %d." % riga)
	if riga < 1:
		p._log("info", "Il colpo cade fuori mappa.")
		return
	var h: String = E.da(col, riga)
	p._fx("esplosione", {"a": h, "grande": true})
	p._log("danno", "Un colpo d’artiglieria pesante cade in %s." % h)
	if not p.terreno.edificio(h):
		p.s.modifiche[h] = "crater"
		p.terreno.imposta_modifiche(p.s.modifiche)
	for v in p.veicoli.in_esagono(h):
		p.veicoli.disabilita(v, "colpo d’artiglieria")
	for x in p.unita_in(h, "de") + p.unita_in(h, "us"):
		if p.attivo(x):
			p._uccidi(x, "colpito dall’artiglieria")

## 645: caduta in terreno accidentato.
func _caduta() -> void:
	if p.s.get("mo_caduta", false):
		p._log("info", "È già capitato: nessun effetto.")
		return
	var lista: Array = p.americani_attivi_in_mappa().filter(func(a): return p.terreno.tipo(a.hex) == "rough")
	if lista.is_empty():
		p._log("info", "Nessun soldato in terreno accidentato: nessun effetto.")
		return
	p.s.mo_caduta = true
	var a: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	if p.controllo_pc(a, 0, "caduta"):
		p._log("info", "%s inciampa ma non si fa male." % p.nome(a))
	else:
		var r: int = p.d10("Caduta di %s" % p.nome(a))
		var l: String = T.lettera_danno(T.ARMI.pistol.danni, r)
		p._applica_danno(a, l, {})

## PV della Missione 10 per i tedeschi usciti dal bordo nord della mappa B.
func tedesco_uscito(x: Dictionary, h: String) -> void:
	if not sbarramento() or int(p.s.condizione) < 2 or h == "":
		return
	var d: Dictionary = p.missione.tedeschi.get(str(int(x.get("num", 0))), {})
	var valore := int(d.get("pv_valore", 0))
	if valore > 0:
		p._pv(-valore, "%s esce dal bordo nord" % p.nome(x))

## Righe del conto finale proprie di Move Out!; restituisce i PV da aggiungere.
func righe_fine(righe: Array) -> int:
	if not sbarramento():
		return righe_fine_m12(righe) if attiva() else 0
	var tot := 0
	for g in p.tedeschi():
		if not p.attivo(g) or g.hex == "":
			continue
		var vid: String = str(g.get("veicolo", ""))
		if vid != "":
			var v: Dictionary = p.veicoli.v(vid)
			if not v.is_empty() and (v.get("immobilizzato", false) or v.stato != "attivo"):
				continue
			if p.veicoli.autista(v).get("id", "") != g.id:
				continue
		var d: Dictionary = p.missione.tedeschi.get(str(int(g.num)), {})
		var valore := int(d.get("pv_valore", 0))
		if valore > 0:
			tot -= valore
			righe.append(["%s ancora in mappa" % p.nome(g), -valore])
	return tot

## 893: lo Sherman americano (comandato dal giocatore, come nella Missione 8).
func _sherman(h: String) -> void:
	if not p.u("Z").is_empty():
		return
	p.s.sherman_pronto = 0
	var ingresso_vecchio = p.s.get("sherman_hex", "")
	p.s.sherman_hex = h
	p.entra_sherman()
	p.s.sherman_hex = ingresso_vecchio

# ================================================================== Missione 12: prigionieri, Claude, chiatta, galleria
## Inizio della partita: A è libero, B e tre altri a caso sono prigionieri (senza armi).
func dopo_nuova() -> void:
	if not attiva() or not bool(p.regola("prigionieri_mo", false)):
		return
	var altri: Array = p.americani().filter(func(a): return not (a.id in ["A", "B"]))
	for i in range(altri.size() - 1, 0, -1):
		var j: int = p.rng.randi_range(0, i)
		var t = altri[i]
		altri[i] = altri[j]
		altri[j] = t
	var presi: Array = [p.u("B")] + altri.slice(0, 3)
	for a in presi:
		a.stato = "dorme"
		a.prigioniero_mo = true
		a.armi = []
		a.munizioni = {"granata": 0}
	p._log("info", "Prigionieri dei tedeschi: %s. Gli altri partono a cercarli." % ", ".join(presi.map(func(a): return p.nome(a))))

func in_galleria(ids: Array) -> bool:
	if ids.is_empty():
		return false
	for id in ids:
		if not p.u(str(id)).get("galleria", false):
			return false
	return true

func paragrafi_galleria() -> Array:
	return p.regola("paragrafi_t", []) if attiva() else []

## Esagoni della galleria: quelli scritti nella mappa (editor, modo «Piani e gallerie»);
## se la mappa non ne ha, da G13 (sotto il ponte) lungo la linea H12–R7.
func esagoni_galleria() -> Array:
	var dati: Array = p.terreno.esagoni_galleria(12)
	if not dati.is_empty():
		return dati
	var out: Array = ["G13"]
	for h in E.linea("H12", "R7"):
		if not (h in out):
			out.append(h)
	return out

## Ingresso principale della galleria (G13, sotto il ponte): il primo ingresso scritto nella mappa.
func ingresso_galleria() -> String:
	var ing: Array = p.terreno.galleria(12).get("ingressi", [])
	return str(ing[0]) if not ing.is_empty() else str(esagoni_galleria()[0])

func verifica_passo(a: Dictionary, verso: String) -> String:
	if not attiva():
		return ""
	if a.get("galleria", false) and not (verso in esagoni_galleria()):
		var gl := esagoni_galleria()
		return "Nella galleria si va solo lungo il tunnel (%s–%s)." % [gl[0], gl[-1]]
	return ""

func puo_entrare_galleria(a: Dictionary) -> bool:
	return attiva() and p.s.get("mo_galleria", false) and p.attivo(a) and a.hex == ingresso_galleria() and not a.get("galleria", false) \
		and not p.veicoli.attivo(p.veicoli.di(a))

func puo_uscire_galleria(a: Dictionary) -> bool:
	return a.get("galleria", false) and (a.hex == ingresso_galleria() or a.hex in p.s.get("mo_botole", []))

## Entra o esce dalla galleria (un punto movimento: nelle Operazioni è libero, nei Round costa l’azione).
func galleria(id: String, entra: bool) -> Dictionary:
	p._inizio_comando()
	var a: Dictionary = p.u(id)
	var e: String = p.puo_agire(a)
	if e != "":
		return p._errore(e)
	if entra and not puo_entrare_galleria(a):
		return p._errore("Nella galleria si entra solo da sotto il ponte in %s, dopo il paragrafo 487." % ingresso_galleria())
	if not entra and not puo_uscire_galleria(a):
		return p._errore("Si esce solo da %s o da una botola scoperta." % ingresso_galleria())
	a.galleria = entra
	a.postura = "crouching"
	p._log("azione", "%s %s in %s." % [p.nome(a), "entra nella galleria" if entra else "sale dalla galleria", a.hex])
	if not entra and a.hex == "R7" and not p.s.avvistamenti[7]:
		p.leggi("687", {"hex": "R7", "ids": [a.id]})
	if p.fase_round():
		p._termina_azione(a)
	p._fine_comando()
	return {"ok": true}

## Slega un compagno prigioniero nello stesso esagono (un’azione nei Round).
func slega(id: String, pid: String) -> Dictionary:
	p._inizio_comando()
	var a: Dictionary = p.u(id)
	var x: Dictionary = p.u(pid)
	var e: String = p.puo_agire(a)
	if e != "":
		return p._errore(e)
	if x.is_empty() or not x.get("legato", false) or x.hex != a.hex:
		return p._errore("Qui non c’è nessuno da slegare.")
	x.legato = false
	x.consapevole = true
	p._log("azione", "%s slega %s." % [p.nome(a), p.nome(x)])
	if p.fase_round():
		x.turni = 1
		x.slot = "turni"
		p._termina_azione(a)
	p._fine_comando()
	return {"ok": true}

func legati_qui(a: Dictionary) -> Array:
	return p.americani().filter(func(x): return x.get("legato", false) and x.hex == a.hex and x.hex != "")

## Coltelli di Claude: quello lanciato non si recupera.
func dopo_tiro(a: Dictionary, arma: Dictionary, b: Dictionary) -> void:
	if str(arma.get("tipo", "")) != "knife" or b.is_empty() or E.distanza(a.hex, str(b.get("hex", a.hex))) == 0:
		return
	a.munizioni.knife = maxi(0, int(a.munizioni.get("knife", 0)) - 1)
	if int(a.munizioni.knife) <= 0:
		a.armi = a.armi.filter(func(w): return w.tipo != "knife")
		p._log("info", "%s ha lanciato l’ultimo coltello." % p.nome(a))

func _claude(h: String) -> void:
	if not p.u("J").is_empty():
		return
	var d := {"id": "J", "nome": "Claude", "IN": 3, "PC": 8, "WS": 1, "DS": 0, "MPA": 4, "comandante": false,
		"porte": ["pistol", "knife"], "munizioni": {"pistol": 5, "knife": 2, "granata": 0}}
	var c: Dictionary = p._nuovo_americano(d)
	c.stato = "attivo"
	c.hex = h
	c.postura = "crouching"
	c.consapevole = true
	c.claude = true
	p.s.unita["J"] = c
	p.s.mo_claude = true
	p._log("info", "Claude, partigiano francese, si unisce alla squadra in %s (pistola e due coltelli da lancio)." % h)
	p._fx("compare", {"id": "J", "a": h, "amico": true})

func _chiatta(h: String) -> void:
	if p.veicoli.v("chiatta").is_empty():
		var v: Dictionary = p.veicoli.crea("chiatta", "chiatta", h, "us")
		v.chiuso = false
		p._log("info", "La chiatta di Claude è in %s: salite a bordo (almeno due ai remi) e scendete il fiume fino a O19." % h)

## La chiatta esce da O19: Condizione 2 sulla mappa B, la chiatta entra in A6 con chi è a bordo.
func _chiatta_mappa_b(h: String) -> void:
	var v: Dictionary = p.veicoli.v("chiatta")
	var a_bordo: Array = p.veicoli.occupanti(v) if not v.is_empty() else []
	for a in p.americani():
		if a.get("prigioniero_mo", false) and a.stato == "dorme":
			continue
		if a.stato == "incapacitato":
			a.salvo_mo = true  # gli incapacitati della Condizione 1 non costano PV
		if p.attivo(a) and a.hex != "" and not (a in a_bordo):
			p._log("info", "%s resta sulla mappa A e torna alle linee." % p.nome(a))
			a.stato = "rimosso"
			a.hex = ""
	p.cambia_mappa("B")
	if not v.is_empty():
		v.hex = h
		for a in a_bordo:
			a.hex = h
	p._log("info", "La chiatta scivola fuori dalla mappa A ed entra nel villaggio (mappa B) in %s." % h)

func _prigionieri_trovati(ctx: Dictionary) -> void:
	var h: String = str(ctx.get("hex", "Q8"))
	if h == "":
		h = "Q8"
	var trovati: Array = p.americani().filter(func(a): return a.get("prigioniero_mo", false) and a.stato == "dorme")
	for a in trovati:
		a.stato = "attivo"
		a.hex = h
		a.postura = "prone"
		a.ferito = true
		a.legato = p.fase_round()
		a.consapevole = not p.fase_round()
		a.turni = 0
		a.slot = "completo" if p.fase_round() else ""
		p._fx("compare", {"id": a.id, "a": h, "amico": true})
	p._log("info", "Prigionieri liberati in %s: %s." % [h, ", ".join(trovati.map(func(a): return p.nome(a)))] if not trovati.is_empty()
		else "Qui non c’è più nessuno.")

## 944–948: il faro dal primo piano di S13.
func _faro(da: String, tab: Array) -> void:
	var r: int = p.d10("Direzione del faro")
	var meta := str(tab[r])
	var luce: Array = []
	for h in E.linea(da, meta):
		if h == da or p.terreno.vede(da, h, "standing", "standing", 1, 0):
			luce.append(h)
	p._log("info", "Il faro punta verso %s: illuminati %s." % [meta, ", ".join(luce)])
	var visti: Array = p.americani_attivi_in_mappa().filter(func(a): return a.hex in luce and not a.get("galleria", false))
	if visti.is_empty():
		p._log("info", "Nessun americano nella luce.")
		return
	var c := int(p.s.condizione)
	if c == 2:
		p.cambia_condizione(3)
	elif c == 4:
		p.cambia_condizione(5)
	visti.sort_custom(func(x, y): return E.distanza(da, x.hex) < E.distanza(da, y.hex))
	var b: Dictionary = visti[0]
	var base: int = T.base_per_distanza("lmg", E.distanza(da, b.hex))
	if base < 0:
		p._log("info", "La mitragliatrice non arriva fin là.")
		return
	p._log("info", "La mitragliatrice del campanile spara su %s." % p.nome(b))
	p.risolvi_tiro({"lato": "cecchino", "WS": 0}, {"tipo": "lmg", "inceppata": false}, b, false, maxi(0, base - 2))

## 947: un partigiano nascosto spara a un tedesco in terreno aperto.
func _partigiano() -> void:
	var lista: Array = p.tedeschi_attivi().filter(func(g): return p.terreno.tipo(g.hex) in ["clear", "road"])
	if lista.is_empty():
		p._log("info", "Nessun tedesco allo scoperto: nessun effetto.")
		return
	var g: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	p._log("info", "Un partigiano nascosto spara sul %s." % p.nome(g))
	p.risolvi_tiro({"lato": "cecchino", "WS": -2}, {"tipo": "pistol", "inceppata": false}, g, false, 0)

## Controlli della Missione 12 dopo ogni comando.
func controlla_m12() -> void:
	if not attiva() or not bool(p.regola("prigionieri_mo", false)):
		return
	if p.s.get("mo_claude", false) and p.veicoli.v("chiatta").is_empty() and p.lettera_mappa() == "A":
		for a in p.americani_attivi_in_mappa():
			if a.hex == "M12":
				p.leggi("442", {"hex": "M12", "ids": [a.id]})
				break
	var v: Dictionary = p.veicoli.v("chiatta")
	if not v.is_empty() and p.lettera_mappa() == "A" and v.hex == "O19" and p.veicoli.attivo(v):
		p.leggi("465", {"hex": "O19", "ids": []})

func righe_fine_m12(righe: Array) -> int:
	if not bool(p.regola("prigionieri_mo", false)):
		return 0
	var n := 0
	for a in p.americani():
		if a.get("prigioniero_mo", false) and a.stato == "uscito":
			n += 1
	if n > 0:
		righe.append(["%d compagni liberati e portati fuori" % n, 5 * n])
	return 5 * n

# ================================================================== Missione 9: notte sulla Linea Sigfrido
## 400/408/413/419: razzo illuminante.
func _razzo(o: Dictionary) -> void:
	var r: int = p.d10("Dove cade il razzo")
	var h := str(o.tab[r])
	var luce: Array = [h] + E.vicini(h)
	p._fx("esplosione", {"a": h, "razzo": true})
	var visti: Array = p.americani_attivi_in_mappa().filter(func(a): return a.hex in luce)
	p._log("info", "Il razzo illumina %s e gli esagoni intorno." % h)
	if visti.is_empty():
		p._log("info", "Nessun soldato illuminato: nessun evento.")
		return
	for a in visti:
		if p.controllo_pc(a, 0, "razzo"):
			a.postura = "prone"
			p._log("info", "%s si butta a terra." % p.nome(a))
		else:
			p._log("info", "%s resta immobile nella luce." % p.nome(a))
	p.s.mo_illuminati = visti.map(func(a): return a.id)
	p.leggi(str(o.poi), {"hex": h, "ids": []})

## 405/410/417/418: un tedesco nascosto spara a un soldato illuminato (senza Round).
func _fuoco_nascosto(o: Dictionary) -> void:
	var ids: Array = p.s.get("mo_illuminati", [])
	var lista: Array = ids.map(func(id): return p.u(str(id))).filter(func(a): return not a.is_empty() and p.attivo(a))
	if lista.is_empty():
		return
	var b: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	var mirato: bool = p.d10("Tiro rapido o mirato") > int(o.soglia)
	var base: int = {"corta": 5, "media": 4, "lunga": 3}.get(str(o.gittata), 4)
	var prob: int = base + int(o.ws) - (0 if mirato else 2)
	p._log("info", "Un tedesco nascosto spara %s a %s." % ["mirando" if mirato else "di rapido", p.nome(b)])
	p.risolvi_tiro({"lato": "cecchino", "WS": int(o.ws)}, {"tipo": str(o.arma), "inceppata": false}, b, mirato, maxi(0, prob))
	p.s.erase("mo_illuminati")

## Filo spinato (497, 600, 604).
func filo(h: String) -> bool:
	return h in p.s.get("filo", [])

func costo_extra(a: Dictionary, verso: String) -> int:
	return 1 if attiva() and p.fase_round() and filo(verso) and not p.veicoli.attivo(p.veicoli.di(a)) else 0

## Chi esce da un esagono col filo spinato nei Round rischia di restare impigliato: true se resta fermo.
func impigliato(ids: Array) -> bool:
	if not attiva() or not p.fase_round():
		return false
	var fermo := false
	for id in ids:
		var a: Dictionary = p.u(str(id))
		if a.is_empty() or not filo(a.hex) or p.veicoli.attivo(p.veicoli.di(a)):
			continue
		if p.d10("%s esce dal filo spinato" % p.nome(a)) == 0:
			p._log("danno", "%s resta impigliato nel filo spinato." % p.nome(a))
			p._ferisci(a)
			a.postura = "prone"
			fermo = true
	return fermo

func dopo_ingresso(ids: Array, h: String) -> void:
	if not attiva() or not p.fase_round() or not filo(h):
		return
	for id in ids:
		var a: Dictionary = p.u(str(id))
		if not a.is_empty() and a.postura != "prone" and not p.veicoli.attivo(p.veicoli.di(a)):
			a.postura = "prone"
			p._log("info", "%s si butta sotto il filo spinato." % p.nome(a))

func esplosione(tipo: String, h: String) -> void:
	if tipo == "satchel" and filo(h):
		p.s.filo.erase(h)
		p._log("info", "La carica apre un varco nel filo spinato in %s." % h)

## 601: crollo della casa pericolante (una volta).
func _crollo(ctx: Dictionary) -> void:
	if p.s.get("mo_crollo", false):
		return
	var h: String = str(ctx.get("hex", ""))
	if h == "" or not p.terreno.edificio(h):
		return
	p.s.mo_crollo = true
	var casa: Array = [h]
	var i := 0
	while i < casa.size():
		for v in E.vicini(casa[i]):
			if not (v in casa) and p.terreno.edificio(v) and p.terreno.tipo_lato(casa[i], v) == "":
				casa.append(v)
		i += 1
	for x in p.americani_attivi_in_mappa().filter(func(a): return a.hex in casa):
		if p.controllo_pc(x, 0, "crollo") and str(x.get("hex_prec", "")) != "" and not (str(x.hex_prec) in casa):
			x.hex = str(x.hex_prec)
			p._log("info", "%s esce di corsa in %s." % [p.nome(x), x.hex])
		else:
			p._applica_danno(x, T.lettera_danno(T.ARMI.pistol.danni, p.d10("Crollo su %s" % p.nome(x))), {})
			x.postura = "prone"
	for c in casa:
		p.s.modifiche[c] = "rubble"
	p.terreno.imposta_modifiche(p.s.modifiche)
	p._fx("esplosione", {"a": h, "grande": true})
	p._log("danno", "Il tetto crolla: %s diventano macerie." % ", ".join(casa))

## Radio portata a mano (Move Out!, regola 5).
func radio_portata() -> bool:
	return attiva() and bool(p.regola("radio_portata", false))

func radio_funziona() -> bool:
	if p.s.get("radio_rotta", false):
		return false
	var a: Dictionary = p.u(str(p.s.get("radio_porta", "")))
	return not a.is_empty() and p.attivo(a) and p.in_mappa(a)

func colpito(x: Dictionary) -> void:
	if not radio_portata() or str(x.get("id", "")) != str(p.s.get("radio_porta", "")) or p.s.get("radio_rotta", false):
		return
	var r: int = p.d10() * 10 + p.d10()
	if r <= 25:
		p.s.radio_rotta = true
		p._log("danno", "La radio di %s è distrutta (%02d)." % [p.nome(x), r])

func _radio_inciampa() -> void:
	if p.s.get("mo_radio_inciampa", false):
		return
	p.s.mo_radio_inciampa = true
	var a: Dictionary = p.u(str(p.s.get("radio_porta", "")))
	if a.is_empty() or not p.in_mappa(a) or not (p.terreno.tipo(a.hex) in ["woods", "brush", "rubble"]):
		p._log("info", "Nessun effetto.")
		return
	a.postura = "prone"
	if p.d10("%s inciampa con la radio" % p.nome(a)) == 0:
		p.s.radio_rotta = true
		p._log("danno", "La radio è distrutta.")
	else:
		p._applica_danno(a, T.lettera_danno(T.ARMI.pistol.danni, p.d10("Danni della caduta")), {})

func _panico() -> void:
	if p.s.get("mo_panico", false):
		return
	var lista: Array = p.americani_attivi_in_mappa().filter(func(a): return int(a.IN) <= 3 and not a.get("carro_us", false))
	if lista.is_empty() or not p.fase_round():
		p._log("info", "Nessun effetto.")
		return
	p.s.mo_panico = true
	var a: Dictionary = lista[p.rng.randi_range(0, lista.size() - 1)]
	a.postura = "prone"
	a.panico = true
	a.turni = 0
	a.slot = "panico"
	p._log("danno", "%s va nel panico e si butta a terra." % p.nome(a))

## 887/889: la colonna americana (Sherman Z e jeep con J e K) entra in gioco; la comandi tu.
func _colonna(h: String) -> void:
	if p.s.get("mo_colonna", false):
		return
	p.s.mo_colonna = true
	if p.s.has("scelte"):
		p.s.scelte.erase("887")
	_sherman(h)
	var z: Dictionary = p.u("Z")
	if not z.is_empty():
		z.colonna = true
	var j: Dictionary = p._nuovo_americano({"id": "J", "nome": "Autista", "IN": 3, "PC": 4, "WS": 0, "DS": 8, "MPA": 4,
		"comandante": false, "porte": ["pistol"], "munizioni": {"pistol": 5, "granata": 0}})
	var k: Dictionary = p._nuovo_americano({"id": "K", "nome": "Mitragliere", "IN": 4, "PC": 6, "WS": 1, "DS": 4, "MPA": 4,
		"comandante": false, "porte": ["carbine"], "munizioni": {"carbine": 5, "granata": 0}})
	var v: Dictionary = p.veicoli.crea("vcolonna", "jeep", h, "us")
	v.mg = {"tipo": "mmg", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false, "montata": true}
	v.mg_munizioni = 10
	for x in [j, k]:
		x.stato = "attivo"
		x.hex = h
		x.postura = "crouching"
		x.consapevole = true
		x.colonna = true
		p.s.unita[x.id] = x
		p.s.imbarco = true
		p.veicoli.sali(x, v)
		p.s.imbarco = false
	p._log("info", "La jeep della colonna entra in %s con l’autista J e il mitragliere K." % h)

## Uscita: ogni mezzo della colonna che esce da Y8 vale 5 PV.
func uscita(a: Dictionary, h: String) -> void:
	if not attiva() or not a.get("colonna", false):
		return
	var v: Dictionary = p.veicoli.di(a)
	var mezzo: String = "vsherman" if a.get("carro_us", false) else str(v.get("id", ""))
	if mezzo == "" or p.s.get("mo_usciti", []).has(mezzo):
		return
	if not p.s.has("mo_usciti"):
		p.s.mo_usciti = []
	p.s.mo_usciti.append(mezzo)
	var veic: Dictionary = p.veicoli.v(mezzo)
	if not veic.is_empty():
		for x in p.veicoli.occupanti(veic):
			if x.id != a.id and p.attivo(x):
				x.stato = "uscito"
				x.hex = ""
		veic.stato = "uscito"
		veic.hex = ""
	if h == "Y8" and int(p.regola("pv_uscita_mezzi", 0)) > 0:
		p._pv(int(p.regola("pv_uscita_mezzi", 0)), "%s esce da Y8" % ("lo Sherman" if mezzo == "vsherman" else "la jeep della colonna"))

func turni_tedesco(g: Dictionary, es: Dictionary) -> Dictionary:
	if attiva() and bool(p.missione.tedeschi.get(str(int(g.num)), {}).get("un_turno", false)) and int(es.get("turni", 0)) > 1:
		es.turni = 1
	return es

func _fronte(o: Dictionary) -> void:
	var v: Dictionary = p.veicoli.v("v%d" % int(o.g))
	if v.is_empty():
		return
	var d: int = E.direzione(v.hex, str(o.verso))
	if d >= 0:
		v.fronte = d
	v.immobile = true
