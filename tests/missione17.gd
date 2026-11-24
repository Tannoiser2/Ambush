extends SceneTree
## Missione 17 (Purple Heart): ponti con il timer, treno e deragliamento, motocicletta, auto comando e borsa sigillata, fine.
const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")
var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	var p = PartitaScript.new(17)
	p.nuova(17, true)
	ok(p.lettera_mappa() == "BE" and p.ph.attiva(), "mappe B + E, libro Purple Heart")
	ok(p.s.modifiche.get("L5", "") == "rubble" and p.s.modifiche.get("S9", "") == "rubble", "edifici a ovest del fiume in macerie")
	var cariche := 0
	for a in p.americani():
		cariche += a.armi.filter(func(w): return w.tipo == "satchel").size()
	ok(cariche >= 5, "cariche da demolizione gratis (%d in tutto)" % cariche)
	ok(p.ponti() == ["G11", "J11", "R10"] and p.ponte_di_pietra("J11") and not p.ponte_di_pietra("G11"), "ponte di legno G11, di pietra J11 e R10")
	var b: Array = p.regola("binario", [])
	var catena := true
	for i in range(1, b.size()):
		if not E.adiacenti(b[i - 1], b[i]):
			catena = false
			print("   binario interrotto: ", b[i - 1], " ", b[i])
	ok(catena, "il binario è continuo da Y5 ad A13")
	var sq: Array = p.americani()
	ok(p.schiera(sq.map(func(a): return a.id), "A3").ok and p.inizia_missione().ok, "la squadra entra in A3")
	# Ponte di legno G11: una carica, innesco nelle Operazioni.
	var a0: Dictionary = sq[0]
	p.s.pausa = ""
	p.s.fase = "operazioni"
	a0.hex = "G11"
	a0.postura = "standing"
	a0.armi.append({"tipo": "satchel", "inceppata": false, "rotta": false, "preparata": true, "catturata": false})
	var r0: Dictionary = p.azione_ponte(a0.id, "sotto", "G11")
	ok(r0.ok and a0.get("sotto_ponte", false), "si scende sotto il ponte G11 %s" % str(r0.get("errore", "")))
	var r1: Dictionary = p.azione_ponte(a0.id, "carica", "G11")
	var r2: Dictionary = p.azione_ponte(a0.id, "timer0", "G11")
	ok(r1.ok and r2.ok and p.ph.ponte_armato("G11"), "carica e innesco sul ponte G11 %s %s" % [str(r1.get("errore", "")), str(r2.get("errore", ""))])
	for a in sq:
		if a.hex != "" and E.distanza(a.hex, "G11") <= 1:
			a.hex = "A3"
			a.erase("sotto_ponte")
	p._controlla_fine_automatica()
	ok(not p.ponte_intatto("G11"), "allontanata la squadra, il ponte G11 salta")
	# Ponte di pietra J11: due cariche e spoletta di 2 turni.
	p.leggi("387", {"hex": "A3"})
	ok(p.fase_round(), "387: tedeschi 22 e 23, iniziano i Round")
	a0.hex = "J11"
	a0.sotto_ponte = true
	p.s.pausa = ""
	var rr: Dictionary = p.s.round
	p.s.fase = "operazioni"
	for k in 2:
		a0.armi.append({"tipo": "satchel", "inceppata": false, "rotta": false, "preparata": true, "catturata": false})
		p.azione_ponte(a0.id, "carica", "J11")
	p.s.fase = "round"
	p.s.round = rr
	p.s.round.n = 1
	var azioni: Array = p.azioni_ponte(a0).map(func(x): return x.azione)
	p.ph.arma_ponte("J11", 2)
	ok(int(p.ponte_stato("J11").cariche) == 2 and "timer2" in azioni and p.ph.ponte_armato("J11"), "due cariche e spoletta di 2 turni sul ponte J11")
	a0.hex = "A3"
	a0.erase("sotto_ponte")
	p.ph.inizio_turno(2)
	ok(p.ponte_intatto("J11"), "dopo un turno il ponte J11 regge ancora")
	p.ph.inizio_turno(1)
	ok(not p.ponte_intatto("J11"), "all’inizio del secondo turno il ponte J11 salta")
	# Sotto il ponte: chi è ferito o in panico può cadere nel fiume.
	var sb: Dictionary = sq[3]
	sb.hex = "R10"
	sb.sotto_ponte = true
	sb.stato = "attivo"
	var gtir: Dictionary = p._crea_tedesco(22, "R13", "crouching")
	ok(p.probabilita_tiro(gtir, gtir.armi[0], sb, true).get("mods", []).any(func(m): return "sotto il ponte" in str(m[0])), "chi è sotto il ponte si colpisce come in un interno")
	gtir.stato = "rimosso"
	gtir.hex = ""
	# Il treno.
	p.leggi("486", {})
	ok(str(p.s.ph.treno.stato) == "attivo" and p.s.punti.get("Y5", "") == "locomotiva", "486: il treno entra in Y5")
	ok(p.ph.round_obbligati(), "i Round continuano finché il treno è in mappa")
	for i in 6:
		p.ph._muovi_treno(6)
	ok(str(p.s.ph.treno.stato) == "deragliato" and int(p.s.condizione) == 3, "il treno arriva al ponte G11 distrutto e deraglia: Condizione 3")
	ok(p.s.ph.treno.has("relitti"), "506: i vagoni scivolano fuori dal binario (%s)" % str(p.s.ph.treno.get("relitti", [])))
	var vagoni: Array = p.s.get("da_leggere", {}).keys().filter(func(h): return p.s.da_leggere[h] == "595")
	ok(not vagoni.is_empty(), "i vagoni merci rovesciati nascondono qualcosa (%s)" % str(vagoni))
	var pv0: int = p.pv_totali()
	for h in vagoni:
		p.leggi("595", {"hex": h})
	ok(p.pv_totali() == pv0 + 10, "595: i tesori del Louvre valgono 10 PV, una volta sola")
	# Motocicletta e auto comando.
	p.leggi("559", {})
	var v48: Dictionary = p.veicoli.v("v48")
	ok(not v48.is_empty() and v48.modello == "moto" and p.veicoli.occupanti(v48).size() == 2, "559: motocicletta con i tedeschi 48 e 49 in W1")
	p.leggi("566", {})
	var g53: Dictionary = p.u("g53")
	ok(not p.veicoli.v("v52").is_empty() and g53.get("veicolo", "") == "v52", "566: auto comando con il corriere SS 53")
	for n in [624, 627, 659, 661]:
		p.ia._g = p.u("g49")
		p.ia._mp = 4
		p.ia.esegui(n)
	for n in [872, 876, 881, 886, 913, 916, 919, 341, 343, 350, 358, 363]:
		p.ia._g = p.u("g52")
		p.ia._mp = 4
		p.ia.esegui(n)
	ok(true, "paragrafi della motocicletta e dell’auto comando eseguiti")
	g53.stato = "morto"
	g53.hex = "W3"
	p.veicoli.scendi(g53)
	p._controlla_fine_automatica()
	var a1: Dictionary = sq[1]
	a1.hex = "W3"
	a1.postura = "crouching"
	p.s.turno = {}
	p.s.fase = "operazioni"
	var voce: Dictionary = {}
	for v in p.oggetti_disponibili(a1.id):
		if v.tipo == "documenti":
			voce = v
	var pv1: int = p.pv_totali()
	ok(not voce.is_empty() and p.prendi(a1.id, voce).ok and p.pv_totali() == pv1 + 5, "652: la borsa sigillata del corriere vale 5 PV")
	# Altri paragrafi dei tedeschi.
	p.leggi("423", {})
	for n in [710, 715, 721, 731, 761, 769, 771, 780, 783, 785, 804, 834, 846, 848, 852, 855]:
		p.ia._g = p.u("g55")
		p.ia._mp = 4
		p.ia.esegui(n)
	ok(true, "paragrafi delle mitragliatrici e dei soldati eseguiti")
	# Fine: tutti i ponti distrutti o minati e nessun tedesco attivo in mappa.
	a0.hex = "R10"
	p.ponte_stato("R10").cariche = 2
	p.ph.arma_ponte("R10", 3)
	for g in p.tedeschi():
		if p.attivo(g):
			g.stato = "morto"
	a0.hex = "A3"
	p.s.fase = "operazioni"
	p.s.round = {}
	p.s.condizione = 3
	p._controlla_fine_automatica()
	ok(p.s.fase == "fine" and int(p.s.ph.get("fine_modo", 0)) == 1, "fine 1: niente tedeschi attivi e tutti i ponti saltati o minati")
	var righe: Array = p.s.fine.get("righe", [])
	ok(righe.any(func(r): return "Ponti distrutti (3)" in str(r[0])), "a fine missione i tre ponti contano 30 PV (%s)" % str(righe))
	_treno_binario()
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)


