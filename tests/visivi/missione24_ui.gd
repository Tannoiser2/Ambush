extends SceneTree
## Scatti della Missione 24: la squadra scarica i muli in K8 e li guida (con i bottoni dei muli), in 2D e 3D.
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
	ui._avvia_missione(24, false, false)
	await aspetta(20)
	var p = ui.p
	var i := 0
	for a in p.americani():
		p.schiera([a.id], "D9" if i == 0 else ("I9" if i < 5 else "J9"))
		i += 1
	p.inizia_missione()
	p.s.pausa = ""
	var b: Dictionary = p.u("B")
	b.hex = "K8"
	p.ss.m24.scarica_muli()
	p.ss.m24.prendi(b)
	for id in ["C", "D"]:
		p.u(id).hex = "K8"
	b.hex = "L8"
	p.ss.m24.dopo_movimento(["B"])
	var c: Dictionary = p.u("C")
	ui.selezione = ["C"]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("K8")
	await aspetta(90)
	await scatta("%s/m24_muli_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(true)
	await aspetta(90)
	var v3 = ui.mappa.vista3d
	if v3 != null:
		var cc: Vector3 = v3.centro3d("K8")
		v3.bersaglio = Vector3(cc.x, 0, cc.z)
		v3.imbardata = 0.6
		v3.beccheggio = 40.0
		v3.distanza = 9.0
		await aspetta(40)
		await scatta("%s/m24_3d_%s.png" % [dir, tag])
	quit()
