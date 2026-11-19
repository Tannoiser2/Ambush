extends SceneTree
## Missione 3: nebbia, fiume e ponti, schieramento in tre edifici, jeep e radio, carri armati, staffette, ordine di ritirata.
## Uso: godot --headless --path . --script tests/missione3.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func gioca_round(q, max_passi := 200) -> void:
	var passi := 0
	while q.s.fase == "round" and passi < max_passi:
		passi += 1
		if q.s.pausa != "":
			q.prosegui()
			continue
		var turno: Array = q.americani_di_turno()
		if turno.is_empty():
			q.prosegui()
		else:
			q.passa(turno[0].id)

func errori_cronaca(q) -> Array:
	var e: Array = q.s.cronaca.filter(func(c): return str(c.get("t", "")) == "errore")
	for c in e:
		print("        ! " + str(c.x))
	return e

func _init() -> void:
	var p = PartitaScript.new(3)
	p.nuova(7, true)
	ok(p.missione.mappa == "B" and p.livello_attivazione() < 0, "mappa B, nessun livello di attivazione")
	ok(p.terreno.limite_vista == 6, "nebbia leggera: vista 6")
	ok(not p.terreno.vede("A13", "H13"), "oltre 6 esagoni non si vede")
	ok(p.e_ingresso("L10") and not p.e_ingresso("A1"), "schieramento solo negli edifici")
	var edifici: Array = p.esagoni_ingresso()
	ok(p.schiera(["A", "B"], edifici[0]).ok and p.schiera(["C"], edifici[1]).ok and p.schiera(["D"], edifici[2]).ok, "tre edifici ammessi")
	ok(not p.schiera(["E"], edifici[3]).ok, "il quarto edificio è rifiutato")
	for id in ["E", "F", "G", "H"]:
		p.schiera([id], edifici[0])
	ok(p.inizia_missione().ok, "la missione parte")
	ok(p.veicoli.v("vjeep").size() > 0, "la jeep della squadra è sulla mappa (%s)" % str(p.veicoli.v("vjeep").get("hex", "")))
	ok(p.radio_presidiata(), "la radio è presidiata (%s)" % str(p.s.get("radio_hex", "")))
	# Fiume: impraticabile se non sui ponti.
	var fiume := ""
	for h in p.terreno.esagoni:
		if p.terreno.tipo(h) == "stream":
			fiume = h
			break
	var vicino: String = E_vicino(p, fiume)
	ok(p.terreno.costo_movimento(vicino, fiume) < 0, "il fiume non si guada (%s→%s)" % [vicino, fiume])
	# Nebbia fitta e schiarita.
	p.leggi("021", {"hex": "", "ids": []})
	ok(p.terreno.limite_vista == 3 and int(p.s.nebbia_veicoli) == 1, "021: vista 3 e veicoli +1 PM")
	p.leggi("022", {"hex": "", "ids": []})
	ok(p.terreno.limite_vista == 6, "022: torna la vista 6")
	# Artiglieria a esagoni fissi.
	p.leggi("017", {"hex": "", "ids": []})
	ok(errori_cronaca(p).is_empty(), "artiglieria 017 senza errori")
	# Radio e ordine di ritirata.
	p.leggi("143", {"hex": "", "ids": []})
	ok(p.s.get("offensiva", false), "143 con la radio presidiata porta al 178")
	ok(p.azioni_ponte(p.u("A")).size() >= 0, "azioni sui ponti calcolate")
	# Distruzione del ponte di legno con una carica.
	var h_legno := ""
	for h in p.ponti():
		if not p.ponte_di_pietra(h):
			h_legno = h
	ok(h_legno == "G13", "il ponte di legno è G13")
	var f: Dictionary = p.u("F")
	f.hex = h_legno
	p.arma_di(f, "satchel").preparata = true
	var azioni: Array = p.azioni_ponte(f).map(func(x): return x.azione)
	ok("carica" in azioni, "F può piazzare la carica sul ponte")
	ok(p.azione_ponte("F", "carica", h_legno).ok, "carica piazzata")
	ok(p.azione_ponte("F", "brilla", h_legno).ok and not p.ponte_intatto(h_legno), "il ponte di legno salta")
	ok(p.terreno.costo_movimento("F13", "G13") < 0, "dopo la distruzione G13 non si attraversa")
	# Tanica dal deposito.
	var g: Dictionary = p.u("D")
	g.hex = "L10"
	ok(p.azione_ponte("D", "tanica", "L10").ok and not p.arma_di(g, "tanica").is_empty(), "D prende una tanica in L10")
	ok(p.porte_usate(g) == 2, "la tanica occupa una casella di porto")
	# Staffette.
	p.leggi("271", {"hex": "", "ids": []})
	var k: Dictionary = p.u("K")
	ok(not k.is_empty() and k.hex == "A17", "la staffetta K entra in A17")
	var a: Dictionary = p.u("A")
	k.hex = a.hex
	p._fine_comando()
	ok(k.get("verificata", false), "la staffetta K raggiunge il comandante e viene interrogata")
	# Fine: uscita dopo l’ordine.
	var b: Dictionary = p.u("B")
	b.hex = "A15"
	b.postura = "standing"
	p.s.fase = "operazioni"
	ok(p.esci("B").ok and b.get("uscito_offensiva", false), "B esce da A15 dopo il 178")
	ok(errori_cronaca(p).is_empty(), "nessun errore nella cronaca (1)")

	# Carro armato: attivazione con 157 e qualche Round.
	var q = PartitaScript.new(3)
	q.nuova(3)
	for id in ["A", "B", "C", "D"]:
		var x: Dictionary = q.u(id)
		x.stato = "attivo"
		x.hex = "D7"
	q.leggi("157", {"hex": "", "ids": []})
	var carro: Dictionary = q.u("g55")
	ok(not carro.is_empty() and carro.hex == "A5", "Panzer IV attivato in A5")
	ok(int(q.s.condizione) == 2, "Condizione 2")
	ok(q.veicoli.di(carro).size() > 0, "il carro ha il suo veicolo")
	gioca_round(q)
	ok(errori_cronaca(q).is_empty(), "i Round col carro non danno errori")
	for c in q.s.cronaca:
		if str(c.get("x", "")).contains("Panzer") or str(c.get("x", "")).contains("carro"):
			print("        · " + str(c.x).left(150))
	q.leggi("258", {"hex": "", "ids": []})
	ok(errori_cronaca(q).is_empty(), "258 (cingolo) senza errori")

	# 259 e 264: attivazioni della Condizione 3.
	var r = PartitaScript.new(3)
	r.nuova(9)
	for id in ["A", "B"]:
		var x: Dictionary = r.u(id)
		x.stato = "attivo"
		x.hex = "K5"
	r.leggi("259", {"hex": "", "ids": []})
	ok(int(r.s.condizione) == 3 and not r.u("g90").is_empty(), "259 attiva i tedeschi della Condizione 3")
	gioca_round(r)
	ok(errori_cronaca(r).is_empty(), "nessun errore nella cronaca (3)")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)

func E_vicino(p, h: String) -> String:
	for v in p.E.vicini(h):
		if p.terreno.tipo(v) != "stream" and not p.ponti().has(v):
			return v
	return ""
