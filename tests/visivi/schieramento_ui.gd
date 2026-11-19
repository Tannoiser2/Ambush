extends SceneTree
## Prova lo schieramento iniziale dall’interfaccia e salva tre schermate
## (xvfb-run godot --path . --script tests/visivi/schieramento_ui.gd -- cartella).
var ui
var errori := 0

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_prova()

func controlla(ok: bool, cosa: String) -> void:
	print(("ok      " if ok else "ERRORE  ") + cosa)
	if not ok:
		errori += 1

func scatta(nome: String) -> void:
	await process_frame
	await process_frame
	var args := OS.get_cmdline_user_args()
	var cartella: String = args[0] if args.size() > 0 else "/tmp/ambush_scatti"
	DirAccess.make_dir_recursive_absolute(cartella)
	root.get_viewport().get_texture().get_image().save_png("%s/schieramento_%s.png" % [cartella, nome])

func _prova() -> void:
	await create_timer(0.4).timeout
	ui._nuova()
	ui._chiudi_finestra()
	ui.mappa.velocita = 30.0
	ui.automatico = true
	await process_frame
	controlla(ui.p.s.fase == "schieramento", "una partita nuova comincia dallo schieramento")
	await scatta("1_inizio")
	ui._clic_mappa("E1", 1)
	await process_frame
	controlla(ui.p.u("A").hex == "E1" and ui.p.s.fase == "schieramento", "piazzare il primo soldato non fa partire la missione")
	controlla(ui.selezione == ["B"], "dopo un piazzamento è pronto il soldato successivo")
	ui._clic_mappa("E1", 1)
	ui._clic_mappa("F1", 1)
	ui.selezione = ["D", "E", "F", "G", "H"]
	ui._aggiorna_tutto()
	ui._clic_mappa("C1", 1)
	await process_frame
	controlla(ui.p.americani().filter(func(x): return x.hex != "").size() == 8 and ui.p.tedeschi().is_empty(), "tutti e otto sulla mappa, nessun nemico attivato")
	await scatta("2_tutti")
	ui.mappa.mostra_vista = true
	ui._cambia_linee()
	controlla(not ui.mappa.mostra_vista and ui.mappa.linee.is_empty(), "il pulsante toglie le linee di vista")
	ui._cambia_linee()
	controlla(ui.mappa.mostra_vista, "e le rimette")
	ui._esito(ui.p.inizia_missione())
	for i in 600:
		await process_frame
		if not ui.riproducendo and ui.p.s.pausa == "":
			break
	controlla(ui.p.s.fase in ["operazioni", "round"], "il via fa cominciare la missione (fase: %s)" % ui.p.s.fase)
	await scatta("3_via")
	print("ERRORI: ", errori)
	quit(1 if errori > 0 else 0)
