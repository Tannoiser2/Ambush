extends Control
## Mappa A con pedine, segnalini, evidenziazioni, linea di vista. Zoom con la rotella, trascina con il tasto destro.

signal esagono_cliccato(h: String, tasto: int)
signal esagono_sopra(h: String)

const E = preload("res://scripts/motore/esagoni.gd")
const SCALA := 0.6
const ORIG := Vector2(307.0, 272.0)
const PASSO := Vector2(270.8, 314.0)
const RAGGIO := 180.5 * SCALA

var partita: Partita
var mappa: Texture2D = preload("res://assets/maps/mappa_a.jpg")
var trame := {}
var zoom := 0.0
var spostamento := Vector2.ZERO
var _trascina := false
var sopra := ""
var selezionati: Array = []
## Esagoni evidenziati: h → Color
var evidenzia: Dictionary = {}
var origine_vista := ""
var postura_vista := "standing"
var mostra_vista := true
var mostra_obiettivi := true
var _t := 0.0
var _vista_cache := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	for f in DirAccess.get_files_at("res://assets/pedine"):
		if f.ends_with(".png"):
			trame[f.get_basename()] = load("res://assets/pedine/" + f)
		elif f.ends_with(".png.import"):
			var n := f.trim_suffix(".import")
			if not trame.has(n.get_basename()):
				trame[n.get_basename()] = load("res://assets/pedine/" + n)
	resized.connect(_adatta)
	mouse_exited.connect(func(): sopra = ""; esagono_sopra.emit(""); queue_redraw())

func _process(delta: float) -> void:
	_t += delta
	if partita != null and partita.fase_round() and not partita.americani_di_turno().is_empty():
		queue_redraw()

func _adatta() -> void:
	if size.x < 10:
		return
	if zoom <= 0.0:
		vista_iniziale()
	_limita()
	queue_redraw()

## All’inizio si inquadra il margine nord, da cui entra la squadra.
func vista_iniziale() -> void:
	zoom = maxf(scala_minima(), minf(size.x / 2300.0, size.y / 1500.0))
	spostamento = Vector2(size.x / 2.0 - 1100.0 * zoom, 10.0 - 40.0 * zoom)
	_limita()
	queue_redraw()

func scala_minima() -> float:
	return minf(size.x / mappa.get_width(), size.y / mappa.get_height())

func centra() -> void:
	zoom = scala_minima()
	spostamento = (size - Vector2(mappa.get_size()) * zoom) / 2.0
	queue_redraw()

func zoom_a(fattore: float, punto: Vector2) -> void:
	var vecchio := zoom
	zoom = clampf(zoom * fattore, scala_minima() * 0.95, 1.6)
	spostamento = punto - (punto - spostamento) * (zoom / vecchio)
	_limita()
	queue_redraw()

func centra_su(h: String) -> void:
	if h == "":
		return
	var p := centro_tex(h)
	spostamento = size / 2.0 - p * zoom
	_limita()
	queue_redraw()

func _limita() -> void:
	var dim := Vector2(mappa.get_size()) * zoom
	var margine := 120.0
	if dim.x <= size.x:
		spostamento.x = (size.x - dim.x) / 2.0
	else:
		spostamento.x = clampf(spostamento.x, size.x - dim.x - margine, margine)
	if dim.y <= size.y:
		spostamento.y = (size.y - dim.y) / 2.0
	else:
		spostamento.y = clampf(spostamento.y, size.y - dim.y - margine, margine)

static func centro_tex(h: String) -> Vector2:
	var q := E.colonna(h)
	var r := E.riga(h) - 1
	return (ORIG + Vector2(q * PASSO.x, r * PASSO.y + float(q & 1) * PASSO.y * 0.5)) * SCALA

func a_schermo(p: Vector2) -> Vector2:
	return spostamento + p * zoom

func centro_schermo(h: String) -> Vector2:
	return a_schermo(centro_tex(h))

func esagono_a(pos: Vector2) -> String:
	var tex := (pos - spostamento) / zoom
	var astr := Vector2((tex.x / SCALA - ORIG.x) / PASSO.x * 1.5, (tex.y / SCALA - ORIG.y) / PASSO.y * E.SQRT3)
	return E.a_punto(astr)

