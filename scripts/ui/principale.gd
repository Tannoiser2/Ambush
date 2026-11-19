extends Control
## Interfaccia principale: barra delle fasi, scheda della squadra, mappa, scheda dell’azione e comandi,
## pista dei Round, situazione e rapporto.
## Ogni comando del motore viene riprodotto a passi: una fase o un attore alla volta, con la scheda
## dell’azione che dice chi agisce, perché e con quale esito, e i pannelli allineati a ciò che si vede.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")
const MappaScript = preload("res://scripts/ui/mappa.gd")
const PistaScript = preload("res://scripts/ui/pista.gd")
const FasiScript = preload("res://scripts/ui/fasi.gd")
const TabellaScript = preload("res://scripts/ui/tabella_carta.gd")
const SALVATAGGIO := "user://ambush_missione1.json"
const PREFERENZE := "user://ambush_preferenze.json"

const C_CHIARO := "f0e7c9"
const C_TENUE := "a39b78"
const C_ROSSO := "ff8c7a"
const C_VERDE := "b9e08f"
const C_USA := "e6da6a"
const C_DE := "b9cfe0"

var p: Partita
var mappa: Control
var pista: Control
var fasi: Control
var selezione: Array = []
var modo := ""          # "", mirato, rapido, granata, satchel, trascina, cedi, sveglia
var arma_scelta := {}   # id soldato → tipo arma
var _ultimo_click := ""
var _indice_click := 0

# nodi
var lista_squadra: VBoxContainer
var barra_cond: Label
var barra_pv: Label
var caselle_avv: Array = []
var box_comandi: VBoxContainer
var box_scheda: HBoxContainer
var titolo_azioni: Label
var aiuto_azioni: Label
var flusso_azioni: HFlowContainer
var info_hex: Label
var rapporto: RichTextLabel
var titolo_rapporto: Label
var carte_box: HFlowContainer
var obiettivi_box: HFlowContainer
var velo: ColorRect
var finestra: PanelContainer
var menu_bersagli: PopupMenu
# scheda dell’azione
var sch_pedina: TextureRect
var sch_titolo: Label
var sch_sotto: Label
var sch_perche_titolo: Label
var sch_tabella: Control
var sch_perche: RichTextLabel
var sch_esito: RichTextLabel
var sch_continua: Button
var sch_modo: Button
var sch_velocita: Button
var sch_salta: Button
var _perche_righe: Array = []
var _perche_par: Array = []
var _tipo_passo := ""
var _esito_righe: Array = []

# riproduzione
var riproducendo := false
var automatico := false
var _salta_tutto := false
var _salta_passo := false
var _avanti := false
var _in_attesa := false
## Stato mostrato dai pannelli durante la riproduzione (vuoto: stato reale).
var stato_vis: Dictionary = {}
var _chiave_fase := ""
var _lotto := 0
var _mostrate := 0
var _titolo_lotto := ""
var _ultima_sequenza: Array = []
var _ultima_vista: Dictionary = {}
var _ultimo_stato: Dictionary = {}
var _attori_comando: Array = []
var _bersagli_menu: Array = []
var _ultimo_esito := ""

func _ready() -> void:
	theme = Tema.tema()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	p = Partita.new()
	_leggi_preferenze()
	_costruisci()
	mappa.velocita = _velocita_iniziale
	_aggiorna_bottoni_scheda()
	_applica_linee()
	var dati := _leggi_salvataggio()
	if not dati.is_empty() and p.carica(dati):
		_aggiorna_tutto(true)
		_mostra_briefing(true)
	else:
		p.nuova(0, true)
		selezione = ["A"]
		_aggiorna_tutto(true)
		_mostra_briefing(false)

# =================================================================== costruzione
func _costruisci() -> void:
	var fondo := ColorRect.new()
	fondo.color = Tema.OLIVA_SCURO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var radice := VBoxContainer.new()
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.add_theme_constant_override("separation", 0)
	add_child(radice)
	radice.add_child(_barra_superiore())
	fasi = FasiScript.new()
	radice.add_child(fasi)
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 8)
	var margine := MarginContainer.new()
	margine.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in ["left", "right", "bottom"]:
		margine.add_theme_constant_override("margin_" + k, 8)
	margine.add_theme_constant_override("margin_top", 6)
	margine.add_child(corpo)
	radice.add_child(margine)
	corpo.add_child(_colonna_squadra())
	corpo.add_child(_colonna_centrale())
	corpo.add_child(_colonna_destra())
	_costruisci_overlay()

func _barra_superiore() -> Control:
	var pc := PanelContainer.new()
	var st := Tema.scatola(Color("23271b"), Color("3d4430"), 0, 0, 14)
	st.border_width_bottom = 2
	st.border_color = Tema.OTTONE.darkened(0.35)
	pc.add_theme_stylebox_override("panel", st)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	pc.add_child(hb)
	hb.add_child(Tema.titolo("AMBUSH!", 32, Color("efe6c8")))
	var sub := VBoxContainer.new()
	sub.add_theme_constant_override("separation", -4)
	sub.add_child(Tema.etichetta("MISSIONE 1 · SANGUE A SAINT-MICHAUX", Tema.testo_bold, 16, Tema.OTTONE))
	sub.add_child(Tema.etichetta("Normandia, fine giugno 1944 · solitario", Tema.testo, 13, Tema.KAKI_SPENTO))
	hb.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	barra_cond = _badge(hb, "CONDIZIONE 1")
	barra_pv = _badge(hb, "PV 0 / 13")
	var avv := VBoxContainer.new()
	avv.add_theme_constant_override("separation", 0)
	avv.add_child(Tema.etichetta("AVVISTAMENTI", Tema.testo_bold, 11, Tema.KAKI_SPENTO))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 2)
	for i in 10:
		var l := Tema.etichetta(str(i), Tema.testo_bold, 13, Tema.KAKI_SPENTO)
		l.custom_minimum_size = Vector2(18, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", Tema.scatola(Color("2a2e21"), Color("596146"), 1, 1, 0))
		box.add_child(l)
		riga.add_child(box)
		caselle_avv.append(box)
	avv.add_child(riga)
	hb.add_child(avv)
	hb.add_child(Tema.bottone("Briefing", func(): _mostra_briefing(false, true)))
	hb.add_child(Tema.bottone("Regole", _mostra_regole))
	hb.add_child(Tema.bottone("Legenda", _mostra_legenda))
	hb.add_child(Tema.bottone("Nuova partita", _chiedi_nuova))
	return pc

func _badge(contenitore: Control, testo: String) -> Label:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Tema.scatola(Color("2f3424"), Tema.OTTONE.darkened(0.3), 1, 2, 10))
	var l := Tema.etichetta(testo, Tema.stencil, 18, Tema.KAKI)
	pc.add_child(l)
	contenitore.add_child(pc)
	return l

func _colonna_squadra() -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(292, 0)
	pc.add_theme_stylebox_override("panel", Tema.carta(8))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	pc.add_child(vb)
	vb.add_child(Tema.titolo("SCHEDA DELLA SQUADRA", 18, Tema.INCHIOSTRO))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lista_squadra = VBoxContainer.new()
	lista_squadra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_squadra.add_theme_constant_override("separation", 3)
	sc.add_child(lista_squadra)
	vb.add_child(sc)
	return pc

func _testo_ricco(dim := 15, colore := Color(C_CHIARO)) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_override("normal_font", Tema.testo)
	l.add_theme_font_override("bold_font", Tema.testo_bold)
	l.add_theme_font_size_override("normal_font_size", dim)
	l.add_theme_font_size_override("bold_font_size", dim)
	l.add_theme_color_override("default_color", colore)
	l.add_theme_constant_override("line_separation", 1)
	return l

func _colonna_centrale() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	var cornice := PanelContainer.new()
	cornice.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cornice.add_theme_stylebox_override("panel", Tema.scatola(Color("15170f"), Color("4d5538"), 2, 2, 0))
	mappa = MappaScript.new()
	mappa.partita = p
	mappa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mappa.esagono_cliccato.connect(_clic_mappa)
	mappa.esagono_sopra.connect(_sopra_mappa)
	cornice.add_child(mappa)
	# Controlli sovrapposti alla mappa
	var sovra := Control.new()
	sovra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cornice.add_child(sovra)
	var zoom_box := HBoxContainer.new()
	zoom_box.anchor_left = 1.0
	zoom_box.anchor_right = 1.0
	zoom_box.offset_right = -10
	zoom_box.offset_top = 10
	zoom_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var bm := Tema.bottone("-", func(): mappa.zoom_a(1 / 1.25, mappa.size / 2), "Allontana")
	bm.custom_minimum_size = Vector2(40, 36)
	zoom_box.add_child(bm)
	var bp := Tema.bottone("+", func(): mappa.zoom_a(1.25, mappa.size / 2), "Avvicina")
	bp.custom_minimum_size = Vector2(40, 36)
	zoom_box.add_child(bp)
	zoom_box.add_child(Tema.bottone("Intera mappa", func(): mappa.centra()))
	zoom_box.add_child(Tema.bottone("Squadra", _centra_squadra, "Inquadra i soldati sulla mappa"))
	bottone_vista = Tema.bottone("", _cambia_linee, "Mostra o nasconde la linea di vista dal soldato scelto e le linee di chi vede chi")
	zoom_box.add_child(bottone_vista)
	zoom_box.add_child(Tema.bottone("Rivedi", _rivedi, "Ripete sulla mappa, passo per passo, l’ultima sequenza di eventi"))
	sovra.add_child(zoom_box)
	var info_pc := PanelContainer.new()
	info_pc.add_theme_stylebox_override("panel", Tema.scatola(Color(0.91, 0.87, 0.76, 0.94), Color("7a6c4c"), 1, 2, 8))
	info_pc.offset_left = 10
	info_pc.offset_top = 10
	info_pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_hex = Tema.etichetta("", Tema.testo, 14, Tema.INCHIOSTRO)
	info_hex.custom_minimum_size = Vector2(320, 0)
	info_hex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_pc.add_child(info_hex)
	sovra.add_child(info_pc)
	info_pc.visible = false
	info_hex.set_meta("pannello", info_pc)
	vb.add_child(cornice)
	# Pannello basso: comandi del soldato oppure scheda dell’azione in corso
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", Tema.pannello_oliva(10))
	barra.custom_minimum_size = Vector2(0, 226)
	box_comandi = VBoxContainer.new()
	box_comandi.add_theme_constant_override("separation", 4)
	barra.add_child(box_comandi)
	titolo_azioni = Tema.etichetta("", Tema.testo_bold, 18, Color(C_CHIARO))
	box_comandi.add_child(titolo_azioni)
	aiuto_azioni = Tema.etichetta("", Tema.testo, 15, Tema.KAKI_SPENTO)
	aiuto_azioni.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aiuto_azioni.custom_minimum_size = Vector2(600, 0)
	box_comandi.add_child(aiuto_azioni)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	flusso_azioni = HFlowContainer.new()
	flusso_azioni.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flusso_azioni.add_theme_constant_override("h_separation", 6)
	flusso_azioni.add_theme_constant_override("v_separation", 6)
	sc.add_child(flusso_azioni)
	box_comandi.add_child(sc)
	box_scheda = _costruisci_scheda()
	box_scheda.visible = false
	barra.add_child(box_scheda)
	vb.add_child(barra)
	return vb

func _costruisci_scheda() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	# CHI
	var chi := VBoxContainer.new()
	chi.custom_minimum_size = Vector2(150, 0)
	chi.add_theme_constant_override("separation", 2)
	chi.add_child(Tema.etichetta("CHI AGISCE", Tema.testo_bold, 12, Tema.OTTONE))
	sch_pedina = TextureRect.new()
	sch_pedina.custom_minimum_size = Vector2(72, 72)
	sch_pedina.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sch_pedina.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sch_pedina.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chi.add_child(sch_pedina)
	sch_titolo = Tema.etichetta("", Tema.stencil, 20, Color(C_CHIARO))
	sch_titolo.custom_minimum_size = Vector2(150, 0)
	sch_titolo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chi.add_child(sch_titolo)
	sch_sotto = Tema.etichetta("", Tema.testo, 14, Tema.KAKI_SPENTO)
	sch_sotto.custom_minimum_size = Vector2(150, 0)
	sch_sotto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chi.add_child(sch_sotto)
	hb.add_child(chi)
	hb.add_child(_divisore())
	# PERCHÉ
	var perche := VBoxContainer.new()
	perche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perche.custom_minimum_size = Vector2(240, 0)
	perche.add_theme_constant_override("separation", 2)
	sch_perche_titolo = Tema.etichetta("PERCHÉ", Tema.testo_bold, 12, Tema.OTTONE)
	sch_perche_titolo.clip_text = true
	sch_perche_titolo.custom_minimum_size = Vector2(240, 0)
	perche.add_child(sch_perche_titolo)
	sch_tabella = TabellaScript.new()
	perche.add_child(sch_tabella)
	sch_perche = _testo_ricco(15)
	perche.add_child(sch_perche)
	hb.add_child(perche)
	hb.add_child(_divisore())
	# COSA SUCCEDE
	var esito := VBoxContainer.new()
	esito.custom_minimum_size = Vector2(300, 0)
	esito.add_theme_constant_override("separation", 2)
	esito.add_child(Tema.etichetta("COSA SUCCEDE", Tema.testo_bold, 12, Tema.OTTONE))
	sch_esito = _testo_ricco(15)
	sch_esito.scroll_following = true
	esito.add_child(sch_esito)
	hb.add_child(esito)
	hb.add_child(_divisore())
	# comandi della riproduzione
	var bt := VBoxContainer.new()
	bt.custom_minimum_size = Vector2(150, 0)
	bt.add_theme_constant_override("separation", 5)
	sch_continua = Tema.bottone("Continua", _premi_continua, "Spazio o Invio")
	sch_continua.custom_minimum_size = Vector2(150, 56)
	sch_continua.add_theme_font_size_override("font_size", 20)
	bt.add_child(sch_continua)
	sch_modo = Tema.bottone("", _cambia_modo, "Passo passo: ti fermi a ogni fase e a ogni soldato. Automatico: scorre da solo.")
	bt.add_child(sch_modo)
	sch_velocita = Tema.bottone("", _cambia_velocita)
	bt.add_child(sch_velocita)
	sch_salta = Tema.bottone("Salta tutto", func(): _salta_tutto = true; _avanti = true, "Mostra subito il risultato finale (Esc)")
	bt.add_child(sch_salta)
	hb.add_child(bt)
	_aggiorna_bottoni_scheda()
	return hb

