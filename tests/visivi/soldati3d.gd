extends SceneTree
## Scatti delle miniature nella vista 3D. Uso: ... --script tests/visivi/soldati3d.gd -- L H cartella
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) if args.size() > 0 else 1600
	var h := int(args[1]) if args.size() > 1 else 1000
	var dir := args[2] if args.size() > 2 else "/tmp"
	DisplayServer.window_set_size(Vector2i(w, h))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_scatti(dir, "%dx%d" % [w, h])

func aspetta(k := 20) -> void:
	for i in k:
		await process_frame

func _scatti(dir: String, tag: String) -> void:
	await aspetta(20)
	ui._pref_grafica["3d"] = true
	ui._avvia_missione(1, false, false)
	await aspetta(5)
	var p = ui.p
	var posti := ["D2", "D2", "D2", "E2", "E2", "C2", "C2", "C3"]
	var i := 0
	for a in p.americani():
		p.schiera([a.id], "A1")
		i += 1
	p.inizia_missione()
	i = 0
	for a in p.americani():
		a.hex = posti[i]
		i += 1
	p.u("B").postura = "crouching"
	p.u("C").postura = "prone"
	p.u("E").postura = "crouching"
	p.u("F").ferito = true
	p.u("G").stato = "incapacitato"
	var hex_de := ["F4", "F4", "G3", "H4", "G5", "E5"]
	var posture_de := ["standing", "crouching", "standing", "prone", "standing", "crouching"]
	var numeri: Array = p.missione.tedeschi.keys()
	var tedeschi: Array = []
	for k in mini(numeri.size(), hex_de.size()):
		tedeschi.append(p._crea_tedesco(int(numeri[k]), hex_de[k], posture_de[k]))
	if tedeschi.size() > 5:
		tedeschi[5].stato = "morto"
	ui.selezione = ["A"]
	ui._aggiorna_tutto(true)
	var v3 = ui.mappa.vista3d
	v3.bersaglio = v3.centro3d("E3")
	v3.imbardata = 0.4
	v3.beccheggio = 38.0
	v3.distanza = 5.5
	await aspetta(30)
	root.get_viewport().get_texture().get_image().save_png("%s/sold_%s_a.png" % [dir, tag])
	v3.imbardata = 2.6
	v3.beccheggio = 30.0
	v3.distanza = 4.0
	v3.bersaglio = v3.centro3d("F4")
	await aspetta(20)
	root.get_viewport().get_texture().get_image().save_png("%s/sold_%s_b.png" % [dir, tag])
	print("tedeschi: ", tedeschi.slice(0, 6).map(func(x): return "%s %s %s" % [x.lettera, str(x.armi), v3.modello_per(x)]))
	quit()
