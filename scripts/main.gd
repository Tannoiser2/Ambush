extends Control
const Game = preload("res://scripts/game.gd")
const Board = preload("res://scripts/board.gd")
const BODY_FONT = preload("res://assets/fonts/Barlow-Regular.ttf")
const TITLE_FONT = preload("res://assets/fonts/SpecialElite-Regular.ttf")
const SAVE_PATH := "user://ambush_mission_01.json"
var game := Game.new()
var board: AmbushBoard
var selected := "A"
var move_as_group := false
var roster: VBoxContainer
var diary: RichTextLabel
var objectives: RichTextLabel
var details: RichTextLabel
var status_label: Label
var phase_label: Label
var condition_label: Label
var hover_label: Label
var progress_label: Label
var stances: Array[Button] = []
var notice := ""

func _ready() -> void:
	build_theme()
	build_ui()
	game.changed.connect(refresh)
	game.new_game()
	if FileAccess.file_exists(SAVE_PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if game.restore(saved): notice="Partita precedente ripristinata automaticamente."
	refresh()
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tmp/preview.png")
		get_tree().quit()

func style(color: String, border: String="", radius: int=4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new();s.bg_color=Color(color)
	s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=10;s.content_margin_bottom=10
	s.set_corner_radius_all(radius)
	if border != "": s.border_color=Color(border);s.set_border_width_all(1)
	return s

func build_theme() -> void:
	var t := Theme.new();t.default_font=BODY_FONT;t.default_font_size=17
	t.set_color("font_color","Label",Color("e6dfc9"))
	t.set_color("default_color","RichTextLabel",Color("e6dfc9"))
	t.set_stylebox("normal","Button",style("303b2e","4a5642"))
	t.set_stylebox("hover","Button",style("46543a","9b9a64"))
	t.set_stylebox("pressed","Button",style("66704b","d0b87c"))
	t.set_stylebox("focus","Button",style("46543a","d0b87c"))
	t.set_color("font_color","Button",Color("ece5cf"))
	t.set_color("font_pressed_color","Button",Color("fff2ce"))
	t.set_stylebox("panel","PanelContainer",style("20281f","384332"))
	t.set_stylebox("normal","LineEdit",style("111a14","617050"))
	t.set_color("font_color","LineEdit",Color("f4e9cb"))
	t.set_stylebox("panel","AcceptDialog",style("20281f","b0a175"))
	theme=t

func label(text: String, font_size:=17, title:=false) -> Label:
	var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",font_size)
	if title:l.add_theme_font_override("font",TITLE_FONT)
	return l

func button(text: String, callback: Callable) -> Button:
	var b:=Button.new();b.text=text;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;b.pressed.connect(callback);return b

func rich(text: String="") -> RichTextLabel:
	var r:=RichTextLabel.new();r.bbcode_enabled=true;r.text=text;r.selection_enabled=true;r.scroll_following=true;r.size_flags_vertical=Control.SIZE_EXPAND_FILL;return r

func box(parent: Node, vertical:=true) -> BoxContainer:
	var b: BoxContainer=VBoxContainer.new() if vertical else HBoxContainer.new();b.add_theme_constant_override("separation",12);parent.add_child(b);return b

func build_ui() -> void:
	var bg:=ColorRect.new();bg.color=Color("141b15");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
	add_child(margin)
	var root:=box(margin)
	var header:=box(root,false)
	var brand:=box(header);brand.add_child(label("AMBUSH!",42,true));brand.add_child(label("VICTORY GAMES  /  EDIZIONE DIGITALE ITALIANA",12))
	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(spacer)
	var mission_info:=box(header);mission_info.add_child(label("01  /  SANGUE A SAINT-MICHAUX",23,true));mission_info.add_child(label("NORMANDIA  ·  FINE GIUGNO 1944",14))
	var tools:=box(root,false)
	phase_label=label("OPERAZIONI",17,true);tools.add_child(phase_label)
	condition_label=label("CONDIZIONE 1",15);tools.add_child(condition_label)
	progress_label=label("0 / 13 PV",15);tools.add_child(progress_label)
	var flexible:=Control.new();flexible.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tools.add_child(flexible)
	tools.add_child(button("Briefing",show_briefing));tools.add_child(button("Salva",save_game));tools.add_child(button("Carica",load_game));tools.add_child(button("Nuova missione",confirm_new))
	var body:=box(root,false);body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var left_panel:=PanelContainer.new();left_panel.custom_minimum_size.x=226;body.add_child(left_panel)
	var left:=box(left_panel);left.add_theme_constant_override("separation",6);left.add_child(label("LA TUA SQUADRA",19,true));left.add_child(label("Seleziona un soldato · A–H",14))
	roster=VBoxContainer.new();roster.add_theme_constant_override("separation",3);left.add_child(roster)
	details=rich();details.custom_minimum_size.y=88;details.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;left.add_child(details)
	left.add_child(button("Gruppo: attiva/disattiva",func(): move_as_group = not move_as_group; refresh()))
	left.add_child(label("POSTURA",13))
	var stance_row:=box(left,false);stance_row.add_theme_constant_override("separation",4)
	for pair in [["In piedi","standing"],["Basso","crouching"],["Prono","prone"]]:
		var value: String=pair[1]
		var b:=button(pair[0],func(): send_command({"type":"stance","soldier":selected,"stance":value}));b.toggle_mode=true;b.add_theme_font_size_override("font_size",14);stance_row.add_child(b);stances.append(b)
	left.add_child(button("Ritira dal margine nord",func(): send_command({"type":"exit","soldier":selected})))
	var center:=box(body);center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var mapbar:=box(center,false);mapbar.add_child(label("CARTA A  /  SETTORE SAINT-MICHAUX",14))
	var stretch:=Control.new();stretch.size_flags_horizontal=Control.SIZE_EXPAND_FILL;mapbar.add_child(stretch)
	mapbar.add_child(button("−",func(): board.zoom_at(board.size/2,1/1.2)));mapbar.add_child(button("+",func(): board.zoom_at(board.size/2,1.2)));mapbar.add_child(button("Centra",func(): board.reset_view()))
	board=Board.new();board.game=game;board.size_flags_vertical=Control.SIZE_EXPAND_FILL;board.size_flags_horizontal=Control.SIZE_EXPAND_FILL;board.custom_minimum_size=Vector2(430,400);center.add_child(board)
	board.hex_clicked.connect(func(id): move_to_hex(id))
	board.hover_changed.connect(func(id): hover_label.text="ESAGONO "+id if id!="" else "Rotella: zoom · tasto destro: sposta la carta")
	hover_label=label("Rotella: zoom · tasto destro: sposta la carta",14);center.add_child(hover_label)
	var right_panel:=PanelContainer.new();right_panel.custom_minimum_size.x=342;body.add_child(right_panel)
	var right:=box(right_panel);right.add_child(label("DIARIO OPERATIVO",22,true));right.add_child(label("PARAGRAFI · DADI · CONDIZIONI",12))
	objectives=rich();objectives.custom_minimum_size.y=154;objectives.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;right.add_child(objectives)
	diary=rich();diary.custom_minimum_size.x=310;right.add_child(diary)
	var footer:=box(root,false)
	status_label=label("",15);status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;footer.add_child(status_label)
	root.add_child(label("VERSIONE DI SVILUPPO 0.3 · Operazioni e Condizioni 1–4. Il combattimento è ancora in costruzione.",13))

func refresh() -> void:
	if not is_instance_valid(roster) or game.state.is_empty():return
	for child in roster.get_children():roster.remove_child(child);child.queue_free()
	for u in game.state.squad:
		if u.id=="K":continue
		var id: String=u.id
		var location: String=u.hex if u.hex!="" else "RISERVA"
		if u.status=="exited":location="RITIRATO"
		var b:=button("%s   %s   ·   %s" % [id,u.name,location],func(): selected=id;refresh())
		b.toggle_mode=true;b.button_pressed=id==selected;b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.custom_minimum_size.y=31
		b.add_theme_font_size_override("font_size",16);roster.add_child(b)
	var u:=game.soldier(selected)
	details.text="[color=#d4ba7a]%s[/color]\nIN %d   PC %d   AT %d\n%s\n%d caricatori · %d granate\n%s" % ["COMANDANTE" if u.commander else "FANTE",u.initiative,u.pc,u.ws,u.weapon,u.clips,u.grenades,u.extra]
	for i in stances.size():stances[i].button_pressed=u.stance==["standing","crouching","prone"][i]
	phase_label.text={"operations":"OPERAZIONI","rounds":"CONTATTO NEMICO","ended":"MISSIONE TERMINATA"}.get(game.state.phase,"PAUSA")
	condition_label.text="CONDIZIONE %d" % game.state.condition
	progress_label.text="%d / 13 PV" % game.state.vp
	var lines: Array[String]=[]
	for entry in game.state.log:
		var color: String={"paragraph":"e7c884","dice":"a8c49b","check":"93b9b0","blocked":"e5a18b","briefing":"e7c884"}.get(entry.kind,"b4bba5")
		lines.append("[color=#%s][b]%s[/b][/color]\n%s\n" % [color,escape_bbcode(entry.title),escape_bbcode(entry.text)])
	var objective_lines: Array[String]=["[b][color=#e7c884]OBIETTIVI DI MISSIONE[/color][/b]"]
	for item in game.objective_status():
		objective_lines.append(("[color=#9bc897]✓[/color] " if item.met else "[color=#d4b474]○[/color] " if item.known else "[color=#b7a795]?[/color] ")+item.title)
	objectives.text="\n".join(objective_lines)
	diary.text="\n".join(lines)
	status_label.text=notice if notice!="" else (game.state.blocked if game.state.blocked!="" else "%s selezionato. %s%s" % [u.name,"Entra da A1–J1." if u.hex=="" else "Scegli un esagono adiacente evidenziato."," Gruppo attivo." if move_as_group else ""])
	board.selected=selected;board.queue_redraw()

func escape_bbcode(value: String) -> String:
	return value.replace("[","[lb]")

func move_to_hex(hex_id: String) -> void:
	if move_as_group:
		var leader := game.soldier(selected)
		var ids: Array[String] = []
		for unit in game.state.squad:
			if unit.status == "active" and unit.hex == leader.hex and unit.stance == leader.stance: ids.append(unit.id)
		send_command({"type":"move_group","soldier":selected,"group":ids,"hex":hex_id})
	else:
		send_command({"type":"move","soldier":selected,"hex":hex_id})

func send_command(command: Dictionary) -> void:
	notice=""
	var result:=game.dispatch(command)
	if not result.ok:notice=result.error
	else:write_save()
	refresh()

func write_save() -> bool:
	var temp:=SAVE_PATH+".tmp"
	var file:=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(game.snapshot()));file.close()
	return DirAccess.rename_absolute(temp,SAVE_PATH)==OK

func save_game() -> void:
	notice="Partita salvata sul dispositivo." if write_save() else "Salvataggio non riuscito: controlla lo spazio disponibile.";refresh()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):notice="Non c’è ancora un salvataggio su questo dispositivo.";refresh();return
	var data=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	notice="Partita ripristinata." if game.restore(data) else "Salvataggio non valido o di una versione diversa; partita attuale conservata.";refresh()

