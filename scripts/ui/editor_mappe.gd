extends Control
## Editor delle mappe: si correggono a mano terreno, quote, lati, ponti, vegetazione ed edifici.
## Le correzioni restano sul dispositivo (DatiMappe, user://mappe) e valgono subito nel gioco;
## «Esporta» le raccoglie in un file da mandare per portarle nel progetto.

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
	["monument", Color(0.85, 0.8, 0.7)],
]
const LATI := [
	["", "nessuno (automatico)", Color(1, 1, 1, 0.0)], ["crest", "cresta", Color(0.55, 0.3, 0.1)],
	["embankment", "massicciata", Color(0.95, 0.55, 0.1)], ["wall", "muro", Color(0.75, 0.1, 0.1)],
	["window", "finestra", Color(0.1, 0.85, 0.95)], ["door", "porta", Color(0.2, 0.85, 0.25)],
]
const MODI := [["terreno", "Terreno"], ["quota", "Quote"], ["lati", "Lati"], ["ponti", "Ponti"], ["vegetazione", "Alberi"], ["edifici", "Edifici"]]

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

var _annulla: Array = []
var _istantanea = null
var _tratto := false
var _trascina_angolo := -1
var _trascina_stanza := false
var _ultimo_px := Vector2.ZERO
var _toccato := {}

var tela: Control
var tavolozza: VBoxContainer
var info: Label
var scelta_mappa: OptionButton
var _bottoni_modo := {}
var vista3d_box: Control
var mappa3d_ctrl = null
var bottone_3d: Button
var _messaggio: Label

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
	r1.add_child(Tema.titolo("EDITOR DELLE MAPPE", 22, Tema.OTTONE))
	scelta_mappa = OptionButton.new()
	scelta_mappa.focus_mode = Control.FOCUS_NONE
	scelta_mappa.custom_minimum_size = Vector2(230, 36)
	for l in DM.MAPPE:
		scelta_mappa.add_item(DM.MAPPE[l])
		scelta_mappa.set_item_metadata(scelta_mappa.item_count - 1, l)
	scelta_mappa.item_selected.connect(func(i): carica(str(scelta_mappa.get_item_metadata(i))))
	r1.add_child(scelta_mappa)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(sp)
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
	# Riga 2: modi
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	vb.add_child(r2)
	var gruppo := ButtonGroup.new()
	for m in MODI:
		var b := Tema.bottone(m[1], _imposta_modo.bind(m[0]))
		b.toggle_mode = true
		b.button_group = gruppo
		b.custom_minimum_size = Vector2(96, 36)
		r2.add_child(b)
		_bottoni_modo[m[0]] = b
	_messaggio = Tema.etichetta("", Tema.testo, 14, Tema.OTTONE)
	_messaggio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messaggio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_messaggio.clip_text = true
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
	tela.draw.connect(_disegna)
	tela.gui_input.connect(_input_tela)
	tela.resized.connect(_limita)
	tela.mouse_exited.connect(func(): sopra = ""; _aggiorna_info())
	vista3d_box = Control.new()
	vista3d_box.visible = false
	vista3d_box.clip_contents = true
	area.add_child(vista3d_box)
	vista3d_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info = Tema.etichetta("", Tema.testo, 15, Tema.KAKI)
	info.clip_text = true
	info.custom_minimum_size = Vector2(100, 24)
	destra.add_child(info)
	_bottoni_modo["terreno"].button_pressed = true
	carica("a")

# ------------------------------------------------------------------ dati
func carica(l: String) -> void:
	lettera = l
	for i in scelta_mappa.item_count:
		if str(scelta_mappa.get_item_metadata(i)) == l:
			scelta_mappa.select(i)
	ter = DM.leggi("mappa_%s" % l).duplicate(true)
	d3 = DM.leggi("mappa_%s_3d" % l).duplicate(true)
	ter_orig = DM.originale("mappa_%s" % l)
	for k in ["alberi", "cespugli", "ciuffi", "case", "vigne"]:
		if not d3.has(k):
			d3[k] = []
	trama = load("res://assets/maps/mappa_%s.jpg" % l)
	_annulla.clear()
	stanza_sel = -1
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
	DM.scrivi("mappa_%s" % lettera, ter)
	DM.scrivi("mappa_%s_3d" % lettera, d3)
	cambiate = true

