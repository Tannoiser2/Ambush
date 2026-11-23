extends SceneTree
## Scatti del campanile di S13: un soldato al piano superiore e uno al pianterreno (2D e 3D).
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	DisplayServer.window_set_size(Vector2i(int(args[0]), int(args[1])))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_scatti(args[2], "%sx%s" % [args[0], args[1]])

func aspetta(n := 20) -> void:
	for i in n:
		await process_frame

func _scatti(dir: String, tag: String) -> void:
	await aspetta(30)
	ui._avvia_missione(5, false, false)
	await aspetta(20)
	var p = ui.p
	p.schiera(["A", "B"], p.esagoni_ingresso()[0])
	p.inizia_missione()
	p.s.fase = "operazioni"
	p.s.pausa = ""
	for id in ["A", "B"]:
		p.u(id).hex = "S13"
		p.u(id).postura = "standing"
	p.cambia_piano("A")
	ui.selezione = ["A"]
	ui._aggiorna_tutto(true)
	ui.mappa.zoom = 1.6
	ui.mappa.centra_su("S13")
	await aspetta(80)
	root.get_viewport().get_texture().get_image().save_png("%s/piani2d_%s.png" % [dir, tag])
	ui._pref_grafica["3d"] = true
	ui._applica_3d()
	await aspetta(60)
	var v = ui.mappa.vista3d
	if v != null:
		v.centra_su("S13")
	await aspetta(120)
	root.get_viewport().get_texture().get_image().save_png("%s/piani3d_%s.png" % [dir, tag])
	print("fatto")
	quit()
