extends Control
## Editor delle mappe: si correggono a mano terreno, quote, lati, muri curvi, ponti, vegetazione, edifici,
## piani e gallerie. Le correzioni restano sul dispositivo (DatiMappe, user://mappe) e valgono subito nel gioco;
## «Esporta» le raccoglie in un file da mandare per portarle nel progetto.
##
## La vista ha tre strati: la mappa stampata (con la sua opacità), i dati che usa il motore (esagoni, terreno,
## quote, lati, piani, gallerie, con un'opacità indipendente) e gli strumenti (selezione, maniglie), sempre pieni.

signal chiuso(cambiate: bool)

const E = preload("res://scripts/motore/esagoni.gd")
const DM = preload("res://scripts/motore/dati_mappe.gd")
const MappaScript = preload("res://scripts/ui/mappa.gd")
const TerrenoScript = preload("res://scripts/motore/terreno.gd")
const RAGGIO := 180.5 * 0.6

## Tipi di terreno che si possono dipingere, nell'ordine della tavolozza, con il colore di sovrapposizione.
const TIPI := [
	["clear", Color(0.95, 0.93, 0.8)], ["road", Color(0.55, 0.5, 0.42)], ["cover", Color(0.85, 0.82, 0.35)],
	["brush", Color(0.55, 0.65, 0.2)], ["woods", Color(0.1, 0.45, 0.12)], ["rough", Color(0.6, 0.4, 0.25)],
	["vineyard", Color(0.55, 0.3, 0.55)], ["stream", Color(0.2, 0.55, 0.9)], ["water", Color(0.1, 0.25, 0.75)],
	["beach", Color(0.95, 0.85, 0.5)], ["wharf", Color(0.5, 0.5, 0.55)], ["subpen", Color(0.35, 0.35, 0.4)],
	["stone_building", Color(0.45, 0.6, 0.75)], ["wood_building", Color(0.7, 0.45, 0.2)], ["bunker", Color(0.4, 0.4, 0.38)],
	["rubble", Color(0.45, 0.4, 0.35)], ["crater", Color(0.35, 0.28, 0.2)], ["fuel_tank", Color(0.7, 0.7, 0.65)],
	["monument", Color(0.85, 0.8, 0.7)], ["cliff", Color(0.8, 0.3, 0.15)], ["boulder", Color(0.55, 0.55, 0.6)],
]
const LATI := [
	["", "nessuno (automatico)", Color(1, 1, 1, 0.0)], ["crest", "cresta", Color(0.55, 0.3, 0.1)],
	["embankment", "massicciata", Color(0.95, 0.55, 0.1)], ["wall", "muro", Color(0.75, 0.1, 0.1)],
	["stonewall", "muretto di pietra", Color(0.62, 0.6, 0.55)],
	["window", "finestra", Color(0.1, 0.85, 0.95)], ["door", "porta", Color(0.2, 0.85, 0.25)],
]
## Tipi dei muri curvi: diventano i lati degli esagoni che la curva attraversa.
const TIPI_CURVA := [["wall", "Muro"], ["stonewall", "Muretto di pietra"], ["crest", "Cresta"], ["embankment", "Massicciata"]]
const MODI := [["terreno", "Terreno"], ["quota", "Quote"], ["lati", "Lati"], ["curve", "Muri curvi"], ["ponti", "Ponti"],
	["vegetazione", "Alberi"], ["edifici", "Edifici"], ["piani", "Piani e gallerie"]]
const EDIF := ["stone_building", "wood_building"]
const COLORI_PARETE := {"muro": Color(0.6, 0.08, 0.08), "finestra": Color(0.1, 0.85, 0.95), "porta": Color(0.2, 0.9, 0.25), "varco": Color(1, 1, 1, 0.8)}
const COLORE_SEL := Color(0.25, 0.85, 1.0)

var lettera := "a"
var ter: Dictionary = {}
var d3: Dictionary = {}
var ter_orig: Dictionary = {}
var modo := "terreno"
var tipo_terreno := "woods"
var quota_scelta := 2
var tipo_lato := "crest"
var attrezzo_veg := "albero"
var raggio_pennello := 90.0
var attrezzo_ed := "sposta"
var auto_vegetazione := true
var mantieni_rettangolo := true
var stanza_sel := -1
var cambiate := false
## Esagoni da controllare: il centro sta in una stanza ma il terreno non è un edificio, o viceversa.
var sospetti: Dictionary = {}
var mostra_sospetti := true

# selezione di esagoni (Terreno, Quote; «Edificio dalla selezione» negli Edifici)
## «seleziona» (tocco o trascinamento), «riquadro», «pennello» (dipinge subito)
var strumento := "seleziona"
## «nuova», «aggiungi», «togli»
var operazione := "nuova"
var selezione: Dictionary = {}
var _sel_aggiungi := true
var _riquadro: Array = []
var _mod_aggiungi := false
var _mod_togli := false

# muri curvi
var tipo_curva := "stonewall"
## «disegna» (trascina da un capo all'altro), «modifica» (trascina i punti), «prolunga» (tocca dove arriva il tratto nuovo)
var attrezzo_curva := "disegna"
var curva_sel := -1
var _punto_curva := -1

# piani e gallerie
## «piani» (tocca un edificio), «gallerie» (tocca gli esagoni del tratto), «ingressi»
var attrezzo_piani := "piani"
var edificio_sel: Array = []
## «edificio» (tutti gli esagoni uniti) o «esagono» (solo quello toccato: una torre in un edificio più grande)
var ambito_piani := "edificio"
var galleria_sel := -1

# strati
var alfa_mappa := 1.0
var alfa_dati := 1.0

var _annulla: Array = []
var _istantanea = null
var _tratto := false
var _trascina_angolo := -1
var _trascina_stanza := false
var _ultimo_px := Vector2.ZERO
var _toccato := {}

var tela: Control
var strato_dati: Control
var strato_attrezzi: Control
var tavolozza: VBoxContainer
var info: Label
var scelta_mappa: OptionButton
var _bottoni_modo := {}
var vista3d_box: Control
var mappa3d_ctrl = null
var bottone_3d: Button
var _messaggio: Label
var _etichetta_sel: Label
var _barra_strati: Control

# vista 2D
var zoom := 0.2
var spostamento := Vector2.ZERO
var trama: Texture2D
var _tocchi := {}
var _pizzico_dist := 0.0
var _pizzico_centro := Vector2.ZERO
var _pan := false
var sopra := ""

func _ready() -> void:
	theme = Tema.tema()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo := PanelContainer.new()
	fondo.add_theme_stylebox_override("panel", Tema.scatola(Tema.OLIVA_SCURO, Color.TRANSPARENT, 0, 0, 0))
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mg := MarginContainer.new()
	for l in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + l, 8)
	fondo.add_child(mg)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	mg.add_child(vb)
	# Riga 1: titolo, mappa, azioni
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 6)
	vb.add_child(r1)
	var tit := Tema.titolo("EDITOR DELLE MAPPE", 22, Tema.OTTONE)
	tit.clip_text = true
	tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tit.custom_minimum_size = Vector2(60, 0)
	scelta_mappa = OptionButton.new()
	scelta_mappa.focus_mode = Control.FOCUS_NONE
	scelta_mappa.custom_minimum_size = Vector2(230, 36)
	for l in DM.MAPPE:
		scelta_mappa.add_item(DM.MAPPE[l])
		scelta_mappa.set_item_metadata(scelta_mappa.item_count - 1, l)
	scelta_mappa.item_selected.connect(func(i): carica(str(scelta_mappa.get_item_metadata(i))))
	r1.add_child(scelta_mappa)
	r1.add_child(tit)
	r1.move_child(tit, 0)
	r1.add_child(Tema.bottone("Annulla", annulla, "Torna indietro di un'operazione"))
	bottone_3d = Tema.bottone("Vista 3D", _alterna_3d, "Guarda la mappa corretta in 3D")
	bottone_3d.toggle_mode = true
	r1.add_child(bottone_3d)
	r1.add_child(Tema.bottone("Esporta", esporta, "Salva tutte le mappe corrette in un file da mandare"))
	r1.add_child(Tema.bottone("Importa", importa, "Carica un file di mappe corrette"))
	r1.add_child(Tema.bottone("Originale", _chiedi_ripristino, "Butta via le correzioni di questa mappa"))
	r1.add_child(Tema.bottone("Chiudi", chiudi))
	for b in r1.get_children():
		if b is Button:
			b.custom_minimum_size.y = 36
	# Riga 2: modi (in una griglia che va a capo se lo schermo è stretto)
	var r2 := HFlowContainer.new()
	r2.add_theme_constant_override("h_separation", 6)
	r2.add_theme_constant_override("v_separation", 6)
	vb.add_child(r2)
	var gruppo := ButtonGroup.new()
	for m in MODI:
		var b := Tema.bottone(m[1], _imposta_modo.bind(m[0]))
		b.toggle_mode = true
		b.button_group = gruppo
		b.custom_minimum_size = Vector2(86, 36)
		r2.add_child(b)
		_bottoni_modo[m[0]] = b
	_messaggio = Tema.etichetta("", Tema.testo, 14, Tema.OTTONE)
	_messaggio.clip_text = true
	_messaggio.custom_minimum_size = Vector2(160, 36)
	_messaggio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messaggio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_messaggio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r2.add_child(_messaggio)
	# Corpo: tavolozza a sinistra, mappa a destra
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 8)
	vb.add_child(corpo)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Tema.pannello_oliva(8))
	pc.custom_minimum_size = Vector2(236, 0)
	corpo.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	tavolozza = VBoxContainer.new()
	tavolozza.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tavolozza.custom_minimum_size = Vector2(212, 0)
	tavolozza.add_theme_constant_override("separation", 4)
	sc.add_child(tavolozza)
	var destra := VBoxContainer.new()
	destra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_child(destra)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	destra.add_child(area)
	tela = Control.new()
	tela.mouse_filter = Control.MOUSE_FILTER_STOP
	tela.clip_contents = true
	area.add_child(tela)
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.draw.connect(_disegna_mappa)
	tela.gui_input.connect(_input_tela)
	tela.resized.connect(_limita)
	tela.mouse_exited.connect(func(): sopra = ""; _aggiorna_info(); _rid())
	strato_dati = Control.new()
	strato_dati.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strato_dati.clip_contents = true
	area.add_child(strato_dati)
	strato_dati.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strato_dati.draw.connect(_disegna_dati)
	strato_attrezzi = Control.new()
	strato_attrezzi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strato_attrezzi.clip_contents = true
	area.add_child(strato_attrezzi)
	strato_attrezzi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strato_attrezzi.draw.connect(_disegna_attrezzi)
	vista3d_box = Control.new()
	vista3d_box.visible = false
	vista3d_box.clip_contents = true
	area.add_child(vista3d_box)
	vista3d_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_barra_strati = _crea_barra_strati()
	destra.add_child(_barra_strati)
	info = Tema.etichetta("", Tema.testo, 15, Tema.KAKI)
	info.clip_text = true
	info.custom_minimum_size = Vector2(100, 24)
	destra.add_child(info)
	_bottoni_modo["terreno"].button_pressed = true
	carica("a")

