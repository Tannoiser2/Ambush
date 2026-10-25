extends Control
const Game = preload("res://scripts/game.gd")
const Board = preload("res://scripts/board.gd")
const Hex = preload("res://scripts/hex_grid.gd")
const RoundRules = preload("res://scripts/round_rules.gd")
const BODY_FONT = preload("res://assets/fonts/Barlow-Regular.ttf")
const TITLE_FONT = preload("res://assets/fonts/SpecialElite-Regular.ttf")
const SAVE_PATH := "user://ambush_mission_01.json"
var game := Game.new()
var board: AmbushBoard
var selected := "A"
var selected_ids: Array[String] = ["A"]
var drag_target := ""
var terrain_review_mode := false
var terrain_button: Button
var terrain_legend: Label
var terrain_editor: HFlowContainer
var terrain_brush: OptionButton
var level_brush: OptionButton
var feature_brush: OptionButton
var side_brush: OptionButton
var side_direction: OptionButton
var selection_label: Label
var map_save_label: Label
var edit_hexes: Array[String] = []
const MAP_REVIEW_PATH := "user://ambush_map_a_reviews.json"
var counter_icons: Dictionary = {}
var action_buttons: Dictionary = {}
var roster: VBoxContainer
var drag_options: VBoxContainer
var exit_drag_button: Button
var pilot_button: Button
var begin_round_button: Button
var next_round_button: Button
var pass_button: Button
var finish_move_button: Button
var fire_options: VBoxContainer
var diary: RichTextLabel
var objectives: RichTextLabel
var details: RichTextLabel
var status_label: Label
var phase_label: Label
var condition_label: Label
var hover_label: Label
var progress_label: Label
var stances: Array[Button] = []
var drop_buttons: Array[Button] = []
var notice := ""

