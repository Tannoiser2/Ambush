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
