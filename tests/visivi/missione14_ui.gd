extends SceneTree
## Scatti della Missione 14: ingresso in Y7 sulle due jeep, poi J8 con i superstiti.
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
	ui._avvia_missione(14, false, false)
	await aspetta(20)
	var p = ui.p
	var sq: Array = p.americani()
	p.schiera(sq.map(func(a): return a.id), "Y7")
	p.inizia_missione()
	p.s.pausa = ""
	ui.selezione = [sq[0].id]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("V7")
	await aspetta(150)
	await scatta("%s/m14_jeep_%s.png" % [dir, tag])
	for a in sq:
		if a.get("veicolo", "") != "":
			p.veicoli.scendi(a)
		a.hex = "J8"
	p.leggi("331", {"hex": "J8", "ids": [sq[0].id]})
	p.leggi("348", {"hex": "J8", "ids": [sq[0].id]})
	p.s.pausa = ""
	ui.selezione = [sq[1].id]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("J8")
	await aspetta(120)
	await scatta("%s/m14_j8_%s.png" % [dir, tag])
	quit()
