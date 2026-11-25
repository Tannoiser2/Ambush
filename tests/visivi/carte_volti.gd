extends SceneTree
## Scatti: carta tedesca in alcune missioni (base, Move Out, Purple Heart, Silver Star)
## e scheda della squadra con i volti dei soldati.
## Uso: xvfb-run godot --path . --script tests/visivi/carte_volti.gd -- [larghezza] [altezza] [cartella]
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
	for n in [4, 10, 15, 20]:
		ui._chiudi_finestra()
		ui._avvia_missione(n, false)
		await aspetta(15)
		ui._chiudi_finestra()
		var nums: Array = ui.p.missione.tedeschi.keys()
		nums.sort_custom(func(a, b): return int(a) < int(b))
		var num := int(nums[nums.size() / 2])
		var perc: String = ui._percorso_carta({"lato": "de", "num": num})
		if perc.ends_with("us05.jpg"):
			push_error("Missione %d: carta tedesca %d senza immagine" % [n, num])
		ui._mostra_carta({"lato": "x", "num": num})
		await aspetta(10)
		await scatta("%s/carta_m%d_%s.png" % [dir, n, tag])
	# Scheda della squadra con i volti (Missione 4 dopo l’atterraggio).
	ui._chiudi_finestra()
	ui._avvia_missione(4, false)
	await aspetta(15)
	ui._chiudi_finestra()
	var p = ui.p
	var r := 6
	for id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
		p.schiera([id], "Y%d" % r)
		r += 1
	p.inizia_missione()
	p.leggi("086", {"hex": "", "ids": []})
	ui._aggiorna_tutto(true)
	await aspetta(20)
	await scatta("%s/squadra_volti_%s.png" % [dir, tag])
	quit()
