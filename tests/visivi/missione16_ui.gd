extends SceneTree
## Scatti della Missione 16: schieramento sulla mappa C, battello d’assalto ed esplosivo nel deposito.
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
	ui._avvia_missione(16, false, false)
	await aspetta(20)
	var p = ui.p
	var sq: Array = p.americani()
	var posti := ["B2", "B2", "B18", "B18", "X2", "X2", "X18", "X18"]
	for i in sq.size():
		p.schiera([sq[i].id], posti[i] if i < posti.size() else "T12")
	ui._aggiorna_tutto(true)
	await aspetta(120)
	await scatta("%s/m16_schieramento_%s.png" % [dir, tag])
	p.inizia_missione()
	p.leggi("407", {"hex": "X2", "ids": []})
	p.s.condizione = 2
	var g20: Dictionary = p.u("g20")
	p.ia._g = g20
	p.ia.ph._muovi_barca(g20)
	var g36 = p._crea_tedesco(36, "V13", "crouching")
	p.ia._g = g36
	p.ia._mp = 5
	p.ph.op({"op": "pianta_esplosivo"}, {"g": g36.id})
	sq[0].hex = "U14"
	ui.selezione = [sq[0].id]
	ui._aggiorna_tutto(true)
	await aspetta(150)
	await scatta("%s/m16_deposito_%s.png" % [dir, tag])
	quit()