func _divisore() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.8, 0.7, 0.4, 0.22)
	c.custom_minimum_size = Vector2(2, 0)
	return c

func _colonna_destra() -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(360, 0)
	vb.add_theme_constant_override("separation", 6)
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", Tema.pannello_oliva(8))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	pv.add_child(Tema.titolo("PISTA DEI ROUND", 16, Tema.OTTONE))
	pista = PistaScript.new()
	pv.add_child(pista)
	pp.add_child(pv)
	vb.add_child(pp)
	# Situazione: obiettivi e tedeschi incontrati
	var op := PanelContainer.new()
	op.add_theme_stylebox_override("panel", Tema.pannello_oliva(8))
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 3)
	ov.add_child(Tema.titolo("OBIETTIVI", 15, Tema.OTTONE))
	obiettivi_box = HFlowContainer.new()
	obiettivi_box.add_theme_constant_override("h_separation", 4)
	obiettivi_box.add_theme_constant_override("v_separation", 4)
	ov.add_child(obiettivi_box)
	ov.add_child(Tema.titolo("TEDESCHI INCONTRATI", 15, Tema.OTTONE))
	carte_box = HFlowContainer.new()
	carte_box.add_theme_constant_override("h_separation", 4)
	carte_box.add_theme_constant_override("v_separation", 4)
	ov.add_child(carte_box)
	op.add_child(ov)
	vb.add_child(op)
	# Rapporto
	var rp := PanelContainer.new()
	rp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rp.add_theme_stylebox_override("panel", Tema.carta(10))
	var rv := VBoxContainer.new()
	titolo_rapporto = Tema.titolo("RAPPORTO DI COMBATTIMENTO", 16, Tema.INCHIOSTRO)
	rv.add_child(titolo_rapporto)
	rapporto = _testo_ricco(14, Tema.INCHIOSTRO)
	rapporto.scroll_following = true
	rapporto.selection_enabled = true
	rv.add_child(rapporto)
	rp.add_child(rv)
	vb.add_child(rp)
	return vb

func _costruisci_overlay() -> void:
	velo = ColorRect.new()
	velo.color = Color(0.05, 0.06, 0.04, 0.62)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.visible = false
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(velo)
	finestra = PanelContainer.new()
	finestra.add_theme_stylebox_override("panel", Tema.carta(26))
	finestra.visible = false
	add_child(finestra)
	menu_bersagli = PopupMenu.new()
	menu_bersagli.id_pressed.connect(_scelto_bersaglio)
	add_child(menu_bersagli)

# =================================================================== stato mostrato
## Stato che i pannelli devono mostrare: quello della riproduzione in corso, altrimenti quello reale.
func _S() -> Dictionary:
	return stato_vis if not stato_vis.is_empty() else p.stato_pannelli()

## Casella della pista che sta agendo in uno stato dato ("2de", "1us"…), o "".
func _casella_di(st: Dictionary) -> String:
	if st.get("fase", "") != "round":
		return ""
	var r: Dictionary = st.get("round", {})
	if not r.get("iniziativa_fatta", false):
		return ""
	var v: String = r.get("vantaggio", "de")
	var o := "de" if v == "us" else "us"
	for c in [[2, v], [2, o], [1, v], [1, o]]:
		for x in st.unita.values():
			if x.lato == c[1] and int(x.get("turni", 0)) == c[0] and x.get("slot", "") == "turni" and x.stato in ["attivo", "fuori"]:
				return "%d%s" % [c[0], c[1]]
	return ""

## Fase da accendere nella barra per lo stato reale (fuori dalla riproduzione).
func _chiave_reale() -> String:
	var st := p.stato_pannelli()
	if st.fase != "round":
		return ""
	if int(st.round.get("n", 0)) == 0:
		return "contatto"
	if p.s.pausa == "inizio_round":
		return "fine"
	var c := _casella_di(st)
	return c if c != "" else "iniziativa"

func _unita_vis(lato: String) -> Array:
	var out: Array = []
	for x in _S().unita.values():
		if x.lato == lato:
			out.append(x)
	out.sort_custom(func(a, b): return str(a.lettera) < str(b.lettera))
	return out

# =================================================================== aggiornamento
func _aggiorna_tutto(ricostruisci_log := false) -> void:
	_pulisci_selezione()
	_aggiorna_pannelli()
	_aggiorna_azioni()
	_aggiorna_obiettivi()
	_aggiorna_mappa()
	_aggiorna_rapporto(ricostruisci_log)

## Barra in alto, barra delle fasi, pista e scheda della squadra, dallo stato mostrato.
func _aggiorna_pannelli() -> void:
	var st := _S()
	if not riproducendo:
		_chiave_fase = _chiave_reale()
	fasi.mostra(st, _chiave_fase)
	var casella := _chiave_fase if _chiave_fase in ["2us", "2de", "1us", "1de"] else ""
	pista.mostra(st, casella)
	_aggiorna_barra(st)
	_aggiorna_squadra()

func _pulisci_selezione() -> void:
	selezione = selezione.filter(func(id): return not p.u(id).is_empty() and (p.attivo(p.u(id)) or p.u(id).stato == "fuori"))
	if p.fase_round():
		var di_turno: Array = p.americani_di_turno().map(func(a): return a.id)
		if not p.s.turno.is_empty():
			selezione = [p.s.turno.id]
		elif not di_turno.is_empty():
			selezione = selezione.filter(func(id): return id in di_turno)
			if selezione.is_empty():
				selezione = [di_turno[0]]
		else:
			selezione = []
	if selezione.size() > 1 and p.fase_round():
		selezione = [selezione[0]]

func _aggiorna_barra(st: Dictionary) -> void:
	var cond := int(st.get("condizione", 1))
	barra_cond.text = "CONDIZIONE %d · ATT. 0–%d" % [cond, int(p.missione.attivazione.get(str(cond), 8))]
	barra_pv.text = "PV %d / %d" % [int(st.get("pv_tot", 0)), int(p.missione.vittoria_pv)]
	var avv: Array = st.get("avvistamenti", [])
	for i in 10:
		var on: bool = i < avv.size() and avv[i]
		var box: PanelContainer = caselle_avv[i]
		box.add_theme_stylebox_override("panel", Tema.scatola(Color("8f2a1e") if on else Color("2a2e21"), Color("c9a24a") if on else Color("596146"), 1, 1, 0))
		(box.get_child(0) as Label).add_theme_color_override("font_color", Color("f6eacb") if on else Tema.KAKI_SPENTO)
		box.tooltip_text = "Avvistamento s%d %s" % [i, "avvenuto" if on else "non ancora avvenuto"]

func _aggiorna_mappa() -> void:
	mappa.selezionati = selezione
	var ev := {}
	var etichette := {}
	var linee: Array = []
	var a: Dictionary = p.u(selezione[0]) if not selezione.is_empty() else {}
	mappa.origine_vista = a.hex if not a.is_empty() else ""
	mappa.postura_vista = a.postura if not a.is_empty() else "standing"
	if not a.is_empty() and p.s.pausa == "" and p.s.fase != "fine" and not riproducendo:
		# chi vede chi: linee dal soldato scelto ai tedeschi che ha in vista
		if a.hex != "" and linee_vista and p.s.fase != "schieramento":
			for g in p.tedeschi_attivi():
				if p.vede_unita(a, g):
					linee.append({"da": a.hex, "a": g.hex, "colore": Color(1.0, 0.45, 0.3, 0.7)})
		if p.s.fase == "schieramento":
			for h in p.esagoni_ingresso():
				ev[h] = Color("8fd16a")
		elif modo == "" and _puo_muovere(a):
			for h in p.destinazioni(a.id):
				ev[h] = Color("8fd16a")
		elif modo in ["mirato", "rapido"]:
			var arma := p.arma_di(a, arma_scelta.get(a.id, ""))
			for g in p.tedeschi_attivi():
				if not arma.is_empty():
					var pr := p.probabilita_tiro(a, arma, g, modo == "mirato")
					if pr.ok:
						ev[g.hex] = Color("e0503c")
						var testo := "%s %d%%" % [g.lettera, (int(pr.prob) + 1) * 10]
						etichette[g.hex] = (str(etichette[g.hex]) + "  " + testo) if etichette.has(g.hex) else testo
		elif modo in ["granata", "satchel"]:
			for h in E.tutti():
				if E.distanza(a.hex, h) <= 6 and p.probabilita_lancio(a, modo, h).ok:
					ev[h] = Color("e08a3c") if not p.unita_in(h, "de").is_empty() else Color(0.9, 0.55, 0.25, 0.5)
		elif modo == "trascina":
			for v in E.vicini(a.hex):
				if p.terreno.costo_movimento(a.hex, v) >= 0:
					ev[v] = Color("8fd16a")
		elif modo in ["cedi", "sveglia"]:
			for x in p.americani_attivi_in_mappa():
				if x.id != a.id and E.distanza(x.hex, a.hex) <= 2:
					ev[x.hex] = Color("6ab0d1")
	mappa.evidenzia = ev
	mappa.etichette = etichette
	mappa.linee = linee
	mappa.queue_redraw()

func _centra_squadra() -> void:
	var esagoni: Array = p.americani_attivi_in_mappa().map(func(x): return x.hex)
	if esagoni.is_empty():
		mappa.vista_iniziale()
	else:
		mappa.assicura_visibili(esagoni + p.tedeschi_attivi().map(func(x): return x.hex))

func _puo_muovere(a: Dictionary) -> bool:
	if p.puo_agire(a) != "":
		return false
	if p.s.fase == "operazioni":
		return true
	return not p.s.turno.is_empty() and p.s.turno.id == a.id and p.s.turno.azione in ["muovi", "muovi_spara", "carica"]

# ------------------------------------------------------------------ squadra
func _aggiorna_squadra() -> void:
	for c in lista_squadra.get_children():
		c.queue_free()
	var in_round: bool = _S().get("fase", "") == "round"
	var di_turno: Array = [] if riproducendo else p.americani_di_turno().map(func(a): return a.id)
	for a in _unita_vis("us"):
		lista_squadra.add_child(_riga_soldato(a, a.id in selezione and not riproducendo, a.id in di_turno, in_round))

