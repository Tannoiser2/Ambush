extends SceneTree
## Scatti della neve (missione 3) e della pioggia (missione 1 con un seme di partita in cui piove).
## Uso: xvfb-run godot --path . --script tests/visivi/meteo3d.gd -- [larghezza] [altezza] [cartella]
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) if args.size() > 0 else 1200
	var h := int(args[1]) if args.size() > 1 else 800
	var dir := args[2] if args.size() > 2 else "/tmp"
	DisplayServer.window_set_size(Vector2i(w, h))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_vai(dir, "%dx%d" % [w, h])

func aspetta(k := 20) -> void:
	for i in k:
		await process_frame

func _vai(dir: String, tag: String) -> void:
	await aspetta(20)
	ui._pref_grafica["3d"] = true
	var errori := []
	for caso in [[3, "neve"], [1, "pioggia"]]:
		ui._avvia_missione(caso[0], false, false)
		await aspetta(5)
		var p = ui.p
		var fx = ui.mappa.vista3d.effetti
		if caso[1] == "pioggia":
			var seme := 1
			p.s.seme = seme
			while fx.tempo_di(p) != "pioggia":
				seme += 1
				p.s.seme = seme
		if fx.tempo_di(p) != caso[1]:
			errori.append("missione %d: tempo %s" % [caso[0], fx.tempo_di(p)])
		var v3 = ui.mappa.vista3d
		v3.bersaglio = v3.centro3d("G6")
		v3.beccheggio = 24.0
		v3.distanza = 6.0
		ui._aggiorna_tutto(true)
		await aspetta(90)
		if fx._precipitazione == null or not fx._precipitazione.emitting:
			errori.append("missione %d: niente %s" % [caso[0], caso[1]])
		root.get_viewport().get_texture().get_image().save_png("%s/meteo_%s_%s.png" % [dir, caso[1], tag])
	# stessa inquadratura senza pioggia, per confronto della luce
	ui.Effetti3DMeteo.meteo_attivo = false
	await aspetta(60)
	root.get_viewport().get_texture().get_image().save_png("%s/meteo_sereno_%s.png" % [dir, tag])
	ui.Effetti3DMeteo.meteo_attivo = true
	await aspetta(5)
	# preferenza spenta: niente precipitazioni
	ui.Effetti3DMeteo.meteo_attivo = false
	await aspetta(5)
	if ui.mappa.vista3d.effetti._precipitazione != null:
		errori.append("meteo spento ma le particelle restano")
	ui.Effetti3DMeteo.meteo_attivo = true
	print("ERRORI: ", errori if not errori.is_empty() else "nessuno")
	quit(1 if not errori.is_empty() else 0)
