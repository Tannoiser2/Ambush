class_name AmbushBoard
extends Control
signal hex_clicked(id: String)
signal hover_changed(id: String)
const Hex = preload("res://scripts/hex_grid.gd")
const RoundRules = preload("res://scripts/round_rules.gd")
var game: AmbushGame
var selected := "A"
var selected_ids: Array[String] = ["A"]
var terrain_review_mode := false
var edit_hexes: Array[String] = []
var edit_side_origin := ""
var edit_side_direction := 0
var edit_side_kind := ""
var grid_opacity := 0.32
var hovered := ""
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var texture: Texture2D = preload("res://assets/maps/map_a.jpg")
var font: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
var counters: Dictionary = {}
var rect := Rect2()
var scale_factor := 1.0

func _ready() -> void:
	for id in ["A","B","C","D","E","F","G","H","J","K"]:
		counters[id]=load("res://assets/counters/us_%s.png" % id)
	for id in ["L","N","P","Q","R","S","X"]:
		counters["GE_"+id]=load("res://assets/counters/ge_%s.png" % id)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): hovered=""; hover_changed.emit(""); queue_redraw())

func map_position(id: String) -> Vector2:
	return rect.position + Hex.center(id) * scale_factor

func polygon_at(id: String) -> PackedVector2Array:
	var center := map_position(id)
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(i*60.0)
		points.append(center + Vector2(cos(angle)*180.0, sin(angle)*181.0)*scale_factor)
	return points

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("222a22"))
	scale_factor = minf((size.x-24.0)/7000.0,(size.y-24.0)/6400.0)*zoom
	rect = Rect2((size-Vector2(7000,6400)*scale_factor)/2.0+pan,Vector2(7000,6400)*scale_factor)
	draw_texture_rect_region(texture, rect, Rect2(0,0,7000,6400),Color.WHITE if terrain_review_mode else Color(0.94,0.93,0.85))
	if game == null or game.state.is_empty(): return
	if terrain_review_mode:
		for hex_id in game.map_terrain.data.hexes:
			var record: Dictionary=game.map_terrain.data.hexes[hex_id]
			var reviewed: bool=record.get("classification","")=="manual_visual_review" and record.get("elevation")!=null and not bool(record.get("hexside_review_pending",false))
			var points:=polygon_at(str(hex_id))
			var fill:=Color("315743") if reviewed else Color("8b3c36") if record.get("elevation")==null else Color("897044")
			fill.a=grid_opacity
			draw_colored_polygon(points,fill)
			points.append(points[0]);draw_polyline(points,Color("e4dfc8",0.72),1.0,true)
			var pos:=map_position(str(hex_id))
			if zoom>1.2:draw_string(font,pos+Vector2(-9,5),str(hex_id),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
			if hex_id in edit_hexes:
				var outline:=polygon_at(str(hex_id));outline.append(outline[0]);draw_polyline(outline,Color("f3d16f"),4.0,true)
	for edge in game.map_terrain.data.hexsides:
		var parts: PackedStringArray=str(edge).split("|")
		if parts.size()!=2 or (not terrain_review_mode and parts[0] not in selected_ids and parts[1] not in selected_ids):continue
		var kind: String=str(game.map_terrain.data.hexsides[edge])
		if kind in ["door","window","crest","embankment"]:
			var midpoint: Vector2=(map_position(parts[0])+map_position(parts[1]))/2.0
			var marker: String={"door":"D","window":"W","crest":"C","embankment":"S"}.get(kind,"?")
			draw_circle(midpoint,7.0,Color("26382f"));draw_string(font,midpoint+Vector2(-4,4),marker,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f4dfae"))
	if terrain_review_mode and edit_side_origin!="":
		var directions: Array[Vector3i]=[Vector3i(1,0,-1),Vector3i(1,-1,0),Vector3i(0,-1,1),Vector3i(-1,0,1),Vector3i(-1,1,0),Vector3i(0,1,-1)]
		var cube: Vector3i=Hex.cube(edit_side_origin)+directions[posmod(edit_side_direction,6)]
		var row: int=cube.y+(cube.x-(cube.x&1))/2+1
		var neighbor:=String.chr(65+cube.x)+str(row) if cube.x>=0 and cube.x<25 and row>=1 and row<=19 else ""
		if neighbor!="":
			var center_a:=map_position(edit_side_origin);var center_b:=map_position(neighbor)
			var midpoint: Vector2=(center_a+center_b)/2.0
			var tangent: Vector2=(center_b-center_a).orthogonal().normalized()*156.0*scale_factor
			draw_line(midpoint-tangent,midpoint+tangent,Color("5de1cb"),8.0,true)
			draw_string(font,midpoint+Vector2(7,-8),"%s→%s · %s" % [edit_side_origin,neighbor,edit_side_kind],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("eaffd7"))
	var chosen := game.soldier(selected)
	if not chosen.is_empty() and chosen.status == "active" and game.state.blocked == "":
		var can_round_move := false
		if game.state.phase == "rounds" and not game.state.get("round_track",{}).is_empty():
			var bucket: Dictionary = RoundRules.current_turn_bucket(game.state.round_track)
			can_round_move = not bucket.is_empty() and bucket.side == "us" and selected in bucket.ids
			if not game.state.get("round_movement",{}).is_empty() and str(game.state.round_movement.soldier) != selected: can_round_move = false
		for col in 25:
			for row in range(1,20):
				var id := String.chr(65+col)+str(row)
				var legal := Hex.is_entry(id) if chosen.hex == "" else Hex.distance(chosen.hex,id)==1
				if game.state.phase == "rounds":
					legal = can_round_move and legal and (chosen.hex != "" or int(game.state.round_setup.number) >= 2)
					if legal:
						var move: Dictionary = game.round_move_cost(selected,id)
						legal = move.status == "legal" and int(game.state.get("round_movement",{}).get("spent",0)) + int(move.get("points",0)) <= int(chosen.get("mp",4))
				if legal and chosen.stance != "prone":
					var points := polygon_at(id)
					draw_colored_polygon(points,Color(0.26,0.42,0.24,0.25))
					points.append(points[0]);draw_polyline(points,Color(0.23,0.40,0.19,0.85),1.5,true)
	for id in game.state.event_markers:
		var pos := map_position(id)
		draw_circle(pos+Vector2(0,9),3,Color("b7954e"))
	for id in game.state.minefields:
		var pos := map_position(id)+Vector2(13,-12)
		draw_rect(Rect2(pos-Vector2(8,8),Vector2(17,17)),Color("a58a50"))
		draw_string(font,pos+Vector2(-5,5),"M",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("1f241d"))
	for id in game.state.get("terrain_overrides",{}):
		var pos := map_position(id)+Vector2(-16,13)
		var rubble: bool = game.state.terrain_overrides[id] == "rubble"
		draw_rect(Rect2(pos-Vector2(11,9),Vector2(22,18)),Color("665348") if rubble else Color("715c3c"))
		draw_string(font,pos+Vector2(-9,5),"MA" if rubble else "CR",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f4deb7"))
	for id in game.state.landmarks:
		var pos := map_position(id)+Vector2(-15,-13)
		draw_circle(pos,10,Color("5a493b"))
		draw_string(font,pos+Vector2(-5,5),"X",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1d9a3"))
	for id in game.state.items:
		draw_string(font,map_position(id)+Vector2(-5,-12),"+",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("6d4f12"))
	var stacks := {}
	for u in game.state.squad:
		if u.hex == "" or u.status in ["exited","killed"]: continue
		if not stacks.has(u.hex): stacks[u.hex]=[]
		stacks[u.hex].append(u)
	for hex_id in stacks:
		var units: Array = stacks[hex_id]
		for i in units.size():
			var u: Dictionary = units[i]
			var offset := Vector2((i%3- minf(2,units.size()-1)/2.0)*18.0,floori(i/3.0)*18.0)
			var pos := map_position(hex_id)+offset
			var token_rect := Rect2(pos-Vector2(12,12),Vector2(24,24))
			draw_rect(Rect2(token_rect.position+Vector2(1,2),token_rect.size),Color(0,0,0,0.3))
			if counters.has(str(u.id)):
				draw_texture_rect(counters[str(u.id)],token_rect,false,Color(0.72,0.64,0.55) if u.status=="incapacitated" else Color(0.8,0.8,0.8) if u.wounded else Color.WHITE)
			draw_rect(token_rect,Color("e5c47e") if u.id in selected_ids else Color("d6d3bd"),false,2.0 if u.id in selected_ids else 1.0)
			if u.stance == "prone": draw_line(pos+Vector2(-7,8),pos+Vector2(7,8),Color("f5dfa8"),2)
	for enemy in game.state.enemies:
		var pos := map_position(enemy.hex)
		var counter_id: String="GE_"+str(enemy.get("letter", ""))
		if counters.has(counter_id):
			draw_texture_rect(counters[counter_id],Rect2(pos-Vector2(12,12),Vector2(24,24)),false,Color.WHITE if enemy.get("status","active")=="active" else Color(0.55,0.55,0.55))
		else:
			draw_circle(pos,12,Color("743c30") if enemy.get("status", "active") == "active" else Color("565a55"))
	if hovered != "":
		var points := polygon_at(hovered);points.append(points[0])
		draw_polyline(points,Color("f5c76a"),2,true)
		var pos := map_position(hovered)+Vector2(12,-18)
		draw_rect(Rect2(pos-Vector2(4,16),Vector2(48,23)),Color("20281f"))
		draw_string(font,pos,hovered,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("f4dfae"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_at(event.position,1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_at(event.position,1.0/1.15)
		elif event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]: dragging=event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var id := nearest(event.position)
			if id != "": hex_clicked.emit(id)
	if event is InputEventMouseMotion:
		if dragging: pan += event.relative; queue_redraw()
		var id := nearest(event.position)
		if id != hovered: hovered=id;hover_changed.emit(id);queue_redraw()

func nearest(point: Vector2) -> String:
	var result := "";var best := 180.0*scale_factor
	for col in 25:
		for row in range(1,20):
			var id := String.chr(65+col)+str(row)
			var distance := point.distance_to(map_position(id))
			if distance < best: best=distance;result=id
	return result

func zoom_at(point: Vector2, multiplier: float) -> void:
	var old := zoom
	zoom = clampf(zoom*multiplier,1.0,4.0)
	pan = (pan-(point-size/2.0))*(zoom/old)+(point-size/2.0)
	if zoom == 1.0: pan=Vector2.ZERO
	queue_redraw()

func reset_view() -> void:
	zoom=1.0;pan=Vector2.ZERO;queue_redraw()