## Due cursori indipendenti: quanto si vede la mappa stampata e quanto i dati del motore.
func _crea_barra_strati() -> Control:
	var riga := HFlowContainer.new()
	riga.add_theme_constant_override("h_separation", 10)
	riga.add_theme_constant_override("v_separation", 2)
	for v in [["MAPPA STAMPATA", "mappa"], ["DATI DEL MOTORE", "dati"]]:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.custom_minimum_size = Vector2(330, 30)
		var l := Tema.etichetta(v[0], Tema.testo_bold, 13, Tema.OTTONE)
		l.custom_minimum_size = Vector2(118, 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(l)
		var s := HSlider.new()
		s.name = "strato_" + v[1]
		s.min_value = 0
		s.max_value = 100
		s.step = 5
		s.value = 100
		s.focus_mode = Control.FOCUS_NONE
		s.custom_minimum_size = Vector2(150, 28)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(s)
		var pc := Tema.etichetta("100%", Tema.testo, 13, Tema.KAKI)
		pc.custom_minimum_size = Vector2(40, 0)
		pc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(pc)
		var chi: String = v[1]
		s.value_changed.connect(func(x): pc.text = "%d%%" % int(x); imposta_strato(chi, x / 100.0))
		riga.add_child(box)
	return riga

## Opacità di uno strato («mappa» o «dati»), da 0 a 1.
func imposta_strato(chi: String, a: float) -> void:
	if chi == "mappa":
		alfa_mappa = clampf(a, 0.0, 1.0)
	else:
		alfa_dati = clampf(a, 0.0, 1.0)
		strato_dati.modulate.a = alfa_dati
	_rid()

func _rid() -> void:
	if tela == null:
		return
	tela.queue_redraw()
	if strato_dati == null:
		return
	strato_dati.queue_redraw()
	strato_attrezzi.queue_redraw()

# ------------------------------------------------------------------ dati
func carica(l: String) -> void:
	lettera = l
	for i in scelta_mappa.item_count:
		if str(scelta_mappa.get_item_metadata(i)) == l:
			scelta_mappa.select(i)
	ter = DM.leggi("mappa_%s" % l).duplicate(true)
	d3 = DM.leggi("mappa_%s_3d" % l).duplicate(true)
	ter_orig = DM.originale("mappa_%s" % l)
	# vecchio formato del campanile: diventa il numero di piani dell'esagono
	if str(ter.get("campanile", "")) != "":
		_esagono(str(ter.campanile))["piani"] = 2
		ter.erase("campanile")
	for k in ["lati", "esagoni"]:
		if not ter.has(k):
			ter[k] = {}
	for k in ["curve", "gallerie"]:
		if not ter.has(k):
			ter[k] = []
	for g in ter.gallerie:
		for k in ["esagoni", "ingressi", "missioni"]:
			if not g.has(k):
				g[k] = []
	for k in ["alberi", "cespugli", "ciuffi", "case", "vigne"]:
		if not d3.has(k):
			d3[k] = []
	trama = load("res://assets/maps/mappa_%s.jpg" % l)
	_annulla.clear()
	stanza_sel = -1
	curva_sel = -1
	edificio_sel = []
	galleria_sel = 0 if not ter.gallerie.is_empty() else -1
	selezione.clear()
	_ricalcola_sospetti()
	_centra()
	_tavolozza()
	if vista3d_box.visible:
		_ricostruisci_3d()
	_dici("Mappa %s%s." % [l.to_upper(), " (con correzioni)" if DM.modificata("mappa_" + l) or DM.modificata("mappa_%s_3d" % l) else ""])

func _salva() -> void:
	# gli edifici disegnati seguono le stanze
	var ed: Array = []
	for st in d3.case:
		ed.append({"tipo": st.tipo, "poly": st.angoli})
	d3["edifici"] = ed
	var t := ter.duplicate()
	for k in ["curve", "gallerie"]:
		if (t.get(k, []) as Array).is_empty():
			t.erase(k)
	DM.scrivi("mappa_%s" % lettera, t)
	DM.scrivi("mappa_%s_3d" % lettera, d3)
	cambiate = true

func _inizia_tratto() -> void:
	_istantanea = [ter.duplicate(true), d3.duplicate(true)]
	_tratto = true

func _fine_tratto() -> void:
	if not _tratto:
		return
	if not _riquadro.is_empty():
		_chiudi_riquadro()
	_tratto = false
	_punto_curva = -1
	_chiudi_disegno_curva()
	if _istantanea != null and (JSON.stringify(_istantanea[0]) != JSON.stringify(ter) or JSON.stringify(_istantanea[1]) != JSON.stringify(d3)):
		_annulla.append(_istantanea)
		if _annulla.size() > 40:
			_annulla.pop_front()
		_salva()
	_istantanea = null
	_ricalcola_sospetti()
	_aggiorna_info()
	_aggiorna_sel()
	_rid()

## Un secondo dito durante un tratto: era un pizzico, si annulla quello che il primo dito aveva fatto.
func _annulla_tratto() -> void:
	if _tratto and _istantanea != null:
		ter = _istantanea[0]
		d3 = _istantanea[1]
	_tratto = false
	_istantanea = null
	_trascina_angolo = -1
	_trascina_stanza = false
	_punto_curva = -1
	_riquadro = []
	_rid()

func annulla() -> void:
	if _annulla.is_empty():
		_dici("Niente da annullare.")
		return
	var s: Array = _annulla.pop_back()
	ter = s[0]
	d3 = s[1]
	stanza_sel = mini(stanza_sel, d3.case.size() - 1)
	curva_sel = mini(curva_sel, ter.curve.size() - 1)
	galleria_sel = mini(galleria_sel, ter.gallerie.size() - 1)
	_salva()
	_ricalcola_sospetti()
	_tavolozza()
	_rid()
	_dici("Annullato.")

func _ricalcola_sospetti() -> void:
	sospetti.clear()
	var piante: Array = []
	for st in d3.get("case", []):
		piante.append(PackedVector2Array(_angoli(st)))
	for h in E.tutti():
		var t := str(ter.get("esagoni", {}).get(h, {}).get("t", "clear"))
		var c := MappaScript.centro_tex(h)
		var dentro := false
		for pol in piante:
			if Geometry2D.is_point_in_polygon(c, pol):
				dentro = true
				break
		var edificio := t in EDIF
		if dentro and not edificio and t != "rubble":
			sospetti[h] = "stanza su %s" % TerrenoScript.NOMI.get(t, t)
		elif edificio and not dentro:
			sospetti[h] = "edificio senza stanza 3D"

func _dici(t: String) -> void:
	_messaggio.text = t

# ------------------------------------------------------------------ tavolozza
func _imposta_modo(m: String) -> void:
	modo = m
	if _bottoni_modo.has(m) and not _bottoni_modo[m].button_pressed:
		_bottoni_modo[m].button_pressed = true
	_tavolozza()
	_rid()

func _titolo_tav(t: String) -> void:
	var l := Tema.etichetta(t, Tema.testo_bold, 14, Tema.OTTONE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	tavolozza.add_child(l)

func _spiega(t: String) -> Label:
	var l := Tema.etichetta(t, Tema.testo, 13, Tema.KAKI_SPENTO)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	tavolozza.add_child(l)
	return l

func _scelte(voci: Array, attuale: String, cb: Callable, colori := {}, colonne := 2) -> void:
	var g := ButtonGroup.new()
	var griglia := GridContainer.new()
	griglia.columns = colonne
	griglia.add_theme_constant_override("h_separation", 4)
	griglia.add_theme_constant_override("v_separation", 4)
	tavolozza.add_child(griglia)
	for v in voci:
		var b := Tema.bottone(str(v[1]), cb.bind(v[0]))
		b.toggle_mode = true
		b.button_group = g
		b.button_pressed = str(v[0]) == attuale
		b.custom_minimum_size = Vector2(208 if colonne == 1 else 102, 32)
		b.add_theme_font_size_override("font_size", 13)
		b.clip_text = true
		if colonne == 1:
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if colori.has(v[0]):
			var c: Color = colori[v[0]]
			var st := Tema.scatola(Color("3b4230"), c, 3, 3, 6)
			b.add_theme_stylebox_override("normal", st)
			var stp := Tema.scatola(Color("2a2f20"), Tema.OTTONE, 3, 3, 6)
			b.add_theme_stylebox_override("pressed", stp)
		griglia.add_child(b)

## Bottoni semplici (non a scelta) in griglia: voci = [[testo, callable, suggerimento], …].
func _azioni(voci: Array, colonne := 2) -> void:
	var g := GridContainer.new()
	g.columns = colonne
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	tavolozza.add_child(g)
	for v in voci:
		var b := Tema.bottone(str(v[0]), v[1], str(v[2]) if v.size() > 2 else "")
		b.custom_minimum_size = Vector2(208 if colonne == 1 else 102, 34)
		b.add_theme_font_size_override("font_size", 13)
		b.clip_text = true
		g.add_child(b)

func _spunta(testo: String, valore: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = testo
	c.button_pressed = valore
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 13)
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.custom_minimum_size = Vector2(200, 0)
	c.toggled.connect(cb)
	tavolozza.add_child(c)

func _sezione_selezione() -> void:
	_titolo_tav("STRUMENTO")
	_scelte([["seleziona", "Seleziona"], ["riquadro", "Riquadro"], ["pennello", "Pennello"]], strumento,
		func(v): strumento = v; _tavolozza(), {}, 2)
	if strumento != "pennello":
		_scelte([["nuova", "Nuova"], ["aggiungi", "Aggiungi"], ["togli", "Togli"]], operazione, func(v): operazione = v)
		_spiega("Seleziona: tocca un esagono o trascina sopra più esagoni. Riquadro: trascina un rettangolo. Nuova ricomincia, Aggiungi e Togli cambiano la selezione (col mouse anche Maiuscole e Ctrl).")
	else:
		_spiega("Pennello: tocca o trascina per dipingere subito con il valore scelto sotto.")
	_azioni([["Tutti", _sel_tutti], ["Nessuno", _sel_nessuno], ["Inverti", _sel_inverti],
		["Uguali", _sel_uguali, "Aggiunge tutti gli esagoni con lo stesso terreno (o la stessa quota) di quelli già scelti"]])
	_etichetta_sel = _spiega("")
	_etichetta_sel.add_theme_color_override("font_color", COLORE_SEL)
	_aggiorna_sel()

func _aggiorna_sel() -> void:
	if _etichetta_sel == null or not is_instance_valid(_etichetta_sel):
		return
	if selezione.is_empty():
		_etichetta_sel.text = "Nessun esagono selezionato."
	elif modo == "quota":
		_etichetta_sel.text = "%d esagoni selezionati: tocca un livello per darlo a tutti." % selezione.size()
	elif modo == "edifici":
		_etichetta_sel.text = "%d esagoni selezionati (dal modo Terreno)." % selezione.size()
	else:
		_etichetta_sel.text = "%d esagoni selezionati: tocca un tipo per darlo a tutti." % selezione.size()

func _tavolozza() -> void:
	_etichetta_sel = null
	for c in tavolozza.get_children():
		tavolozza.remove_child(c)
		c.queue_free()
	match modo:
		"terreno":
			_sezione_selezione()
			_titolo_tav("TIPO DI TERRENO")
			var voci: Array = []
			var colori := {}
			for t in TIPI:
				voci.append([t[0], TerrenoScript.NOMI.get(t[0], t[0])])
				colori[t[0]] = t[1]
			_scelte(voci, tipo_terreno, scegli_tipo, colori, 1)
			_spunta("Aggiorna alberi e cespugli (bosco e macchia si riempiono, il terreno libero si svuota)", auto_vegetazione, func(v): auto_vegetazione = v)
			_spunta("Segna con «?» gli esagoni da controllare (stanza 3D su un terreno che non è edificio, o edificio senza stanza)", mostra_sospetti, func(v): mostra_sospetti = v; _rid())
		"quota":
			_sezione_selezione()
			_titolo_tav("QUOTA DELL'ESAGONO")
			_spiega("Ogni esagono mostra il numero del suo livello.")
			var voci: Array = []
			for q in range(0, 6):
				voci.append([str(q), "Livello %d" % q])
			_scelte(voci, str(quota_scelta), func(v): scegli_quota(int(v)))
			_azioni([["Abbassa di 1", func(): cambia_quota(-1)], ["Alza di 1", func(): cambia_quota(1)]])
		"lati":
			_titolo_tav("LATO DELL'ESAGONO")
			_spiega("Tocca vicino al bordo tra due esagoni. I muri degli edifici sono automatici: qui si aggiungono creste, massicciate, muretti, finestre e porte, o un muro dove manca. Per i muri lunghi o curvi usa «Muri curvi».")
			var voci: Array = []
			var colori := {}
			for t in LATI:
				voci.append([t[0], t[1]])
				colori[t[0]] = t[2]
			_scelte(voci, tipo_lato, func(v): tipo_lato = v, colori, 1)
		"curve":
			_titolo_tav("MURI DRITTI E CURVI")
			_scelte([["disegna", "Disegna"], ["modifica", "Modifica"], ["prolunga", "Prolunga"]], attrezzo_curva, func(v): attrezzo_curva = v; _tavolozza())
			match attrezzo_curva:
				"disegna":
					_spiega("Trascina da un capo all'altro: nasce un muro dritto. Poi con Modifica trascini i punti di controllo (i cerchi) per curvarlo.")
				"modifica":
					_spiega("Tocca un muro per sceglierlo. Trascina i quadrati (capi) o i cerchi (punti di controllo).")
				"prolunga":
					_spiega("Tocca dove deve arrivare un nuovo tratto del muro scelto.")
			_titolo_tav("TIPO")
			var colori := {}
			for t in LATI:
				colori[t[0]] = t[2]
			_scelte(TIPI_CURVA, tipo_curva, scegli_tipo_curva, colori, 2)
			_spiega("Il motore usa i lati degli esagoni attraversati dalla curva (segnati in giallo): si aggiornano da soli.")
			_titolo_tav("MURO SCELTO")
			_azioni([["Raddrizza", raddrizza_curva], ["Elimina", elimina_curva]])
		"ponti":
			_titolo_tav("PONTI")
			_spiega("Tocca un esagono di ruscello o di acqua per mettere o togliere il ponte.")
		"vegetazione":
			_titolo_tav("ALBERI E CESPUGLI")
			_spiega("Albero e cespuglio: tocca per piantarne uno, trascina per piantarne una fila. Gomma: toglie tutto nel cerchio. Riempi e svuota lavorano sull'intero esagono.")
			_scelte([["albero", "Albero"], ["cespuglio", "Cespuglio"], ["gomma", "Gomma"], ["riempi_bosco", "Riempi: bosco"], ["riempi_macchia", "Riempi: macchia"], ["svuota", "Svuota esagono"]], attrezzo_veg, func(v): attrezzo_veg = v)
			_titolo_tav("GRANDEZZA")
			var s := HSlider.new()
			s.min_value = 30
			s.max_value = 220
			s.value = raggio_pennello
			s.custom_minimum_size = Vector2(200, 28)
			s.focus_mode = Control.FOCUS_NONE
			s.value_changed.connect(func(v): raggio_pennello = v; _rid())
			tavolozza.add_child(s)
		"edifici":
			_titolo_tav("EDIFICI")
			_scelte([["sposta", "Sposta"], ["nuova", "Nuova stanza"], ["esagoni", "Esagoni"], ["angolo_piu", "Angolo +"],
				["angolo_meno", "Angolo -"], ["muro", "Muro"], ["finestra", "Finestra"], ["porta", "Porta"], ["apri", "Varco"]],
				attrezzo_ed, func(v): attrezzo_ed = v; _tavolozza(); _rid())
			var spiegazioni := {
				"sposta": "Tocca una stanza per sceglierla; trascina i quadratini degli angoli per cambiarne la forma, o l'interno per spostarla.",
				"nuova": "Tocca dove mettere una stanza nuova.",
				"esagoni": "Tocca un esagono per metterlo nell'edificio o toglierlo: è quello che usa il motore (bordo d'ottone).",
				"angolo_piu": "Tocca una parete della stanza: nasce un angolo nuovo da trascinare con Sposta.",
				"angolo_meno": "Tocca un angolo della stanza per toglierlo.",
			}
			_spiega(str(spiegazioni.get(attrezzo_ed, "Tocca lungo una parete per cambiarla.")))
			_spunta("Angoli ad angolo retto (la stanza resta un rettangolo)", mantieni_rettangolo, func(v): mantieni_rettangolo = v)
			_titolo_tav("STANZA SCELTA")
			_azioni([["Pietra", func(): _materiale_stanza("pietra")], ["Legno", func(): _materiale_stanza("legno")],
					["Ruota -", func(): _ruota_stanza(-2.0)], ["Ruota +", func(): _ruota_stanza(2.0)],
					["Raddrizza", _raddrizza], ["Elimina", _elimina_stanza],
					["Allinea esagoni", allinea_esagoni, "Gli esagoni coperti dalla stanza diventano edificio, quelli rimasti fuori tornano liberi"]], 2)
			_titolo_tav("DALLA SELEZIONE")
			_etichetta_sel = _spiega("")
			_etichetta_sel.add_theme_color_override("font_color", COLORE_SEL)
			_aggiorna_sel()
			_azioni([["Edificio dagli esagoni selezionati", edificio_da_selezione, "Gli esagoni selezionati nel modo Terreno diventano un edificio con la sua pianta"]], 1)
		"piani":
			_titolo_tav("PIANI E GALLERIE")
			_scelte([["piani", "Piani"], ["gallerie", "Gallerie"], ["ingressi", "Ingressi"]], attrezzo_piani, func(v): attrezzo_piani = v; _tavolozza(); _rid())
			if attrezzo_piani == "piani":
				_spiega("Tocca un edificio e scegli quanti piani ha. Edificio intero: tutti i suoi esagoni uniti; un esagono: solo quello toccato (una torre, come il campanile). Sulla mappa: «2 P» e il tratteggio. Le regole del gioco prevedono un solo piano superiore.")
				_scelte([["edificio", "Edificio intero"], ["esagono", "Un esagono"]], ambito_piani, func(v): ambito_piani = v; edificio_sel = []; _tavolozza(); _rid())
				_titolo_tav("SCELTI")
				var righe: Array = []
				for h in edificio_sel:
					var np := int(ter.esagoni.get(str(h), {}).get("piani", 1))
					righe.append("%s: %d %s" % [h, np, "piano" if np == 1 else "piani"])
				var s := _spiega("Niente di scelto." if edificio_sel.is_empty() else ", ".join(righe))
				s.add_theme_color_override("font_color", Tema.KAKI)
				var tutti_uguali := true
				for h in edificio_sel:
					tutti_uguali = tutti_uguali and int(ter.esagoni.get(str(h), {}).get("piani", 1)) == _piani_di(edificio_sel)
				_scelte([["1", "1 piano"], ["2", "2 piani"]], str(_piani_di(edificio_sel)) if not edificio_sel.is_empty() and tutti_uguali else "", func(v): imposta_piani(int(v)))
			else:
				_spiega("Gallerie: tocca gli esagoni uno dopo l'altro per tracciare il tratto (toccane uno già dentro per toglierlo). Ingressi: tocca un esagono della galleria per farne o toglierne un ingresso.")
				_titolo_tav("GALLERIA")
				var ob := OptionButton.new()
				ob.focus_mode = Control.FOCUS_NONE
				ob.custom_minimum_size = Vector2(208, 34)
				ob.clip_text = true
				for i in ter.gallerie.size():
					ob.add_item(str(ter.gallerie[i].get("nome", "Galleria %d" % (i + 1))))
				if galleria_sel >= 0:
					ob.select(galleria_sel)
				ob.item_selected.connect(func(i): galleria_sel = i; _tavolozza(); _rid())
				tavolozza.add_child(ob)
				_azioni([["Nuova", nuova_galleria], ["Elimina", elimina_galleria]])
				if galleria_sel >= 0:
					var g: Dictionary = ter.gallerie[galleria_sel]
					_spiega("Nome")
					var nome := LineEdit.new()
					nome.text = str(g.get("nome", ""))
					nome.custom_minimum_size = Vector2(208, 34)
					nome.text_submitted.connect(func(t): _cambia_galleria("nome", t))
					nome.focus_exited.connect(func(): _cambia_galleria("nome", nome.text))
					tavolozza.add_child(nome)
					_spiega("Vale per le missioni (numeri separati da virgola; vuoto = tutte)")
					var mis := LineEdit.new()
					mis.text = ", ".join((g.get("missioni", []) as Array).map(func(x): return str(int(x))))
					mis.custom_minimum_size = Vector2(208, 34)
					mis.text_submitted.connect(func(t): _cambia_galleria("missioni", t))
					mis.focus_exited.connect(func(): _cambia_galleria("missioni", mis.text))
					tavolozza.add_child(mis)
					var es: Array = g.get("esagoni", [])
					var s2 := _spiega("%d esagoni: %s\nIngressi: %s" % [es.size(), " ".join(es), ", ".join(g.get("ingressi", [])) if not (g.get("ingressi", []) as Array).is_empty() else "nessuno"])
					s2.add_theme_color_override("font_color", Tema.KAKI)
	_aggiorna_info()

# ------------------------------------------------------------------ vista 2D
func _centra() -> void:
	if trama == null or tela.size.x < 10:
		call_deferred("_centra_dopo")
		return
	zoom = minf(tela.size.x / trama.get_width(), tela.size.y / trama.get_height())
	spostamento = (tela.size - Vector2(trama.get_size()) * zoom) / 2.0
	_rid()

func _centra_dopo() -> void:
	await get_tree().process_frame
	if tela.size.x >= 10:
		_centra()

func _zoom_minimo() -> float:
	return minf(tela.size.x / trama.get_width(), tela.size.y / trama.get_height()) * 0.9

func _zoom_a(f: float, punto: Vector2) -> void:
	var vecchio := zoom
	zoom = clampf(zoom * f, _zoom_minimo(), 2.0)
	spostamento = punto - (punto - spostamento) * (zoom / vecchio)
	_limita()

func _limita() -> void:
	if trama == null:
		return
	var dim := Vector2(trama.get_size()) * zoom
	for asse in 2:
		if dim[asse] <= tela.size[asse]:
			spostamento[asse] = (tela.size[asse] - dim[asse]) / 2.0
		else:
			spostamento[asse] = clampf(spostamento[asse], tela.size[asse] - dim[asse] - 40.0, 40.0)
	_rid()

func _px(pos: Vector2) -> Vector2:
	return (pos - spostamento) / zoom

func _sc(p: Vector2) -> Vector2:
	return spostamento + p * zoom

func esagono_px(p: Vector2) -> String:
	return E.a_punto(Vector2((p.x / 0.6 - 307.0) / 270.8 * 1.5, (p.y / 0.6 - 272.0) / 314.0 * E.SQRT3))

func _poligono_hex(h: String, scala := 1.0) -> PackedVector2Array:
	var c := MappaScript.centro_tex(h)
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i)
		pts.append(_sc(c + Vector2(cos(a), sin(a)) * RAGGIO * scala))
	return pts

func _colore_tipo(t: String) -> Color:
	for x in TIPI:
		if x[0] == t:
			return x[1]
	return Color.MAGENTA

func _visibile(pol: PackedVector2Array) -> bool:
	return Rect2(Vector2.ZERO, tela.size).grow(RAGGIO * zoom).has_point(pol[0])

## Strato 1: la mappa stampata.
func _disegna_mappa() -> void:
	tela.draw_rect(Rect2(Vector2.ZERO, tela.size), Color("15170f"))
	if trama == null:
		return
	tela.draw_texture_rect(trama, Rect2(spostamento, Vector2(trama.get_size()) * zoom), false, Color(1, 1, 1, alfa_mappa))

## Strato 2: i dati che usa il motore.
func _disegna_dati() -> void:
	if trama == null:
		return
	var ci := strato_dati
	var dim_testo := int(clampf(RAGGIO * zoom * 0.42, 9.0, 30.0))
	var esagoni: Dictionary = ter.get("esagoni", {})
	for h in E.tutti():
		var pol := _poligono_hex(h)
		if not _visibile(pol):
			continue
		var dati: Dictionary = esagoni.get(h, {})
		var orig: Dictionary = ter_orig.get("esagoni", {}).get(h, {})
		var t := str(dati.get("t", "clear"))
		if t != "clear":
			var c := _colore_tipo(t)
			c.a = 0.38 if modo in ["terreno", "edifici", "piani"] else 0.2
			ci.draw_colored_polygon(pol, c)
		var cen := _sc(MappaScript.centro_tex(h))
		var q := int(dati.get("q", 1))
		if modo == "quota":
			_testo_centrato(ci, cen, str(q), dim_testo * 2, Color.WHITE)
		elif modo in ["terreno", "piani"] and zoom > 0.14:
			_testo_centrato(ci, cen + Vector2(0, -RAGGIO * zoom * 0.55), str(q), maxi(9, int(dim_testo * 0.8)), Color(1, 1, 1, 0.9))
		if bool(dati.get("ponte", false)):
			if modo == "ponti":
				ci.draw_colored_polygon(pol, Color(0.95, 0.75, 0.1, 0.45))
				_testo_centrato(ci, cen, "PONTE", dim_testo, Color.BLACK)
			else:
				ci.draw_polyline(_chiuso(_poligono_hex(h, 0.55)), Color(0.95, 0.75, 0.1, 0.8), 2.0)
		var diverso := str(dati.get("t", "")) != str(orig.get("t", "")) or int(dati.get("q", 1)) != int(orig.get("q", 1)) \
			or bool(dati.get("ponte", false)) != bool(orig.get("ponte", false)) or int(dati.get("piani", 1)) != int(orig.get("piani", 1))
		if diverso:
			ci.draw_polyline(_chiuso(pol), Color(1.0, 0.85, 0.1), maxf(2.0, 4.0 * zoom * 3.0))
		elif zoom > 0.12:
			ci.draw_polyline(_chiuso(pol), Color(0, 0, 0, 0.25), 1.0)
	_disegna_piani(ci)
	_disegna_lati(ci, modo in ["lati", "curve"])
	_disegna_gallerie(ci, modo == "piani")
	match modo:
		"vegetazione":
			_disegna_vegetazione(ci)
		"edifici":
			_disegna_edifici(ci)
	if modo != "curve":
		for i in ter.curve.size():
			_disegna_curva(ci, i, false)

## Strato 3: selezione e strumenti (sempre pieno).
func _disegna_attrezzi() -> void:
	if trama == null:
		return
	var ci := strato_attrezzi
	if modo in ["terreno", "quota", "edifici"]:
		for h in selezione:
			var pol := _poligono_hex(h)
			if not _visibile(pol):
				continue
			ci.draw_colored_polygon(pol, Color(COLORE_SEL, 0.28))
			ci.draw_polyline(_chiuso(_poligono_hex(h, 0.93)), COLORE_SEL, 2.5)
	if not _riquadro.is_empty():
		var r := Rect2(_sc(_riquadro[0]), Vector2.ZERO).expand(_sc(_riquadro[1]))
		ci.draw_rect(r, Color(COLORE_SEL, 0.15))
		ci.draw_rect(r, COLORE_SEL, false, 2.0)
	if mostra_sospetti and modo in ["terreno", "edifici"]:
		for h in sospetti:
			var c := _sc(MappaScript.centro_tex(h))
			ci.draw_circle(c, maxf(7.0, RAGGIO * zoom * 0.22), Color(0.95, 0.35, 0.05, 0.85))
			_testo_centrato(ci, c, "?", int(maxf(12.0, RAGGIO * zoom * 0.3)), Color.WHITE)
	if sopra != "":
		ci.draw_polyline(_chiuso(_poligono_hex(sopra)), Color.WHITE, 3.0)
	match modo:
		"edifici":
			_disegna_maniglie_stanza(ci)
		"curve":
			for i in ter.curve.size():
				_disegna_curva(ci, i, true)
		"piani":
			if not edificio_sel.is_empty():
				for h in edificio_sel:
					ci.draw_polyline(_chiuso(_poligono_hex(h, 0.95)), Tema.OTTONE, 4.0)
	if modo == "vegetazione" and attrezzo_veg in ["albero", "cespuglio", "gomma"] and _ultimo_px != Vector2.ZERO:
		var r: float = raggio_pennello if attrezzo_veg == "gomma" else (raggio_pennello * 0.6 if attrezzo_veg == "albero" else raggio_pennello * 0.3)
		ci.draw_arc(_sc(_ultimo_px), r * zoom, 0, TAU, 40, Color.WHITE, 2.0)

func _chiuso(pol: PackedVector2Array) -> PackedVector2Array:
	var b := PackedVector2Array(pol)
	b.append(pol[0])
	return b

func _testo_centrato(ci: CanvasItem, c: Vector2, t: String, dim: int, col: Color) -> void:
	var f := Tema.testo_bold
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x
	ci.draw_string_outline(f, c + Vector2(-w / 2.0, dim * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim, 4, Color(0, 0, 0, 0.6) if col != Color.BLACK else Color(1, 1, 1, 0.6))
	ci.draw_string(f, c + Vector2(-w / 2.0, dim * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim, col)

func _estremi_lato(a: String, b: String) -> Array:
	var ca := MappaScript.centro_tex(a)
	var cb := MappaScript.centro_tex(b)
	var mezzo := (ca + cb) / 2.0
	var dir := (cb - ca).normalized().orthogonal()
	return [mezzo - dir * RAGGIO * 0.5, mezzo + dir * RAGGIO * 0.5]

func _colore_lato(t: String) -> Color:
	for x in LATI:
		if x[0] == t:
			return x[2]
	return Color.MAGENTA

## Lati che vengono da un muro curvo (per segnarli diversi).
func _lati_delle_curve() -> Dictionary:
	var out := {}
	for c in ter.curve:
		for k in c.get("lati", []):
			out[str(k)] = true
	return out

func _disegna_lati(ci: CanvasItem, pieni: bool) -> void:
	var lati: Dictionary = ter.get("lati", {})
	var esagoni: Dictionary = ter.get("esagoni", {})
	var edif := EDIF + ["bunker"]
	var largo := 1.0 if pieni else 0.6
	# muri automatici: tra un edificio e ciò che non lo è
	for h in E.tutti():
		if not str(esagoni.get(h, {}).get("t", "")) in edif:
			continue
		for v in E.vicini(h):
			if str(esagoni.get(v, {}).get("t", "")) in edif or lati.has(E.lato(h, v)):
				continue
			var es := _estremi_lato(h, v)
			ci.draw_line(_sc(es[0]), _sc(es[1]), Color(0.75, 0.1, 0.1, 0.45), maxf(2.0, 10.0 * zoom * largo))
	var da_curve := _lati_delle_curve()
	for k in lati:
		var parti := str(k).split("|")
		if parti.size() != 2:
			continue
		var es := _estremi_lato(parti[0], parti[1])
		ci.draw_line(_sc(es[0]), _sc(es[1]), Color(0, 0, 0, 0.6), maxf(4.0, 22.0 * zoom * largo))
		ci.draw_line(_sc(es[0]), _sc(es[1]), _colore_lato(str(lati[k])), maxf(3.0, 16.0 * zoom * largo))
		if da_curve.has(str(k)) and modo == "curve":
			ci.draw_line(_sc(es[0]), _sc(es[1]), Color(1.0, 0.85, 0.1), maxf(1.5, 5.0 * zoom))

## Edifici a più piani: tratteggio sugli esagoni e «2 P» al centro di ogni gruppo di esagoni con quei piani.
func _disegna_piani(ci: CanvasItem) -> void:
	var visti := {}
	for h0 in ter.esagoni:
		var h := str(h0)
		var np := int(ter.esagoni[h].get("piani", 1))
		if visti.has(h) or np <= 1:
			continue
		# esagoni vicini con lo stesso numero di piani
		var gruppo: Array = [h]
		visti[h] = true
		var i := 0
		while i < gruppo.size():
			for v in E.vicini(str(gruppo[i])):
				if not visti.has(v) and int(ter.esagoni.get(v, {}).get("piani", 1)) == np:
					visti[v] = true
					gruppo.append(v)
			i += 1
		var cen := Vector2.ZERO
		for g in gruppo:
			var c := MappaScript.centro_tex(g)
			cen += c
			# tratteggio obliquo dentro l'esagono
			var r := RAGGIO * 0.8
			for k in range(-3, 4):
				var o := Vector2(k * r / 3.5, 0)
				var a := c + o + Vector2(-r, -r).normalized() * r * 0.8
				var b := c + o + Vector2(r, r).normalized() * r * 0.8
				var clip := Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), _poligono_px(g, 0.85))
				for seg in clip:
					if seg.size() >= 2:
						ci.draw_line(_sc(seg[0]), _sc(seg[seg.size() - 1]), Color(0.1, 0.1, 0.15, 0.8), maxf(1.5, 5.0 * zoom))
			ci.draw_polyline(_chiuso(_poligono_hex(g, 0.85)), Color(0.1, 0.1, 0.15, 0.9), maxf(2.0, 6.0 * zoom))
		var dim := int(clampf(RAGGIO * zoom * 0.5, 11.0, 34.0))
		_cartellino(ci, _sc(cen / float(gruppo.size())), "%d P" % np, dim, Color(1.0, 0.9, 0.55))

func _poligono_px(h: String, scala := 1.0) -> PackedVector2Array:
	var c := MappaScript.centro_tex(h)
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i)
		pts.append(c + Vector2(cos(a), sin(a)) * RAGGIO * scala)
	return pts