func confirm_new() -> void:
	var dialog:=ConfirmationDialog.new();dialog.title="Nuova missione";dialog.dialog_text="Ricominciare Saint-Michaux? Il salvataggio automatico corrente verrà sostituito.";dialog.ok_button_text="Ricomincia";dialog.cancel_button_text="Annulla";add_child(dialog)
	dialog.confirmed.connect(func():notice="";game.new_game();write_save();dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(480,160))

func show_briefing() -> void:
	var popup:=AcceptDialog.new();popup.title="Ordine di operazione · Missione 1";popup.ok_button_text="Torna alla carta";add_child(popup)
	var text:=rich();text.custom_minimum_size=Vector2(600,440);text.scroll_following=false;popup.add_child(text)
	text.text="[font_size=28][color=#e7c884]Sangue a Saint-Michaux[/color][/font_size]\n\n"+game.mission.briefing+"\n\n[b]INGRESSO[/b]\nMappa A, margine nord: A1–J1. Il corso d’acqua è un ruscello.\n\n[b]OBIETTIVO ORIGINALE[/b]\nServono 13 PV. Controlla l’edificio T8, gli esagoni K13 e L13 e un’altura a sud-est che permetta di vedere tutti gli esagoni stradali, senza tedeschi attivi sulla mappa: questo finale assegna 4 PV aggiuntivi. In alternativa, ritira tutti i soldati attivi da A1–J1.\n\n[b]STATO DI QUESTA VERSIONE[/b]\nIngresso, movimento singolo o di gruppo in Operazioni, posture, riferimenti neri delle quattro carte Condizione, controlli e catene di paragrafi supportati. I campi minati sono segnati sulla carta; se una mina esplode, il calcolo dei danni resta sospeso. Al combattimento o a un’istruzione non verificata il motore si ferma e conserva lo stato. Linea di vista, danni e vittoria completa non sono ancora automatizzati.\n\n[b]COMANDI[/b]\nClicca un soldato, poi un esagono verde. Rotella per ingrandire; trascina con il tasto destro per spostare la mappa. Salvataggio automatico dopo ogni azione locale."
	popup.confirmed.connect(popup.queue_free);popup.canceled.connect(popup.queue_free);popup.popup_centered(Vector2i(650,500))

