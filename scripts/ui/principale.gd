extends Control
## Interfaccia principale: scheda della squadra, mappa, comandi, pista dei Round, carte tedesche e rapporto.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")
const MappaScript = preload("res://scripts/ui/mappa.gd")
const PistaScript = preload("res://scripts/ui/pista.gd")
const SALVATAGGIO := "user://ambush_missione1.json"

var p: Partita
var mappa: Control
var pista: Control
var selezione: Array = []
var modo := ""          # "", mirato, rapido, granata, satchel, trascina, cedi, sveglia, assalto
var arma_scelta := {}   # id soldato → tipo arma
var _ultimo_click := ""
var _indice_click := 0

# nodi
var lista_squadra: VBoxContainer
var barra_fase: Label
var barra_cond: Label
var barra_pv: Label
var caselle_avv: Array = []
var titolo_azioni: Label
var aiuto_azioni: Label
var flusso_azioni: HFlowContainer
var info_hex: Label
var rapporto: RichTextLabel
var titolo_rapporto: Label
## Righe della cronaca che appartengono all’ultima sequenza e quante ne sono già state mostrate.
var _lotto := 0
var _mostrate := 0
var _titolo_lotto := ""
var carte_box: HFlowContainer
var obiettivi_box: VBoxContainer
var velo: ColorRect
var finestra: PanelContainer
var menu_bersagli: PopupMenu
var riproducendo := false
var _salta := false
var _bersagli_menu: Array = []
var _log_mostrati := 0

func _ready() -> void:
	theme = Tema.tema()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	p = Partita.new()
	_costruisci()
	var dati := _leggi_salvataggio()
	if not dati.is_empty() and p.carica(dati):
		_aggiorna_tutto(true)
		_mostra_briefing(true)
	else:
		p.nuova()
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
	hb.add_theme_constant_override("separation", 14)
	pc.add_child(hb)
	var t := Tema.titolo("AMBUSH!", 34, Color("efe6c8"))
	hb.add_child(t)
	var sub := VBoxContainer.new()
	sub.add_theme_constant_override("separation", -4)
	sub.add_child(Tema.etichetta("MISSIONE 1 · SANGUE A SAINT-MICHAUX", Tema.testo_bold, 16, Tema.OTTONE))
	sub.add_child(Tema.etichetta("Normandia, fine giugno 1944 · solitario", Tema.testo, 13, Tema.KAKI_SPENTO))
	hb.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	barra_fase = _badge(hb, "OPERAZIONI")
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
	pc.custom_minimum_size = Vector2(340, 0)
	pc.add_theme_stylebox_override("panel", Tema.carta(10))
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	var testa := HBoxContainer.new()
	testa.add_child(Tema.titolo("SCHEDA DELLA SQUADRA", 19, Tema.INCHIOSTRO))
	vb.add_child(testa)
	var nota := Tema.etichetta("Clic per scegliere · Maiusc/Ctrl+clic per un gruppo", Tema.testo, 12, Tema.INCHIOSTRO_TENUE)
	vb.add_child(nota)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lista_squadra = VBoxContainer.new()
	lista_squadra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_squadra.add_theme_constant_override("separation", 4)
	sc.add_child(lista_squadra)
	vb.add_child(sc)
	return pc

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
	zoom_box.add_child(Tema.bottone("−", func(): mappa.zoom_a(1 / 1.25, mappa.size / 2)))
	zoom_box.add_child(Tema.bottone("+", func(): mappa.zoom_a(1.25, mappa.size / 2)))
	zoom_box.add_child(Tema.bottone("Intera mappa", func(): mappa.centra()))
	var cb := CheckButton.new()
	cb.text = "Linea di vista"
	cb.button_pressed = true
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_color_override("font_color", Tema.KAKI)
	cb.toggled.connect(func(v): mappa.mostra_vista = v; mappa.queue_redraw())
	zoom_box.add_child(cb)
	sovra.add_child(zoom_box)
	var info_pc := PanelContainer.new()
	info_pc.add_theme_stylebox_override("panel", Tema.scatola(Color(0.91, 0.87, 0.76, 0.93), Color("7a6c4c"), 1, 2, 8))
	info_pc.anchor_top = 1.0
	info_pc.anchor_bottom = 1.0
	info_pc.offset_left = 10
	info_pc.offset_top = -12
	info_pc.offset_bottom = -12
	info_pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info_pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_hex = Tema.etichetta("", Tema.macchina, 14, Tema.INCHIOSTRO)
	info_hex.custom_minimum_size = Vector2(300, 0)
	info_hex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_pc.add_child(info_hex)
	sovra.add_child(info_pc)
	info_pc.visible = false
	info_hex.set_meta("pannello", info_pc)
	vb.add_child(cornice)
	# Barra dei comandi
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", Tema.pannello_oliva(12))
	barra.custom_minimum_size = Vector2(0, 128)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	barra.add_child(bv)
	titolo_azioni = Tema.etichetta("", Tema.testo_bold, 17, Color("f0e7c9"))
	bv.add_child(titolo_azioni)
	aiuto_azioni = Tema.etichetta("", Tema.testo, 14, Tema.KAKI_SPENTO)
	aiuto_azioni.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(aiuto_azioni)
	flusso_azioni = HFlowContainer.new()
	flusso_azioni.add_theme_constant_override("h_separation", 6)
	flusso_azioni.add_theme_constant_override("v_separation", 6)
	bv.add_child(flusso_azioni)
	vb.add_child(barra)
	return vb

