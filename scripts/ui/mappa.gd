extends Control
## Mappa A con pedine, segnalini, evidenziazioni, linea di vista.
## Mouse: rotella per lo zoom, trascinamento (sinistro o destro) per spostare.
## Tocco: un dito trascina, due dita pizzicano per lo zoom e spostano.

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
var mappa: Texture2D
## Lettera della mappa disegnata (per accorgersi del cambio di mappa a metà missione).
var lettera_mappa := ""
var trame := {}
## Grafica a scelta: mappa originale o «realistica», pedine originali o ridisegnate.
var mappa_realistica := false
var pedine_nuove := false
## Mostra chi è in comando e il raggio di comando dei comandanti.
var mostra_comando := true
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
## Stato dei pannelli durante la riproduzione (consapevolezza, turni rimasti…), o vuoto.
var stato_pannelli: Dictionary = {}
## Segni che restano sulla mappa finché non parte il comando successivo: linee di tiro con l’esito.
var segni: Array = []
## Passo della riproduzione in corso: i segni dei passi precedenti si attenuano.
var passo_corrente := 0
## Etichette sugli esagoni (probabilità di tiro sui bersagli): h → testo.
var etichette: Dictionary = {}
## Linee di vista da mostrare: [{da, a, colore}].
var linee: Array = []
# tocco e trascinamento
var _tocchi := {}
var _pizzico_dist := 0.0
var _pizzico_centro := Vector2.ZERO
var _premuto := false
var _premuto_pos := Vector2.ZERO
var _trascinato := false
var _multi := false
## Seconda istanza usata come velo della vista 3D: disegna solo pedine e segni, senza fondo.
var solo_velo := false
## Nel velo della vista 3D le pedine sono miniature: non si disegnano le pedine piatte.
var senza_pedine := false
## Verso dell'ultimo movimento o tiro di ogni unità: id -> [da, a] (per girare le miniature 3D).
var direzioni: Dictionary = {}
## Missione 4: soldati in discesa col paracadute: id -> {"passo": n, "atterra": t0 o -1}
var paracadutisti: Dictionary = {}
## Vista 3D (scripts/ui/mappa3d.gd), creata la prima volta che si passa al 3D.
var vista3d = null
var in_3d := false
const Mappa3DScript = preload("res://scripts/ui/mappa3d.gd")

func imposta_3d(attiva: bool) -> void:
	in_3d = attiva
	if attiva:
		if vista3d == null:
			vista3d = Mappa3DScript.new()
			add_child(vista3d)
			vista3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vista3d.visible = true
		vista3d.prepara(self)
	elif vista3d != null:
		vista3d.visible = false
	queue_redraw()

func _3d() -> bool:
	return in_3d and vista3d != null and vista3d.visible

## Posizione sullo schermo del centro di un esagono, nella vista attiva (2D o 3D).
func posizione_schermo(h: String) -> Vector2:
	if _3d():
		return vista3d.centro_schermo(h)
	return centro_schermo(h)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	imposta_grafica(mappa_realistica, pedine_nuove)
	resized.connect(_adatta)
	mouse_exited.connect(func(): sopra = ""; esagono_sopra.emit(""); queue_redraw())

func _carica_cartella(cartella: String) -> void:
	for f in DirAccess.get_files_at(cartella):
		var n := f
		if f.ends_with(".png.import"):
			n = f.trim_suffix(".import")
		elif not f.ends_with(".png"):
			continue
		trame[n.get_basename()] = load(cartella + "/" + n)

## Sceglie la mappa (originale o realistica) e la serie di pedine (originali o ridisegnate).
## Le due mappe hanno lo stesso reticolo; le pedine nuove sostituiscono quelle con lo stesso nome.
func imposta_grafica(realistica: bool, nuove: bool) -> void:
	mappa_realistica = realistica
	pedine_nuove = nuove
	var lettera := "a"
	if partita != null:
		lettera = partita.lettera_mappa().to_lower()
	lettera_mappa = lettera
	var percorso_mappa := "res://assets/maps/mappa_%s%s.jpg" % [lettera, "_realistica" if realistica else ""]
	if not ResourceLoader.exists(percorso_mappa):
		percorso_mappa = "res://assets/maps/mappa_%s.jpg" % lettera
	mappa = load(percorso_mappa)
	trame.clear()
	# Le pedine originali non hanno tutte le lettere tedesche: quelle mancanti vengono dalla serie ridisegnata.
	if nuove:
		_carica_cartella("res://assets/pedine")
		_carica_cartella("res://assets/pedine_nuove")
	else:
		_carica_cartella("res://assets/pedine_nuove")
		_carica_cartella("res://assets/pedine")
	if vista3d != null and in_3d:
		vista3d.prepara(self)
	queue_redraw()

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

