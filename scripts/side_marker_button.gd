extends Button

var side_kind := "crest"
var marker_letter := "C"
var marker_color := Color("596657")

func _ready() -> void:
	custom_minimum_size=Vector2(42,42)
	focus_mode=Control.FOCUS_NONE
	tooltip_text={"crest":"Cresta — seleziona, poi clicca un lato","embankment":"Scarpata — seleziona, poi clicca un lato","door":"Porta — seleziona, poi clicca un lato","window":"Finestra — seleziona, poi clicca un lato","none":"Rimuovi indicatore — seleziona, poi clicca un lato"}.get(side_kind,side_kind)

func _draw() -> void:
	var center:=size/2.0
	draw_circle(center,15.0,marker_color)
	draw_arc(center,15.0,0.0,TAU,32,Color("e5ddc3"),1.5,true)
	draw_string(get_theme_default_font(),center+Vector2(-4,5),marker_letter,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
