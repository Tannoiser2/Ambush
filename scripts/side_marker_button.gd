extends Button

var side_kind := "crest"
var marker_letter := "C"
var marker_color := Color("596657")

func _ready() -> void:
	custom_minimum_size=Vector2(42,42)
	focus_mode=Control.FOCUS_NONE
	tooltip_text={"crest":"Cresta — trascina sul lato dell’esagono","embankment":"Scarpata — trascina sul lato dell’esagono","door":"Porta — trascina sul lato dell’esagono","window":"Finestra — trascina sul lato dell’esagono","none":"Rimuovi indicatore — trascina sul lato dell’esagono"}.get(side_kind,side_kind)

func _draw() -> void:
	var center:=size/2.0
	draw_circle(center,15.0,marker_color)
	draw_arc(center,15.0,0.0,TAU,32,Color("e5ddc3"),1.5,true)
	draw_string(get_theme_default_font(),center+Vector2(-4,5),marker_letter,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview:=Label.new()
	preview.text="● "+marker_letter
	preview.add_theme_color_override("font_color",marker_color)
	preview.add_theme_font_size_override("font_size",24)
	set_drag_preview(preview)
	return {"ambush_hexside":side_kind}
