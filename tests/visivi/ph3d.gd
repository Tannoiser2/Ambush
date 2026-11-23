extends SceneTree
## Scatti 3D delle mappe di Purple Heart. Uso: godot --path . --script tests/visivi/ph3d.gd -- missione L H cartella
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 15
	var be := n == 99
	if be:
		n = 16
	var w := int(args[1]) if args.size() > 1 else 1600
	var h := int(args[2]) if args.size() > 2 else 1000
	var dir := args[3] if args.size() > 3 else "/tmp"
	DisplayServer.window_set_size(Vector2i(w, h))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	mappa_be = be
	_scatti(n, dir, ("be_" if be else "") + "%d_%dx%d" % [n, w, h])

func aspetta(k := 20) -> void:
	for i in k:
		await process_frame

func inquadra(v3, hx: String, imb: float, bec: float, dist: float) -> void:
	var c: Vector3 = v3.centro3d(hx)
	v3.bersaglio = Vector3(c.x, 0, c.z)
	v3.imbardata = imb
	v3.beccheggio = bec
	v3.distanza = dist

var mappa_be := false

func _scatti(n: int, dir: String, tag: String) -> void:
	await aspetta(20)
	ui._pref_grafica["3d"] = true
	ui._avvia_missione(n, false, false)
	await aspetta(10)
	var p = ui.p
	var ing: Array = p.esagoni_ingresso()
	for a in p.americani():
		p.schiera([a.id], str(ing[0]))
	p.inizia_missione()
	p.s.pausa = ""
	var viste: Array = []
	match n:
		15:
			p.leggi("442", {"hex": ing[0]})
			p.leggi("386", {"hex": ing[0]})
			viste = [["N7", 0.5, 38.0, 9.0], ["J12", -0.5, 35.0, 8.0], ["V14", 0.9, 40.0, 8.0], ["M10", -0.3, 50.0, 24.0]]
		13:
			p.s.fase = "operazioni"
			p.leggi("495", {"hex": "P11", "ids": []})
			p.leggi("643", {"hex": "H14"})
			p.s.pausa = ""
			viste = [["H14", 0.6, 38.0, 10.0], ["V12", -0.4, 35.0, 9.0], ["M12", 0.2, 50.0, 24.0]]
		_:
			if mappa_be:
				p.cambia_mappa("BE")
			viste = [["M10", -0.3, 50.0, 24.0], ["K15", 0.4, 38.0, 10.0], ["R16", -0.6, 40.0, 9.0]]
	ui._aggiorna_tutto(true)
	var v3 = ui.mappa.vista3d
	await aspetta(40)
	for i in viste.size():
		var x: Array = viste[i]
		inquadra(v3, str(x[0]), float(x[1]), float(x[2]), float(x[3]))
		await aspetta(25)
		root.get_viewport().get_texture().get_image().save_png("%s/ph3d_%s_%d.png" % [dir, tag, i])
		print("scatto ", i)
	quit()
