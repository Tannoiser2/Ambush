extends SceneTree
## Scatti della vista 3D. Uso: xvfb-run godot --path . --script tests/visivi/mappa3d.gd -- missione L H cartella
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 6
	var w := int(args[1]) if args.size() > 1 else 1600
	var h := int(args[2]) if args.size() > 2 else 1000
	var dir := args[3] if args.size() > 3 else "/tmp"
	DisplayServer.window_set_size(Vector2i(w, h))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_scatti(n, dir, "%d_%dx%d" % [n, w, h])

func aspetta(k := 20) -> void:
	for i in k:
		await process_frame

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
	ui.selezione = ["A"]
	ui._aggiorna_tutto(true)
	var v3 = ui.mappa.vista3d
	var t0 := Time.get_ticks_msec()
	await aspetta(30)
	root.get_viewport().get_texture().get_image().save_png("%s/m3d_%s_a.png" % [dir, tag])
	v3.imbardata = 0.6
	v3.beccheggio = 35.0
	v3.distanza = 7.0
	await aspetta(20)
	root.get_viewport().get_texture().get_image().save_png("%s/m3d_%s_b.png" % [dir, tag])
	v3.bersaglio = Vector3(v3.dim_px.x * 0.01 * 0.5, 0, v3.dim_px.y * 0.01 * 0.5)
	v3.imbardata = -0.4
	v3.beccheggio = 48.0
	v3.distanza = 22.0
	await aspetta(20)
	root.get_viewport().get_texture().get_image().save_png("%s/m3d_%s_c.png" % [dir, tag])
	print("hex sotto il centro: ", v3._raggio_esagono(v3.size / 2.0), " tempo ", Time.get_ticks_msec() - t0)
	quit()
