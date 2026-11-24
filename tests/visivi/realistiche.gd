extends SceneTree
## Scatti delle mappe realistiche di Silver Star (F, F+H, F+G, G+H) in 2D e 3D, e del pannello «Grafica».
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
	for n in [20, 19, 21, 24]:
		ui._avvia_missione(n, false, false)
		await aspetta(20)
		ui.mappa.imposta_3d(false)
		ui.mappa.imposta_grafica(true, ui.mappa.pedine_nuove)
		ui.mappa.vista_intera() if ui.mappa.has_method("vista_intera") else null
		await aspetta(30)
		await scatta("%s/real_m%d_%s.png" % [dir, n, tag])
	ui.mappa.imposta_3d(true)
	await aspetta(80)
	await scatta("%s/real_m24_3d_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(false)
	ui._mostra_grafica()
	await aspetta(30)
	await scatta("%s/real_grafica_%s.png" % [dir, tag])
	quit()