## Gallerie: una fascia scura lungo i centri degli esagoni, ingressi segnati con un riquadro e «INGRESSO».
func _disegna_gallerie(ci: CanvasItem, evidenzia: bool) -> void:
	for i in ter.gallerie.size():
		var g: Dictionary = ter.gallerie[i]
		var es: Array = g.get("esagoni", [])
		if es.is_empty():
			continue
		var scelta: bool = evidenzia and i == galleria_sel
		var pts := PackedVector2Array()
		for h in es:
			pts.append(_sc(MappaScript.centro_tex(str(h))))
		var largo := maxf(6.0, RAGGIO * zoom * 0.55) if evidenzia else maxf(3.0, RAGGIO * zoom * 0.14)
		var bordo := Color(1.0, 0.85, 0.1) if scelta else Color(0.85, 0.75, 0.55)
		var fondo := Color(0.16, 0.12, 0.08, 0.9 if evidenzia else 0.55)
		if pts.size() == 1:
			ci.draw_circle(pts[0], largo * 0.6, fondo)
		elif not evidenzia:
			ci.draw_polyline(pts, fondo, largo, true)
		else:
			ci.draw_polyline(pts, Color(0, 0, 0, 0.5), largo + 6.0, true)
			ci.draw_polyline(pts, fondo, largo, true)
			# bordo tratteggiato ai due lati: si legge come «sotto terra»
			for k in pts.size() - 1:
				var a := pts[k]
				var b := pts[k + 1]
				var n := (b - a).normalized().orthogonal() * largo * 0.5
				ci.draw_dashed_line(a + n, b + n, bordo, 2.0, 10.0)
				ci.draw_dashed_line(a - n, b - n, bordo, 2.0, 10.0)
		for h in g.get("ingressi", []):
			var c := _sc(MappaScript.centro_tex(str(h)))
			var r := maxf(7.0, RAGGIO * zoom * 0.28) if evidenzia else maxf(4.0, RAGGIO * zoom * 0.14)
			ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), fondo)
			ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), bordo, false, 2.5 if evidenzia else 1.5)
			if evidenzia and zoom > 0.3:
				_cartellino(ci, c + Vector2(0, r + 14.0), "INGRESSO", int(clampf(RAGGIO * zoom * 0.2, 12.0, 18.0)), Color(1.0, 0.9, 0.6))
		if evidenzia:
			var m := pts[pts.size() / 2]
			_cartellino(ci, m + Vector2(0, -largo - 16.0), str(g.get("nome", "")).to_upper(), int(clampf(RAGGIO * zoom * 0.22, 12.0, 20.0)), bordo)