func _colonna_destra() -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(372, 0)
	vb.add_theme_constant_override("separation", 8)
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", Tema.pannello_oliva(8))
	var pv := VBoxContainer.new()
	pv.add_child(Tema.titolo("PISTA DEI ROUND", 16, Tema.OTTONE))
	pista = PistaScript.new()
	pista.partita = p
	pv.add_child(pista)
	pp.add_child(pv)
	vb.add_child(pp)
	# Obiettivi e carte tedesche
	var op := PanelContainer.new()
	op.add_theme_stylebox_override("panel", Tema.pannello_oliva(8))
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 3)
	ov.add_child(Tema.titolo("OBIETTIVI", 16, Tema.OTTONE))
	obiettivi_box = VBoxContainer.new()
	obiettivi_box.add_theme_constant_override("separation", 1)
	ov.add_child(obiettivi_box)
	carte_box = HFlowContainer.new()
	carte_box.add_theme_constant_override("h_separation", 4)
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
	rapporto = RichTextLabel.new()
	rapporto.bbcode_enabled = true
	rapporto.scroll_following = true
	rapporto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rapporto.add_theme_font_override("normal_font", Tema.macchina)
	rapporto.add_theme_font_override("bold_font", Tema.testo_bold)
	rapporto.add_theme_font_size_override("normal_font_size", 14)
	rapporto.add_theme_font_size_override("bold_font_size", 14)
	rapporto.add_theme_color_override("default_color", Tema.INCHIOSTRO)
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

# =================================================================== aggiornamento
func _aggiorna_tutto(ricostruisci_log := false) -> void:
	_pulisci_selezione()
	_aggiorna_barra()
	_aggiorna_squadra()
	_aggiorna_azioni()
	_aggiorna_obiettivi()
	_aggiorna_mappa()
	_aggiorna_rapporto(ricostruisci_log)
	pista.queue_redraw()

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

func _aggiorna_barra() -> void:
	var s := p.s
	if s.fase == "round":
		barra_fase.text = "ROUND %d" % int(s.round.get("n", 0))
		barra_fase.add_theme_color_override("font_color", Color("f08d74"))
	elif s.fase == "fine":
		barra_fase.text = "FINE MISSIONE"
		barra_fase.add_theme_color_override("font_color", Tema.OTTONE)
	else:
		barra_fase.text = "OPERAZIONI"
		barra_fase.add_theme_color_override("font_color", Tema.KAKI)
	barra_cond.text = "CONDIZIONE %d · ATT. 0–%d" % [int(s.condizione), p.livello_attivazione()]
	barra_pv.text = "PV %d / %d" % [p.pv_totali(), int(p.missione.vittoria_pv)]
	for i in 10:
		var on: bool = s.avvistamenti[i]
		var box: PanelContainer = caselle_avv[i]
		box.add_theme_stylebox_override("panel", Tema.scatola(Color("8f2a1e") if on else Color("2a2e21"), Color("c9a24a") if on else Color("596146"), 1, 1, 0))
		(box.get_child(0) as Label).add_theme_color_override("font_color", Color("f6eacb") if on else Tema.KAKI_SPENTO)
		box.tooltip_text = "Avvistamento s%d %s" % [i, "avvenuto" if on else "non ancora avvenuto"]

