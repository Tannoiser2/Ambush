extends Control
## Mappa A con pedine, segnalini, evidenziazioni, linea di vista. Zoom con la rotella, trascina con il tasto destro.

signal esagono_cliccato(h: String, tasto: int)
signal esagono_sopra(h: String)

const E = preload("res://scripts/motore/esagoni.gd")
const SCALA := 0.6
const ORIG := Vector2(307.0, 272.0)
const PASSO := Vector2(270.8, 314.0)
const RAGGIO := 180.5 * SCALA
## Zoom minimo con cui si mostrano le azioni durante la riproduzione.
const ZOOM_AZIONE := 0.5

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
## Riproduzione: stato visibile sostitutivo (id → {hex, postura, stato, ferito, panico}), o null.
var vista = null
var animazioni: Array = []
var mobili: Dictionary = {}
var tracce: Array = []
var velocita := 1.0
## Unità che sta agendo durante la riproduzione (anello persistente).
var attore_id := ""
var _tween_pan: Tween

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
	if not animazioni.is_empty() or not mobili.is_empty() or attore_id != "":
		animazioni = animazioni.filter(func(a): return _t < a.t0 + a.dur)
		for k in mobili.keys():
			if _t >= mobili[k].t0 + mobili[k].dur:
				mobili.erase(k)
		queue_redraw()
	elif partita != null and partita.fase_round() and not partita.americani_di_turno().is_empty():
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
	var margine := 24.0
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
	# Tracce dei movimenti dell’ultima sequenza
	for tr in tracce:
		_disegna_traccia(tr)
	var per_hex := {}
	var stati := _stati_visibili()
	for id in stati:
		if mobili.has(id):
			continue
		var d: Dictionary = stati[id]
		if not per_hex.has(d.hex):
			per_hex[d.hex] = []
		per_hex[d.hex].append(d)
	var di_turno: Array = [] if vista != null else partita.americani_di_turno().map(func(a): return a.id)
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
			_pedina(x, Rect2(p, Vector2(dim, dim)), vista == null and x.id in selezionati, x.id in di_turno)
	# Pedine in movimento (sopra le altre)
	for id in mobili:
		var m: Dictionary = mobili[id]
		if not stati.has(id):
			continue
		var k := clampf((_t - m.t0) / m.dur, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		var c := centro_schermo(m.da).lerp(centro_schermo(m.a), k)
		var dim := lato * 1.05
		var r := Rect2(c - Vector2(dim, dim) / 2.0 + Vector2(m.off, -m.off), Vector2(dim, dim))
		draw_circle(r.get_center(), dim * 0.75, Color(1, 1, 1, 0.18))
		_pedina(stati[id], r, false, false)
	# Chi sta agendo
	if attore_id != "" and stati.has(attore_id):
		var hx: String = stati[attore_id].hex
		var cc := centro_schermo(hx)
		if mobili.has(attore_id):
			var m: Dictionary = mobili[attore_id]
			var km := clampf((_t - m.t0) / m.dur, 0.0, 1.0)
			cc = centro_schermo(m.da).lerp(centro_schermo(m.a), km * km * (3.0 - 2.0 * km))
		var pul := 0.75 + 0.25 * sin(_t * 6.0)
		draw_arc(cc, RAGGIO * zoom * 0.95, 0, TAU, 40, Color(1.0, 0.82, 0.3, pul), maxf(3.0, 5.0 * zoom), true)
	# Effetti animati
	for a in animazioni:
		_disegna_effetto(a)
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

## Pedine da disegnare: lo stato reale o quello della riproduzione in corso.
func _stati_visibili() -> Dictionary:
	var out := {}
	for id in partita.s.unita:
		var x: Dictionary = partita.s.unita[id]
		var d: Dictionary
		if vista != null:
			if not vista.has(id):
				continue
			d = x.duplicate()
			d.merge(vista[id], true)
		else:
			if x.hex == "" or x.stato in ["fuori", "uscito", "rimosso"]:
				continue
			d = x
		out[id] = d
	return out

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

# ================================================================== riproduzione animata
## Avvia l’animazione di un evento del motore. Restituisce la durata in secondi.
func anima(ev: Dictionary) -> float:
	if ev.has("vista"):
		vista = ev.vista
	var tipo: String = ev.fx
	var dur := 0.0
	match tipo:
		"muovi":
			dur = (0.65 if ev.get("strisciando", false) else 0.42)
			var i := 0
			for id in ev.ids:
				mobili[id] = {"da": ev.da if ev.da != "" else ev.a, "a": ev.a, "t0": _t, "dur": dur / velocita, "off": i * 6.0}
				i += 1
			if ev.da != "":
				var lato := "us"
				var x: Dictionary = partita.u(str(ev.ids[0]))
				if not x.is_empty():
					lato = x.lato
				tracce.append({"da": ev.da, "a": ev.a, "lato": lato})
			assicura_visibili([ev.da, ev.a] if ev.da != "" else [ev.a])
		"tiro":
			dur = 0.8 if ev.esito == "inceppata" else (1.25 if ev.get("auto", false) else 0.95)
			assicura_visibili([ev.da, ev.a] if ev.da != "" else [ev.a])
		"lancio":
			dur = 1.5
			assicura_visibili([ev.da, ev.a])
		"esplosione":
			dur = 1.2 if ev.get("grande", false) else 0.9
			assicura_visibili([ev.a])
		"assalto":
			dur = 1.0
			assicura_visibili([ev.a])
		"danno":
			dur = 1.1
			var x: Dictionary = (vista if vista != null else {}).get(ev.id, {})
			ev.a = x.get("hex", partita.u(ev.id).get("hex", ""))
			if ev.a != "":
				assicura_visibili([ev.a])
		"compare":
			dur = 1.3
			assicura_visibili([ev.a, _americano_vicino(ev.a)])
		"sparisce":
			dur = 0.9
		"attore":
			dur = 0.7
			attore_id = str(ev.id)
			assicura_visibili([ev.a, _americano_vicino(ev.a)])
		"postura":
			dur = 0.3
	if dur > 0.0:
		var a := ev.duplicate()
		a.t0 = _t
		a.dur = dur / velocita
		animazioni.append(a)
	queue_redraw()
	return dur / velocita

## Esagono dell’americano più vicino (per inquadrare insieme chi agisce e i suoi possibili bersagli).
func _americano_vicino(h: String) -> String:
	var migliore := ""
	var dmin := 999
	var stati := _stati_visibili()
	for id in stati:
		var d: Dictionary = stati[id]
		if d.lato != "us" or d.stato != "attivo":
			continue
		var dd := E.distanza(h, d.hex)
		if dd < dmin:
			dmin = dd
			migliore = d.hex
	return migliore if dmin <= 12 else ""

func fine_riproduzione() -> void:
	vista = null
	attore_id = ""
	mobili.clear()
	queue_redraw()

func pulisci_tracce() -> void:
	tracce.clear()
	animazioni.clear()
	queue_redraw()

## Sposta la vista in modo che gli esagoni indicati siano visibili.
func assicura_visibili(esagoni: Array) -> void:
	var punti: Array = []
	for h in esagoni:
		if h != "" and E.valido(str(h)):
			punti.append(centro_tex(str(h)))
	if punti.is_empty():
		return
	var margine := Rect2(Vector2(70, 70), size - Vector2(140, 170))
	var tutti_dentro := true
	for pt in punti:
		if not margine.has_point(a_schermo(pt)):
			tutti_dentro = false
	if tutti_dentro and zoom >= ZOOM_AZIONE * 0.9:
		return
	var minimo: Vector2 = punti[0]
	var massimo: Vector2 = punti[0]
	for pt in punti:
		minimo = minimo.min(pt)
		massimo = massimo.max(pt)
	var nuovo_zoom := zoom
	var adatto := minf(size.x * 0.7 / maxf(1.0, massimo.x - minimo.x), size.y * 0.6 / maxf(1.0, massimo.y - minimo.y))
	if nuovo_zoom < ZOOM_AZIONE:
		nuovo_zoom = maxf(nuovo_zoom, minf(ZOOM_AZIONE, adatto))
	var est := (massimo - minimo) * nuovo_zoom
	if est.x > size.x * 0.7 or est.y > size.y * 0.6:
		nuovo_zoom = maxf(scala_minima(), minf(size.x * 0.7 / maxf(1.0, massimo.x - minimo.x), size.y * 0.6 / maxf(1.0, massimo.y - minimo.y)))
	var centro: Vector2 = (minimo + massimo) / 2.0
	var dest := size / 2.0 - centro * nuovo_zoom
	if _tween_pan != null and _tween_pan.is_valid():
		_tween_pan.kill()
	_tween_pan = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_pan.tween_property(self, "zoom", nuovo_zoom, 0.3 / velocita)
	_tween_pan.tween_method(func(v: Vector2): spostamento = v; _limita(); queue_redraw(), spostamento, dest, 0.3 / velocita)

func _p(h: String) -> Vector2:
	return centro_schermo(h)

## Dimensione di riferimento degli effetti: mai troppo piccoli anche a mappa intera.
func _re() -> float:
	return RAGGIO * maxf(zoom, 0.42)

func _freccia(o: Vector2, b: Vector2, col: Color, w: float, accorcia := 0.0) -> void:
	var dir := (b - o).normalized()
	var fine := b - dir * accorcia
	draw_line(o, fine, Color(0, 0, 0, col.a * 0.6), w + 3.0)
	draw_line(o, fine, col, w)
	var lato := Vector2(-dir.y, dir.x)
	var dim := w * 3.2
	draw_colored_polygon(PackedVector2Array([fine + dir * dim * 0.4, fine - dir * dim + lato * dim * 0.6, fine - dir * dim - lato * dim * 0.6]), col)

func _progresso(a: Dictionary) -> float:
	return clampf((_t - a.t0) / a.dur, 0.0, 1.0)

func _testo_flottante(pos: Vector2, testo: String, colore: Color, k: float, dim := 22.0) -> void:
	var f: Font = Tema.stencil
	var fs := int(clampf(dim * zoom * 3.0, 15.0, 30.0))
	var alfa := 1.0 if k < 0.7 else (1.0 - (k - 0.7) / 0.3)
	var y := pos.y - _re() * 0.7 - k * 26.0
	var w := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(Vector2(pos.x - w / 2.0 - 7, y - fs - 2), Vector2(w + 14, fs + 10))
	draw_rect(r, Color(0.12, 0.11, 0.08, 0.82 * alfa))
	draw_rect(r, Color(colore.r, colore.g, colore.b, alfa), false, 2.0)
	draw_string(f, Vector2(pos.x - w / 2.0, y + 2), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(colore.r, colore.g, colore.b, alfa))

func _anello(c: Vector2, raggio: float, colore: Color, spessore: float) -> void:
	draw_arc(c, raggio, 0, TAU, 40, colore, spessore, true)

func _esplosione(c: Vector2, k: float, grande: bool) -> void:
	var r := _re() * (1.4 if grande else 0.9)
	if k < 0.25:
		var kk := k / 0.25
		draw_circle(c, r * (0.3 + 0.7 * kk), Color(1.0, 0.85, 0.35, 0.9))
		draw_circle(c, r * (0.15 + 0.45 * kk), Color(1, 1, 0.85, 1))
	var ks := clampf((k - 0.1) / 0.9, 0.0, 1.0)
	for i in 7:
		var ang := float(i) / 7.0 * TAU + 0.4
		var d := r * (0.25 + 0.75 * ks)
		draw_circle(c + Vector2(cos(ang), sin(ang)) * d * 0.7, r * (0.25 + 0.2 * ks), Color(0.35, 0.32, 0.28, 0.55 * (1.0 - ks)))
	_anello(c, r * (0.4 + 0.9 * k), Color(1, 0.6, 0.2, 0.8 * (1.0 - k)), maxf(3.5, 5.0 * zoom))

func _disegna_traccia(tr: Dictionary) -> void:
	var a := _p(tr.da)
	var b := _p(tr.a)
	var col := Color(0.75, 0.85, 1.0, 0.9) if tr.lato == "de" else Color(0.95, 0.9, 0.45, 0.85)
	var w := maxf(3.5, 4.5 * zoom)
	draw_line(a, b, Color(0, 0, 0, 0.5), w + 3.0)
	draw_dashed_line(a, b, col, w, maxf(5.0, 12.0 * zoom))
	var dir := (b - a).normalized()
	var punta := b - dir * _re() * 0.45
	var lato := Vector2(-dir.y, dir.x)
	var dim := maxf(12.0, 16.0 * zoom)
	draw_colored_polygon(PackedVector2Array([punta + dir * dim * 0.6, punta - dir * dim * 0.6 + lato * dim * 0.6, punta - dir * dim * 0.6 - lato * dim * 0.6]), col)

func _origine_cecchino(b: Vector2) -> Vector2:
	return b + Vector2(-1, -1).normalized() * _re() * 6.0

func _disegna_effetto(a: Dictionary) -> void:
	var k := _progresso(a)
	match str(a.fx):
		"tiro":
			_effetto_tiro(a, k)
		"lancio":
			_effetto_lancio(a, k)
		"esplosione":
			_esplosione(_p(a.a), k, a.get("grande", false))
		"assalto":
			var c := _p(a.a)
			var scuoti := Vector2(sin(_t * 60.0), cos(_t * 47.0)) * 4.0 * (1.0 - k)
			var r := _re()
			for i in 2:
				var s := -1.0 if i == 0 else 1.0
				draw_line(c + scuoti + Vector2(-r * 0.5 * s, -r * 0.5), c + scuoti + Vector2(r * 0.5 * s, r * 0.5), Color(0.9, 0.85, 0.75), maxf(4.0, 7.0 * zoom))
			_anello(c, r * (0.6 + 0.3 * sin(k * PI)), Color(0.9, 0.2, 0.1, 0.9), maxf(3.0, 4.0 * zoom))
			if k > 0.45:
				var ok: bool = a.esito == "riuscito"
				_testo_flottante(c, "ASSALTO A SEGNO" if ok else "ASSALTO RESPINTO", Color("ff8c6a") if ok else Color("e8dfc2"), (k - 0.45) / 0.55)
			else:
				_testo_flottante(c, "ASSALTO!", Color("ffcf6a"), k / 0.45)
		"danno":
			if a.a == "":
				return
			var testi := {"panico": ["PANICO", Color("ffb347")], "spavento": ["SPAVENTATO", Color("e8dfc2")], "ferito": ["FERITO", Color("ff6b5b")],
				"incapacitato": ["INCAPACITATO", Color("ff4d3d")], "ucciso": ["UCCISO", Color("ffffff")], "catturato": ["CATTURATO", Color("9fd0ff")], "arreso": ["SI ARRENDE", Color("ffffff")]}
			var t: Array = testi.get(a.tipo, [str(a.tipo).to_upper(), Color.WHITE])
			var c := _p(a.a)
			if a.tipo in ["ferito", "incapacitato", "ucciso"]:
				draw_circle(c, _re() * (0.5 + 0.4 * k), Color(0.8, 0.05, 0.02, 0.35 * (1.0 - k)))
			_testo_flottante(c, t[0], t[1], k)
		"compare":
			var c := _p(a.a)
			var amico: bool = a.get("amico", false)
			var col := Color(0.55, 0.95, 0.45) if amico else Color(1.0, 0.25, 0.15)
			for i in 3:
				var kk := fposmod(k * 2.0 - i * 0.33, 1.0)
				_anello(c, _re() * (0.6 + 1.2 * kk), Color(col.r, col.g, col.b, 0.85 * (1.0 - kk)), maxf(3.5, 5.0 * zoom))
			var x: Dictionary = partita.u(a.id)
			var nome := "SOLDATO " + str(x.get("lettera", "")) if amico else "NEMICO! " + str(x.get("lettera", ""))
			_testo_flottante(c, nome, col.lightened(0.3), minf(k * 1.3, 0.69))
		"sparisce":
			var c := _p(a.da) if a.da != "" else Vector2.ZERO
			if a.da == "":
				return
			_anello(c, _re() * (0.5 + 0.6 * k), Color(0.85, 0.85, 0.8, 0.8 * (1.0 - k)), 3.0)
			_testo_flottante(c, "DILEGUATO" if a.motivo == "dileguato" else "ESCE", Color("e8dfc2"), k)
		"attore":
			var c := _p(a.a)
			var r := _re() * (0.95 + 0.12 * sin(k * TAU * 2.0))
			_anello(c, r, Color(1.0, 0.82, 0.3, 0.95), maxf(3.0, 6.0 * zoom))
			var x: Dictionary = partita.u(a.id)
			_testo_flottante(c, "AGISCE " + str(x.get("lettera", "")), Color("ffd27a"), minf(k, 0.69))

func _effetto_tiro(a: Dictionary, k: float) -> void:
	var b := _p(a.a)
	var o := _p(a.da) if a.da != "" else _origine_cecchino(b)
	var dir := (b - o).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var r := _re()
	var mancato: bool = a.esito == "mancato"
	var arrivo := b + (perp * r * 0.75 + dir * r * 0.4 if mancato else Vector2.ZERO)
	var nemico: bool = partita.u(str(a.tiratore)).get("lato", "de") != "us"
	var col := Color(1.0, 0.55, 0.3) if nemico else Color(1.0, 0.95, 0.55)
	# freccia di tiro: chi spara a chi
	var alfa_f := 0.9 if k < 0.75 else 0.9 * (1.0 - (k - 0.75) / 0.25)
	_freccia(o, b, Color(col.r, col.g, col.b, alfa_f), maxf(4.5, 5.0 * zoom), r * 0.55)
	_anello(o, r * 0.62, Color(col.r, col.g, col.b, alfa_f), maxf(3.0, 4.0 * zoom))
	if a.esito == "inceppata":
		draw_circle(o, r * 0.35 * (1.0 + k), Color(0.6, 0.6, 0.6, 0.6 * (1.0 - k)))
		_testo_flottante(o, "INCEPPATA!", Color("ffb347"), k)
		return
	var colpi := 6 if a.get("auto", false) else 1
	var durata_volo := 0.32
	for i in colpi:
		var t0 := 0.06 * i
		var kk := (k * (1.0 + 0.06 * colpi) - t0) / durata_volo
		if kk < 0.0:
			continue
		# lampo alla bocca
		if kk < 0.35:
			draw_circle(o + dir * r * 0.45, r * 0.3 * (1.0 - kk / 0.35) + 4.0, Color(1, 0.9, 0.4, 0.95))
		if kk <= 1.0:
			var dispersione := perp * r * 0.12 * (float(i % 3) - 1.0)
			var testa := o.lerp(arrivo + dispersione, kk)
			var coda := o.lerp(arrivo + dispersione, maxf(0.0, kk - 0.22))
			draw_line(coda, testa, Color(1, 1, 0.85, 0.95), maxf(4.0, 6.0 * zoom))
			draw_circle(testa, maxf(4.0, 5.0 * zoom), Color(1, 1, 0.9))
		elif kk < 1.8:
			var kp := (kk - 1.0) / 0.8
			var p := arrivo + perp * r * 0.12 * (float(i % 3) - 1.0)
			draw_circle(p, r * (0.12 + 0.25 * kp), Color(0.55, 0.48, 0.38, 0.6 * (1.0 - kp)))
	if k > 0.5:
		var etichetta := "COLPITO" if a.esito == "colpito" else "MANCATO"
		_testo_flottante(b, etichetta, Color("ff6b5b") if a.esito == "colpito" else Color("e8dfc2"), (k - 0.5) / 0.5, 18.0)

func _effetto_lancio(a: Dictionary, k: float) -> void:
	var o := _p(a.da)
	var b := _p(a.a)
	var volo := 0.55
	var r := _re()
	if a.bersaglio != a.a:
		draw_dashed_line(o, _p(a.bersaglio), Color(1, 0.8, 0.4, 0.35), 2.0, 8.0)
	if k < volo:
		var kk := k / volo
		var altezza := o.distance_to(b) * 0.35 + r
		var pos := o.lerp(b, kk) - Vector2(0, sin(kk * PI) * altezza)
		var pts := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0 * kk
			pts.append(o.lerp(b, t) - Vector2(0, sin(t * PI) * altezza))
		if pts.size() >= 2:
			draw_polyline(pts, Color(1, 0.95, 0.75, 0.8), maxf(3.0, 3.0 * zoom))
		draw_circle(pos, maxf(9.0, 12.0 * zoom), Color(0.1, 0.12, 0.06))
		draw_circle(pos, maxf(6.0, 8.0 * zoom), Color(0.45, 0.5, 0.3))
		return
	var ke := (k - volo) / (1.0 - volo)
	match str(a.esito):
		"esplode":
			_esplosione(b, ke, a.tipo == "satchel")
			if a.bersaglio != a.a:
				_testo_flottante(b, "DEVIATA", Color("ffcf6a"), ke, 16.0)
		"inesploso":
			draw_circle(b, maxf(4.0, 9.0 * zoom), Color(0.22, 0.26, 0.16))
			_testo_flottante(b, "INESPLOSA", Color("e8dfc2"), ke)
		"rilanciato":
			_testo_flottante(b, "RILANCIATA!", Color("9fd0ff"), ke)