## Testo su un fondo scuro, leggibile sopra qualunque terreno.
func _cartellino(ci: CanvasItem, c: Vector2, t: String, dim: int, col: Color) -> void:
	var w := Tema.testo_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x
	ci.draw_rect(Rect2(c - Vector2(w / 2.0 + 6, dim * 0.75), Vector2(w + 12, dim * 1.45)), Color(0.08, 0.07, 0.05, 0.85))
	_testo_centrato(ci, c, t, dim, col)

func _disegna_vegetazione(ci: CanvasItem) -> void:
	for a in d3.alberi:
		ci.draw_circle(_sc(Vector2(a[0], a[1])), maxf(2.0, float(a[2]) * zoom), Color(0.05, 0.4, 0.05, 0.55))
	for c in d3.cespugli:
		ci.draw_circle(_sc(Vector2(c[0], c[1])), maxf(1.5, float(c[2]) * zoom), Color(0.6, 0.7, 0.1, 0.6))
	for c in d3.ciuffi:
		ci.draw_circle(_sc(Vector2(c[0], c[1])), maxf(1.0, 6.0 * zoom), Color(0.9, 0.85, 0.3, 0.7))

func _disegna_edifici(ci: CanvasItem) -> void:
	for i in d3.case.size():
		var st: Dictionary = d3.case[i]
		var an := _angoli(st)
		var pol := PackedVector2Array()
		for p in an:
			pol.append(_sc(p))
		var fondo := Color(0.3, 0.45, 0.6, 0.22) if str(st.tipo) == "pietra" else Color(0.6, 0.38, 0.15, 0.22)
		if i == stanza_sel:
			fondo.a = 0.4
		if pol.size() >= 3:
			ci.draw_colored_polygon(pol, fondo)
		for j in an.size():
			var p: Vector2 = an[j]
			var q: Vector2 = an[(j + 1) % an.size()]
			var segs: Array = st.lati[j] if j < st.lati.size() else [[0.0, 1.0, "muro"]]
			for sg in segs:
				var a := p.lerp(q, float(sg[0]))
				var b := p.lerp(q, float(sg[1]))
				var col: Color = COLORI_PARETE.get(str(sg[2]), Color.MAGENTA)
				ci.draw_line(_sc(a), _sc(b), col, maxf(2.5, 12.0 * zoom))

