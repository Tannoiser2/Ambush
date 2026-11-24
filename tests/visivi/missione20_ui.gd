extends SceneTree
## Scatti della Missione 20: il convoglio in fila, un camion fuori uso con il carico da trasbordare e un blocco stradale, in 2D e 3D.
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
	ui._avvia_missione(20, false, false)
	await aspetta(20)
	var p = ui.p
	p.schiera(p.americani().map(func(a): return a.id), "A8")
	p.inizia_missione()
	p.s.pausa = ""
	var guida: Dictionary = p.veicoli.autista(p.veicoli.v("vjeep"))
	for h in ["B7", "C7", "D6", "E7", "F6"]:
		p.muovi([guida.id], h)
		p.s.pausa = ""
	ui.selezione = [guida.id]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("D6")
	await aspetta(120)
	await scatta("%s/m20_convoglio_%s.png" % [dir, tag])
	# Camion fuori uso, carico da trasbordare, blocco stradale.
	p.s.avvistamenti[0] = true
	p._op({"op": "ss_blocco", "hex": "F5"}, {})
	var c2: Dictionary = p.veicoli.v("vcamion2")
	p.veicoli.disabilita(c2, "prova")
	var c1: Dictionary = p.veicoli.v("vcamion1")
	p.veicoli.sposta(c1, c2.hex)
	var g: Dictionary = p.u("G")
	p.veicoli.scendi(g)
	g.hex = c2.hex
	g.postura = "crouching"
	p.s.pausa = ""
	ui.selezione = ["G"]
	ui._aggiorna_tutto(true)
	await aspetta(60)
	await scatta("%s/m20_carico_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(true)
	await aspetta(90)
	var v3 = ui.mappa.vista3d
	if v3 != null:
		var c: Vector3 = v3.centro3d("E6")
		v3.bersaglio = Vector3(c.x, 0, c.z)
		v3.imbardata = 0.6
		v3.beccheggio = 40.0
		v3.distanza = 9.0
		await aspetta(40)
		await scatta("%s/m20_3d_%s.png" % [dir, tag])
	quit()
