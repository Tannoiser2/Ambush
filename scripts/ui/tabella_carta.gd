extends Control
## Tabella delle azioni di una carta tedesca: righe per numero d’azione, colonne per Condizione,
## reazione speciale o autoconservazione. Evidenzia la casella che ha deciso l’azione.

var dati: Dictionary = {}
var colonna := ""
var numero := -1

func _ready() -> void:
	custom_minimum_size = Vector2(240, 92)

func mostra(d: Dictionary, col: String, num: int) -> void:
	dati = d
	colonna = col
	numero = num
	queue_redraw()

static func nome_colonna(k: String) -> String:
	if k == "S":
		return "S"
	if k.length() == 1 and k >= "A" and k <= "Z":
		return "R-" + k
	return "C " + k

func _draw() -> void:
	if dati.is_empty():
		return
	var f: Font = Tema.testo_bold
	var colonne: Array = dati.colonne.keys()
	var gruppi: Array = dati.gruppi
	var w0 := 52.0
	var w := minf(96.0, (size.x - w0) / maxf(1.0, colonne.size()))
	var h := size.y / (gruppi.size() + 1)
	var riga_att := -1
	for i in gruppi.size():
		if numero >= int(gruppi[i][0]) and numero <= int(gruppi[i][1]):
			riga_att = i
	draw_string(f, Vector2(0, h * 0.72), "DADO", HORIZONTAL_ALIGNMENT_CENTER, w0, 12, Tema.KAKI_SPENTO)
	for c in colonne.size():
		var k: String = str(colonne[c])
		var x := w0 + c * w
		var att := k == colonna
		if att:
			draw_rect(Rect2(x, 0, w - 2, size.y), Color(0.79, 0.64, 0.29, 0.2))
		draw_string(f, Vector2(x, h * 0.72), nome_colonna(k), HORIZONTAL_ALIGNMENT_CENTER, w - 2, 12, Tema.OTTONE if att else Tema.KAKI_SPENTO)
	for i in gruppi.size():
		var y := h * (i + 1)
		var a := int(gruppi[i][0])
		var b := int(gruppi[i][1])
		if i == riga_att:
			draw_rect(Rect2(0, y, w0 + colonne.size() * w - 2, h - 1), Color(0.79, 0.64, 0.29, 0.2))
		draw_string(f, Vector2(0, y + h * 0.74), str(a) if a == b else "%d-%d" % [a, b], HORIZONTAL_ALIGNMENT_CENTER, w0, 14, Tema.KAKI if i == riga_att else Tema.KAKI_SPENTO)
		for c in colonne.size():
			var k: String = str(colonne[c])
			var x := w0 + c * w
			var qui := i == riga_att and k == colonna
			if qui:
				draw_rect(Rect2(x, y, w - 2, h - 1), Tema.OTTONE)
				draw_rect(Rect2(x, y, w - 2, h - 1), Color("fff3c4"), false, 2.0)
			draw_string(f, Vector2(x, y + h * 0.74), str(int(dati.colonne[k][i])), HORIZONTAL_ALIGNMENT_CENTER, w - 2, 14, Color("1c1f16") if qui else Tema.KAKI_SPENTO)
		draw_line(Vector2(0, y), Vector2(w0 + colonne.size() * w - 2, y), Color(1, 1, 1, 0.08), 1.0)