## Maniglie della stanza scelta e bordo d'ottone sugli esagoni del suo edificio (quelli del motore).
func _disegna_maniglie_stanza(ci: CanvasItem) -> void:
	if stanza_sel < 0 or stanza_sel >= d3.case.size():
		return
	var st: Dictionary = d3.case[stanza_sel]
	for h in esagoni_edificio_stanza(stanza_sel):
		ci.draw_polyline(_chiuso(_poligono_hex(h, 0.96)), Tema.OTTONE, 3.0)
	for p in _angoli(st):
		var r := Rect2(_sc(p) - Vector2(9, 9), Vector2(18, 18))
		ci.draw_rect(r, Color.WHITE)
		ci.draw_rect(r, Color.BLACK, false, 2.0)

## Disegna un muro curvo; con «maniglie» anche i punti da trascinare (solo quello scelto).
func _disegna_curva(ci: CanvasItem, i: int, maniglie: bool) -> void:
	var c: Dictionary = ter.curve[i]
	var pts := TerrenoScript.punti_curva(c.get("punti", []), 6.0)
	if pts.size() < 2:
		return
	var sc := PackedVector2Array()
	for q in pts:
		sc.append(_sc(q))
	var col := _colore_lato(str(c.get("tipo", "wall")))
	col.a = 1.0
	var scelta: bool = maniglie and i == curva_sel
	ci.draw_polyline(sc, Color(0, 0, 0, 0.6), maxf(4.0, 14.0 * zoom) + 3.0, true)
	ci.draw_polyline(sc, Color(1.0, 0.85, 0.1) if scelta else col, maxf(3.0, 14.0 * zoom), true)
	if not scelta:
		return
	var pv: Array = c.punti
	for k in pv.size():
		var p := _sc(Vector2(float(pv[k][0]), float(pv[k][1])))
		if k % 3 == 0:
			if k > 0:
				var pc := _sc(Vector2(float(pv[k - 1][0]), float(pv[k - 1][1])))
				ci.draw_line(p, pc, Color(1, 1, 1, 0.8), 1.5)
			if k + 1 < pv.size():
				var pn := _sc(Vector2(float(pv[k + 1][0]), float(pv[k + 1][1])))
				ci.draw_line(p, pn, Color(1, 1, 1, 0.8), 1.5)
			ci.draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color.WHITE)
			ci.draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color.BLACK, false, 2.0)
		else:
			ci.draw_circle(p, 9.0, Color.BLACK)
			ci.draw_circle(p, 7.0, Color(1.0, 0.85, 0.1))

func _angoli(st: Dictionary) -> Array:
	var out: Array = []
	for q in st.angoli:
		out.append(Vector2(float(q[0]), float(q[1])))
	return out

func _imposta_angoli(st: Dictionary, an: Array) -> void:
	var l: Array = []
	for p in an:
		l.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	st.angoli = l
	# esagoni coperti dalla stanza
	var pol := PackedVector2Array(an)
	var hs: Array = []
	var cen := Vector2.ZERO
	for p in an:
		cen += p
	cen /= float(an.size())
	for h in E.tutti():
		if Geometry2D.is_point_in_polygon(MappaScript.centro_tex(h), pol):
			hs.append(h)
	if hs.is_empty():
		var h := esagono_px(cen)
		if h != "":
			hs.append(h)
	st.hex = hs

# ------------------------------------------------------------------ input
func _input_tela(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			_tocchi[st.index] = st.position
		else:
			_tocchi.erase(st.index)
		if _tocchi.size() >= 2:
			_annulla_tratto()
			var k := _tocchi.keys()
			_pizzico_dist = (_tocchi[k[0]] as Vector2).distance_to(_tocchi[k[1]])
			_pizzico_centro = ((_tocchi[k[0]] as Vector2) + (_tocchi[k[1]] as Vector2)) / 2.0
		return
	if ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		_tocchi[sd.index] = sd.position
		if _tocchi.size() >= 2:
			var k := _tocchi.keys()
			var a: Vector2 = _tocchi[k[0]]
			var b: Vector2 = _tocchi[k[1]]
			var d := a.distance_to(b)
			var centro := (a + b) / 2.0
			if _pizzico_dist > 1.0 and d > 1.0:
				_zoom_a(d / _pizzico_dist, centro)
				spostamento += centro - _pizzico_centro
				_limita()
			_pizzico_dist = d
			_pizzico_centro = centro
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_a(1.15, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_a(1.0 / 1.15, mb.position)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_pan = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _tocchi.size() >= 2:
					return
				_mod_aggiungi = mb.shift_pressed
				_mod_togli = mb.ctrl_pressed or mb.meta_pressed or mb.alt_pressed
				_toccato.clear()
				_inizia_tratto()
				_applica(_px(mb.position), true)
			else:
				_trascina_angolo = -1
				_trascina_stanza = false
				_fine_tratto()
		tela.accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		var p := _px(mm.position)
		_ultimo_px = p
		if _pan:
			spostamento += mm.relative
			_limita()
		elif _tratto and _tocchi.size() < 2 and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_applica(p, false)
		var h := esagono_px(p)
		if h != sopra:
			sopra = h
			_aggiorna_info()
		strato_attrezzi.queue_redraw()
	elif ev is InputEventMagnifyGesture:
		_zoom_a((ev as InputEventMagnifyGesture).factor, (ev as InputEventMagnifyGesture).position)
	elif ev is InputEventPanGesture:
		spostamento -= (ev as InputEventPanGesture).delta * 12.0
		_limita()

## Applica l'attrezzo nel punto p (pixel della mappa); «inizio» alla pressione, poi ad ogni movimento.
func _applica(p: Vector2, inizio: bool) -> void:
	var h := esagono_px(p)
	match modo:
		"terreno", "quota":
			if strumento == "pennello":
				if h != "" and not _toccato.has(h):
					_toccato[h] = true
					if modo == "terreno":
						_dipingi_tipo(h)
					else:
						_esagono(h)["q"] = quota_scelta
			else:
				_seleziona_in(p, h, inizio)
		"ponti":
			if h != "" and inizio:
				var e := _esagono(h)
				if bool(e.get("ponte", false)):
					e.erase("ponte")
				else:
					e["ponte"] = true
		"lati":
			_dipingi_lato(p)
		"curve":
			_curve(p, inizio)
		"vegetazione":
			_vegetazione(p, h, inizio)
		"edifici":
			_edifici(p, h, inizio)
		"piani":
			if inizio:
				_piani_gallerie(h)
	_rid()

func _esagono(h: String) -> Dictionary:
	if not ter.esagoni.has(h):
		ter.esagoni[h] = {"t": "clear", "q": 1}
	return ter.esagoni[h]

func _dipingi_tipo(h: String) -> void:
	var e := _esagono(h)
	if str(e.get("t", "")) == tipo_terreno:
		return
	e["t"] = tipo_terreno
	if not tipo_terreno in EDIF:
		e.erase("piani")
	if auto_vegetazione:
		match tipo_terreno:
			"woods":
				_riempi(h, true)
			"brush":
				_riempi(h, false)
			"clear", "road", "stream", "water", "beach", "wharf", "subpen", "stone_building", "wood_building", "bunker", "fuel_tank", "monument", "crater", "cliff", "boulder":
				_svuota(h)

func _dipingi_lato(p: Vector2) -> void:
	var h := esagono_px(p)
	if h == "":
		return
	var migliore := ""
	var dmin := 1e9
	for v in E.vicini(h):
		var m := (MappaScript.centro_tex(h) + MappaScript.centro_tex(v)) / 2.0
		var d := p.distance_to(m)
		if d < dmin:
			dmin = d
			migliore = v
	if migliore == "" or dmin > RAGGIO * 0.5:
		return
	var k := E.lato(h, migliore)
	if _toccato.has(k):
		return
	_toccato[k] = true
	if tipo_lato == "":
		ter.lati.erase(k)
	else:
		ter.lati[k] = tipo_lato

# ------------------------------------------------------------------ selezione
func _op_effettiva() -> String:
	if _mod_togli:
		return "togli"
	if _mod_aggiungi:
		return "aggiungi"
	return operazione

func _seleziona_in(p: Vector2, h: String, inizio: bool) -> void:
	if strumento == "riquadro":
		if inizio:
			_riquadro = [p, p]
		elif not _riquadro.is_empty():
			_riquadro[1] = p
		return
	if inizio:
		var op := _op_effettiva()
		if op == "nuova":
			# toccare l'unico esagono scelto lo deseleziona
			if selezione.size() == 1 and selezione.has(h):
				selezione.clear()
				_sel_aggiungi = false
				_aggiorna_sel()
				return
			selezione.clear()
		_sel_aggiungi = op != "togli"
	if h == "":
		return
	if _sel_aggiungi:
		selezione[h] = true
	else:
		selezione.erase(h)
	_aggiorna_sel()

func _chiudi_riquadro() -> void:
	var r := Rect2(_riquadro[0], Vector2.ZERO).expand(_riquadro[1])
	_riquadro = []
	var dentro: Array = []
	if r.size.length() < RAGGIO * 0.3:
		var h := esagono_px(r.position)
		if h != "":
			dentro.append(h)
	else:
		for h in E.tutti():
			if r.has_point(MappaScript.centro_tex(h)):
				dentro.append(h)
	seleziona_esagoni(dentro, _op_effettiva())

## Cambia la selezione con una lista di esagoni: «nuova», «aggiungi» o «togli».
func seleziona_esagoni(lista: Array, op := "nuova") -> void:
	if op == "nuova":
		selezione.clear()
	for h in lista:
		if op == "togli":
			selezione.erase(str(h))
		else:
			selezione[str(h)] = true
	_aggiorna_sel()
	_rid()

func _sel_tutti() -> void:
	seleziona_esagoni(E.tutti(), "nuova")

func _sel_nessuno() -> void:
	seleziona_esagoni([], "nuova")

func _sel_inverti() -> void:
	var altri: Array = []
	for h in E.tutti():
		if not selezione.has(h):
			altri.append(h)
	seleziona_esagoni(altri, "nuova")

## Aggiunge gli esagoni con lo stesso terreno (modo Terreno) o la stessa quota (modo Quote) di quelli scelti.
func _sel_uguali() -> void:
	if selezione.is_empty():
		_dici("Prima scegli almeno un esagono.")
		return
	var valori := {}
	for h in selezione:
		valori[_valore_uguale(str(h))] = true
	var lista: Array = []
	for h in E.tutti():
		if valori.has(_valore_uguale(h)):
			lista.append(h)
	seleziona_esagoni(lista, "aggiungi")

func _valore_uguale(h: String) -> String:
	var e: Dictionary = ter.esagoni.get(h, {})
	return str(int(e.get("q", 1))) if modo == "quota" else str(e.get("t", "clear"))

## Sceglie il tipo di terreno; se ci sono esagoni selezionati lo dà a tutti (un solo passo di «Annulla»).
func scegli_tipo(t: String) -> void:
	tipo_terreno = t
	if selezione.is_empty():
		return
	_inizia_tratto()
	for h in selezione:
		_dipingi_tipo(str(h))
	_fine_tratto()
	_dici("%s a %d esagoni." % [_maiuscola(str(TerrenoScript.NOMI.get(t, t))), selezione.size()])

func _maiuscola(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)

func scegli_quota(q: int) -> void:
	quota_scelta = q
	if selezione.is_empty():
		return
	_inizia_tratto()
	for h in selezione:
		_esagono(str(h))["q"] = q
	_fine_tratto()
	_dici("Livello %d a %d esagoni." % [q, selezione.size()])

func cambia_quota(d: int) -> void:
	if selezione.is_empty():
		_dici("Prima seleziona gli esagoni.")
		return
	_inizia_tratto()
	for h in selezione:
		var e := _esagono(str(h))
		e["q"] = clampi(int(e.get("q", 1)) + d, 0, 9)
	_fine_tratto()
	_dici("Quota %s di 1 per %d esagoni." % ["alzata" if d > 0 else "abbassata", selezione.size()])

# ------------------------------------------------------------------ vegetazione
func _dentro_hex(p: Vector2, h: String) -> bool:
	return esagono_px(p) == h

## Riempie un esagono di alberi (bosco) o cespugli (macchia) su una griglia irregolare.
func _riempi(h: String, bosco: bool) -> void:
	_svuota(h)
	var c := MappaScript.centro_tex(h)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(h + lettera)
	var passo := 58.0 if bosco else 34.0
	var y := -RAGGIO
	while y <= RAGGIO:
		var x := -RAGGIO
		while x <= RAGGIO:
			var q := c + Vector2(x + rng.randf_range(-passo * 0.3, passo * 0.3), y + rng.randf_range(-passo * 0.3, passo * 0.3))
			if _dentro_hex(q, h) and q.distance_to(c) < RAGGIO * 0.93:
				if bosco:
					d3.alberi.append([snappedf(q.x, 0.1), snappedf(q.y, 0.1), snappedf(rng.randf_range(40.0, 60.0), 0.1)])
				else:
					d3.cespugli.append([snappedf(q.x, 0.1), snappedf(q.y, 0.1), snappedf(rng.randf_range(16.0, 28.0), 0.1)])
			x += passo
		y += passo * 0.87

func _svuota(h: String) -> void:
	for k in ["alberi", "cespugli", "ciuffi"]:
		var tenuti: Array = []
		for a in d3[k]:
			if esagono_px(Vector2(a[0], a[1])) != h:
				tenuti.append(a)
		d3[k] = tenuti

func _vegetazione(p: Vector2, h: String, _inizio: bool) -> void:
	match attrezzo_veg:
		"albero", "cespuglio":
			var albero := attrezzo_veg == "albero"
			var r := raggio_pennello * (0.6 if albero else 0.3)
			var lista: Array = d3.alberi if albero else d3.cespugli
			for a in lista:
				if Vector2(a[0], a[1]).distance_to(p) < r * 1.2:
					return
			lista.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(r, 0.1)])
		"gomma":
			for k in ["alberi", "cespugli", "ciuffi"]:
				var tenuti: Array = []
				for a in d3[k]:
					if Vector2(a[0], a[1]).distance_to(p) > raggio_pennello:
						tenuti.append(a)
				d3[k] = tenuti
		"riempi_bosco", "riempi_macchia":
			if h != "" and not _toccato.has(h):
				_toccato[h] = true
				_riempi(h, attrezzo_veg == "riempi_bosco")
		"svuota":
			if h != "" and not _toccato.has(h):
				_toccato[h] = true
				_svuota(h)

