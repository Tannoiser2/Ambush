extends SceneTree
## Missione 9 (Move Out!): razzi, sentinelle, filo spinato, bunker, Jagdpanther, alba e colonna americana.
const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")
var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	var p = PartitaScript.new(9)
	p.nuova(9, true)
	ok(p.terreno.tipo("H13") == "crater" and p.terreno.limite_vista == 4, "crateri e notte (vista 4)")
	ok(p.schiera(["A", "B", "C", "D", "E", "F", "G", "H"], "A6").ok and p.inizia_missione().ok, "la squadra entra in A6")
	ok(p.s.get("radio_porta", "") == "A" and p.radio_presidiata(), "la radio la porta A")
	# Razzo che illumina la squadra (419: 0 → A6).
	p.s.fase = "operazioni"
	var prima: int = int(p.s.condizione)
	for i in 20:
		p.leggi("419", {"hex": "A6", "ids": ["A"]})
		if int(p.s.condizione) == 2:
			break
	ok(prima == 1 and int(p.s.condizione) == 2, "un razzo illumina la squadra e si passa alla Condizione 2")
	# Sentinelle.
	p.s.fase = "operazioni"
	p.s.pausa = ""
	p.leggi("437", {"hex": "", "ids": []})
	ok(p.u("g20").hex == "O4" and p.u("g40").hex == "N4" and p.u("g41").hex == "P3" and int(p.s.condizione) == 3, "437: sentinelle 20, 40, 41 e Condizione 3")
	# Filo spinato.
	p.leggi("497", {"hex": "", "ids": []})
	ok(p.mo.filo("K7"), "497: filo spinato da K5 a K9")
	p.s.fase = "round"
	ok(p._costo_passo(p.u("B"), "J7", "K7") == p.terreno.costo_movimento("J7", "K7") + 1, "nei Round il filo costa 1 PM in più")
	p.s.fase = "operazioni"
	# Bunker con Jagdpanther.
	p.leggi("639", {"hex": "", "ids": []})
	ok(p.s.bunker.has("S17") and p.u("g50").hex == "S17" and p.u("g51").hex == "S17", "639: bunker in S17 con i tedeschi 50 e 51")
	var jp: Dictionary = p.veicoli.v("v12")
	ok(not jp.is_empty() and jp.hex == "U16" and jp.get("immobile", false), "639: Jagdpanther immobile in U16")
	ok(p.arma_di(p.u("g50"), "pzb").size() > 0, "il mitragliere 50 ha il Panzerbüchse")
	p.leggi("668", {"hex": "", "ids": []})
	ok(jp.get("squarcio", false), "668: lo squarcio nel Jagdpanther")
	# Alba e colonna.
	p.leggi("874", {})
	ok(int(p.s.condizione) == 4 and p.terreno.limite_vista == 10, "874: alba, vista 10, Condizione 4")
	p.s.fase = "operazioni"
	p.s.pausa = ""
	p.leggi("885", {})
	ok(p.s.get("scelte", {}).has("887"), "885: con la radio la colonna si chiama quando si vuole")
	p.leggi("887", {})
	ok(p.u("Z").hex == "A6" and p.u("J").hex == "A6" and p.u("K").hex == "A6" and int(p.s.condizione) == 6, "887: Sherman e jeep in A6, Condizione 6")
	ok(p.terreno.limite_vista == 0, "pieno giorno")
	# Contrattacco con i Panzerfaust.
	p.leggi("892", {})
	ok(p.u("g30").hex == "Q19" and p.arma_di(p.u("g30"), "pzf").size() > 0, "892: contrattacco con i Panzerfaust in Q19")
	# Qualche Round col contrattacco: i Panzerfaust contro la colonna, i bunker e il Jagdpanther.
	var z: Dictionary = p.u("Z")
	p.veicoli.v("vsherman").hex = "P17"
	z.hex = "P17"
	for x in p.veicoli.occupanti(p.veicoli.v("vcolonna")):
		x.hex = "R17"
	p.veicoli.v("vcolonna").hex = "R17"
	p.leggi("665", {})
	var giri := 0
	var spari_at := 0
	while giri < 400 and p.s.fase != "fine":
		giri += 1
		if p.s.fase == "operazioni":
			break
		if p.s.pausa != "":
			p.prosegui()
			continue
		var dt: Array = p.americani_di_turno()
		if dt.is_empty():
			p.prosegui()
			continue
		p.passa(dt[0].id)
	for c in p.s.cronaca:
		if "spara col Panzer" in str(c.x):
			spari_at += 1
	print("        Round giocati: %d, colpi anticarro: %d, Sherman: %s" % [int(p.s.get("round", {}).get("n", 0)), spari_at, p.veicoli.v("vsherman").stato])
	ok(true, "Round col contrattacco senza blocchi")
	# Panzerfaust a bruciapelo contro lo Sherman (823).
	var g31: Dictionary = p.u("g31")
	g31.stato = "attivo"
	g31.hex = "P14"
	g31.postura = "standing"
	g31.armi = [{"tipo": "pistol", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false},
		{"tipo": "pzf", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false}]
	var vs: Dictionary = p.veicoli.v("vsherman")
	vs.stato = "attivo"
	vs.hex = "P15"
	z.stato = "attivo"
	z.hex = "P15"
	p.s.fase = "round"
	p.ia._g = g31
	p.ia.mo.esegui(823)
	ok(g31.armi.filter(func(w): return w.tipo == "pzf").is_empty(), "823: il tedesco 31 spara il Panzerfaust (monouso) allo Sherman")
	# Uscita della jeep da Y8: +5 PV.
	var pv0: int = p.pv_totali()
	var j: Dictionary = p.u("J")
	var v: Dictionary = p.veicoli.v("vcolonna")
	j.stato = "attivo"
	v.stato = "attivo"
	if p.veicoli.di(j).is_empty():
		p.s.imbarco = true
		p.veicoli.sali(j, v)
		p.s.imbarco = false
	v.hex = "Y8"
	for x in p.veicoli.occupanti(v):
		x.hex = "Y8"
	p.s.fase = "operazioni"
	p.s.pausa = ""
	p.mo.uscita(j, "Y8")
	ok(p.pv_totali() == pv0 + 5, "la jeep della colonna esce da Y8: +5 PV")
	var errs: Array = p.s.cronaca.filter(func(c): return str(c.get("t", "")) == "errore")
	for c in errs:
		print("        ! " + str(c.x))
	ok(errs.is_empty(), "nessun errore nella cronaca")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
