extends SceneTree
## Piani degli edifici: il campanile di S13 sulla mappa B (gioco base e Move Out!).
const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")
var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func _init() -> void:
	var p = PartitaScript.new(5)
	p.nuova(5, true)
	var t = p.terreno
	ok(t.ha_piani("S13") and not t.ha_piani("S14"), "S13 ha un piano superiore")
	ok(not t.vede("Q14", "U12"), "il campanile blocca la vista tra Q14 e U12 (livello 2)")
	var giu := 0
	var su := 0
	for h in E.tutti():
		if t.vede("S13", h, "standing", "standing", 0, 0):
			giu += 1
		if t.vede("S13", h, "standing", "standing", 1, 0):
			su += 1
	ok(su > giu, "dal piano superiore si vede di più (%d esagoni contro %d)" % [su, giu])
	# Un americano sale e scende (Operazioni).
	p.schiera(["A", "B"], p.esagoni_ingresso()[0])
	p.inizia_missione()
	p.s.fase = "operazioni"
	p.s.pausa = ""
	var a: Dictionary = p.u("A")
	var b: Dictionary = p.u("B")
	a.hex = "S13"
	b.hex = "S13"
	a.postura = "standing"
	ok(p.cambia_piano("A").ok and p.piano(a) == 1, "A sale al piano superiore")
	ok(p._verifica_passo(a, "S14") != "", "dal piano superiore non si esce senza scendere")
	ok(not p.vede_unita(b, a) and not p.stesso_posto(a, b), "tra i due piani non ci si vede")
	# Tedesco al piano di sopra con il paragrafo 477.
	p.leggi("477", {"hex": "", "ids": []})
	var g: Dictionary = p.u("g12")
	ok(not g.is_empty() and g.hex == "S13" and p.piano(g) == 1, "477: il tedesco 12 al piano superiore di S13")
	ok(p.vede_unita(a, g) and p.stesso_posto(a, g), "A e il tedesco 12 sono nello stesso posto")
	ok(not p.vede_unita(b, g), "B al pianterreno non vede il tedesco di sopra")
	ok(p.probabilita_lancio(b, "granata", "S13").ok, "B può lanciare una granata al piano di sopra")
	# Granata: esplode solo al piano superiore.
	b.munizioni.granata = 3
	var g_stato_prima: String = g.stato
	var b_ferito: bool = b.ferito
	p.s.fase = "round"
	for i in 6:
		p.risolvi_lancio(b, "granata", "S13")
	ok(b.ferito == b_ferito and b.stato == "attivo", "la granata lanciata di sopra non ferisce chi lancia al pianterreno")
	p.s.fase = "operazioni"
	# 265: dal piano superiore il tedesco scende; dal pianterreno sale se c’è un americano di sopra.
	g.stato = "attivo"
	g.piano = 1
	p.ia._g = g
	p.ia._fermo = false
	p.leggi("265", {"g": g.id, "hex": "S13"})
	ok(p.piano(g) == 0, "265: il tedesco scende al pianterreno")
	a.stato = "attivo"
	a.piano = 1
	p.ia._g = g
	p.leggi("265", {"g": g.id, "hex": "S13"})
	ok(p.piano(g) == 1, "265: con un americano di sopra il tedesco sale e lo carica")
	# Salvataggio.
	var q = PartitaScript.new(5)
	ok(q.carica(JSON.parse_string(JSON.stringify(p.salva()))) and q.piano(q.u("A")) == p.piano(a), "il piano resta nel salvataggio")
	var errs: Array = p.s.cronaca.filter(func(c): return str(c.get("t", "")) == "errore")
	for c in errs:
		print("        ! " + str(c.x))
	ok(errs.is_empty(), "nessun errore nella cronaca")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
