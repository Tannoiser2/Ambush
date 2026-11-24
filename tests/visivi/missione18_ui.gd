extends SceneTree
## Scatti della Missione 18: la decisione a inizio Round, Jagdpanther e Sherman di rinforzo in 2D e in 3D.
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
	ui._avvia_missione(18, false, false)
	await aspetta(20)
	var p = ui.p
	var sq: Array = p.americani()
	p.schiera(sq.map(func(a): return a.id), "K15")
	p.inizia_missione()
	p.s.pausa = ""
	# Jagdpanther in N14 con due serventi
	p.leggi("621", {"hex": "N15"})
	sq[0].hex = "N14"
	sq[1].hex = "N14"
	p._controlla_da_leggere()
	p.esegui_scelta("599")
	p.jagd_sali(sq[0].id)
	ui.selezione = [sq[1].id]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("N14")
	await aspetta(120)
	await scatta("%s/m18_jagd_%s.png" % [dir, tag])
	# Sherman di rinforzo e Panzer, poi la decisione
	p.leggi("762", {"hex": "K15"})
	p.leggi("714", {})
	for id in ["AA", "BB"]:
		var z: Dictionary = p.u(id)
		z.stato = "attivo"
		z.hex = "K18" if id == "AA" else "F18"
		var vz: Dictionary = p.veicoli.di(z)
		vz.hex = z.hex
		vz.erase("fuori_mappa_ph")
	p.leggi("301", {})
	p.s.pausa = "inizio_round"
	ui.selezione = []
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("J15")
	await aspetta(120)
	await scatta("%s/m18_decisione_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(true)
	await aspetta(90)
	var v3 = ui.mappa.vista3d
	if v3 != null:
		var c: Vector3 = v3.centro3d("K16")
		v3.bersaglio = Vector3(c.x, 0, c.z)
		v3.imbardata = 0.4
		v3.beccheggio = 40.0
		v3.distanza = 10.0
		await aspetta(40)
		await scatta("%s/m18_3d_%s.png" % [dir, tag])
	quit()