func _ready() -> void:
	for id in ["A","B","C","D","E","F","G","H","J","K"]:
		counter_icons[id] = load("res://assets/counters/us_%s.png" % id)
	build_theme()
	build_ui()
	game.changed.connect(refresh)
	game.new_game()
	load_map_reviews()
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
	var left:=box(left_panel);left.add_theme_constant_override("separation",6);left.add_child(label("LA TUA SQUADRA",19,true));left.add_child(label("Pedine selezionate: clic per includere/escludere",13))
	var roster_scroll:=ScrollContainer.new();roster_scroll.custom_minimum_size.y=210;roster_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;left.add_child(roster_scroll)
	roster=VBoxContainer.new();roster.add_theme_constant_override("separation",3);roster_scroll.add_child(roster)
	details=rich();details.custom_minimum_size.y=88;details.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;left.add_child(details)
	left.add_child(label("POSTURA",13))
	var stance_row:=box(left,false);stance_row.add_theme_constant_override("separation",4)
	for pair in [["In piedi","standing"],["Basso","crouching"],["Prono","prone"]]:
		var value: String=pair[1]
		var b:=button(pair[0],func(): send_command({"type":"round_stance" if game.state.phase=="rounds" else "stance","soldier":selected,"stance":value}));b.toggle_mode=true;b.add_theme_font_size_override("font_size",14);stance_row.add_child(b);stances.append(b)
	for i in 2:
		var drop_button := button("",Callable(self,"choose_drop").bind(i))
		drop_button.visible = false
		left.add_child(drop_button)
		drop_buttons.append(drop_button)
	left.add_child(label("AZIONI · REGOLE 5/3",13))
	for pair in [["move","Muovi · clic sulla carta"],["equipment","Equipaggiamento"],["prepare","Prepara arma"],["clear_jam","Disinceppa arma"],["captured","Muovi prigioniero"]]:
		var action_button := button(pair[1],func(): pass)
		action_button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		left.add_child(action_button)
		action_buttons[pair[0]]=action_button
	drag_options=VBoxContainer.new();left.add_child(drag_options)
	exit_drag_button=button("Evacua con il ferito",func(): send_command({"type":"exit_drag","soldier":selected,"casualty":drag_target}))
	exit_drag_button.visible=false;left.add_child(exit_drag_button)
	pilot_button=button("Soccorri il pilota",func(): send_command({"type":"rescue_pilot","soldier":selected}))
	pilot_button.visible=false;left.add_child(pilot_button)
	begin_round_button=button("Prepara il Round",func(): send_command({"type":"begin_round"}))
	begin_round_button.visible=false;left.add_child(begin_round_button)
	next_round_button=button("Round successivo",func(): send_command({"type":"next_round"}))
	next_round_button.visible=false;left.add_child(next_round_button)
	pass_button=button("Passa il turno",func(): send_command({"type":"round_pass","soldier":selected}))
	pass_button.visible=false;left.add_child(pass_button)
	finish_move_button=button("Termina movimento",func(): send_command({"type":"round_move_finish","soldier":selected}))
	finish_move_button.visible=false;left.add_child(finish_move_button)
	fire_options=VBoxContainer.new();left.add_child(fire_options)
	left.add_child(button("Ritira dal margine nord",func(): send_command({"type":"exit","soldier":selected})))
	var center:=box(body);center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var mapbar:=box(center,false);mapbar.add_child(label("CARTA A  /  SETTORE SAINT-MICHAUX",14))
	var stretch:=Control.new();stretch.size_flags_horizontal=Control.SIZE_EXPAND_FILL;mapbar.add_child(stretch)
	mapbar.add_child(button("−",func(): board.zoom_at(board.size/2,1/1.2)));mapbar.add_child(button("+",func(): board.zoom_at(board.size/2,1.2)));mapbar.add_child(button("Centra",func(): board.reset_view()))
	terrain_button=button("Mappa semplificata",func(): terrain_review_mode=not terrain_review_mode;refresh())
	terrain_button.toggle_mode=true;mapbar.add_child(terrain_button)
	board=Board.new();board.game=game;board.size_flags_vertical=Control.SIZE_EXPAND_FILL;board.size_flags_horizontal=Control.SIZE_EXPAND_FILL;board.custom_minimum_size=Vector2(430,400);center.add_child(board)
	board.hex_clicked.connect(handle_map_click)
	board.hover_changed.connect(show_hover)
	terrain_legend=label("VERDE verificato · OCRA stimato · ROSSO quota assente. Seleziona un esagono e una direzione: il lato interessato viene evidenziato in turchese. D porta · W finestra · C cresta · S scarpata.",13)
	terrain_legend.visible=false;terrain_legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;center.add_child(terrain_legend)
	terrain_editor=HFlowContainer.new();terrain_editor.visible=false;terrain_editor.custom_minimum_size.y=84;center.add_child(terrain_editor)
	selection_label=label("Nessun esagono selezionato",13);terrain_editor.add_child(selection_label)
	map_save_label=label("Mappa salvata sul dispositivo",12);terrain_editor.add_child(map_save_label)
	terrain_brush=OptionButton.new()
	for item in [["Lascia invariato",""],["Aperto","clear"],["Bosco","woods"],["Macchia","brush"],["Terreno difficile","rough"],["Copertura","cover"],["Strada","road"],["Ruscello","stream"],["Edificio in legno","wood_building"],["Edificio in pietra","stone_building"],["Ponte in legno","wood_bridge"],["Ponte in pietra","stone_bridge"],["Ferrovia","railroad"],["Crateri","crater"],["Macerie","rubble"]]:terrain_brush.add_item(item[0]);terrain_brush.set_item_metadata(terrain_brush.item_count-1,item[1])
	terrain_editor.add_child(terrain_brush)
	feature_brush=OptionButton.new()
	for item in [["Edificio invariato",""],["Rimuovi edificio","none"],["Edificio in legno","wood"],["Edificio in pietra","stone"],["Secondo piano","second_story"]]:feature_brush.add_item(item[0]);feature_brush.set_item_metadata(feature_brush.item_count-1,item[1])
	terrain_editor.add_child(feature_brush)
	level_brush=OptionButton.new()
	for item in [["Quota invariata",-99],["Livello 1",1],["Livello 2",2],["Livello 3",3]]:level_brush.add_item(item[0]);level_brush.set_item_metadata(level_brush.item_count-1,item[1])
	terrain_editor.add_child(level_brush)
	side_brush=OptionButton.new()
	for item in [["Lato invariato",""],["Lato normale","none"],["Cresta","crest"],["Scarpata","embankment"],["Porta","door"],["Finestra","window"]]:side_brush.add_item(item[0]);side_brush.set_item_metadata(side_brush.item_count-1,item[1])
	terrain_editor.add_child(side_brush)
	side_direction=OptionButton.new()
	for direction_name in ["SE","NE","N","NW","SW","S"]:side_direction.add_item(direction_name)
	side_direction.item_selected.connect(func(_index:int):refresh())
	terrain_editor.add_child(side_direction)
	terrain_editor.add_child(button("Applica a selezione",apply_map_brush))
	terrain_editor.add_child(button("Salva mappa",save_map_reviews))
	terrain_editor.add_child(button("Deseleziona",func():edit_hexes.clear();refresh()))
	hover_label=label("Rotella: zoom · tasto destro: sposta la carta",14)
	hover_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hover_label.custom_minimum_size.y=44
	center.add_child(hover_label)
	var right_panel:=PanelContainer.new();right_panel.custom_minimum_size.x=342;body.add_child(right_panel)
	var right:=box(right_panel);right.add_child(label("DIARIO OPERATIVO",22,true));right.add_child(label("PARAGRAFI · DADI · CONDIZIONI",12))
	objectives=rich();objectives.custom_minimum_size.y=154;objectives.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;right.add_child(objectives)
	diary=rich();diary.custom_minimum_size.x=310;right.add_child(diary)
	var footer:=box(root,false)
	status_label=label("",15);status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;footer.add_child(status_label)
	root.add_child(label("VERSIONE DI SVILUPPO 0.3 · Operazioni e Condizioni 1–4. Il combattimento è ancora in costruzione.",13))

