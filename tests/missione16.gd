extends SceneTree
## Missione 16 (Purple Heart): schieramento, battelli d’assalto, esplosivi, deposito.
const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")
var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	var p = PartitaScript.new(16)
	p.nuova(16, true)
	ok(p.lettera_mappa() == "C" and p.ph.attiva(), "mappa C, libro Purple Heart")
	ok(p.terreno.limite_vista == 6 and p.terreno.fiume, "notte di luna (6 esagoni) e fiume")
	var sq: Array = p.americani()
	ok(not p.schiera([sq[0].id], "V13").ok, "nel deposito non si schiera")
	p.schiera([sq[0].id, sq[1].id], "B2")
	ok(not p.inizia_missione().ok, "servono due soldati per angolo")
	p.schiera([sq[2].id, sq[3].id], "B18")
	p.schiera([sq[4].id, sq[5].id], "X2")
	p.schiera([sq[6].id, sq[7].id], "X18")
	for i in range(8, sq.size()):
		p.schiera([sq[i].id], "S12")
	ok(p.inizia_missione().ok, "schieramento valido, la missione comincia")
	# 407: commando in battello in L1, il secondo battello al Round successivo.
	p.leggi("407", {"hex": "B2", "ids": []})
	var g20: Dictionary = p.u("g20")
	ok(str(g20.get("barca", "")) != "" and g20.hex == "L1", "407: i commando sono in un battello in L1")
	ok(int(g20.get("esplosivi", 0)) == 1, "ogni commando ha un esplosivo")
	ok(p.s.ph.pendenti.size() == 1 and str(p.s.ph.pendenti[0].p) == "421", "421 rimandato al prossimo Round")
	# Il battello si muove seguendo i riferimenti rossi della Condizione 2.
	p.s.condizione = 2
	var bid: String = g20.barca
	var da: String = p.s.ph.barche[bid].hex
	p.ia._g = g20
	p.ia._mp = 4
	p.ia.ph._muovi_barca(g20)
	var ora: String = p.s.ph.barche[bid].hex
	ok(ora != da and g20.hex == ora and p.u("g21").hex == ora, "il battello si sposta con tutti a bordo (%s → %s)" % [da, ora])
	ok(p.ia.ph.barca_gia_mossa(g20), "una sola mossa per turno")
	# Sbarco.
	p.ia._g = g20
	p.ia.ph.sbarca(g20)
	ok(str(g20.get("barca", "")) == "" and g20.hex != ora and g20.postura == "prone", "531: il tedesco sbarca prono in %s" % g20.hex)
	# Esplosivo: piazzato da fermo, non dopo essersi mosso.
	var g21: Dictionary = p.u("g21")
	g21.erase("barca")
	g21.hex = "V13"
	p.ia._g = g21
	p.ia._mp = 1
	p.ph.op({"op": "pianta_esplosivo"}, {"g": "g21"})
	ok(p.ph.esplosivo("V13") == 0, "chi si è già mosso non piazza")
	p.ia._mp = int(p.effettivo_mpa(g21))
	p.ph.op({"op": "pianta_esplosivo"}, {"g": "g21"})
	ok(p.ph.esplosivo("V13") == 2 and int(g21.esplosivi) == 0, "piazzato l’esplosivo in V13 (lato 2)")
	ok(p.ph.blocca_fine(), "con un esplosivo in mappa la missione non finisce")
	# Disinnesco in due azioni.
	var a: Dictionary = sq[8] if sq.size() > 8 else sq[0]
	a.hex = "V13"
	ok(p.ph.disinnesca(a) == "" and p.ph.esplosivo("V13") == 1, "prima azione: lato 1")
	var pv0: int = p.punti_vittoria() if p.has_method("punti_vittoria") else 0
	ok(p.ph.disinnesca(a) == "" and p.ph.esplosivo("V13") == 0, "seconda azione: disinnescato")
	ok(not p.ph.blocca_fine(), "nessun esplosivo: si può finire")
	# Esplosione nel deposito.
	g21.hex = "W14"
	p.ph.esplodi("W14")
	ok("W14" in p.s.ph.deposito_distrutto and g21.stato == "morto", "l’esplosione distrugge W14 e uccide chi c’è")
	var righe: Array = []
	var b: int = p.ph.righe_fine(righe)
	ok(b == 8 - 2, "PV del deposito: 8 intatti − 2 = %d" % b)
	_semplificazioni()
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)