func poligono(h: String, riduzione := 1.0) -> PackedVector2Array:
	var c := centro_schermo(h)
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i)
		pts.append(c + Vector2(cos(a) * RAGGIO * zoom, sin(a) * RAGGIO * zoom * 1.0) * riduzione)
	return pts

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_a(1.15, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_a(1.0 / 1.15, mb.position)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_trascina = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var h := esagono_a(mb.position)
			if h != "":
				esagono_cliccato.emit(h, MOUSE_BUTTON_LEFT)
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _trascina:
			spostamento += mm.relative
			_limita()
			queue_redraw()
		var h := esagono_a(mm.position)
		if h != sopra:
			sopra = h
			esagono_sopra.emit(h)
			queue_redraw()
	elif ev is InputEventMagnifyGesture:
		zoom_a((ev as InputEventMagnifyGesture).factor, (ev as InputEventMagnifyGesture).position)
	elif ev is InputEventPanGesture:
		spostamento -= (ev as InputEventPanGesture).delta * 12.0
		_limita()
		queue_redraw()

# ------------------------------------------------------------------ disegno
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("15170f"))
	draw_texture_rect(mappa, Rect2(spostamento, Vector2(mappa.get_size()) * zoom), false)
	if partita == null or partita.s.is_empty():
		return
	var s: Dictionary = partita.s
	# Obiettivi della missione
	if mostra_obiettivi:
		for h in ["T8", "K13", "L13"] + partita.alture_obiettivo():
			draw_polyline(_chiudi(poligono(h, 0.92)), Color(0.78, 0.6, 0.15, 0.85), maxf(2.0, 5.0 * zoom))
	# Evidenziazioni (destinazioni, bersagli)
	for h in evidenzia:
		var c: Color = evidenzia[h]
		draw_colored_polygon(poligono(h, 0.96), Color(c.r, c.g, c.b, 0.28))
		draw_polyline(_chiudi(poligono(h, 0.96)), Color(c.r, c.g, c.b, 0.9), maxf(1.5, 3.0 * zoom))
	# Segnalini sulla mappa
	var lato := RAGGIO * zoom
	for h in s.modifiche:
		_segnalino(h, "cratere" if s.modifiche[h] == "crater" else "macerie", Vector2(-0.55, -0.55), 0.62)
	for h in s.mine:
		_segnalino(h, "campo_minato", Vector2(0.5, -0.5), 0.55)
	for h in s.eventi:
		_segnalino(h, "evento", Vector2(-0.5, 0.5), 0.5)
	for h in s.punti:
		_segnalino(h, "typhoon", Vector2(0.0, -0.45), 0.7)
	for h in s.oggetti:
		if not s.oggetti[h].is_empty():
			_segnalino(h, "mitra" if s.oggetti[h][0].tipo == "smg" else "arma", Vector2(0.5, 0.5), 0.45)
	# Pedine
	var per_hex := {}
	for id in s.unita:
		var x: Dictionary = s.unita[id]
		if x.hex == "" or x.stato in ["fuori", "uscito", "rimosso"]:
			continue
		if not per_hex.has(x.hex):
			per_hex[x.hex] = []
		per_hex[x.hex].append(x)
	var di_turno: Array = partita.americani_di_turno().map(func(a): return a.id)
	for h in per_hex:
		var pila: Array = per_hex[h]
		pila.sort_custom(func(a, b): return _ordine(a) < _ordine(b))
		var n := pila.size()
		var dim := lato * (1.05 if n <= 2 else 0.92)
		var passo := minf(lato * 0.22, lato * 0.9 / maxf(1.0, n - 1)) if n > 1 else 0.0
		var base := centro_schermo(h) - Vector2(dim, dim) / 2.0 - Vector2(passo, -passo) * (n - 1) / 2.0
		for i in n:
			var x: Dictionary = pila[i]
			var p := base + Vector2(passo, -passo) * i
			_pedina(x, Rect2(p, Vector2(dim, dim)), x.id in selezionati, x.id in di_turno)
	# Esagono sotto il cursore e linea di vista
	if sopra != "":
		draw_polyline(_chiudi(poligono(sopra, 0.98)), Color(1, 0.95, 0.75, 0.9), maxf(1.5, 2.5 * zoom))
		if mostra_vista and origine_vista != "" and origine_vista != sopra:
			var v := _vista(origine_vista, sopra)
			var col := Color("7fd36a") if v.ok else Color("e0503c")
			var a := centro_schermo(origine_vista)
			var b := centro_schermo(sopra)
			draw_line(a, b, Color(0, 0, 0, 0.6), maxf(3.0, 6.0 * zoom))
			draw_dashed_line(a, b, col, maxf(2.0, 4.0 * zoom), maxf(6.0, 14.0 * zoom))
			draw_circle(b, maxf(4.0, 9.0 * zoom), col)

