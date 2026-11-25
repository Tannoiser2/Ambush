extends SceneTree
## Scatto 3D del treno (Missione 17: locomotiva e vagone sul binario) e del faro di Purple Heart.
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[2] if args.size() > 2 else "/tmp"
	DisplayServer.window_set_size(Vector2i(1400, 900))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_scatti(dir)

func aspetta(k := 20) -> void:
	for i in k:
		await process_frame

func _scatti(dir: String) -> void:
	await aspetta(20)
	ui._pref_grafica["3d"] = true
	ui._avvia_missione(17, false, false)
	await aspetta(5)
	var p = ui.p
	var binario: Array = p.regola("binario", [])
	var i := binario.size() / 2
	p.s.punti[binario[i]] = "locomotiva"
	p.s.punti[binario[i + 1]] = "vagone merci"
	p.s.punti[binario[i + 2]] = "cisterna"
	var fh: String = binario[i - 3]
	if not p.s.has("oggetti"):
		p.s.oggetti = {}
	p.s.oggetti[fh] = [{"tipo": "faro"}]
	ui._aggiorna_tutto(true)
	var v3 = ui.mappa.vista3d
	v3.bersaglio = v3.centro3d(binario[i + 1])
	v3.imbardata = 0.6
	v3.beccheggio = 32.0
	v3.distanza = 5.5
	await aspetta(40)
	root.get_viewport().get_texture().get_image().save_png("%s/treno_faro.png" % dir)
	v3.bersaglio = v3.centro3d(fh)
	v3.distanza = 4.5
	await aspetta(30)
	root.get_viewport().get_texture().get_image().save_png("%s/faro.png" % dir)
	print("scatto ", binario[i], " faro ", fh)
	quit()
