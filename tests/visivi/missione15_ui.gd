extends SceneTree
## Scatti della Missione 15: diga, letto asciutto e piena, colonna motorizzata, pulsante delle chiuse.
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) if args.size() > 0 else 1366
	var h := int(args[1]) if args.size() > 1 else 900
	var dir := args[2] if args.size() > 2 else "/tmp"
	DisplayServer.window_set_size(Vector2i(w, h))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_scatti(dir, "%dx%d" % [w, h])

func aspetta(n := 20) -> void:
	for i in n:
		await process_frame

func scatta(percorso: String) -> void:
	await aspetta(8)
	root.get_viewport().get_texture().get_image().save_png(percorso)
	print("scatto ", percorso)

func _scatti(dir: String, tag: String) -> void:
	await aspetta(30)
	ui._avvia_missione(15, false, false)
	await aspetta(20)
	var p = ui.p
	var sq: Array = p.americani()
	p.schiera(sq.map(func(a): return a.id), "Y17")
	p.inizia_missione()
	p.s.pausa = ""
	p.leggi("442", {"hex": "K12", "ids": [sq[0].id]})
	p.leggi("532", {})
	p.s.ph.chiuse.hex = "O5"
	p.s.punti.erase("V12")
	p.s.punti["O5"] = "comandi chiuse"
	for i in sq.size():
		sq[i].hex = ["O5", "O5", "P5", "Q6", "R5", "P4", "Q4", "R4"][i % 8]
	ui.selezione = [sq[0].id]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("P7")
	await aspetta(150)
	await scatta("%s/m15_diga_%s.png" % [dir, tag])
	p.s.fase = "operazioni"
	p.azione_ph(sq[0].id, "chiuse")
	p.ph.inizio_round()
	p.ph.inizio_round()
	p.leggi("593", {})
	p.leggi("598", {})
	p.s.pausa = ""
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("H6")
	await aspetta(120)
	await scatta("%s/m15_piena_%s.png" % [dir, tag])
	quit()
