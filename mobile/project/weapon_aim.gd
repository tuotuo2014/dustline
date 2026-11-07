extends Control
## One camera, a projected aiming ray, and a lightweight 2D optical overlay.
var game: Node3D
var cursor := Vector2.ZERO
var has_cursor := false
var aiming := false
var scoped := false
var _owns_cursor := false
var _previous_cursor := Input.MOUSE_MODE_VISIBLE
var _hud_colors: Dictionary = {}
var _font: Font=preload("res://assets/fonts/NotoSansSC.ttf")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=30

func available() -> bool:
	return is_instance_valid(game) and game.active and not game.round_over and game.player.controls_enabled and game.hud._hud.visible and game.profile.equipped=="repulsor" and "repulsor" in game.profile.owned

func screen_point() -> Vector2:
	return get_viewport_rect().size*.5

func target_point() -> Vector3:
	var camera: Camera3D=game.player.get_node("Camera3D")
	var origin := camera.project_ray_origin(screen_point())
	var endpoint := origin+camera.project_ray_normal(screen_point())*200.0
	var query := PhysicsRayQueryParameters3D.create(origin,endpoint,1|4,[game.player.get_rid()])
	var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
	return endpoint if hit.is_empty() else Vector3(hit.position)

func toggle_scope() -> void:
	if not available():
		game._show_toast("先在营地购买并装备枪械，再点「瞄准」。",3)
		return
	if not game.player.scope_enabled:
		var direction: Vector3 = (target_point()-(game.player.global_position+Vector3(0,1.62,0))).normalized()
		game.player.camera_yaw=atan2(-direction.x,-direction.z)
		game.player.camera_pitch=-asin(clampf(direction.y,-1,1))
	game.player.set_scope(not game.player.scope_enabled)

func _process(_delta: float) -> void:
	aiming=available()
	if not aiming and game.player.scope_enabled: game.player.set_scope(false)
	scoped=aiming and game.player.scope_enabled
	if scoped:
		for item in game.hud._hud.get_children():
			if item==self or item==game.hud._menu_button or item==game.hud._tutorial_panel or not item is CanvasItem: continue
			if not _hud_colors.has(item): _hud_colors[item]=item.modulate
			item.modulate=Color(1,1,1,0)
	elif not _hud_colors.is_empty():
		for item in _hud_colors:
			if is_instance_valid(item): item.modulate=_hud_colors[item]
		_hud_colors.clear()
	queue_redraw()

func _draw() -> void:
	if not aiming: return
	var point := screen_point()
	var tint := Color("bce9d6")
	if not scoped:
		for axis in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
			draw_line(point+axis*6,point+axis*16,Color(0,0,0,.85),4,true)
			draw_line(point+axis*7,point+axis*15,tint,1.6,true)
		draw_circle(point,1.7,Color("ffe2a4"))
		return
	var radius := minf(size.x,size.y)*.43
	var outer := size.length()
	for i in 128:
		var a := Vector2.from_angle(TAU*i/128.0)
		var b := Vector2.from_angle(TAU*(i+1)/128.0)
		draw_colored_polygon(PackedVector2Array([point+a*radius,point+a*outer,point+b*outer,point+b*radius]),Color(.005,.008,.009,1))
	draw_circle(point,radius,Color(.04,.10,.09,.035))
	draw_arc(point,radius,0,TAU,128,Color("52635d"),4,true)
	draw_arc(point,radius-6,0,TAU,128,Color(0,0,0,.8),2,true)
	for axis in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		draw_line(point+axis*5,point+axis*(radius-10),Color(.02,.035,.025,.95),1.4,true)
		var across := Vector2(-axis.y,axis.x)
		for i in range(1,9):
			var tick: Vector2 = point+axis*(radius*.095*i)
			draw_line(tick-across*4,tick+across*4,tint,1,true)
	draw_circle(point,2,Color("e89c65"))
	draw_string(_font,point+Vector2(-radius*.65,radius*.65),"4×  精密瞄准",HORIZONTAL_ALIGNMENT_LEFT,-1,16,tint)
	var caption := "点瞄准退出 · 点开火射击 · 弹药 %d"%game.round_ammo
	var caption_width := _font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	draw_string(_font,Vector2(point.x-caption_width*.5,point.y+radius+23),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,tint)