## 503/504/493: binario interrotto da una carica, bazooka contro la locomotiva, treno che si muove nelle caselle tedesche.
func _treno_binario() -> void:
	var p = PartitaScript.new(17)
	p.nuova(9, true)
	var sq: Array = p.americani()
	p.schiera(sq.map(func(a): return a.id), "A3")
	p.inizia_missione()
	p.s.pausa = ""
	p.leggi("486", {})
	p.s.pausa = ""
	p.s.round.vantaggio = "us"
	p.s.round.treno_mosso = []
	p.ph.casella_treno([2, "us"])
	ok(int(p.s.ph.treno.idx) == 0, "con il vantaggio americano il treno aspetta la casella tedesca")
	p.ph.casella_treno([2, "de"])
	ok(int(p.s.ph.treno.idx) == 6, "nella casella tedesca il treno avanza di 6 esagoni")
	p.ph.casella_treno([])
	ok(int(p.s.ph.treno.idx) == 12, "a fine Round il treno ha fatto anche il secondo turno")
	# carica lanciata sul binario davanti alla locomotiva
	var b: Array = p.regola("binario", [])
	p.ph.distruggi_binario(str(b[14]))
	p.ph._muovi_treno(6)
	ok(str(p.s.ph.treno.stato) == "deragliato", "503: la locomotiva entra nel binario interrotto e deraglia")
	# bazooka contro la locomotiva
	var q = PartitaScript.new(17)
	q.nuova(10, true)
	q.schiera(q.americani().map(func(a): return a.id), "A3")
	q.inizia_missione()
	q.leggi("486", {})
	q.ph._muovi_treno(6)
	q.ph.colpo_treno(0, "M")
	ok(str(q.s.ph.treno.stato) == "attivo", "504: la locomotiva regge a una penetrazione media")
	q.ph.colpo_treno(2, "M")
	ok(str(q.s.ph.treno.stato) == "deragliato" and q.s.ph.treno.relitti.size() == 5, "504: un vagone distrutto fa deragliare il treno")