## Regole che nelle prime versioni erano semplificate: due jeep, allerta, soldato J, camion, battelli colpiti, deposito in fiamme.
func _semplificazioni() -> void:
	var p = PartitaScript.new(16)
	p.nuova(5, true)
	var sq: Array = p.americani()
	for c in [["B2", 0], ["B18", 2], ["X2", 4], ["X18", 6]]:
		p.schiera([sq[c[1]].id, sq[c[1] + 1].id], str(c[0]))
	p.inizia_missione()
	ok(not p.veicoli.v("vjeep").is_empty() and not p.veicoli.v("vjeep2").is_empty(), "due jeep della squadra")
	# 501: il soldato J e i commando
	p.leggi("501", {"hex": "V13", "ids": []})
	var j: Dictionary = p.u("J")
	ok(not j.is_empty() and j.hex == "V12" and j.postura == "standing" and j.consapevole, "501: la guardia del deposito J in V12")
	p.s.round.n = 1
	ok(p.in_comando(j), "J è in comando nel Round 1")
	p.s.round.n = 2
	ok(p.in_comando(sq[0]), "in allerta: nel secondo Round tutti in comando")
	p.s.round.n = 3
	# battello colpito: con penetrazione media o pesante affonda con gli occupanti
	var g20: Dictionary = p.u("g20")
	p.s.ph.barche["bx"] = {"hex": "U11", "mossa": ""}
	g20.barca = "bx"
	g20.hex = "U11"
	p.ph.affonda_barca("bx", false, "prova")
	ok(not p.s.ph.barche.has("bx") and str(g20.get("barca", "")) == "" and g20.postura == "prone", "il battello affonda: il tedesco raggiunge la riva (%s)" % g20.hex)
	# camion del carburante
	p.s.fase = "operazioni"
	p.s.pausa = ""
	p.leggi("717", {"hex": "A3"})
	var t1: Dictionary = p.u("T1")
	var v1: Dictionary = p.veicoli.di(t1)
	ok(not t1.is_empty() and v1.modello == "camion" and v1.hex == "A3", "717: il primo camion entra in A3")
	ok(p.veicoli.sali(sq[0], v1) != "" and not p.scendi_veicolo(t1.id).ok, "nessuno sale sul camion e l’autista non scende")
	v1.hex = "U14"
	t1.hex = "U14"
	ok(p.carica_camion(t1.id).ok and v1.carico, "nelle Operazioni il camion si carica in U14")
	v1.hex = "A3"
	t1.hex = "A3"
	var pv0: int = p.pv_totali()
	p.s.pausa = ""
	ok(p.esci(t1.id).ok and p.pv_totali() == pv0 + 2 and not p.u("T2").is_empty(), "esce carico da A3: +2 PV, entra il secondo camion")
	p.veicoli.disabilita(p.veicoli.di(p.u("T2")), "prova")
	ok(p.pv_totali() == pv0 and not p.u("T3").is_empty(), "il secondo camion messo fuori uso: −2 PV, entra il terzo")
	# deposito in fiamme
	p.ph.esplodi("V13")
	var x: Dictionary = sq[2]
	x.hex = "W12"
	for v in E.vicini("V13"):
		if p.terreno.costo_movimento(v, "V13") >= 0 and not (v in p.ph.deposito()):
			x.hex = v
			break
	x.postura = "standing"
	x.stato = "attivo"
	p.s.fase = "operazioni"
	p.s.pausa = ""
	var r: Dictionary = p.muovi([x.id], "V13")
	ok(r.ok and (x.stato == "morto" or (x.hex != "V13" and x.postura == "prone")), "414.2: chi entra nel deposito in fiamme muore o passa oltre, prono (%s, %s)" % [x.stato, x.hex])
