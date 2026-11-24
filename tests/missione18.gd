extends SceneTree
## Missione 18 (Purple Heart): preparazione, rumore dei corazzati e Panzer fuori mappa, l’ufficiale sotto la Kübelwagen,
## il Jagdpanther da servire, i caduti da perquisire, gli Sherman di rinforzo guidati dai paragrafi, la decisione e la fine.
const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")
var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _nuova() -> Partita:
	var p = PartitaScript.new(18)
	p.nuova(18, true)
	var sq: Array = p.americani()
	p.schiera(sq.map(func(a): return a.id), "K15")
	p.inizia_missione()
	return p

func _init() -> void:
	var p = PartitaScript.new(18)
	p.nuova(18, true)
	ok(p.lettera_mappa() == "BE" and p.ph.m18.attiva(), "mappe B + E, Missione 18 attiva")
	var macerie: bool = ["B11", "C11", "E11", "D13", "G13", "G16", "O18", "P18"].all(func(h): return p.s.modifiche.get(h, "") == "rubble")
	ok(macerie and p.s.guadi == ["I11", "O10", "V11"], "macerie e guadi")
	ok(p.americani().filter(func(a): return a.ferito).size() == 1, "un soldato a caso comincia ferito")
	ok(p.esagoni_ingresso() == ["K15"], "la squadra comincia in K15")
	var jeep: Dictionary = p.veicoli.crea("vprova", "jeep", "I10", "us")
	ok(p.veicoli.costo(jeep, "I10", "I11") == 3 and p.veicoli.costo(jeep, "N11", "N10") == -1, "i mezzi passano il fiume solo dai guadi (3 PM)")
	p.s.veicoli.erase("vprova")
	ok(not p.e_uscita("K19"), "prima della decisione non si esce dal bordo ovest")
	ok(p.ph.m18.est_del_fiume("K5") and not p.ph.m18.est_del_fiume("K15"), "a est del fiume = in alto")

	# 507: Round senza tedeschi, al Round 2 il 512 porta i Panzer fuori mappa accanto ad A5.
	p = _nuova()
	p.leggi("507", {"hex": "K15"})
	ok(p.fase_round() and p.s.round.get("tutti_consapevoli", false), "507: iniziano i Round, tutti consapevoli")
	p.s.pausa = ""
	p._avvia_round()
	ok(p.fase_round() and p.tedeschi_attivi().is_empty(), "Round 1 senza tedeschi, si resta nei Round")
	p.s.pausa = ""
	p.s.round.n = 1
	p._fine_round()
	ok(p.fase_round(), "a fine Round 1 si resta nei Round in attesa del 512")
	p.s.pausa = ""
	p._avvia_round()
	var g57: Dictionary = p.u("g57")
	ok(not g57.is_empty() and g57.get("fuori_mappa_ph", false) and int(p.s.condizione) == 2, "512: Panzer 57–60 fuori mappa accanto ad A5, Condizione 2")
	var spia: Dictionary = p.americani()[0]
	spia.hex = "B5"
	spia.stato = "attivo"
	ok(not p.vede_unita(spia, g57), "un carro fuori mappa non si vede")
	var v57: Dictionary = p.veicoli.di(g57)
	ok(p.ph.m18.entra_dal_bordo(v57) >= 1 and not g57.get("fuori_mappa_ph", false), "al primo turno il carro entra in A5 pagando l’esagono")
	ok(p.vede_unita(spia, g57), "entrato, il carro si vede")

	# 714: Panzer in mappa, tutti consapevoli.
	p = _nuova()
	p.s.avvistamenti[6] = true
	p.s.avvistamenti[8] = true
	p.leggi("705", {"hex": "K15"})
	ok(not p.u("g57").is_empty() and int(p.s.condizione) == 2, "699/705: i carri entrano in base a ciò che vede la squadra")

	# 653: l’ufficiale sotto la Kübelwagen.
	p = _nuova()
	var a: Dictionary = p.americani()[0]
	a.hex = "E17"
	var pv0: int = p.pv_totali()
	p.leggi("642", {"hex": "K15"})
	ok(p.s.da_leggere.get("E17", "") == "653" and p.s.punti.get("E17", "") == "Kübelwagen distrutta", "642: Kübelwagen in E17, il 653 si legge entrando")
	ok(p.terreno.tipo_lato("D16", "E17") == "", "642: il muro tra D16 ed E17 è sfondato")
	p._controlla_da_leggere()
	ok(p.pv_totali() == pv0 + 2 and p.s.scelte.has("663") and p.s.scelte.has("677") and p.s.scelte.has("m18resa"), "653: +2 PV, scelte sigaretta / rifiuto / resa")
	p.leggi("673", {"hex": "E17"})
	ok(a.stato == "morto" and not p.s.scelte.has("663"), "673: la Kübelwagen esplode, muore chi è nell’esagono")

	# 599: il Jagdpanther da servire.
	p = _nuova()
	var sq: Array = p.americani()
	p.leggi("621", {"hex": "N15"})
	ok(p.s.punti.get("N14", "") == "Jagdpanther distrutto" and p.s.da_leggere.get("N14", "") == "585", "621: Jagdpanther distrutto in N14")
	sq[0].hex = "N14"
	sq[1].hex = "N14"
	p._controlla_da_leggere()
	ok(p.s.scelte.has("599"), "585: si può esaminare l’interno")
	p.esegui_scelta("599")
	ok(p.jagd_sali(sq[0].id).ok and p.jagd_sali(sq[1].id).ok and sq[0].get("in_jagd", false), "due soldati salgono sul Jagdpanther")
	var cann: Dictionary = {}
	for w in sq[0].armi:
		if w.get("jagd", false) and w.tipo == "cannone":
			cann = w
	ok(not cann.is_empty() and not cann.preparata and int(sq[0].munizioni.cannone) == 4, "cannone scarico, quattro colpi")
	ok(p.prepara(sq[0].id, "cannone").ok and cann.preparata, "si carica il cannone")
	var bers: Dictionary = p._crea_tedesco(19, "N12", "standing")
	var pr: Dictionary = p.probabilita_tiro(sq[0], cann, bers, true)
	ok(pr.ok and pr.mods.any(func(m): return m[0] == "abilità" and int(m[1]) == -1), "cannone verso est con abilità −1 %s" % str(pr))
	var dietro: Dictionary = p._crea_tedesco(25, "N18", "standing")
	ok(not p.probabilita_tiro(sq[0], cann, dietro, true).ok, "nessun tiro fuori dall’arco frontale")
	ok(not p.vede_unita(bers, sq[0]), "il Jagdpanther non è un bersaglio")
	p.s.fase = "operazioni"
	p.risolvi_tiro(sq[0], cann, bers, true)
	ok(int(p.ph.m18.jagd().colpi) == 3 and not cann.preparata, "sparato un colpo: ne restano tre")
	p.jagd_scendi(sq[0].id)
	ok(not sq[0].get("in_jagd", false) and sq[0].armi.all(func(w): return not w.get("jagd", false)), "sceso, il soldato lascia le armi del carro")

	# s8: caduti da perquisire.
	p = _nuova()
	sq = p.americani()
	p.leggi("304", {"hex": "K13"})
	ok(p.s.punti.get("J9", "") == "Semicingolato distrutto" and str(p.s.da_leggere.get("K13", "")) == "310,c18", "304: semicingolato in J9, K13 da perquisire")
	sq[0].hex = "K13"
	p._controlla_da_leggere()
	var oggetti: Array = p.s.oggetti.get("K13", [])
	ok(oggetti.any(func(o): return o.tipo == "mmg") and oggetti.filter(func(o): return o.tipo == "bolt").size() == 1, "310: mitragliatrice media, bazooka, granate; il caduto ha un fucile")

	# 981: munizioni finite.
	p = _nuova()
	var g19: Dictionary = p._crea_tedesco(19, "G2", "standing")
	p.leggi("512", {})
	p.s.round.sparato_prec = [["g19", "bolt"]]
	p.leggi("981", {})
	ok(g19.armi.all(func(w): return w.tipo == "pzf") and g19.reazione == "A", "981: finito il fucile, resta il Panzerfaust e passa alla reazione A")

	# 762: Sherman di rinforzo guidati dai paragrafi.
	p = _nuova()
	sq = p.americani()
	p.leggi("762", {"hex": "K15"})
	var aa: Dictionary = p.u("AA")
	ok(not aa.is_empty() and aa.stato == "fuori" and aa.get("ia_sherman", false) and int(p.s.condizione) == 4 and p.fase_round(), "762: tre Sherman fuori mappa, Condizione 4, Round")
	ok(p.puo_agire(aa) != "", "lo Sherman non è ai tuoi ordini")
	var ing0: String = str(aa.ingresso_18)
	ok(p.ph.m18.cambia_ingresso("AA") != ing0, "si sceglie l’esagono d’ingresso")
	p.s.pausa = ""
	p._avvia_round()
	var giri := 0
	while p.fase_round() and giri < 40 and p.s.fase != "fine":
		giri += 1
		if p.s.pausa != "":
			p.prosegui()
			continue
		var c: Array = p.casella_attuale()
		if c.is_empty():
			break
		if c[1] == "us":
			var attore := {}
			for x in p.americani():
				if int(x.turni) == c[0] and x.slot == "turni" and not x.get("ia_sherman", false):
					attore = x
			if attore.is_empty():
				p._flusso()
				if p.s.pausa == "":
					break
				continue
			p._consuma_turno(attore)
			p._flusso()
		else:
			p._flusso()
		if aa.stato == "attivo":
			break
	ok(aa.stato == "attivo" and aa.hex != "" and p.s.cronaca.any(func(l): return "entra in mappa in" in str(l.get("x", ""))), "al suo turno lo Sherman AA entra dal bordo ovest e segue la carta (%s)" % aa.hex)
	ok(p.ph.round_obbligati(), "si resta nei Round finché c’è uno Sherman attivo")
	p.s.fase = "round"
	p.leggi("312", {})
	ok(not aa.get("ia_sherman", true) or not p.radio_presidiata(), "312/318: con la radio presidiata gli Sherman passano ai tuoi ordini")
	p.u("A").stato = "attivo"
	p.u("A").hex = "K15"
	p.leggi("318", {})
	ok(not aa.get("ia_sherman", false) and p.puo_agire(aa) != "Lo Sherman AA non è ai tuoi ordini: muove e spara secondo i suoi paragrafi.", "318: gli Sherman ai tuoi ordini")

	# Decisione: 306 → 992/994, con la scelta obbligatoria all’inizio del Round.
	p = _nuova()
	p.leggi("703", {})
	p.cambia_condizione(4)
	p.leggi("301", {})
	ok(p.ph.m18.decisione_pendente() and p.s.scelte.has("992") and p.s.scelte.has("994"), "301/306: decisione pendente")
	p.s.pausa = "inizio_round"
	p.prosegui()
	ok(p.s.pausa == "inizio_round", "senza decisione il Round non comincia")
	p.esegui_scelta("994")
	ok(int(p.s.condizione) == 6 and int(p.missione.vittoria_pv) == 30 and not p.s.scelte.has("992"), "994: si ripiega, Condizione 6, 30 PV")
	ok(p.e_uscita("K19"), "dopo l’ordine di ripiegare si esce dal bordo ovest")
	var es: Dictionary = p.americani().filter(func(x): return not x.get("carro_us", false))[0]
	es.hex = "K19"
	es.postura = "standing"
	p.s.pausa = ""
	p.s.fase = "operazioni"
	var pv1: int = p.pv_totali()
	p.esci(es.id)
	ok(p.pv_totali() == pv1 + 2, "+2 PV per chi esce dal bordo ovest")
	for x in p.americani():
		if x.stato == "attivo":
			x.stato = "uscito"
			x.hex = ""
	p._controlla_fine_automatica()
	ok(p.s.fase == "fine", "senza americani in mappa la missione finisce")

	p = _nuova()
	p.leggi("992", {})
	ok(int(p.s.condizione) == 5 and int(p.missione.vittoria_pv) == 36 and p.ph.niente_pv_incapacitati(), "992: si tiene la posizione, 36 PV, niente perdite per gli incapacitati")
	sq = p.americani()
	sq[0].hex = "K5"
	p.s.fase = "operazioni"
	p._controlla_fine_automatica()
	ok(p.s.fase == "fine" and p.s.fine.righe.any(func(r): return "a est del fiume" in str(r[0])), "senza tedeschi attivi finisce: 1 PV per chi è a est del fiume")

	# Granatiere con il Panzerfaust contro lo Sherman entro 3 esagoni.
	p = _nuova()
	p.leggi("762", {"hex": "K15"})
	var bb: Dictionary = p.u("BB")
	bb.stato = "attivo"
	bb.hex = "K16"
	p.veicoli.di(bb).hex = "K16"
	p.veicoli.di(bb).erase("fuori_mappa_ph")
	var gr: Dictionary = p._crea_tedesco(25, "K14", "standing")
	p.ia._g = gr
	p.ia._mp = 4
	var prima: int = gr.armi.filter(func(w): return w.tipo == "pzf").size()
	for hx in E.tutti():
		if E.distanza(hx, "K16") == 2 and p.terreno.vede(hx, "K16", "crouching", "crouching") and p.terreno.costo_movimento(hx, hx) != -2:
			gr.hex = hx
			break
	p.ia.esegui(806)
	ok(prima == 1 and gr.armi.filter(func(w): return w.tipo == "pzf").is_empty(), "806: il granatiere spara il Panzerfaust allo Sherman (vede %s, dist %d)" % [str(p.vede_unita(gr, bb)), E.distanza(gr.hex, bb.hex)])

	print("Errori: %d" % errori)
	quit(errori)
