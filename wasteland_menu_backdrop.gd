extends Control
## Painted treatment of an actual game scene, with restrained wind and worn markings.
var _picture: TextureRect
var _clock := 0.0
var _last_draw := 0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_picture=TextureRect.new()
	_picture.texture=load("res://assets/menu/wasteland-entry.png")
	_picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader=preload("res://wasteland_menu.gdshader")
	_picture.material=shader_material
	_picture.show_behind_parent=true
	add_child(_picture)
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Draw the weathered frame above the scene, beneath all menu controls.
	resized.connect(queue_redraw)
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_clock+=delta
	_last_draw+=delta
	if _last_draw<.05: return
	_last_draw=0
	_picture.material.set_shader_parameter("drift",_clock)
	queue_redraw()
func _draw() -> void:
	var gold := Color("e8b84b")
	var dark := Color("322614")
	draw_rect(Rect2(0,0,size.x,7),gold)
	draw_rect(Rect2(0,size.y-7,size.x,7),gold)
	for x in range(-32,int(size.x)+32,36):
		draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+14,0),Vector2(x+7,7),Vector2(x-7,7)]),dark)
		draw_colored_polygon(PackedVector2Array([Vector2(x,size.y-7),Vector2(x+14,size.y-7),Vector2(x+7,size.y),Vector2(x-7,size.y)]),dark)
	var random := RandomNumberGenerator.new()
	random.seed=5406
	for i in 120:
		var edge := random.randf()<.5
		var point := Vector2(random.randf_range(0,size.x),random.randf_range(12,38))
		if edge: point.y=size.y-point.y
		draw_line(point,point+Vector2(random.randf_range(2,28),random.randf_range(-1,1)),Color(.15,.10,.04,.26),1)
