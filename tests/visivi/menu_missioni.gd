extends SceneTree
## Scatti della pagina iniziale: carosello dei moduli e missioni a sinistra, descrizione e opzioni a destra.
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

func scatto(dir: String, nome: String) -> void:
	await aspetta(15)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, nome])

func _scatti(dir: String, tag: String) -> void:
	await aspetta(40)
	await scatto(dir, "menu_" + tag)
	ui._mostra_missione_scelta(6)
	await scatto(dir, "menu6_" + tag)
	ui._gira_carosello(1)
	await scatto(dir, "menu_mo_" + tag)
	ui._mostra_missione_scelta(15)
	await scatto(dir, "menu15_" + tag)
	ui._modulo_carosello = 4
	ui._mostra_modulo(false)
	await scatto(dir, "menu_campagna_" + tag)
	ui._mostra_missione_scelta(6)
	ui._avvia_missione(6, false, false)
	await aspetta(30)
	await scatto(dir, "partita_" + tag)
	print("scatto ", tag)
	quit()
