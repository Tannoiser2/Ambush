extends SceneTree
## Scatti della Missione 5: briefing e mappa con guado, installazioni e auto comando.
## Uso: xvfb-run godot --path . --script tests/visivi/missione3_ui.gd -- [larghezza] [altezza] [cartella]
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
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(percorso)
	print("scatto ", percorso)

func _scatti(dir: String, tag: String) -> void:
	await aspetta(30)
	ui._chiudi_finestra()
	ui._avvia_missione(5, false)
	await aspetta(20)
	await scatta("%s/m5_briefing_%s.png" % [dir, tag])
	ui._chiudi_finestra()
	await aspetta(10)
	var p = ui.p
	p.inizia_missione()
	for id in ["A", "B", "C", "D"]:
		var x: Dictionary = p.u(id)
		x.stato = "attivo"
		x.hex = "Q8"
	p.s.fase = "operazioni"
	p.leggi("635", {"hex": "", "ids": []})
	p.leggi("487", {"hex": "", "ids": []})
	p.leggi("626", {"hex": "", "ids": []})
	p.leggi("133", {"hex": "Q8", "ids": ["A"]})
	p.leggi("996", {"hex": "", "ids": []})
	while p.s.pausa != "":
		p.prosegui()
	var primo := "A"
	ui.selezione = [primo]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("S10")
	await aspetta(30)
	await scatta("%s/m5_mappa_%s.png" % [dir, tag])
	quit()
