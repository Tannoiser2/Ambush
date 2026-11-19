extends SceneTree
## Scatti della Missione 2: elenco delle missioni, briefing, mappa B con la jeep e la Kübelwagen.
## Uso: xvfb-run godot --path . --script tests/visivi/missione2_ui.gd -- [larghezza] [altezza] [cartella]
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
	ui._scegli_missione()
	await scatta("%s/m2_menu_%s.png" % [dir, tag])
	ui._chiudi_finestra()
	ui._avvia_missione(2, false)
	await aspetta(20)
	await scatta("%s/m2_briefing_%s.png" % [dir, tag])
	ui._chiudi_finestra()
	var p = ui.p
	p.inizia_missione()
	for id in ["A", "B", "C", "D"]:
		p.schiera([id], "")
	p.s.fase = "operazioni"
	for id in ["A", "B", "C"]:
		var x: Dictionary = p.u(id)
		x.stato = "attivo"
		x.hex = "L9"
	p.leggi("304", {"hex": "", "ids": []})
	p.leggi("156", {"hex": "", "ids": []})
	p.leggi("128", {"hex": "N12", "ids": ["A"]})
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("N11")
	await aspetta(30)
	await scatta("%s/m2_mappa_%s.png" % [dir, tag])
	quit()
