extends SceneTree
## Gioca qualche passo sull’interfaccia e salva schermate, anche durante le animazioni
## (serve un display: xvfb-run godot --path . --script tests/visivi/scatti.gd -- seme).
var ui
var n := 0

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var sc: PackedScene = load("res://scene/principale.tscn")
	ui = sc.instantiate()
	root.add_child(ui)
	_sequenza()

func scatta(nome: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png("/tmp/claude-0/sc_%02d_%s.png" % [n, nome])
	print("scatto ", n, " ", nome)

## Segue una riproduzione: scatti a intervalli finché termina.
func segui(nome: String, intervallo := 0.7, massimo := 6) -> void:
	var i := 0
	await create_timer(0.25).timeout
	while ui.riproducendo and i < massimo:
		await scatta("%s_%d" % [nome, i])
		await create_timer(intervallo).timeout
		i += 1
	while ui.riproducendo:
		await process_frame
	await scatta(nome + "_fine")

func _sequenza() -> void:
	await create_timer(0.5).timeout
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seme := int(args[0]) if args.size() > 0 else 7
	ui.p.nuova(seme)
	ui._chiudi_finestra()
	ui._aggiorna_tutto(true)
	ui.selezione = ["A", "B", "C"]
	ui._aggiorna_tutto()
	for h in ["E1", "E2", "E3", "F3", "G4", "G5", "H5", "H6", "I6", "J7", "K7", "L8"]:
		if ui.p.s.fase != "operazioni" or ui.p.s.pausa != "":
			break
		ui._clic_mappa(h, 1)
		await segui("mossa_" + h, 0.6, 2)
	for i in 14:
		if ui.p.s.fase != "round":
			break
		if ui.p.s.pausa != "":
			ui._prosegui()
			await segui("prosegui_%d" % i, 0.55, 8)
			continue
		var di_turno: Array = ui.p.americani_di_turno()
		if di_turno.is_empty():
			ui._prosegui()
			await segui("flusso_%d" % i)
			continue
		var a: Dictionary = di_turno[0]
		ui.selezione = [a.id]
		ui._aggiorna_tutto()
		# Tira al primo tedesco visibile, altrimenti passa
		var fatto := false
		if a.postura == "prone":
			ui.p.cambia_postura(a.id, "crouching")
		for g in ui.p.tedeschi_attivi():
			for arma in ui.p.armi_da_fuoco(a):
				if ui.p.probabilita_tiro(a, arma, g, true).ok and not fatto:
					ui.arma_scelta[a.id] = arma.tipo
					ui.modo = "mirato"
					ui._spara(a, g)
					fatto = true
		if not fatto:
			ui._esito(ui.p.passa(a.id))
		await segui("us_%d" % i, 0.4, 4)
	quit()