func _aggiorna_mappa() -> void:
	mappa.selezionati = selezione
	var ev := {}
	var a: Dictionary = p.u(selezione[0]) if not selezione.is_empty() else {}
	mappa.origine_vista = a.hex if not a.is_empty() else ""
	mappa.postura_vista = a.postura if not a.is_empty() else "standing"
	if not a.is_empty() and p.s.pausa == "" and p.s.fase != "fine":
		if modo == "" and _puo_muovere(a):
			for h in p.destinazioni(a.id):
				ev[h] = Color("8fd16a")
		elif modo in ["mirato", "rapido"]:
			var arma := p.arma_di(a, arma_scelta.get(a.id, ""))
			for g in p.tedeschi_attivi():
				if not arma.is_empty():
					var pr := p.probabilita_tiro(a, arma, g, modo == "mirato")
					if pr.ok:
						ev[g.hex] = Color("e0503c")
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
	mappa.queue_redraw()

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
	var di_turno: Array = p.americani_di_turno().map(func(a): return a.id)
	for a in p.americani():
		lista_squadra.add_child(_riga_soldato(a, a.id in selezione, a.id in di_turno))

func _riga_soldato(a: Dictionary, sel: bool, turno: bool) -> Control:
	var pc := PanelContainer.new()
	var colore := Color("efe6cb") if not sel else Color("f4dfa0")
	var bordo := Color("b4a47b") if not sel else Tema.OTTONE
	if turno and not sel:
		bordo = Tema.VERDE_OK
	var st := Tema.scatola(colore, bordo, 2 if (sel or turno) else 1, 3, 8)
	if a.stato in ["morto"]:
		st.bg_color = Color("cfc5ad")
	pc.add_theme_stylebox_override("panel", st)
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.gui_input.connect(func(ev): _clic_riga(ev, a.id))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	var tr := TextureRect.new()
	var chiave := "us_" + str(a.lettera) + ("_acc" if a.postura == "crouching" else "")
	tr.texture = mappa.trame.get(chiave, mappa.trame.get("us_" + str(a.lettera)))
	tr.custom_minimum_size = Vector2(46, 46)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if a.stato == "morto":
		tr.modulate = Color(0.5, 0.5, 0.5)
	hb.add_child(tr)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var r1 := HBoxContainer.new()
	r1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nome := Tema.etichetta("%s · %s%s" % [a.lettera, str(a.nome).to_upper(), "  ★" if a.comandante else ""], Tema.testo_bold, 16, Tema.INCHIOSTRO)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(nome)
	var dove := "fuori mappa" if a.stato == "fuori" else ("uscito" if a.stato == "uscito" else str(a.hex))
	r1.add_child(Tema.etichetta(dove, Tema.stencil, 15, Tema.INCHIOSTRO_TENUE))
	vb.add_child(r1)
	if a.get("senza_carta", false):
		vb.add_child(Tema.etichetta("Superstite dell’imboscata · da portare in salvo", Tema.testo, 13, Tema.INCHIOSTRO_TENUE))
	else:
		vb.add_child(Tema.etichetta("IN %d · PC %d · WS %+d · PM %d" % [int(a.IN), int(a.PC), int(a.WS), p.effettivo_mpa(a)], Tema.testo, 13, Tema.INCHIOSTRO_TENUE))
	var armi: Array = []
	for arma in a.armi:
		var n: String = T.ARMI.get(arma.tipo, {}).get("breve", arma.tipo)
		if arma.tipo in ["satchel"]:
			n = "Carica" + (" pronta" if arma.preparata else "")
		elif arma.tipo == "bazooka":
			n = "Bazooka %s (%d)" % ["carico" if arma.preparata else "scarico", p.munizioni_arma(a, "bazooka")]
		elif arma.tipo != "pistol" or true:
			n += " (%d)" % p.munizioni_arma(a, arma.tipo)
		if arma.inceppata:
			n += " INCEPPATA"
		if arma.rotta:
			n += " ROTTA"
		armi.append(n)
	var gr := int(a.munizioni.get("granata", 0))
	if gr > 0:
		armi.append("%d granat%s" % [gr, "a" if gr == 1 else "e"])
	if not armi.is_empty():
		var la := Tema.etichetta(" · ".join(armi), Tema.testo, 13, Tema.INCHIOSTRO)
		la.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(la)
	var stati := HFlowContainer.new()
	stati.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stati.add_theme_constant_override("h_separation", 4)
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
			stati.add_child(_chip("FUORI MAPPA (USCITO)", Color("50604a")))
	if p.fase_round() and (a.stato == "attivo" or a.stato == "fuori"):
		if a.panico:
			stati.add_child(_chip("PANICO", Tema.ROSSO))
		elif not a.consapevole:
			stati.add_child(_chip("inconsapevole", Color("6a6a5a")))
		elif int(a.turni) > 0:
			stati.add_child(_chip("●".repeat(int(a.turni)) + " turn" + ("o" if int(a.turni) == 1 else "i"), Tema.VERDE_OK))
		else:
			stati.add_child(_chip("turno concluso", Color("7a735a")))
	if not a.prigionieri.is_empty():
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
	if multi and p.s.fase == "operazioni" and not selezione.is_empty():
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

