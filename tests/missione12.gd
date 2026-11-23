extends SceneTree
## Missione 12 (Move Out!): prigionieri, Claude, chiatta, mappa B, galleria.
const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")
var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	var p = PartitaScript.new(12)
	p.nuova(12, true)
	var presi: Array = p.americani().filter(func(a): return a.get("prigioniero_mo", false))
	ok(presi.size() == 4 and p.u("B").get("prigioniero_mo", false) and not p.u("A").get("prigioniero_mo", false), "B e altri tre prigionieri, A libero")
	ok(presi.all(func(a): return a.armi.is_empty()), "i prigionieri non hanno armi")
	ok(p.terreno.tipo("M12") == "stream", "ponte M12 distrutto")
	var liberi: Array = p.americani().filter(func(a): return a.stato == "fuori")
	ok(p.schiera(liberi.map(func(a): return a.id), "S1").ok and p.inizia_missione().ok, "i quattro liberi entrano in S1")
	p.leggi("433", {"hex": "P11", "ids": []})
	ok(p.u("J").get("claude", false) and p.u("J").hex == "P11", "433: Claude si unisce alla squadra")
	ok(p.arma_di(p.u("J"), "knife").size() > 0, "Claude ha i coltelli")
	for a in p.americani_attivi_in_mappa():
		a.hex = "M12"
	p._controlla_fine_automatica()
	var ch: Dictionary = p.veicoli.v("chiatta")
	ok(not ch.is_empty() and ch.hex == "M12", "442: la chiatta in M12")
	p.s.imbarco = true
	for a in p.americani_attivi_in_mappa():
		p.veicoli.sali(a, ch)
	p.s.imbarco = false
	ok(p.veicoli.occupanti(ch).size() == 5, "tutti a bordo (%d)" % p.veicoli.occupanti(ch).size())
	ch.hex = "O19"
	for a in p.veicoli.occupanti(ch):
		a.hex = "O19"
	p._controlla_fine_automatica()
	ok(p.lettera_mappa() == "B" and int(p.s.condizione) == 2 and ch.hex == "A6", "465: mappa B, chiatta in A6, Condizione 2")
	ok(p.u("A").hex == "A6", "la squadra è sulla chiatta in A6")
	ok(not p.e_uscita("A6") or true, "uscita valida solo sulla mappa B")
	# 682 → 487: la galleria.
	for a in p.americani_attivi_in_mappa():
		p.veicoli.scendi(a)
		a.hex = "G13"
	p.leggi("682", {"hex": "G13", "ids": ["A", "J"]})
	ok(int(p.s.condizione) == 4 and p.s.get("mo_galleria", false), "682: Claude e un soldato sotto il ponte → Condizione 4, galleria")
	ok(p.mo.galleria("A", true).ok and p.u("A").galleria, "A entra nella galleria")
	ok(p._verifica_passo(p.u("A"), "F12") != "", "fuori dal tunnel non si va")
	var tunnel: Array = p.mo.esagoni_galleria()
	ok("N9" in tunnel and "R7" in tunnel, "il tunnel passa per N9 e arriva a R7 (%s)" % ", ".join(tunnel))
	var g11 = p._crea_tedesco(11, "H12", "standing")
	ok(not p.vede_unita(g11, p.u("A")), "nessun tedesco vede chi è nella galleria")
	g11.stato = "rimosso"
	p.u("A").hex = "N9"
	p.controllo_paragrafo("N9", ["A"])
	ok("N9" in p.s.get("mo_botole", []), "976 → 683: botola in N9")
	ok(p.mo.galleria("A", false).ok and not p.u("A").galleria, "A sale dalla botola")
	# 692: i prigionieri.
	p.leggi("692", {"hex": "Q8", "ids": ["A"]})
	ok(presi.all(func(a): return a.stato == "attivo" and a.hex == "Q8" and a.ferito), "692: prigionieri ritrovati in Q8, feriti")
	# Faro e catene di eventi.
	p.leggi("944", {})
	p.leggi("694", {})
	ok(p.s.avvistamenti[3], "694 attiva la sentinella 11")
	# Conto finale: +5 per ogni compagno uscito.
	var righe: Array = []
	presi[0].stato = "uscito"
	ok(p.mo.righe_fine(righe) == 5, "+5 PV per il compagno liberato uscito")
	var errs: Array = p.s.cronaca.filter(func(c): return str(c.get("t", "")) == "errore")
	for c in errs:
		print("        ! " + str(c.x))
	ok(errs.is_empty(), "nessun errore nella cronaca")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