func _riga_soldato(a: Dictionary, sel: bool, turno: bool, in_round: bool) -> Control:
	var pc := PanelContainer.new()
	var colore := Color("efe6cb") if not sel else Color("f4dfa0")
	var bordo := Color("b4a47b") if not sel else Tema.OTTONE
	if turno and not sel:
		bordo = Tema.VERDE_OK
	var st := Tema.scatola(colore, bordo, 2 if (sel or turno) else 1, 3, 6)
	if a.stato in ["morto"]:
		st.bg_color = Color("cfc5ad")
	pc.add_theme_stylebox_override("panel", st)
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.gui_input.connect(func(ev): _clic_riga(ev, a.id))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 7)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	var tr := TextureRect.new()
	var chiave := "us_" + str(a.lettera) + ("_acc" if a.postura == "crouching" else "")
	tr.texture = mappa.trame.get(chiave, mappa.trame.get("us_" + str(a.lettera)))
	tr.custom_minimum_size = Vector2(40, 40)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if a.stato == "morto":
		tr.modulate = Color(0.5, 0.5, 0.5)
	hb.add_child(tr)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", -1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var r1 := HBoxContainer.new()
	r1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nome := Tema.etichetta("%s · %s" % [a.lettera, str(a.nome).to_upper()], Tema.testo_bold, 15, Tema.INCHIOSTRO)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.clip_text = true
	r1.add_child(nome)
	var dove := ("da schierare" if _S().get("fase", "") == "schieramento" else "fuori mappa") if a.stato == "fuori" else ("uscito" if a.stato == "uscito" else str(a.hex))
	r1.add_child(Tema.etichetta(dove, Tema.stencil, 14, Tema.INCHIOSTRO_TENUE))
	vb.add_child(r1)
	var righe: Array = []
	if a.get("senza_carta", false):
		righe.append("Superstite dell’imboscata, da portare in salvo")
	else:
		righe.append("IN %d · PC %d · WS %+d · PM %d" % [int(a.IN), int(a.PC), int(a.WS), p.effettivo_mpa(a)])
	var armi: Array = []
	for arma in a.armi:
		var n: String = T.ARMI.get(arma.tipo, {}).get("breve", arma.tipo)
		if arma.tipo in ["satchel"]:
			n = "Carica" + (" pronta" if arma.preparata else "")
		elif arma.tipo == "bazooka":
			n = "Bazooka %s (%d)" % ["carico" if arma.preparata else "scarico", int(a.munizioni.get("bazooka", 0))]
		else:
			n += " (%d)" % int(a.munizioni.get(arma.tipo, 0))
		if arma.inceppata:
			n += " INCEPPATA"
		if arma.rotta:
			n += " ROTTA"
		armi.append(n)
	var gr := int(a.munizioni.get("granata", 0))
	if gr > 0:
		armi.append("%d granat%s" % [gr, "a" if gr == 1 else "e"])
	if not armi.is_empty():
		righe.append(" · ".join(armi))
	var info := Tema.etichetta("\n".join(righe), Tema.testo, 13, Tema.INCHIOSTRO_TENUE)
	info.clip_text = true
	info.add_theme_constant_override("line_spacing", -3)
	vb.add_child(info)
	var stati := HFlowContainer.new()
	stati.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stati.add_theme_constant_override("h_separation", 3)
	stati.add_theme_constant_override("v_separation", 2)
	if a.get("comandante", false):
		stati.add_child(_chip("comandante", Color("7a6226")))
	if a.stato == "attivo" or a.stato == "fuori":
		stati.add_child(_chip(T.NOMI_POSTURA[a.postura], Color("6b6248")))
	if a.ferito and a.stato == "attivo":
		stati.add_child(_chip("FERITO", Tema.ROSSO))
	match a.stato:
		"incapacitato":
			stati.add_child(_chip("INCAPACITATO", Tema.ROSSO))
		"morto":
			stati.add_child(_chip("UCCISO", Color("2a2a2a")))
		"uscito":
			stati.add_child(_chip("USCITO DALLA MAPPA", Color("50604a")))
	if in_round and (a.stato == "attivo" or a.stato == "fuori"):
		if a.get("panico", false):
			stati.add_child(_chip("PANICO", Tema.ROSSO))
		elif not a.get("consapevole", false):
			stati.add_child(_chip("inconsapevole", Color("55554a")))
		elif a.get("slot", "") == "turni" and int(a.get("turni", 0)) > 0:
			stati.add_child(_chip("%d turn%s" % [int(a.turni), "o" if int(a.turni) == 1 else "i"], Tema.VERDE_OK))
		elif _S().get("round", {}).get("iniziativa_fatta", false):
			stati.add_child(_chip("ha finito", Color("7a735a")))
		else:
			stati.add_child(_chip("consapevole", Color("4f6a3a")))
	if not a.get("prigionieri", []).is_empty():
		stati.add_child(_chip("%d prigionier%s" % [a.prigionieri.size(), "o" if a.prigionieri.size() == 1 else "i"], Color("49586b")))
	if stati.get_child_count() > 0:
		vb.add_child(stati)
	return pc

func _chip(testo: String, colore: Color) -> Control:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", Tema.scatola(colore, Color.TRANSPARENT, 0, 2, 5))
	var l := Tema.etichetta(testo, Tema.testo_bold, 12, Color("f6efdc"))
	pc.add_child(l)
	return pc

func _clic_riga(ev: InputEvent, id: String) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT or riproducendo:
		return
	var a := p.u(id)
	var multi: bool = ev.shift_pressed or ev.ctrl_pressed or ev.meta_pressed
	if multi and p.s.fase in ["operazioni", "schieramento"] and not selezione.is_empty():
		if id in selezione:
			selezione.erase(id)
		else:
			selezione.append(id)
	else:
		selezione = [id]
	modo = ""
	if a.hex != "":
		if not _visibile_su_mappa(a.hex):
			mappa.centra_su(a.hex)
	_aggiorna_tutto()

func _visibile_su_mappa(h: String) -> bool:
	var c: Vector2 = mappa.centro_schermo(h)
	return Rect2(Vector2(40, 40), mappa.size - Vector2(80, 80)).has_point(c)

# ------------------------------------------------------------------ obiettivi e tedeschi
func _aggiorna_obiettivi() -> void:
	for c in obiettivi_box.get_children():
		c.queue_free()
	var v := p.condizioni_vittoria()
	var alt: Array = p.alture_obiettivo()
	var righe := [
		[v.t8, "Edificio T8", "Un soldato attivo nell’edificio T8"],
		[v.kl, "Edifici K13–L13", "Un soldato negli edifici K13–L13"],
		[v.altura != "", "Altura %s" % ", ".join(alt), "Un soldato attivo sull’altura con vista sulla strada"],
		[v.nessun_tedesco, "Nessun tedesco attivo", "Nessun tedesco attivo sulla mappa"],
		[p.pv_totali() + (4 if v.ok else 0) >= 13, "13 PV (ora %d)" % p.pv_totali(), "Servono 13 punti vittoria; il primo finale ne dà 4 in più"],
	]
	for r in righe:
		var c := _chip(("fatto: " if r[0] else "") + str(r[1]), Color("3f6b2f") if r[0] else Color("3a3f2c"))
		c.tooltip_text = r[2]
		c.mouse_filter = Control.MOUSE_FILTER_PASS
		obiettivi_box.add_child(c)
	for c in carte_box.get_children():
		c.queue_free()
	var incontrati: Array = p.tedeschi()
	if incontrati.is_empty():
		carte_box.add_child(Tema.etichetta("Nessuno, per ora.", Tema.testo, 14, Tema.KAKI_SPENTO))
	for g in incontrati:
		var stato: String = {"attivo": g.hex, "morto": "ucciso", "incapacitato": "incapac.", "catturato": "catturato", "arreso": "arreso", "rimosso": "dileguato", "uscito": "uscito"}.get(g.stato, g.stato)
		var b := Tema.bottone("%s · %s" % [g.lettera, stato], func(): _mostra_carta(g), "Tedesco %d, %s%s. Tocca per vedere la carta." % [int(g.num), str(g.nome).to_lower(), (" · reazione speciale " + g.reazione) if g.reazione != "" else ""])
		b.icon = mappa.trame.get("ge_" + str(g.lettera))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 24)
		b.add_theme_font_size_override("font_size", 14)
		if not p.in_mappa(g):
			b.modulate = Color(0.62, 0.62, 0.62)
		carte_box.add_child(b)
	if p.u("J").get("stato", "") != "":
		carte_box.add_child(Tema.bottone("J · pilota", func(): _mostra_carta(p.u("J")), "Pilota britannico"))

# =================================================================== comandi
func _aggiorna_azioni() -> void:
	box_scheda.visible = riproducendo
	box_comandi.visible = not riproducendo
	if riproducendo:
		return
	for c in flusso_azioni.get_children():
		c.queue_free()
	_gruppo_box = null
	aiuto_azioni.add_theme_color_override("font_color", Tema.KAKI_SPENTO)
	var s := p.s
	if s.fase == "fine":
		titolo_azioni.text = "MISSIONE CONCLUSA"
		aiuto_azioni.text = "Totale %d PV: %s." % [int(s.fine.get("totale", 0)), "vittoria" if s.fine.get("vinta", false) else "sconfitta"]
		_b("Resoconto finale", _mostra_fine)
		_b("Nuova partita", _chiedi_nuova)
		return
	if s.fase == "schieramento":
		_azioni_schieramento()
		return
	if s.pausa != "":
		# Si arriva qui solo riprendendo una partita salvata a metà di una sequenza.
		var testi := {"inizio_round": ["IL NEMICO È IN VISTA", "Sta per iniziare il prossimo Round: consapevolezza, evento, iniziativa e poi i turni."],
			"azioni_tedesche": ["I TEDESCHI HANNO AGITO", "Il Round prosegue con la casella successiva della pista."],
			"fine_round": ["FINE DEL ROUND", "Si chiude il Round e si controlla se restano tedeschi attivi."]}
		var tx: Array = testi.get(s.pausa, ["IN PAUSA", ""])
		titolo_azioni.text = tx[0]
		aiuto_azioni.text = tx[1]
		var c := _b("Prosegui", _prosegui, "Spazio o Invio")
		c.custom_minimum_size = Vector2(190, 44)
		_azioni_missione()
		return
	if selezione.is_empty():
		titolo_azioni.text = "NESSUN SOLDATO SCELTO"
		if p.fase_round():
			aiuto_azioni.text = "Nessun americano può agire in questo momento."
			_b("Prosegui", _prosegui)
		else:
			aiuto_azioni.text = "Scegli un soldato nella scheda della squadra o sulla mappa."
		_azioni_missione()
		return
	var a := p.u(selezione[0])
	var nomi: Array = selezione.map(func(id): return p.u(id).lettera)
	var dove: String = "fuori mappa" if a.stato == "fuori" else a.hex
	var prefisso := ""
	if p.fase_round() and p.puo_agire(a) == "":
		prefisso = "TOCCA A TE: "
	if selezione.size() > 1:
		titolo_azioni.text = "GRUPPO %s · %s · %s" % [", ".join(nomi), dove, T.NOMI_POSTURA[a.postura]]
	else:
		titolo_azioni.text = "%s%s %s · %s · %s" % [prefisso, a.lettera, str(a.nome).to_upper(), dove, T.NOMI_POSTURA[a.postura]]
	var err := p.puo_agire(a)
	if p.s.fase == "operazioni":
		_azioni_operazioni(a)
	elif err != "":
		aiuto_azioni.text = err
	else:
		_azioni_round(a)
	_azioni_missione()
	if _ultimo_esito != "":
		aiuto_azioni.text = _ultimo_esito + "\n" + aiuto_azioni.text

var _gruppo_box: HBoxContainer
var bottone_vista: Button
var linee_vista := true

func _cambia_linee() -> void:
	linee_vista = not linee_vista
	_salva_preferenze()
	_applica_linee()
	if not riproducendo:
		_aggiorna_mappa()

func _applica_linee() -> void:
	mappa.mostra_vista = linee_vista
	if not linee_vista:
		mappa.linee = []
	mappa.queue_redraw()
	if bottone_vista != null:
		bottone_vista.text = "Linee di vista: sì" if linee_vista else "Linee di vista: no"

func _b(testo: String, cb: Callable, tip := "", attivo := true) -> Button:
	var b := Tema.bottone(testo, cb, tip)
	b.disabled = not attivo
	b.custom_minimum_size = Vector2(0, 36)
	if _gruppo_box != null and is_instance_valid(_gruppo_box):
		_gruppo_box.add_child(b)
	else:
		flusso_azioni.add_child(b)
	return b

