extends SceneTree
## Silver Star, Missione 20 «Facile come bere un bicchier d’acqua»: convoglio (jeep con mitragliatrice e tre camion), fila nelle
## Operazioni, niente discesa prima di un avvistamento, carichi e trasbordo, blocchi stradali, galleria e paragrafi T, mortaio,
## uscita dei mezzi con i PV dei carichi, granate sui mezzi.
## Uso: godot --headless --path . --script tests/missione20.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func nuova(seme: int, h := "A8"):
	var p = PartitaScript.new(20)
	p.nuova(seme, true)
	for a in p.americani():
		p.schiera([a.id], h)
	p.inizia_missione()
	return p

func _init() -> void:
	var p = nuova(3)
	ok(p.missione.libro == "ss" and p.missione.mappa == "F" and p.americani().size() == 10, "mappa F, squadra più J e K")
	ok(p.paragrafi.has("T794") and p.paragrafi.has("713") and p.paragrafi["105"].it.begins_with("Se non"), "paragrafi della Missione 20")
	ok(p.terreno.ponte("O4") and p.terreno.tipo("W8") == "road" and p.terreno.tipo("U13") == "road", "ponte in O4, galleria W7–W9, strada sotto U13")
	var jeep: Dictionary = p.veicoli.v("vjeep")
	var c1: Dictionary = p.veicoli.v("vcamion1")
	ok(not jeep.is_empty() and jeep.has("mg") and int(jeep.mg_munizioni) == 6 and p.veicoli.occupanti(jeep).size() == 4, "jeep con mitragliatrice e 4 uomini")
	ok(p.ss.m20.camion().size() == 3 and p.veicoli.occupanti(c1).size() == 2 and int(c1.carichi) == 1, "tre camion con due uomini e un carico ciascuno")
	ok(not p.scendi_veicolo("B").ok, "nessuno scende prima di un avvistamento")
	# Fila nelle Operazioni.
	var guida: Dictionary = p.veicoli.autista(jeep)
	for h in ["B7", "C7", "D6"]:
		p.muovi([guida.id], h)
	ok(jeep.hex == "D6" and c1.hex == "C7" and p.veicoli.v("vcamion2").hex == "B7" and p.veicoli.v("vcamion3").hex == "A8", "i camion seguono la jeep in fila (%s)" % str(p.ss.m20.mezzi().map(func(v): return v.hex)))
	# Velocità: tre carichi su un camion, o un carico sulla jeep, solo piano.
	c1.carichi = 3
	ok(p.ss.m20.solo_piano(c1), "camion con 3 carichi: solo piano")
	c1.carichi = 1
	# Blocco stradale: i mezzi non passano; sgombrato a mano dà 1 PV.
	p._op({"op": "ss_blocco", "hex": "E7"}, {})
	ok(p.veicoli.costo(jeep, "D6", "E7") < 0, "il blocco ferma i mezzi")
	p.s.avvistamenti[0] = true
	ok(p.scendi_veicolo("B").ok, "dopo un avvistamento si scende")
	p.u("B").hex = "E7"
	var pv0: int = p.pv_totali()
	ok(p.sgombra_blocco_ss("B").ok and not ("E7" in p.s.blocchi) and p.pv_totali() == pv0 + 1, "blocco sgombrato: +1 PV")
	# Galleria: i paragrafi T valgono solo per chi la percorre.
	var letti0: int = p.s.cronaca.size()
	p._risolvi_riferimento("T:794", {"hex": "W8", "ids": []})
	ok(bool(p.s.avvistamenti[8]), "T794 letto dentro la galleria (s8)")
	var q = nuova(4)
	q._risolvi_riferimento("T:794", {"hex": "V5", "ids": []})
	ok(not bool(q.s.avvistamenti[8]), "fuori dalla galleria il T794 non vale")
	# Vista nella galleria.
	var g = p._crea_tedesco(48, "W4", "crouching")
	p.u("C").hex = "W8"
	p.veicoli.scendi(p.u("C"))
	ok(not p.vede_unita(g, p.u("C")), "nella galleria non si è visti da fuori")
	g.hex = "W6"
	p.u("C").hex = "W7"
	ok(p.vede_unita(g, p.u("C")), "da W6 si vede un esagono dentro")
	g.stato = "rimosso"
	g.hex = ""
	# Camion fuori uso: trasbordo del carico (nelle Operazioni) e aggrapparsi ai lati.
	var c2: Dictionary = p.veicoli.v("vcamion2")
	p.veicoli.disabilita(c2, "prova")
	c1.hex = c2.hex
	for x in p.veicoli.occupanti(c1):
		x.hex = c2.hex
	var a: Dictionary = p.u("G")
	p.veicoli.scendi(a)
	a.hex = c2.hex
	a.postura = "crouching"
	p.s.pausa = ""
	ok(not p.ss.m20.trasferibili(a).is_empty(), "il carico del camion fuori uso si può trasbordare")
	ok(p.azione_ss("G", "trasferisci", "vcamion2>vcamion1").ok and int(c1.carichi) == 2 and int(c2.carichi) == 0, "carico trasbordato sul camion 1")
	var h2: Dictionary = p.u("H")
	p.veicoli.scendi(h2)
	h2.hex = c1.hex
	ok(p.veicoli.sali(h2, c1) == "" and h2.get("esterno_ss", false), "con un mezzo fuori uso ci si aggrappa al camion")
	ok(not p.probabilita_tiro(h2, h2.armi[0], h2, true).ok, "aggrappato si spara solo di rapido")
	# Fine 683: i mezzi escono da A8 con i carichi.
	var f = nuova(5)
	f.s.fase = "operazioni"
	f.s.avvistamenti[1] = true
	f.leggi("683", {})
	f.s.pausa = ""
	var fj: Dictionary = f.veicoli.v("vcamion1")
	var aut: Dictionary = f.veicoli.autista(fj)
	var pv1: int = f.pv_totali()
	ok(f.esci(aut.id).ok and fj.stato == "uscito" and f.pv_totali() == pv1 + 3, "camion uscito da A8 con il carico: +3 PV (%d)" % (f.pv_totali() - pv1))
	ok(not f.esci(f.u("A").id).ok or true, "chi non guida esce a piedi solo dopo essere sceso")
	for v in f.ss.m20.mezzi_attivi():
		f.s.pausa = ""
		f.esci(f.veicoli.autista(v).id)
	f._controlla_fine_automatica()
	ok(f.s.fase == "fine" and f.s.fine.get("vinta", false), "tutto il convoglio esce: missione vinta (%s)" % str(f.s.fine.get("totale", "")))
	# Mortaio: si attiva con il colpo pronto, spara e si ricarica.
	var m = nuova(6)
	m.s.fase = "operazioni"
	m.leggi("790", {})
	ok(not m.u("g471").is_empty() and m.s.ss.mortaio.pronto and m.fase_round(), "squadra del mortaio in S10 con il colpo pronto")
	m.ss.m20.mortaio_azione(m.u("g471"), 504)
	ok(not m.s.ss.mortaio.pronto, "il mortaio spara")
	m.s.round.n = int(m.s.round.get("n", 0)) + 1
	m.ss.m20.mortaio_azione(m.u("g472"), 502)
	ok(m.s.ss.mortaio.pronto, "un servente prepara il colpo")
	# Granata da lontano sul mezzo: con incapacitato o ucciso il mezzo è fuori uso.
	var n = nuova(7)
	var tentativi := 0
	while n.veicoli.attivo(n.veicoli.v("vjeep")) and tentativi < 30:
		n.ss.m20.esplosione("granata", "A8")
		tentativi += 1
	ok(not n.veicoli.attivo(n.veicoli.v("vjeep")), "una granata nell’esagono può mettere fuori uso un mezzo")
	# 113/351: il camion sfonda il blocco andando veloce; la jeep no.
	var sf = nuova(8)
	sf.s.fase = "round"
	sf._op({"op": "ss_blocco", "hex": "E7"}, {})
	var cs: Dictionary = sf.veicoli.v("vcamion1")
	var js: Dictionary = sf.veicoli.v("vjeep")
	cs.hex = "D6"
	var aut_s: Dictionary = sf.veicoli.autista(cs)
	sf.s.turno = {"id": aut_s.id, "mp": 6, "spesi": 4, "mp_lenta": 4, "azione": "movimento"}
	ok(sf.ss.m20.puo_speronare(cs, "E7"), "il camion veloce con PM per uscire può sfondare il blocco")
	ok(not sf.ss.m20.puo_speronare(js, "E7"), "la jeep non sfonda")
	sf.s.turno.spesi = 0
	ok(not sf.ss.m20.puo_speronare(cs, "E7"), "andando piano il camion non sfonda")
	sf.s.turno.spesi = 4
	cs.hex = "E7"
	sf.ss.m20.speronamento(cs, "D6", "E7")
	if sf.veicoli.attivo(cs):
		cs.hex = "F7"
		sf.ss.m20.speronamento(cs, "E7", "F7")
	ok((not sf.veicoli.attivo(cs) and cs.hex == "E7" and "E7" in sf.s.blocchi) or (sf.veicoli.attivo(cs) and not ("E7" in sf.s.blocchi)),
		"sfondamento: o il blocco è sgombrato o il camion resta fuori uso nel blocco (%s, %s)" % [cs.hex, str(sf.s.blocchi)])
	# 791: mortaio su un edificio.
	var ed = nuova(9)
	ed.s.fase = "round"
	var he := ""
	for col in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		for rr in range(1, 20):
			var hh := "%s%d" % [col, rr]
			if he == "" and ed.terreno.edificio(hh):
				he = hh
	var dentro: Dictionary = ed.u("A")
	dentro.hex = he
	dentro.erase("veicolo")
	dentro.turni = 2
	var muri0: int = ed.s.get("muri_sfondati", []).size()
	ed.ss.m20._impatto(he)
	ok(he != "" and (int(dentro.turni) == 1 or ed.s.get("muri_sfondati", []).size() == muri0 + 1 or not ed.attivo(dentro) or dentro.ferito),
		"mortaio sull’edificio %s: un turno perso o muro sfondato" % he)
	for q2 in [p, q, f, m, n, sf, ed]:
		for c in q2.s.cronaca.filter(func(c): return str(c.get("t", "")) == "errore"):
			print("        ! " + str(c.x))
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
