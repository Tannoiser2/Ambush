extends SceneTree
## Editor delle mappe: le correzioni si salvano, il gioco le legge, «Annulla» e «Originale» funzionano;
## selezione multipla, edifici modificabili, muri curvi, piani, gallerie e strati.
const DM = preload("res://scripts/motore/dati_mappe.gd")
const E = preload("res://scripts/motore/esagoni.gd")
const EditorMappeScript = preload("res://scripts/ui/editor_mappe.gd")
const MappaScript = preload("res://scripts/ui/mappa.gd")
const TerrenoScript = preload("res://scripts/motore/terreno.gd")
var errori := 0

func verifica(cond: bool, msg: String) -> void:
	if not cond:
		errori += 1
		print("ERRORE: ", msg)

var _passi_nuovi := 0

func _init() -> void:
	_prova()

func _prova() -> void:
	DM.cancella("mappa_a")
	DM.cancella("mappa_a_3d")
	var ed = EditorMappeScript.new()
	root.add_child(ed)
	ed.size = Vector2(1200, 800)
	await process_frame
	await process_frame
	ed.carica("a")
	var h := "K5"
	var prima := str(DM.leggi("mappa_a").esagoni[h].t)
	# terreno: bosco su K5 (con alberi)
	ed.modo = "terreno"
	ed.strumento = "pennello"
	ed.tipo_terreno = "woods" if prima != "woods" else "clear"
	ed._toccato.clear()
	ed._inizia_tratto()
	ed._applica(MappaScript.centro_tex(h), true)
	ed._fine_tratto()
	var dipinto: String = ed.tipo_terreno
	verifica(DM.modificata("mappa_a"), "la mappa corretta non è stata salvata")
	verifica(str(DM.leggi("mappa_a").esagoni[h].t) == ed.tipo_terreno, "il tipo salvato non è quello dipinto")
	var t := TerrenoScript.new("res://data/mappa_a.json")
	verifica(t.tipo(h) == ed.tipo_terreno, "il terreno del gioco non legge la correzione")
	if ed.tipo_terreno == "woods":
		var n := 0
		for a in ed.d3.alberi:
			if ed.esagono_px(Vector2(a[0], a[1])) == h:
				n += 1
		verifica(n >= 4, "il bosco nuovo non ha alberi (%d)" % n)
	# quota
	ed.modo = "quota"
	ed.quota_scelta = 3
	ed._inizia_tratto()
	ed._applica(MappaScript.centro_tex("L6"), true)
	ed._fine_tratto()
	verifica(int(DM.leggi("mappa_a").esagoni["L6"].q) == 3, "quota non salvata")
	# lato: cresta tra K5 e K6
	ed.modo = "lati"
	ed.tipo_lato = "crest"
	ed._toccato.clear()
	ed._inizia_tratto()
	ed._applica((MappaScript.centro_tex("K5") + MappaScript.centro_tex("K6")) / 2.0, true)
	ed._fine_tratto()
	verifica(str(DM.leggi("mappa_a").lati.get("K5|K6", "")) == "crest", "lato non salvato")
	# edifici: nuova stanza, una finestra, sposta un angolo
	ed.modo = "edifici"
	var n0: int = ed.d3.case.size()
	ed.attrezzo_ed = "nuova"
	ed._inizia_tratto()
	ed._applica(MappaScript.centro_tex("E10"), true)
	ed._fine_tratto()
	verifica(ed.d3.case.size() == n0 + 1, "stanza non aggiunta")
	var st: Dictionary = ed.d3.case[-1]
	verifica("E10" in st.hex, "la stanza nuova non copre E10")
	ed.attrezzo_ed = "finestra"
	var an: Array = ed._angoli(st)
	ed._toccato.clear()
	ed._inizia_tratto()
	ed._applica((an[0] as Vector2).lerp(an[1], 0.5), true)
	ed._fine_tratto()
	var tipi: Array = []
	for sg in ed.d3.case[-1].lati[0]:
		tipi.append(str(sg[2]))
	verifica("finestra" in tipi, "finestra non messa: %s" % str(tipi))
	ed.attrezzo_ed = "sposta"
	ed.stanza_sel = ed.d3.case.size() - 1
	ed._inizia_tratto()
	ed._applica(an[2], true)
	ed._applica((an[2] as Vector2) + Vector2(30, 20), false)
	ed._fine_tratto()
	var an2: Array = ed._angoli(ed.d3.case[-1])
	verifica((an2[2] as Vector2).distance_to((an[2] as Vector2) + Vector2(30, 20)) < 1.0, "angolo non spostato")
	verifica(absf(((an2[1] as Vector2) - (an2[0] as Vector2)).dot((an2[2] as Vector2) - (an2[1] as Vector2))) < 1.0, "la stanza non è più rettangolare")
	verifica(DM.leggi("mappa_a_3d").case.size() == n0 + 1, "stanze non salvate")
	await _prove_nuove(ed)
	# annulla: torna indietro l'ultimo spostamento
	for i in _passi_nuovi:
		ed.annulla()
	ed.annulla()
	verifica((ed._angoli(ed.d3.case[-1])[2] as Vector2).distance_to(an[2]) < 1.0, "annulla non ha rimesso l'angolo")
	# esporta / importa
	var pac := DM.pacchetto()
	verifica(pac.mappe.has("mappa_a") and pac.mappe.has("mappa_a_3d"), "il pacchetto non contiene la mappa A")
	DM.cancella("mappa_a")
	DM.cancella("mappa_a_3d")
	verifica(not DM.modificata("mappa_a"), "ripristino non riuscito")
	verifica(DM.importa(JSON.stringify(pac)) == 2, "importazione non riuscita")
	verifica(str(DM.leggi("mappa_a").esagoni[h].t) == dipinto, "dopo l'importazione manca la correzione")
	verifica(DM.importa("non è un file") == -1, "un file sbagliato è stato accettato")
	# pulizia
	DM.cancella("mappa_a")
	DM.cancella("mappa_a_3d")
	verifica(str(DM.leggi("mappa_a").esagoni[h].t) == prima, "l'originale non è tornato")
	ed.queue_free()
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)