func refresh() -> void:
	if not is_instance_valid(roster) or game.state.is_empty():return
	if game.state.phase=="rounds" and selected_ids.size()>1:
		selected_ids.clear();selected_ids.append(selected)
	for child in roster.get_children():roster.remove_child(child);child.queue_free()
	var stacks: Dictionary = {}
	for unit in game.state.squad:
		var location: String=str(unit.hex) if unit.hex!="" else "RISERVA"
		if unit.status=="exited":location="RITIRATI"
		elif unit.status=="killed":location="CADUTI"
		if not stacks.has(location):stacks[location]=[]
		stacks[location].append(unit)
	var locations: Array=stacks.keys()
	locations.sort()
	for location in locations:
		roster.add_child(label("ESAGONO " + str(location) if location not in ["RISERVA","RITIRATI","CADUTI"] else str(location),13))
		var row:=HFlowContainer.new();row.custom_minimum_size.x=194;row.add_theme_constant_override("h_separation",3);row.add_theme_constant_override("v_separation",3);roster.add_child(row)
		for unit in stacks[location]:
			var id: String=str(unit.id)
			var b:=button("",Callable(self,"toggle_soldier").bind(id))
			b.icon=counter_icons.get(id)
			b.expand_icon=true
			b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
			b.custom_minimum_size=Vector2(42,46)
			b.toggle_mode=true;b.button_pressed=id in selected_ids
			b.tooltip_text="%s · %s · %s" % [unit.name,unit.stance,unit.status]
			row.add_child(b)
	if game.soldier(selected).is_empty():selected="A";selected_ids=["A"]
	var u:=game.soldier(selected)
	action_buttons.move.disabled=game.state.phase!="operations" or game.state.blocked!="" or u.status!="active" or u.stance=="prone" or not stack_is_legal()
	action_buttons.move.tooltip_text="Seleziona le pedine nello stesso esagono e con la stessa postura, poi clicca un esagono adiacente."
	for key in ["equipment","prepare","clear_jam","captured"]:
		action_buttons[key].disabled=true
		action_buttons[key].tooltip_text="Azione della regola 5/3 non ancora automatizzata."
	action_buttons.equipment.tooltip_text="Raccogli, posa o scambia equipaggiamento: non ancora automatizzato."
	details.text="[color=#d4ba7a]%s[/color]\nIN %d   PC %d   AT %d\n%s\n%d caricatori · %d granate\n%s%s" % ["COMANDANTE" if u.commander else "FANTE",u.initiative,u.pc,u.ws,u.weapon,u.clips,u.grenades,u.extra,"\nFERITO · movimento 2" if u.wounded else ""]
	for i in stances.size():
		stances[i].button_pressed=u.stance==["standing","crouching","prone"][i]
		var can_change: bool=game.state.phase=="operations"
		if game.state.phase=="rounds" and game.state.blocked=="" and game.state.get("round_movement",{}).is_empty() and not game.state.get("round_track",{}).is_empty() and not u.wounded:
			var bucket: Dictionary=RoundRules.current_turn_bucket(game.state.round_track)
			can_change=not bucket.is_empty() and bucket.side=="us" and selected in bucket.ids and not bool(game.state.round_track.get("free_stance_used",{}).get(selected,false))
		stances[i].disabled=not can_change
	var pending: String = game.state.pending_drop
	var pending_unit: Dictionary = game.soldier(pending) if pending != "" else {}
	for i in drop_buttons.size():
		drop_buttons[i].visible = not pending_unit.is_empty() and pending_unit.port_boxes[i] != ""
		if drop_buttons[i].visible: drop_buttons[i].text = "Lascia: " + pending_unit.port_boxes[i]
	for child in drag_options.get_children():drag_options.remove_child(child);child.queue_free()
	var eligible: bool = u.status == "active" and u.stance == "standing" and u.hex != "" and "" in u.port_boxes
	if eligible:
		for casualty in game.state.squad:
			if casualty.id == u.id or casualty.hex != u.hex or casualty.status not in ["incapacitated","killed"]:continue
			var casualty_id: String = casualty.id
			var drag_button:=button("Trascina: " + casualty.name,func():drag_target="" if drag_target==casualty_id else casualty_id;refresh())
			drag_button.toggle_mode=true;drag_button.button_pressed=drag_target==casualty_id
			drag_options.add_child(drag_button)
	if drag_target != "" and (not eligible or game.soldier(drag_target).hex != u.hex):drag_target=""
	exit_drag_button.visible=drag_target != "" and Hex.is_entry(u.hex)
	pilot_button.visible=game.state.pilot_found and game.state.landmarks.has("R15") and game.soldier("J").is_empty() and u.status=="active" and not u.wounded and u.hex=="R15" and game.state.blocked==""
	begin_round_button.visible=game.state.phase=="rounds" and game.state.get("round_track",{}).is_empty() and (game.state.blocked=="" or str(game.state.blocked).begins_with("Contatto nemico registrato"))
	next_round_button.visible=game.state.phase=="rounds" and str(game.state.blocked).begins_with("Round %d concluso" % game.state.round_setup.get("number",0))
	pass_button.visible=false
	finish_move_button.visible=game.state.phase=="rounds" and game.state.blocked=="" and not game.state.get("round_movement",{}).is_empty() and str(game.state.round_movement.soldier)==selected
	if game.state.phase=="rounds" and game.state.blocked=="" and not game.state.get("round_track",{}).is_empty():
		var bucket: Dictionary=RoundRules.current_turn_bucket(game.state.round_track)
		pass_button.visible=game.state.get("round_movement",{}).is_empty() and not bucket.is_empty() and bucket.side=="us" and selected in bucket.ids
	for child in fire_options.get_children():fire_options.remove_child(child);child.queue_free()
	if game.state.phase=="rounds" and game.state.blocked=="":
		for enemy in game.state.enemies:
			if enemy.get("status","active")!="active":continue
			var enemy_id: String=str(enemy.id)
			var command: Dictionary={"type":"round_fire","soldier":selected,"enemy":enemy_id}
			if game.validate_command(command)=="":
				fire_options.add_child(button("Tiro mirato → GE "+enemy_id,func():send_command(command)))
	phase_label.text={"operations":"OPERAZIONI","rounds":"CONTATTO NEMICO","ended":"MISSIONE TERMINATA"}.get(game.state.phase,"PAUSA")
	condition_label.text="CONDIZIONE %d" % game.state.condition
	progress_label.text="%d / 13 PV" % game.net_vp()
	var lines: Array[String]=[]
	for entry in game.state.log:
		var color: String={"paragraph":"e7c884","dice":"a8c49b","check":"93b9b0","blocked":"e5a18b","briefing":"e7c884"}.get(entry.kind,"b4bba5")
		lines.append("[color=#%s][b]%s[/b][/color]\n%s\n" % [color,escape_bbcode(entry.title),escape_bbcode(entry.text)])
	var objective_lines: Array[String]=["[b][color=#e7c884]OBIETTIVI DI MISSIONE[/color][/b]"]
	for item in game.objective_status():
		objective_lines.append(("[color=#9bc897]OK[/color] " if item.met else "[color=#d4b474]--[/color] " if item.known else "[color=#b7a795]??[/color] ")+item.title)
	objectives.text="\n".join(objective_lines)
	diary.text="\n".join(lines)
	status_label.text=notice if notice!="" else (game.state.blocked if game.state.blocked!="" else "%s selezionati: %s. %s" % [str(selected_ids.size()),", ".join(selected_ids),"Entra da A1–J1." if u.hex=="" else "Scegli un esagono adiacente evidenziato."])
	if notice=="" and game.state.phase=="rounds" and game.state.blocked=="" and not game.state.get("round_movement",{}).is_empty():
		status_label.text="%s: %d/%d PM spesi. Scegli un altro esagono verde o termina il movimento." % [game.state.round_movement.soldier,int(game.state.round_movement.spent),int(game.soldier(str(game.state.round_movement.soldier)).get("mp",4))]
	terrain_button.button_pressed=terrain_review_mode;terrain_legend.visible=terrain_review_mode
	terrain_editor.visible=terrain_review_mode
	selection_label.text=map_selection_summary() if not edit_hexes.is_empty() else "Clicca gli esagoni da aggiungere · clicca di nuovo per rimuovere"
	board.selected=selected;board.selected_ids=selected_ids.duplicate();board.terrain_review_mode=terrain_review_mode;board.queue_redraw()
	board.edit_hexes=edit_hexes.duplicate()
	board.edit_side_origin=edit_hexes[0] if not edit_hexes.is_empty() else ""
	board.edit_side_direction=side_direction.selected if is_instance_valid(side_direction) else 0
	board.edit_side_kind=str(side_brush.get_item_metadata(side_brush.selected)) if is_instance_valid(side_brush) else ""