func _inizia_tratto() -> void:
	_istantanea = [ter.duplicate(true), d3.duplicate(true)]
	_tratto = true

func _fine_tratto() -> void:
	if not _tratto:
		return
	_tratto = false
	if _istantanea != null and (JSON.stringify(_istantanea[0]) != JSON.stringify(ter) or JSON.stringify(_istantanea[1]) != JSON.stringify(d3)):
		_annulla.append(_istantanea)
		if _annulla.size() > 40:
			_annulla.pop_front()
		_salva()
	_istantanea = null
	_ricalcola_sospetti()
	_aggiorna_info()

## Un secondo dito durante un tratto: era un pizzico, si annulla quello che il primo dito aveva fatto.
func _annulla_tratto() -> void:
	if _tratto and _istantanea != null:
		ter = _istantanea[0]
		d3 = _istantanea[1]
	_tratto = false
	_istantanea = null
	_trascina_angolo = -1
	_trascina_stanza = false
	tela.queue_redraw()

func annulla() -> void:
	if _annulla.is_empty():
		_dici("Niente da annullare.")
		return
	var s: Array = _annulla.pop_back()
	ter = s[0]
	d3 = s[1]
	stanza_sel = mini(stanza_sel, d3.case.size() - 1)
	_salva()
	_ricalcola_sospetti()
	tela.queue_redraw()
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
		var edificio := t in ["stone_building", "wood_building"]
		if dentro and not edificio and t != "rubble":
			sospetti[h] = "stanza su %s" % TerrenoScript.NOMI.get(t, t)
		elif edificio and not dentro:
			sospetti[h] = "edificio senza stanza 3D"

func _dici(t: String) -> void:
	_messaggio.text = t

# ------------------------------------------------------------------ tavolozza
func _imposta_modo(m: String) -> void:
	modo = m
	_tavolozza()
	tela.queue_redraw()

func _titolo_tav(t: String) -> void:
	var l := Tema.etichetta(t, Tema.testo_bold, 14, Tema.OTTONE)
	tavolozza.add_child(l)

func _spiega(t: String) -> void:
	var l := Tema.etichetta(t, Tema.testo, 13, Tema.KAKI_SPENTO)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	tavolozza.add_child(l)

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
		if colonne == 1:
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if colori.has(v[0]):
			var c: Color = colori[v[0]]
			var st := Tema.scatola(Color("3b4230"), c, 3, 3, 6)
			b.add_theme_stylebox_override("normal", st)
			var stp := Tema.scatola(Color("2a2f20"), Tema.OTTONE, 3, 3, 6)
			b.add_theme_stylebox_override("pressed", stp)
		griglia.add_child(b)

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

