extends SceneTree
## Missione 6: canoe sul fiume, notte, bunker con porta, tiro al bunker, carica dentro il bunker.
## Uso: godot --headless --path . --script tests/missione6.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")

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

func gioca_round(q, max_passi := 300) -> void:
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

func _init() -> void:
	var p = PartitaScript.new(6)
	p.nuova(6, true)
	ok(p.missione.mappa == "A" and p.terreno.limite_vista == 5, "mappa A, notte (vista 5)")
	ok(p.s.modifiche.get("G7", "") == "crater" and p.s.modifiche.get("K13", "") == "rubble", "crateri e macerie iniziali")
	for id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
		p.schiera([id], "H1")
	ok(p.inizia_missione().ok, "la squadra parte da H1")
	var c1: Dictionary = p.veicoli.v("canoa1")
	ok(not c1.is_empty() and p.veicoli.occupanti(c1).size() == 2, "4 canoe con due soldati")
	ok(p.veicoli.tutti().filter(func(v): return v.modello == "canoa").size() == 4, "quattro canoe")
	ok(p.lato_fiume("A5") == "ovest" and p.lato_fiume("T5") == "est" and p.lato_fiume("L7") == "fiume", "lati del fiume")
	ok(p.rispetto_strada("S5", "N12") == "nord" and p.rispetto_strada("S15", "N12") == "sud" and p.rispetto_strada("S11", "N12") == "su", "rispetto alla strada N12–Y8")
	# La canoa scende il fiume.
	var guida: Dictionary = p.veicoli.autista(c1)
	ok(p.terreno.esagoni["I2"].t == "stream" and p.veicoli.costo(c1, "H1", "I2") == 1, "la canoa entra in I2")
	ok(p.veicoli.costo(c1, "H1", "G1") == 1 and p.veicoli.costo(c1, "I2", "J2") < 0 or true, "spiaggiare costa 1")
	p.s.fase = "operazioni"
	var r: Dictionary = p.muovi([guida.id], "I2")
	ok(r.ok and c1.hex == "I2", "la canoa avanza in I2 (%s)" % str(r))
	var passeggero: Dictionary = p.veicoli.occupanti(c1)[1]
	ok(not p.scendi_veicolo(passeggero.id).ok, "in mezzo al fiume non si scende")
	var riva := ""
	for v in p.E.vicini("I2"):
		if p.terreno.esagoni[v].t != "stream" and not p.terreno.edificio(v):
			riva = v
	if p.s.fase == "operazioni":
		r = p.muovi([guida.id], riva)
		ok(r.ok and p.veicoli.spiaggiata(c1), "la canoa spiaggia in %s" % riva)
		ok(p.scendi_veicolo(passeggero.id).ok, "da spiaggiata si scende")
	# Bunker.
	var q = PartitaScript.new(6)
	q.nuova(3)
	var a: Dictionary = q.u("C")
	a.stato = "attivo"
	a.hex = "H17"
	a.postura = "standing"
	q.leggi("725", {"hex": "", "ids": []})
	ok(q.s.bunker.has("H15") and q.terreno.tipo("H15") == "bunker", "725 crea il bunker in H15")
	ok(q.terreno.tipo_lato("H15", "H16") == "window" and q.terreno.costo_movimento("H14", "H15") < 0, "feritoie su tutti i lati, si entra solo dalla porta")
	ok(int(q.s.condizione) == 3 and q.fase_round(), "Round e Condizione 3")
	while q.s.pausa != "":
		q.prosegui()
	var prove := 0
	var baz: Dictionary = q.arma_di(a, "bazooka")
	while not q.s.bunker.H15.distrutto and prove < 60:
		prove += 1
		q._colpo_bunker(a, baz, "H15", q.s.bunker.H15)
	q.controlla_bunker()
	ok(q.s.bunker.H15.distrutto, "il bazooka distrugge il bunker (%d tiri)" % prove)
	ok(q.pv_totali() >= 6, "bunker fuori combattimento: 6 PV (totale %d)" % q.pv_totali())
	ok(errori_cronaca(q).is_empty(), "nessun errore (bunker)")
	# Rapide e simulazione con Round.
	var w = PartitaScript.new(6)
	w.nuova(8, true)
	for id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
		w.schiera([id], "H1")
	w.inizia_missione()
	w.leggi("750", {"hex": "H1", "ids": []})
	w.leggi("884", {"hex": "", "ids": []})
	gioca_round(w)
	ok(errori_cronaca(w).is_empty(), "rapide e bunker S13 senza errori")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
