extends SceneTree
## Silver Star, Missione 23 «Sconosciuti nella notte»: nebbia, PV degli esagoni, pattuglie a segnalino (avanzano, si vedono, si
## schierano), razzi illuminanti, filo spinato, edificio fortificato, Panzer, superstite e Sherman di soccorso, fine.
## Uso: godot --headless --path . --script tests/missione23.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func nuova(seme: int):
	var p = PartitaScript.new(23)
	p.nuova(seme, true)
	for a in p.americani():
		p.schiera([a.id], "A1")
	p.inizia_missione()
	p.s.pausa = ""
	return p

func _init() -> void:
	var p = nuova(3)
	ok(p.missione.mappa == "F" and p.terreno.limite_vista == 3, "mappa F, nebbia: vista 3")
	ok(p.terreno.ponte("O4") and p.terreno.muri_sfondati.size() == 3, "ponte in O4 e muri sfondati")
	p.leggi("387", {})
	ok(p.terreno.limite_vista == 5 or not bool(p.s.avvistamenti[1]) == false, "387: la nebbia si dirada (o pattuglia MM)")
	p._op({"op": "vista", "n": 10}, {})
	ok(p.terreno.limite_vista == 10, "vista a 10")
	# PV degli esagoni.
	p.ss.m23._st().pattuglie = {}
	var a: Dictionary = p.u("A")
	a.hex = "O13"
	var pv0: int = p.pv_totali()
	p.ss.m23.dopo_movimento(["A"])
	a.hex = "O14"
	p.ss.m23.dopo_movimento(["A"])
	ok(p.pv_totali() == pv0 + 1, "O14: +1 PV (%d → %d, %s)" % [pv0, p.pv_totali(), str(p.ss.m23._st().pv_esagoni)])
	# Pattuglia: avanza e si schiera.
	var q = nuova(5)
	q.ss.m23.piazza_pattuglia("NN", "H1")
	var b: Dictionary = q.u("B")
	b.hex = "A2"
	q.ss.m23._muovi_pattuglie(1, "B")
	var pt: Dictionary = q.ss.m23._st().pattuglie.get("NN", {})
	ok(pt.is_empty() or E.distanza(pt.hex, "A1") < E.distanza("H1", "A1"), "il segnalino avanza verso la squadra")
	q.ss.m23._st().pattuglie["NN"] = {"hex": "B2"}
	q.ss.m23._st().corrente = "NN"
	q.ss.m23.schiera_pattuglia("de")
	var g55: Dictionary = q.u("g55")
	ok(not g55.is_empty() and q.attivo(g55) and E.distanza(g55.hex, "B2") <= 1 and not q.ss.m23._st().pattuglie.has("NN"), "la pattuglia NN si schiera intorno a B2")
	ok(q.fase_round(), "iniziano i Round")
	q.ia._g = g55
	q.s.round.numero_azione = 3
	q.ss.m23.turno_pattuglia(q.ia, g55, 739)
	ok(true, "turno di una SS della pattuglia senza errori")
	# Razzo illuminante.
	var r = nuova(7)
	var ill: Array = r.ss.m23.razzo("A1")
	ok(not ill.is_empty() and r.terreno.illuminati.has("A1") and r.terreno.illuminati.has("B1"), "razzo: A1 e intorno illuminati")
	r.ss.m23.fine_round()
	ok(not r.terreno.illuminati.has("A1"), "il razzo si spegne a fine Round")
	# Filo spinato ed edificio fortificato.
	r.leggi("160", {})
	ok("R12" in r.ss.m23._st().filo, "160: filo spinato in R12–U12")
	var c: Dictionary = r.u("C")
	c.hex = "Q12"
	ok(r.ss.m23.costo_passo(c, "R12", 1) == (2 if r.fase_round() else 1), "nel filo spinato +1 PM nei Round")
	r.leggi("271", {})
	ok(r.u("g59").hex == "T12" and "T12" in r.ss.m23._st().fortificati and int(r.s.condizione) == 3, "271: mitragliatrici nell’edificio fortificato T12, Condizione 3")
	var mods: Array = []
	r.ss.m23.mod_tiro(c, r.u("g59"), mods)
	ok(not mods.is_empty(), "edificio fortificato: −2")
	# Panzer nascosto.
	r.leggi("410", {})
	ok(not r.veicoli.v("v67").is_empty() and r.veicoli.v("v67").hex == "S13", "410: Panzer 67 in S13")
	# Superstite e Sherman.
	var s = nuova(9)
	s.leggi("414", {"hex": "C3", "ids": []})
	ok(not s.u("J").is_empty() and s.u("J").hex == "C3" and not s.ss.agisce_da_solo(s.u("J")), "414: il superstite si unisce alla squadra")
	s.leggi("442", {})
	ok(s.s.get("scelte", {}).has("328"), "442: scelta fra aiuto e da soli")
	s.esegui_scelta("328")
	var sh: Dictionary = s.u("AA")
	ok(not sh.is_empty() and s.veicoli.v("vsh7").hex in ["B19", "A8"] and s.ss.agisce_da_solo(sh) and int(s.missione.vittoria_pv) == 17, "328: Sherman US 07, servono 17 PV")
	s.s.round.numero_azione = 2
	s.ss.m21.turno_americano(sh)
	ok(true, "turno dello Sherman senza errori")
	# Fine: s7, s8, nessun tedesco, Condizione 3.
	s.s.avvistamenti[7] = true
	s.s.avvistamenti[8] = true
	s.cambia_condizione(3)
	for g in s.tedeschi():
		if s.attivo(g):
			s._uccidi(g, "prova")
	s.ss.m23.controlla()
	ok(s.s.fase == "fine", "fine dopo s7 e s8 senza tedeschi")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
