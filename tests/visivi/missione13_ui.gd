extends SceneTree
## Scatti della Missione 13: base navale (mappa A + D) con faro, motosiluranti e deposito della marina.
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
	ui._avvia_missione(13, false, false)
	await aspetta(20)
	var p = ui.p
	var sq: Array = p.americani().filter(func(a): return a.stato == "fuori")
	p.schiera(sq.map(func(a): return a.id), "Q1")
	p.inizia_missione()
	p.s.fase = "operazioni"
	p.s.pausa = ""
	p.leggi("495", {"hex": "P11", "ids": []})
	for i in sq.size():
		sq[i].hex = ["K12", "L12", "M13", "H14", "N12", "O12", "P11", "Q11"][i % 8]
	p.leggi("526", {"hex": "K12", "ids": [sq[0].id]})
	p.leggi("643", {"hex": "H14"})
	p.s.pausa = ""
	ui.selezione = [sq[0].id]
	ui._aggiorna_tutto(true)
	await aspetta(150)
	await scatta("%s/m13_base_%s.png" % [dir, tag])
	ui.mappa.centra_su("H15")
	await aspetta(60)
	await scatta("%s/m13_porto_%s.png" % [dir, tag])
	quit()
