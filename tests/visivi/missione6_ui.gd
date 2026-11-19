extends SceneTree
## Scatti della Missione 6: briefing, canoe sul fiume e bunker.
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
	ui._avvia_missione(6, false)
	await aspetta(20)
	await scatta("%s/m6_briefing_%s.png" % [dir, tag])
	ui._chiudi_finestra()
	await aspetta(10)
	var p = ui.p
	for id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
		p.schiera([id], "H1")
	p.inizia_missione()
	p.s.fase = "operazioni"
	var c1: Dictionary = p.veicoli.v("canoa1")
	var guida: Dictionary = p.veicoli.autista(c1)
	for h in ["I2", "I3", "J4"]:
		p.muovi([guida.id], h)
	p.leggi("725", {"hex": "", "ids": []})
	while p.s.pausa != "":
		p.prosegui()
	var primo: String = guida.id
	ui.selezione = [primo]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("J8")
	await aspetta(30)
	await scatta("%s/m6_mappa_%s.png" % [dir, tag])
	quit()
