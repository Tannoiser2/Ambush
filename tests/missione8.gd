extends SceneTree
## Missione 8: ingresso A1–A6, esagoni XXX, Sherman guidato dal giocatore, blocchi stradali, ponte minato, uscita da Y8.
## Uso: godot --headless --path . --script tests/missione8.gd

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
	var p = PartitaScript.new(8)
	p.nuova(8)
	ok(p.e_ingresso("A1") and p.e_ingresso("A6") and not p.e_ingresso("A7"), "ingresso A1–A6")
	ok(p.livello_attivazione() == 1, "Condizione 1: livello 0–1")
	# XXX nella Condizione 2.
	p.cambia_condizione(2)
	var xxx := ""
	for h in p.missione.condizioni["2"].esagoni:
		if p.missione.condizioni["2"].esagoni[h] == "XXX":
			xxx = h
			break
	var a: Dictionary = p.u("A")
	a.stato = "attivo"
	var vicino := ""
	for v in p.E.vicini(xxx):
		if p.terreno.costo_movimento(v, xxx) >= 0:
			vicino = v
	a.hex = vicino
	ok(xxx != "" and p._verifica_passo(a, xxx) != "", "XXX vietato (%s)" % xxx)
	# Sherman.
	p.s.fase = "operazioni"
	p.s.round = {}
	p.leggi("362", {"hex": "", "ids": []})
	ok(p.sherman_entrabile(), "362: lo Sherman è disponibile")
	ok(p.entra_sherman().ok and p.u("Z").hex == "A6", "lo Sherman entra in A6")
	var z: Dictionary = p.u("Z")
	ok(p.veicoli.e_autista(z) and p.veicoli.di(z).modello == "sherman", "Z guida lo Sherman")
	var dest: Array = p.destinazioni("Z")
	ok(not dest.is_empty(), "lo Sherman ha destinazioni: %s" % str(dest))
	var r: Dictionary = p.muovi(["Z"], dest[0])
	ok(r.ok and p.veicoli.v("vsherman").hex == dest[0], "lo Sherman si muove in %s" % dest[0])
	# Blocco stradale.
	p.leggi("363", {"hex": "", "ids": []})
	ok("S11" in p.s.blocchi, "blocco stradale in S11 e S12")
	ok(p.veicoli.costo(p.veicoli.v("vsherman"), "R11", "S11") < 0, "il carro non passa dal blocco")
	for id in ["B", "C", "D"]:
		var x: Dictionary = p.u(id)
		x.stato = "attivo"
		x.hex = "S11"
	ok(p.sgombra_blocco("B").ok and not ("S11" in p.s.blocchi), "tre soldati spostano il blocco")
	# Ponte: disinnescato non salta.
	p.leggi("221", {"hex": "", "ids": []})
	p.leggi("373", {"hex": "", "ids": []})
	ok(p.ponte_intatto("M12"), "il ponte disinnescato non salta")
	# Uscita da Y8.
	var e: Dictionary = p.u("E")
	e.stato = "attivo"
	e.hex = "Y8"
	e.postura = "standing"
	var prima: int = p.pv_totali()
	if p.fase_round():
		p.s.fase = "operazioni"
	var re: Dictionary = p.esci("E")
	ok(re.ok and p.pv_totali() == prima + 1, "uscire da Y8 vale 1 PV (%s, %d→%d, fase %s)" % [str(re), prima, p.pv_totali(), p.s.fase])
	ok(errori_cronaca(p).is_empty(), "nessun errore (Sherman, blocco, ponte)")
	# Attivazioni e Round.
	var q = PartitaScript.new(8)
	q.nuova(4)
	for id in ["A", "B", "C", "D"]:
		var x: Dictionary = q.u(id)
		x.stato = "attivo"
		x.hex = "J9"
	q.leggi("355", {"hex": "", "ids": []})
	q.leggi("354", {"hex": "", "ids": []})
	gioca_round(q)
	q.leggi("524", {"hex": "", "ids": []})
	q.leggi("673", {"hex": "", "ids": []})
	gioca_round(q)
	ok(errori_cronaca(q).is_empty(), "attivazioni e Round senza errori")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
