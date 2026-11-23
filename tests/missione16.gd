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
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
