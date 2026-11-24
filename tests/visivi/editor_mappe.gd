extends SceneTree
## Scatti dell'editor delle mappe. Uso: godot --path . --script tests/visivi/editor_mappe.gd -- L H cartella
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) if args.size() > 0 else 1600
	var h := int(args[1]) if args.size() > 1 else 1000
	var dir := args[2] if args.size() > 2 else "/tmp"
	DisplayServer.window_set_size(Vector2i(w, h))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_scatti(dir, "%dx%d" % [w, h])

func aspetta(k := 20) -> void:
	for i in k:
		await process_frame

func scatto(dir: String, nome: String) -> void:
	await aspetta(8)
	root.get_viewport().get_texture().get_image().save_png("%s/editor_%s.png" % [dir, nome])

func _scatti(dir: String, tag: String) -> void:
	await aspetta(20)
	ui._scegli_missione()
	await aspetta(10)
	await scatto(dir, tag + "_0menu")
	ui._apri_editor_mappe()
	await aspetta(10)
	var ed = ui.get_child(ui.get_child_count() - 1)
	ed.carica("be")
	await aspetta(5)
	await scatto(dir, tag + "_1terreno")
	ed._zoom_a(3.0, ed.tela.size / 2.0)
	ed._imposta_modo("quota")
	await scatto(dir, tag + "_2quote")
	ed._imposta_modo("lati")
	await scatto(dir, tag + "_3lati")
	ed._imposta_modo("vegetazione")
	await scatto(dir, tag + "_4alberi")
	ed._imposta_modo("edifici")
	ed.stanza_sel = 3
	await scatto(dir, tag + "_5edifici")
	ed.bottone_3d.button_pressed = true
	ed._alterna_3d()
	await aspetta(40)
	await scatto(dir, tag + "_6vista3d")
	quit()
