extends SceneTree
## Primi piani della vista 3D. Uso: godot --path . --script tests/visivi/dettaglio3d.gd -- missione L H cartella esagono:imbardata:beccheggio:distanza ...
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0])
	var w := int(args[1])
	var h := int(args[2])
	var dir := args[3]
	DisplayServer.window_set_size(Vector2i(w, h))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_scatti(n, dir, "%d_%dx%d" % [n, w, h], args.slice(4))

func aspetta(k := 20) -> void:
	for i in k:
		await process_frame

func _scatti(n: int, dir: String, tag: String, viste: Array) -> void:
	await aspetta(20)
	ui._pref_grafica["3d"] = true
	ui._avvia_missione(n, false, false)
	await aspetta(10)
	var p = ui.p
	var ing: Array = p.esagoni_ingresso()
	for a in p.americani():
		p.schiera([a.id], str(ing[0]))
	p.inizia_missione()
	ui._aggiorna_tutto(true)
	var v3 = ui.mappa.vista3d
	await aspetta(20)
	var k := 0
	for vv in viste:
		var x := str(vv).split(":")
		var c: Vector3 = v3.centro3d(x[0])
		v3.bersaglio = Vector3(c.x, c.y, c.z)
		v3.imbardata = float(x[1])
		v3.beccheggio = float(x[2])
		v3.distanza = float(x[3])
		await aspetta(15)
		root.get_viewport().get_texture().get_image().save_png("%s/det_%s_%d.png" % [dir, tag, k])
		k += 1
	quit()