func _tavolozza() -> void:
	for c in tavolozza.get_children():
		c.queue_free()
	match modo:
		"terreno":
			_titolo_tav("TIPO DI TERRENO")
			_spiega("Tocca o trascina sugli esagoni per dipingerli. Due dita: sposti e ingrandisci la mappa.")
			var voci: Array = []
			var colori := {}
			for t in TIPI:
				voci.append([t[0], TerrenoScript.NOMI.get(t[0], t[0])])
				colori[t[0]] = t[1]
			_scelte(voci, tipo_terreno, func(v): tipo_terreno = v, colori, 1)
			_spunta("Aggiorna alberi e cespugli (bosco e macchia si riempiono, il terreno libero si svuota)", auto_vegetazione, func(v): auto_vegetazione = v)
			_spunta("Segna con «?» gli esagoni da controllare (stanza 3D su un terreno che non è edificio, o edificio senza stanza)", mostra_sospetti, func(v): mostra_sospetti = v; tela.queue_redraw())
		"quota":
			_titolo_tav("QUOTA DELL'ESAGONO")
			_spiega("Ogni esagono mostra il suo livello. Tocca o trascina per assegnare quello scelto.")
			var voci: Array = []
			for q in range(0, 6):
				voci.append([str(q), "Livello %d" % q])
			_scelte(voci, str(quota_scelta), func(v): quota_scelta = int(v))
		"lati":
			_titolo_tav("LATO DELL'ESAGONO")
			_spiega("Tocca vicino al bordo tra due esagoni. I muri degli edifici sono automatici: qui si aggiungono creste, massicciate, finestre e porte, o un muro dove manca.")
			var voci: Array = []
			var colori := {}
			for t in LATI:
				voci.append([t[0], t[1]])
				colori[t[0]] = t[2]
			_scelte(voci, tipo_lato, func(v): tipo_lato = v, colori, 1)
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
			s.value_changed.connect(func(v): raggio_pennello = v; tela.queue_redraw())
			tavolozza.add_child(s)
		"edifici":
			_titolo_tav("EDIFICI")
			_spiega("Ogni edificio è fatto di stanze. Sposta: tocca una stanza per sceglierla, trascina i quadratini degli angoli o l'interno per spostarla. Muro, finestra e porta: tocca lungo una parete per cambiarla.")
			_scelte([["sposta", "Sposta"], ["nuova", "Nuova stanza"], ["muro", "Muro"], ["finestra", "Finestra"], ["porta", "Porta"], ["apri", "Varco"]], attrezzo_ed, func(v): attrezzo_ed = v; tela.queue_redraw())
			_spunta("Angoli ad angolo retto (la stanza resta un rettangolo)", mantieni_rettangolo, func(v): mantieni_rettangolo = v)
			_titolo_tav("STANZA SCELTA")
			var g := GridContainer.new()
			g.columns = 2
			g.add_theme_constant_override("h_separation", 4)
			g.add_theme_constant_override("v_separation", 4)
			tavolozza.add_child(g)
			for v in [["Pietra", func(): _materiale_stanza("pietra")], ["Legno", func(): _materiale_stanza("legno")],
					["Ruota -", func(): _ruota_stanza(-2.0)], ["Ruota +", func(): _ruota_stanza(2.0)],
					["Raddrizza", _raddrizza], ["Elimina", _elimina_stanza]]:
				var b := Tema.bottone(v[0], v[1])
				b.custom_minimum_size = Vector2(102, 34)
				b.add_theme_font_size_override("font_size", 13)
				g.add_child(b)
	_aggiorna_info()

# ------------------------------------------------------------------ vista 2D
func _centra() -> void:
	if trama == null or tela.size.x < 10:
		call_deferred("_centra_dopo")
		return
	zoom = minf(tela.size.x / trama.get_width(), tela.size.y / trama.get_height())
	spostamento = (tela.size - Vector2(trama.get_size()) * zoom) / 2.0
	tela.queue_redraw()

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
	tela.queue_redraw()

func _px(pos: Vector2) -> Vector2:
	return (pos - spostamento) / zoom

func _sc(p: Vector2) -> Vector2:
	return spostamento + p * zoom

func esagono_px(p: Vector2) -> String:
	return E.a_punto(Vector2((p.x / 0.6 - 307.0) / 270.8 * 1.5, (p.y / 0.6 - 272.0) / 314.0 * E.SQRT3))

func _poligono_hex(h: String) -> PackedVector2Array:
	var c := MappaScript.centro_tex(h)
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i)
		pts.append(_sc(c + Vector2(cos(a), sin(a)) * RAGGIO))
	return pts

func _colore_tipo(t: String) -> Color:
	for x in TIPI:
		if x[0] == t:
			return x[1]
	return Color.MAGENTA