func stack_is_legal() -> bool:
	var leader: Dictionary=game.soldier(selected)
	if leader.is_empty():return false
	for id in selected_ids:
		var unit: Dictionary=game.soldier(id)
		if unit.is_empty() or unit.status!="active" or unit.hex!=leader.hex or unit.stance!=leader.stance:return false
	return not selected_ids.is_empty()

func toggle_soldier(id: String) -> void:
	var unit: Dictionary=game.soldier(id)
	var leader: Dictionary=game.soldier(selected)
	if id in selected_ids:
		if selected_ids.size()>1:selected_ids.erase(id);selected=selected_ids[0]
	else:
		if leader.is_empty() or unit.status!="active" or leader.status!="active" or unit.hex!=leader.hex or unit.stance!=leader.stance:selected_ids=[id]
		else:selected_ids.append(id)
		selected=id
	drag_target=""
	refresh()

func escape_bbcode(value: String) -> String:
	return value.replace("[","[lb]")

func show_hover(id: String) -> void:
	if id == "":
		hover_label.text = "Rotella: zoom · tasto destro: sposta la carta"
		hover_label.tooltip_text = ""
		return
	hover_label.text = "ESAGONO " + id
	hover_label.tooltip_text = "Classificazione del terreno ancora in revisione."
	var terrain: Dictionary = game.map_terrain_at(id)
	var terrain_names := {"clear":"aperto","woods":"bosco","brush":"macchia","cover":"copertura","road":"strada","stream":"corso d'acqua","stone_building":"edificio in pietra","wood_building":"edificio in legno","crater":"cratere","rubble":"macerie"}
	if not terrain.is_empty():
		hover_label.text += "  ·  terreno stimato: " + str(terrain_names.get(str(terrain.terrain),"da verificare"))
		hover_label.text += "  ·  quota " + (str(terrain.elevation) if terrain.elevation != null else "?")
		if terrain.get("building","")!="":hover_label.text += "  ·  edificio: " + ("legno" if terrain.building=="wood" else "pietra")
		if bool(terrain.get("second_story",false)):hover_label.text += "  ·  secondo piano"
		if terrain_review_mode:
			hover_label.text += "  ·  %s" % ("CLASSE VERIFICATA" if terrain.get("classification","")=="manual_visual_review" else "CLASSE DA VERIFICARE")
			if terrain.get("elevation")==null:hover_label.text += "  ·  QUOTA DA DEFINIRE"
			if bool(terrain.get("hexside_review_pending",false)):hover_label.text += "  ·  LATI DA VERIFICARE"
	var observer: Dictionary = game.soldier(selected)
	if not observer.is_empty() and observer.hex != "" and observer.hex != id:
		var los: Dictionary = game.map_los(str(observer.hex),id)
		var los_names := {"clear":"libera","blocked":"ostruita","unknown":"da verificare"}
		hover_label.text += "  ·  LOS preliminare da %s: %s" % [observer.hex,los_names.get(str(los.status),"da verificare")]
		hover_label.tooltip_text = str(los.reason)
	for enemy in game.state.enemies:
		if enemy.hex == id:
			hover_label.text += "  ·  TEDESCO %s / GE %s  ·  %s  ·  IN %d PC %d AT %+d  ·  %s" % [enemy.get("letter", "?"), enemy.id, enemy.get("role", ""), enemy.get("initiative", 0), enemy.get("pc", 0), enemy.get("ws", 0), enemy.get("status", "active")]
			if game.state.phase == "rounds" and enemy.get("status", "active") == "active":
				var shot: Dictionary = game.fire_preview(selected,str(enemy.id))
				if shot.status == "estimated":
					hover_label.text += "  ·  tiro mirato stimato: %d/10 (D10 0–%d)" % [int(shot.chance)+1,int(shot.chance)]
				else:
					hover_label.text += "  ·  tiro: %s" % {"blocked":"LOS ostruita", "unknown":"da verificare", "unavailable":"non disponibile"}.get(str(shot.status),"da verificare")
				hover_label.tooltip_text = str(shot.reason)

