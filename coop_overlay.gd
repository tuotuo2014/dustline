extends Control
## A small 2D squad overlay, without additional world cameras or viewports.
const CYAN := Color("77e4dd")
const GOLD := Color("f6c77a")
const RED := Color("ff857e")
var game: Node3D
var _clock := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_clock+=delta
	if _clock<.05: return
	_clock=0
	queue_redraw()

func text(at: Vector2, value: String, tint: Color, font_size := 14) -> void:
	draw_string(get_theme_default_font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func _draw() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.coop) or not game.coop.in_round: return
	var net: Node=game.coop
	var radar: Control=game.hud._minimap
	var top := radar.position.y+radar.size.y+10
	var compact := get_viewport_rect().size.y<850
	var row_height := 25.0 if compact else 36.0
	var width := radar.size.x
	var panel_height: float=32+net.members.size()*row_height
	var bottom: float=game.hud._vitals.position.y-10
	# On short windows tuck the compact roster beside the radar.
	var left := 24.0
	if top+panel_height>bottom:
		left=radar.position.x+radar.size.x+18
		top=250
		width=minf(300,game.hud._mission_box.position.x-left-18)
	if width<180: return
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.025,.06,.065,.90)
	style.border_color=Color(CYAN,.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	draw_style_box(style,Rect2(left,top,width,panel_height))
	text(Vector2(left+10,top+20),"真人小队 %d/4"%net.members.size(),CYAN)
	var index := 0
	for id in net.members:
		var member: Dictionary=net.members[id]
		var body: Node3D=net.actor(id)
		if not is_instance_valid(body): continue
		var distance: float=body.global_position.distance_to(game.player.global_position)
		var state := "倒地 · 待救援" if member.hp<=0 else "%d/%d HP"%[ceili(member.hp),member.max_hp]
		var rtt := int(member.get("rtt",0))
		if id==net.local_id(): state+=" · 你"
		else: state+=" · %dm"%roundi(distance)
		var y: float=top+43+index*row_height
		text(Vector2(left+10,y),str(member.name).left(9)+"  "+state,RED if member.hp<=0 else Color("dbe8df"),12 if compact else 14)
		var ratio: float=clampf(float(member.hp)/maxf(1,member.max_hp),0,1)
		draw_rect(Rect2(left+10,y+4,(width-20)*ratio,3),RED if member.hp<=30 else CYAN)
		if not compact: text(Vector2(left+10,y+18),"Lv.%d · %s · %dms"%[member.rank,game.player.CharacterCatalog.get_info(member.character).name,rtt],Color("8fa9a3"),10)
		index+=1
	for id in net.team.pings:
		var ping: Dictionary=net.team.pings[id]
		world_marker(ping.point,str(ping.name)+" · "+net.team.ping_title(ping.kind),RED if ping.kind=="danger" else (GOLD if ping.kind=="supply" else CYAN))
	for mark in net.team.scans: world_marker(mark.point,mark.title,GOLD,.65)
	if not net.team.extraction.is_empty(): world_marker(net.team.extraction.point,"撤离集合圈 · 8m",Color("9ce7a7"))
	var message: String=net.team.status_text()
	var area := Rect2(Vector2(get_viewport_rect().size.x*.28,bottom-44),Vector2(get_viewport_rect().size.x*.44,34))
	draw_style_box(style,area)
	text(area.position+Vector2(10,22),message.left(56),GOLD,13)
	if net.connection_stalled():
		text(Vector2(get_viewport_rect().size.x*.38,66),"网络延迟，正在等待同步…",RED,18)

func world_marker(point: Vector3, title: String, tint: Color, weight := 1.0) -> void:
	var camera: Camera3D=game.player.get_node("Camera3D")
	var target := point+Vector3(0,1.7,0)
	var at := camera.unproject_position(target)
	var rect := get_viewport_rect().grow(-30)
	if camera.is_position_behind(target): at=rect.get_center()-(at-rect.get_center())
	var outside := not rect.has_point(at) or camera.is_position_behind(target)
	at=at.clamp(rect.position,rect.end)
	draw_arc(at,8*weight,0,TAU,16,tint,1.5,true)
	var distance: float=point.distance_to(game.player.global_position)
	var caption := ("↗ " if outside else "")+title+" · %dm"%roundi(distance)
	text(Vector2(clampf(at.x+12,30,rect.end.x-200),clampf(at.y,84,rect.end.y-200)),caption,tint,12)
