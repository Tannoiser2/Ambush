extends SceneTree
## Scatto della pagina iniziale con le 8 missioni illustrate.
## Uso: xvfb-run godot --path . --script tests/visivi/menu_missioni.gd -- [larghezza] [altezza] [cartella]
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

func _scatti(dir: String, tag: String) -> void:
	await aspetta(40)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/menu_%s.png" % [dir, tag])
	ui._mostra_missione_scelta(6)
	await aspetta(20)
	root.get_viewport().get_texture().get_image().save_png("%s/menu6_%s.png" % [dir, tag])
	ui._avvia_missione(6, false, false)
	await aspetta(30)
	root.get_viewport().get_texture().get_image().save_png("%s/partita_%s.png" % [dir, tag])
	print("scatto ", tag)
	quit()