# ------------------------------------------------------------------ obiettivi e carte
func _aggiorna_obiettivi() -> void:
	for c in obiettivi_box.get_children():
		c.queue_free()
	var v := p.condizioni_vittoria()
	var alt: Array = p.alture_obiettivo()
	var righe := [
		[v.t8, "Un soldato attivo nell’edificio T8"],
		[v.kl, "Un soldato negli edifici K13–L13"],
		[v.altura != "", "Un soldato sull’altura (%s) con vista sulla strada" % ", ".join(alt)],
		[v.nessun_tedesco, "Nessun tedesco attivo sulla mappa"],
		[p.pv_totali() + (4 if v.ok else 0) >= 13, "13 punti vittoria (ora %d)" % p.pv_totali()],
	]
	for r in righe:
		var l := Tema.etichetta(("☑ " if r[0] else "☐ ") + r[1], Tema.testo, 14, Color("cfe3b4") if r[0] else Tema.KAKI_SPENTO)
		obiettivi_box.add_child(l)
	for c in carte_box.get_children():
		c.queue_free()
	for g in p.tedeschi():
		var b := TextureButton.new()
		var tex: Texture2D = load("res://assets/carte/ge%02d.jpg" % int(g.num))
		b.texture_normal = tex
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
		b.custom_minimum_size = Vector2(64, 92)
		var stato: String = {"attivo": "attivo in %s" % g.hex, "morto": "ucciso", "incapacitato": "incapacitato", "catturato": "catturato", "arreso": "arreso", "rimosso": "dileguato", "uscito": "uscito dalla mappa"}.get(g.stato, g.stato)
		b.tooltip_text = "Tedesco %d (%s), %s · %s%s" % [int(g.num), g.lettera, str(g.nome).to_lower(), stato, ("\nReazione speciale " + g.reazione) if g.reazione != "" else ""]
		if not p.in_mappa(g):
			b.modulate = Color(0.55, 0.55, 0.55)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): _mostra_carta(g))
		carte_box.add_child(b)
	if p.u("J").get("stato", "") != "":
		var b := TextureButton.new()
		b.texture_normal = load("res://assets/carte/us05.jpg")
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
		b.custom_minimum_size = Vector2(64, 92)
		b.tooltip_text = "Pilota britannico (J)"
		b.pressed.connect(func(): _mostra_carta(p.u("J")))
		carte_box.add_child(b)

# ------------------------------------------------------------------ comandi
func _aggiorna_azioni() -> void:
	for c in flusso_azioni.get_children():
		c.queue_free()
	var s := p.s
	if riproducendo:
		titolo_azioni.text = "AZIONE IN CORSO · " + _titolo_lotto
		aiuto_azioni.text = "Segui sulla mappa chi agisce (anello giallo), le frecce di tiro e i movimenti; il rapporto a destra avanza riga per riga. Spazio per saltare."
		_b("Più veloce" if mappa.velocita < 1.5 else "Velocità normale", func(): mappa.velocita = 2.5 if mappa.velocita < 1.5 else 1.0; _aggiorna_azioni())
		_b("Salta ▸▸", func(): _salta = true, "Mostra subito l’esito (Spazio)")
		return
	if s.fase == "fine":
		titolo_azioni.text = "MISSIONE CONCLUSA"
		aiuto_azioni.text = "Totale %d PV · %s" % [int(s.fine.get("totale", 0)), "vittoria" if s.fine.get("vinta", false) else "sconfitta"]
		_b("Resoconto finale", _mostra_fine)
		_b("Nuova partita", _chiedi_nuova)
		return
	if s.pausa != "":
		titolo_azioni.text = "IN ATTESA DI ORDINI"
		aiuto_azioni.text = "Premi «Continua» (Spazio) per passare alla fase successiva. «Rivedi» ripete l’ultima sequenza sulla mappa."
		var c := _b("Continua ▸", _prosegui, "Spazio o Invio")
		c.custom_minimum_size = Vector2(170, 36)
		_b("Rivedi", _rivedi)
		return
	if selezione.is_empty():
		titolo_azioni.text = "NESSUN SOLDATO SCELTO"
		if p.fase_round():
			aiuto_azioni.text = "I tedeschi stanno agendo."
			_b("Continua", _prosegui)
		else:
			aiuto_azioni.text = "Scegli un soldato nella scheda della squadra o sulla mappa."
		_azioni_missione()
		return
	var a := p.u(selezione[0])
	var nomi: Array = selezione.map(func(id): return p.u(id).lettera)
	var dove: String = "fuori mappa" if a.stato == "fuori" else a.hex
	if selezione.size() > 1:
		titolo_azioni.text = "GRUPPO %s · %s · %s" % [", ".join(nomi), dove, T.NOMI_POSTURA[a.postura]]
	else:
		titolo_azioni.text = "%s %s · %s · %s" % [a.lettera, str(a.nome).to_upper(), dove, T.NOMI_POSTURA[a.postura]]
	var err := p.puo_agire(a)
	if p.s.fase == "operazioni":
		_azioni_operazioni(a)
	elif err != "":
		aiuto_azioni.text = err
	else:
		_azioni_round(a)
	_azioni_missione()

