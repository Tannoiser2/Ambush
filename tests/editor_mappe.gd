extends SceneTree
## Editor delle mappe: le correzioni si salvano, il gioco le legge, «Annulla» e «Originale» funzionano.
const DM = preload("res://scripts/motore/dati_mappe.gd")
const EditorMappeScript = preload("res://scripts/ui/editor_mappe.gd")
const MappaScript = preload("res://scripts/ui/mappa.gd")
const TerrenoScript = preload("res://scripts/motore/terreno.gd")
var errori := 0

func verifica(cond: bool, msg: String) -> void:
	if not cond:
		errori += 1
		print("ERRORE: ", msg)

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
	ed.tipo_terreno = "woods" if prima != "woods" else "clear"
	ed._toccato.clear()
	ed._inizia_tratto()
	ed._applica(MappaScript.centro_tex(h), true)
	ed._fine_tratto()
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
	# annulla: torna indietro l'ultimo spostamento
	ed.annulla()
	verifica((ed._angoli(ed.d3.case[-1])[2] as Vector2).distance_to(an[2]) < 1.0, "annulla non ha rimesso l'angolo")
	# esporta / importa
	var pac := DM.pacchetto()
	verifica(pac.mappe.has("mappa_a") and pac.mappe.has("mappa_a_3d"), "il pacchetto non contiene la mappa A")
	DM.cancella("mappa_a")
	DM.cancella("mappa_a_3d")
	verifica(not DM.modificata("mappa_a"), "ripristino non riuscito")
	verifica(DM.importa(JSON.stringify(pac)) == 2, "importazione non riuscita")
	verifica(str(DM.leggi("mappa_a").esagoni[h].t) == ed.tipo_terreno, "dopo l'importazione manca la correzione")
	verifica(DM.importa("non è un file") == -1, "un file sbagliato è stato accettato")
	# pulizia
	DM.cancella("mappa_a")
	DM.cancella("mappa_a_3d")
	verifica(str(DM.leggi("mappa_a").esagoni[h].t) == prima, "l'originale non è tornato")
	ed.queue_free()
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