# ------------------------------------------------------------------ muri curvi
func scegli_tipo_curva(t: String) -> void:
	tipo_curva = t
	if curva_sel >= 0 and curva_sel < ter.curve.size() and str(ter.curve[curva_sel].tipo) != t:
		_inizia_tratto()
		ter.curve[curva_sel].tipo = t
		aggiorna_lati_curva(curva_sel)
		_fine_tratto()

## Lati degli esagoni attraversati da una curva (punti in pixel della mappa).
func lati_attraversati(punti: Array) -> Array:
	var pts := TerrenoScript.punti_curva(punti, 5.0)
	var out: Array = []
	if pts.is_empty():
		return out
	var prec := esagono_px(pts[0])
	for k in range(1, pts.size()):
		var h := esagono_px(pts[k])
		if h != prec:
			_passaggio(prec, h, pts[k - 1], pts[k], out, 0)
			prec = h
	return out

## Fra due punti in esagoni diversi: se sono vicini il lato è quello; altrimenti si divide il tratto a metà.
func _passaggio(a: String, b: String, pa: Vector2, pb: Vector2, out: Array, prof: int) -> void:
	if a == "" or b == "" or a == b:
		return
	if E.adiacenti(a, b):
		var k := E.lato(a, b)
		if not (k in out):
			out.append(k)
		return
	if prof > 10:
		return
	var m := (pa + pb) / 2.0
	var hm := esagono_px(m)
	_passaggio(a, hm, pa, m, out, prof + 1)
	_passaggio(hm, b, m, pb, out, prof + 1)

## Rifà i lati del motore di una curva: toglie quelli vecchi (se nessun'altra curva li usa) e mette i nuovi.
func aggiorna_lati_curva(i: int) -> void:
	var c: Dictionary = ter.curve[i]
	_togli_lati_curva(i)
	var nuovi := lati_attraversati(c.punti)
	for k in nuovi:
		ter.lati[k] = str(c.tipo)
	c["lati"] = nuovi

func _togli_lati_curva(i: int) -> void:
	var altri := {}
	for j in ter.curve.size():
		if j != i:
			for k in ter.curve[j].get("lati", []):
				altri[str(k)] = true
	for k in ter.curve[i].get("lati", []):
		if not altri.has(str(k)) and ter.lati.has(k):
			ter.lati.erase(k)
	ter.curve[i]["lati"] = []

## Nuovo muro dritto da a a b (i punti di controllo a un terzo e due terzi).
func nuova_curva(a: Vector2, b: Vector2, tipo := "") -> int:
	var c := {"tipo": tipo if tipo != "" else tipo_curva, "punti": _tratto_dritto(a, b), "lati": []}
	ter.curve.append(c)
	curva_sel = ter.curve.size() - 1
	aggiorna_lati_curva(curva_sel)
	return curva_sel

## Un tocco senza trascinare con «Disegna» non lascia un muro di un pixel.
func _chiudi_disegno_curva() -> void:
	if modo != "curve" or attrezzo_curva != "disegna" or curva_sel < 0 or curva_sel >= ter.curve.size():
		return
	var c: Dictionary = ter.curve[curva_sel]
	if _punto(c, 0).distance_to(_punto(c, c.punti.size() - 1)) < RAGGIO * 0.25:
		_togli_lati_curva(curva_sel)
		ter.curve.remove_at(curva_sel)
		curva_sel = _curva_vicina(_punto(c, 0))

func _tratto_dritto(a: Vector2, b: Vector2) -> Array:
	var out: Array = []
	for q in [a, a.lerp(b, 1.0 / 3.0), a.lerp(b, 2.0 / 3.0), b]:
		out.append([snappedf(q.x, 0.1), snappedf(q.y, 0.1)])
	return out

func _punto(c: Dictionary, k: int) -> Vector2:
	return Vector2(float(c.punti[k][0]), float(c.punti[k][1]))

func _metti_punto(c: Dictionary, k: int, p: Vector2) -> void:
	c.punti[k] = [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]

## Sposta un punto di una curva; un capo si porta dietro i suoi punti di controllo.
func sposta_punto_curva(i: int, k: int, p: Vector2) -> void:
	var c: Dictionary = ter.curve[i]
	var dlt := p - _punto(c, k)
	_metti_punto(c, k, p)
	if k % 3 == 0:
		for j in [k - 1, k + 1]:
			if j >= 0 and j < c.punti.size():
				_metti_punto(c, j, _punto(c, j) + dlt)
	aggiorna_lati_curva(i)

func _curva_vicina(p: Vector2) -> int:
	var dmin := 16.0 / maxf(zoom, 0.05)
	var migliore := -1
	for i in ter.curve.size():
		var pts := TerrenoScript.punti_curva(ter.curve[i].punti, 8.0)
		for k in pts.size() - 1:
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1]))
			if d < dmin:
				dmin = d
				migliore = i
	return migliore

func _curve(p: Vector2, inizio: bool) -> void:
	match attrezzo_curva:
		"disegna":
			if inizio:
				nuova_curva(p, p + Vector2(1, 0))
				_punto_curva = 3
			elif _punto_curva >= 0 and curva_sel >= 0:
				var c: Dictionary = ter.curve[curva_sel]
				c.punti = _tratto_dritto(_punto(c, 0), p)
				aggiorna_lati_curva(curva_sel)
		"modifica":
			if inizio:
				_punto_curva = -1
				if curva_sel >= 0 and curva_sel < ter.curve.size():
					var c: Dictionary = ter.curve[curva_sel]
					for k in c.punti.size():
						if _sc(_punto(c, k)).distance_to(_sc(p)) < 22.0:
							_punto_curva = k
				if _punto_curva < 0:
					curva_sel = _curva_vicina(p)
					if curva_sel >= 0:
						tipo_curva = str(ter.curve[curva_sel].tipo)
						_tavolozza()
			elif _punto_curva >= 0 and curva_sel >= 0:
				sposta_punto_curva(curva_sel, _punto_curva, p)
		"prolunga":
			if not inizio:
				return
			if curva_sel < 0 or curva_sel >= ter.curve.size():
				_dici("Prima scegli un muro (Modifica) o disegnane uno.")
				return
			prolunga_curva(curva_sel, p)

## Aggiunge in fondo alla curva un tratto che arriva a p, che parte nella stessa direzione dell'ultimo (curva liscia).
func prolunga_curva(i: int, p: Vector2) -> void:
	var c: Dictionary = ter.curve[i]
	var n: int = c.punti.size()
	var fine := _punto(c, n - 1)
	var prima := _punto(c, n - 2)
	var dir := (fine - prima)
	var lung := fine.distance_to(p)
	var c1 := fine + (dir.normalized() * lung / 3.0 if dir.length() > 0.5 else (p - fine) / 3.0)
	for q in [c1, fine.lerp(p, 2.0 / 3.0), p]:
		c.punti.append([snappedf(q.x, 0.1), snappedf(q.y, 0.1)])
	aggiorna_lati_curva(i)

func raddrizza_curva() -> void:
	if curva_sel < 0 or curva_sel >= ter.curve.size():
		_dici("Prima scegli un muro (Modifica).")
		return
	_inizia_tratto()
	var c: Dictionary = ter.curve[curva_sel]
	var k := 0
	while k + 3 < c.punti.size():
		var a := _punto(c, k)
		var b := _punto(c, k + 3)
		_metti_punto(c, k + 1, a.lerp(b, 1.0 / 3.0))
		_metti_punto(c, k + 2, a.lerp(b, 2.0 / 3.0))
		k += 3
	aggiorna_lati_curva(curva_sel)
	_fine_tratto()

func elimina_curva() -> void:
	if curva_sel < 0 or curva_sel >= ter.curve.size():
		_dici("Prima scegli un muro (Modifica).")
		return
	_inizia_tratto()
	_togli_lati_curva(curva_sel)
	ter.curve.remove_at(curva_sel)
	curva_sel = -1
	_fine_tratto()

