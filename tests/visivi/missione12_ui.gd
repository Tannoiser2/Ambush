extends SceneTree
## Scatti della Missione 12: chiatta sul fiume (mappa A), poi galleria e prigionieri sulla mappa B.
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
	ui._avvia_missione(12, false, false)
	await aspetta(20)
	var p = ui.p
	for a in p.americani().filter(func(x): return x.stato == "fuori"):
		p.schiera([a.id], "S1")
	p.inizia_missione()
	p.leggi("433", {"hex": "P11", "ids": []})
	for a in p.americani_attivi_in_mappa():
		a.hex = "M12"
	p._controlla_fine_automatica()
	var ch: Dictionary = p.veicoli.v("chiatta")
	p.s.imbarco = true
	for a in p.americani_attivi_in_mappa():
		p.veicoli.sali(a, ch)
	p.s.imbarco = false
	ui.selezione = ["A"]
	ui._aggiorna_tutto(true)
	await aspetta(150)
	await scatta("%s/m12_chiatta_%s.png" % [dir, tag])
	ch.hex = "O19"
	for a in p.veicoli.occupanti(ch):
		a.hex = "O19"
	p._controlla_fine_automatica()
	for a in p.americani_attivi_in_mappa():
		p.veicoli.scendi(a)
		a.hex = "G13"
	p.leggi("682", {"hex": "G13", "ids": ["A", "J"]})
	p.mo.galleria("A", true)
	p.leggi("692", {"hex": "Q8", "ids": []})
	ui.selezione = ["J"]
	ui._aggiorna_tutto(true)
	await aspetta(150)
	await scatta("%s/m12_galleria_%s.png" % [dir, tag])
	quit()
