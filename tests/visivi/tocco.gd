extends SceneTree
## Verifica i gesti sulla mappa: trascinamento con un dito, pizzico con due, tocco che sceglie un esagono
## (serve un display: xvfb-run godot --path . --script tests/visivi/tocco.gd).
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

func tocco(indice: int, pos: Vector2, giu: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = indice
	e.position = pos
	e.pressed = giu
	Input.parse_input_event(e)

func striscia(indice: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = indice
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)

func _prova() -> void:
	await create_timer(0.4).timeout
	ui.p.nuova(3)
	ui._chiudi_finestra()
	ui._aggiorna_tutto(true)
	await process_frame
	var m: Control = ui.mappa
	var centro: Vector2 = m.global_position + m.size / 2.0
	m.zoom_a(2.0, m.size / 2.0)
	await process_frame
	# un dito: trascina
	var prima: Vector2 = m.spostamento
	tocco(0, centro, true)
	await process_frame
	for i in 8:
		striscia(0, centro + Vector2(-12.0 * (i + 1), -6.0 * (i + 1)), Vector2(-12, -6))
		await process_frame
	tocco(0, centro + Vector2(-96, -48), false)
	await process_frame
	await process_frame
	controlla(m.spostamento.distance_to(prima) > 40.0, "un dito sposta la mappa (%.0f px)" % m.spostamento.distance_to(prima))
	# due dita: pizzico
	var z0: float = m.zoom
	tocco(0, centro + Vector2(-60, 0), true)
	tocco(1, centro + Vector2(60, 0), true)
	await process_frame
	for i in 8:
		striscia(0, centro + Vector2(-60 + 5.0 * (i + 1), 0), Vector2(5, 0))
		striscia(1, centro + Vector2(60 - 5.0 * (i + 1), 0), Vector2(-5, 0))
		await process_frame
	tocco(1, centro + Vector2(20, 0), false)
	tocco(0, centro + Vector2(-20, 0), false)
	await process_frame
	await process_frame
	controlla(m.zoom < z0 * 0.8, "due dita che si avvicinano rimpiccioliscono (zoom %.2f → %.2f)" % [z0, m.zoom])
	var z1: float = m.zoom
	tocco(0, centro + Vector2(-20, 0), true)
	tocco(1, centro + Vector2(20, 0), true)
	await process_frame
	for i in 8:
		striscia(0, centro + Vector2(-20 - 8.0 * (i + 1), 0), Vector2(-8, 0))
		striscia(1, centro + Vector2(20 + 8.0 * (i + 1), 0), Vector2(8, 0))
		await process_frame
	tocco(1, centro + Vector2(84, 0), false)
	tocco(0, centro + Vector2(-84, 0), false)
	await process_frame
	await process_frame
	controlla(m.zoom > z1 * 1.2, "due dita che si allontanano ingrandiscono (zoom %.2f → %.2f)" % [z1, m.zoom])
	# tocco semplice: sceglie l’esagono e non sposta
	m.vista_iniziale()
	await process_frame
	ui.selezione = ["A"]
	ui._aggiorna_tutto()
	var bersaglio: Vector2 = m.global_position + m.centro_schermo("E1")
	var sp: Vector2 = m.spostamento
	tocco(0, bersaglio, true)
	await process_frame
	tocco(0, bersaglio, false)
	for i in 30:
		await process_frame
	controlla(ui.p.u("A").hex == "E1", "un tocco su E1 fa entrare il soldato (ora in «%s»)" % ui.p.u("A").hex)
	controlla(m.spostamento.distance_to(sp) < 400.0, "il tocco non trascina la mappa")
	print("ERRORI: ", errori)
	quit(1 if errori > 0 else 0)