## Gruppo di comandi con la sua etichetta (Postura, Movimento, Fuoco…): va a capo tutto insieme.
func _gruppo(testo: String) -> void:
	_gruppo_box = HBoxContainer.new()
	_gruppo_box.add_theme_constant_override("separation", 6)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Tema.scatola(Color("262a1d"), Color("4d5538"), 1, 3, 6))
	pc.add_child(_gruppo_box)
	var l := Tema.etichetta(testo, Tema.testo_bold, 12, Tema.OTTONE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gruppo_box.add_child(l)
	flusso_azioni.add_child(pc)

func _azioni_posture(a: Dictionary, costo := "") -> void:
	_gruppo("POSTURA")
	for k in ["standing", "crouching", "prone"]:
		var b := _b(_maiuscola(T.NOMI_POSTURA[k]) + costo, func(): _esito(p.cambia_postura(a.id, k)), "", a.postura != k and a.hex != "")
		if a.postura == k:
			b.text = _maiuscola(T.NOMI_POSTURA[k])
			b.add_theme_stylebox_override("disabled", Tema.scatola(Color("55603f"), Tema.OTTONE, 1, 3, 10))
			b.add_theme_color_override("font_disabled_color", Color(C_CHIARO))

func _maiuscola(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)

## Schieramento iniziale: si dispongono i soldati sul margine nord, poi si dà il via.
func _azioni_schieramento() -> void:
	var tutti: Array = p.americani().filter(func(x): return x.stato in ["attivo", "fuori"])
	var fuori: Array = tutti.filter(func(x): return x.hex == "")
	var dentro := tutti.size() - fuori.size()
	titolo_azioni.text = "SCHIERAMENTO · %d di %d soldati sulla mappa" % [dentro, tutti.size()]
	var scelti: Array = selezione.map(func(id): return p.u(id).lettera)
	aiuto_azioni.text = "Scegli i soldati nella scheda a sinistra e tocca un esagono verde del margine nord (A1–J1). Puoi spostarli quante volte vuoi: nessuna carta viene letta e il nemico non reagisce finché non dai il via. Chi lasci fuori potrà entrare più tardi."
	if not scelti.is_empty():
		aiuto_azioni.text = "Scelti: %s. " % ", ".join(scelti) + aiuto_azioni.text
	_gruppo("SCEGLI")
	_b("Tutti", func(): selezione = tutti.map(func(x): return x.id); _aggiorna_tutto(), "Sceglie tutta la squadra: un tocco su un esagono li mette insieme")
	_b("Quelli ancora fuori (%d)" % fuori.size(), func(): selezione = fuori.map(func(x): return x.id); _aggiorna_tutto(), "", not fuori.is_empty())
	_b("Aggiungi il prossimo", _aggiungi_prossimo, "Aggiunge alla scelta il prossimo soldato ancora fuori", not fuori.filter(func(x): return not (x.id in selezione)).is_empty())
	_gruppo("SPOSTA")
	var sulla_mappa: Array = selezione.filter(func(id): return p.u(id).hex != "")
	_b("Rimetti fuori mappa", func(): p.schiera(sulla_mappa, ""); _salva(); _aggiorna_tutto(), "", not sulla_mappa.is_empty())
	_gruppo("VIA")
	var via := _b("Inizia la missione", func(): _esito(p.inizia_missione()), "La squadra entra davvero: si legge la carta della Condizione per ogni esagono occupato", dentro > 0)
	via.custom_minimum_size = Vector2(220, 44)
	via.add_theme_font_size_override("font_size", 19)
	if dentro > 0:
		via.add_theme_color_override("font_color", Color("fff3c4"))
		via.add_theme_stylebox_override("normal", Tema.scatola(Color("6b5a22"), Tema.OTTONE, 2, 3, 10))

func _aggiungi_prossimo() -> void:
	for x in p.americani():
		if x.stato == "fuori" and not (x.id in selezione):
			selezione.append(x.id)
			break
	_aggiorna_tutto()

func _azioni_operazioni(a: Dictionary) -> void:
	if a.stato == "fuori":
		aiuto_azioni.text = "Tocca un esagono verde del margine nord (A1–J1) per entrare. Ogni esagono raggiunto fa leggere la carta della Condizione."
	else:
		aiuto_azioni.text = "Tocca un esagono verde adiacente per muovere%s. Nelle Operazioni non ci sono limiti di movimento." % (" il gruppo" if selezione.size() > 1 else "")
	if a.hex != "" and selezione.size() == 1:
		_azioni_posture(a)
	if a.hex != "":
		var compagni: Array = p.unita_in(a.hex, "us").filter(func(x): return x.postura == a.postura)
		if compagni.size() > 1:
			_gruppo("GRUPPO")
			if selezione.size() > 1:
				_b("Solo %s" % a.lettera, func(): selezione = [a.id]; _aggiorna_tutto())
			else:
				_b("Tutti quelli nell’esagono (%d)" % compagni.size(), func(): selezione = compagni.map(func(x): return x.id); _aggiorna_tutto(), "Muovi insieme i soldati nello stesso esagono e nella stessa postura")
	else:
		var fuori: Array = p.americani().filter(func(x): return x.stato == "fuori")
		if fuori.size() > 1:
			_gruppo("GRUPPO")
			if selezione.size() > 1:
				_b("Solo %s" % a.lettera, func(): selezione = [a.id]; _aggiorna_tutto())
			else:
				_b("Tutti quelli fuori mappa (%d)" % fuori.size(), func(): selezione = fuori.map(func(x): return x.id); _aggiorna_tutto(), "Entrano insieme nello stesso esagono")
	if selezione.size() > 1:
		return
	_azioni_equipaggiamento(a)

func _azioni_equipaggiamento(a: Dictionary) -> void:
	if a.hex == "":
		return
	_gruppo("EQUIPAGGIAMENTO")
	var ogg := p.oggetti_disponibili(a.id).filter(func(v): return v.da == "terra" or not p.attivo(p.u(str(v.da))))
	_b("Equipaggiamento" + (" (%d da raccogliere)" % ogg.size() if not ogg.is_empty() else ""), func(): _finestra_equipaggiamento(a.id))
	var bz := p.arma_di(a, "bazooka")
	if not bz.is_empty() and not bz.preparata:
		_b("Carica il bazooka", func(): _esito(p.prepara(a.id, "bazooka")), "Serve un razzo; resta carico finché non spara.")
	var sc := p.arma_di(a, "satchel")
	if not sc.is_empty() and not sc.preparata:
		_b("Prepara la carica", func(): _esito(p.prepara(a.id, "satchel")))
	for arma in a.armi:
		if arma.inceppata:
			_b("Disinceppa: " + T.ARMI[arma.tipo].breve, func(): _esito(p.disinceppa(a.id, arma.tipo)))
	var inattivi: Array = p.unita_in(a.hex, "us", false).filter(func(x): return x.stato in ["incapacitato", "morto"])
	if not inattivi.is_empty():
		_b("Trascina " + inattivi[0].lettera, func(): modo = "trascina"; _aggiorna_tutto(), "Poi tocca l’esagono adiacente. Il soldato deve essere in piedi.")
		if E.riga(a.hex) == 1 and E.colonna(a.hex) <= 9:
			_b("Esci trascinando " + inattivi[0].lettera, func(): _esito(p.trascina(a.id, inattivi[0].id, "USCITA")))
	if a.hex == "R15" and p.s.pilota == "intrappolato":
		_b("Libera il pilota", func(): _esito(p.libera_pilota(a.id)), "Durante le Operazioni costa un controllo Evento; nei Round due azioni.")
	if E.riga(a.hex) == 1 and E.colonna(a.hex) <= 9:
		_b("Esci dalla mappa", func(): _conferma("Uscire dalla mappa?", "%s lascia il campo e non potrà rientrare. Se tutti i soldati attivi escono dal margine nord la missione termina." % p.nome(a), func(): _esito(p.esci(a.id))))

func _azioni_round(a: Dictionary) -> void:
	var t: Dictionary = p.s.turno if (not p.s.turno.is_empty() and p.s.turno.id == a.id) else {}
	var azione: String = t.get("azione", "")
	var cambio: bool = t.get("cambio_libero", not a.ferito) if not t.is_empty() else not a.ferito
	var di_turno: Array = p.americani_di_turno()
	if azione in ["muovi", "muovi_spara", "carica"]:
		var testi := {"muovi": "Movimento", "muovi_spara": "Movimento e tiro rapido", "carica": "Carica d’assalto"}
		aiuto_azioni.text = "%s: restano %d punti movimento%s. Tocca un esagono verde; da accovacciato si striscia di un solo esagono." % [testi[azione], int(t.mp), " e il cambio di postura gratuito" if cambio else ""]
		_azioni_posture(a, "" if cambio else " (1 PM)")
		if azione == "muovi_spara" and int(t.spari) == 0:
			_bottoni_fuoco(a, false)
		if azione == "carica":
			var qui: Array = p.unita_in(a.hex, "de")
			if not qui.is_empty():
				_gruppo("ASSALTO")
			for g in qui:
				_b("Assalta %s per uccidere" % g.lettera, func(): _esito(p.assalta(a.id, g.id, "uccidi")))
				_b("Assalta %s per catturare" % g.lettera, func(): _esito(p.assalta(a.id, g.id, "cattura")))
		if azione != "carica" or p.unita_in(a.hex, "de").is_empty():
			_gruppo("FINE")
			_b("Fine movimento", func(): _esito(p.fine_azione(a.id)) if azione != "carica" else _annulla_carica(a))
		return
	if azione == "rapido":
		aiuto_azioni.text = "Secondo tiro rapido: tocca un bersaglio rosso sulla mappa, oppure termina."
		_bottoni_fuoco(a, false)
		_gruppo("FINE")
		_b("Termina l’azione", func(): _esito(p.fine_azione(a.id)))
		return
	var altri: Array = di_turno.filter(func(x): return x.id != a.id).map(func(x): return x.lettera)
	var turni := int(a.turni)
	aiuto_azioni.text = "%s ha %d turn%s: in ogni turno un cambio di postura%s e una sola azione.%s" % [a.nome, turni, "o" if turni == 1 else "i",
		" gratuito" if cambio else " (1 PM, è ferito)", (" Nella stessa casella possono agire anche " + ", ".join(altri) + ": scegli tu l’ordine.") if not altri.is_empty() else ""]
	if a.stato == "fuori":
		_gruppo("MOVIMENTO")
		_b("Entra sulla mappa", func(): _esito(p.scegli_azione(a.id, "muovi")), "Spendi i punti movimento per il primo esagono del margine nord.")
		_gruppo("FINE")
		_b("Passa", func(): _esito(p.passa(a.id)))
		return
	_azioni_posture(a, "" if cambio else " (1 PM)")
	_gruppo("MOVIMENTO")
	_b("Muovi (%d PM)" % p.effettivo_mpa(a), func(): _esito(p.scegli_azione(a.id, "muovi")), "Spendi i punti movimento secondo il terreno.", a.postura != "prone")
	_b("Muovi e spara", func(): _esito(p.scegli_azione(a.id, "muovi_spara")), "Metà dei PM e un tiro rapido, prima o dopo.", a.postura != "prone")
	_b("Carica d’assalto", func(): _esito(p.scegli_azione(a.id, "carica")), "Muovi con metà dei PM ed entra nell’esagono nemico per assaltare (−3).", a.postura == "standing")
	_bottoni_fuoco(a, true)
	_b("Due tiri rapidi", func(): _imposta_modo(a, "rapido"), "Due tiri rapidi (−2 ciascuno), anche a bersagli diversi.", a.postura != "prone" and not p.armi_da_fuoco(a).filter(func(x): return x.tipo != "bazooka").is_empty())
	if int(a.munizioni.get("granata", 0)) > 0:
		_b("Granata (%d)" % int(a.munizioni.granata), func(): _imposta_modo(a, "granata"), "In piedi fino a 6 esagoni, accovacciato fino a 3.", a.postura != "prone")
	var sc := p.arma_di(a, "satchel")
	if not sc.is_empty() and sc.preparata:
		_b("Lancia la carica", func(): _imposta_modo(a, "satchel"), "Solo in piedi, fino a 3 esagoni.", a.postura == "standing")
	var nemici_qui: Array = p.unita_in(a.hex, "de")
	if not nemici_qui.is_empty():
		_gruppo("ASSALTO")
	for g in nemici_qui:
		_b("Assalta %s per uccidere" % g.lettera, func(): _esito(p.assalta(a.id, g.id, "uccidi")), "Bisogna essere in piedi.")
		_b("Assalta %s per catturare" % g.lettera, func(): _esito(p.assalta(a.id, g.id, "cattura")), "Bisogna essere in piedi.")
	if a.comandante and not a.panico:
		_gruppo("COMANDO")
		_b("Cedi il turno", func(): _imposta_modo(a, "cedi"), "Dai un turno a un soldato entro 2 esagoni (non ferito).")
		_b("Allerta un soldato", func(): _imposta_modo(a, "sveglia"), "Rendi consapevole un soldato entro 2 esagoni.")
	_azioni_equipaggiamento(a)
	_gruppo("FINE")
	_b("Passa il turno", func(): _esito(p.passa(a.id)))

func _bottoni_fuoco(a: Dictionary, mirato: bool) -> void:
	var armi: Array = p.armi_da_fuoco(a)
	if not mirato:
		armi = armi.filter(func(x): return x.tipo != "bazooka")
	_gruppo("FUOCO")
	if armi.is_empty():
		_b("Nessuna arma pronta", Callable(), "Arma inceppata, scarica o non preparata.", false)
		return
	if not armi_scelta_valida(a, armi):
		arma_scelta[a.id] = armi[0].tipo
	if armi.size() > 1:
		for arma in armi:
			var scelta: bool = arma_scelta[a.id] == arma.tipo
			var b := _b(("Arma: " if scelta else "Usa: ") + str(T.ARMI[arma.tipo].breve), func(): arma_scelta[a.id] = arma.tipo; _aggiorna_tutto(), "Arma da usare")
			if scelta:
				b.add_theme_color_override("font_color", Tema.OTTONE)
	if mirato:
		var b := _b("Tiro mirato", func(): _imposta_modo(a, "mirato"), "Un tiro senza malus; il bazooka spara solo mirato.", a.postura != "prone")
		if modo == "mirato":
			b.add_theme_color_override("font_color", Tema.OTTONE)
	elif modo != "rapido":
		_b("Tiro rapido", func(): _imposta_modo(a, "rapido"))

func armi_scelta_valida(a: Dictionary, armi: Array) -> bool:
	if not arma_scelta.has(a.id):
		return false
	for x in armi:
		if x.tipo == arma_scelta[a.id]:
			return true
	return false

func _annulla_carica(a: Dictionary) -> void:
	p.s.turno.azione = "muovi"
	_esito(p.fine_azione(a.id))

func _azioni_missione() -> void:
	if p.s.fase == "operazioni" and p.condizioni_vittoria().ok:
		_gruppo("MISSIONE")
		var b := _b("Missione compiuta: termina", func(): _conferma("Terminare la missione?", "Tutti gli obiettivi sono raggiunti: ottieni 4 PV supplementari. I soldati incapacitati negli edifici non fanno perdere punti.", func(): _esito(p.termina_missione("obiettivo"))))
		b.add_theme_color_override("font_color", Tema.OTTONE)

func _imposta_modo(a: Dictionary, m: String) -> void:
	modo = m if modo != m else ""
	_ultimo_esito = ""
	if m in ["mirato", "rapido"] and not arma_scelta.has(a.id):
		var armi := p.armi_da_fuoco(a)
		if not armi.is_empty():
			arma_scelta[a.id] = armi[0].tipo
	_aggiorna_tutto()
	if modo != "":
		var testi := {"mirato": "TIRO MIRATO: tocca un tedesco evidenziato in rosso. Accanto a ogni bersaglio c’è la probabilità di colpirlo.",
			"rapido": "TIRO RAPIDO: tocca un tedesco evidenziato in rosso. Accanto a ogni bersaglio c’è la probabilità di colpirlo.",
			"granata": "GRANATA: tocca l’esagono bersaglio (arancione).", "satchel": "CARICA: tocca l’esagono bersaglio (arancione).",
			"cedi": "CEDI IL TURNO: tocca un compagno entro 2 esagoni (azzurro).", "sveglia": "ALLERTA: tocca un compagno inconsapevole entro 2 esagoni (azzurro).",
			"trascina": "TRASCINA: tocca l’esagono adiacente in cui trascinare (verde)."}
		aiuto_azioni.text = testi.get(modo, "")
		aiuto_azioni.add_theme_color_override("font_color", Color("f2d98c"))
		if modo in ["mirato", "rapido"] and mappa.etichette.is_empty():
			aiuto_azioni.text += " Nessun bersaglio in vista con quest’arma."
		_gruppo_box = null
		var b := _b("Annulla", func(): modo = ""; _aggiorna_tutto(), "Esc")
		b.custom_minimum_size = Vector2(0, 48)
		flusso_azioni.move_child(b, 0)

# =================================================================== mappa: clic e passaggio
func _clic_mappa(h: String, _tasto: int) -> void:
	if riproducendo or p.s.pausa != "" or p.s.fase == "fine" or finestra.visible:
		return
	if p.s.fase == "schieramento":
		if h in p.esagoni_ingresso() and not selezione.is_empty():
			p.schiera(selezione, h)
			# pronto il prossimo soldato ancora fuori
			var fuori: Array = p.americani().filter(func(x): return x.stato == "fuori")
			if not fuori.is_empty():
				selezione = [fuori[0].id]
			_salva()
		else:
			var qui: Array = p.unita_in(h, "us")
			if not qui.is_empty():
				selezione = qui.map(func(x): return x.id)
		_aggiorna_tutto()
		return
	var a: Dictionary = p.u(selezione[0]) if not selezione.is_empty() else {}
	if not a.is_empty():
		match modo:
			"mirato", "rapido":
				var bersagli: Array = []
				var arma := p.arma_di(a, arma_scelta.get(a.id, ""))
				for g in p.unita_in(h, "de"):
					if not arma.is_empty() and p.probabilita_tiro(a, arma, g, modo == "mirato").ok:
						bersagli.append(g)
				if bersagli.size() == 1:
					_spara(a, bersagli[0])
				elif bersagli.size() > 1:
					_menu_bersagli(a, bersagli)
				return
			"granata", "satchel":
				_esito(p.lancia(a.id, modo, h))
				return
			"trascina":
				var f: Array = p.unita_in(a.hex, "us", false).filter(func(x): return x.stato in ["incapacitato", "morto"])
				if not f.is_empty():
					_esito(p.trascina(a.id, f[0].id, h))
				return
			"cedi", "sveglia":
				for x in p.unita_in(h, "us"):
					if x.id != a.id:
						_esito(p.cedi_turno(a.id, x.id) if modo == "cedi" else p.sveglia(a.id, x.id))
						return
				return
		if h in mappa.evidenzia and _puo_muovere(a):
			_esito(p.muovi(selezione.duplicate(), h))
			return
	# Selezione dei soldati sulla mappa
	var miei: Array = p.unita_in(h, "us")
	if p.fase_round():
		var di_turno: Array = p.americani_di_turno().map(func(x): return x.id)
		miei = miei.filter(func(x): return x.id in di_turno)
	if not miei.is_empty():
		if _ultimo_click == h:
			_indice_click = (_indice_click + 1) % miei.size()
		else:
			_indice_click = 0
		_ultimo_click = h
		selezione = [miei[_indice_click].id]
		modo = ""
		_aggiorna_tutto()

func _spara(a: Dictionary, g: Dictionary) -> void:
	var r := p.tiro(a.id, arma_scelta.get(a.id, ""), g.id, modo == "mirato")
	if p.s.turno.is_empty() or p.s.turno.get("azione", "") != "rapido":
		modo = ""
	_esito(r)

func _menu_bersagli(a: Dictionary, lista: Array) -> void:
	menu_bersagli.clear()
	_bersagli_menu = lista
	var arma := p.arma_di(a, arma_scelta.get(a.id, ""))
	for i in lista.size():
		var g: Dictionary = lista[i]
		var pr := p.probabilita_tiro(a, arma, g, modo == "mirato")
		menu_bersagli.add_item("%s · %s · %d%%" % [p.nome(g), T.NOMI_POSTURA[g.postura], (int(pr.prob) + 1) * 10], i)
	menu_bersagli.position = Vector2i(get_global_mouse_position())
	menu_bersagli.popup()

func _scelto_bersaglio(i: int) -> void:
	if selezione.is_empty() or i >= _bersagli_menu.size():
		return
	_spara(p.u(selezione[0]), _bersagli_menu[i])

func _sopra_mappa(h: String) -> void:
	var pannello: Control = info_hex.get_meta("pannello")
	if h == "":
		pannello.visible = false
		return
	var t := p.terreno
	var righe: Array = ["%s · %s · quota %d" % [h, t.nome_tipo(h), t.quota(h)]]
	var extra: Array = []
	if p.s.eventi.has(h):
		extra.append("segnalino Evento")
	if p.s.mine.has(h):
		extra.append("CAMPO MINATO")
	if h in ["T8", "K13", "L13"]:
		extra.append("obiettivo: edificio")
	if h in p.alture_obiettivo():
		extra.append("obiettivo: altura")
	if not extra.is_empty():
		righe.append(", ".join(extra))
	for x in p.unita_in(h, "", false):
		var st: String = T.NOMI_POSTURA.get(x.postura, x.postura)
		if x.stato != "attivo":
			st = x.stato
		righe.append("· %s — %s%s" % [p.nome(x), st, ", ferito" if x.ferito and x.stato == "attivo" else ""])
	for o in p.s.oggetti.get(h, []):
		righe.append("· a terra: " + T.ARMI.get(o.tipo, {}).get("nome", o.tipo))
	if not selezione.is_empty():
		var a := p.u(selezione[0])
		if a.hex != "" and a.hex != h:
			var v := t.vista(a.hex, h, a.postura, "standing")
			righe.append("Vista da %s: %s" % [a.lettera, "libera" if v.ok else "bloccata (" + str(v.motivo) + ")"])
			if modo in ["mirato", "rapido"]:
				var arma := p.arma_di(a, arma_scelta.get(a.id, ""))
				for g in p.unita_in(h, "de"):
					if not arma.is_empty():
						righe.append("%s: %s" % [g.lettera, p.testo_probabilita(p.probabilita_tiro(a, arma, g, modo == "mirato"))])
			elif modo in ["granata", "satchel"]:
				var pl := p.probabilita_lancio(a, modo, h)
				righe.append(p.testo_probabilita(pl) if pl.ok else "Lancio impossibile: " + str(pl.motivo))
			elif modo == "" and _puo_muovere(a) and h in mappa.evidenzia and p.fase_round():
				var c: int = t.costo_movimento(a.hex, h) if a.hex != "" else 1
				righe.append("Costo: %d PM%s" % [c, " (strisciando: tutto il movimento)" if a.postura == "crouching" else ""])
	info_hex.text = "\n".join(righe)
	pannello.visible = true
	pannello.reset_size()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE:
			if finestra.visible:
				_chiudi_finestra()
			elif riproducendo:
				_salta_tutto = true
				_avanti = true
			elif modo != "":
				modo = ""
				_aggiorna_tutto()
		elif ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			if finestra.visible:
				return
			if riproducendo:
				_premi_continua()
			elif p.s.pausa != "":
				_prosegui()

# =================================================================== esiti e riproduzione a passi
func _esito(r: Dictionary) -> void:
	if riproducendo:
		return
	if not r.get("ok", false):
		aiuto_azioni.text = "NON SI PUÒ: " + str(r.get("errore", "Azione non valida."))
		aiuto_azioni.add_theme_color_override("font_color", Color("f2a58f"))
		return
	if not (modo == "rapido" and not p.s.turno.is_empty() and p.s.turno.get("azione", "") == "rapido"):
		modo = ""
	_ultimo_esito = ""
	_attori_comando = selezione.duplicate()
	mappa.pulisci_tracce()
	_salva()
	_riproduci()

func _prosegui() -> void:
	if riproducendo:
		return
	_attori_comando = []
	p.prosegui()
	_salva()
	_riproduci()

func _premi_continua() -> void:
	if _in_attesa:
		_avanti = true
	else:
		_salta_passo = true

func _cambia_modo() -> void:
	automatico = not automatico
	_salva_preferenze()
	_aggiorna_bottoni_scheda()
	if automatico and _in_attesa:
		_avanti = true

func _cambia_velocita() -> void:
	mappa.velocita = 2.5 if mappa.velocita < 1.5 else 1.0
	_salva_preferenze()
	_aggiorna_bottoni_scheda()

func _aggiorna_bottoni_scheda() -> void:
	if sch_modo == null:
		return
	sch_modo.text = "Modo: automatico" if automatico else "Modo: passo passo"
	sch_velocita.text = "Velocità: doppia" if (mappa != null and mappa.velocita > 1.5) else "Velocità: normale"
	if _in_attesa:
		sch_continua.text = "Continua"
		sch_continua.add_theme_color_override("font_color", Color("fff3c4"))
		sch_continua.add_theme_stylebox_override("normal", Tema.scatola(Color("6b5a22"), Tema.OTTONE, 2, 3, 10))
	else:
		sch_continua.text = "Mostra subito"
		sch_continua.remove_theme_color_override("font_color")
		sch_continua.remove_theme_stylebox_override("normal")

## Sorveglianza della riproduzione: se la sequenza si interrompe a metà (un errore imprevisto),
## l’interfaccia non resta bloccata: si ripristina da sola e dice in che punto è successo.
var _battito := 0
var _gen := 0
var _punto := ""

func _process(delta: float) -> void:
	var ora := Time.get_ticks_msec()
	if delta > 1.0 or not riproducendo:
		_battito = ora
	elif ora - _battito > 4000:
		_ripristina()

func _ripristina() -> void:
	_gen += 1
	var dove := _punto
	riproducendo = false
	_in_attesa = false
	stato_vis = {}
	_mostrate = _lotto
	mappa.animazioni.clear()
	mappa.mobili.clear()
	mappa.fine_riproduzione()
	mappa.linee = []
	_aggiorna_bottoni_scheda()
	_aggiorna_tutto()
	_ultimo_esito = "La sequenza si era interrotta (%s): l’ho ripristinata, la partita continua da qui. Se ricapita, riferiscimi questo testo." % dove
	_aggiorna_azioni()
	push_warning("Riproduzione ripristinata: " + dove)

func _attendi(t: float) -> void:
	var fine := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < fine and not _salta_tutto and not _salta_passo:
		_battito = Time.get_ticks_msec()
		await get_tree().process_frame

func _attendi_clic() -> void:
	_in_attesa = true
	_avanti = false
	_aggiorna_bottoni_scheda()
	while not _avanti and not _salta_tutto and not automatico:
		_battito = Time.get_ticks_msec()
		await get_tree().process_frame
	_in_attesa = false
	_aggiorna_bottoni_scheda()

## Divide gli eventi di un comando in passi: l’azione del giocatore, poi ogni fase e ogni tedesco.
func _dividi(voci: Array, stato0: Dictionary, vista0: Dictionary) -> Array:
	var passi: Array = []
	var cor := {"tipo": "comando", "dati": {}, "voci": [], "stato": stato0, "vista": vista0}
	for v in voci:
		if v.t == "passo":
			if not cor.voci.is_empty() or cor.tipo != "comando":
				passi.append(cor)
			cor = {"tipo": str(v.tipo), "dati": v, "voci": [], "stato": v.stato, "vista": v.vista}
		else:
			cor.voci.append(v)
	if not cor.voci.is_empty() or cor.tipo != "comando":
		passi.append(cor)
	return passi

func _da_confermare(ps: Dictionary) -> bool:
	if ps.tipo != "comando":
		return true
	for v in ps.voci:
		if v.t in ["par", "errore", "danno"]:
			return true
	return false

func _durata_riga(v: Dictionary) -> float:
	var d := 0.3
	match str(v.t):
		"par":
			d = clampf(0.5 + str(v.x).length() / 400.0, 0.6, 1.4)
		"dado":
			d = 0.45
		"combattimento":
			d = 0.4
		"danno", "attivazione", "pv", "condizione":
			d = 0.5
		"azione", "tedesco", "round":
			d = 0.15
	return d / mappa.velocita

var _n_passo := 0

## Riproduce gli eventi dell’ultimo comando, un passo alla volta.
func _riproduci(ripetizione := false) -> void:
	var voci: Array = p.recenti.duplicate()
	if not ripetizione:
		_ultima_sequenza = voci
		_ultima_vista = p.vista_iniziale
		_ultimo_stato = p.stato_iniziale
	var passi := _dividi(voci, _ultimo_stato, _ultima_vista)
	var banale := true
	for v in voci:
		if v.t in ["passo", "par", "dado", "danno", "combattimento", "attivazione", "condizione", "pv", "fine", "errore"] or (v.t == "fx" and v.fx != "postura"):
			banale = false
	_lotto = voci.filter(func(v): return v.t != "fx" and v.t != "passo").size()
	if banale or passi.is_empty():
		_mostrate = _lotto
		_aggiorna_tutto()
		_dopo_riproduzione(ripetizione)
		return
	riproducendo = true
	_gen += 1
	var gen := _gen
	_battito = Time.get_ticks_msec()
	_salta_tutto = false
	_mostrate = 0
	_titolo_lotto = "OPERAZIONI"
	var tiro_proprio := {}
	mappa.evidenzia = {}
	mappa.etichette = {}
	mappa.linee = []
	_aggiorna_azioni()
	for i in passi.size():
		if gen != _gen:
			return
		var ps: Dictionary = passi[i]
		_punto = "passo %d di %d, %s" % [i + 1, passi.size(), ps.tipo]
		_battito = Time.get_ticks_msec()
		_n_passo += 1
		_salta_passo = false
		mappa.passo_corrente = _n_passo
		stato_vis = ps.stato
		mappa.stato_pannelli = ps.stato
		mappa.vista = ps.vista
		mappa.attore_id = ""
		_chiave_fase = _chiave_passo(ps)
		_prepara_scheda(ps)
		_aggiorna_pannelli()
		_render_rapporto(true)
		if not _salta_tutto and ps.tipo != "comando":
			await _attendi(0.35 / mappa.velocita)
		for v in ps.voci:
			if gen != _gen:
				return
			_battito = Time.get_ticks_msec()
			_punto = "passo %d di %d, %s, voce %s %s" % [i + 1, passi.size(), ps.tipo, v.t, v.get("fx", "")]
			if v.t == "fx":
				_scheda_fx(v)
				if v.fx == "tiro" and ps.tipo == "comando":
					tiro_proprio = v
				if _salta_tutto or _salta_passo:
					mappa.anima(v)
					continue
				var d: float = mappa.anima(v)
				if d > 0.0:
					await _attendi(d)
			else:
				_scheda_riga(v)
				_mostrate += 1
				_render_rapporto(true)
				if not _salta_tutto and not _salta_passo:
					await _attendi(_durata_riga(v))
		if gen != _gen:
			return
		_punto = "passo %d di %d, %s, chiusura" % [i + 1, passi.size(), ps.tipo]
		# Il passo è finito: i pannelli passano allo stato successivo, la scheda resta leggibile.
		var prossimo: Dictionary = passi[i + 1] if i + 1 < passi.size() else {}
		stato_vis = prossimo.get("stato", {})
		mappa.stato_pannelli = stato_vis
		mappa.vista = prossimo.vista if not prossimo.is_empty() else p.istantanea()
		mappa.animazioni.clear()
		mappa.mobili.clear()
		mappa.queue_redraw()
		_aggiorna_pannelli()
		_aggiorna_obiettivi()
		if _salta_tutto:
			continue
		if _da_confermare(ps):
			if automatico:
				_salta_passo = false
				var lunghezza := "\n".join(_perche_righe).length() + "\n".join(_esito_righe).length()
				await _attendi(clampf(1.2 + lunghezza / 110.0, 1.6, 7.0) / mappa.velocita)
			else:
				await _attendi_clic()
	if gen != _gen:
		return
	_punto = "fine sequenza"
	_mostrate = _lotto
	mappa.fine_riproduzione()
	mappa.linee = []
	riproducendo = false
	stato_vis = {}
	_ultimo_esito = _riassunto_tiro(tiro_proprio) if passi.size() == 1 and passi[0].tipo == "comando" else ""
	_aggiorna_tutto()
	_dopo_riproduzione(ripetizione)

func _dopo_riproduzione(ripetizione: bool) -> void:
	if p.s.fase == "fine":
		if not ripetizione:
			_mostra_fine()
	elif p.s.pausa != "" and not ripetizione:
		# La sequenza continua da sola: ogni passo ha già chiesto la sua conferma.
		_prosegui.call_deferred()

func _riassunto_tiro(fx: Dictionary) -> String:
	if fx.is_empty():
		return ""
	var chi := p.u(str(fx.tiratore))
	var su := p.u(str(fx.bersaglio))
	var esito := "ARMA INCEPPATA"
	if fx.esito == "colpito":
		esito = "COLPITO, " + str(fx.get("danno", ""))
	elif fx.esito == "mancato":
		esito = "MANCATO"
	var dadi := (" (serviva 0–%d, è uscito %d)" % [int(fx.prob), int(fx.dado)]) if fx.has("dado") else ""
	return "Ultimo tiro: %s contro %s: %s%s." % [chi.get("lettera", "?"), su.get("lettera", "?"), esito, dadi]

func _rivedi() -> void:
	if riproducendo or _ultima_sequenza.is_empty():
		return
	p.recenti = _ultima_sequenza.duplicate()
	mappa.pulisci_tracce()
	_riproduci(true)

## Fase da accendere nella barra durante un passo.
func _chiave_passo(ps: Dictionary) -> String:
	match str(ps.tipo):
		"consapevolezza", "evento", "iniziativa":
			return str(ps.tipo)
		"tedesco":
			return str(ps.dati.get("casella", ""))
		"fine_round":
			return "fine"
		"operazioni":
			return "fine"
	var st: Dictionary = ps.stato
	if st.get("fase", "") != "round":
		return ""
	if int(st.round.get("n", 0)) == 0:
		return "contatto"
	var c := _casella_di(st)
	return c if c != "" else _chiave_fase

# ------------------------------------------------------------------ scheda dell’azione
func _col(testo: String, colore: String) -> String:
	return "[color=#%s]%s[/color]" % [colore, testo]

func _dado(n: int) -> String:
	return "[bgcolor=#e9dfc3][color=#1c1f16][b] %d [/b][/color][/bgcolor]" % n

func _nome_vis(st: Dictionary, id: String) -> String:
	var x: Dictionary = st.get("unita", {}).get(id, p.u(id))
	if x.is_empty():
		return id
	if x.lato == "de":
		return "tedesco %d (%s)" % [int(x.num), x.lettera]
	return "%s %s" % [x.lettera, x.nome]

func _pedina_scheda(x: Dictionary) -> void:
	var chiave := ("us_" if x.lato == "us" else "ge_") + str(x.lettera)
	var tex: Texture2D = mappa.trame.get(chiave + ("_acc" if x.get("postura", "") == "crouching" else ""), mappa.trame.get(chiave))
	sch_pedina.texture = tex
	sch_pedina.visible = tex != null

func _prepara_scheda(ps: Dictionary) -> void:
	_perche_righe = []
	_perche_par = []
	_esito_righe = []
	_tipo_passo = str(ps.tipo)
	sch_esito.scroll_following = not (_tipo_passo in ["consapevolezza", "iniziativa"])
	sch_tabella.visible = false
	sch_pedina.visible = false
	sch_perche_titolo.text = "PERCHÉ"
	mappa.linee = []
	var d: Dictionary = ps.dati
	var st: Dictionary = ps.stato
	var n := int(d.get("n", st.get("round", {}).get("n", 0)))
	match str(ps.tipo):
		"tedesco":
			var g: Dictionary = st.unita.get(str(d.id), {})
			_pedina_scheda(g)
			_titolo_lotto = "TURNO DEL TEDESCO %s" % g.get("lettera", "")
			sch_titolo.text = "TEDESCO %d (%s)" % [int(g.get("num", 0)), g.get("lettera", "")]
			var turni := int(g.get("turni", 1))
			sch_sotto.text = "%s in %s, %s%s\nTurno %s di questo Round" % [g.get("nome", ""), g.get("hex", ""), T.NOMI_POSTURA.get(g.get("postura", ""), ""),
				", ferito" if g.get("ferito", false) else "", "1 di 2" if turni == 2 else "unico o ultimo"]
			sch_perche_titolo.text = "PERCHÉ · LA SUA CARTA DICE: PARAGRAFO %d" % int(d.paragrafo)
			sch_tabella.mostra(p.missione.tedeschi[str(int(g.get("num", 0)))], str(d.colonna), int(d.numero))
			sch_tabella.visible = true
			var motivo := "Colonna C %s: la Condizione in corso." % d.colonna
			if d.motivo == "autoconservazione":
				motivo = "Colonna S, autoconservazione: ha un americano nello stesso esagono o adiacente."
			elif d.motivo == "reazione":
				motivo = "Colonna R-%s: reazione speciale decisa da un paragrafo." % d.colonna
			var numero := "Numero d’azione %s %s" % [_dado(int(d.numero)), "appena tirato, vale per tutti i tedeschi di questo turno." if d.get("numero_tirato", false) else "(lo stesso per tutti i tedeschi di questo turno)."]
			var vede: Array = d.get("vede", [])
			var visti := "Non vede nessun americano." if vede.is_empty() else "Vede: " + ", ".join(vede.map(func(id): return str(st.unita.get(id, {}).get("lettera", id)))) + ("" if not linee_vista else " (linee tratteggiate sulla mappa)") + "."
			_perche_righe.append(numero + " " + motivo + " " + visti)
			for id in vede:
				var a: Dictionary = st.unita.get(id, {})
				if linee_vista and a.get("hex", "") != "" and g.get("hex", "") != "":
					mappa.linee.append({"da": g.hex, "a": a.hex, "colore": Color(0.72, 0.85, 1.0, 0.6)})
		"consapevolezza":
			_titolo_lotto = "ROUND %d · CONSAPEVOLEZZA" % n
			sch_titolo.text = "CONSAPEVOLEZZA"
			sch_sotto.text = "Round %d: chi si accorge del nemico?" % n
			if n == 1:
				_perche_righe.append("Round 1: ogni soldato che [b]vede[/b] il tedesco appena comparso tira un dado. Se non supera la sua Percezione (PC) si accorge del nemico. Chi resta inconsapevole non riceve turni in questo Round.")
			elif n == 2:
				_perche_righe.append("Round 2: chi non è ancora consapevole ritenta il controllo di Percezione, anche se è fuori mappa. Dal Round 3 tutti saranno consapevoli.")
			else:
				_perche_righe.append("Dal Round 3 tutti i soldati attivi sono consapevoli: nessun dado.")
			_perche_righe.append(_col("Chi viene attaccato da inconsapevole se ne accorge subito dopo.", C_TENUE))
			var gruppi := {"fuori": [], "non_vede": [], "gia": []}
			for r in d.get("righe", []):
				var nome := "[b]%s[/b]" % _nome_vis(st, str(r.id))
				match str(r.esito):
					"si":
						_esito_righe.append("%s: PC %d, dado %s  %s" % [nome, int(r.pc), _dado(int(r.dado)), _col("si accorge del nemico", C_VERDE)])
					"no":
						_esito_righe.append("%s: PC %d, dado %s  %s" % [nome, int(r.pc), _dado(int(r.dado)), _col("non si accorge di nulla", C_ROSSO)])
					"auto":
						_esito_righe.append("%s: %s" % [nome, _col("consapevole senza tirare (lo dice il paragrafo)", C_VERDE)])
					_:
						gruppi[str(r.esito)].append(str(st.unita.get(str(r.id), {}).get("lettera", r.id)))
			if not gruppi.gia.is_empty():
				_esito_righe.append("[b]%s[/b]: %s" % [", ".join(gruppi.gia), _col("già consapevoli", C_VERDE)])
			if not gruppi.non_vede.is_empty():
				_esito_righe.append("[b]%s[/b]: %s" % [", ".join(gruppi.non_vede), _col("non vedono il tedesco, restano inconsapevoli", C_TENUE)])
			if not gruppi.fuori.is_empty():
				_esito_righe.append("[b]%s[/b]: %s" % [", ".join(gruppi.fuori), _col("fuori mappa, nel Round 1 non tirano", C_TENUE)])
			if n > 2:
				_esito_righe.append(_col("Tutti consapevoli.", C_VERDE))
		"evento":
			_titolo_lotto = "ROUND %d · EVENTO" % n
			sch_titolo.text = "EVENTO"
			sch_sotto.text = "Round %d: controllo Evento" % n
			_perche_righe.append("Dal Round 2 ogni Round si apre con un controllo Evento: due dadi sommati, letti sulla colonna Eventi della carta della Condizione.")
			if d.has("somma"):
				var rif := str(d.get("rif", "NONE"))
				_perche_righe.append("Dadi %s + %s = [b]%d[/b]: %s" % [_dado(int(d.a)), _dado(int(d.b)), int(d.somma), "nessun evento." if rif == "NONE" else "si legge il paragrafo " + rif.get_slice(":", rif.get_slice_count(":") - 1) + "."])
		"iniziativa":
			_titolo_lotto = "ROUND %d · INIZIATIVA" % n
			sch_titolo.text = "INIZIATIVA"
			sch_sotto.text = "Round %d: chi ha il vantaggio e quanti turni ha ciascuno" % n
			var vant: String = "AMERICANO" if d.vant == "us" else "TEDESCO"
			var nota := ""
			if d.get("forzato", false):
				nota = " (lo decide il paragrafo di attivazione)"
			elif int(d.du) == int(d.dt):
				nota = " (in parità va ai tedeschi)"
			_perche_righe.append("Dado americano %s   dado tedesco %s   vantaggio [b]%s[/b]%s." % [_dado(int(d.du)), _dado(int(d.dt)), vant, nota])
			_perche_righe.append("Ognuno incrocia il dado del suo lato con la propria Iniziativa (IN) sulla pista: 2 turni, 1 turno o panico. I numeri rossi mandano nel panico solo gli americani [b]fuori comando[/b]. I feriti hanno al massimo 1 turno.")
			var primo := "americani" if d.vant == "us" else "tedeschi"
			var secondo := "tedeschi" if d.vant == "us" else "americani"
			_perche_righe.append(_col("Ordine: 2 turni %s, 2 turni %s, 1 turno %s, 1 turno %s." % [primo, secondo, primo, secondo], C_TENUE))
			for r in d.get("righe", []):
				var x: Dictionary = st.unita.get(str(r.id), {})
				var nome := "[b]%s[/b] (IN %d)" % [_nome_vis(st, str(r.id)), int(x.get("IN", 0))]
				var colore := C_USA if x.get("lato", "us") == "us" else C_DE
				var testo := ""
				if r.panico:
					testo = _col("PANICO" + (": numero rosso e fuori comando" if r.get("rosso", false) and not r.get("comando", true) else ""), C_ROSSO)
				else:
					testo = "%d turn%s" % [int(r.turni), "o" if int(r.turni) == 1 else "i"]
					if r.get("paragrafo", false):
						testo += " (dal paragrafo)"
					elif r.get("ferito", false):
						testo += " (ferito)"
					elif r.get("rosso", false):
						testo += " (numero rosso, ma è in comando)"
				_esito_righe.append("%s: %s" % [_col(nome, colore), testo])
			var ignari: Array = []
			for x in st.unita.values():
				if x.lato == "us" and x.stato in ["attivo", "fuori"] and not x.get("consapevole", false):
					ignari.append(str(x.lettera))
			if not ignari.is_empty():
				ignari.sort()
				_esito_righe.append(_col("Inconsapevoli, senza turni: " + ", ".join(ignari), C_TENUE))
		"attivazione":
			_titolo_lotto = "CONTATTO!"
			sch_titolo.text = "CONTATTO!"
			sch_sotto.text = "Un tedesco entra in gioco"
			if st.get("fase", "") == "round":
				_perche_righe.append("Un paragrafo attiva un altro nemico: entra nel Round in corso e riceve i suoi turni.")
			else:
				_perche_righe.append("Un paragrafo attiva un nemico: le Operazioni si interrompono e iniziano i [b]Round[/b]. Prima si vede chi si accorge del pericolo, poi si tira l’iniziativa e si agisce a turni.")
		"condizione":
			_titolo_lotto = "CAMBIO DI CONDIZIONE"
			sch_titolo.text = "CONDIZIONE %d" % int(d.get("n", 0))
			sch_sotto.text = "La missione cambia passo"
			_perche_righe.append("Si passa alla Condizione %d: cambiano i paragrafi letti negli esagoni, la colonna usata dai tedeschi e il livello di attivazione. I segnalini Evento vengono tolti e si ricontrollano gli esagoni occupati dalla squadra." % int(d.get("n", 0)))
		"fine_round":
			_titolo_lotto = "FINE DEL ROUND %d" % n
			sch_titolo.text = "FINE ROUND %d" % n
			sch_sotto.text = "Tutti hanno agito"
			_perche_righe.append("Chi era in panico si getta a terra. Se sulla mappa resta almeno un tedesco attivo comincia un nuovo Round, altrimenti riprendono le Operazioni.")
		"operazioni":
			_titolo_lotto = "RIPRENDONO LE OPERAZIONI"
			sch_titolo.text = "OPERAZIONI"
			sch_sotto.text = "Nessun tedesco attivo"
			_perche_righe.append("Non ci sono più tedeschi attivi sulla mappa: i Round finiscono e la squadra torna a muoversi liberamente. Al prossimo contatto tutti ripartono inconsapevoli.")
		_:
			_titolo_lotto = ("ROUND %d · TURNO AMERICANO" % n) if st.get("fase", "") == "round" and n > 0 else ("ROUND" if st.get("fase", "") == "round" else "OPERAZIONI")
			var attori: Array = _attori_comando.filter(func(id): return st.get("unita", {}).has(id))
			if attori.is_empty():
				sch_titolo.text = "LA SQUADRA"
				sch_sotto.text = ""
			else:
				var a: Dictionary = st.unita[attori[0]]
				_pedina_scheda(a)
				sch_titolo.text = ("%s %s" % [a.lettera, str(a.nome).to_upper()]) if attori.size() == 1 else "GRUPPO " + ", ".join(attori)
				sch_sotto.text = "Turno americano" if st.get("fase", "") == "round" else "Operazioni: la squadra avanza"
			sch_perche_titolo.text = "PERCHÉ · COSA DICE LA CARTA DELLA CONDIZIONE"
	sch_titolo.add_theme_font_size_override("font_size", 20 if sch_titolo.text.length() <= 11 else 15)
	_render_scheda()

func _render_scheda() -> void:
	# Il paragrafo più recente sta in alto; quelli che l’hanno preceduto restano sotto, attenuati.
	var righe: Array = _perche_righe.duplicate()
	for i in range(_perche_par.size() - 1, -1, -1):
		righe.append(_perche_par[i] if i == _perche_par.size() - 1 else _col(_perche_par[i].replace("[b]", "").replace("[/b]", ""), "8f8866"))
	sch_perche.text = "\n".join(righe)
	sch_esito.text = "\n".join(_esito_righe)

## Riga della cronaca dentro la scheda dell’azione.
func _scheda_riga(v: Dictionary) -> void:
	if _tipo_passo in ["consapevolezza", "iniziativa"] and str(v.t) in ["dado", "info"]:
		return  # già riassunto, soldato per soldato, nella scheda
	var x: String = str(v.x).replace("[", "[lb]")
	match str(v.t):
		"par":
			var pid: String = v.get("id", "")
			_perche_par.append("%s  %s" % [_col("[b]§ %s[/b]" % pid, "f2d98c"), x])
		"dado":
			_esito_righe.append(_col("   " + x, "cfc6a0"))
		"danno":
			_esito_righe.append(_col("[b]%s[/b]" % x, C_ROSSO))
		"pv":
			_esito_righe.append(_col("[b]%s[/b]" % x, C_VERDE))
		"attivazione", "condizione":
			_esito_righe.append(_col("[b]%s[/b]" % x, "ffb347"))
		"combattimento":
			_esito_righe.append("[b]%s[/b]" % x)
		"tedesco":
			if not x.begins_with("Turno del"):
				_esito_righe.append(_col(x, C_DE))
		"round", "titolo":
			pass
		"errore":
			_esito_righe.append(_col(x, C_ROSSO))
		_:
			_esito_righe.append(x)
	_render_scheda()

## Dati di un effetto dentro la scheda: il calcolo del tiro prima dei dadi.
func _scheda_fx(v: Dictionary) -> void:
	match str(v.fx):
		"tiro":
			if int(v.get("base", -1)) >= 0:
				var parti: Array = ["base %d (%s)" % [int(v.base), v.get("gittata", "")]]
				for m in v.get("mods", []):
					parti.append("%s %+d" % [m[0], int(m[1])])
				_esito_righe.append(_col("   Calcolo: %s = colpisce con 0–%d (%d%%)" % [", ".join(parti), int(v.prob), (int(v.prob) + 1) * 10], "cfc6a0"))
			else:
				_esito_righe.append(_col("   Probabilità fissata dal paragrafo: colpisce con 0–%d (%d%%)" % [int(v.prob), (int(v.prob) + 1) * 10], "cfc6a0"))
			_render_scheda()
		"attore":
			pass

# ------------------------------------------------------------------ rapporto
func _bbcode(voci: Array, attenuato := false) -> String:
	var out: Array = []
	for v in voci:
		var x: String = str(v.x).replace("[", "[lb]")
		if attenuato:
			var pre := ""
			match str(v.t):
				"par":
					pre = "§ %s  " % v.get("id", "")
					x = x.replace("\n", " ")
				"dado":
					pre = "    "
				"round", "titolo", "fine":
					x = "— %s —" % x
			out.append(pre + x)
			continue
		match str(v.t):
			"par":
				var pid: String = v.get("id", "")
				var tipo: String = p.paragrafi.get(pid, {}).get("tipo", "")
				var colore := "#7a2a1c" if tipo != "azione" else "#3d4a5c"
				out.append("[color=%s][b]§ %s[/b][/color]  %s" % [colore, pid, x.replace("\n", "\n      ")])
			"dado":
				out.append("[color=#5e5440]    %s[/color]" % x)
			"danno":
				out.append("[color=#a52a1f][b]%s[/b][/color]" % x)
			"pv":
				out.append("[color=#3f6b2f][b]%s[/b][/color]" % x)
			"condizione", "attivazione":
				out.append("[color=#a52a1f][b]%s[/b][/color]" % x)
			"round", "titolo", "fine":
				out.append("[b]— %s —[/b]" % x)
			"combattimento":
				out.append("[b]%s[/b]" % x)
			"tedesco":
				out.append("[color=#3d4a5c]%s[/color]" % x)
			"errore":
				out.append("[color=#a52a1f]%s[/color]" % x)
			_:
				out.append(x)
	return "\n".join(out)

func _aggiorna_rapporto(ricostruisci := false) -> void:
	if ricostruisci:
		_lotto = 0
	_mostrate = _lotto
	_render_rapporto(false)

## Cronaca: righe precedenti attenuate, poi la sequenza corrente con la riga in corso evidenziata.
func _render_rapporto(evidenzia: bool) -> void:
	var cron: Array = p.s.cronaca
	var inizio_lotto := maxi(0, cron.size() - _lotto)
	var vecchie: Array = cron.slice(maxi(0, inizio_lotto - 140), inizio_lotto)
	var testo := ""
	if not vecchie.is_empty():
		testo = "[color=#8c8371]" + _bbcode(vecchie, true) + "[/color]"
	if _lotto > 0:
		testo += ("\n\n" if testo != "" else "") + "[center][b][color=#7a2a1c]—  ULTIMA SEQUENZA  —[/color][/b][/center]"
		var nuove: Array = cron.slice(inizio_lotto, inizio_lotto + _mostrate)
		for i in nuove.size():
			var riga := _bbcode([nuove[i]])
			if evidenzia and i == nuove.size() - 1:
				riga = "[bgcolor=#f2d98c]" + riga + "[/bgcolor]"
			testo += "\n" + riga
	rapporto.text = testo
	titolo_rapporto.text = ("RAPPORTO · " + _titolo_lotto) if riproducendo else "RAPPORTO DI COMBATTIMENTO"

# =================================================================== finestre
func _apri_finestra(contenuto: Control, larghezza := 760.0) -> void:
	for c in finestra.get_children():
		c.queue_free()
	finestra.add_child(contenuto)
	finestra.custom_minimum_size = Vector2(larghezza, 0)
	velo.visible = true
	finestra.visible = true
	finestra.reset_size()
	await get_tree().process_frame
	finestra.reset_size()
	finestra.position = ((size - finestra.size) / 2.0).max(Vector2(10, 10))

func _chiudi_finestra() -> void:
	finestra.visible = false
	velo.visible = false

func _intestazione(vb: VBoxContainer, titolo: String, sotto := "") -> void:
	vb.add_child(Tema.titolo(titolo, 30, Tema.INCHIOSTRO))
	if sotto != "":
		vb.add_child(Tema.etichetta(sotto, Tema.testo_bold, 15, Tema.ROSSO))
	var linea := ColorRect.new()
	linea.color = Tema.INCHIOSTRO_TENUE
	linea.custom_minimum_size = Vector2(0, 2)
	vb.add_child(linea)

func _paragrafo(vb: VBoxContainer, testo: String, dim := 16, a_macchina := false) -> void:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.text = testo
	l.add_theme_font_override("normal_font", Tema.macchina if a_macchina else Tema.testo)
	l.add_theme_font_override("bold_font", Tema.testo_bold)
	l.add_theme_font_size_override("normal_font_size", dim if a_macchina else dim + 1)
	l.add_theme_font_size_override("bold_font_size", dim if a_macchina else dim + 1)
	l.add_theme_color_override("default_color", Tema.INCHIOSTRO)
	vb.add_child(l)

func _mostra_briefing(c_e_salvataggio: bool, solo_lettura := false) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_intestazione(vb, "ORDINE DI MISSIONE", "MISSIONE 1 · SANGUE A SAINT-MICHAUX · RISERVATO")
	_paragrafo(vb, p.missione.briefing, 16, true)
	_paragrafo(vb, "[b]Ingresso.[/b] " + p.missione.ingresso + " Livelli di attivazione: Condizione 1: 0–1; Condizione 2: 0–3; Condizione 3: 0–5; Condizione 4: 0–8.", 15)
	_paragrafo(vb, "[b]Vittoria: 13 PV.[/b] La missione termina in uno di due modi:\n1. Un soldato attivo nell’edificio T8, un soldato negli edifici K13–L13 e un soldato attivo sull’altura di sud-est da cui si vede tutta la strada, senza tedeschi attivi sulla mappa: ottieni 4 PV in più.\n2. Tutti i soldati attivi escono dalla mappa da A1–J1.\nPerdi 2 PV per ogni americano ucciso o incapacitato. Un incapacitato non costa PV se lo porti fuori mappa da A1–J1 o, con il primo finale, in uno dei due edifici. Altri PV si scoprono durante la missione.", 15)
	var bb := HBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_END
	if solo_lettura:
		bb.add_child(Tema.bottone("Chiudi", _chiudi_finestra))
	else:
		if c_e_salvataggio:
			bb.add_child(Tema.bottone("Nuova missione", func(): _chiudi_finestra(); _nuova()))
			var r := Tema.bottone("Riprendi la partita", _chiudi_finestra)
			bb.add_child(r)
		else:
			bb.add_child(Tema.bottone("Regole in breve", _mostra_regole))
			bb.add_child(Tema.bottone("Agli ordini: inizia", func(): _chiudi_finestra(); _seleziona_primo()))
	vb.add_child(bb)
	_apri_finestra(vb, 820)

func _seleziona_primo() -> void:
	selezione = ["A"]
	_aggiorna_tutto()

func _mostra_regole() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_intestazione(vb, "REGOLE IN BREVE", "Ambush! · Victory Games 1983 · edizione digitale")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 520)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	_paragrafo(inner, "[b]Operazioni.[/b] Finché non ci sono tedeschi attivi muovi i soldati uno alla volta o in gruppo (stesso esagono e postura), un esagono per volta, senza limiti. Ogni esagono raggiunto richiede un [b]controllo di paragrafo[/b]: il motore legge la carta Condizione nella finestrella e risolve il paragrafo. «Evento» fa tirare due dadi sulla colonna degli eventi casuali e lascia un segnalino Evento (nessun altro controllo in quell’esagono finché non cambia la Condizione).", 15)
	_paragrafo(inner, "[b]Controlli.[/b] Percezione: un dado ≤ PC del soldato (il PC più alto nell’esagono). Attivazione: un dado ≤ livello della Condizione. Lo 0 riesce sempre, il 9 fallisce sempre. Quando un tedesco si attiva iniziano i [b]Round[/b].", 15)
	_paragrafo(inner, "[b]Round.[/b] 1) Consapevolezza (Round 1 e 2): chi vede il nemico tira la percezione; dal Round 3 tutti sono consapevoli. 2) Evento (dal Round 2). 3) Iniziativa: un dado per parte; chi fa di più ha il vantaggio (pari: tedeschi). Sulla pista ogni soldato riceve 2 turni, 1 turno o panico secondo la sua iniziativa; i numeri rossi fanno andare nel panico gli americani [b]fuori comando[/b] (somma delle iniziative nell’esagono, più quella del comandante entro 2 esagoni, inferiore a 5). Agiscono prima i 2 turni in vantaggio, poi in svantaggio, poi gli 1 turno.", 15)
	_paragrafo(inner, "[b]Azioni nel turno.[/b] Un cambio di postura gratuito (non ai feriti), poi una sola azione: muovere (PM secondo il terreno; accovacciati si striscia di un esagono), muovere e fare un tiro rapido (metà PM), tiro mirato, due tiri rapidi, assalto o carica d’assalto, granata, preparare il bazooka, disinceppare, equipaggiamento, trascinare un ferito, cedere il turno o allertare (comandante), passare.", 15)
	_paragrafo(inner, "[b]Tiro.[/b] Probabilità base: stesso esagono 8, adiacente 6, corta 5, media 4, lunga 3. Modificatori: abilità (WS), tiro rapido −2, tiratore ferito −1, terreno e postura del bersaglio (scoperto: in piedi +1, prono −1; bosco −2/−3/−4…). Poi: inceppamento (percentuale), colpo (un dado ≤ probabilità), danno (panico, ferita, incapacitato, ucciso), consumo del caricatore. Le armi automatiche con tiro mirato possono colpire più bersagli nello stesso esagono.", 15)
	_paragrafo(inner, "[b]Tedeschi.[/b] Agiscono da soli: la loro carta incrocia il numero d’azione tedesco con la Condizione, la reazione speciale o l’autoconservazione (se un americano è nello stesso esagono o adiacente). Si muovono solo seguendo i riferimenti rossi della carta Condizione.", 15)
	_paragrafo(inner, "[b]Come si legge lo schermo.[/b] La barra in alto mostra sempre la fase in corso. Ogni azione viene mostrata un passo alla volta nella scheda sotto la mappa: chi agisce, perché (la carta e il dado che l’hanno deciso) e cosa succede. «Continua» (Spazio) passa al passo successivo; «Modo: automatico» fa scorrere tutto da solo. Le linee di tiro restano sulla mappa con l’esito fino al tuo comando successivo.", 15)
	_paragrafo(inner, "[b]Comandi.[/b] Mouse: rotella per lo zoom, trascina per spostare la mappa, passaggio sopra un esagono per terreno, linea di vista e probabilità. Tocco: un dito trascina, due dita pizzicano per lo zoom, un tocco su un esagono lo sceglie e ne mostra le informazioni. Esc annulla la modalità. La partita si salva da sola sul dispositivo.", 15)
	vb.add_child(sc)
	var bb := HBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_END
	bb.add_child(Tema.bottone("Chiudi", func(): _chiudi_finestra(); if p.s.cronaca.size() <= 3: _mostra_briefing(false)))
	vb.add_child(bb)
	_apri_finestra(vb, 860)

