extends SceneTree
## Scatti della Missione 23: la squadra nella nebbia con il segnalino della pattuglia, un razzo illuminante, il filo spinato e
## l’edificio fortificato, in 2D e 3D.
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
	ui._avvia_missione(23, false, false)
	await aspetta(20)
	var p = ui.p
	p.schiera(p.americani().map(func(a): return a.id), "A1")
	p.inizia_missione()
	p.s.pausa = ""
	var esa := ["C3", "C3", "D4", "D4", "E3", "E3", "B3", "B3"]
	var i := 0
	for a in p.americani():
		a.hex = esa[i]
		i += 1
	p.ss.m23.piazza_pattuglia("NN", "H5")
	p.ss.m23.razzo("E4")
	ui.selezione = ["A"]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("E4")
	await aspetta(90)
	await scatta("%s/m23_nebbia_%s.png" % [dir, tag])
	p._op({"op": "vista", "n": 10}, {})
	p.leggi("160", {})
	p.ss.m23._st().pattuglie = {}
	p.leggi("271", {})
	p.s.pausa = ""
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("S12")
	await aspetta(90)
	await scatta("%s/m23_villaggio_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(true)
	await aspetta(90)
	var v3 = ui.mappa.vista3d
	if v3 != null:
		var c: Vector3 = v3.centro3d("S12")
		v3.bersaglio = Vector3(c.x, 0, c.z)
		v3.imbardata = 0.6
		v3.beccheggio = 40.0
		v3.distanza = 9.0
		await aspetta(40)
		await scatta("%s/m23_3d_%s.png" % [dir, tag])
	quit()
