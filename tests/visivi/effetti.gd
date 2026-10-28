extends SceneTree
## Schermate degli effetti animati a tempi fissi.
var ui
func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_go()

func scatta(nome: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().get_region(Rect2i(356, 70, 856, 690)).save_png("/tmp/claude-0/fx_%s.png" % nome)

func prova(nome: String, ev: Dictionary, tempi: Array) -> void:
	ev.vista = ui.p.istantanea()
	var t0 := Time.get_ticks_msec()
	var d: float = ui.mappa.anima(ev)
	for k in tempi:
		while Time.get_ticks_msec() - t0 < int(d * 1000.0 * k):
			await process_frame
		await scatta("%s_%02d" % [nome, int(k * 100)])
	await create_timer(d).timeout

func _go() -> void:
	await create_timer(0.4).timeout
	ui.p.nuova(3)
	ui._chiudi_finestra()
	var p: Partita = ui.p
	for id in ["A", "B"]:
		p.u(id).stato = "attivo"; p.u(id).hex = "H5"
	var g := p._crea_tedesco(25, "M7", "crouching")
	ui._aggiorna_tutto()
	ui.mappa.zoom = 0.0
	ui.mappa.vista_iniziale()
	ui.mappa.centra_su("J6")
	await prova("raffica", {"t": "fx", "fx": "tiro", "da": "H5", "a": "M7", "tiratore": "A", "bersaglio": "g25", "auto": true, "esito": "colpito"}, [0.15, 0.35, 0.7])
	await prova("tedesco", {"t": "fx", "fx": "tiro", "da": "M7", "a": "H5", "tiratore": "g25", "bersaglio": "B", "auto": false, "esito": "mancato"}, [0.2, 0.75])
	await prova("granata", {"t": "fx", "fx": "lancio", "da": "H5", "bersaglio": "J6", "a": "J7", "tipo": "granata", "esito": "esplode", "id": "A"}, [0.3, 0.7])
	await prova("attore", {"t": "fx", "fx": "attore", "id": "g25", "a": "M7"}, [0.5])
	await prova("muovi", {"t": "fx", "fx": "muovi", "ids": ["g25"], "da": "M7", "a": "L7"}, [0.5])
	await prova("danno", {"t": "fx", "fx": "danno", "id": "B", "tipo": "ferito"}, [0.4])
	quit()
