extends SceneTree
## Scatti della Missione 21: schieramento a sezioni, il Jagdpanther con i granatieri sopra, la motovedetta e il cannone navale
## nella baia (con il bottone «Sali sulla motovedetta»), in 2D e 3D.
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
	ui._avvia_missione(21, false, false)
	await aspetta(20)
	var p = ui.p
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("L14")
	await aspetta(60)
	await scatta("%s/m21_schieramento_%s.png" % [dir, tag])
	var esa := ["E15", "F14", "G14", "H13", "S13", "T12", "U13", "V13"]
	var i := 0
	for a in p.americani():
		p.schiera([a.id], esa[i])
		i += 1
	p.inizia_missione()
	p.s.pausa = ""
	p.leggi("365", {})
	p.s.pausa = ""
	p.veicoli.sposta(p.veicoli.v("v21"), "P18")
	p.leggi("587", {})
	p.s.pausa = ""
	var vpb: Dictionary = p.veicoli.v("vpb")
	p.veicoli.sposta(vpb, "D1")
	var a: Dictionary = p.u("A")
	a.hex = "E2"
	a.postura = "crouching"
	p.s.turno = {}
	ui.selezione = ["A"]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("F4")
	await aspetta(90)
	await scatta("%s/m21_baia_%s.png" % [dir, tag])
	ui.mappa.centra_su("P17")
	await aspetta(40)
	await scatta("%s/m21_carro_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(true)
	await aspetta(90)
	var v3 = ui.mappa.vista3d
	if v3 != null:
		var c: Vector3 = v3.centro3d("E2")
		v3.bersaglio = Vector3(c.x, 0, c.z)
		v3.imbardata = 0.6
		v3.beccheggio = 40.0
		v3.distanza = 9.0
		await aspetta(40)
		await scatta("%s/m21_3d_%s.png" % [dir, tag])
	quit()
