extends SceneTree
## Scatti della Missione 3: briefing, schieramento negli edifici, mappa con Panzer IV, radio, ponti e azioni sui ponti.
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
	ui._avvia_missione(3, false)
	await aspetta(20)
	await scatta("%s/m3_briefing_%s.png" % [dir, tag])
	ui._chiudi_finestra()
	await aspetta(10)
	await scatta("%s/m3_schieramento_%s.png" % [dir, tag])
	var p = ui.p
	p.schiera(["A", "B", "C", "D"], "J13")
	p.schiera(["E", "F"], "K12")
	p.schiera(["G", "H"], "L10")
	p.inizia_missione()
	p.leggi("178", {"hex": "", "ids": []})
	var f: Dictionary = p.u("F")
	f.hex = "G13"
	f.stato = "attivo"
	p.arma_di(f, "satchel").preparata = true
	p.azione_ponte("F", "carica", "G13")
	p.leggi("157", {"hex": "", "ids": []})
	while p.s.pausa != "":
		p.prosegui()
	ui.selezione = ["F"]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("H12")
	await aspetta(30)
	await scatta("%s/m3_mappa_%s.png" % [dir, tag])
	quit()
