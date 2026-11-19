extends SceneTree
## Scatti della Missione 4: briefing, schieramento per il lancio, mappa dopo l’atterraggio.
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
	ui._avvia_missione(4, false)
	await aspetta(20)
	await scatta("%s/m4_briefing_%s.png" % [dir, tag])
	ui._chiudi_finestra()
	await aspetta(10)
	await scatta("%s/m4_schieramento_%s.png" % [dir, tag])
	var p = ui.p
	var r := 6
	for id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
		p.schiera([id], "Y%d" % r)
		r += 1
	ui._aggiorna_tutto(true)
	await aspetta(10)
	await scatta("%s/m4_pronti_%s.png" % [dir, tag])
	p.inizia_missione()
	p.leggi("086", {"hex": "", "ids": []})
	var primo := ""
	for a in p.americani():
		if p.attivo(a):
			primo = a.id
			break
	ui.selezione = [primo]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su(p.u(primo).hex)
	await aspetta(30)
	await scatta("%s/m4_mappa_%s.png" % [dir, tag])
	quit()
