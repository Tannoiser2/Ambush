class_name Tema
extends RefCounted
## Stile grafico: verde oliva da campo, carta manila dei rapporti, stampigliature e macchina da scrivere.

const OLIVA_SCURO := Color("1c1f16")
const OLIVA := Color("2f3424")
const OLIVA_CHIARO := Color("434a33")
const BORDO := Color("5c6545")
const KAKI := Color("d8cfa6")
const KAKI_SPENTO := Color("a39b78")
const OTTONE := Color("c9a24a")
const CARTA := Color("e9dfc3")
const CARTA_SCURA := Color("d6c9a3")
const INCHIOSTRO := Color("2a241a")
const INCHIOSTRO_TENUE := Color("5e5440")
const ROSSO := Color("a52a1f")
const VERDE_OK := Color("4f7a3a")
const USA := Color("c9be3e")
const GERMANIA := Color("a9bccb")

static var stencil: Font
static var macchina: Font
static var testo: Font
static var testo_bold: Font
static var _tema: Theme

static func carica() -> void:
	if stencil != null:
		return
	var simboli: FontFile = load("res://assets/fonts/DejaVuSans-Simboli.ttf")
	stencil = load("res://assets/fonts/StardosStencil-Bold.ttf")
	stencil.fallbacks = [simboli]
	macchina = load("res://assets/fonts/SpecialElite-Regular.ttf")
	macchina.fallbacks = [simboli]
	var osw: FontFile = load("res://assets/fonts/Oswald.ttf")
	osw.fallbacks = [simboli]
	var v := FontVariation.new()
	v.base_font = osw
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 400}
	testo = v
	var b := FontVariation.new()
	b.base_font = osw
	b.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	testo_bold = b

static func scatola(colore: Color, bordo := Color.TRANSPARENT, spessore := 0, raggio := 3, margine := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colore
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = margine
	s.content_margin_right = margine
	s.content_margin_top = margine * 0.6
	s.content_margin_bottom = margine * 0.6
	return s

static func tema() -> Theme:
	carica()
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = testo
	t.default_font_size = 16
	t.set_color("font_color", "Label", KAKI)
	# Pulsanti: targhette metalliche oliva con bordo ottone.
	var n := scatola(Color("3b4230"), Color("6d7650"), 1, 3, 10)
	var h := scatola(Color("4b5539"), OTTONE, 1, 3, 10)
	var p := scatola(Color("2a2f20"), OTTONE, 1, 3, 10)
	var d := scatola(Color("2a2e22"), Color("3f4532"), 1, 3, 10)
	var f := scatola(Color("4b5539"), OTTONE, 2, 3, 10)
	for k in [["normal", n], ["hover", h], ["pressed", p], ["disabled", d], ["focus", f]]:
		t.set_stylebox(k[0], "Button", k[1])
	t.set_color("font_color", "Button", KAKI)
	t.set_color("font_hover_color", "Button", Color("f3ead0"))
	t.set_color("font_pressed_color", "Button", OTTONE)
	t.set_color("font_disabled_color", "Button", Color("6e6a55"))
	t.set_font("font", "Button", testo_bold)
	t.set_font_size("font_size", "Button", 15)
	t.set_stylebox("panel", "PanelContainer", scatola(OLIVA, BORDO, 1, 4, 10))
	t.set_stylebox("panel", "TooltipPanel", scatola(CARTA, INCHIOSTRO, 1, 2, 8))
	t.set_color("font_color", "TooltipLabel", INCHIOSTRO)
	t.set_font("font", "TooltipLabel", macchina)
	t.set_font_size("font_size", "TooltipLabel", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.15)
	sb.set_corner_radius_all(3)
	t.set_stylebox("scroll", "VScrollBar", sb)
	var gr := StyleBoxFlat.new()
	gr.bg_color = Color(0.35, 0.3, 0.2, 0.6)
	gr.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", gr)
	t.set_stylebox("grabber_highlight", "VScrollBar", gr)
	t.set_stylebox("grabber_pressed", "VScrollBar", gr)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("separation", "VBoxContainer", 6)
	# Menu a comparsa
	t.set_stylebox("panel", "PopupMenu", scatola(CARTA, INCHIOSTRO, 1, 2, 6))
	t.set_stylebox("hover", "PopupMenu", scatola(Color("cbb98a"), Color.TRANSPARENT, 0, 2, 6))
	t.set_color("font_color", "PopupMenu", INCHIOSTRO)
	t.set_color("font_hover_color", "PopupMenu", INCHIOSTRO)
	t.set_font("font", "PopupMenu", macchina)
	t.set_font_size("font_size", "PopupMenu", 15)
	_tema = t
	return t

static func etichetta(testo_: String, font: Font = null, dim := 16, colore := KAKI) -> Label:
	carica()
	var l := Label.new()
	l.text = testo_
	l.add_theme_font_override("font", font if font != null else testo)
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", colore)
	return l

static func titolo(testo_: String, dim := 22, colore := KAKI) -> Label:
	carica()
	return etichetta(testo_, stencil, dim, colore)

static func bottone(testo_: String, cb: Callable = Callable(), tip := "") -> Button:
	var b := Button.new()
	b.text = testo_
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Pannello di carta (rapporti, scheda della squadra).
static func carta(margine := 12) -> StyleBoxFlat:
	var s := scatola(CARTA, Color("9b8c66"), 1, 2, margine)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(2, 3)
	return s

static func pannello_oliva(margine := 10) -> StyleBoxFlat:
	return scatola(OLIVA, BORDO, 1, 4, margine)