## Tocco (o trascinamento) simulato nel punto della mappa: pressione, movimenti, rilascio.
func _tocca(ed, punti: Array) -> void:
	ed._toccato.clear()
	ed._inizia_tratto()
	ed._applica(punti[0], true)
	for k in range(1, punti.size()):
		ed._applica(punti[k], false)
	ed._fine_tratto()

func _c(h: String) -> Vector2:
	return MappaScript.centro_tex(h)

func _prove_nuove(ed) -> void:
	var passi0: int = ed._annulla.size()
	# --- selezione: tocco, trascinamento, riquadro, aggiungi e togli
	ed._imposta_modo("terreno")
	ed.strumento = "seleziona"
	ed.operazione = "nuova"
	_tocca(ed, [_c("C3")])
	verifica(ed.selezione.keys() == ["C3"], "il tocco non seleziona un esagono: %s" % str(ed.selezione.keys()))
	_tocca(ed, [_c("C3")])
	verifica(ed.selezione.is_empty(), "toccare l'unico esagono scelto non lo deseleziona")
	_tocca(ed, [_c("C3"), _c("D3"), _c("E3")])
	verifica(ed.selezione.size() == 3, "trascinando non si selezionano tre esagoni: %s" % str(ed.selezione.keys()))
	ed.operazione = "aggiungi"
	_tocca(ed, [_c("C5")])
	verifica(ed.selezione.size() == 4 and ed.selezione.has("C5"), "aggiungi non aggiunge")
	ed.operazione = "togli"
	_tocca(ed, [_c("D3")])
	verifica(ed.selezione.size() == 3 and not ed.selezione.has("D3"), "togli non toglie")
	ed.strumento = "riquadro"
	ed.operazione = "nuova"
	_tocca(ed, [_c("F6") - Vector2(30, 30), _c("H8") + Vector2(30, 30)])
	for h in ["F6", "G7", "H8", "F8", "H6"]:
		verifica(ed.selezione.has(h), "il riquadro F6–H8 non prende %s" % h)
	verifica(not ed.selezione.has("E5") and not ed.selezione.has("I9"), "il riquadro prende esagoni fuori")
	var n_riq: int = ed.selezione.size()
	ed._mod_togli = true
	_tocca(ed, [_c("G7")])
	ed._mod_togli = false
	verifica(ed.selezione.size() == n_riq - 1 and not ed.selezione.has("G7"), "Ctrl col riquadro non toglie: %d" % ed.selezione.size())
	# --- un clic: tipo a tutta la selezione (un solo passo di Annulla)
	var sel: Array = ed.selezione.keys()
	var prima_annulla: int = ed._annulla.size()
	ed.scegli_tipo("rough")
	var tutti := true
	for h in sel:
		tutti = tutti and str(DM.leggi("mappa_a").esagoni[h].t) == "rough"
	verifica(tutti, "il tipo non è andato a tutti gli esagoni selezionati")
	verifica(ed._annulla.size() == prima_annulla + 1, "assegnare a tutti deve essere un solo passo")
	var t := TerrenoScript.new("res://data/mappa_a.json")
	verifica(t.tipo(str(sel[0])) == "rough", "il motore non legge il tipo assegnato alla selezione")
	# --- quota a tutta la selezione, alza di 1
	ed._imposta_modo("quota")
	ed.scegli_quota(4)
	verifica(int(DM.leggi("mappa_a").esagoni[sel[0]].q) == 4 and int(DM.leggi("mappa_a").esagoni[sel[-1]].q) == 4, "quota non assegnata a tutta la selezione")
	ed.cambia_quota(1)
	verifica(int(DM.leggi("mappa_a").esagoni[sel[0]].q) == 5, "alza di 1 non funziona")
	# --- uguali
	ed._imposta_modo("terreno")
	ed.seleziona_esagoni([sel[0]], "nuova")
	ed._sel_uguali()
	verifica(ed.selezione.size() >= sel.size(), "uguali non prende gli esagoni dello stesso tipo")
	ed._sel_nessuno()
	verifica(ed.selezione.is_empty(), "nessuno non svuota")
	# --- muri curvi: i lati attraversati vanno al motore
	ed._imposta_modo("curve")
	ed.tipo_curva = "stonewall"
	ed.attrezzo_curva = "disegna"
	_tocca(ed, [_c("C10"), _c("D10"), _c("G10")])
	verifica(ed.ter.curve.size() == 1, "muro non creato")
	var lati: Array = ed.ter.curve[0].lati
	verifica(lati.size() >= 3, "il muro dritto C10–G10 attraversa pochi lati: %s" % str(lati))
	for k in lati:
		var pp := str(k).split("|")
		verifica(E.adiacenti(pp[0], pp[1]), "lato non fra esagoni vicini: %s" % k)
	t = TerrenoScript.new("res://data/mappa_a.json")
	var k0: String = lati[0]
	verifica(t.tipo_lato(k0.split("|")[0], k0.split("|")[1]) == "stonewall", "il motore non vede il muretto")
	verifica(t.curve.size() == 1, "il motore non legge la curva")
	# curvarlo: il punto di controllo si sposta e i lati cambiano
	ed.attrezzo_curva = "modifica"
	var c1: Vector2 = ed._punto(ed.ter.curve[0], 1)
	_tocca(ed, [c1, c1 + Vector2(0, 420)])
	var lati2: Array = ed.ter.curve[0].lati
	verifica(str(lati2) != str(lati), "curvando il muro i lati non cambiano")
	for k in lati:
		if not k in lati2:
			verifica(not ed.ter.lati.has(k) or str(ed.ter.lati[k]) != "stonewall", "un lato vecchio del muro è rimasto: %s" % k)
	ed.prolunga_curva(0, _c("I12"))
	verifica(ed.ter.curve[0].punti.size() == 7, "prolunga non aggiunge un tratto")
	ed.curva_sel = 0
	ed.raddrizza_curva()
	var cc: Dictionary = ed.ter.curve[0]
	var a0: Vector2 = ed._punto(cc, 0)
	var a3: Vector2 = ed._punto(cc, 3)
	verifica(ed._punto(cc, 1).distance_to(a0.lerp(a3, 1.0 / 3.0)) < 1.0, "raddrizza non rimette i controlli sulla linea")
	var lati_fin: Array = cc.lati.duplicate()
	ed.elimina_curva()
	var rimasti := 0
	for k in lati_fin:
		if str(ed.ter.lati.get(k, "")) == "stonewall":
			rimasti += 1
	verifica(ed.ter.curve.is_empty() and rimasti == 0, "eliminando il muro restano %d lati" % rimasti)
	# un tocco con Disegna non lascia muri minuscoli
	ed.attrezzo_curva = "disegna"
	_tocca(ed, [_c("K10")])
	verifica(ed.ter.curve.is_empty(), "un tocco crea un muro di un punto")
	# --- edifici: angoli, esagoni occupati, allinea, dalla selezione
	ed._imposta_modo("edifici")
	ed.stanza_sel = 0
	var st: Dictionary = ed.d3.case[0]
	var n_ang: int = st.angoli.size()
	ed.aggiungi_angolo(0, 0, 0.5)
	verifica(ed.d3.case[0].angoli.size() == n_ang + 1 and ed.d3.case[0].lati.size() == n_ang + 1, "angolo non aggiunto")
	ed.togli_angolo(0, 1)
	verifica(ed.d3.case[0].angoli.size() == n_ang and ed.d3.case[0].lati.size() == n_ang, "angolo non tolto")
	var hx := "B2"
	var tipo_b2 := str(ed.ter.esagoni[hx].t)
	ed.attrezzo_ed = "esagoni"
	_tocca(ed, [_c(hx)])
	verifica(str(DM.leggi("mappa_a").esagoni[hx].t) in ["stone_building", "wood_building"], "l'esagono non diventa edificio")
	_tocca(ed, [_c(hx)])
	verifica(str(DM.leggi("mappa_a").esagoni[hx].t) == tipo_b2, "l'esagono non torna al suo terreno")
	ed.seleziona_esagoni(["N16", "O16"], "nuova")
	var nst: int = ed.d3.case.size()
	ed.edificio_da_selezione()
	verifica(ed.d3.case.size() == nst + 1, "l'edificio dalla selezione non ha una stanza")
	verifica(str(DM.leggi("mappa_a").esagoni["N16"].t) == "stone_building", "gli esagoni selezionati non sono edificio")
	var nuova: Dictionary = ed.d3.case[-1]
	verifica("N16" in nuova.hex and "O16" in nuova.hex, "la stanza non copre i due esagoni: %s" % str(nuova.hex))
	# allinea: si sposta la stanza su un esagono vicino e gli esagoni la seguono
	ed.stanza_sel = ed.d3.case.size() - 1
	var an: Array = ed._angoli(nuova)
	var dlt := _c("N18") - _c("N16")
	for j in an.size():
		an[j] += dlt
	ed._imposta_angoli(nuova, an)
	ed.allinea_esagoni()
	verifica(str(DM.leggi("mappa_a").esagoni["N18"].t) == "stone_building", "allinea non fa edificio l'esagono coperto")
	verifica(not str(DM.leggi("mappa_a").esagoni["N16"].t) in ["stone_building", "wood_building"], "allinea lascia edificio l'esagono scoperto")
	# --- piani: edificio a due piani letto dal motore
	ed._imposta_modo("piani")
	ed.attrezzo_piani = "piani"
	_tocca(ed, [_c("N18")])
	verifica("N18" in ed.edificio_sel, "toccando l'edificio non lo si sceglie")
	ed.imposta_piani(2)
	t = TerrenoScript.new("res://data/mappa_a.json")
	verifica(t.ha_piani("N18") and t.piani("N18") == 2, "il motore non vede i due piani")
	ed.imposta_piani(1)
	t = TerrenoScript.new("res://data/mappa_a.json")
	verifica(not t.ha_piani("N18"), "tornato a un piano, il motore vede ancora il piano superiore")
	# --- gallerie: la galleria della Missione 12 è nei dati, se ne crea una nuova
	verifica(ed.ter.gallerie.size() == 1 and "N9" in ed.ter.gallerie[0].esagoni, "manca la galleria della Missione 12 nella mappa A")
	ed.attrezzo_piani = "gallerie"
	ed.nuova_galleria()
	ed.attrezzo_piani = "gallerie"
	for h in ["C15", "D15", "E14"]:
		_tocca(ed, [_c(h)])
	_tocca(ed, [_c("B15")])
	var g: Dictionary = ed.ter.gallerie[ed.galleria_sel]
	verifica(g.esagoni == ["B15", "C15", "D15", "E14"], "tratto della galleria sbagliato: %s" % str(g.esagoni))
	ed.attrezzo_piani = "ingressi"
	_tocca(ed, [_c("B15")])
	_tocca(ed, [_c("H2")])
	verifica(g.ingressi == ["B15"], "ingressi sbagliati: %s" % str(g.ingressi))
	ed._cambia_galleria("missioni", "7, 8")
	t = TerrenoScript.new("res://data/mappa_a.json")
	verifica(t.esagoni_galleria(7) == ["B15", "C15", "D15", "E14"], "il motore non trova la galleria nuova per la missione 7")
	verifica("N9" in t.esagoni_galleria(12), "il motore non trova più la galleria della 12")
	ed.attrezzo_piani = "gallerie"
	_tocca(ed, [_c("D15")])
	verifica(not ("D15" in g.esagoni), "toccare un esagono della galleria non lo toglie")
	ed.elimina_galleria()
	verifica(ed.ter.gallerie.size() == 1, "galleria non eliminata")
	# --- strati: opacità indipendenti
	ed.imposta_strato("mappa", 0.3)
	ed.imposta_strato("dati", 0.6)
	verifica(is_equal_approx(ed.alfa_mappa, 0.3) and is_equal_approx(ed.strato_dati.modulate.a, 0.6), "le opacità degli strati non vanno")
	ed.imposta_strato("mappa", 1.0)
	ed.imposta_strato("dati", 1.0)
	await process_frame
	_passi_nuovi = ed._annulla.size() - passi0