func _mostra_carta(x: Dictionary) -> void:
	var vb := VBoxContainer.new()
	var tr := TextureRect.new()
	tr.texture = load("res://assets/carte/us05.jpg" if x.lato == "us" else "res://assets/carte/ge%02d.jpg" % int(x.num))
	tr.custom_minimum_size = Vector2(380, 540)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(tr)
	if x.lato == "de":
		var righe: Array = ["%s · %s" % [p.nome(x), {"attivo": "attivo in " + x.hex}.get(x.stato, x.stato)]]
		if x.reazione != "":
			righe.append("Reazione speciale %s in vigore" % x.reazione)
		for arma in x.armi:
			var st := ""
			if arma.inceppata: st = " (inceppata)"
			if arma.rotta: st = " (rotta)"
			if arma.get("scarica", false): st = " (senza munizioni)"
			righe.append("· " + T.ARMI[arma.tipo].nome + st)
		_paragrafo(vb, "\n".join(righe), 15)
	var bb := HBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_END
	bb.add_child(Tema.bottone("Chiudi", _chiudi_finestra))
	vb.add_child(bb)
	_apri_finestra(vb, 440)

func _mostra_fine() -> void:
	var f: Dictionary = p.s.fine
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_intestazione(vb, "MISSIONE CONCLUSA", "VITTORIA" if f.get("vinta", false) else "SCONFITTA")
	var righe: Array = ["[b]Punti ottenuti durante la missione:[/b] %d" % int(f.get("pv_partita", 0))]
	for v in p.s.pv:
		righe.append("    %+d  %s" % [int(v.n), v.motivo])
	righe.append("")
	for r in f.get("righe", []):
		righe.append("%+d  %s" % [int(r[1]), r[0]])
	righe.append("")
	righe.append("[b]TOTALE: %d PV[/b] (servono 13)" % int(f.get("totale", 0)))
	_paragrafo(vb, "\n".join(righe), 16)
	var bb := HBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_END
	bb.add_child(Tema.bottone("Chiudi", _chiudi_finestra))
	bb.add_child(Tema.bottone("Nuova partita", func(): _chiudi_finestra(); _nuova()))
	vb.add_child(bb)
	_apri_finestra(vb, 640)