## All’inizio si inquadrano gli esagoni da cui entra la squadra.
func vista_iniziale() -> void:
	if _3d():
		vista3d.vista_iniziale()
		return
	zoom = maxf(scala_minima(), minf(size.x / 2300.0, size.y / 1500.0))
	var ing: Array = partita.esagoni_ingresso() if partita != null else []
	if ing.is_empty():
		spostamento = Vector2(size.x / 2.0 - 1100.0 * zoom, 10.0 - 40.0 * zoom)
	else:
		var c := Vector2.ZERO
		for h in ing:
			c += centro_tex(h)
		c /= float(ing.size())
		spostamento = size / 2.0 - c * zoom
	_limita()
	queue_redraw()

func scala_minima() -> float:
	return minf(size.x / mappa.get_width(), size.y / mappa.get_height())

func centra() -> void:
	if _3d():
		vista3d.centra()
		return
	zoom = scala_minima()
	spostamento = (size - Vector2(mappa.get_size()) * zoom) / 2.0
	queue_redraw()

func zoom_a(fattore: float, punto: Vector2) -> void:
	if _3d():
		vista3d.zoom_a(fattore, punto)
		return
	var vecchio := zoom
	zoom = clampf(zoom * fattore, scala_minima() * 0.95, 1.6)
	spostamento = punto - (punto - spostamento) * (zoom / vecchio)
	_limita()
	queue_redraw()

