extends SceneTree
## Esegue una sequenza di comandi sull’interfaccia e salva schermate (richiede un display, es. xvfb-run).
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
	await create_timer(0.3).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-0/ui_%s.png" % nome)
	print("scatto ", nome)

func _sequenza() -> void:
	await create_timer(0.5).timeout
	var passi: Array = OS.get_cmdline_user_args()
	var seme := int(passi[0]) if passi.size() > 0 else 7
	ui.p.nuova(seme)
	ui._chiudi_finestra()
	ui._aggiorna_tutto(true)
	await scatta("00_inizio")
	ui.selezione = ["A", "B", "C"]
	ui._aggiorna_tutto()
	await scatta("01_gruppo")
	var colonne := ["E1", "E2", "E3", "F3", "G4", "G5", "H5", "H6", "I6", "J7"]
	for h in colonne:
		if ui.p.s.fase != "operazioni" or ui.p.s.pausa != "":
			break
		ui._clic_mappa(h, 1)
		await process_frame
		if ui.dispaccio.visible:
			await scatta("02_dispaccio_" + h)
			ui._chiudi_dispaccio()
	await scatta("03_dopo_movimento")
	# Se sono iniziati i Round, prosegue qualche passo
	for i in 12:
		if ui.p.s.fase != "round":
			break
		if ui.p.s.pausa != "":
			await scatta("04_round_%d" % i)
			ui._chiudi_dispaccio() if ui.dispaccio.visible else ui._prosegui()
			continue
		var di_turno: Array = ui.p.americani_di_turno()
		if di_turno.is_empty():
			ui._prosegui()
			continue
		ui.selezione = [di_turno[0].id]
		ui._aggiorna_tutto()
		await scatta("05_turno_%d" % i)
		ui.p.passa(di_turno[0].id)
		ui._aggiorna_tutto()
	quit()