func _conferma(titolo: String, testo: String, ok: Callable) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_intestazione(vb, titolo)
	_paragrafo(vb, testo, 16)
	var bb := HBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_END
	bb.add_child(Tema.bottone("Annulla", _chiudi_finestra))
	bb.add_child(Tema.bottone("Conferma", func(): _chiudi_finestra(); ok.call()))
	vb.add_child(bb)
	_apri_finestra(vb, 520)

func _finestra_equipaggiamento(id: String) -> void:
	var a := p.u(id)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_intestazione(vb, "EQUIPAGGIAMENTO · " + p.nome(a).to_upper(), "Caselle di porto %d/%d · munizioni %d/6" % [p.porte_usate(a), p.porte_massime(a), p.scatole_munizioni(a)])
	_paragrafo(vb, "Raccogliere da un caduto richiede di essere accovacciati; da prono non si raccoglie nulla. Nei Round ogni scambio è un’azione.", 14)
	var griglia := VBoxContainer.new()
	for arma in a.armi:
		var hb := HBoxContainer.new()
		var l := Tema.etichetta("Porta: " + T.ARMI.get(arma.tipo, {}).get("nome", arma.tipo), Tema.macchina, 15, Tema.INCHIOSTRO)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		hb.add_child(Tema.bottone("Lascia a terra", func(): _chiudi_finestra(); _esito(p.lascia(id, arma.tipo))))
		griglia.add_child(hb)
	for voce in p.oggetti_disponibili(id):
		var hb := HBoxContainer.new()
		var l := Tema.etichetta(("A terra: " if voce.da == "terra" else "") + str(voce.testo), Tema.macchina, 15, Tema.INCHIOSTRO)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		hb.add_child(Tema.bottone("Prendi", func(): _chiudi_finestra(); _esito(p.prendi(id, voce))))
		griglia.add_child(hb)
	if griglia.get_child_count() == 0:
		_paragrafo(vb, "Niente da scambiare qui.", 15)
	vb.add_child(griglia)
	var bb := HBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_END
	bb.add_child(Tema.bottone("Chiudi", _chiudi_finestra))
	vb.add_child(bb)
	_apri_finestra(vb, 620)

