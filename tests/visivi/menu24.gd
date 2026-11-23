extends SceneTree
## Scatti del menu delle missioni (anche espansioni). Uso: -- larghezza altezza cartella missione
var ui
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	DisplayServer.window_set_size(Vector2i(int(a[0]), int(a[1])))
	ui = (load("res://scene/principale.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	_vai(a[2], int(a[3]), "%sx%s" % [a[0], a[1]])
func _vai(dir: String, n: int, tag: String) -> void:
	for i in 40: await process_frame
	ui._mostra_missione_scelta(n)
	for i in 30: await process_frame
	var sc = ui._elenco_missioni.get_parent()
	if sc is ScrollContainer and n > 12:
		sc.scroll_vertical = 100000
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/menu_%d_%s.png" % [dir, n, tag])
	quit()