func handle_map_click(hex_id: String) -> void:
	if terrain_review_mode:
		if hex_id in edit_hexes:edit_hexes.erase(hex_id)
		else:edit_hexes.append(hex_id)
		edit_hexes.sort()
		refresh()
		return
	move_to_hex(hex_id)

func neighbor_id(id: String, direction: int) -> String:
	var directions: Array[Vector3i]=[Vector3i(1,0,-1),Vector3i(1,-1,0),Vector3i(0,-1,1),Vector3i(-1,0,1),Vector3i(-1,1,0),Vector3i(0,1,-1)]
	var cube: Vector3i=Hex.cube(id)+directions[posmod(direction,6)]
	var row: int=cube.y+(cube.x-(cube.x&1))/2+1
	return String.chr(65+cube.x)+str(row) if cube.x>=0 and cube.x<25 and row>=1 and row<=19 else ""

func map_edge_key(a: String,b: String) -> String:
	return a+"|"+b if a<b else b+"|"+a

func map_selection_summary() -> String:
	var terrains: Dictionary={}
	var elevations: Dictionary={}
	var buildings: Dictionary={}
	for id in edit_hexes:
		var record: Dictionary=game.map_terrain.data.hexes.get(id,{})
		var terrain:=str(record.get("terrain","?"))
		var elevation:=str(record.get("elevation","?"))
		var building:=str(record.get("building",""))
		terrains[terrain]=int(terrains.get(terrain,0))+1
		elevations[elevation]=int(elevations.get(elevation,0))+1
		if building!="":buildings[building]=int(buildings.get(building,0))+1
	var terrain_names: PackedStringArray=[]
	var elevation_names: PackedStringArray=[]
	var building_names: PackedStringArray=[]
	for key in terrains:terrain_names.append("%s (%d)" % [key,terrains[key]])
	for key in elevations:elevation_names.append("%s (%d)" % [key,elevations[key]])
	for key in buildings:building_names.append("%s (%d)" % [key,buildings[key]])
	var terrain_text:= ", ".join(terrain_names)
	var elevation_text:= ", ".join(elevation_names)
	var building_text:= ", ".join(building_names) if not building_names.is_empty() else "nessun edificio"
	return "%d esagoni [%s] · terreno: %s · quota: %s · %s" % [edit_hexes.size(),", ".join(edit_hexes),terrain_text,elevation_text,building_text]

