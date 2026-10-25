class_name AmbushTerrainArt
extends RefCounted

static var texture_cache: Dictionary={}
static var overlay_cache: Dictionary={}

static func texture(kind: String) -> Texture2D:
	if texture_cache.has(kind):return texture_cache[kind]
	var path: String = {
		"clear":"clear_1", "clear_1":"clear_1", "clear_2":"clear_2", "clear_3":"clear_3",
		"woods":"woods", "brush":"brush", "rough":"rough",
		"stream":"stream", "cover":"cover", "road":"road", "dirt_road":"dirt_road",
		"wood_bridge":"wood_bridge", "stone_bridge":"stone_bridge", "railroad":"railroad",
		"wood_building":"wood_building", "stone_building":"stone_building"
	}.get(kind, "clear_1")
	if kind in ["crater","rubble"]:return null
	var tile: Texture2D=load("res://assets/terrain/%s.png" % path)
	if kind in ["stone_building","wood_building"]:tile=_centered_building(tile)
	texture_cache[kind]=tile
	return tile

static func _centered_building(source: Texture2D) -> Texture2D:
	var image:=source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel:=image.get_pixel(x,y)
			if pixel.r>0.94 and pixel.g>0.94 and pixel.b>0.9:pixel.a=0.0
			else:pixel.a=1.0
			image.set_pixel(x,y,pixel)
	var centered: Image=load("res://assets/terrain/clear_1.png").get_image()
	centered.convert(Image.FORMAT_RGBA8)
	centered.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(7,14))
	return ImageTexture.create_from_image(centered)

static func overlay_texture(kind: String) -> Texture2D:
	if overlay_cache.has(kind):return overlay_cache[kind]
	var source:=texture(kind)
	if source==null:return null
	var image:=source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel:=image.get_pixel(x,y)
			if pixel.r>0.94 and pixel.g>0.94 and pixel.b>0.9:pixel.a=0.0
			else:pixel.a=1.0
			image.set_pixel(x,y,pixel)
	var result:=ImageTexture.create_from_image(image)
	overlay_cache[kind]=result
	return result
