extends SceneTree
## Scatti 3D di edifici, mezzi e paracadute.
## Uso: ... --script tests/visivi/scena3d.gd -- L H cartella
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) if args.size() > 0 else 1180
	var h := int(args[1]) if args.size() > 1 else 820
	var dir := args[2] if args.size() > 2 else "/tmp"
	DisplayServer.window_set_size(Vector2i(w, h))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_scatti(dir, "%dx%d" % [w, h])

func aspetta(k := 20) -> void:
	for i in k:
		await process_frame

func foto(nome: String) -> void:
	await aspetta(25)
	root.get_viewport().get_texture().get_image().save_png(nome)

func _scatti(dir: String, tag: String) -> void:
	await aspetta(20)
	ui._pref_grafica["3d"] = true
	# --- Missione 3: villaggio, jeep, carri
	ui._avvia_missione(3, false, false)
	await aspetta(5)
	var p = ui.p
	for a in p.americani():
		p.schiera([a.id], "M10" if a.id < "D" else ("N9" if a.id < "G" else "P9"))
	p.inizia_missione()
	p._crea_tedesco(4, "O8", "standing")
	var j = p._crea_tedesco(54, "R6", "standing")
	ui.selezione = ["E"]
	ui._aggiorna_tutto(true)
	var v3 = ui.mappa.vista3d
	v3.bersaglio = v3.centro3d("O8")
	v3.imbardata = 0.5
	v3.beccheggio = 42.0
	v3.distanza = 9.0
	ui.mappa.sopra = ""
	await foto("%s/scena_%s_villaggio.png" % [dir, tag])
	v3.bersaglio = v3.centro3d("N9")
	v3.distanza = 5.0
	v3.beccheggio = 50.0
	await foto("%s/scena_%s_dentro.png" % [dir, tag])
	var jeep_hex: String = p.s.veicoli.vjeep.hex if p.s.get("veicoli", {}).has("vjeep") else "J12"
	v3.bersaglio = v3.centro3d(jeep_hex)
	v3.distanza = 4.0
	v3.imbardata = -0.8
	await foto("%s/scena_%s_jeep.png" % [dir, tag])
	# --- Missione 4: lancio
	ui._avvia_missione(4, false, false)
	await aspetta(5)
	p = ui.p
	var ing: Array = p.esagoni_ingresso()
	var i := 0
	for a in p.americani():
		p.schiera([a.id], str(ing[i % ing.size()]))
		i += 1
	ui._pref_grafica["3d"] = true
	ui.mappa.velocita = 0.6
	ui._avvia_dal_schieramento() if ui.has_method("_avvia_dal_schieramento") else ui._esito(p.inizia_missione())
	v3 = ui.mappa.vista3d
	v3.bersaglio = v3.centro3d(str(ing[2]))
	v3.distanza = 9.0
	v3.beccheggio = 30.0
	await aspetta(60)
	await foto("%s/scena_%s_lancio1.png" % [dir, tag])
	await aspetta(90)
	await foto("%s/scena_%s_lancio2.png" % [dir, tag])
	print("paracadutisti: ", ui.mappa.paracadutisti.keys(), " riproduce ", ui.riproducendo)
	quit()
