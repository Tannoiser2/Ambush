extends SceneTree
## Scatti della Missione 19: canoe con i sommozzatori aggrappati, nuoto e immersione, chiatte ed esplosivi, in 2D e in 3D.
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
	ui._avvia_missione(19, false, false)
	await aspetta(20)
	var p = ui.p
	p.schiera(p.americani().map(func(a): return a.id), "A1")
	p.inizia_missione()
	p.s.pausa = ""
	var c1: Dictionary = p.veicoli.v("canoa1")
	p.muovi([p.veicoli.autista(c1).id], "B1")
	ui.selezione = [p.veicoli.autista(c1).id]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("C2")
	await aspetta(120)
	await scatta("%s/m19_canoe_%s.png" % [dir, tag])
	# Sgancio dei sommozzatori, uno sott’acqua, chiatte e un esplosivo a tempo.
	p.leggi("787", {"hex": "D1", "ids": []})
	p.u("E").hex = "E3"
	p.u("F").hex = "F4"
	p.u("G").hex = "D4"
	p.u("H").hex = "E4"
	p.s.pausa = ""
	p.cambia_postura("F", "prone")
	p._op({"op": "ss_chiatte", "dispari": ["D7", "J7"], "pari": ["D7", "J7"]}, {})
	p.leggi("237", {})
	p.u("G").hex = "D7"
	p.ss.piazza_esplosivo(p.u("G"))
	p.s.pausa = ""
	ui.selezione = ["F"]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("E5")
	await aspetta(120)
	await scatta("%s/m19_cala_%s.png" % [dir, tag])
	ui.selezione = ["G"]
	ui._aggiorna_tutto(true)
	await aspetta(40)
	await scatta("%s/m19_azioni_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(true)
	await aspetta(90)
	var v3 = ui.mappa.vista3d
	if v3 != null:
		var c: Vector3 = v3.centro3d("E5")
		v3.bersaglio = Vector3(c.x, 0, c.z)
		v3.imbardata = 0.5
		v3.beccheggio = 42.0
		v3.distanza = 11.0
		await aspetta(40)
		await scatta("%s/m19_3d_%s.png" % [dir, tag])
	quit()
