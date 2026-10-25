extends Button

var terrain_id := ""
var tile_texture: Texture2D
var caption := ""

func _ready() -> void:
	custom_minimum_size=Vector2(60,64)
	flat=true
	focus_mode=Control.FOCUS_NONE
	tooltip_text=caption
	pressed.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _draw() -> void:
	var w:=size.x
	var points:=PackedVector2Array([Vector2(w*0.25,3),Vector2(w*0.75,3),Vector2(w-3,25),Vector2(w*0.75,47),Vector2(w*0.25,47),Vector2(3,25)])
	var uvs:=PackedVector2Array([Vector2(0.25,0),Vector2(0.75,0),Vector2(1,0.5),Vector2(0.75,1),Vector2(0.25,1),Vector2(0,0.5)])
	var fill:=Color("e4dfca") if tile_texture==null else Color.WHITE
	if tile_texture!=null:draw_polygon(points,PackedColorArray([fill,fill,fill,fill,fill,fill]),uvs,tile_texture)
	else:
		draw_colored_polygon(points,Color("71684e"))
		if terrain_id=="crater":
			draw_arc(Vector2(w/2.0,26),14.0,0.0,TAU,28,Color("3b392e"),3.0,true)
			draw_arc(Vector2(w/2.0,26),8.0,0.0,TAU,24,Color("c2a66b"),2.0,true)
		elif terrain_id=="rubble":
			for shard in [PackedVector2Array([Vector2(15,25),Vector2(22,15),Vector2(28,25)]),PackedVector2Array([Vector2(28,31),Vector2(39,18),Vector2(45,33)]),PackedVector2Array([Vector2(17,38),Vector2(25,30),Vector2(30,40)])]:draw_colored_polygon(shard,Color("c5b18c"))
	var outline:=Color("f0d071") if button_pressed else Color("536149")
	draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[4],points[5],points[0]]),outline,3.0 if button_pressed else 1.5,true)
	draw_string(get_theme_default_font(),Vector2(2,62),caption,HORIZONTAL_ALIGNMENT_CENTER,w-4,9,Color("e8e1cd"))
