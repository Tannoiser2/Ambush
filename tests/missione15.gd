extends SceneTree
## Missione 15 (Purple Heart): diga e letto asciutto, relitti e bottino, collina, chiuse e piena, colonna motorizzata.
const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")
var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	var p = PartitaScript.new(15)
	p.nuova(15, true)
	ok(p.lettera_mappa() == "C" and p.ph.attiva(), "mappa C, libro Purple Heart")
	ok(p.terreno.tipo("P7") == "cover" and p.terreno.tipo("N5") == "clear" and p.terreno.ponte("S9"), "letto asciutto, diga e ponte in S9")
	ok(p.terreno.costo_movimento("N4", "N5") < 0 and p.terreno.costo_movimento("O5", "N5") > 0, "sulla diga si entra solo da O5 e M6")
	for i in E.tutti().size():
		pass
	var catena := true
	for i in range(1, p.ph.LETTO_15.size()):
		if not E.adiacenti(p.ph.LETTO_15[i - 1], p.ph.LETTO_15[i]):
			catena = false
			print("   non adiacenti: ", p.ph.LETTO_15[i - 1], " ", p.ph.LETTO_15[i])
	ok(catena, "il letto del fiume è una catena di esagoni adiacenti")
	var sq: Array = p.americani()
	ok(p.schiera(sq.map(func(a): return a.id), "Y17").ok and p.inizia_missione().ok, "la squadra entra in Y17")
	# Relitti e bottino.
	p.leggi("373", {"hex": "Y17", "ids": [sq[0].id]})
	ok(p.s.punti.get("O15", "") != "" and p.s.da_leggere.get("N14", "") == "380", "373: relitto in O15, caduti in N14")
	sq[0].hex = "N14"
	p._controlla_da_leggere()
	ok(p.oggetti_disponibili(sq[0].id).filter(func(v): return v.da == "terra").size() >= 6, "380: bazooka, BAR, razzi e granate da raccogliere")
	# La collina.
	p.leggi("505", {"hex": "N14"})
	sq[1].hex = "X9"
	p._controlla_fine_automatica()
	ok(p.s.ph.get("collina", "") == "fatto" and int(p.s.condizione) in [2, 3], "505/519: dalla collina in X9 si passa alla Condizione %d" % int(p.s.condizione))
	# Le chiuse e la piena.
	p.s.condizione = 2
	p.leggi("532", {})
	ok(p.s.ph.has("chiuse"), "532/479: comandi delle chiuse in %s" % p.s.ph.get("chiuse", {}).get("hex", "?"))
	p.s.ph.chiuse.hex = "O5"
	sq[2].hex = "O5"
	p.s.pausa = ""
	p.s.fase = "operazioni"
	var r: Dictionary = p.azione_ph(sq[2].id, "chiuse")
	ok(r.ok and p.s.ph.chiuse.aperte and p.s.ph.has("piena"), "chiuse aperte nelle Operazioni %s" % str(r.get("errore", "")))
	ok(p.fase_round(), "565: iniziano i Round")
	sq[3].hex = "P7"
	sq[3].stato = "attivo"
	p.ph.inizio_turno(2)
	ok(p.terreno.tipo("N6") == "water" and p.terreno.tipo("Q8") == "water" and sq[3].stato == "morto", "la piena avanza di quattro esagoni e travolge chi è in P7")
	p.ph.inizio_turno(1)
	ok(not p.ph.ponte_s9() and p.terreno.tipo("S9") == "water", "la piena travolge il ponte in S9")
	ok(p.ph.round_obbligati(), "i Round continuano finché la piena è in mappa")
	for i in 3:
		p.ph.inizio_turno(2)
	ok(p.s.ph.piena.fuori and int(p.s.condizione) == 4, "542: la piena esce, Condizione 4 (+5 PV)")
	# La colonna motorizzata.
	p.s.condizione = 2
	p.leggi("593", {})
	var g4: Dictionary = p.u("g4")
	var v4: Dictionary = p.veicoli.v("v4")
	ok(not v4.is_empty() and v4.modello == "moto" and g4.get("veicolo", "") == "v4" and g4.reazione == "W", "593: motociclista 4 in A3, reazione W")
	p.ia._g = g4
	p.ia._mp = 4
	p.ia.esegui(613)
	ok(v4.hex != "A3", "613: la motocicletta avanza (%s)" % v4.hex)
	p.leggi("598", {})
	var v8: Dictionary = p.veicoli.v("v8")
	var v16: Dictionary = p.veicoli.v("v16")
	ok(p.veicoli.occupanti(v8).size() == 4 and p.veicoli.occupanti(v16).size() == 4, "598: Kübelwagen e auto comando con quattro uomini ciascuna")
	ok(p.s.ph.get("pv_uscita", 0) == 5, "698: −5 PV per ogni tedesco che esce (Condizione 2)")
	ok(p.ia.colonna(p.u("g12")) == "W", "a bordo il feldmaresciallo ignora l’autoconservazione")
	var pv0: int = p.pv_totali()
	p.veicoli._esce(v8)
	ok(p.pv_totali() == pv0 - 20, "la Kübelwagen esce con quattro tedeschi: −20 PV (%d)" % (p.pv_totali() - pv0))
	# Il feldmaresciallo e le guardie scendono.
	v16.bersagliato = true
	for id in ["g16", "g12", "g14"]:
		p.ia._g = p.u(id)
		p.ia._mp = 4
		p.ia.esegui(626 if id != "g16" else 613)
	ok(p.u("g12").get("veicolo", "") == "" and p.u("g12").reazione == "", "620: sotto il fuoco il feldmaresciallo scende e lascia la reazione W")
	for n in [322, 324, 635, 658, 665, 675, 680]:
		p.ia._g = p.u("g14") if n != 322 and n != 658 and n != 675 else p.u("g12")
		p.ia._mp = 4
		p.ia.esegui(n)
	ok(true, "paragrafi d’azione del feldmaresciallo e delle guardie eseguiti")
	# Fine: nessun tedesco attivo in mappa.
	for g in p.tedeschi():
		g.stato = "morto"
	p.s.ph.erase("attesa_598")
	p.s.fase = "operazioni"
	p._controlla_fine_automatica()
	ok(p.s.fase == "fine", "senza tedeschi attivi in mappa la missione termina (%s)" % str(p.s.get("fine", {}).get("totale", "?")))
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