func centra_su(h: String) -> void:
	if h == "":
		return
	if _3d():
		vista3d.centra_su(h)
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
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			_tocchi[st.index] = st.position
		else:
			_tocchi.erase(st.index)
		if _tocchi.size() >= 2:
			_multi = true
			var k := _tocchi.keys()
			_pizzico_dist = (_tocchi[k[0]] as Vector2).distance_to(_tocchi[k[1]])
			_pizzico_centro = ((_tocchi[k[0]] as Vector2) + (_tocchi[k[1]] as Vector2)) / 2.0
		else:
			_pizzico_dist = 0.0
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		_tocchi[sd.index] = sd.position
		if _tocchi.size() >= 2:
			var k := _tocchi.keys()
			var a: Vector2 = _tocchi[k[0]]
			var b: Vector2 = _tocchi[k[1]]
			var d := a.distance_to(b)
			var centro := (a + b) / 2.0
			if _pizzico_dist > 1.0 and d > 1.0:
				zoom_a(d / _pizzico_dist, centro)
				spostamento += centro - _pizzico_centro
				_limita()
				queue_redraw()
			_pizzico_dist = d
			_pizzico_centro = centro
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_a(1.15, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_a(1.0 / 1.15, mb.position)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_trascina = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_premuto = true
				_premuto_pos = mb.position
				_trascinato = false
				if _tocchi.size() < 2:
					_multi = false
			else:
				if _premuto and not _trascinato and not _multi:
					var h := esagono_a(mb.position)
					if h != "":
						if h != sopra:
							sopra = h
							esagono_sopra.emit(h)
						esagono_cliccato.emit(h, MOUSE_BUTTON_LEFT)
				_premuto = false
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _tocchi.size() < 2:
			if _premuto and not _trascinato and mm.position.distance_to(_premuto_pos) > 10.0:
				_trascinato = true
			if _trascina or (_premuto and _trascinato):
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
	if _3d():
		return
	if not solo_velo:
		draw_rect(Rect2(Vector2.ZERO, size), Color("15170f"))
		draw_texture_rect(mappa, Rect2(spostamento, Vector2(mappa.get_size()) * zoom), false)
	if mappa_realistica and not solo_velo:
		# la mappa realistica ha un reticolo appena accennato: lo si rinforza un poco
		for h in E.tutti():
			draw_polyline(_chiudi(poligono(h)), Color(1, 1, 1, clampf(zoom * 0.3, 0.05, 0.16)), 1.0)
	if partita == null or partita.s.is_empty():
		return
	var s: Dictionary = partita.s
	# Raggio di comando: gli esagoni entro due dal comandante
	if mostra_comando and vista == null:
		for a in partita.americani():
			if a.get("comandante", false) and a.stato == "attivo" and a.hex != "" and not a.get("panico", false):
				for h in E.tutti():
					if E.distanza(a.hex, h) <= 2:
						draw_colored_polygon(poligono(h, 0.98), Color(0.95, 0.8, 0.3, 0.09))
						draw_polyline(_chiudi(poligono(h, 0.98)), Color(0.95, 0.8, 0.3, 0.3), maxf(1.0, 1.5 * zoom))
	# Obiettivi della missione
	if mostra_obiettivi:
		for h in partita.obiettivi_mappa():
			draw_polyline(_chiudi(poligono(h, 0.92)), Color(0.78, 0.6, 0.15, 0.85), maxf(2.0, 5.0 * zoom))
	# Evidenziazioni (destinazioni, bersagli)
	for h in evidenzia:
		var c: Color = evidenzia[h]
		draw_colored_polygon(poligono(h, 0.96), Color(c.r, c.g, c.b, 0.28))
		draw_polyline(_chiudi(poligono(h, 0.96)), Color(c.r, c.g, c.b, 0.9), maxf(1.5, 3.0 * zoom))
	# Segnalini sulla mappa
	var lato := RAGGIO * zoom
	for h in s.modifiche:
		if s.modifiche[h] == "stream":
			_marcatore(h, "PONTE DISTRUTTO", Vector2(0.0, -0.62), Color("7a2e22"))
		elif s.modifiche[h] == "cover":
			# Purple Heart 15: letto del fiume asciutto (copertura).
			draw_colored_polygon(poligono(h, 0.96), Color(0.74, 0.62, 0.44, 0.62))
		elif s.modifiche[h] == "water":
			# Purple Heart 15: esagono allagato dalla piena.
			draw_colored_polygon(poligono(h, 0.96), Color(0.22, 0.48, 0.85, 0.50))
		elif s.modifiche[h] == "clear":
			pass
		else:
			_segnalino(h, "cratere" if s.modifiche[h] == "crater" else "macerie", Vector2(-0.55, -0.55), 0.62)
	# Piano superiore (campanile di S13): segnalino sotto il soldato
	var al_piano := {}
	for x in s.unita.values():
		if int(x.get("piano", 0)) > 0 and partita.piano(x) > 0 and x.get("stato", "") in ["attivo", "incapacitato"]:
			if not al_piano.has(x.hex):
				al_piano[x.hex] = []
			al_piano[x.hex].append(str(x.lettera) if x.lato == "us" else "%s%d" % [x.lettera, int(x.num)])
	for h in al_piano:
		_marcatore(str(h), "PIANO SUP.: " + ", ".join(al_piano[h]), Vector2(0.0, -0.66), Color("5b3a22"))
	# Missione 9: filo spinato
	for hf in s.get("filo", []):
		_marcatore(str(hf), "FILO SPINATO", Vector2(0.0, 0.62), Color("4a4033"))
	# Missione 12: soldati nella galleria
	for x in s.unita.values():
		if x.get("galleria", false) and str(x.get("hex", "")) != "" and x.get("stato", "") == "attivo":
			_marcatore(str(x.hex), "GALLERIA", Vector2(0.0, -0.62), Color("3a3326"))
	# Missione 10: colpi dei mortai
	var marcatori: Array = s.get("art_marcatori", [])
	for k in marcatori.size():
		if str(marcatori[k]) != "":
			draw_arc(centro_schermo(str(marcatori[k])), RAGGIO * zoom * 0.7, 0.0, TAU, 32, Color(0.85, 0.25, 0.15, 0.9), maxf(2.0, 4.0 * zoom))
			_marcatore(str(marcatori[k]), "MORTAIO %d" % (k + 1), Vector2(0.0, 0.55 - 0.3 * k), Color("8f2a1e"))
	# Missione 8: blocchi stradali
	for h in s.get("blocchi", []):
		_marcatore(str(h), "BLOCCO STRADALE", Vector2(0.0, -0.62), Color("5b4a33"))
	# Missione 7: mine anticarro
	for h in s.get("mine_at", []):
		_marcatore(str(h), "MINA ANTICARRO", Vector2(0.0, -0.62), Color("6b3a1f"))
	# Missione 6: bunker
	for h in s.get("bunker", {}):
		var bk: Dictionary = s.bunker[h]
		var testo_b := "BUNKER DISTRUTTO" if bk.distrutto else ("BUNKER · PORTA SFONDATA" if bk.sfondata else "BUNKER")
		_marcatore(h, testo_b, Vector2(0.0, -0.62), Color("3a3a3a") if bk.distrutto else Color("4b4f55"))
		if not bk.distrutto and E.adiacenti(h, str(bk.porta)):
			var pm := (centro_schermo(h) + centro_schermo(str(bk.porta))) / 2.0
			draw_circle(pm, maxf(3.0, RAGGIO * zoom * 0.12), Color("c9a227"))
	# Missione 5: installazioni da distruggere
	for h in s.get("installazioni", {}):
		var ins: Dictionary = s.installazioni[h]
		var nome_i: String = {"antenna": "ANTENNA", "radar": "RADAR", "rampa": "RAMPA V-2", "v2": "RAZZO V-2"}.get(str(ins.nome), str(ins.nome).to_upper())
		_marcatore(h, nome_i + (" DISTRUTTO" if ins.distrutta else ""), Vector2(0.0, 0.62), Color("3a3a3a") if ins.distrutta else Color("7a2e22"))
	# Missione 4: esagoni illuminati dai razzi, cassa delle armi
	for h in partita.terreno.illuminati:
		draw_colored_polygon(poligono(h, 0.96), Color(1.0, 0.93, 0.55, 0.22))
	var cassa: Dictionary = s.get("cassa", {})
	if not cassa.is_empty() and str(cassa.hex) != "" and cassa.stato != "persa":
		_marcatore(str(cassa.hex), "CASSA" + (" APERTA" if cassa.stato == "aperta" else ""), Vector2(0.0, 0.66), Color("4a5d32"))
	# Missione 3: radio, deposito, cariche e carburante sui ponti
	if str(s.get("radio_hex", "")) != "":
		_marcatore(str(s.radio_hex), "RADIO", Vector2(0.0, -0.62), Color("3d4f5f"))
	var dep := str(partita.regola("deposito", ""))
	if dep != "":
		_marcatore(dep, "CARBURANTE", Vector2(0.0, -0.62), Color("5b4a33"))
	for h in s.get("ponti", {}):
		var st: Dictionary = s.ponti[h]
		if st.distrutto:
			continue
		var parti: Array = []
		if int(st.cariche) > 0:
			parti.append("CARICHE %d" % int(st.cariche))
		if st.carburante:
			parti.append("CARBURANTE")
		if int(st.controlli) > 0:
			parti.append("CONTROLLO %d/4" % mini(4, int(st.controlli)))
		if st.get("catturato", false):
			parti.append("CATTURATO")
		elif int(st.get("disinnesco", 0)) > 0:
			parti.append("CARICHE STACCATE %d/4" % int(st.disinnesco))
		if not parti.is_empty():
			_marcatore(h, " · ".join(parti), Vector2(0.0, -0.62), Color("6b3a1f"))
	for h in s.mine:
		_segnalino(h, "campo_minato", Vector2(0.5, -0.5), 0.55)
	for h in s.eventi:
		_segnalino(h, "evento", Vector2(-0.5, 0.5), 0.5)
	for h in s.punti:
		var nome_p := str(s.punti[h])
		if trame.has(nome_p):
			_segnalino(h, nome_p, Vector2(0.0, -0.45), 0.7)
		else:
			_marcatore(h, {"carro": "PANZER", "bunker": "BUNKER", "trappola": "TRAPPOLA", "guado": "GUADO",
				"deposito": "CARBURANTE", "kubelwagen": "KÜBELWAGEN", "avviso_mine": "MINEN!", "rifiuti": "RIFIUTI", "radar": "RADAR", "sherman": "SHERMAN DISTRUTTO"}.get(nome_p, nome_p.to_upper()), Vector2(0.0, -0.62), Color("5b4a33"))
	# Veicoli
	for veic in ({} if senza_pedine else s.get("veicoli", {})).values():
		if str(veic.hex) != "" and not veic.get("fuori_mappa_ph", false):
			var col := Color("4a5d32") if veic.lato == "us" else Color("5d5f63")
			if veic.stato != "attivo":
				col = Color("3a3a3a")
			var extra := "" if veic.stato == "attivo" else " (FUORI USO)"
			if int(veic.get("carichi", 0)) > 0:
				extra += " · %d %s" % [int(veic.carichi), "CARICO" if int(veic.carichi) == 1 else "CARICHI"]
			if veic.stato == "attivo" and int(veic.get("forature", 0)) > 0 and not veic.gomme:
				extra = " (GOMMA A TERRA)"
			_marcatore(str(veic.hex), str(veic.nome).to_upper() + extra, Vector2(0.0, 0.66), col)
	if partita != null and partita.ss.attiva() and not senza_pedine:
		for e in s.get("ss", {}).get("esplosivi", []):
			_marcatore(str(e.hex), "TIC TAC", Vector2(0.0, -0.62), Color("8a2b1c"))
	for h in s.oggetti:
		var armi_a_terra: Array = s.oggetti[h].filter(func(o): return not (str(o.get("tipo", "")) in ["barca", "esplosivo", "incendio", "carica_us", "faro", "antenna", "cannone_costiero"]))
		if not armi_a_terra.is_empty():
			_segnalino(h, "mitra" if armi_a_terra[0].tipo == "smg" else "arma", Vector2(0.5, 0.5), 0.45)
		for o in s.oggetti[h]:
			match str(o.get("tipo", "")):
				"barca":
					_marcatore(h, "BATTELLO", Vector2(0.0, 0.66), Color("4a5560"))
				"esplosivo":
					_marcatore(h, "ESPLOSIVO %d" % int(s.get("ph", {}).get("esplosivi", {}).get(h, 2)), Vector2(0.0, -0.62), Color("8a2b1c"))
				"incendio":
					_marcatore(h, "IN FIAMME", Vector2(0.0, 0.3), Color("a04a12"))
				"carica_us":
					_marcatore(h, "ESPLOSIVO", Vector2(0.0, -0.62), Color("4a5d32"))
				"faro":
					_marcatore(h, "FARO", Vector2(0.0, -0.62), Color("6b5a22"))
				"antenna":
					_marcatore(h, "ANTENNA", Vector2(0.0, -0.62), Color("5b4a33"))
				"cannone_costiero":
					_marcatore(h, "CANNONE COSTIERO", Vector2(0.0, -0.62), Color("5d5f63"))
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
		if d.get("fuori_mappa_ph", false):
			continue  # Missione 18: carri in attesa fuori mappa
		if not per_hex.has(d.hex):
			per_hex[d.hex] = []
		per_hex[d.hex].append(d)
	var di_turno: Array = [] if vista != null else partita.americani_di_turno().map(func(a): return a.id)
	if senza_pedine:
		per_hex = {}
	for h in per_hex:
		var pila: Array = per_hex[h]
		pila.sort_custom(func(a, b): return _ordine(a) < _ordine(b))
		var posti := _posti(pila.size(), lato)
		for i in pila.size():
			var x: Dictionary = pila[i]
			var r: Rect2 = posti[i]
			r.position += centro_schermo(h)
			_pedina(x, r, vista == null and x.id in selezionati, x.id in di_turno)
	# Pedine in movimento (sopra le altre)
	for id in ({} if senza_pedine else mobili):
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
	# Linee di vista (chi vede chi) e segni dei tiri già risolti
	for l in linee:
		_linea_vista(l)
	for i in segni.size():
		_disegna_segno(segni[i], i)
	# Effetti animati
	for a in animazioni:
		_disegna_effetto(a)
	# Etichette sui bersagli
	for h in etichette:
		_etichetta_hex(h, str(etichette[h]))
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
			if stato_pannelli.has("unita") and stato_pannelli.unita.has(id):
				d = (stato_pannelli.unita[id] as Dictionary).duplicate()
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

## Segnaposto disegnato: targhetta con il nome (veicoli, carro distrutto, bunker…).
func _marcatore(h: String, testo: String, off: Vector2, colore: Color) -> void:
	var c := centro_schermo(h) + off * RAGGIO * zoom
	var fs := int(clampf(RAGGIO * zoom * 0.2, 9.0, 22.0))
	var f: Font = Tema.testo_bold
	var w := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs
	var r := Rect2(c - Vector2(w / 2.0, fs * 0.75), Vector2(w, fs * 1.5))
	draw_rect(r, colore)
	draw_rect(r, Color("e9dfbf"), false, maxf(1.0, fs * 0.08))
	draw_string(f, r.position + Vector2(fs * 0.5, fs * 1.08), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f4ecd3"))

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
	else:
		# Pedina senza immagine: riquadro con lettera e numero.
		draw_rect(r, (Color("4d5a3c") if x.lato == "us" else Color("6b6f73")) * mod)
		draw_rect(r, Color("1d2116"), false, maxf(1.0, r.size.x * 0.04))
		var fs := int(maxf(8.0, r.size.x * 0.42))
		draw_string(Tema.stencil, r.position + Vector2(0, r.size.y * 0.55), str(x.lettera), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color("f2ead2"))
		if x.has("num"):
			draw_string(Tema.testo, r.position + Vector2(0, r.size.y * 0.9), str(int(x.num) % 100), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(fs * 0.55), Color("f2ead2"))
	var mini := r.size.x * 0.48
	if x.postura == "prone" and x.stato == "attivo":
		var tp: Texture2D = trame.get("prono_" + str(x.lato), trame["prono"])
		if trame.has("prono_" + str(x.lato)):
			draw_texture_rect(tp, Rect2(r.position + Vector2(0, r.size.y - mini), Vector2(mini, mini)), false)
		else:
			draw_texture_rect(tp, Rect2(r.position + Vector2(0, r.size.y - mini * 0.62), Vector2(mini * 1.2, mini * 0.62)), false)
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
	_icone_stato(x, r)
	if partita != null and partita.ss.attiva() and x.stato == "attivo" and (partita.ss.in_acqua(x) or x.get("barca_ss", false)):
		# Silver Star: nuotatori, sommozzatori sott’acqua e barche di guardia.
		var fs2 := int(maxf(8.0, r.size.x * 0.17))
		var sotto: bool = partita.ss.sott_acqua(x)
		var etich: String = "BARCA %d" % int(x.get("equip_ss", 0)) if x.get("barca_ss", false) else ("SOTT’ACQUA" if sotto else "IN ACQUA")
		if sotto:
			draw_rect(r, Color(0.1, 0.3, 0.55, 0.45))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - fs2 * 1.3), Vector2(r.size.x, fs2 * 1.3)), Color(0.08, 0.25, 0.45, 0.9))
		draw_string(Tema.testo_bold, r.position + Vector2(0, r.size.y - fs2 * 0.3), etich, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs2, Color.WHITE)
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
			if ev.get("paracadute", false):
				dur = 0.7
			for id in ev.ids:
				mobili[id] = {"da": ev.da if ev.da != "" else ev.a, "a": ev.a, "t0": _t, "dur": dur / velocita, "off": i * 6.0}
				if ev.da != "" and ev.da != ev.a:
					direzioni[id] = [ev.da, ev.a]
				if ev.get("paracadute", false):
					paracadutisti[id] = {"passo": int(ev.get("passo", 0)), "atterra": -1.0}
				i += 1
			if ev.da != "":
				var lato := "us"
				var x: Dictionary = partita.u(str(ev.ids[0]))
				if not x.is_empty():
					lato = x.lato
				tracce.append({"da": ev.da, "a": ev.a, "lato": lato, "passo": passo_corrente})
			assicura_visibili([ev.da, ev.a] if ev.da != "" else [ev.a])
		"tiro":
			dur = 0.8 if ev.esito == "inceppata" else (1.25 if ev.get("auto", false) else 0.95)
			if str(ev.get("da", "")) != "" and str(ev.get("a", "")) != "" and ev.da != ev.a:
				direzioni[str(ev.tiratore)] = [ev.da, ev.a]
			assicura_visibili([ev.da, ev.a] if ev.da != "" else [ev.a])
			var nemico: bool = partita.u(str(ev.tiratore)).get("lato", "de") != "us"
			segni.append({"da": ev.da, "a": ev.a, "nemico": nemico, "esito": ev.esito, "bersaglio": ev.get("bersaglio", ""),
				"testo": {"colpito": "COLPITO", "mancato": "MANCATO", "inceppata": "ARMA INCEPPATA"}.get(ev.esito, ""),
				"passo": passo_corrente, "da_t": _t + dur * 0.6 / velocita})
		"lancio":
			dur = 1.5
			assicura_visibili([ev.da, ev.a])
			if ev.has("id") and ev.da != ev.a:
				direzioni[str(ev.id)] = [ev.da, ev.a]
		"atterra":
			dur = 1.1
			if paracadutisti.has(str(ev.id)):
				paracadutisti[str(ev.id)].atterra = _t
				paracadutisti[str(ev.id)].dur = dur / velocita
			assicura_visibili([ev.a])
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
			for j in range(segni.size() - 1, -1, -1):
				var sg: Dictionary = segni[j]
				if sg.passo == passo_corrente and sg.bersaglio == ev.id and sg.esito == "colpito":
					sg.testo = "COLPITO: " + {"panico": "PANICO", "spavento": "SOLO SPAVENTO", "ferito": "FERITO", "incapacitato": "INCAPACITATO", "ucciso": "UCCISO"}.get(ev.tipo, str(ev.tipo).to_upper())
					break
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
	stato_pannelli = {}
	attore_id = ""
	mobili.clear()
	queue_redraw()

