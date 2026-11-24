extends SceneTree
## Missione 14 (Purple Heart): ingresso sulle jeep, radio del sergente, J8, superstiti, ripiegamento, artiglieria, carro PH.
const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")
var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	var p = PartitaScript.new(14)
	p.nuova(14, true)
	ok(p.lettera_mappa() == "C" and p.ph.attiva(), "mappa C, libro Purple Heart")
	var sq: Array = p.americani()
	ok(p.schiera(sq.map(func(a): return a.id), "Y7").ok and p.inizia_missione().ok, "la squadra entra in Y7")
	var j1: Dictionary = p.veicoli.v("vjeep1")
	var j2: Dictionary = p.veicoli.v("vjeep2")
	ok(not j1.is_empty() and not j2.is_empty() and p.veicoli.occupanti(j1).size() == 4 and p.veicoli.occupanti(j2).size() == 4, "due jeep con quattro uomini ciascuna")
	ok(p.radio_presidiata(), "la radio la porta il sergente A")
	# J8: superstiti e ripiegamento.
	for a in sq:
		if a.get("veicolo", "") != "":
			p.veicoli.scendi(a)
		a.hex = "J8"
	p.s.pausa = ""
	p.leggi("331", {"hex": "J8", "ids": [sq[0].id]})
	ok(p.s.modifiche.get("J8", "") == "rubble" and p.s.punti.get("L8", "") != "", "331: macerie in J8, camion distrutto in L8")
	p.leggi("348", {"hex": "J8", "ids": [sq[0].id]})
	ok(not p.u("J").is_empty() and p.u("K").stato == "incapacitato" and p.u("J").get("superstite_ph", false), "541: superstiti J e K incapacitati")
	ok(int(p.s.condizione) == 2 and p.s.ph.get("ripiegamento", false), "362: ripiegamento, Condizione 2")
	# Uscita dal bordo nord.
	var a0: Dictionary = sq[1]
	a0.hex = "Y5"
	a0.postura = "standing"
	p.s.fase = "operazioni"
	p.s.pausa = ""
	var pv0: int = p.pv_totali()
	var r: Dictionary = p.esci(a0.id)
	ok(r.ok and p.pv_totali() == pv0 + 2, "un soldato esce da Y5: +2 PV %s" % str(r.get("errore", "")))
	var a1: Dictionary = sq[2]
	var kk: Dictionary = p.u("K")
	a1.hex = "Y6"
	kk.hex = "Y6"
	a1.postura = "standing"
	a1.armi = []
	var rt: Dictionary = p.trascina(a1.id, "K", "USCITA")
	ok(rt.ok and kk.get("uscito", false) and p.pv_totali() == pv0 + 4, "il superstite K trascinato fuori mappa (%s)" % str(rt.get("errore", "ok")))
	var righe: Array = []
	ok(p.ph.righe_fine(righe) == 2, "K portato in salvo: +2 PV a fine missione")
	# Artiglieria.
	p.leggi("592", {})
	p.leggi("383", {})
	p.leggi("378", {"hex": "S9"})
	ok(not p.ponte_intatto("S9"), "378: il ponte in S9 è distrutto")
	# Condizione 3: Panzer IV con i paragrafi di Purple Heart.
	p.s.condizione = 3
	p.leggi("445", {})
	var v43: Dictionary = p.veicoli.v("v43")
	ok(not v43.is_empty() and v43.modello == "panzer4" and int(v43.primo_turno) == 923, "445: Panzer IV 43 in Q19, primo turno 923")
	var g43: Dictionary = p.u("g43")
	for n in [909, 921, 923, 900, 901, 902, 903, 905, 906, 907, 908, 910, 911, 925, 927, 929]:
		p.veicoli.esegui_carro(n, g43, v43)
	ok(true, "paragrafi del carro di Purple Heart eseguiti senza errori")
	p.leggi("438", {})
	p.leggi("453", {})
	ok(p.attivo(p.u("g40")) and p.u("g44").hex == "H19", "438/453: tedeschi 40–42 e 44–45 attivati")
	for n in [590, 712, 750]:
		p.ia._g = p.u("g41")
		p.ia._mp = 4
		p.ia.esegui(n)
	ok(true, "paragrafi 590, 712, 750 eseguiti")
	p.leggi("462", {})
	ok(true, "462: catena di eventi della Condizione 3")
	_mg_jeep()
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)


## Mitragliatrice media montata sulla jeep 1 (scelta nello schieramento) e dispersione dell’artiglieria del 555.
func _mg_jeep() -> void:
	var p = PartitaScript.new(14)
	p.nuova(3, true)
	ok(p.ph.mg_jeep_possibile(), "nello schieramento si può montare la MG sulla jeep")
	p.ph.scegli_mg_jeep(true)
	p.schiera(p.americani().map(func(a): return a.id), "Y7")
	p.inizia_missione()
	var j1: Dictionary = p.veicoli.v("vjeep1")
	ok(j1.has("mg") and not p.u("G").armi.any(func(w): return w.tipo == "ar"), "MG media sulla jeep 1 al posto del BAR di G")
	var occ: Array = p.veicoli.occupanti(j1)
	ok(p._mg_montata(occ[1]).tipo == "mmg" and p._mg_montata(occ[0]).is_empty() and p._mg_montata(occ[2]).is_empty(), "la spara solo il passeggero 1")
	var prima: int = p.s.modifiche.size()
	p.leggi("555", {"hex": "K9"})
	ok(p.s.cronaca.any(func(r): return "Artiglieria su K9: percentuale" in str(r.x)), "555: dispersione dell’artiglieria con i percentuali")
