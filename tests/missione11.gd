extends SceneTree
## Missione 11 (Move Out!): sentinella, paracadutisti alla deriva, allarme, risveglio della squadra, ghiaccio.
## Uso: godot --headless --path . --script tests/missione11.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func errori_cronaca(q) -> Array:
	var e: Array = q.s.cronaca.filter(func(c): return str(c.get("t", "")) == "errore")
	for c in e:
		print("        ! " + str(c.x))
	return e

## Muove il soldato un esagono alla volta verso h (Operazioni) finché parte un Round.
func cammina(q, id: String, h: String) -> void:
	for i in 40:
		var a: Dictionary = q.u(id)
		if q.s.fase != "operazioni" or a.hex == h or not q.attivo(a):
			return
		var migliore := ""
		for v in E.vicini(a.hex):
			if q.terreno.costo_movimento(a.hex, v) < 0:
				continue
			if migliore == "" or E.distanza(v, h) < E.distanza(migliore, h):
				migliore = v
		if migliore == "":
			return
		q.muovi([id], migliore)

func _init() -> void:
	var p = PartitaScript.new(11)
	p.nuova(11, true)
	ok(p.missione.libro == "mo" and p.paragrafi.has("409") and p.paragrafi["409"].it.begins_with("[s1]"), "libretto di Move Out! caricato")
	ok(11 in PartitaScript.disponibili(), "missione 11 nell’elenco")
	ok(p.terreno.tipo("L7") == "clear" and p.mo.ghiacciato("L7"), "ruscello ghiacciato = terreno libero")
	ok(not p.schiera(["A"], "X8").ok, "si schiera solo in Y8")
	ok(p.schiera(["A"], "Y8").ok, "la sentinella A in Y8")
	ok(not p.schiera(["B"], "Y8").ok, "un solo soldato sveglio")
	ok(p.inizia_missione().ok, "missione iniziata")
	ok(p.u("B").stato == "dorme", "gli altri dormono fuori mappa")
	# La sentinella cammina verso il primo esagono con 409.
	var bersaglio := ""
	for h in p.missione.condizioni["1"].esagoni:
		if p.missione.condizioni["1"].esagoni[h] == "s1:409" and (bersaglio == "" or E.distanza(h, "Y8") < E.distanza(bersaglio, "Y8")):
			bersaglio = h
	cammina(p, "A", bersaglio)
	ok(p.s.avvistamenti[1], "paracadutisti avvistati (409) andando verso %s" % bersaglio)
	var paracadutisti: Array = p.tedeschi().filter(func(g): return int(g.num) in [29, 39, 42, 43, 45, 47, 48, 49])
	ok(paracadutisti.size() == 8, "otto paracadutisti in gioco (%d)" % paracadutisti.size())
	var a_terra: Array = paracadutisti.filter(func(g): return p.attivo(g))
	ok(a_terra.all(func(g): return g.postura == "prone" and int(g.get("paracadute", 0)) == 2 or g.ferito), "a terra proni col paracadute")
	ok(int(p.s.condizione) == 2, "Condizione 2 dopo gli atterraggi")
	ok(p.s.fase == "round" or a_terra.is_empty(), "iniziano i Round")
	ok(p.s.mo_allarme == "attesa", "si aspetta l’allarme dal casello")
	# Turni tedeschi col paracadute: lo tolgono in due azioni.
	var g0: Dictionary = a_terra[0] if not a_terra.is_empty() else {}
	if not g0.is_empty():
		p.ia.turno(g0)
		ok(int(g0.paracadute) == 1 and g0.postura == "crouching", "primo turno: si accovaccia e comincia a togliersi il paracadute")
		p.ia.turno(g0)
		ok(int(g0.paracadute) == 0, "secondo turno: paracadute tolto")
	# La sentinella arriva al casello T8: allarme (411).
	var a: Dictionary = p.u("A")
	a.hex = "T8"
	p._controlla_fine_automatica()
	ok(p.s.mo_allarme == "dato" and p.u("B").stato == "fuori" and int(p.u("B").attesa) == 2, "allarme dato: la squadra si sveglia (2 azioni)")
	ok(p.pv_totali() >= 8 + 4, "PV: 8 attivazioni + 4 per l’allarme (%d)" % p.pv_totali())
	# Attesa fuori mappa e ingresso in Y8.
	var b: Dictionary = p.u("B")
	p.s.fase = "round"
	p.s.pausa = ""
	b.turni = 1
	b.slot = "turni"
	b.consapevole = true
	p.s.turno = {}
	var prima := int(b.attesa)
	ok(p.mo.prepara(b) and int(b.attesa) == prima - 1, "B spende un’azione a prepararsi")
	# Condizione 3 quando entra l’ultimo.
	for x in p.americani():
		if x.stato == "fuori":
			x.stato = "attivo"
			x.hex = "Y8"
	p.s.fase = "operazioni"
	p._controlla_fine_automatica()
	ok(int(p.s.condizione) == 3, "Condizione 3 quando entra l’ultimo soldato")
	# Ghiaccio: con il dado truccato a 0 cede.
	var c: Dictionary = p.u("C")
	c.hex = "L7"
	c.hex_prec = "K7"
	var visto := false
	for i in 30:
		p.mo._ghiaccio({"hex": "L7"})
		if p.terreno.tipo("L7") == "ford":
			visto = true
			break
	ok(visto and ("L7" in p.s.guadi), "il ghiaccio cede: guado in L7")
	ok(c.hex == "K7" and c.postura == "prone" or c.get("bagnato", false), "il soldato torna prono indietro oppure è bagnato")
	# Evento 460: Condizione 4/5/6 secondo le righe.
	for x in p.americani_attivi_in_mappa():
		x.hex = "B3"
	p.leggi("460", {})
	ok(int(p.s.condizione) == 4, "nessuno a sud della riga 10: Condizione 4")
	# Evento 450 → 452: paracadutista fuori mappa in W1.
	p.s.fase = "operazioni"
	p.leggi("450", {})
	ok(p.s.avvistamenti[4], "450 porta a 452 (avvistamento 4)")
	ok(p.u("g28").is_empty() or p.u("g28").hex == "W1" or not p.attivo(p.u("g28")), "il tedesco 28 entra in W1 (o non sopravvive)")
	# Uscita a ovest: 2 PV.
	var pv0: int = p.pv_totali()
	var d: Dictionary = p.u("D")
	d.hex = "A5"
	d.postura = "standing"
	p.s.fase = "operazioni"
	p.s.pausa = ""
	p.esci("D")
	ok(p.pv_totali() == pv0 + 2, "uscita dal bordo ovest: +2 PV")
	ok(errori_cronaca(p).is_empty(), "nessun errore nella cronaca")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