func apply_map_brush() -> void:
	if edit_hexes.is_empty():return
	var terrain: String=str(terrain_brush.get_item_metadata(terrain_brush.selected))
	var feature: String=str(feature_brush.get_item_metadata(feature_brush.selected))
	var level: int=int(level_brush.get_item_metadata(level_brush.selected))
	var side: String=str(side_brush.get_item_metadata(side_brush.selected))
	for id in edit_hexes:
		var record: Dictionary=game.map_terrain.data.hexes[id].duplicate(true)
		if terrain!="":record.terrain=terrain
		if level!=-99:record.elevation=level
		if feature!="":
			if feature=="none":record.erase("building");record.erase("second_story")
			elif feature=="second_story":record.second_story=true
			else:record.building=feature
		if terrain!="" or level!=-99 or feature!="":record.classification="manual_visual_review"
		game.map_terrain.data.hexes[id]=record
		if side!="":
			var other:=neighbor_id(id,side_direction.selected)
			if other!="":game.map_terrain.data.hexsides[map_edge_key(id,other)]=side
	save_map_reviews()
	refresh()

func save_map_reviews() -> void:
	var edited_hexes: Dictionary={}
	var original: Dictionary=game.map_terrain.data
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_a_terrain.json"))
	for id in original.hexes:
		if original.hexes[id]!=source.hexes.get(id,{}):edited_hexes[id]=original.hexes[id]
	var edited_sides: Dictionary={}
	for edge in original.hexsides:
		if original.hexsides[edge]!=source.hexsides.get(edge,""):edited_sides[edge]=original.hexsides[edge]
	var file:=FileAccess.open(MAP_REVIEW_PATH,FileAccess.WRITE)
	if file==null:notice="Salvataggio mappa non riuscito.";refresh();return
	file.store_string(JSON.stringify({"hexes":edited_hexes,"hexsides":edited_sides},"\t"));file.close()
	map_save_label.text="Salvata · %d esagoni · %d lati" % [edited_hexes.size(),edited_sides.size()]
	notice="Revisione mappa salvata sul dispositivo.";refresh()