func _vista(a: String, b: String) -> Dictionary:
	return partita.terreno.vista(a, b, postura_vista, "standing")

func _ordine(x: Dictionary) -> int:
	var o := 0 if x.lato == "de" else 10
	if x.stato in ["morto", "incapacitato"]:
		o -= 20
	return o

func _chiudi(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q

func _segnalino(h: String, nome: String, off: Vector2, scala: float) -> void:
	var tex: Texture2D = trame.get(nome)
	if tex == null:
		return
	var d := RAGGIO * zoom * scala
	var c := centro_schermo(h) + off * RAGGIO * zoom
	draw_texture_rect(tex, Rect2(c - Vector2(d, d) / 2.0, Vector2(d, d)), false)

func _pedina(x: Dictionary, r: Rect2, selezionato: bool, di_turno: bool) -> void:
	var chiave := ("us_" if x.lato == "us" else "ge_") + str(x.lettera)
	if x.postura == "crouching":
		chiave += "_acc"
	var tex: Texture2D = trame.get(chiave, trame.get(chiave.trim_suffix("_acc")))
	var mod := Color.WHITE
	if x.stato == "morto":
		mod = Color(0.45, 0.45, 0.45)
	elif x.stato in ["incapacitato", "catturato", "arreso"]:
		mod = Color(0.75, 0.72, 0.68)
	# ombra
	draw_rect(Rect2(r.position + Vector2(3, 4) * clampf(zoom * 2.5, 0.5, 2.0), r.size), Color(0, 0, 0, 0.45))
	if tex != null:
		draw_texture_rect(tex, r, false, mod)
	var mini := r.size.x * 0.48
	if x.postura == "prone" and x.stato == "attivo":
		draw_texture_rect(trame["prono"], Rect2(r.position + Vector2(0, r.size.y - mini * 0.62), Vector2(mini * 1.2, mini * 0.62)), false)
	if x.ferito and x.stato == "attivo":
		draw_texture_rect(trame["ferito"], Rect2(r.position + Vector2(r.size.x - mini * 0.8, -mini * 0.15), Vector2(mini * 0.8, mini * 0.8)), false)
	if x.stato == "incapacitato":
		draw_texture_rect(trame["incapacitato"], Rect2(r.position + r.size * 0.2, r.size * 0.6), false)
	elif x.stato == "morto":
		draw_texture_rect(trame["ucciso"], Rect2(r.position + r.size * 0.22, r.size * 0.56), false)
	elif x.stato in ["catturato", "arreso"]:
		draw_texture_rect(trame["prigioniero"], Rect2(r.position + r.size * 0.2, r.size * 0.6), false)
	if x.get("panico", false):
		var f: Font = Tema.testo_bold
		var fs := int(maxf(9.0, r.size.x * 0.2))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.38), Vector2(r.size.x, fs * 1.25)), Color(0.65, 0.12, 0.08, 0.9))
		draw_string(f, r.position + Vector2(0, r.size.y * 0.38 + fs), "PANICO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color.WHITE)
	if selezionato:
		draw_rect(r.grow(2.0), Tema.OTTONE, false, maxf(2.0, 4.0 * zoom))
	elif di_turno:
		var a := 0.55 + 0.45 * sin(_t * 5.0)
		draw_rect(r.grow(2.0), Color(0.55, 0.95, 0.45, a), false, maxf(2.0, 3.5 * zoom))
