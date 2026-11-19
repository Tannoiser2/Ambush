extends SceneTree
## Prova le opzioni di grafica (mappa realistica, pedine ridisegnate, segni del comando)
## e salva alcune schermate: xvfb-run godot --path . --script tests/visivi/grafica_ui.gd -- cartella
var ui
var errori := 0
var cartella := "/tmp/ambush_scatti"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		cartella = args[0]
	DirAccess.make_dir_recursive_absolute(cartella)
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
	root.get_viewport().get_texture().get_image().save_png("%s/grafica_%s.png" % [cartella, nome])

func _prova() -> void:
	await create_timer(0.4).timeout
	ui._nuova()
	ui._chiudi_finestra()
	ui._pref_grafica = {"mappa": false, "pedine": false, "comando": true}
	ui._applica_grafica()
	var p: Partita = ui.p
	p.schiera(["A", "B", "C"], "E1")
	p.schiera(["D"], "G1")
	p.schiera(["E", "F"], "J1")
	p.schiera(["G"], "A1")
	p.schiera(["H"], "C1")
	ui.selezione = ["D"]
	ui._aggiorna_tutto()
	await process_frame
	controlla(p.in_comando(p.u("A")) and p.in_comando(p.u("D")), "A e D (entro due esagoni dal comandante) sono in comando")
	controlla(not p.in_comando(p.u("G")) and not p.in_comando(p.u("E")), "G da solo ed E con F (somma 4) sono fuori comando")
	controlla(p.in_comando_se(["G"], "B1") == false and p.in_comando_se(["G"], "C1"), "l’anteprima dice dove G tornerebbe in comando (C1 sì, B1 no)")
	controlla(p.u("G").hex == "A1", "l’anteprima non sposta nessuno")
	ui.mappa.vista_iniziale()
	await process_frame
	ui.mappa.zoom_a(1.7, ui.mappa.centro_schermo("E1"))
	ui.mappa.spostamento += Vector2(120, 150)
	ui._sopra_mappa("H1")
	await scatta("1_originale")
	ui._pref_grafica.pedine = true
	ui._applica_grafica()
	ui._aggiorna_tutto()
	controlla(ui.mappa.pedine_nuove and ui.mappa.trame.has("prono_us"), "le pedine ridisegnate sono caricate")
	await scatta("2_pedine_nuove")
	ui._pref_grafica.mappa = true
	ui._applica_grafica()
	p.u("B").postura = "crouching"
	p.u("C").postura = "prone"
	p.u("E").ferito = true
	ui._aggiorna_tutto()
	controlla(ui.mappa.mappa_realistica, "la mappa realistica è caricata")
	await scatta("3_realistica")
	ui.mappa.centra()
	await scatta("4_realistica_intera")
	ui._mostra_grafica()
	await create_timer(0.2).timeout
	await scatta("5_finestra")
	ui._chiudi_finestra()
	ui._pref_grafica = {"mappa": false, "pedine": false, "comando": true}
	ui._applica_grafica()
	ui._salva_preferenze()
	print("ERRORI: ", errori)
	quit(1 if errori > 0 else 0)
