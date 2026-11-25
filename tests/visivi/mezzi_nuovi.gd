extends SceneTree
## Scatti 3D dei mezzi e degli oggetti nuovi: sidecar, Opel Blitz (tedesco e americano), semicingolato,
## cannone anticarro, chiatta, scialuppa, mortaio, cane, rampa a traliccio, radar, antenna, V-2,
## relitto d’aereo, mine e filo spinato; poi il treno e il faro.
## Uso: xvfb-run godot --path . --script tests/visivi/mezzi_nuovi.gd -- [larghezza] [altezza] [cartella]
var ui

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) if args.size() > 0 else 1400
	var h := int(args[1]) if args.size() > 1 else 900
	var dir := args[2] if args.size() > 2 else "/tmp"
	DisplayServer.window_set_size(Vector2i(w, h))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_scatti(dir, "%dx%d" % [w, h])

func aspetta(k := 20) -> void:
	for i in k:
		await process_frame

func foto(percorso: String) -> void:
	await aspetta(25)
	root.get_viewport().get_texture().get_image().save_png(percorso)
	print("scatto ", percorso)

func _veicolo(p, id: String, modello: String, lato: String, hx: String, fronte: int) -> void:
	if not p.s.has("veicoli"):
		p.s.veicoli = {}
	p.s.veicoli[id] = {"id": id, "nome": modello, "modello": modello, "lato": lato, "hex": hx, "stato": "attivo",
		"fronte": fronte, "occupanti": []}

func _scatti(dir: String, tag: String) -> void:
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
	_veicolo(p, "v1", "moto", "de", "F5", 1)
	_veicolo(p, "v2", "camion", "de", "G5", 1)
	_veicolo(p, "v3", "camion", "us", "H5", 1)
	_veicolo(p, "v4", "halftrack", "de", "F6", 1)
	_veicolo(p, "v5", "atg", "de", "G6", 1)
	_veicolo(p, "v6", "auto_comando", "de", "H6", 1)
	_veicolo(p, "v7", "chiatta", "us", "F7", 1)
	_veicolo(p, "v8", "scialuppa", "us", "G7", 1)
	p.s.ss = {"mortaio": {"hex": "H7", "pronto": true}}
	var nums: Array = p.missione.tedeschi.keys()
	var cane: Dictionary = p._crea_tedesco(int(nums[0]), "H7", "standing")
	cane.cane = true
	p.s.installazioni = {"J5": {"nome": "rampa", "pv": 2, "par": "", "distrutta": false},
		"J6": {"nome": "radar", "pv": 2, "par": "", "distrutta": false},
		"K5": {"nome": "antenna", "pv": 2, "par": "", "distrutta": false},
		"K6": {"nome": "v2", "pv": 2, "par": "", "distrutta": false}}
	p.s.punti["J8"] = "typhoon"
	p.s.mine_at = ["F8"]
	p.s.filo = ["G8"]
	ui.selezione = []
	ui._aggiorna_tutto(true)
	var v3 = ui.mappa.vista3d
	v3.imbardata = 0.5
	v3.beccheggio = 38.0
	v3.distanza = 5.0
	v3.bersaglio = v3.centro3d("G6")
	await foto("%s/mezzi_a_%s.png" % [dir, tag])
	v3.bersaglio = v3.centro3d("J6")
	v3.imbardata = -0.6
	await foto("%s/mezzi_b_%s.png" % [dir, tag])
	v3.bersaglio = v3.centro3d("G7")
	v3.imbardata = 2.6
	v3.distanza = 3.6
	await foto("%s/mezzi_c_%s.png" % [dir, tag])
	v3.bersaglio = v3.centro3d("F5")
	v3.imbardata = 1.2
	v3.beccheggio = 28.0
	v3.distanza = 1.6
	await foto("%s/mezzi_d_%s.png" % [dir, tag])
	v3.bersaglio = v3.centro3d("H7")
	v3.imbardata = 0.8
	await foto("%s/mezzi_e_%s.png" % [dir, tag])
	quit()
