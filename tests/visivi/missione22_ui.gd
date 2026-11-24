extends SceneTree
## Scatti della Missione 22: la squadra sui mezzi, il grande ponte con i genieri tedeschi, un esplosivo e un soldato sotto il
## ponte (con i bottoni del ponte), in 2D e 3D.
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
	ui._avvia_missione(22, false, false)
	await aspetta(20)
	var p = ui.p
	p.schiera(p.americani().map(func(a): return a.id), "X1")
	p.inizia_missione()
	p.s.pausa = ""
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("V3")
	await aspetta(90)
	await scatta("%s/m22_ingresso_%s.png" % [dir, tag])
	p.s.avvistamenti[5] = true
	p.leggi("483", {})
	p.leggi("723", {})
	p.s.pausa = ""
	var a: Dictionary = p.u("A")
	p.veicoli.scendi(a)
	a.hex = "J14"
	p.ss.m22.scendi_sotto(a)
	p.ss.m22._st().esplosivi["J14"] = 2
	var b: Dictionary = p.u("B")
	p.veicoli.scendi(b)
	b.hex = "I15"
	b.postura = "crouching"
	p.s.turno = {}
	if p.fase_round():
		p.s.round.slot_azione = ""
	ui.selezione = ["A"]
	ui._aggiorna_tutto(true)
	ui.mappa.centra_su("J14")
	await aspetta(90)
	await scatta("%s/m22_ponte_%s.png" % [dir, tag])
	ui.mappa.imposta_3d(true)
	await aspetta(90)
	var v3 = ui.mappa.vista3d
	if v3 != null:
		var c: Vector3 = v3.centro3d("J14")
		v3.bersaglio = Vector3(c.x, 0, c.z)
		v3.imbardata = 0.6
		v3.beccheggio = 40.0
		v3.distanza = 9.0
		await aspetta(40)
		await scatta("%s/m22_3d_%s.png" % [dir, tag])
	quit()
