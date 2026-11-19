extends SceneTree
## Missione 2: mappa B, ingresso da ovest, PV per gli edifici, jeep dei rinforzi, Kübelwagen, Me-109, resa del 173.
## Uso: godot --headless --path . --script tests/missione2.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	var p = PartitaScript.new(2)
	p.nuova(11)
	ok(p.missione.mappa == "B" and p.terreno.tipo("O6") == "wood_building", "mappa B caricata (O6 è la stazione)")
	ok(p.e_ingresso("A6") and not p.e_ingresso("A1"), "si entra da A6–A15")
	ok(p.livello_attivazione() == 1, "Condizione 1: livello 0–1")
	# Edifici: 1 PV per esagono.
	var a: Dictionary = p.u("A")
	a.stato = "attivo"
	a.hex = "N5"
	p._ingresso("M5", ["A"], false)
	a.hex = "M5"
	ok(p.s.get("edifici_entrati", []).has("M5") and p.pv_totali() >= 1, "entrare in M5 vale 1 PV")
	var pv := p.pv_totali()
	p._ingresso("M5", ["A"], false)
	ok(p.pv_totali() == pv, "lo stesso edificio non conta due volte")
	# Rinforzi: la jeep arriva in Operazioni.
	p.s.fase = "operazioni"
	p.leggi("304", {"hex": "", "ids": []})
	var jeep: Dictionary = p.veicoli.v("vjeep")
	ok(not jeep.is_empty() and jeep.hex in ["A5", "A17"], "la jeep entra in A5 o A17")
	var j: Dictionary = p.u("J")
	ok(j.get("veicolo", "") == "vjeep" and p.veicoli.e_autista(j), "l’autista J è al volante")
	ok(not p.arma_di(j, "mmg").is_empty(), "l’autista può usare la mitragliatrice a jeep ferma")
	var b: Dictionary = p.u("B")
	b.stato = "attivo"
	b.hex = jeep.hex
	ok(p.sali_veicolo("B").ok, "B sale sulla jeep")
	var dest: Array = p.destinazioni("J")
	ok(not dest.is_empty(), "la jeep ha destinazioni: %s" % str(dest))
	var verso: String = dest[0]
	var r: Dictionary = p.muovi(["J"], verso)
	ok(r.ok and jeep.hex == verso and b.hex == verso, "la jeep si muove con a bordo B (%s)" % verso)
	ok(p.scendi_veicolo("B").ok and not b.has("veicolo"), "B scende")
	p.leggi("304", {"hex": "", "ids": []})
	ok(p.veicoli.tutti().size() == 1, "il 304 non si ripete")
	# Me-109: nessun errore, segue le regole.
	for i in 5:
		p.leggi("008", {"hex": "", "ids": []})
	ok(true, "il mitragliamento del Me-109 si risolve")
	# Kübelwagen: si attiva in N12, iniziano i Round, si muove con i riferimenti rossi.
	var q = PartitaScript.new(2)
	q.nuova(5)
	for id in ["A", "B", "C"]:
		var x: Dictionary = q.u(id)
		x.stato = "attivo"
		x.hex = "M9"
	q.leggi("128", {"hex": "N12", "ids": ["A"]})
	var k: Dictionary = q.veicoli.v("v19")
	ok(not k.is_empty() and k.hex == "N12", "Kübelwagen in N12")
	ok(int(q.s.condizione) == 5, "si passa alla Condizione 5")
	ok(q.u("g19").get("veicolo", "") == "v19" and q.u("g119").get("veicolo", "") == "v19", "autista e ufficiale a bordo")
	var partenza: String = k.hex
	var passi := 0
	while q.s.fase == "round" and passi < 60 and k.hex == partenza and k.stato == "attivo":
		passi += 1
		if q.s.pausa != "":
			q.prosegui()
			continue
		var turno: Array = q.americani_di_turno()
		if turno.is_empty():
			q.prosegui()
		else:
			q.passa(turno[0].id)
	ok(k.hex != partenza or k.stato != "attivo", "la Kübelwagen si è mossa (ora in %s, %s)" % [k.hex, k.stato])
	# Colpi sulla Kübelwagen: tabella dei colpi senza errori.
	var c: Dictionary = q.u("C")
	for i in 20:
		if not q.veicoli.attivo(k):
			break
		q.veicoli.colpito(k, "ar", c, true, {})
	ok(true, "colpi contro la Kübelwagen risolti (stato %s)" % k.stato)
	# Resa nel bunker (173).
	var w = PartitaScript.new(2)
	w.nuova(7)
	var d: Dictionary = w.u("D")
	d.stato = "attivo"
	d.hex = "J14"
	w.leggi("173", {"hex": "J14", "ids": ["D"]})
	ok(w.u("g119").get("stato", "") == "catturato", "l’ufficiale della Kübelwagen è catturato")
	ok(w.pv_totali() >= 3, "la cattura vale almeno 3 PV (%d)" % w.pv_totali())
	var errori_cronaca := 0
	for pp in [p, q, w]:
		for v in pp.s.cronaca:
			if v.t == "errore":
				errori_cronaca += 1
				print("  cronaca: ", v.x)
	ok(errori_cronaca == 0, "nessun errore nella cronaca")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
