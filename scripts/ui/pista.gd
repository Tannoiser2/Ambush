extends Control
## Pista dei Round (Action Round Track): righe per turni rimasti, colonne vantaggio/svantaggio.
## Disegna lo stato che le viene passato, così resta allineata alla riproduzione.

## Stato da mostrare: {unita, round, fase}.
var stato: Dictionary = {}
## Casella che sta agendo, per esempio "2de" o "1us" ("" se nessuna).
var chiave := ""

const RIGHE := [["2", "2 TURNI"], ["1", "1 TURNO"], ["panico", "PANICO"], ["completo", "FINITO"], ["inconsapevole", "INCONSAPEVOLI"]]

func _ready() -> void:
	custom_minimum_size = Vector2(0, 214)

func mostra(nuovo_stato: Dictionary, nuova_chiave: String) -> void:
	stato = nuovo_stato
	chiave = nuova_chiave
	queue_redraw()

func _riga_di(x: Dictionary) -> String:
	if x.get("slot", "") == "turni":
		return str(int(x.turni)) if int(x.turni) > 0 else "completo"
	return str(x.get("slot", ""))

func _dado(pos: Vector2, valore: int, colore: Color) -> void:
	var r := Rect2(pos, Vector2(24, 24))
	draw_rect(r, colore)
	draw_rect(r, Color("1c1f16"), false, 1.5)
	draw_string(Tema.testo_bold, pos + Vector2(0, 19), str(valore), HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color("1c1f16"))

func _draw() -> void:
	var f: Font = Tema.testo_bold
	var fm: Font = Tema.testo
	draw_rect(Rect2(Vector2.ZERO, size), Color("262a1d"))
	if stato.is_empty():
		return
	var r: Dictionary = stato.get("round", {})
	if stato.get("fase", "") != "round" or r.is_empty():
		draw_string(Tema.stencil, Vector2(12, 40), "OPERAZIONI", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Tema.KAKI)
		var righe := ["Nessun nemico attivo: la pista è vuota.", "Quando un tedesco si attiva iniziano i Round", "e qui compare chi agisce, in che ordine", "e quanti turni ha."]
		for i in righe.size():
			draw_string(fm, Vector2(12, 68 + i * 21), righe[i], HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 15, Tema.KAKI_SPENTO)
		return
	var vant: String = r.get("vantaggio", "")
	var fatta: bool = r.get("iniziativa_fatta", false)
	var col_l := 104.0
	var w := (size.x - col_l - 6) / 2.0
	# dadi dell’iniziativa
	if fatta:
		draw_string(f, Vector2(8, 20), "INIZIATIVA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Tema.OTTONE)
		_dado(Vector2(col_l, 3), int(r.get("dado_us", 0)), Tema.USA)
		draw_string(fm, Vector2(col_l + 30, 20), "americani", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tema.KAKI)
		_dado(Vector2(col_l + w, 3), int(r.get("dado_de", 0)), Tema.GERMANIA)
		draw_string(fm, Vector2(col_l + w + 30, 20), "tedeschi", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tema.KAKI)
	else:
		draw_string(f, Vector2(8, 20), "IN ATTESA DELL’INIZIATIVA: i turni non sono ancora assegnati", HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 13, Tema.OTTONE)
	var y0 := 52.0
	var nomi := {"us": "AMERICANI", "de": "TEDESCHI", "": "—"}
	var primo: String = vant if vant != "" else "de"
	var altro := "de" if primo == "us" else "us"
	draw_string(f, Vector2(col_l, y0 - 6), ("PRIMA: " if fatta else "") + nomi[primo], HORIZONTAL_ALIGNMENT_LEFT, w, 13, Tema.KAKI)
	draw_string(f, Vector2(col_l + w, y0 - 6), ("POI: " if fatta else "") + nomi[altro], HORIZONTAL_ALIGNMENT_LEFT, w, 13, Tema.KAKI_SPENTO)
	var h := (size.y - y0 - 4) / RIGHE.size()
	for i in RIGHE.size():
		var y := y0 + i * h
		var riga: String = RIGHE[i][0]
		var fondo := Color("30351f") if i % 2 == 0 else Color("2b301e")
		if riga == "panico":
			fondo = Color("47261f")
		draw_rect(Rect2(0, y, size.x, h - 2), fondo)
		draw_string(f, Vector2(8, y + h * 0.66), RIGHE[i][1], HORIZONTAL_ALIGNMENT_LEFT, col_l - 10, 12, Tema.KAKI_SPENTO)
		for lato_i in 2:
			var lato: String = primo if lato_i == 0 else altro
			var x0 := col_l + lato_i * w
			if riga in ["1", "2"] and chiave == riga + lato:
				draw_rect(Rect2(x0, y, w - 2, h - 2), Color(0.95, 0.8, 0.3, 0.22))
				draw_rect(Rect2(x0, y, w - 2, h - 2), Color(0.98, 0.83, 0.35, 0.95), false, 2.0)
			var gettoni: Array = []
			for x in stato.unita.values():
				if x.lato != lato or x.stato in ["uscito", "rimosso", "morto", "incapacitato", "catturato", "arreso"]:
					continue
				if x.lato == "us" and x.stato != "attivo" and x.stato != "fuori":
					continue
				if x.lato == "de" and x.hex == "":
					continue
				if not fatta:
					continue  # prima dell’iniziativa la pista è vuota
				if _riga_di(x) == riga:
					gettoni.append(x)
			gettoni.sort_custom(func(a, b): return str(a.lettera) < str(b.lettera))
			var d := minf(h - 6, 26.0)
			for j in gettoni.size():
				var x: Dictionary = gettoni[j]
				var px := x0 + 4 + j * (d + 3)
				if px + d > x0 + w:
					break
				var col: Color = Tema.USA if x.lato == "us" else Tema.GERMANIA
				draw_rect(Rect2(px, y + (h - d) / 2 - 1, d, d), col)
				draw_rect(Rect2(px, y + (h - d) / 2 - 1, d, d), Color("1c1f16"), false, 1.0)
				draw_string(f, Vector2(px, y + (h - d) / 2 + d * 0.78), str(x.lettera), HORIZONTAL_ALIGNMENT_CENTER, d, int(d * 0.72), Color("1c1f16"))
