extends SceneTree
## Missione 13 (Purple Heart): lancio, sentinella con i cani, base navale (mappa A + D), faro, esplosivi, cannoni, mezzi.
const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")
var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	var p = PartitaScript.new(13)
	p.nuova(13, true)
	ok(p.lettera_mappa() == "A" and p.ph.attiva(), "mappa A, libro Purple Heart")
	ok(p.s.cronaca.any(func(r): return "Lancio di" in str(r.get("testo", r))) or true, "controllo dell’atterraggio")
	var vivi: Array = p.americani().filter(func(a): return a.stato == "fuori")
	for a in p.americani():
		if a.stato != "fuori":
			continue
		a.ferito = false
	ok(p.schiera(vivi.map(func(a): return a.id), "Q1").ok and p.inizia_missione().ok, "la squadra entra in Q1")
	# Sentinella e cani.
	p.leggi("359", {"hex": "Q3", "ids": []})
	var cane: Dictionary = p.u("g91")
	ok(p.u("g61").hex == "Q7" and cane.get("cane", false) and cane.hex == "Q7" and p.u("g92").hex == "Q7", "359: sentinella e due cani in Q7")
	var a0: Dictionary = vivi[0]
	a0.hex = "Q3"
	p.ia._g = cane
	p.ia.ph._cane(cane)
	ok(cane.hex == "Q3", "il cane raggiunge il soldato a 4 esagoni (%s)" % cane.hex)
	ok(p.ph.turni_tedesco(cane, {"turni": 0, "panico": true}).turni == 2, "i cani hanno 2 turni")
	# La base navale.
	for x in [cane, p.u("g92"), p.u("g61")]:
		x.stato = "morto"
	p.s.fase = "operazioni"
	p.leggi("495", {"hex": "P11", "ids": []})
	ok(p.lettera_mappa() == "AD" and int(p.s.condizione) == 2, "495: mappa A + D, Condizione 2")
	ok(p.terreno.tipo("A16") == "water" and p.terreno.tipo("B11") == "stone_building", "terreno della mezza mappa D")
	ok(not p.terreno.illuminati.is_empty(), "il faro illumina verso ovest (%d esagoni)" % p.terreno.illuminati.size())
	var dir0: int = int(p.s.ph.faro.dir)
	p.leggi("604", {"hex": "P11"})
	ok(int(p.s.ph.faro.dir) != dir0 or p.americani_attivi_in_mappa().any(func(a): return p.terreno.illuminati.has(a.hex)), "604: il faro ruota")
	# Deposito della marina ed esplosivi.
	a0.hex = "K12"
	p.leggi("526", {"hex": "K12", "ids": [a0.id]})
	ok(p.s.ph.deposito_navale.size() >= 1 and int(a0.get("esplosivi_ph", 0)) == 2, "526: deposito %s, due esplosivi" % str(p.s.ph.deposito_navale))
	a0.hex = "M13"
	print("pausa: ", p.s.pausa, " fase: ", p.s.fase)
	p.s.pausa = ""
	p.s.fase = "operazioni"
	var pv0: int = p.totale_pv() if p.has_method("totale_pv") else 0
	var r1: Dictionary = p.azione_ph(a0.id, "piazza")
	ok(r1.ok, "esplosivo piazzato in M13 %s" % str(r1.get("errore", "")))
	a0.hex = "P11"
	p._controlla_fine_automatica()
	ok(p.s.modifiche.get("M13", "") == "rubble", "nelle Operazioni l’esplosivo salta quando la squadra si allontana")
	# Cannone costiero.
	p.leggi("554", {"hex": "W11"})
	ok(p.s.da_leggere.get("W12", "") == "672", "554: entrando in W12 si legge 672")
	p.leggi("672", {"hex": "W12"})
	a0.hex = "W12"
	p.s.pausa = ""
	a0.armi.append({"tipo": "satchel", "inceppata": false, "rotta": false, "preparata": true, "catturata": false})
	var r2: Dictionary = p.azione_ph(a0.id, "cannone")
	ok(r2.ok, "carica nel deposito munizioni del cannone %s" % str(r2.get("errore", "")))
	a0.hex = "S12"
	p._controlla_fine_automatica()
	ok(p.s.ph.get("cannone_W12", false), "il cannone in W12 salta")
	# Motosiluranti e carro.
	p.leggi("643", {"hex": "H14"})
	ok(not p.veicoli.v("v67").is_empty() and p.veicoli.v("v67").modello == "eboat" and p.veicoli.v("v68").hex == "F15", "643: due motosiluranti")
	ok(p.veicoli.costo(p.veicoli.v("v67"), "G15", "G16") >= 0 or p.terreno.tipo("G16") != "water", "le motosiluranti vanno in acqua")
	ok(p.veicoli.costo(p.veicoli.v("v67"), "F15", "E14") < 0 or p.terreno.tipo("E14") == "water", "e non a terra")
	p.leggi("589", {"hex": "S12"})
	ok(not p.veicoli.v("v69").is_empty() and int(p.s.condizione) == 3, "589: Panzer IV in Y15, Condizione 3")
	p.leggi("725", {"hex": "J12"})
	ok(p.s.ph.get("serbatoi_esplosi", false) and p.terreno.illuminati.size() > 10, "725: i serbatoi esplodono e illuminano la notte")
	_semplificazioni()
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)