func _disegna() -> void:
	if trama == null:
		return
	tela.draw_texture_rect(trama, Rect2(spostamento, Vector2(trama.get_size()) * zoom), false)
	var font := Tema.testo_bold
	var dim_testo := int(clampf(RAGGIO * zoom * 0.42, 9.0, 30.0))
	var esagoni: Dictionary = ter.get("esagoni", {})
	for h in E.tutti():
		var pol := _poligono_hex(h)
		if not Rect2(Vector2.ZERO, tela.size).grow(RAGGIO * zoom).has_point(pol[0]):
			continue
		var dati: Dictionary = esagoni.get(h, {})
		var orig: Dictionary = ter_orig.get("esagoni", {}).get(h, {})
		match modo:
			"terreno":
				var c := _colore_tipo(str(dati.get("t", "clear")))
				c.a = 0.0 if str(dati.get("t", "clear")) == "clear" else 0.38
				tela.draw_colored_polygon(pol, c)
			"quota":
				var q := int(dati.get("q", 1))
				var c := Color.from_hsv(0.08, 0.6, clampf(0.25 + q * 0.17, 0.0, 1.0), 0.33)
				tela.draw_colored_polygon(pol, c)
				var cen := _sc(MappaScript.centro_tex(h))
				_testo_centrato(cen, str(q), dim_testo * 2, Color.WHITE)
			"ponti":
				if bool(dati.get("ponte", false)):
					tela.draw_colored_polygon(pol, Color(0.95, 0.75, 0.1, 0.45))
					_testo_centrato(_sc(MappaScript.centro_tex(h)), "PONTE", dim_testo, Color.BLACK)
		var diverso := str(dati.get("t", "")) != str(orig.get("t", "")) or int(dati.get("q", 1)) != int(orig.get("q", 1)) or bool(dati.get("ponte", false)) != bool(orig.get("ponte", false))
		var bordo := PackedVector2Array(pol)
		bordo.append(pol[0])
		if diverso:
			tela.draw_polyline(bordo, Color(1.0, 0.85, 0.1), maxf(2.0, 4.0 * zoom * 3.0))
		elif zoom > 0.12:
			tela.draw_polyline(bordo, Color(0, 0, 0, 0.18), 1.0)
	if mostra_sospetti and modo in ["terreno", "edifici"]:
		for h in sospetti:
			var c := _sc(MappaScript.centro_tex(h))
			tela.draw_circle(c, maxf(7.0, RAGGIO * zoom * 0.22), Color(0.95, 0.35, 0.05, 0.85))
			_testo_centrato(c, "?", int(maxf(12.0, RAGGIO * zoom * 0.3)), Color.WHITE)
	if sopra != "":
		var pol := _poligono_hex(sopra)
		pol.append(pol[0])
		tela.draw_polyline(pol, Color.WHITE, 3.0)
	match modo:
		"lati":
			_disegna_lati()
		"vegetazione":
			_disegna_vegetazione()
		"edifici":
			_disegna_edifici()
	if modo == "vegetazione" and attrezzo_veg in ["albero", "cespuglio", "gomma"] and _ultimo_px != Vector2.ZERO:
		var r: float = raggio_pennello if attrezzo_veg == "gomma" else (raggio_pennello * 0.6 if attrezzo_veg == "albero" else raggio_pennello * 0.3)
		tela.draw_arc(_sc(_ultimo_px), r * zoom, 0, TAU, 40, Color.WHITE, 2.0)

