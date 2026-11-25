extends SceneTree
## Sequenza di fotogrammi delle animazioni procedurali delle miniature: passo, rinculo, cambio di posa, caduta.
## Uso: xvfb-run godot --path . --script tests/visivi/animazioni3d.gd -- [cartella]
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp"
	DisplayServer.window_set_size(Vector2i(900, 640))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_vai(dir)

func aspetta(k := 1) -> void:
	for i in k:
		await process_frame

func foto(dir: String, nome: String) -> void:
	await aspetta(2)
	root.get_viewport().get_texture().get_image().save_png("%s/anim_%s.png" % [dir, nome])

func _vai(dir: String) -> void:
	await aspetta(20)
	ui._pref_grafica["3d"] = true
	ui._avvia_missione(1, false, false)
	await aspetta(5)
	var p = ui.p
	for a in p.americani():
		p.schiera([a.id], "A1")
	p.inizia_missione()
	for a in p.americani():
		a.hex = ""
	var a = p.u("A")
	a.hex = "G6"
	a.postura = "standing"
	ui.selezione = []
	ui._aggiorna_tutto(true)
	var m2 = ui.mappa
	var v3 = m2.vista3d
	v3.bersaglio = v3.centro3d("G6")
	v3.imbardata = 1.4
	v3.beccheggio = 22.0
	v3.distanza = 1.7
	await aspetta(20)
	var errori := []
	# passo: da F6 a G6 in 1,2 s
	m2.direzioni["A"] = ["F6", "G6"]
	m2.mobili["A"] = {"da": "F6", "a": "G6", "t0": m2._t, "dur": 1.2, "off": 0.0}
	for i in 4:
		await _attendi(0.25)
		await foto(dir, "passo%d" % i)
	m2.mobili.erase("A")
	await _attendi(0.3)
	var fig: Node3D = v3._figure["A"]
	var corpo: MeshInstance3D = fig.get_node("corpo")
	# rinculo
	m2.direzioni["A"] = ["G6", "H6"]
	m2.spari["A"] = m2._t
	await _attendi(0.12)
	if corpo.position.length() < 0.005:
		errori.append("nessun rinculo")
	await foto(dir, "rinculo")
	await _attendi(0.5)
	if corpo.position.length() > 0.002:
		errori.append("rinculo non tornato")
	# cambio di posa: in piedi → accovacciato
	a.postura = "crouching"
	await _attendi(0.1)
	if fig.get_child_count() < 3:
		errori.append("nessuna dissolvenza fra le pose")
	await foto(dir, "posa")
	await _attendi(0.4)
	# caduta
	a.stato = "morto"
	await _attendi(0.15)
	var x1 := corpo.rotation.x
	await foto(dir, "caduta1")
	await _attendi(0.5)
	var z2 := corpo.rotation.z
	await foto(dir, "caduta2")
	if not (x1 < -0.05 and x1 > -1.4 and absf(z2 - deg_to_rad(80.0)) < 0.05):
		errori.append("caduta non graduale: %.2f, poi %.2f" % [x1, z2])
	print("ERRORI: ", errori if not errori.is_empty() else "nessuno")
	quit(1 if not errori.is_empty() else 0)

func _attendi(sec: float) -> void:
	var t0: float = ui.mappa._t
	while ui.mappa._t - t0 < sec:
		await process_frame
