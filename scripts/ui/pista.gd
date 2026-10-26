extends Control
## Pista dei Round (Action Round Track) in forma compatta: righe per turni, colonne vantaggio/svantaggio.

var partita: Partita
var trame: Dictionary = {}

const RIGHE := [["2", "2 TURNI"], ["1", "1 TURNO"], ["panico", "PANICO"], ["completo", "COMPLETO"], ["inconsapevole", "INCONSAPEVOLI"]]

func _ready() -> void:
	custom_minimum_size = Vector2(0, 196)
	for f in ["us_A", "ge_L"]:
		pass

func _riga_di(x: Dictionary) -> String:
	if x.slot == "turni":
		return str(int(x.turni)) if int(x.turni) > 0 else "completo"
	return x.slot

func _draw() -> void:
	var f: Font = Tema.testo_bold
	var fm: Font = Tema.testo
	draw_rect(Rect2(Vector2.ZERO, size), Color("262a1d"))
	if partita == null or partita.s.is_empty():
		return
	var s: Dictionary = partita.s
	if s.fase != "round" or s.round.is_empty():
		draw_string(Tema.stencil, Vector2(12, 40), "OPERAZIONI", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Tema.KAKI)
		draw_string(fm, Vector2(12, 66), "Nessun nemico attivo: muovi liberamente,", HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 15, Tema.KAKI_SPENTO)
		draw_string(fm, Vector2(12, 86), "un esagono alla volta. Ogni ingresso", HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 15, Tema.KAKI_SPENTO)
		draw_string(fm, Vector2(12, 106), "richiede un controllo di paragrafo.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 15, Tema.KAKI_SPENTO)
		return
	var r: Dictionary = s.round
	var vant: String = r.get("vantaggio", "")
	var col_l := 92.0
	var w := (size.x - col_l - 8) / 2.0
	var y0 := 30.0
	var h := (size.y - y0 - 6) / RIGHE.size()
	# intestazione
	draw_string(f, Vector2(8, 20), "VANTAGGIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Tema.OTTONE)
	var nomi := {"us": "AMERICANO", "de": "TEDESCO", "": "—"}
	var altro := "de" if vant == "us" else "us"
	draw_string(f, Vector2(col_l, 20), nomi[vant], HORIZONTAL_ALIGNMENT_CENTER, w, 13, Tema.KAKI)
	draw_string(f, Vector2(col_l + w, 20), "svantaggio", HORIZONTAL_ALIGNMENT_CENTER, w, 13, Tema.KAKI_SPENTO)
	var casella: Array = partita.casella_attuale()
	for i in RIGHE.size():
		var y := y0 + i * h
		var chiave: String = RIGHE[i][0]
		var fondo := Color("30351f") if i % 2 == 0 else Color("2b301e")
		if chiave == "panico":
			fondo = Color("47261f")
		draw_rect(Rect2(0, y, size.x, h - 2), fondo)
		draw_string(f, Vector2(8, y + h * 0.62), RIGHE[i][1], HORIZONTAL_ALIGNMENT_LEFT, col_l - 10, 12, Tema.KAKI_SPENTO)
		for lato_i in 2:
			var lato: String = vant if lato_i == 0 else altro
			var x0 := col_l + lato_i * w
			if lato_i == 0 and chiave in ["1", "2"]:
				draw_rect(Rect2(x0, y, w, h - 2), Color(0.79, 0.64, 0.29, 0.13))
			if not casella.is_empty() and str(casella[0]) == chiave and casella[1] == lato:
				draw_rect(Rect2(x0, y, w, h - 2), Color(0.55, 0.9, 0.45, 0.25))
				draw_rect(Rect2(x0, y, w, h - 2), Color(0.55, 0.9, 0.45, 0.9), false, 2.0)
			var gettoni: Array = []
			for x in s.unita.values():
				if x.lato != lato or x.stato in ["uscito", "rimosso", "morto", "incapacitato", "catturato", "arreso"]:
					continue
				if x.lato == "us" and x.stato != "attivo" and x.stato != "fuori":
					continue
				if x.lato == "de" and x.hex == "":
					continue
				if _riga_di(x) == chiave:
					gettoni.append(x)
			var d := minf(h - 8, 26.0)
			for j in gettoni.size():
				var x: Dictionary = gettoni[j]
				var px := x0 + 4 + j * (d + 3)
				if px + d > x0 + w:
					break
				var col: Color = Tema.USA if x.lato == "us" else Tema.GERMANIA
				draw_rect(Rect2(px, y + (h - d) / 2 - 1, d, d), col)
				draw_rect(Rect2(px, y + (h - d) / 2 - 1, d, d), Color("1c1f16"), false, 1.0)
				draw_string(f, Vector2(px, y + (h - d) / 2 + d * 0.78), str(x.lettera), HORIZONTAL_ALIGNMENT_CENTER, d, int(d * 0.72), Color("1c1f16"))