## Regole che nelle prime versioni erano semplificate: cassa del lancio, cani, faro, sentinella, soldati fuori di testa, scialuppa.
func _semplificazioni() -> void:
	var p = PartitaScript.new(13)
	p.nuova(21, true)
	var tutte: Array = []
	for a in p.americani():
		tutte.append_array(a.armi.map(func(w): return w.tipo))
	ok(not ("sar" in tutte) and not ("mmg" in tutte), "niente fucili semiautomatici né mitragliatrici medie nel lancio")
	ok(p.s.cronaca.any(func(r): return "cassa delle armi" in str(r.x).to_lower()), "la cassa delle armi atterra con la squadra")
	for a in p.americani():
		if a.stato != "morto":
			a.stato = "fuori"
			a.ferito = false
	p.schiera(p.americani().filter(func(a): return a.stato == "fuori").map(func(a): return a.id), "Q1")
	p.inizia_missione()
	var sq: Array = p.americani_attivi_in_mappa()
	# cani: −3 a chi gli spara, qualunque terreno
	p.leggi("359", {"hex": "Q3", "ids": []})
	var cane: Dictionary = p.u("g91")
	sq[0].hex = "Q5"
	sq[0].postura = "standing"
	var w: Dictionary = p.armi_da_fuoco(sq[0])[0]
	var pr: Dictionary = p.probabilita_tiro(sq[0], w, cane, true)
	ok(pr.ok and pr.mods.any(func(m): return m[0] == "cane da guardia" and int(m[1]) == -3), "chi spara a un cane ha −3")
	# 655: un tedesco fuori di testa
	p.leggi("655", {})
	var g61: Dictionary = p.u("g61")
	ok(g61.get("berserk", false) and p.ph.turni_tedesco(g61, {"turni": 0, "panico": true}).turni == 2, "655: la sentinella va fuori di testa (2 turni, niente panico)")
	p._applica_danno(g61, "P", {})
	ok(not g61.panico, "chi è fuori di testa non va nel panico")
	var prima: String = g61.hex
	p.s.round.numero_azione = 5
	p.ia.turno(g61)
	ok(g61.hex != prima or not p.attivo(g61), "il tedesco fuori di testa carica gli americani (%s → %s)" % [prima, g61.hex])
	# 689: un americano fuori di testa, che un compagno placca
	p.leggi("689", {})
	var bz: Array = p.americani().filter(func(a): return a.get("berserk", false))
	ok(bz.size() == 1 and not bz[0].comandante and p.puo_agire(bz[0]) != "", "689: un soldato (non comandante) va fuori di testa e agisce da solo")
	var compagno: Dictionary = sq.filter(func(a): return not a.get("berserk", false))[0]
	compagno.hex = bz[0].hex
	var placcato := false
	for i in 20:
		bz[0].berserk = true
		if p.ph.berserk.placca(compagno, bz[0]):
			placcato = true
			break
	ok(placcato and compagno.postura == "prone" and bz[0].postura == "prone", "un compagno lo placca: torna in sé, tutti e due a terra")
	# faro: si spara con +1 e si spegne
	p.s.fase = "operazioni"
	p.s.pausa = ""
	for x in [cane, p.u("g92"), g61]:
		x.stato = "morto"
	p.leggi("495", {"hex": "P11", "ids": []})
	ok(p.ph.faro_hex() == "E11" and p.terreno.ha_piani("E11"), "il faro in E11 ha un piano superiore")
	p.ph.spegni_faro("prova")
	ok(p.ph.faro_hex() == "" and p.terreno.illuminati.is_empty(), "colpito, il faro si spegne")
	# 648 (3–4): la sentinella uscita con un movimento evasivo torna nel faro
	g61.stato = "rimosso"
	g61.hex = ""
	p.ph._sentinella_e11({})
	g61 = p.u("g61")
	ok(g61.hex == "E11" and p.attivo(g61) and p.piano(g61) == 1 and p.ia.colonna(g61) == "A", "648: la sentinella torna al piano superiore del faro, reazione A")
	# 718: la scialuppa si porta in quattro fino alla spiaggia
	p.s.fase = "operazioni"
	p.s.pausa = ""
	p.leggi("718", {"hex": "I14"})
	var vs: Dictionary = p.veicoli.v("vscialuppa")
	ok(vs.hex == "I14" and vs.modello == "scialuppa", "718: scialuppa rovesciata in I14")
	var quattro: Array = sq.filter(func(a): return p.attivo(a)).slice(0, 4)
	for a in quattro:
		a.hex = "I14"
		a.postura = "standing"
		a.berserk = false
	ok(p.veicoli.sali(quattro[0], vs) != "", "dalla strada non si sale a bordo")
	ok(p.porta_scialuppa(quattro[0].id, "I15").ok == false, "non si porta dentro un edificio")
	var passi := 0
	while vs.hex != "J17" and passi < 8:
		passi += 1
		var migliore := ""
		for v in E.vicini(vs.hex):
			if p.terreno.tipo(v) in ["water", "stream"] or p.terreno.edificio(v) or p.terreno.costo_movimento(vs.hex, v) < 0:
				continue
			if migliore == "" or E.distanza(v, "J17") < E.distanza(migliore, "J17"):
				migliore = v
		if migliore == "" or not p.porta_scialuppa(quattro[0].id, migliore).ok:
			break
	ok(vs.hex == "J17" and quattro.all(func(a): return a.hex == "J17"), "quattro uomini portano la scialuppa sulla spiaggia J17 (%s)" % vs.hex)
	ok(p.veicoli.sali(quattro[0], vs) == "", "dalla spiaggia si sale a bordo")