func _chiedi_nuova() -> void:
	_conferma("Nuova partita?", "La missione in corso andrà persa.", _nuova)

func _nuova() -> void:
	p.nuova(0, true)
	selezione = ["A"]
	modo = ""
	_ultimo_esito = ""
	_ultima_sequenza = []
	mappa.pulisci_tracce()
	mappa.vista_iniziale.call_deferred()
	_salva()
	_aggiorna_tutto(true)
	mappa.centra()
	_mostra_briefing(false)

# =================================================================== salvataggio
func _salva() -> void:
	var f := FileAccess.open(SALVATAGGIO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(p.salva()))

func _leggi_salvataggio() -> Dictionary:
	if not FileAccess.file_exists(SALVATAGGIO):
		return {}
	var testo := FileAccess.get_file_as_string(SALVATAGGIO)
	var d = JSON.parse_string(testo)
	if d is Dictionary and d.get("fase", "") != "fine":
		return d
	return {}

func _leggi_preferenze() -> void:
	if not FileAccess.file_exists(PREFERENZE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PREFERENZE))
	if d is Dictionary:
		automatico = bool(d.get("automatico", false))
		linee_vista = bool(d.get("linee_vista", true))
		_velocita_iniziale = float(d.get("velocita", 1.0))

var _velocita_iniziale := 1.0

