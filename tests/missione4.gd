extends SceneTree
## Missione 4: lancio col paracadute, notte e razzi illuminanti, cassa delle armi, ponti da disinnescare, fuga del generale.
## Uso: godot --headless --path . --script tests/missione4.gd

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
			continue
		var a: Dictionary = turno[0]
		if int(a.get("paracadute", 0)) > 0:
			if a.postura == "prone":
				q.cambia_postura(a.id, "crouching")
			if not q.togli_paracadute(a.id).ok:
				q.passa(a.id)
		else:
			q.passa(a.id)

func _init() -> void:
	var lanci := 0
	var round_partiti := 0
	for seme in range(1, 13):
		var p = PartitaScript.new(4)
		p.nuova(seme, true)
		if seme == 1:
			ok(p.terreno.limite_vista == 5, "notte: vista 5")
			ok(p.e_ingresso("Y6") and p.e_ingresso("Y15") and not p.e_ingresso("Y16"), "si parte da Y6–Y15")
			ok(not p.schiera(["A", "B"], "Y6").ok, "un solo soldato per esagono")
			ok(p.u("A").armi[0].tipo == "smg" and p.arma_di(p.u("C"), "bazooka").is_empty(), "il bazooka non è addosso ai soldati")
		var righe := 6
		for id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
			p.schiera([id], "Y%d" % righe)
			righe += 1
		var r: Dictionary = p.inizia_missione()
		if not r.ok:
			ok(false, "il lancio parte (seme %d): %s" % [seme, str(r)])
			continue
		lanci += 1
		var atterrati: Array = p.americani().filter(func(x): return x.hex != "" and x.hex.substr(0, 1) != "Y" or x.stato == "morto")
		if seme == 1:
			ok(atterrati.size() >= 6, "i soldati scendono verso ovest (%d)" % atterrati.size())
			ok(p.s.cassa.stato in ["chiusa", "persa"], "la cassa è atterrata (%s in %s)" % [p.s.cassa.stato, p.s.cassa.hex])
			ok(int(p.s.condizione) in [2, 3, 4], "dopo il lancio Condizione %d" % int(p.s.condizione))
		if p.fase_round():
			round_partiti += 1
			gioca_round(p)
		ok(errori_cronaca(p).is_empty(), "lancio %d senza errori (fase %s, Condizione %d)" % [seme, p.s.fase, int(p.s.condizione)])
	ok(lanci == 12, "12 lanci completati (%d con i Round)" % round_partiti)

	# Cassa, paracadute, ponti.
	var q = PartitaScript.new(4)
	q.nuova(4)
	q.s.cassa = {"hex": "K10", "stato": "chiusa", "armi": ["ar", "bazooka"], "munizioni": {"bazooka": 2}}
	var a: Dictionary = q.u("A")
	a.stato = "attivo"
	a.hex = "K10"
	a.postura = "crouching"
	ok(q.apri_cassa("A").ok and q.s.cassa.stato == "aperta", "la cassa si apre")
	var voci: Array = q.oggetti_disponibili("A")
	ok(voci.size() == 4, "nella cassa: 2 armi e 2 razzi (%d voci)" % voci.size())
	var razzo: Dictionary = voci.filter(func(v): return v.tipo == "mun:bazooka")[0]
	ok(q.prendi("A", razzo).ok and int(a.munizioni.get("bazooka", 0)) == 1, "A prende un razzo")
	var b: Dictionary = q.u("B")
	b.stato = "attivo"
	b.hex = "G14"
	for i in 4:
		q.disinnesca_ponte("B")
	ok(q.ponte_stato("G14").get("catturato", false), "il ponte G14 è catturato")
	# Razzo illuminante.
	q.leggi("086", {"hex": "", "ids": []})
	ok(q.s.razzi.size() == 1 and not q.terreno.illuminati.is_empty(), "il razzo illumina (%s)" % str(q.s.razzi))
	var c: String = q.s.razzi[0]
	var lontano := ""
	for h in q.terreno.illuminati:
		if q.E.distanza(h, c) == 3:
			lontano = h
	q.leggi("724", {"hex": "", "ids": []})
	ok(q.terreno.illuminati.is_empty(), "il razzo si spegne")
	q.leggi("556", {"hex": "", "ids": []})
	q.leggi("097", {"hex": "", "ids": []})
	ok(q.u("J").hex == "A5" and q.u("J").ferito, "il sopravvissuto dell’aliante entra in A5")
	# Paracadute nei Round.
	q.leggi("590", {"hex": "", "ids": []})
	ok(q.fase_round(), "590 avvia i Round")
	a.paracadute = 2
	gioca_round(q, 120)
	ok(errori_cronaca(q).is_empty(), "nessun errore nella cronaca (cassa e ponti)")
	# Fuga del generale: Kübelwagen in M4.
	var k = PartitaScript.new(4)
	k.nuova(8)
	var x: Dictionary = k.u("A")
	x.stato = "attivo"
	x.hex = "K8"
	k.leggi("741", {"hex": "K8", "ids": ["A"]})
	ok(not k.veicoli.v("vk").is_empty(), "la Kübelwagen nascosta è in M4")
	k.leggi("590", {"hex": "", "ids": []})
	gioca_round(k, 200)
	ok(errori_cronaca(k).is_empty(), "generale e aiutante senza errori")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
