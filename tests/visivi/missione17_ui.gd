extends SceneTree
## Scatti della Missione 17: ponte con le cariche (pulsanti del timer) e treno in 2D e in 3D.
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
	ui._avvia_missione(17, false, false)
	await aspetta(20)
	var p = ui.p
	var sq: Array = p.americani()
	p.schiera(sq.map(func(a): return a.id), "A3")
	p.inizia_missione()
	p.s.pausa = ""
	var a0: Dictionary = sq[0]
	a0.hex = "J11"
	a0.postura = "standing"
	p.ponte_stato("J11").cariche = 2
	ui.selezione = [a0.id]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("L10")
	await aspetta(150)
	await scatta("%s/m17_ponte_%s.png" % [dir, tag])
	p.leggi("486", {})
	p.s.pausa = ""
	p.ph._muovi_treno(6)
	ui._aggiorna_tutto(true)
	ui.mappa.imposta_3d(true)
	await aspetta(90)
	var v3 = ui.mappa.vista3d
	if v3 != null:
		var c: Vector3 = v3.centro3d("U5")
		v3.bersaglio = Vector3(c.x, 0, c.z)
		v3.imbardata = -0.3
		v3.beccheggio = 38.0
		v3.distanza = 9.0
		await aspetta(40)
		await scatta("%s/m17_treno3d_%s.png" % [dir, tag])
	quit()