func load_map_reviews() -> void:
	if not FileAccess.file_exists(MAP_REVIEW_PATH):return
	var saved=JSON.parse_string(FileAccess.get_file_as_string(MAP_REVIEW_PATH))
	if not saved is Dictionary:return
	var saved_hexes: Variant=saved.get("hexes",{})
	var saved_sides: Variant=saved.get("hexsides",{})
	if saved_hexes is Dictionary:
		for id in saved_hexes:
			if game.map_terrain.data.hexes.has(id) and saved_hexes[id] is Dictionary:game.map_terrain.data.hexes[id]=saved_hexes[id]
	if saved_sides is Dictionary:
		for edge in saved_sides:
			if str(edge).split("|").size()==2 and saved_sides[edge] in ["none","door","window","crest","embankment"]:game.map_terrain.data.hexsides[edge]=saved_sides[edge]

func move_to_hex(hex_id: String) -> void:
	if game.state.phase == "rounds":
		send_command({"type":"round_move","soldier":selected,"hex":hex_id})
		return
	if game.state.phase != "operations":
		notice="Non è possibile muoversi in questa fase."
		refresh()
		return
	if drag_target != "":
		send_command({"type":"drag","soldier":selected,"casualty":drag_target,"hex":hex_id})
	elif selected_ids.size()>1:
		send_command({"type":"move_group","soldier":selected,"group":selected_ids.duplicate(),"hex":hex_id})
	else:
		send_command({"type":"move","soldier":selected,"hex":hex_id})