func _b(testo: String, cb: Callable, tip := "", attivo := true) -> Button:
	var b := Tema.bottone(testo, cb, tip)
	b.disabled = not attivo
	flusso_azioni.add_child(b)
	return b

func _sep() -> void:
	var c := ColorRect.new()
	c.color = Color(0.8, 0.7, 0.4, 0.25)
	c.custom_minimum_size = Vector2(2, 30)
	flusso_azioni.add_child(c)

func _azioni_posture(a: Dictionary, costo := "") -> void:
	for k in ["standing", "crouching", "prone"]:
		var b := _b(_maiuscola(T.NOMI_POSTURA[k]) + costo, func(): _esito(p.cambia_postura(a.id, k)), "", a.postura != k and a.hex != "")
		if a.postura == k:
			b.add_theme_stylebox_override("disabled", Tema.scatola(Color("55603f"), Tema.OTTONE, 1, 3, 10))
			b.add_theme_color_override("font_disabled_color", Color("f0e7c9"))

func _maiuscola(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)

func _azioni_operazioni(a: Dictionary) -> void:
	if a.stato == "fuori":
		aiuto_azioni.text = "Clicca un esagono evidenziato del margine nord (A1–J1) per entrare. Ogni ingresso richiede un controllo di paragrafo."
	else:
		aiuto_azioni.text = "Clicca un esagono adiacente evidenziato per muovere%s. Nessun limite di movimento durante le Operazioni." % (" il gruppo" if selezione.size() > 1 else "")
	if a.hex != "" and selezione.size() == 1:
		_azioni_posture(a)
		_sep()
	if a.hex != "":
		var compagni: Array = p.unita_in(a.hex, "us").filter(func(x): return x.postura == a.postura)
		if compagni.size() > 1:
			_b("Gruppo nell’esagono (%d)" % compagni.size(), func(): selezione = compagni.map(func(x): return x.id); _aggiorna_tutto())
	if selezione.size() > 1:
		return
	_azioni_equipaggiamento(a)

