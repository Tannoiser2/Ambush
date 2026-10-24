class_name AmbushBoard
extends Control
signal hex_clicked(id: String)
signal hover_changed(id: String)
const Hex = preload("res://scripts/hex_grid.gd")
var game: AmbushGame
var selected := "A"
var hovered := ""
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var texture: Texture2D = preload("res://assets/maps/map_a.jpg")
var font: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
var rect := Rect2()
var scale_factor := 1.0

func _ready() -> void:
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
	draw_texture_rect_region(texture, rect, Rect2(0,0,7000,6400),Color(0.94,0.93,0.85))
	if game == null or game.state.is_empty(): return
	var chosen := game.soldier(selected)
	if not chosen.is_empty() and chosen.status == "active" and game.state.blocked == "":
		for col in 25:
			for row in range(1,20):
				var id := String.chr(65+col)+str(row)
				var legal := Hex.is_entry(id) if chosen.hex == "" else Hex.distance(chosen.hex,id)==1
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
			var token_rect := Rect2(pos-Vector2(10,11),Vector2(20,22))
			draw_rect(Rect2(token_rect.position+Vector2(1,2),token_rect.size),Color(0,0,0,0.3))
			draw_rect(token_rect,Color("8b4e39") if u.status=="incapacitated" else Color("6d5932") if u.wounded else Color("344d39"))
			draw_rect(token_rect,Color("e5c47e") if u.id==selected else Color("d6d3bd"),false,2.0 if u.id==selected else 1.0)
			draw_string(font,pos+Vector2(-5,5),u.id,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff7d9"))
			if u.stance == "prone": draw_line(pos+Vector2(-7,8),pos+Vector2(7,8),Color("f5dfa8"),2)
	for enemy in game.state.enemies:
		var pos := map_position(enemy.hex)
		draw_circle(pos,12,Color("743c30"))
		draw_string(font,pos+Vector2(-5,5),str(enemy.get("letter", enemy.id)),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff0d7"))
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
