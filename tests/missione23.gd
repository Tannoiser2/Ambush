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
	ok(r.s.bunker.has("T12") and r.s.bunker.T12.fortificato, "271: il fortificato usa le aperture e la tabella dei colpi (517)")
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
	# 388: chi ha fallito il 492 spara per errore al superstite.
	var er = nuova(31)
	er.s.fase = "operazioni"
	er.ss.m23.piazza_pattuglia("MM", "O14")
	er.ss.m23._st().corrente = "MM"
	er.ss.m23._st().falliti_492 = ["A", "B"]
	er.u("A").hex = "O16"
	er.u("B").hex = "O16"
	var pv_er: int = er.pv_totali()
	er.leggi("388", {"hex": "O16", "ids": []})
	var jj: Dictionary = er.u("J")
	ok(not jj.is_empty() and jj.hex == "O14", "388: il superstite compare nell’esagono del segnalino (%s)" % jj.get("hex", ""))
	ok(jj.stato != "morto" or er.pv_totali() <= pv_er - 4, "388: se muore si perdono 4 PV (%d)" % (er.pv_totali() - pv_er))
	# 517: edificio fortificato con finestre su tutti i lati e tabella dei colpi; distrutto +2 PV.
	var fo = nuova(33)
	fo.s.fase = "operazioni"
	fo.ss.m23.op({"op": "ss23_fortificato", "hex": "R13", "porta": "R14"}, {})
	ok(fo.s.bunker.has("R13") and fo.s.bunker.R13.fortificato and fo.terreno.tipo_lato("R13", "Q13") == "window", "517: fortificato in R13, lati come finestre")
	var pv_fo: int = fo.pv_totali()
	var att: Dictionary = fo.u("A")
	var baz: Dictionary = {"tipo": "bazooka", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false}
	var giri := 0
	while not fo.s.bunker.R13.distrutto and giri < 60:
		fo._colpo_bunker(att, baz, "R13", fo.s.bunker.R13)
		giri += 1
	ok(fo.s.bunker.R13.distrutto and fo.s.modifiche.get("R13", "") == "rubble" and fo.pv_totali() >= pv_fo + 2, "517: distrutto, macerie e +2 PV (%d colpi)" % giri)
	# 300 sulla mappa F: il Panzer in S13 è in un edificio.
	var pz23 = nuova(32)
	pz23.s.fase = "operazioni"
	pz23.leggi("411", {})
	var v67: Dictionary = pz23.veicoli.v("v67")
	ok(v67.is_empty() or pz23.veicoli.in_edificio(v67), "300: il Panzer in S13 è in un edificio")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
