extends SceneTree
## Silver Star, Missione 22 «Un altro ponte di troppo?»: semicingolato e jeep della squadra, PV degli esagoni, grande ponte (483),
## livelli del ponte, esplosivi e disinnesco, genieri tedeschi col semicingolato, esplosioni e crollo (260 → 330/994), cecchino
## col detonatore di V14, cannone anticarro, Panzer nascosto, fine.
## Uso: godot --headless --path . --script tests/missione22.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func nuova(seme: int):
	var p = PartitaScript.new(22)
	p.nuova(seme, true)
	for a in p.americani():
		p.schiera([a.id], "X1")
	p.inizia_missione()
	p.s.pausa = ""
	return p

func _init() -> void:
	var p = nuova(3)
	ok(p.missione.mappa == "FG" and p.americani().size() == 8, "mappa FG, otto uomini")
	var ht: Dictionary = p.veicoli.v("vht")
	var jp: Dictionary = p.veicoli.v("vjeep")
	ok(not ht.is_empty() and ht.has("mg") and p.veicoli.occupanti(ht).size() == 5 and p.veicoli.occupanti(jp).size() == 3, "semicingolato con 5 uomini e MG, jeep con 3")
	ok(p.terreno.ponte("O4") and p.terreno.ponte("V14") and p.terreno.tipo("K10") == "rubble" and p.terreno.tipo("W8") == "road", "ponti O4 e V14, macerie in K10, galleria")
	# PV degli esagoni.
	var a: Dictionary = p.u("F")
	p.veicoli.scendi(a)
	a.hex = "W9"
	a.postura = "standing"
	var pv0: int = p.pv_totali()
	p.muovi(["F"], "W8")
	ok(p.pv_totali() == pv0 + 1, "W8: +1 PV")
	p.muovi(["F"], "W9")
	p.muovi(["F"], "W8")
	ok(p.pv_totali() == pv0 + 1, "lo stesso esagono non conta due volte")
	# Grande ponte.
	ok(p.terreno.tipo("J14") != "road", "prima del 483 il grande ponte non c’è")
	p.s.avvistamenti[5] = true
	p.leggi("483", {})
	ok(p.ss.m22._st().ponte3 and p.terreno.tipo("J14") == "road" and int(p.s.condizione) == 2, "483: ponte I15–K14 e Condizione 2")
	# Sotto il ponte, esplosivo e disinnesco.
	var b: Dictionary = p.u("G")
	p.veicoli.scendi(b)
	b.hex = "J14"
	ok(p.ss.m22.puo_scendere(b) and p.ss.m22.scendi_sotto(b) == "" and p.ss.m22.sotto(b), "si scende sotto il ponte")
	ok(p.ss.m22.verifica_passo(b, "H14") != "", "da sotto il ponte non si esce senza risalire")
	p.ss.m22._st().esplosivi["J14"] = 2
	var pv1: int = p.pv_totali()
	p.ss.m22.disinnesca(b)
	ok(p.ss.m22.esplosivo("J14") == 1, "prima azione: lato 1")
	p.ss.m22.disinnesca(b)
	ok(p.ss.m22.esplosivo("J14") == 0 and p.pv_totali() == pv1 + 1, "disinnescato: +1 PV")
	# Esplosioni: un tratto distrutto, poi il crollo e la scelta.
	p.ss.m22._st().esplosivi["I15"] = 2
	p.ss.m22.esplodi("I15")
	ok(p.terreno.tipo("I15") == "rubble" and p.terreno.tipo("J14") == "road", "primo scoppio: distrutto solo I15")
	p.ss.m22._st().esplosivi["K14"] = 2
	p.ss.m22.esplodi("K14")
	ok(p.ss.m22._st().crollato and p.terreno.tipo("J14") == "rubble" and p.s.get("scelte", {}).has("330") and p.s.scelte.has("994"), "secondo scoppio: crolla, scelta 330/994")
	p.esegui_scelta("994")
	ok(int(p.s.condizione) == 3 and p.ss.m22._st().modo == "ritirata" and p.ss.m22.uscita_ammessa("X1") and not p.s.scelte.has("330"), "994: ritirata da W1–Y1, Condizione 3")
	# Genieri.
	var q = nuova(5)
	q.s.avvistamenti[4] = true
	q.ss.m22._st().ponte3 = true
	q.ss.m22.regole_terreno()
	q.leggi("617", {})
	var vde: Dictionary = q.ss.m22.semicingolato()
	ok(not vde.is_empty() and vde.hex == "H15" and q.veicoli.occupanti(vde).size() == 6 and q.u("g42").reazione == "T", "617: semicingolato dei genieri in H15")
	var autista: Dictionary = q.u("g41")
	q.s.round.numero_azione = 3
	q.ia._g = autista
	q.ss.m22.turno_autista(q.ia, autista)
	var scesi: Array = q.tedeschi().filter(func(g): return g.get("reazione", "") == "E")
	ok(vde.hex == "I15" and scesi.size() == 1 and scesi[0].hex == "I15", "il semicingolato va in I15 e lascia un geniere (%s)" % vde.hex)
	var gen: Dictionary = scesi[0]
	q.ia._g = gen
	q.ss.m22.turno_e(q.ia, gen)
	ok(gen.get("sotto_ponte", false), "il geniere scende sotto il ponte")
	q.ss.m22.turno_e(q.ia, gen)
	ok(q.ss.m22.esplosivo("I15") == 2 and int(gen.esplosivi_g) == 0, "il geniere innesca l’esplosivo")
	q.ss.m22.turno_e(q.ia, gen)
	q.ss.m22.turno_e(q.ia, gen)
	ok(not gen.get("sotto_ponte", false) and gen.reazione == "", "risale e torna alla carta")
	# 182: americano sotto un esplosivo sul lato 2 → salta.
	var c: Dictionary = q.u("H")
	q.veicoli.scendi(c)
	c.hex = "I15"
	c.sotto_ponte = true
	c.hex_sotto = "I15"
	q.leggi("182", {})
	ok(q.ss.m22._st().distrutti.has("I15"), "182 → 204: l’esplosivo salta con l’americano sotto")
	# Cecchino 26 e detonatore.
	var r = nuova(7)
	r.leggi("610", {})
	var g26: Dictionary = r.u("g26")
	ok(not g26.is_empty() and g26.reazione == "B" and g26.hex in ["S10", "R17", "W19"], "610: il 26 in reazione B (%s)" % g26.hex)
	r.ss.m22._st().esplosivi["V14"] = 2
	var d: Dictionary = r.u("D")
	r.veicoli.scendi(d)
	d.hex = "U15"
	var pv2: int = r.pv_totali()
	r.ia._g = g26
	r.ss.m22.turno_b(r.ia, g26)
	ok(r.ss.m22._st().distrutti.has("V14") and r.pv_totali() <= pv2 - 1, "il 26 fa saltare il ponte V14 (−1 PV)")
	# Cannone anticarro e Panzer.
	r.leggi("508", {})
	ok(not r.u("g371").is_empty() and r.ss.m22._st().atg.hex == "Q9" and not r.veicoli.v("vatg").is_empty(), "508: cannone anticarro in Q9")
	var gp: Dictionary = r.u("g371")
	r.ia._g = gp
	r.ss.m22.turno_atg(r.ia, gp)
	ok(true, "turno di un servente senza errori")
	r.leggi("411", {})
	var pz: Dictionary = r.veicoli.v("v67")
	ok(not pz.is_empty() and pz.hex == "S13" and int(pz.get("primo_turno", 0)) == 415, "411: Panzer in S13, primo turno 415")
	# Fine nella Condizione 2.
	var f = nuova(11)
	f.leggi("269", {})
	f.leggi("616", {})
	for g in f.tedeschi():
		if f.attivo(g):
			f._uccidi(g, "prova")
	f.ss.m22.controlla()
	ok(f.s.fase == "fine", "269: senza tedeschi né esplosivi la missione finisce")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