func _azioni_equipaggiamento(a: Dictionary) -> void:
	if a.hex == "":
		return
	_sep()
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
		_b("Trascina " + inattivi[0].lettera, func(): modo = "trascina"; _aggiorna_tutto(), "Poi clicca l’esagono adiacente. Il soldato deve essere in piedi.")
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
		aiuto_azioni.text = "%s: restano %d punti movimento%s. Clicca un esagono evidenziato; accovacciato si striscia di un solo esagono." % [testi[azione], int(t.mp), " · cambio di postura gratuito disponibile" if cambio else ""]
		_azioni_posture(a, "" if cambio else " (1 PM)")
		_sep()
		if azione == "muovi_spara" and int(t.spari) == 0:
			_bottoni_fuoco(a, false)
		if azione == "carica":
			var qui: Array = p.unita_in(a.hex, "de")
			for g in qui:
				_b("Assalto a %s (uccidere)" % g.lettera, func(): _esito(p.assalta(a.id, g.id, "uccidi")))
				_b("Assalto a %s (catturare)" % g.lettera, func(): _esito(p.assalta(a.id, g.id, "cattura")))
		if azione != "carica" or p.unita_in(a.hex, "de").is_empty():
			_b("Fine movimento", func(): _esito(p.fine_azione(a.id)) if azione != "carica" else _annulla_carica(a))
		return
	if azione == "rapido":
		aiuto_azioni.text = "Secondo tiro rapido: clicca un bersaglio in rosso oppure termina."
		_bottoni_fuoco(a, false)
		_b("Termina l’azione", func(): _esito(p.fine_azione(a.id)))
		return
	var altri: Array = di_turno.filter(func(x): return x.id != a.id).map(func(x): return x.lettera)
	aiuto_azioni.text = "Turno di %s: scegli un’azione.%s%s" % [a.nome, " Cambio di postura gratuito." if cambio else "", (" Possono agire anche: " + ", ".join(altri) + ".") if not altri.is_empty() else ""]
	if a.stato == "fuori":
		_b("Entra sulla mappa", func(): _esito(p.scegli_azione(a.id, "muovi")), "Spendi i punti movimento per il primo esagono del margine nord.")
		_b("Passa", func(): _esito(p.passa(a.id)))
		return
	_azioni_posture(a, "" if cambio else " (1 PM)")
	_sep()
	_b("Muovi", func(): _esito(p.scegli_azione(a.id, "muovi")), "Spendi i punti movimento (PM %d)." % p.effettivo_mpa(a), a.postura != "prone")
	_b("Muovi e spara", func(): _esito(p.scegli_azione(a.id, "muovi_spara")), "Metà dei PM e un tiro rapido, prima o dopo.", a.postura != "prone")
	_bottoni_fuoco(a, true)
	_b("Due tiri rapidi", func(): _imposta_modo(a, "rapido"), "Due tiri rapidi (−2 ciascuno), anche a bersagli diversi.", a.postura != "prone")
	var nemici_qui: Array = p.unita_in(a.hex, "de")
	for g in nemici_qui:
		_b("Assalto a %s (uccidere)" % g.lettera, func(): _esito(p.assalta(a.id, g.id, "uccidi")), "Bisogna essere in piedi.")
		_b("Assalto a %s (catturare)" % g.lettera, func(): _esito(p.assalta(a.id, g.id, "cattura")), "Bisogna essere in piedi.")
	_b("Carica d’assalto", func(): _esito(p.scegli_azione(a.id, "carica")), "Muovi con metà dei PM ed entra nell’esagono nemico per assaltare (−3).", a.postura == "standing")
	if int(a.munizioni.get("granata", 0)) > 0:
		_b("Granata (%d)" % int(a.munizioni.granata), func(): _imposta_modo(a, "granata"), "In piedi fino a 6 esagoni, accovacciato fino a 3.", a.postura != "prone")
	var sc := p.arma_di(a, "satchel")
	if not sc.is_empty() and sc.preparata:
		_b("Lancia la carica", func(): _imposta_modo(a, "satchel"), "Solo in piedi, fino a 3 esagoni.", a.postura == "standing")
	if a.comandante and not a.panico:
		_b("Cedi il turno", func(): _imposta_modo(a, "cedi"), "Dai un turno a un soldato entro 2 esagoni (non ferito).")
		_b("Allerta un soldato", func(): _imposta_modo(a, "sveglia"), "Rendi consapevole un soldato entro 2 esagoni.")
	_azioni_equipaggiamento(a)
	_sep()
	_b("Passa", func(): _esito(p.passa(a.id)))

func _bottoni_fuoco(a: Dictionary, mirato: bool) -> void:
	var armi: Array = p.armi_da_fuoco(a)
	if not mirato:
		armi = armi.filter(func(x): return x.tipo != "bazooka")
	if armi.is_empty():
		return
	if not armi_scelta_valida(a, armi):
		arma_scelta[a.id] = armi[0].tipo
	if armi.size() > 1:
		for arma in armi:
			var b := _b(("▸ " if arma_scelta[a.id] == arma.tipo else "") + T.ARMI[arma.tipo].breve, func(): arma_scelta[a.id] = arma.tipo; _aggiorna_tutto(), "Arma da usare")
	if mirato:
		_b("Tiro mirato", func(): _imposta_modo(a, "mirato"), "Un tiro senza malus; il bazooka spara solo mirato.", a.postura != "prone")
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
	if not _ultima_sequenza.is_empty() and p.s.pausa == "" and not riproducendo:
		_sep()
		_b("↺ Rivedi", _rivedi, "Ripeti sulla mappa l’ultima sequenza di eventi")
	if p.s.fase == "operazioni" and p.condizioni_vittoria().ok:
		_sep()
		var b := _b("★ Missione compiuta: termina", func(): _conferma("Terminare la missione?", "Tutti gli obiettivi sono raggiunti: ottieni 4 PV supplementari. I soldati incapacitati negli edifici non fanno perdere punti.", func(): _esito(p.termina_missione("obiettivo"))))
		b.add_theme_color_override("font_color", Tema.OTTONE)

