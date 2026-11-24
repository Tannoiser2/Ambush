extends SceneTree
## Scatti delle regole di Purple Heart aggiunte dopo le prime versioni: camion e guardia J (M16), scialuppa (M13),
## sotto il ponte e spoletta in turni (M17), decisione della Missione 18.
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
	# M16: camion del carburante in U14 e guardia J
	ui._avvia_missione(16, false, false)
	await aspetta(20)
	var p = ui.p
	var sq: Array = p.americani()
	for c in [["B2", 0], ["B18", 2], ["X2", 4], ["X18", 6]]:
		p.schiera([sq[c[1]].id, sq[c[1] + 1].id], str(c[0]))
	p.inizia_missione()
	p.s.pausa = ""
	p.s.fase = "operazioni"
	p.leggi("717", {"hex": "A3"})
	var t1: Dictionary = p.u("T1")
	var v1: Dictionary = p.veicoli.di(t1)
	v1.hex = "U14"
	t1.hex = "U14"
	p.ph._soldato_j()
	ui.selezione = [t1.id]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("U14")
	await aspetta(120)
	await scatta("%s/ph_camion_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(true)
	await aspetta(90)
	var v3 = ui.mappa.vista3d
	if v3 != null:
		var c: Vector3 = v3.centro3d("U14")
		v3.bersaglio = Vector3(c.x, 0, c.z)
		v3.imbardata = 0.5
		v3.beccheggio = 40.0
		v3.distanza = 8.0
		await aspetta(40)
		await scatta("%s/ph_camion3d_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(false)
	await aspetta(10)
	# M17: sotto il ponte J11 con due cariche
	ui._avvia_missione(17, false, false)
	await aspetta(20)
	p = ui.p
	sq = p.americani()
	p.schiera(sq.map(func(a): return a.id), "A3")
	p.inizia_missione()
	p.s.pausa = ""
	var a0: Dictionary = sq[0]
	a0.hex = "J11"
	a0.postura = "crouching"
	a0.sotto_ponte = true
	p.ponte_stato("J11").cariche = 2
	p.leggi("387", {"hex": "A3"})
	p.s.pausa = ""
	ui.selezione = [a0.id]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("J11")
	await aspetta(120)
	await scatta("%s/ph_ponte_%s.png" % [dir, tag])
	quit()