func pulisci_tracce() -> void:
	tracce.clear()
	segni.clear()
	passo_corrente = 0
	animazioni.clear()
	queue_redraw()

## Sposta la vista in modo che gli esagoni indicati siano visibili.
func assicura_visibili(esagoni: Array) -> void:
	if _3d():
		vista3d.assicura_visibili(esagoni)
		return
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
	if o.distance_to(b) < maxf(4.0, accorcia + w * 4.0):
		return  # tiro dentro lo stesso esagono: nessuna freccia, bastano l’anello e la scritta
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
	var vecchia: bool = int(tr.get("passo", 0)) != passo_corrente
	if vecchia:
		col.a = 0.4
	var w := maxf(3.5, 4.5 * zoom)
	draw_line(a, b, Color(0, 0, 0, 0.2 if vecchia else 0.5), w + 3.0)
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

# ================================================================== pedine affiancate, icone, segni
## Posti delle pedine di un esagono, affiancate invece che impilate: rettangoli relativi al centro.
func _posti(n: int, lato: float) -> Array:
	var out: Array = []
	if n <= 1:
		var d := lato * 1.05
		out.append(Rect2(-d / 2.0, -d / 2.0, d, d))
		return out
	var colonne := 2 if n <= 4 else 3
	var righe := int(ceil(n / float(colonne)))
	var d := lato * (0.84 if n == 2 else (0.74 if n <= 4 else (0.6 if righe <= 2 else 0.52)))
	var gap := lato * 0.04
	for i in n:
		var rg := i / colonne
		var in_riga := mini(colonne, n - rg * colonne)
		var cl := i % colonne
		var x := (cl - (in_riga - 1) / 2.0) * (d + gap) - d / 2.0
		var y := (rg - (righe - 1) / 2.0) * (d + gap) - d / 2.0
		out.append(Rect2(x, y, d, d))
	return out