func _imposta_modo(a: Dictionary, m: String) -> void:
	modo = m if modo != m else ""
	if m in ["mirato", "rapido"] and not arma_scelta.has(a.id):
		var armi := p.armi_da_fuoco(a)
		if not armi.is_empty():
			arma_scelta[a.id] = armi[0].tipo
	_aggiorna_tutto()
	if modo != "":
		var testi := {"mirato": "Clicca un tedesco evidenziato in rosso per il tiro mirato.", "rapido": "Clicca un tedesco evidenziato in rosso per il tiro rapido.",
			"granata": "Clicca l’esagono bersaglio della granata.", "satchel": "Clicca l’esagono bersaglio della carica.",
			"cedi": "Clicca un compagno entro 2 esagoni.", "sveglia": "Clicca un compagno inconsapevole entro 2 esagoni.", "trascina": "Clicca l’esagono adiacente in cui trascinare."}
		aiuto_azioni.text = testi.get(modo, "") + "  (Esc per annullare)"

# =================================================================== mappa: clic e passaggio
func _clic_mappa(h: String, _tasto: int) -> void:
	if riproducendo or p.s.pausa != "" or p.s.fase == "fine":
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
		menu_bersagli.add_item("%s · %s · colpisce 0–%d" % [p.nome(g), T.NOMI_POSTURA[g.postura], int(pr.prob)], i)
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
			if riproducendo:
				_salta = true
			elif finestra.visible:
				_chiudi_finestra()
			elif modo != "":
				modo = ""
				_aggiorna_tutto()
		elif ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			if riproducendo:
				_salta = true
			elif p.s.pausa != "" and not finestra.visible:
				_prosegui()

# =================================================================== esiti e riproduzione
func _esito(r: Dictionary) -> void:
	if riproducendo:
		return
	if not r.get("ok", false):
		aiuto_azioni.text = "⚠ " + str(r.get("errore", "Azione non valida."))
		aiuto_azioni.add_theme_color_override("font_color", Color("f2a58f"))
		get_tree().create_timer(3.5).timeout.connect(func(): aiuto_azioni.add_theme_color_override("font_color", Tema.KAKI_SPENTO))
		return
	if not (modo == "rapido" and not p.s.turno.is_empty() and p.s.turno.get("azione", "") == "rapido"):
		modo = ""
	_salva()
	_riproduci()

func _prosegui() -> void:
	if riproducendo:
		return
	p.prosegui()
	_salva()
	_riproduci()

func _titolo_iniziale() -> String:
	return ("ROUND %d" % int(p.s.round.get("n", 0))) if p.fase_round() and int(p.s.round.get("n", 0)) > 0 else ("ROUND" if p.fase_round() else "OPERAZIONI")

func _aggiorna_titolo(v: Dictionary) -> void:
	match str(v.t):
		"round":
			var x := str(v.x).trim_suffix(".").to_upper()
			if x.begins_with("ROUND") or x.begins_with("INIZIANO"):
				_titolo_lotto = x
		"attivazione":
			_titolo_lotto = "CONTATTO!"
		"tedesco":
			_titolo_lotto = "AZIONI TEDESCHE"
		"condizione":
			if _titolo_lotto == "OPERAZIONI":
				_titolo_lotto = "CAMBIO DI CONDIZIONE"
		"fine":
			_titolo_lotto = "FINE MISSIONE"

func _durata_riga(v: Dictionary) -> float:
	var d := 0.35
	match str(v.t):
		"par":
			d = clampf(0.8 + str(v.x).length() / 260.0, 0.9, 2.4)
		"dado":
			d = 0.5
		"tedesco":
			d = 0.6
		"combattimento":
			d = 0.45
		"danno":
			d = 0.35
		"condizione", "round", "titolo":
			d = 1.0
		"attivazione", "pv":
			d = 0.7
		"azione":
			d = 0.2
	return d / mappa.velocita

func _attendi(t: float) -> void:
	var fine := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < fine and not _salta:
		await get_tree().process_frame

var _ultima_sequenza: Array = []
var _ultima_vista: Dictionary = {}