func send_command(command: Dictionary) -> void:
	notice=""
	var result:=game.dispatch(command)
	if not result.ok:notice=result.error
	else:write_save()
	refresh()

func choose_drop(index: int) -> void:
	send_command({"type":"drop_port","soldier":game.state.pending_drop,"index":index})

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
	text.text="[font_size=28][color=#e7c884]Sangue a Saint-Michaux[/color][/font_size]\n\n"+game.mission.briefing+"\n\n[b]INGRESSO[/b]\nMappa A, margine nord: A1–J1. Il corso d’acqua è un ruscello.\n\n[b]OBIETTIVO ORIGINALE[/b]\nServono 13 PV. Controlla l’edificio T8, gli esagoni K13 e L13 e un’altura a sud-est che permetta di vedere tutti gli esagoni stradali, senza tedeschi attivi sulla mappa: questo finale assegna 4 PV aggiuntivi. In alternativa, ritira tutti i soldati attivi da A1–J1.\n\n[b]STATO DI QUESTA VERSIONE[/b]\nIngresso, movimento singolo o di gruppo in Operazioni, posture, soccorso dei feriti, riferimenti neri delle quattro carte Condizione, controlli e catene di paragrafi supportati. Il motore applica le esplosioni delle mine e registra caratteristiche e PV dei tedeschi attivati. Nei Round sono disponibili iniziativa, postura, movimento americano e un primo tiro mirato verificato in M5. Altre LOS, combattimenti e condizioni di vittoria restano in sviluppo.\n\n[b]COMANDI[/b]\nClicca un soldato, poi un esagono verde. Per soccorrere un ferito, seleziona un fante in piedi con uno spazio di trasporto libero nello stesso esagono e premi «Trascina». Se trovi il pilota in R15, seleziona un soldato non ferito e premi «Soccorri il pilota». Rotella per ingrandire; trascina con il tasto destro per spostare la mappa. Salvataggio automatico dopo ogni azione locale."
	popup.confirmed.connect(popup.queue_free);popup.canceled.connect(popup.queue_free);popup.popup_centered(Vector2i(650,500))

