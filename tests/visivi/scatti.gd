extends SceneTree
## Gioca qualche passo sull’interfaccia e salva una schermata a ogni passo della riproduzione
## (serve un display: xvfb-run godot --path . --script tests/visivi/scatti.gd -- seme larghezza altezza cartella).
var ui
var n := 0
var cartella := "/tmp/ambush_scatti"

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var w := int(args[1]) if args.size() > 1 else 1600
	var h := int(args[2]) if args.size() > 2 else 900
	if args.size() > 3:
		cartella = args[3]
	DirAccess.make_dir_recursive_absolute(cartella)
	DisplayServer.window_set_size(Vector2i(w, h))
	var sc: PackedScene = load("res://scene/principale.tscn")
	ui = sc.instantiate()
	root.add_child(ui)
	_sequenza()

func scatta(nome: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png("%s/sc_%02d_%s.png" % [cartella, n, nome])
	print("scatto ", n, " ", nome)

## Segue una riproduzione a passi: uno scatto a ogni conferma richiesta, poi prosegue.
func segui(nome: String, massimo := 14) -> void:
	var i := 0
	var fermo := 0
	while fermo < 12:
		await process_frame
		if ui._in_attesa:
			fermo = 0
			if i < massimo:
				await scatta("%s_%d" % [nome, i])
			i += 1
			ui._avanti = true
			await process_frame
		elif ui.riproducendo:
			fermo = 0
			if i >= massimo:
				ui._salta_tutto = true
		else:
			fermo += 1

func _sequenza() -> void:
	await create_timer(0.5).timeout
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seme := int(args[0]) if args.size() > 0 else 7
	ui.p.nuova(seme)
	ui._chiudi_finestra()
	ui.automatico = false
	ui.mappa.velocita = 2.5
	ui._aggiorna_tutto(true)
	ui.selezione = ["A", "B", "C"]
	ui._aggiorna_tutto()
	await scatta("inizio")
	for h in ["E1", "E2", "E3", "F3", "G4", "G5", "H5", "H6", "I6", "J7", "K7", "L8"]:
		if ui.p.s.fase != "operazioni" or ui.p.s.pausa != "":
			break
		ui._clic_mappa(h, 1)
		await segui("mossa_" + h)
	await scatta("dopo_mosse")
	for i in 10:
		if ui.p.s.fase != "round":
			break
		var di_turno: Array = ui.p.americani_di_turno()
		if di_turno.is_empty():
			ui._prosegui()
			await segui("flusso_%d" % i)
			continue
		var a: Dictionary = di_turno[0]
		ui.selezione = [a.id]
		ui._aggiorna_tutto()
		if a.postura == "prone":
			ui._esito(ui.p.cambia_postura(a.id, "crouching"))
			await segui("postura_%d" % i)
		var fatto := false
		for g in ui.p.tedeschi_attivi():
			for arma in ui.p.armi_da_fuoco(a):
				if ui.p.probabilita_tiro(a, arma, g, true).ok and not fatto:
					ui.arma_scelta[a.id] = arma.tipo
					ui._imposta_modo(a, "mirato")
					await scatta("mira_%d" % i)
					ui._spara(a, g)
					fatto = true
		if not fatto:
			await scatta("turno_%d" % i)
			ui._esito(ui.p.passa(a.id))
		await segui("us_%d" % i)
		await scatta("dopo_us_%d" % i)
	ui._mostra_legenda()
	await create_timer(0.3).timeout
	await scatta("legenda")
	quit()