## Riproduce gli eventi dell’ultimo comando: righe del rapporto una alla volta,
## sincronizzate con gli spostamenti, i tiri e le esplosioni sulla mappa.
func _riproduci(ripetizione := false) -> void:
	var voci: Array = p.recenti.duplicate()
	if not ripetizione:
		_ultima_sequenza = voci
		_ultima_vista = p.vista_iniziale
	var significative := voci.filter(func(v): return v.t != "fx" or v.fx != "postura")
	if significative.is_empty():
		_aggiorna_tutto()
		return
	riproducendo = true
	_salta = false
	_lotto = voci.filter(func(v): return v.t != "fx").size()
	_mostrate = 0
	_titolo_lotto = _titolo_iniziale()
	mappa.pulisci_tracce()
	mappa.evidenzia = {}
	mappa.vista = p.vista_iniziale
	_render_rapporto(true)
	_aggiorna_azioni()
	for v in voci:
		if _salta:
			break
		if v.t == "fx":
			var d: float = mappa.anima(v)
			if d > 0.0:
				await _attendi(d)
		else:
			_aggiorna_titolo(v)
			_mostrate += 1
			_render_rapporto(true)
			if v.t in ["round", "condizione", "pv"] or str(v.x).begins_with("Turni:"):
				_aggiorna_barra()
				pista.queue_redraw()
			await _attendi(_durata_riga(v))
	if _salta:
		for v in voci:
			if v.t != "fx":
				_aggiorna_titolo(v)
	mappa.fine_riproduzione()
	riproducendo = false
	_aggiorna_tutto()
	if p.s.fase == "fine":
		_mostra_fine()

func _rivedi() -> void:
	if riproducendo or _ultima_sequenza.is_empty():
		return
	p.recenti = _ultima_sequenza.duplicate()
	p.vista_iniziale = _ultima_vista
	_riproduci(true)

func _bbcode(voci: Array, grande := false, attenuato := false) -> String:
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
		match v.t:
			"par":
				var pid: String = v.get("id", "")
				var tipo: String = p.paragrafi.get(pid, {}).get("tipo", "")
				var colore := "#7a2a1c" if tipo != "azione" else "#3d4a5c"
				out.append("[color=%s][b]§ %s[/b][/color]  %s" % [colore, pid, x.replace("\n", "\n      ")])
			"dado":
				out.append("[color=#5e5440]    ⚄ %s[/color]" % x)
			"danno":
				out.append("[color=#a52a1f][b]✚ %s[/b][/color]" % x)
			"pv":
				out.append("[color=#3f6b2f][b]★ %s[/b][/color]" % x)
			"condizione":
				out.append("[color=#a52a1f][b]■ %s[/b][/color]" % x)
			"attivazione":
				out.append("[color=#a52a1f][b]▲ %s[/b][/color]" % x)
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
		testo = "[color=#8c8371]" + _bbcode(vecchie, false, true) + "[/color]"
	if _lotto > 0:
		testo += ("\n\n" if testo != "" else "") + "[center][b][color=#7a2a1c]━━━  %s  ━━━[/color][/b][/center]" % _titolo_lotto
		var nuove: Array = cron.slice(inizio_lotto, inizio_lotto + _mostrate)
		for i in nuove.size():
			var riga := _bbcode([nuove[i]])
			if evidenzia and i == nuove.size() - 1:
				riga = "[bgcolor=#f2d98c]" + riga + "[/bgcolor]"
			testo += "\n" + riga
	rapporto.text = testo
	titolo_rapporto.text = ("RAPPORTO · " + _titolo_lotto) if _lotto > 0 else "RAPPORTO DI COMBATTIMENTO"

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

func _paragrafo(vb: VBoxContainer, testo: String, dim := 16) -> void:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.text = testo
	l.add_theme_font_override("normal_font", Tema.macchina)
	l.add_theme_font_override("bold_font", Tema.testo_bold)
	l.add_theme_font_size_override("normal_font_size", dim)
	l.add_theme_font_size_override("bold_font_size", dim)
	l.add_theme_color_override("default_color", Tema.INCHIOSTRO)
	vb.add_child(l)

func _mostra_briefing(c_e_salvataggio: bool, solo_lettura := false) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_intestazione(vb, "ORDINE DI MISSIONE", "MISSIONE 1 · SANGUE A SAINT-MICHAUX · RISERVATO")
	_paragrafo(vb, p.missione.briefing)
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
	_paragrafo(inner, "[b]Comandi.[/b] Rotella: zoom · tasto destro trascinato: sposta la mappa · passaggio del mouse: terreno, linea di vista dal soldato scelto, probabilità di tiro · Esc: annulla la modalità · Spazio/Invio: continua. La partita si salva da sola sul dispositivo.", 15)
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
	p.nuova()
	selezione = ["A"]
	modo = ""
	_log_mostrati = 0
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
