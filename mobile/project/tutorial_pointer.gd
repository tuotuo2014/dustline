extends Control
## Lightweight canvas arrows follow real targets and never intercept gameplay input.
var camera: Camera3D
var focus_control: Control
var exclusion_control: Control
var card: Control
var data: Dictionary = {}
var screen_point := Vector2.ZERO
var target_rect := Rect2()
var edge_target := false
var behind_target := false
var _clock := 0.0
var _caption := ""
var _direction := Vector2.DOWN
var _active := false
const GOLD := Color("ffd392")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_clock+=delta
	_active=false
	target_rect=Rect2()
	edge_target=false
	behind_target=false
	_caption=str(data.get("pointer_label",""))
	if _caption.is_empty():
		queue_redraw()
		return
	if is_instance_valid(focus_control) and focus_control.is_visible_in_tree():
		target_rect=focus_control.get_global_rect().grow(6)
		screen_point=Vector2(target_rect.get_center().x,target_rect.position.y-8)
		_direction=Vector2.DOWN
		_active=true
	elif data.get("focus","")=="look":
		screen_point=Vector2(size.x*.73,size.y*.62)
		if is_instance_valid(exclusion_control):
			screen_point.x=maxf(screen_point.x,exclusion_control.get_global_rect().end.x+90)
		_direction=Vector2.LEFT
		_active=true
	elif data.has("world_target") and is_instance_valid(camera):
		var point: Vector3=data.world_target
		var local := camera.to_local(point)
		behind_target=camera.is_position_behind(point)
		var raw := camera.unproject_position(point) if not behind_target else size*.5+Vector2(local.x,-local.y).normalized()*size.length()
		if behind_target and Vector2(local.x,-local.y).length()<.05: raw=size*.5+Vector2(0,size.y)
		var safe := Rect2(Vector2(32,100),Vector2(maxf(1,size.x-64),maxf(1,size.y-290)))
		edge_target=behind_target or not safe.has_point(raw)
		screen_point=Vector2(clampf(raw.x,safe.position.x,safe.end.x),clampf(raw.y,safe.position.y,safe.end.y))
		if is_instance_valid(card) and card.get_global_rect().grow(34).has_point(screen_point):
			screen_point.x=minf(card.get_global_rect().end.x+48,safe.end.x)
			edge_target=true
		if is_instance_valid(exclusion_control) and exclusion_control.get_global_rect().grow(28).has_point(screen_point):
			screen_point.x=exclusion_control.get_global_rect().end.x+40
			edge_target=true
		_direction=(raw-screen_point).normalized() if edge_target else Vector2.DOWN
		if _direction.length_squared()<.01: _direction=Vector2.DOWN
		if behind_target: _caption="目标在身后 · 转动镜头寻找"
		elif edge_target: _caption="朝箭头方向看 · "+_caption
		_active=true
	queue_redraw()

func _draw() -> void:
	if not _active: return
	var pulse := .65+.25*sin(_clock*3.0)
	if target_rect.has_area():
		draw_style_box(_outline(Color(GOLD,pulse)),target_rect)
	var end := screen_point
	var start := end-_direction*(54.0+sin(_clock*3.0)*4)
	var wing := _direction.orthogonal()*10.0
	for width in [10.0,4.0]:
		var tint := Color(.03,.05,.04,.88) if width>5 else GOLD
		draw_line(start,end,tint,width,true)
		draw_polyline(PackedVector2Array([end-_direction*15+wing,end,end-_direction*15-wing]),tint,width,true)
	if not edge_target and not target_rect.has_area():
		draw_arc(end+Vector2(0,18),13+2*pulse,0,TAU,32,Color(GOLD,pulse),2,true)
	var font := get_theme_default_font()
	var font_size := 16
	var text_width := minf(font.get_string_size(_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,size.x-70)
	var center := start-Vector2(0,46) if target_rect.has_area() else (start+Vector2(0,28) if _direction.y<-.5 else end+Vector2(0,49))
	var box := Rect2(Vector2(clampf(center.x-text_width*.5-12,20,maxf(20,size.x-text_width-44)),clampf(center.y,80,size.y-105)),Vector2(text_width+24,36))
	if is_instance_valid(exclusion_control) and box.intersects(exclusion_control.get_global_rect().grow(12)):
		box.position.x=exclusion_control.get_global_rect().end.x+16
	draw_style_box(_outline(Color("566555"),Color(.04,.07,.05,.96)),box)
	draw_string(font,box.position+Vector2(12,24),_caption,HORIZONTAL_ALIGNMENT_LEFT,text_width,font_size,GOLD)

func _outline(edge: Color, fill := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style
