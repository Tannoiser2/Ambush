extends SceneTree
## Missione 5: guadi, documenti da portare fuori, installazioni da far saltare, V-2, auto comando con scienziati.
## Uso: godot --headless --path . --script tests/missione5.gd

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
		else:
			q.passa(turno[0].id)

func _init() -> void:
	var p = PartitaScript.new(5)
	p.nuova(5)
	ok(p.livello_attivazione() == 1, "Condizione 1: livello 0–1")
	ok(p.e_ingresso("A12") and p.e_ingresso("L19") and not p.e_ingresso("M19") and not p.e_ingresso("A11"), "ingresso A12–L19")
	ok(not p.arma_di(p.u("F"), "satchel").is_empty() and not p.arma_di(p.u("H"), "satchel").is_empty(), "due cariche da demolizione")
	# Guado.
	ok(p.terreno.costo_movimento("G6", "G7") < 0 or p.terreno.tipo("G7") != "stream", "senza guado il fiume non si attraversa")
	p.leggi("044", {"hex": "", "ids": []})
	ok(p.terreno.guado("G7") and p.s.punti.get("G7", "") == "guado", "044 rivela il guado in G7")
	var vicino := ""
	for v in p.E.vicini("G7"):
		if p.terreno.tipo(v) != "stream" and not p.terreno.edificio(v):
			vicino = v
	ok(p.terreno.tipo("G7") != "stream" or p.terreno.costo_movimento(vicino, "G7") >= 0, "dal guado si entra nel fiume (%s→G7)" % vicino)
	# Documenti.
	var a: Dictionary = p.u("A")
	a.stato = "attivo"
	a.hex = "K7"
	p.s.fase = "operazioni"
	p.leggi("133", {"hex": "K7", "ids": ["A"]})
	ok(int(a.get("documenti", 0)) == 1 and p.pv_totali() == 0, "i documenti non valgono finché non escono")
	a.hex = "A14"
	a.postura = "standing"
	ok(p.esci("A").ok and p.pv_totali() == 1, "uscendo con i documenti si prende 1 PV")
	# Installazioni.
	var f: Dictionary = p.u("F")
	f.stato = "attivo"
	f.hex = "R6"
	p.leggi("635", {"hex": "", "ids": []})
	ok(p.s.installazioni.has("S6"), "rampa in S6")
	ok(p.installazioni_vicine(f) == ["S6"], "F è accanto alla rampa con la carica")
	var pv: int = p.pv_totali()
	ok(p.demolisci("F", "S6").ok and p.pv_totali() == pv + 2, "la rampa salta: +2 PV")
	# V-2.
	var h: Dictionary = p.u("H")
	h.stato = "attivo"
	h.hex = "S12"
	p.leggi("487", {"hex": "", "ids": []})
	var g: Dictionary = p.u("G")
	g.stato = "attivo"
	g.hex = "S15"
	p.demolisci("H", "S13")
	ok(p.s.modifiche.get("S13", "") == "rubble" and p.s.modifiche.get("S14", "") == "rubble", "il V-2 esplode: S13 e S14 in macerie")
	ok(errori_cronaca(p).is_empty(), "nessun errore (documenti e installazioni)")
	# Auto comando e scienziati.
	var q = PartitaScript.new(5)
	q.nuova(6)
	for id in ["A", "B", "C"]:
		var x: Dictionary = q.u(id)
		x.stato = "attivo"
		x.hex = "P12"
	q.leggi("992", {"hex": "", "ids": []})
	ok(not q.veicoli.v("v13").is_empty() and q.u("g13").get("veicolo", "") == "v13", "l’auto comando entra in Y8 con l’autista")
	gioca_round(q, 400)
	ok(errori_cronaca(q).is_empty(), "auto comando senza errori (auto in %s)" % str(q.veicoli.v("v13").get("hex", "")))
	q.leggi("037", {"hex": "S15", "ids": [], "g": "g13", "veicolo": true})
	ok(not q.u("g24").is_empty() and not q.u("g42").is_empty(), "037: compaiono gli scienziati in S14")
	gioca_round(q, 300)
	ok(errori_cronaca(q).is_empty(), "scienziati senza errori")
	for chiave in ["072", "461", "485", "623", "045", "645"]:
		q.leggi(chiave, {"hex": "", "ids": []})
	ok(errori_cronaca(q).is_empty(), "eventi una tantum senza errori")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
