extends SceneTree
## Missione 10 (Move Out!): mortai nella Condizione 1 sulla mappa A, poi la città sulla mappa B.
## Uso: godot --headless --path . --script tests/missione10.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")
const MO = preload("res://scripts/motore/missioni_mo.gd")
const E = preload("res://scripts/motore/esagoni.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	# Diagrammi di dispersione.
	ok(MO.dispersione("M10", 5) == "M10", "0–9: il colpo cade sul bersaglio")
	ok(MO.dispersione("M10", 12) == E.vicino("M10", 0), "10–14: un esagono a nord")
	ok(MO.dispersione("M10", 47) == E.vicino(E.vicino("M10", 0), 0), "45–49: due esagoni a nord")
	ok(MO.dispersione("M10", 62) == E.vicino(E.vicino("M10", 1), 2), "60–64: due esagoni a est")
	ok(MO.dispersione("A1", 97) == "", "fuori mappa")
	var p = PartitaScript.new(10)
	p.nuova(10, true)
	ok(p.missione.libro == "mo" and p.lettera_mappa() == "A", "mappa A all’inizio")
	ok(p.inizia_missione().ok, "missione iniziata senza schieramento")
	ok(p.tedeschi_attivi().size() == 14, "quattordici tedeschi sulla riga 19 (%d)" % p.tedeschi_attivi().size())
	ok(not p.veicoli.v("v26").is_empty() and not p.veicoli.v("v27").is_empty(), "Panzer IV e Jagdpanther in mappa")
	ok(p.u("MOR").get("artiglieria", false) and p.u("B").stato == "dorme", "mortai pronti, squadra fuori")
	ok(p.s.fase == "round", "Round dall’inizio")
	ok(p.pv_totali() == 0, "nessun PV per le attivazioni")
	# Si gioca la Condizione 1: i mortai sparano sul tedesco più vicino.
	var colpi := 0
	var giri := 0
	while int(p.s.condizione) == 1 and giri < 3000 and p.s.fase != "fine":
		giri += 1
		if p.s.pausa != "":
			p.prosegui()
			continue
		var di_turno: Array = p.americani_di_turno()
		if di_turno.is_empty():
			p.prosegui()
			continue
		var a: Dictionary = di_turno[0]
		var bersagli: Array = p.tedeschi_attivi()
		var k := 0 if p.s.turno.is_empty() or not (0 in p.s.turno.get("colpi", [])) else 1
		if bersagli.is_empty():
			p.passa(a.id)
			continue
		var r: Dictionary = p.mo.colpo(a.id, k, bersagli[0].hex)
		if r.get("ok", false):
			colpi += 1
		else:
			print("        ! ", r.get("errore", ""))
			p.passa(a.id)
	ok(colpi > 4, "i mortai hanno sparato (%d colpi)" % colpi)
	ok(int(p.s.condizione) == 2, "Condizione 2 dopo l’avanzata (giri %d)" % giri)
	ok(p.lettera_mappa() == "B" and p.terreno != null, "si passa alla mappa B")
	ok(p.u("MOR").stato == "rimosso", "i mortai tacciono")
	ok(p.u("B").stato == "fuori" and "Y5" in p.esagoni_ingresso(), "la squadra entra da Y1–Y19")
	var colpiti: int = p.tedeschi().filter(func(g): return g.stato in ["morto", "incapacitato"]).size()
	print("        tedeschi fuori combattimento: %d, PV %d" % [colpiti, p.pv_totali()])
	ok(colpiti == 0 or p.pv_totali() > 0, "PV per i tedeschi colpiti dai mortai")
	# Salvataggio sulla mappa B.
	var q = PartitaScript.new(10)
	ok(q.carica(JSON.parse_string(JSON.stringify(p.salva()))) and q.lettera_mappa() == "B" and q.terreno.tipo("S13") == p.terreno.tipo("S13"), "salvataggio ricaricato sulla mappa B")
	# Riattivazione (871 → 875: tedeschi 34 e 35 in A1).
	var usciti: Array = p.tedeschi().filter(func(g): return g.stato == "uscito")
	ok(not usciti.is_empty(), "tedeschi usciti dalla mappa A pronti a tornare (%d)" % usciti.size())
	p.leggi("871", {"hex": "", "ids": []})
	var tornati: Array = p.tedeschi_attivi()
	ok(not tornati.is_empty() and tornati.all(func(g): return g.hex.begins_with("A")), "871: tornano dal bordo A della mappa B (%s)" % ", ".join(tornati.map(func(g): return "%d@%s" % [g.num, g.hex])))
	ok(p.s.fase == "round", "iniziano i Round")
	# La missione non finisce prima della Condizione 4.
	p.s.fase = "operazioni"
	p.s.pausa = ""
	p._controlla_fine_automatica()
	ok(p.s.fase != "fine", "nessuna fine prima che la squadra entri")
	# 893: arriva lo Sherman.
	p.s.fase = "operazioni"
	p.leggi("893", {})
	ok(p.u("Z").hex == "Y5" and int(p.s.condizione) == 4, "893: Sherman in Y5 e Condizione 4")
	# Colpo casuale 873.
	p.leggi("873", {})
	ok(true, "873 eseguito")
	var errs: Array = p.s.cronaca.filter(func(c): return str(c.get("t", "")) == "errore")
	for c in errs:
		print("        ! " + str(c.x))
	ok(errs.is_empty(), "nessun errore nella cronaca")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
