extends SceneTree
## Silver Star, Missione 21 «Sorpresa, sorpresa!»: schieramento a sezioni, arrivi per evento casuale, Jagdpanther e Panzer con i
## granatieri a bordo (reazione T), tedeschi nascosti (reazione H), cannone navale con i serventi J e K, Sherman di soccorso e
## motovedetta che porta via la squadra; fine quando non ci sono più tedeschi attivi.
## Uso: godot --headless --path . --script tests/missione21.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func nuova(seme: int):
	var p = PartitaScript.new(21)
	p.nuova(seme, true)
	var a_esa := ["E15", "F14", "G14", "H13"]
	var b_esa := ["S13", "T12", "U13", "V13"]
	var i := 0
	for a in p.americani():
		p.schiera([a.id], a_esa[i] if i < 4 else b_esa[i - 4])
		i += 1
	p.inizia_missione()
	p.s.pausa = ""
	return p

func _init() -> void:
	var p0 = PartitaScript.new(21)
	p0.nuova(1, true)
	ok(p0.missione.mappa == "FH" and p0.americani().size() == 8, "mappa FH, otto uomini")
	ok(p0.paragrafi.has("690") and p0.paragrafi.has("587") and p0.paragrafi.has("425"), "paragrafi della Missione 21")
	ok(p0.terreno.ponte("K12") and p0.terreno.ponte("T7"), "ponti in K12 e T7")
	ok(p0.schiera(["A", "B"], "E15").ok and not p0.schiera(["C"], "E15").ok, "al massimo 2 per esagono")
	p0.schiera(["C", "D"], "F14")
	ok(not p0.schiera(["E"], "G14").ok, "sezione A: 4 uomini")
	ok(not p0.schiera(["E"], "A1").ok, "fuori dalle sezioni non si schiera")

	var p = nuova(3)
	ok(p.s.fase in ["operazioni", "round"] and p.s.get("radio_hex", "") != "", "la missione comincia con la radio (%s)" % p.s.get("radio_hex", ""))
	# Jagdpanther con 31 e 32 sopra.
	p.leggi("360", {})
	var jg: Dictionary = p.u("g21")
	var v21: Dictionary = p.veicoli.v("v21")
	var g31: Dictionary = p.u("g31")
	ok(not v21.is_empty() and v21.hex == "B19" and v21.modello == "jagdpanther" and not v21.chiuso, "Jagdpanther in B19, aperto")
	ok(p.fase_round() and not g31.is_empty() and g31.hex == "B19" and g31.reazione == "T" and g31.su_carro == "v21", "31 sul Jagdpanther in reazione T")
	ok(bool(v21.get("piano_finche_colpito", false)), "il carro va piano finché non è colpito")
	p.veicoli.sposta(v21, "C18")
	ok(g31.hex == "C18" and p.u("g32").hex == "C18", "i granatieri seguono il carro")
	# Il granatiere salta giù quando il carro è colpito.
	v21.colpito_ss = true
	p.s.round.numero_azione = 4
	p.ia._g = g31
	ok(p.ss.m21.turno_granatiere(p.ia, g31, 584) and g31.reazione == "", "carro colpito: il granatiere toglie la T")
	# Tedesco nascosto.
	var q = nuova(5)
	q.leggi("361", {})
	var g33: Dictionary = q.u("g33")
	ok(not g33.is_empty() and g33.reazione == "H" and g33.hex in ["T15", "Q16", "R13", "U15", "T12"] and q.unita_in(g33.hex, "us").is_empty(), "il 33 esce nascosto in un esagono libero (%s)" % g33.hex)
	# Panzer con 22 e 23 sopra, 24 e 25 a piedi.
	q.leggi("472", {})
	var v30: Dictionary = q.veicoli.v("v30")
	ok(not v30.is_empty() and v30.hex in ["B19", "P19", "Y16", "Y10"] and q.u("g22").su_carro == "v30", "Panzer con i granatieri (%s)" % v30.hex)
	ok(q.u("g24").hex != q.u("g25").hex and q.u("g24").hex in ["H19", "Y17", "S19"], "24 e 25 in esagoni diversi")
	# Cannone navale.
	q.leggi("473", {})
	var j: Dictionary = q.u("J")
	ok(not j.is_empty() and j.hex == "D2" and q.ss.agisce_da_solo(j) and q.ss.m21._st().atg.carico, "cannone navale in D2 con J e K, carico")
	ok(not (j in q.americani_di_turno()), "i serventi non sono ai tuoi ordini")
	q.s.round.numero_azione = 5
	q.ss.m21.turno_americano(j)
	ok(true, "turno di un servente senza errori")
	# 253: settore coperto D3–E3–E2; un carro fuori settore fa girare il cannone a entrambi i serventi.
	ok(q.ss.m21.in_arco("E3") and q.ss.m21.in_arco("D3") and q.ss.m21.in_arco("E2") and not q.ss.m21.in_arco("C2"), "settore iniziale D3, E3, E2")
	var kk: Dictionary = q.u("K")
	j.turni = 2
	kk.turni = 2
	q.ss.m21._st().atg.carico = true
	q.ss.m21._st().atg.caricato = -1
	for g in q.tedeschi_attivi():
		if q.veicoli.attivo(q.veicoli.di(g)):
			q.veicoli.di(g).hex = "C2"
			g.hex = "C2"
	var vede_c := q.tedeschi_attivi().filter(func(g): return q.veicoli.attivo(q.veicoli.di(g)) and q.vede_unita(j, g)).size() > 0
	if vede_c:
		q.ss.m21._atg_spara(j, "vicino")
		ok(q.ss.m21._st().atg.verso == "C2" and int(kk.turni) == 1, "il cannone ruota verso il bersaglio: il compagno spende un turno")
	# 250: con nessun bersaglio il carro tedesco bombarda l’edificio più vicino; due colpi lo riducono in macerie (−1 PV).
	var pv_e: int = q.pv_totali()
	q.veicoli._colpo_su_edificio(j, "Q16")
	q.veicoli._colpo_su_edificio(j, "Q16")
	ok(q.s.modifiche.get("Q16", "") == "rubble" and q.pv_totali() == pv_e - 1, "250: due colpi distruggono l’edificio, −1 PV")
	# 690 con la radio presidiata: scelta.
	var r = nuova(7)
	r.leggi("690", {})
	ok(r.s.get("scelte", {}).has("582") and r.s.scelte.has("587"), "690 con la radio: scegli fra 582 e 587")
	r.esegui_scelta("582")
	var sh: Dictionary = r.u("AA")
	var vs: Dictionary = r.veicoli.v("vsh4")
	ok(not sh.is_empty() and vs.hex in ["A11", "Y4"] and r.ss.agisce_da_solo(sh) and not r.s.scelte.has("587"), "582: lo Sherman entra (%s)" % vs.hex)
	ok(r.ss.m21._st().modo21 == "tenere" and bool(r.s.avvistamenti[8]), "s8, si tiene la posizione")
	ok(not r.u("J").is_empty(), "582 attiva anche il cannone navale (473)")
	# Sherman: un turno da solo con la carta US 04.
	r.s.round.numero_azione = 3
	r.ss.m21.turno_americano(sh)
	ok(true, "turno dello Sherman senza errori")
	# Sherman fuori uso: −3 PV.
	var pv0: int = r.pv_totali()
	r.veicoli.disabilita(vs, "prova")
	ok(r.pv_totali() == pv0 - 3, "Sherman fuori uso: −3 PV")
	# Fine: nessun tedesco attivo.
	for g in r.tedeschi():
		if r.attivo(g):
			r._uccidi(g, "prova")
	r.ss.m21.controlla()
	ok(r.s.fase == "fine", "senza tedeschi attivi la missione finisce")
	# Motovedetta.
	var m = nuova(9)
	m.leggi("587", {})
	var pb: Dictionary = m.u("PB")
	var vpb: Dictionary = m.veicoli.v("vpb")
	ok(not vpb.is_empty() and vpb.hex == "A1" and vpb.modello == "motovedetta" and m.s.condizione == 3, "587: motovedetta in A1, Condizione 3")
	ok(m.fase_round(), "587 fa cominciare i Round")
	# La squadra a bordo: la motovedetta esce.
	for a in m.ss.m21._squadra():
		a.hex = "B1"
	vpb.hex = "A1"
	m.ss.m21._carica_squadra(vpb)
	ok(m.ss.m21._tutti_a_bordo(), "la motovedetta raccoglie chi è accanto")
	m.ss.m21._esce_motovedetta(vpb)
	m.ss.m21.controlla()
	ok(m.s.fase == "fine", "la squadra esce con la motovedetta: fine")
	# Guado.
	var w = nuova(11)
	w.leggi("700", {})
	ok(w.terreno.esagoni["H11"].get("guado", false), "700: guado in H11")
	# Eventi una volta sola.
	w.leggi("222", {})
	var rotti: int = (w.americani() + w.tedeschi()).filter(func(x): return x.get("calcio_rotto", false)).size()
	ok(rotti == 1, "222: un calcio rotto")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