func _testo_centrato(c: Vector2, t: String, dim: int, col: Color) -> void:
	var f := Tema.testo_bold
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x
	tela.draw_string_outline(f, c + Vector2(-w / 2.0, dim * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim, 4, Color(0, 0, 0, 0.6) if col != Color.BLACK else Color(1, 1, 1, 0.6))
	tela.draw_string(f, c + Vector2(-w / 2.0, dim * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, dim, col)

func _estremi_lato(a: String, b: String) -> Array:
	var ca := MappaScript.centro_tex(a)
	var cb := MappaScript.centro_tex(b)
	var mezzo := (ca + cb) / 2.0
	var dir := (cb - ca).normalized().orthogonal()
	return [mezzo - dir * RAGGIO * 0.5, mezzo + dir * RAGGIO * 0.5]

func _disegna_lati() -> void:
	var lati: Dictionary = ter.get("lati", {})
	var esagoni: Dictionary = ter.get("esagoni", {})
	var edif := ["stone_building", "wood_building", "bunker"]
	# muri automatici: tra un edificio e ciò che non lo è
	for h in E.tutti():
		if not str(esagoni.get(h, {}).get("t", "")) in edif:
			continue
		for v in E.vicini(h):
			if str(esagoni.get(v, {}).get("t", "")) in edif or lati.has(E.lato(h, v)):
				continue
			var es := _estremi_lato(h, v)
			tela.draw_line(_sc(es[0]), _sc(es[1]), Color(0.75, 0.1, 0.1, 0.45), maxf(2.0, 10.0 * zoom))
	for k in lati:
		var parti := str(k).split("|")
		if parti.size() != 2:
			continue
		var col := Color.MAGENTA
		for t in LATI:
			if t[0] == str(lati[k]):
				col = t[2]
		var es := _estremi_lato(parti[0], parti[1])
		tela.draw_line(_sc(es[0]), _sc(es[1]), Color(0, 0, 0, 0.6), maxf(4.0, 22.0 * zoom))
		tela.draw_line(_sc(es[0]), _sc(es[1]), col, maxf(3.0, 16.0 * zoom))

func _disegna_vegetazione() -> void:
	for a in d3.alberi:
		tela.draw_circle(_sc(Vector2(a[0], a[1])), maxf(2.0, float(a[2]) * zoom), Color(0.05, 0.4, 0.05, 0.55))
	for c in d3.cespugli:
		tela.draw_circle(_sc(Vector2(c[0], c[1])), maxf(1.5, float(c[2]) * zoom), Color(0.6, 0.7, 0.1, 0.6))
	for c in d3.ciuffi:
		tela.draw_circle(_sc(Vector2(c[0], c[1])), maxf(1.0, 6.0 * zoom), Color(0.9, 0.85, 0.3, 0.7))

const COLORI_PARETE := {"muro": Color(0.6, 0.08, 0.08), "finestra": Color(0.1, 0.85, 0.95), "porta": Color(0.2, 0.9, 0.25), "varco": Color(1, 1, 1, 0.8)}

func _disegna_edifici() -> void:
	for i in d3.case.size():
		var st: Dictionary = d3.case[i]
		var an := _angoli(st)
		var pol := PackedVector2Array()
		for p in an:
			pol.append(_sc(p))
		var fondo := Color(0.3, 0.45, 0.6, 0.22) if str(st.tipo) == "pietra" else Color(0.6, 0.38, 0.15, 0.22)
		if i == stanza_sel:
			fondo.a = 0.4
		tela.draw_colored_polygon(pol, fondo)
		for j in an.size():
			var p: Vector2 = an[j]
			var q: Vector2 = an[(j + 1) % an.size()]
			var segs: Array = st.lati[j] if j < st.lati.size() else [[0.0, 1.0, "muro"]]
			for sg in segs:
				var a := p.lerp(q, float(sg[0]))
				var b := p.lerp(q, float(sg[1]))
				var col: Color = COLORI_PARETE.get(str(sg[2]), Color.MAGENTA)
				tela.draw_line(_sc(a), _sc(b), col, maxf(2.5, 12.0 * zoom))
		if i == stanza_sel:
			for p in an:
				var r := Rect2(_sc(p) - Vector2(9, 9), Vector2(18, 18))
				tela.draw_rect(r, Color.WHITE)
				tela.draw_rect(r, Color.BLACK, false, 2.0)

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
		tela.queue_redraw()
	elif ev is InputEventMagnifyGesture:
		_zoom_a((ev as InputEventMagnifyGesture).factor, (ev as InputEventMagnifyGesture).position)
	elif ev is InputEventPanGesture:
		spostamento -= (ev as InputEventPanGesture).delta * 12.0
		_limita()

## Applica l'attrezzo nel punto p (pixel della mappa); «inizio» alla pressione, poi ad ogni movimento.
func _applica(p: Vector2, inizio: bool) -> void:
	var h := esagono_px(p)
	match modo:
		"terreno":
			if h != "" and not _toccato.has(h):
				_toccato[h] = true
				_dipingi_tipo(h)
		"quota":
			if h != "":
				_esagono(h)["q"] = quota_scelta
		"ponti":
			if h != "" and inizio:
				var e := _esagono(h)
				if bool(e.get("ponte", false)):
					e.erase("ponte")
				else:
					e["ponte"] = true
		"lati":
			_dipingi_lato(p)
		"vegetazione":
			_vegetazione(p, h, inizio)
		"edifici":
			_edifici(p, inizio)
	tela.queue_redraw()

func _esagono(h: String) -> Dictionary:
	if not ter.esagoni.has(h):
		ter.esagoni[h] = {"t": "clear", "q": 1}
	return ter.esagoni[h]

func _dipingi_tipo(h: String) -> void:
	var e := _esagono(h)
	if str(e.get("t", "")) == tipo_terreno:
		return
	e["t"] = tipo_terreno
	if auto_vegetazione:
		match tipo_terreno:
			"woods":
				_riempi(h, true)
			"brush":
				_riempi(h, false)
			"clear", "road", "stream", "water", "beach", "wharf", "subpen", "stone_building", "wood_building", "bunker", "fuel_tank", "monument", "crater":
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

func _vegetazione(p: Vector2, h: String, inizio: bool) -> void:
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

# ------------------------------------------------------------------ edifici
func _stanza_in(p: Vector2) -> int:
	for i in range(d3.case.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(p, PackedVector2Array(_angoli(d3.case[i]))):
			return i
	return -1

## Parete più vicina a p: [stanza, lato, posizione 0–1 lungo il lato], o [] se troppo lontana.
func _parete_vicina(p: Vector2) -> Array:
	var migliore: Array = []
	var dmin := 30.0 / maxf(zoom, 0.05) * 0.5 + 18.0
	for i in d3.case.size():
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

func _edifici(p: Vector2, inizio: bool) -> void:
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
	_fine_tratto()
	tela.queue_redraw()

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
	tela.queue_redraw()

## Rende la stanza un rettangolo esatto, con gli assi del suo lato più lungo.
func _raddrizza() -> void:
	if stanza_sel < 0 or stanza_sel >= d3.case.size():
		_dici("Prima scegli una stanza (attrezzo Sposta).")
		return
	var st: Dictionary = d3.case[stanza_sel]
	var an := _angoli(st)
	if an.size() != 4:
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
	tela.queue_redraw()

func _elimina_stanza() -> void:
	if stanza_sel < 0 or stanza_sel >= d3.case.size():
		_dici("Prima scegli una stanza (attrezzo Sposta).")
		return
	_inizia_tratto()
	d3.case.remove_at(stanza_sel)
	stanza_sel = -1
	_fine_tratto()
	tela.queue_redraw()

# ------------------------------------------------------------------ informazioni
func _aggiorna_info() -> void:
	if info == null:
		return
	var parti: Array = []
	if sopra != "":
		var e: Dictionary = ter.get("esagoni", {}).get(sopra, {})
		parti.append("%s · %s · livello %d%s%s" % [sopra, TerrenoScript.NOMI.get(str(e.get("t", "clear")), str(e.get("t", ""))), int(e.get("q", 1)), " · ponte" if bool(e.get("ponte", false)) else "",
			(" · da controllare: " + str(sospetti[sopra])) if sospetti.has(sopra) else ""])
	if modo == "edifici" and stanza_sel >= 0 and stanza_sel < d3.case.size():
		var st: Dictionary = d3.case[stanza_sel]
		parti.append("stanza in %s di %s (%s)" % [str(st.tipo), ", ".join(st.hex), "esagoni coperti"])
	parti.append("%d alberi, %d cespugli, %d stanze, %d esagoni da controllare" % [d3.get("alberi", []).size(), d3.get("cespugli", []).size(), d3.get("case", []).size(), sospetti.size()])
	info.text = "   ".join(parti)

# ------------------------------------------------------------------ 3D
func _alterna_3d() -> void:
	var on := bottone_3d.button_pressed
	vista3d_box.visible = on
	tela.visible = not on
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
	var n: int = {"a": 6, "b": 2, "ad": 6, "c": 14, "be": 17}.get(lettera, 6)
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
