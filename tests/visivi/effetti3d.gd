extends SceneTree
## Scatti degli effetti 3D: notte con gli esagoni in vista più chiari e un bengala (Missione 23), nebbia procedurale
## (Missione 3), acqua del fiume (Missione 19), colpi traccianti, esplosione, incendio e fumo.
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
	print("scatto ", percorso, " ", Time.get_ticks_msec())

func inquadra(h: String, dist := 8.0, becc := 42.0, imb := 0.6) -> void:
	var v3 = ui.mappa.vista3d
	var c: Vector3 = v3.centro3d(h)
	v3.bersaglio = Vector3(c.x, 0, c.z)
	v3.imbardata = imb
	v3.beccheggio = becc
	v3.distanza = dist

func _scatti(dir: String, tag: String) -> void:
	await aspetta(30)
	# --- Notte, Missione 23: squadra in C3–E3, bengala su E4, incendio in F5, colpi ed esplosione.
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
	p._op({"op": "vista", "n": 4}, {})
	p.ss.m23.razzo("F4")
	p.s.oggetti["G5"] = [{"tipo": "incendio"}]
	ui.selezione = ["A"]
	ui._aggiorna_tutto(true)
	ui.mappa.imposta_3d(true)
	await aspetta(60)
	inquadra("E4", 9.0, 44.0)
	await aspetta(50)
	await scatta("%s/fx_notte_%s.png" % [dir, tag])
	ui.mappa.anima({"fx": "tiro", "da": "D4", "a": "G4", "tiratore": "D", "bersaglio": "", "arma": "lmg", "auto": true, "mirato": true, "esito": "colpito", "prob": 5})
	ui.mappa.anima({"fx": "esplosione", "a": "F5", "grande": true})
	await aspetta(9)
	await scatta("%s/fx_colpi_%s.png" % [dir, tag])
	await aspetta(25)
	await scatta("%s/fx_fumo_%s.png" % [dir, tag])
	# --- Nebbia di giorno, Missione 3.
	print("avvio 3 ", Time.get_ticks_msec())
	ui.mappa.imposta_3d(false)
	ui._avvia_missione(3, false, false)
	await aspetta(20)
	print("avviata 3 ", Time.get_ticks_msec())
	p = ui.p
	p.schiera(p.americani().map(func(a): return a.id), p.esagoni_ingresso()[0])
	p.inizia_missione()
	p.s.pausa = ""
	ui._aggiorna_tutto(true)
	ui.mappa.imposta_3d(true)
	await aspetta(60)
	inquadra(p.u("A").hex if p.u("A").hex != "" else "E5", 11.0, 34.0)
	await aspetta(60)
	await scatta("%s/fx_nebbia_%s.png" % [dir, tag])
	# --- Acqua del fiume, Missione 19.
	ui._avvia_missione(19, false, false)
	await aspetta(20)
	p = ui.p
	p.schiera(p.americani().map(func(a): return a.id), "A1")
	p.inizia_missione()
	p.s.pausa = ""
	ui._aggiorna_tutto(true)
	ui.mappa.imposta_3d(true)
	await aspetta(60)
	inquadra("C1", 6.0, 38.0)
	await aspetta(50)
	await scatta("%s/fx_acqua_notte_%s.png" % [dir, tag])
	# --- Acqua di giorno, Missione 22 (torrente sotto il ponte di O4).
	ui._avvia_missione(22, false, false)
	await aspetta(20)
	p = ui.p
	p.schiera(p.americani().map(func(a): return a.id), "X1")
	p.inizia_missione()
	p.s.pausa = ""
	ui._aggiorna_tutto(true)
	ui.mappa.imposta_3d(true)
	await aspetta(60)
	inquadra("N8", 5.0, 36.0, 1.2)
	await aspetta(50)
	await scatta("%s/fx_acqua_%s.png" % [dir, tag])
	quit()
