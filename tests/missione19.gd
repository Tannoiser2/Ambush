extends SceneTree
## Silver Star, Missione 19 «Fradici»: canoe con i sommozzatori aggrappati, sgancio (787), nuoto e immersione, vista
## sott’acqua, −4 contro i nuotatori, chiatte ed esplosivi a tempo, barche di guardia, camion dei rinforzi, fine (789).
## Uso: godot --headless --path . --script tests/missione19.gd

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

func nuova(seme: int):
	var p = PartitaScript.new(19)
	p.nuova(seme, true)
	for id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
		p.schiera([id], "A1")
	p.inizia_missione()
	return p

func _init() -> void:
	var p = nuova(3)
	ok(p.missione.libro == "ss" and p.missione.mappa == "FH" and p.terreno.limite_vista == 3, "mappa F con H, notte (vista 3)")
	ok(p.paragrafi.has("787") and p.paragrafi["787"].it.begins_with("[s9]"), "paragrafi Silver Star caricati")
	ok(p.paragrafi["801"].it == JSON.parse_string(FileAccess.get_file_as_string("res://data/paragrafi.json"))["801"].it, "le azioni 800–869 restano quelle base")
	var c1: Dictionary = p.veicoli.v("canoa1")
	var c2: Dictionary = p.veicoli.v("canoa2")
	ok(not c1.is_empty() and not c2.is_empty() and p.veicoli.v("canoa3").is_empty(), "due canoe")
	ok(p.veicoli.occupanti(c1).size() == 4 and p.veicoli.occupanti(c2).size() == 4, "due rematori e due sommozzatori per canoa")
	ok(p.u("E").get("aggrappato", false) and p.u("E").sub and p.u("A").coltello_ss and int(p.u("F").esplosivi_ss) == 1, "sommozzatori, coltelli, esplosivi")
	ok(p.ss.in_acqua(p.u("E")) and not p.ss.in_acqua(p.u("A")), "chi è aggrappato è in acqua, chi rema no")
	ok(not p.muovi(["E"], "B1").ok, "l’aggrappato non nuota da solo")
	# La canoa avanza lungo la riga 1 con i sommozzatori.
	p.s.fase = "operazioni"
	var guida: Dictionary = p.veicoli.autista(c1)
	var r: Dictionary = p.muovi([guida.id], "B1")
	ok(r.ok and c1.hex == "B1" and p.u("E").hex == "B1" and p.u("F").hex == "B1", "la canoa porta con sé i sommozzatori (%s)" % str(r))
	ok(not p.muovi([guida.id], "B2").ok, "le canoe non sbarcano a sud della colonna N")
	# 787: il comandante sgancia i sommozzatori.
	p.leggi("787", {"hex": "D1", "ids": []})
	ok(not p.u("E").get("aggrappato", false) and str(p.u("E").get("veicolo", "")) == "" and p.u("E").hex == "B1", "787: i sommozzatori si staccano")
	ok(p.veicoli.occupanti(c1).size() == 2, "in canoa restano i due rematori")
	# Nuoto: 2 PM per esagono d’acqua; i sommozzatori non salgono a terra prima del 789.
	ok(p._costo_passo(p.u("E"), "B1", "C1") == 2, "nuotare costa 2 PM per esagono")
	ok(not p.muovi(["E"], "B2").ok, "il sommozzatore resta in acqua prima del 789")
	ok(p.cambia_postura("E", "prone").ok and p.ss.sott_acqua(p.u("E")), "si immerge (cambio di postura gratuito)")
	ok(not p.cambia_postura("A", "prone").ok or not p.ss.in_acqua(p.u("A")), "chi è in canoa non si immerge")
	r = p.muovi(["E"], "C1")
	ok(r.ok and p.u("E").hex == "C1", "sott’acqua si nuota anche da proni (%s)" % str(r))
	ok(not p.cambia_postura("E", "crouching").ok, "in acqua niente accovacciati")
	# Vista sott’acqua e −4 contro i nuotatori.
	var g = p._crea_tedesco(54, "E1", "crouching")
	ok(not p.vede_unita(g, p.u("E")), "chi è sott’acqua non si vede da due esagoni")
	g.hex = "C2"
	ok(p.vede_unita(g, p.u("E")), "da un esagono adiacente sì")
	ok(not p.probabilita_tiro(p.u("E"), p.u("E").armi[0], g, false).ok, "sott’acqua non si spara")
	p.cambia_postura("E", "standing")
	var pr: Dictionary = p.probabilita_tiro(g, g.armi[0], p.u("E"), true)
	ok(pr.ok and pr.mods.any(func(m): return int(m[1]) == -4), "−4 contro il nuotatore (%s %s)" % [str(pr), p.u("E").postura])
	ok(not p.probabilita_tiro(p.u("E"), p.u("E").armi[0], g, true).ok and p.probabilita_tiro(p.u("E"), p.u("E").armi[0], g, false).ok, "in acqua solo tiro rapido")
	g.stato = "rimosso"
	g.hex = ""
	# Chiatte ed esplosivi a tempo.
	p._op({"op": "ss_chiatte", "dispari": ["C3"], "pari": ["C3"]}, {})
	p.leggi("237", {})
	var ch: Dictionary = p.ss.chiatta_in("C3")
	ok(not ch.is_empty(), "chiatta in C3")
	p.u("F").hex = "C3"
	ok(p.ss.puo_esplosivo(p.u("F")), "il sommozzatore può applicare l’esplosivo")
	var pv0: int = p.pv_totali()
	ok(p.ss.piazza_esplosivo(p.u("F")) == "" and int(p.u("F").esplosivi_ss) == 0, "esplosivo applicato")
	p.u("F").hex = "B1"
	var scoppiata := false
	for i in 4:
		p.ss.dopo_mossa_operazioni()
	scoppiata = ch.stato == "distrutto"
	ok(scoppiata or p.s.ss.esplosivi.is_empty(), "l’esplosivo salta (o fa cilecca) dopo due mosse")
	if scoppiata:
		ok(p.pv_totali() == pv0 + 3, "chiatta distrutta: +3 PV")
	# Barca di guardia: crea, colpi, eliminazione.
	var b = PartitaScript.new(19)
	b.nuova(5, true)
	b.s.fase = "operazioni"
	b._op({"op": "ss_barca_guardia", "g": 60, "hex": "C7"}, {})
	var gb: Dictionary = b.u("g60")
	ok(not gb.is_empty() and gb.barca_ss and int(gb.equip_ss) == 3 and int(gb.munizioni.granata) == 99, "barca di guardia 60 in C7")
	ok(b.fase_round(), "la barca attiva i Round")
	for i in 20:
		if not b.attivo(gb):
			break
		b.ss._colpita_barca(gb, "smg", {}, {})
	ok(not b.attivo(gb), "colpita più volte la barca è eliminata")
	# Camion dei rinforzi.
	var t = PartitaScript.new(19)
	t.nuova(7, true)
	t.s.fase = "operazioni"
	t.leggi("429", {})
	var cam: Dictionary = t.veicoli.v("camion_ss")
	ok(not cam.is_empty() and cam.hex == "Y4" and t.veicoli.occupanti(cam).size() == 6, "camion in Y4 con i tedeschi 10–15")
	ok(t.u("g10").reazione == "T" and t.fase_round(), "reazione speciale T, iniziano i Round")
	# Fine: 789, poi tutti in acqua a sud della colonna G.
	var f = PartitaScript.new(19)
	f.nuova(9, true)
	for id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
		f.schiera([id], "A1")
	f.inizia_missione()
	f.s.fase = "operazioni"
	f.leggi("787", {})
	f.leggi("789", {})
	ok(int(f.s.condizione) == 2 and f.s.ss.fine_789, "789: Condizione 2")
	f._controlla_fine_automatica()
	ok(f.s.fase == "fine", "tutti in acqua in A1 senza tedeschi attivi: la missione finisce (%s)" % f.s.fase)
	errori_cronaca(p)
	errori_cronaca(t)
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
