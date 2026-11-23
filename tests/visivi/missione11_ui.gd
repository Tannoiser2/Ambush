extends SceneTree
## Scatti della Missione 11: scelta nel menu, schieramento della sentinella, paracadutisti atterrati (2D e 3D).
## Uso: xvfb-run godot --path . --script tests/visivi/missione11_ui.gd -- [larghezza] [altezza] [cartella]
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
	ui._mostra_missione_scelta(11)
	await aspetta(20)
	await scatta("%s/m11_menu_%s.png" % [dir, tag])
	ui._avvia_missione(11, false, false)
	await aspetta(20)
	await scatta("%s/m11_schieramento_%s.png" % [dir, tag])
	var p = ui.p
	p.schiera(["A"], "Y8")
	p.inizia_missione()
	p.leggi("409", {"hex": "Y8", "ids": ["A"]})
	ui._aggiorna_tutto(true)
	await aspetta(200)
	await scatta("%s/m11_lancio_%s.png" % [dir, tag])
	ui._pref_grafica["3d"] = true
	ui._applica_3d()
	await aspetta(120)
	await scatta("%s/m11_lancio3d_%s.png" % [dir, tag])
	quit()