func _salva_preferenze() -> void:
	var f := FileAccess.open(PREFERENZE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"automatico": automatico, "velocita": mappa.velocita, "linee_vista": linee_vista}))

func _mostra_legenda() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_intestazione(vb, "LEGENDA", "Cosa significano i segni sulla mappa e sui pannelli")
	_paragrafo(vb, "[b]Pedine.[/b] Gialle: americani. Grigio-azzurre: tedeschi. Nello stesso esagono stanno affiancate, mai coperte. Bordo ottone: soldato scelto. Bordo verde che pulsa: può agire adesso.", 15)
	_paragrafo(vb, "[b]Stati sulla pedina.[/b] Pedina scurita con un punto di domanda: inconsapevole, non riceve turni. Pallini in basso a destra: turni che gli restano in questo Round. Fascia rossa PANICO: non agisce e a fine Round si getta a terra. Croce rossa: ferito. Segnalino PRONE: prono.", 15)
	_paragrafo(vb, "[b]Linee.[/b] Linea piena con freccia: un tiro, gialla se spara un americano e arancione se spara un tedesco, con l’esito scritto sul bersaglio. Resta finché non dai il comando successivo; i tiri dei passi precedenti si attenuano. Linea tratteggiata rossa: un tedesco che il soldato scelto vede. Linea tratteggiata azzurra: un americano che il tedesco di turno vede. Tratteggio con freccia: un movimento.", 15)
	_paragrafo(vb, "[b]Esagoni.[/b] Verde: dove puoi muovere. Rosso: bersaglio valido, con la probabilità di colpire. Arancione: dove puoi lanciare. Azzurro: compagno che puoi comandare. Bordo ottone fisso: obiettivo della missione.", 15)
	_paragrafo(vb, "[b]Pista dei Round.[/b] Ogni soldato è una casella con la sua lettera, nella riga dei turni che gli restano. La casella con il bordo giallo è quella che sta agendo.", 15)
	var bb := HBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_END
	bb.add_child(Tema.bottone("Chiudi", _chiudi_finestra))
	vb.add_child(bb)
	_apri_finestra(vb, 860)
