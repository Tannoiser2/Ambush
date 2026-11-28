extends SceneTree
## Scatti dell'editor delle mappe. Uso: godot --path . --script tests/visivi/editor_mappe.gd -- L H cartella
## Nulla viene salvato: le prove usano le funzioni dell'editor senza chiudere un tratto.
const MappaScript = preload("res://scripts/ui/mappa.gd")
const DM = preload("res://scripts/motore/dati_mappe.gd")
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

func scatto(dir: String, nome: String) -> void:
	await aspetta(8)
	root.get_viewport().get_texture().get_image().save_png("%s/editor_%s.png" % [dir, nome])

func _c(h: String) -> Vector2:
	return MappaScript.centro_tex(h)

## Inquadra un punto della mappa al centro con uno zoom dato.
func _inquadra(ed, p: Vector2, z: float) -> void:
	ed.zoom = z
	ed.spostamento = ed.tela.size / 2.0 - p * z
	ed._limita()

func _scatti(dir: String, tag: String) -> void:
	await aspetta(20)
	ui._scegli_missione()
	await aspetta(10)
	await scatto(dir, tag + "_0menu")
	ui._apri_editor_mappe()
	await aspetta(10)
	var ed = ui.get_child(ui.get_child_count() - 1)
	ed.carica("a")
	await aspetta(5)
	# 1. selezione multipla nel modo Terreno
	ed._imposta_modo("terreno")
	ed.seleziona_esagoni(["J10", "K10", "K11", "L10", "L11", "M10", "M11", "J11"], "nuova")
	_inquadra(ed, _c("L11"), 0.42)
	await scatto(dir, tag + "_1selezione")
	# 2. quote: solo il numero
	ed._imposta_modo("quota")
	await scatto(dir, tag + "_2quote")
	# 3. muri curvi
	ed._sel_nessuno()
	ed._imposta_modo("curve")
	ed.attrezzo_curva = "modifica"
	ed.nuova_curva(_c("H13"), _c("M15"), "stonewall")
	ed.sposta_punto_curva(0, 1, _c("H13").lerp(_c("M15"), 0.33) + Vector2(0, -260))
	ed.sposta_punto_curva(0, 2, _c("H13").lerp(_c("M15"), 0.66) + Vector2(0, 240))
	ed._tavolozza()
	_inquadra(ed, _c("K14"), 0.4)
	await scatto(dir, tag + "_3muricurvi")
	# 4. gallerie (Missione 12)
	ed._imposta_modo("piani")
	ed.attrezzo_piani = "gallerie"
	ed._tavolozza()
	_inquadra(ed, _c("L10"), 0.26)
	await scatto(dir, tag + "_4gallerie")
	# 5. strati: mappa stampata attenuata, dati del motore pieni
	ed._imposta_modo("terreno")
	(ed._barra_strati.find_child("strato_mappa", true, false) as HSlider).value = 25
	await scatto(dir, tag + "_5strati")
	(ed._barra_strati.find_child("strato_mappa", true, false) as HSlider).value = 100
	(ed._barra_strati.find_child("strato_dati", true, false) as HSlider).value = 30
	await scatto(dir, tag + "_6strati_dati")
	(ed._barra_strati.find_child("strato_dati", true, false) as HSlider).value = 100
	# 7. edifici: stanza scelta con le maniglie e l'edificio del motore
	ed.carica("be")
	await aspetta(3)
	ed._imposta_modo("edifici")
	ed.stanza_sel = 3
	ed._tavolozza()
	var st: Dictionary = ed.d3.case[3]
	_inquadra(ed, _c(str(st.hex[0])), 0.4)
	await scatto(dir, tag + "_7edifici")
	# 8. piani: il campanile di S13 sulla mappa B
	ed.carica("b")
	await aspetta(3)
	ed._imposta_modo("piani")
	ed.attrezzo_piani = "piani"
	ed._piani_gallerie("S13")
	_inquadra(ed, _c("S13"), 0.45)
	await scatto(dir, tag + "_8piani")
	# 9. vista 3D: il campanile a due piani
	ed.bottone_3d.button_pressed = true
	ed._alterna_3d()
	await aspetta(30)
	ed.mappa3d_ctrl.vista3d.centra_su("S13")
	ed.mappa3d_ctrl.vista3d.distanza = 5.5
	await aspetta(30)
	await scatto(dir, tag + "_9vista3d")
	# 10. muretto curvo in 3D (salvato per la prova e poi cancellato)
	ed.bottone_3d.button_pressed = false
	ed._alterna_3d()
	ed.carica("a")
	ed._imposta_modo("curve")
	ed._inizia_tratto()
	ed.nuova_curva(_c("H13"), _c("M15"), "stonewall")
	ed.sposta_punto_curva(0, 1, _c("H13").lerp(_c("M15"), 0.33) + Vector2(0, -260))
	ed.sposta_punto_curva(0, 2, _c("H13").lerp(_c("M15"), 0.66) + Vector2(0, 240))
	ed._fine_tratto()
	ed.bottone_3d.button_pressed = true
	ed._alterna_3d()
	await aspetta(30)
	ed.mappa3d_ctrl.vista3d.centra_su("J14")
	ed.mappa3d_ctrl.vista3d.distanza = 7.0
	await aspetta(30)
	await scatto(dir, tag + "_10muro3d")
	DM.cancella("mappa_a")
	DM.cancella("mappa_a_3d")
	quit()