# ------------------------------------------------------------------ edifici
func _stanza_in(p: Vector2) -> int:
	for i in range(d3.case.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(p, PackedVector2Array(_angoli(d3.case[i]))):
			return i
	return -1

## Parete più vicina a p: [stanza, lato, posizione 0–1 lungo il lato], o [] se troppo lontana.
func _parete_vicina(p: Vector2, solo := -1) -> Array:
	var migliore: Array = []
	var dmin := 30.0 / maxf(zoom, 0.05) * 0.5 + 18.0
	for i in d3.case.size():
		if solo >= 0 and i != solo:
			continue
		var an := _angoli(d3.case[i])
		for j in an.size():
			var a: Vector2 = an[j]
			var b: Vector2 = an[(j + 1) % an.size()]
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			var d := p.distance_to(q)
			if d < dmin:
				dmin = d
				migliore = [i, j, a.distance_to(q) / maxf(a.distance_to(b), 1.0)]
	return migliore

## Esagoni di edificio uniti a h (senza un muro scritto fra loro): un edificio per il motore.
func gruppo_edificio(h: String) -> Array:
	if not str(ter.esagoni.get(h, {}).get("t", "")) in EDIF:
		return []
	var out: Array = [h]
	var i := 0
	while i < out.size():
		var x: String = out[i]
		for v in E.vicini(x):
			if v in out or not str(ter.esagoni.get(v, {}).get("t", "")) in EDIF:
				continue
			if str(ter.lati.get(E.lato(x, v), "")) == "wall":
				continue
			out.append(v)
		i += 1
	return out

## Esagoni del motore che appartengono all'edificio di una stanza.
func esagoni_edificio_stanza(i: int) -> Array:
	var out: Array = []
	for h in d3.case[i].hex:
		for g in gruppo_edificio(str(h)):
			if not (g in out):
				out.append(g)
	return out

func _edifici(p: Vector2, h: String, inizio: bool) -> void:
	match attrezzo_ed:
		"sposta":
			if inizio:
				_trascina_angolo = -1
				_trascina_stanza = false
				if stanza_sel >= 0 and stanza_sel < d3.case.size():
					var an := _angoli(d3.case[stanza_sel])
					for j in an.size():
						if _sc(an[j]).distance_to(_sc(p)) < 22.0:
							_trascina_angolo = j
				if _trascina_angolo < 0:
					stanza_sel = _stanza_in(p)
					_trascina_stanza = stanza_sel >= 0
				_ultimo_px = p
				_aggiorna_info()
				return
			if stanza_sel < 0:
				return
			var st: Dictionary = d3.case[stanza_sel]
			var an := _angoli(st)
			if _trascina_angolo >= 0:
				if mantieni_rettangolo and an.size() == 4:
					an = _rettangolo_da_angolo(an, _trascina_angolo, p)
				else:
					an[_trascina_angolo] = p
				_imposta_angoli(st, an)
			elif _trascina_stanza:
				var dlt := p - _ultimo_px
				for j in an.size():
					an[j] += dlt
				_imposta_angoli(st, an)
			_ultimo_px = p
		"nuova":
			if not inizio:
				return
			var lato := 180.0
			var an: Array = [p + Vector2(-lato, -lato) / 2.0, p + Vector2(lato, -lato) / 2.0, p + Vector2(lato, lato) / 2.0, p + Vector2(-lato, lato) / 2.0]
			var st := {"tipo": "pietra", "hex": [], "angoli": [], "lati": [[[0.0, 1.0, "muro"]], [[0.0, 1.0, "muro"]], [[0.0, 1.0, "muro"]], [[0.0, 1.0, "muro"]]]}
			if stanza_sel >= 0 and stanza_sel < d3.case.size():
				st.tipo = d3.case[stanza_sel].tipo
			_imposta_angoli(st, an)
			d3.case.append(st)
			stanza_sel = d3.case.size() - 1
			attrezzo_ed = "sposta"
			_tavolozza()
		"esagoni":
			if inizio and h != "":
				alterna_esagono_edificio(h)
		"angolo_piu":
			if not inizio:
				return
			var pv := _parete_vicina(p, stanza_sel)
			if pv.is_empty():
				pv = _parete_vicina(p)
			if pv.is_empty():
				return
			stanza_sel = int(pv[0])
			aggiungi_angolo(stanza_sel, int(pv[1]), float(pv[2]))
		"angolo_meno":
			if not inizio:
				return
			var migliore := [-1, -1]
			var dmin := 24.0
			for i in d3.case.size():
				var an := _angoli(d3.case[i])
				for j in an.size():
					var d := _sc(an[j]).distance_to(_sc(p))
					if d < dmin:
						dmin = d
						migliore = [i, j]
			if migliore[0] >= 0:
				stanza_sel = migliore[0]
				togli_angolo(migliore[0], migliore[1])
		"muro", "finestra", "porta", "apri":
			var pv := _parete_vicina(p)
			if pv.is_empty():
				return
			var chiave := "%d_%d_%d" % [pv[0], pv[1], int(float(pv[2]) * 20.0)]
			if _toccato.has(chiave):
				return
			_toccato[chiave] = true
			stanza_sel = int(pv[0])
			var st: Dictionary = d3.case[pv[0]]
			var an := _angoli(st)
			var lung: float = (an[pv[1]] as Vector2).distance_to(an[(int(pv[1]) + 1) % an.size()])
			var largo: float = {"finestra": 56.0, "porta": 46.0, "muro": 50.0, "apri": 60.0}[attrezzo_ed] / maxf(lung, 1.0)
			var tipo: String = {"finestra": "finestra", "porta": "porta", "muro": "muro", "apri": "varco"}[attrezzo_ed]
			while st.lati.size() < an.size():
				st.lati.append([[0.0, 1.0, "muro"]])
			st.lati[pv[1]] = _metti_tratto(st.lati[pv[1]], clampf(float(pv[2]) - largo / 2.0, 0.0, 1.0), clampf(float(pv[2]) + largo / 2.0, 0.0, 1.0), tipo)
			_aggiorna_info()

## Inserisce un angolo sulla parete j della stanza i, alla posizione t (0–1): la parete si divide in due.
func aggiungi_angolo(i: int, j: int, t: float) -> void:
	var st: Dictionary = d3.case[i]
	var an := _angoli(st)
	t = clampf(t, 0.05, 0.95)
	var p: Vector2 = (an[j] as Vector2).lerp(an[(j + 1) % an.size()], t)
	while st.lati.size() < an.size():
		st.lati.append([[0.0, 1.0, "muro"]])
	var prima: Array = []
	var dopo: Array = []
	for sg in st.lati[j]:
		var a := float(sg[0])
		var b := float(sg[1])
		if a < t:
			prima.append([snappedf(a / t, 0.001), snappedf(minf(b, t) / t, 0.001), sg[2]])
		if b > t:
			dopo.append([snappedf((maxf(a, t) - t) / (1.0 - t), 0.001), snappedf((b - t) / (1.0 - t), 0.001), sg[2]])
	an.insert(j + 1, p)
	st.lati[j] = prima if not prima.is_empty() else [[0.0, 1.0, "muro"]]
	st.lati.insert(j + 1, dopo if not dopo.is_empty() else [[0.0, 1.0, "muro"]])
	_imposta_angoli(st, an)

## Toglie l'angolo j della stanza i (servono almeno tre angoli): le due pareti diventano una.
func togli_angolo(i: int, j: int) -> void:
	var st: Dictionary = d3.case[i]
	var an := _angoli(st)
	if an.size() <= 3:
		_dici("Una stanza ha almeno tre angoli.")
		return
	var n := an.size()
	var jp := (j - 1 + n) % n
	while st.lati.size() < n:
		st.lati.append([[0.0, 1.0, "muro"]])
	var l1 := (an[jp] as Vector2).distance_to(an[j])
	var l2 := (an[j] as Vector2).distance_to(an[(j + 1) % n])
	var tot := maxf(l1 + l2, 1.0)
	var k1 := l1 / tot
	var uniti: Array = []
	for sg in st.lati[jp]:
		uniti.append([snappedf(float(sg[0]) * k1, 0.001), snappedf(float(sg[1]) * k1, 0.001), sg[2]])
	for sg in st.lati[j]:
		uniti.append([snappedf(k1 + float(sg[0]) * (1.0 - k1), 0.001), snappedf(k1 + float(sg[1]) * (1.0 - k1), 0.001), sg[2]])
	st.lati[jp] = _metti_tratto(uniti, 0.0, 0.0, "muro")
	st.lati.remove_at(j)
	an.remove_at(j)
	_imposta_angoli(st, an)

## Mette o toglie un esagono dall'edificio (il terreno che usa il motore): diventa edificio del materiale della stanza
## scelta, oppure torna al terreno originale (o libero se anche l'originale era un edificio).
func alterna_esagono_edificio(h: String) -> void:
	var e := _esagono(h)
	if str(e.get("t", "")) in EDIF:
		var orig := str(ter_orig.get("esagoni", {}).get(h, {}).get("t", "clear"))
		e["t"] = orig if not orig in EDIF else "clear"
		e.erase("piani")
	else:
		var legno: bool = stanza_sel >= 0 and stanza_sel < d3.case.size() and str(d3.case[stanza_sel].tipo) == "legno"
		e["t"] = "wood_building" if legno else "stone_building"
		# un esagono che si unisce a un edificio a più piani ne prende i piani
		for v in E.vicini(h):
			var np := int(ter.esagoni.get(v, {}).get("piani", 1))
			if np > 1 and str(ter.esagoni.get(v, {}).get("t", "")) in EDIF:
				e["piani"] = np
		_svuota(h)

## La stanza scelta e il suo edificio tornano d'accordo: gli esagoni coperti dalla stanza sono edificio,
## quelli dell'edificio che nessuna stanza copre tornano al terreno originale (o libero).
func allinea_esagoni() -> void:
	if stanza_sel < 0 or stanza_sel >= d3.case.size():
		_dici("Prima scegli una stanza (attrezzo Sposta).")
		return
	_inizia_tratto()
	var st: Dictionary = d3.case[stanza_sel]
	var coperti := {}
	for c in d3.case:
		for h in c.hex:
			coperti[str(h)] = true
	# esagoni da rivedere: l'edificio attuale e gli esagoni di edificio rimasti senza stanza qui vicino
	# (dove la stanza stava prima di essere spostata)
	var gruppo := esagoni_edificio_stanza(stanza_sel)
	for h in E.tutti():
		if h in gruppo or coperti.has(h) or not str(ter.esagoni.get(h, {}).get("t", "")) in EDIF:
			continue
		for x in st.hex:
			if E.distanza(h, str(x)) <= 2:
				gruppo.append(h)
				break
	var tipo := "wood_building" if str(st.tipo) == "legno" else "stone_building"
	for h in st.hex:
		var e := _esagono(str(h))
		if not str(e.get("t", "")) in EDIF:
			e["t"] = tipo
			_svuota(str(h))
	for h in gruppo:
		if not coperti.has(h):
			var orig := str(ter_orig.get("esagoni", {}).get(h, {}).get("t", "clear"))
			_esagono(h)["t"] = orig if not orig in EDIF else "clear"
			_esagono(h).erase("piani")
	_fine_tratto()
	_dici("Esagoni dell'edificio: %s." % ", ".join(esagoni_edificio_stanza(stanza_sel)))

## Gli esagoni selezionati diventano un edificio in pietra, con una stanza che ne segue il contorno.
func edificio_da_selezione() -> void:
	if selezione.is_empty():
		_dici("Prima seleziona gli esagoni nel modo Terreno.")
		return
	_inizia_tratto()
	var poligoni: Array = []
	for h in selezione:
		var e := _esagono(str(h))
		e["t"] = "stone_building"
		_svuota(str(h))
		poligoni.append(_poligono_px(str(h), 1.02))
	# unisce gli esagoni vicini in un'unica pianta
	var uniti: Array = []
	for pol in poligoni:
		var cur: PackedVector2Array = pol
		var resto: Array = []
		for u in uniti:
			var m := Geometry2D.merge_polygons(cur, u)
			if m.size() == 1:
				cur = m[0]
			else:
				resto.append(u)
		resto.append(cur)
		uniti = resto
	for grezzo in uniti:
		# la pianta sta un po' dentro il bordo degli esagoni, come le case stampate
		var ridotti := Geometry2D.offset_polygon(grezzo, -RAGGIO * 0.18)
		if ridotti.is_empty():
			continue
		var semplice := _semplifica(ridotti[0])
		var an: Array = []
		for q in semplice:
			an.append(q)
		var lati: Array = []
		for _k in an.size():
			lati.append([[0.0, 1.0, "muro"]])
		var st := {"tipo": "pietra", "hex": [], "angoli": [], "lati": lati}
		_imposta_angoli(st, an)
		d3.case.append(st)
	stanza_sel = d3.case.size() - 1
	_fine_tratto()
	_dici("Nuovo edificio su %d esagoni." % selezione.size())

## Toglie dal contorno i punti quasi allineati (la pianta resta leggibile e con pochi angoli).
func _semplifica(pol: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pol.size()
	for i in n:
		var a := pol[(i - 1 + n) % n]
		var b := pol[i]
		var c := pol[(i + 1) % n]
		if absf((b - a).normalized().cross((c - b).normalized())) > 0.05:
			out.append(b)
	return out if out.size() >= 3 else pol

## Inserisce il tratto [t0, t1] di un tipo nella lista dei tratti di un lato, unendo quelli uguali vicini.
func _metti_tratto(segs: Array, t0: float, t1: float, tipo: String) -> Array:
	var out: Array = []
	for sg in segs:
		var a := float(sg[0])
		var b := float(sg[1])
		if b <= t0 or a >= t1:
			out.append([a, b, sg[2]])
			continue
		if a < t0:
			out.append([a, t0, sg[2]])
		if b > t1:
			out.append([t1, b, sg[2]])
	out.append([t0, t1, tipo])
	out.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var uniti: Array = []
	for sg in out:
		if float(sg[1]) - float(sg[0]) < 0.004:
			continue
		if not uniti.is_empty() and str(uniti[-1][2]) == str(sg[2]):
			uniti[-1][1] = sg[1]
		else:
			uniti.append([snappedf(float(sg[0]), 0.001), snappedf(float(sg[1]), 0.001), sg[2]])
	return uniti

## Trascinando un angolo la stanza resta un rettangolo: l'angolo opposto sta fermo, gli assi non cambiano.
func _rettangolo_da_angolo(an: Array, i: int, p: Vector2) -> Array:
	var o: Vector2 = an[(i + 2) % 4]
	var asse: Vector2 = ((an[(i + 2) % 4] as Vector2) - (an[(i + 1) % 4] as Vector2)).normalized()
	if asse.length() < 0.5:
		return an
	var out := an.duplicate()
	out[i] = p
	out[(i + 1) % 4] = p + asse * (o - p).dot(asse)
	out[(i + 3) % 4] = o - asse * (o - p).dot(asse)
	return out

func _materiale_stanza(m: String) -> void:
	if stanza_sel < 0 or stanza_sel >= d3.case.size():
		_dici("Prima scegli una stanza (attrezzo Sposta).")
		return
	_inizia_tratto()
	d3.case[stanza_sel].tipo = m
	# anche per il motore: gli esagoni dell'edificio cambiano materiale
	for h in esagoni_edificio_stanza(stanza_sel):
		_esagono(h)["t"] = "wood_building" if m == "legno" else "stone_building"
	_fine_tratto()
	_rid()

func _ruota_stanza(gradi: float) -> void:
	if stanza_sel < 0 or stanza_sel >= d3.case.size():
		_dici("Prima scegli una stanza (attrezzo Sposta).")
		return
	_inizia_tratto()
	var st: Dictionary = d3.case[stanza_sel]
	var an := _angoli(st)
	var c := Vector2.ZERO
	for q in an:
		c += q
	c /= float(an.size())
	for j in an.size():
		an[j] = c + (an[j] - c).rotated(deg_to_rad(gradi))
	_imposta_angoli(st, an)
	_fine_tratto()
	_rid()

## Rende la stanza un rettangolo esatto, con gli assi del suo lato più lungo.
func _raddrizza() -> void:
	if stanza_sel < 0 or stanza_sel >= d3.case.size():
		_dici("Prima scegli una stanza (attrezzo Sposta).")
		return
	var st: Dictionary = d3.case[stanza_sel]
	var an := _angoli(st)
	if an.size() != 4:
		_dici("Raddrizza vale per le stanze con quattro angoli.")
		return
	_inizia_tratto()
	var c := Vector2.ZERO
	for q in an:
		c += q
	c /= 4.0
	var u: Vector2 = ((an[1] as Vector2) - (an[0] as Vector2) + (an[2] as Vector2) - (an[3] as Vector2)).normalized()
	var v := u.orthogonal()
	var mu := 0.0
	var mv := 0.0
	for q in an:
		mu += absf((q - c).dot(u))
		mv += absf((q - c).dot(v))
	mu /= 4.0
	mv /= 4.0
	var nuovi: Array = []
	for q in an:
		var su := signf((q - c).dot(u))
		var sv := signf((q - c).dot(v))
		nuovi.append(c + u * su * mu + v * sv * mv)
	_imposta_angoli(st, nuovi)
	_fine_tratto()
	_rid()

func _elimina_stanza() -> void:
	if stanza_sel < 0 or stanza_sel >= d3.case.size():
		_dici("Prima scegli una stanza (attrezzo Sposta).")
		return
	_inizia_tratto()
	d3.case.remove_at(stanza_sel)
	stanza_sel = -1
	_fine_tratto()
	_rid()

# ------------------------------------------------------------------ piani e gallerie
func _piani_di(gruppo: Array) -> int:
	var n := 1
	for h in gruppo:
		n = maxi(n, int(ter.esagoni.get(str(h), {}).get("piani", 1)))
	return n

func _piani_gallerie(h: String) -> void:
	if h == "":
		return
	match attrezzo_piani:
		"piani":
			edificio_sel = gruppo_edificio(h)
			if ambito_piani == "esagono" and not edificio_sel.is_empty():
				edificio_sel = [h]
			if edificio_sel.is_empty():
				_dici("%s non è un edificio: i piani si danno agli esagoni di edificio." % h)
			_tavolozza()
		"gallerie":
			if galleria_sel < 0:
				nuova_galleria()
			alterna_esagono_galleria(galleria_sel, h)
			_tavolozza()
		"ingressi":
			if galleria_sel < 0:
				_dici("Prima crea una galleria.")
				return
			alterna_ingresso(galleria_sel, h)
			_tavolozza()

## Numero di piani dell'edificio scelto (1 o 2): vale per tutti i suoi esagoni.
func imposta_piani(n: int) -> void:
	if edificio_sel.is_empty():
		_dici("Prima tocca un edificio.")
		return
	_inizia_tratto()
	for h in edificio_sel:
		if n > 1:
			_esagono(str(h))["piani"] = n
		else:
			_esagono(str(h)).erase("piani")
	_fine_tratto()
	_tavolozza()
	_dici("Edificio %s: %d %s." % [", ".join(edificio_sel), n, "piano" if n == 1 else "piani"])

func nuova_galleria() -> void:
	_inizia_tratto()
	ter.gallerie.append({"nome": "Galleria %d" % (ter.gallerie.size() + 1), "esagoni": [], "ingressi": [], "missioni": []})
	galleria_sel = ter.gallerie.size() - 1
	_fine_tratto()
	attrezzo_piani = "gallerie"
	_tavolozza()

func elimina_galleria() -> void:
	if galleria_sel < 0 or galleria_sel >= ter.gallerie.size():
		return
	_inizia_tratto()
	ter.gallerie.remove_at(galleria_sel)
	galleria_sel = ter.gallerie.size() - 1
	_fine_tratto()
	_tavolozza()

## Toglie h dalla galleria se c'è; altrimenti lo aggiunge al capo a cui è vicino (in fondo, se non tocca nessuno dei due).
func alterna_esagono_galleria(i: int, h: String) -> void:
	_inizia_tratto()
	var g: Dictionary = ter.gallerie[i]
	var es: Array = g.esagoni
	if h in es:
		es.erase(h)
		(g.ingressi as Array).erase(h)
	elif not es.is_empty() and E.adiacenti(h, str(es[0])) and not E.adiacenti(h, str(es[-1])):
		es.insert(0, h)
	else:
		es.append(h)
	_fine_tratto()

func alterna_ingresso(i: int, h: String) -> void:
	var g: Dictionary = ter.gallerie[i]
	if not (h in g.esagoni):
		_dici("Un ingresso deve essere un esagono della galleria.")
		return
	_inizia_tratto()
	if h in g.ingressi:
		(g.ingressi as Array).erase(h)
	else:
		(g.ingressi as Array).append(h)
	_fine_tratto()

func _cambia_galleria(campo: String, testo: String) -> void:
	if galleria_sel < 0 or galleria_sel >= ter.gallerie.size():
		return
	var g: Dictionary = ter.gallerie[galleria_sel]
	var valore
	if campo == "missioni":
		var l: Array = []
		for x in testo.replace(";", ",").split(",", false):
			if x.strip_edges().is_valid_int():
				l.append(int(x.strip_edges()))
		valore = l
	else:
		valore = testo.strip_edges()
	if str(g.get(campo, "")) == str(valore):
		return
	_inizia_tratto()
	g[campo] = valore
	_fine_tratto()

# ------------------------------------------------------------------ informazioni
func _aggiorna_info() -> void:
	if info == null:
		return
	var parti: Array = []
	if sopra != "":
		var e: Dictionary = ter.get("esagoni", {}).get(sopra, {})
		var np := int(e.get("piani", 1))
		parti.append("%s · %s · livello %d%s%s%s" % [sopra, TerrenoScript.NOMI.get(str(e.get("t", "clear")), str(e.get("t", ""))), int(e.get("q", 1)),
			" · ponte" if bool(e.get("ponte", false)) else "", (" · %d piani" % np) if np > 1 else "",
			(" · da controllare: " + str(sospetti[sopra])) if sospetti.has(sopra) else ""])
	if modo == "edifici" and stanza_sel >= 0 and stanza_sel < d3.case.size():
		var st: Dictionary = d3.case[stanza_sel]
		parti.append("stanza in %s su %s; edificio: %s" % [str(st.tipo), ", ".join(st.hex), ", ".join(esagoni_edificio_stanza(stanza_sel))])
	elif modo == "curve" and curva_sel >= 0 and curva_sel < ter.curve.size():
		parti.append("muro scelto: %d lati di esagono" % (ter.curve[curva_sel].get("lati", []) as Array).size())
	parti.append("%d stanze, %d muri curvi, %d gallerie, %d esagoni da controllare" % [d3.get("case", []).size(), ter.get("curve", []).size(), ter.get("gallerie", []).size(), sospetti.size()])
	info.text = "   ".join(parti)

# ------------------------------------------------------------------ 3D
func _alterna_3d() -> void:
	var on := bottone_3d.button_pressed
	vista3d_box.visible = on
	tela.visible = not on
	strato_dati.visible = not on
	strato_attrezzi.visible = not on
	_barra_strati.visible = not on
	if on:
		_ricostruisci_3d()
		_dici("Vista 3D: per modificare torna al 2D.")
	else:
		_dici("")

## Anteprima 3D: una partita vuota sulla mappa scelta, con la vista 3D del gioco.
func _ricostruisci_3d() -> void:
	if mappa3d_ctrl != null:
		mappa3d_ctrl.queue_free()
		mappa3d_ctrl = null
	var n: int = {"a": 6, "b": 2, "ad": 6, "c": 14, "be": 17, "f": 20, "fh": 19, "fg": 21, "gh": 24}.get(lettera, 6)
	var p := Partita.new(n)
	p.missione = p.missione.duplicate()
	p.missione["mappa"] = lettera.to_upper()
	p.terreno = TerrenoScript.new("res://data/mappa_%s.json" % lettera)
	p.nuova(1, true)
	# solo la mappa: niente soldati schierati, segnalini, mezzi o modifiche della missione
	for id in p.s.unita:
		p.s.unita[id].hex = ""
	for k in ["modifiche", "oggetti", "punti", "veicoli"]:
		p.s[k] = {}
	p.terreno.imposta_modifiche(p.s.modifiche)
	var m = MappaScript.new()
	m.partita = p
	m.senza_pedine = true
	vista3d_box.add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mappa3d_ctrl = m
	m.imposta_3d(true)

# ------------------------------------------------------------------ esporta, importa, ripristina
func esporta() -> void:
	var pac := DM.pacchetto()
	if (pac.mappe as Dictionary).is_empty():
		_dici("Non ci sono mappe corrette da esportare.")
		return
	var testo := JSON.stringify(pac)
	var nome := "ambush_mappe_corrette.json"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(testo.to_utf8_buffer(), nome, "application/json")
		_dici("File «%s» scaricato: mandamelo e porto le correzioni nel gioco." % nome)
		return
	var cartella := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if cartella == "":
		cartella = OS.get_user_data_dir()
	var percorso := cartella.path_join(nome)
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	if f == null:
		_dici("Non riesco a scrivere il file.")
		return
	f.store_string(testo)
	f.close()
	_dici("Salvato in %s" % percorso)

var _attesa_import := false

func importa() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			window.__ambush_import = null;
			var i = document.createElement('input');
			i.type = 'file'; i.accept = '.json,application/json';
			i.onchange = function(e) {
				var f = e.target.files[0]; if (!f) return;
				var r = new FileReader();
				r.onload = function() { window.__ambush_import = r.result; };
				r.readAsText(f);
			};
			i.click();
		""", true)
		_attesa_import = true
		_dici("Scegli il file da importare.")
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.filters = PackedStringArray(["*.json"])
	fd.file_selected.connect(func(percorso): _importa_testo(FileAccess.get_file_as_string(percorso)); fd.queue_free())
	fd.canceled.connect(func(): fd.queue_free())
	add_child(fd)
	fd.popup_centered(Vector2i(900, 600))

func _process(_d: float) -> void:
	if _attesa_import and OS.has_feature("web"):
		var r = JavaScriptBridge.eval("window.__ambush_import", true)
		if r != null and str(r) != "" and str(r) != "<null>":
			_attesa_import = false
			JavaScriptBridge.eval("window.__ambush_import = null;", true)
			_importa_testo(str(r))

func _importa_testo(t: String) -> void:
	var n := DM.importa(t)
	if n < 0:
		_dici("Il file non contiene mappe di Ambush!.")
		return
	cambiate = true
	carica(lettera)
	_dici("Importate %d parti di mappa." % n)

func _chiedi_ripristino() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Mappa originale"
	dlg.dialog_text = "Buttare via tutte le correzioni della mappa %s?" % lettera.to_upper()
	dlg.ok_button_text = "Sì, torna all'originale"
	dlg.cancel_button_text = "No"
	dlg.confirmed.connect(func():
		DM.cancella("mappa_%s" % lettera)
		DM.cancella("mappa_%s_3d" % lettera)
		cambiate = true
		carica(lettera)
		dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

func chiudi() -> void:
	chiuso.emit(cambiate)
	queue_free()