func _in_round() -> bool:
	if stato_pannelli.has("fase"):
		return stato_pannelli.fase == "round"
	return partita != null and partita.fase_round()

## Segni sulla pedina: inconsapevole (pedina scurita con un punto di domanda), turni rimasti (pallini).
func _icone_stato(x: Dictionary, r: Rect2) -> void:
	if x.get("stato", "") != "attivo":
		return
	if not _in_round():
		_segno_comando(x, r)
		return
	var u := r.size.x
	if x.lato == "us" and not x.get("consapevole", true) and not x.get("panico", false):
		draw_rect(r, Color(0.08, 0.09, 0.07, 0.38))
		var c := r.position + Vector2(u * 0.74, u * 0.27)
		var rr := u * 0.2
		draw_circle(c, rr + 1.5, Color(0.93, 0.9, 0.8))
		draw_circle(c, rr, Color(0.13, 0.14, 0.11))
		var fs := int(maxf(9.0, rr * 1.7))
		draw_string(Tema.testo_bold, c + Vector2(-rr, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_CENTER, rr * 2.0, fs, Color(0.96, 0.93, 0.82))
	_segno_comando(x, r)
	if x.get("slot", "") == "turni" and int(x.get("turni", 0)) > 0:
		var n := int(x.turni)
		var rp := maxf(3.0, u * 0.085)
		for i in n:
			var c := r.position + Vector2(u - rp * 1.4 - i * rp * 2.4, u - rp * 1.4)
			draw_circle(c, rp + 1.5, Color(0.08, 0.09, 0.07))
			draw_circle(c, rp, Color(0.55, 0.95, 0.45) if x.lato == "us" else Color(0.6, 0.85, 1.0))

func _linea_vista(l: Dictionary) -> void:
	var a := _p(str(l.da))
	var b := _p(str(l.a))
	var col: Color = l.get("colore", Color(1, 1, 1, 0.6))
	draw_dashed_line(a, b, Color(0, 0, 0, col.a * 0.5), maxf(3.0, 4.5 * zoom), maxf(5.0, 10.0 * zoom))
	draw_dashed_line(a, b, col, maxf(1.5, 2.5 * zoom), maxf(5.0, 10.0 * zoom))
	draw_circle(b, maxf(3.5, 7.0 * zoom), col)

## Linea di tiro che resta sulla mappa con l’esito scritto sul bersaglio.
func _disegna_segno(sg: Dictionary, indice: int) -> void:
	var b := _p(str(sg.a))
	var o := _p(str(sg.da)) if str(sg.da) != "" else _origine_cecchino(b)
	var attuale: bool = int(sg.passo) == passo_corrente
	var alfa := 0.95 if attuale else 0.38
	var col := Color(1.0, 0.45, 0.25, alfa) if sg.nemico else Color(1.0, 0.92, 0.4, alfa)
	var r := _re()
	_freccia(o, b, col, maxf(3.0, 3.5 * zoom), r * 0.6)
	draw_arc(o, r * 0.66, 0, TAU, 32, col, maxf(2.5, 3.0 * zoom), true)
	if str(sg.da) == "":
		_scritta(o, "CECCHINO NASCOSTO", col, 13)
	if _t < float(sg.get("da_t", 0.0)) or str(sg.testo) == "":
		return
	# più tiri sullo stesso esagono: scritte una sopra l’altra
	var livello := 0
	for j in indice:
		if str(segni[j].a) == str(sg.a) and int(segni[j].passo) == int(sg.passo):
			livello += 1
	var colore_testo := Color(1.0, 0.5, 0.42, alfa) if sg.esito == "colpito" else Color(0.92, 0.89, 0.78, alfa)
	if attuale or livello == 0:
		_scritta(b - Vector2(0, r * 0.95 + livello * 24.0), str(sg.testo), colore_testo, 15)

func _scritta(pos: Vector2, testo: String, colore: Color, dim: int) -> void:
	var f: Font = Tema.testo_bold
	var w := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, dim).x
	var rr := Rect2(Vector2(pos.x - w / 2.0 - 6, pos.y - dim - 4), Vector2(w + 12, dim + 9))
	draw_rect(rr, Color(0.1, 0.1, 0.07, 0.85 * colore.a))
	draw_rect(rr, colore, false, 1.5)
	draw_string(f, Vector2(pos.x - w / 2.0, pos.y), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, dim, colore)

