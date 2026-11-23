extends SceneTree
## Scatti della Missione 10: turno dei mortai sulla mappa A e passaggio alla mappa B (2D e 3D).
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
	ui._avvia_missione(10, false, false)
	await aspetta(20)
	await scatta("%s/m10_inizio_%s.png" % [dir, tag])
	var p = ui.p
	p.inizia_missione()
	ui.automatico = true
	for i in 200:
		if p.s.pausa != "":
			p.prosegui()
			continue
		if not p.americani_di_turno().is_empty():
			break
		p.prosegui()
	ui._aggiorna_tutto(true)
	await aspetta(200)
	ui._premi_continua()
	await aspetta(60)
	var a: Dictionary = p.americani_di_turno()[0] if not p.americani_di_turno().is_empty() else {}
	if not a.is_empty():
		p.mo.colpo(a.id, 0, p.tedeschi_attivi()[0].hex)
	ui.selezione = [a.get("id", "MOR")]
	ui._aggiorna_tutto(true)
	await aspetta(200)
	await scatta("%s/m10_mortai_%s.png" % [dir, tag])
	ui._pref_grafica["3d"] = true
	ui._applica_3d()
	await aspetta(120)
	await scatta("%s/m10_mortai3d_%s.png" % [dir, tag])
	ui._pref_grafica["3d"] = false
	ui._applica_3d()
	p.mo._condizione_2_m10()
	ui._aggiorna_tutto(true)
	await aspetta(120)
	await scatta("%s/m10_mappaB_%s.png" % [dir, tag])
	ui._pref_grafica["3d"] = true
	ui._applica_3d()
	await aspetta(160)
	await scatta("%s/m10_mappaB3d_%s.png" % [dir, tag])
	quit()
