extends Control
## Barra delle fasi: mostra sempre in che punto della sequenza di gioco ci si trova.
## Operazioni, oppure Round n: Consapevolezza, Evento, Iniziativa, le quattro caselle dei turni, Fine Round.

var stato: Dictionary = {}
## Fase in corso: "", contatto, consapevolezza, evento, iniziativa, 2us, 2de, 1us, 1de, fine.
var chiave := ""
var _t := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 44)

func _process(delta: float) -> void:
	_t += delta
	if chiave != "":
		queue_redraw()

func mostra(nuovo_stato: Dictionary, nuova_chiave: String) -> void:
	stato = nuovo_stato
	chiave = nuova_chiave
	queue_redraw()

func _ha_unita(lato: String, turni: int) -> bool:
	for x in stato.get("unita", {}).values():
		if x.lato == lato and x.get("slot", "") == "turni" and int(x.get("turni", 0)) >= turni and x.stato in ["attivo", "fuori"]:
			if x.lato == "de" and x.hex == "":
				continue
			return true
	return false

func _spunta(c: Vector2, d: float, colore: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-d, 0), c + Vector2(-d * 0.3, d * 0.7), c + Vector2(d, -d * 0.7)]), colore, 2.5, true)

func _draw() -> void:
	var f: Font = Tema.testo_bold
	var fm: Font = Tema.testo
	draw_rect(Rect2(Vector2.ZERO, size), Color("1f2318"))
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Color("4d5538"), 2.0)
	if stato.is_empty():
		return
	var h := size.y - 10.0
	var y := 5.0
	var in_round: bool = stato.get("fase", "") == "round"
	var r: Dictionary = stato.get("round", {})
	var w_tit := 190.0
	if not in_round:
		var fine: bool = stato.get("fase", "") == "fine"
		draw_string(Tema.stencil, Vector2(14, y + h * 0.74), "MISSIONE CONCLUSA" if fine else "OPERAZIONI", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Tema.OTTONE if fine else Tema.KAKI)
		if not fine:
			var rr := Rect2(w_tit + 40, y, size.x - w_tit - 50, h)
			draw_rect(rr, Color("2f3424"))
			draw_rect(rr, Color("6d7650"), false, 1.0)
			draw_string(fm, rr.position + Vector2(12, h * 0.68), "Muovi la squadra un esagono alla volta: ogni esagono raggiunto fa leggere la carta della Condizione. Appena compare un tedesco iniziano i Round.", HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 20, 15, Tema.KAKI_SPENTO)
		return
	var n := int(r.get("n", 0))
	draw_string(Tema.stencil, Vector2(14, y + h * 0.74), ("ROUND %d" % n) if n > 0 else "CONTATTO!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f08d74"))
	var vant: String = r.get("vantaggio", "") if r.get("iniziativa_fatta", false) else ""
	var primo := vant
	var altro := ("de" if vant == "us" else "us") if vant != "" else ""
	var nomi := {"us": "AMERICANI", "de": "TEDESCHI", "": ""}
	# [chiave, titolo, sottotitolo, lato, saltata]
	var voci: Array = [
		["consapevolezza", "CONSAPEVOLEZZA", "chi si accorge del nemico" if n <= 2 else "tutti consapevoli", "", n > 2],
		["evento", "EVENTO", "due dadi" if n != 1 else "non nel Round 1", "", n == 1],
		["iniziativa", "INIZIATIVA", "vantaggio e turni", "", false],
	]
	for t in [2, 1]:
		for lato in [primo, altro]:
			var titolo := "%d TURN%s" % [t, "I" if t == 2 else "O"]
			var k := "%d%s" % [t, lato]
			var sotto: String = nomi[lato] if lato != "" else ("chi ha il vantaggio" if voci.size() % 2 == 1 else "l’altro lato")
			var vuota: bool = vant != "" and not _ha_unita(lato, t) and chiave != k
			voci.append([k if lato != "" else "?", titolo, sotto, lato, vuota])
	voci.append(["fine", "FINE ROUND", "panico a terra", "", false])
	var corrente := -1
	for i in voci.size():
		if voci[i][0] == chiave:
			corrente = i
	var x0 := w_tit
	var gap := 14.0
	var w := (size.x - x0 - 10.0 - gap * (voci.size() - 1)) / voci.size()
	for i in voci.size():
		var v: Array = voci[i]
		var rr := Rect2(x0 + i * (w + gap), y, w, h)
		var lato: String = v[3]
		var base := Color("2f3424")
		var bordo := Color("596146")
		var testo := Tema.KAKI_SPENTO
		if lato == "us":
			bordo = Tema.USA.darkened(0.35)
		elif lato == "de":
			bordo = Tema.GERMANIA.darkened(0.35)
		var fatto := corrente >= 0 and i < corrente
		if i == corrente:
			base = Tema.USA if lato == "us" else (Tema.GERMANIA if lato == "de" else Tema.OTTONE)
			bordo = Color("fff3c4")
			testo = Color("1c1f16")
		elif fatto and (v[3] != "" or not v[4]):
			base = Color("262a1d")
			testo = Color("7d8162")
		elif v[4]:
			base = Color("23271b")
			testo = Color("5f6349")
		draw_rect(rr, base)
		draw_rect(rr, bordo, false, 3.0 if i == corrente else 1.0)
		if i == corrente:
			var a := 0.35 + 0.35 * sin(_t * 4.0)
			draw_rect(rr.grow(3.0), Color(1.0, 0.95, 0.7, a), false, 2.0)
		draw_string(f, rr.position + Vector2(8, 15), v[1], HORIZONTAL_ALIGNMENT_LEFT, w - 12, 14, testo)
		draw_string(fm, rr.position + Vector2(8, 30), v[2], HORIZONTAL_ALIGNMENT_LEFT, w - 12, 12, testo)
		var saltata: bool = v[4] and not (fatto and v[3] != "")
		if fatto and not saltata:
			_spunta(rr.position + Vector2(w - 13, 11), 5.0, Color("9bc27a"))
		if saltata and i != corrente:
			draw_line(rr.position + Vector2(6, h * 0.5), rr.position + Vector2(w - 6, h * 0.5), Color("5f6349"), 1.0)
		if i < voci.size() - 1:
			var cx := rr.end.x + gap / 2.0
			var cy := y + h / 2.0
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 4, cy - 6), Vector2(cx + 4, cy), Vector2(cx - 4, cy + 6)]), Color("6d7650"))