func _etichetta_hex(h: String, testo: String) -> void:
	_scritta(_p(h) + Vector2(0, _re() * 1.05 + 16.0), testo, Color(1.0, 0.93, 0.7), 15)

## In comando (cerchio verde con spunta) o fuori comando (cerchio rosso con croce):
## chi è fuori comando va nel panico con i numeri rossi dell’iniziativa.
func _segno_comando(x: Dictionary, r: Rect2) -> void:
	if not mostra_comando or vista != null or partita == null or x.lato != "us" or x.get("panico", false):
		return
	var vivo := partita.u(str(x.id))
	if vivo.is_empty() or vivo.stato != "attivo" or vivo.hex == "":
		return
	var dentro: bool = partita.in_comando(vivo)
	var u := r.size.x
	var c := r.position + Vector2(u * 0.86, u * 0.56)
	var rr := maxf(4.5, u * 0.115)
	var w := maxf(1.5, rr * 0.3)
	draw_circle(c, rr + 1.5, Color(0.08, 0.09, 0.07))
	draw_circle(c, rr, Color(0.25, 0.6, 0.25) if dentro else Color(0.78, 0.16, 0.1))
	if dentro:
		draw_polyline(PackedVector2Array([c + Vector2(-rr * 0.5, 0), c + Vector2(-rr * 0.12, rr * 0.4), c + Vector2(rr * 0.55, -rr * 0.4)]), Color.WHITE, w, true)
	else:
		draw_line(c + Vector2(-rr * 0.42, -rr * 0.42), c + Vector2(rr * 0.42, rr * 0.42), Color.WHITE, w, true)
		draw_line(c + Vector2(-rr * 0.42, rr * 0.42), c + Vector2(rr * 0.42, -rr * 0.42), Color.WHITE, w, true)
