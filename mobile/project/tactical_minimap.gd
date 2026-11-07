extends Control
## North-up tactical chart. Cached world geometry; no second 3D camera/render pass.
const CYAN := Color("77e4dd")
const MUTED := Color("739b9f")
const GOLD := Color("f6c77a")
const RED := Color("ff857e")
const WOLF = preload("res://assets/ui/wolf_marker.svg")
const GREEN := Color("a5e7b1")
var game: Node3D
var vitals_panel: Control
var chart: Control
var world_id := 0
var features: Array = []
var contours: Array[PackedVector2Array] = []
var markers: Array[Dictionary] = []
var player_position := Vector2.ZERO
var player_heading := 0.0
var camera_heading := 0.0
var region_name := ""
var extent := 210.0
var exit_distance := 0
var scan := 0.0
var _refresh_clock := 0.0
var _layout_clock := 0.0
var update_count := 0
var pixels_per_meter := 1.0

class Chart extends Control:
	var map: Control
	func _draw() -> void: map.draw_chart()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	chart=Chart.new()
	chart.name="MapSurface"
	chart.map=self
	chart.mouse_filter=Control.MOUSE_FILTER_IGNORE
	chart.clip_contents=true
	add_child(chart)
	resized.connect(_resize_chart)
	_resize_chart()

func _resize_chart() -> void:
	if not is_instance_valid(chart): return
	chart.position=Vector2(10,46)
	chart.size=Vector2(maxf(10,size.x-20),maxf(20,size.y-83))
	pixels_per_meter=(minf(chart.size.x,chart.size.y)-24.0)/(extent*2.0)
	queue_redraw()
	chart.queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(game) or not is_instance_valid(game.world): return
	_refresh_clock+=delta
	_layout_clock+=delta
	if _layout_clock>=.15:
		_layout_clock=0
		place()
	if game.world.get_instance_id()!=world_id: rebuild_world()
	# Twenty updates/second keep the vector overlay inexpensive and responsive.
	if _refresh_clock<.05: return
	scan=fmod(scan+_refresh_clock*.65,TAU)
	_refresh_clock=0
	refresh_markers()
	update_count+=1
	queue_redraw()
	chart.queue_redraw()

func place() -> void:
	var safe := Rect2(Vector2.ZERO,get_viewport_rect().size)
	if is_instance_valid(game) and is_instance_valid(game.hud): safe=game.hud.mobile_safe_rect()
	size=Vector2(196,228)
	position=safe.position+Vector2(16,16)
	_resize_chart()

func rebuild_world() -> void:
	world_id=game.world.get_instance_id()
	features=game.world.get_meta("minimap_features",[])
	region_name=str(game.region.name)
	extent=float(game.region.extent)
	_resize_chart()
	contours.clear()
	# Sample the actual dunes once when entering a different region.
	var count := 40
	var stride := extent*2/count
	var heights: Array[float]=[]
	for z in count+1:
		for x in count+1: heights.append(game.world.ground_height(-extent+x*stride,-extent+z*stride))
	for z in count:
		for x in count:
			var corners := PackedVector2Array([Vector2(x,z),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)])
			var values := [heights[z*(count+1)+x],heights[z*(count+1)+x+1],heights[(z+1)*(count+1)+x+1],heights[(z+1)*(count+1)+x]]
			for level in [1.0,3.0,6.0,10.0,16.0]:
				var intersections := PackedVector2Array()
				for edge in 4:
					var next := (edge+1)%4
					if (values[edge]<level)==(values[next]<level): continue
					var t: float=(level-values[edge])/(values[next]-values[edge])
					intersections.append(corners[edge].lerp(corners[next],t)*stride-Vector2.ONE*extent)
				for i in range(0,intersections.size()-1,2): contours.append(PackedVector2Array([intersections[i],intersections[i+1]]))

func refresh_markers() -> void:
	player_position=flat(game.player.global_position)
	player_heading=-game.player.get_node("Body").global_rotation.y
	camera_heading=-game.player.camera_yaw
	exit_distance=roundi(player_position.distance_to(flat(game.extraction.global_position))) if is_instance_valid(game.extraction) else 0
	markers.clear()
	for pickup in game.pickups:
		if not is_instance_valid(pickup) or pickup.is_queued_for_deletion() or pickup.get_meta("taken",false): continue
		if flat(pickup.global_position).distance_to(player_position)>65: continue
		add_marker(pickup,"supply",GOLD,false)
	for mutant in game.mutants:
		if not is_instance_valid(mutant) or mutant.is_queued_for_deletion(): continue
		add_marker(mutant,"threat",RED,true)
	if is_instance_valid(game.coop) and game.coop.in_round:
		for avatar in game.coop.avatars.values(): add_marker(avatar,"teammate",CYAN,true)
	for shelter in game.shelters: add_marker(shelter,"camp",CYAN,shelter==game.base)
	for relay in game.relays: add_marker(relay,"relay",GREEN if relay.get_meta("active",false) else GOLD,true)
	for extraction in game.extraction_points: add_marker(extraction,"exit",GREEN if game._can_extract() else MUTED,true)

func add_marker(node: Node3D, kind: String, tint: Color, persistent: bool) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion(): return
	markers.append({"id":node.get_instance_id(),"point":flat(node.global_position),"kind":kind,"color":tint,"persistent":persistent})

static func flat(point: Vector3) -> Vector2: return Vector2(point.x,point.z)

func project(point: Vector2) -> Vector2:
	return chart.size*.5+point*pixels_per_meter

func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color=Color(.025,.065,.078,.96)
	panel.border_color=Color(.28,.62,.65,.6)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(9)
	draw_style_box(panel,Rect2(Vector2.ZERO,size))
	# Interrupted luminous rails and machined corner brackets.
	draw_line(Vector2(16,0),Vector2(92,0),CYAN,2,true)
	draw_line(Vector2(size.x-66,size.y),Vector2(size.x-15,size.y),Color(CYAN,.6),2,true)
	for x in [6.0,size.x-6]:
		var direction := 1.0 if x<10 else -1.0
		draw_polyline(PackedVector2Array([Vector2(x,23),Vector2(x,7),Vector2(x+16*direction,7)]),Color(CYAN,.7),1,true)
	text_at(Vector2(15,23),"战术雷达",15,CYAN)
	text_at(Vector2(size.x-49,22),"● 在线",11,CYAN)
	text_at(Vector2(15,42),region_name+" · 北向上",12,MUTED)
	draw_line(Vector2(10,45),Vector2(size.x-10,45),Color(CYAN,.25),1)
	text_at(Vector2(12,size.y-14),"绿色方框：撤离 %d m"%exit_distance,13,GREEN)

func text_at(at: Vector2, value: String, font_size: int, tint: Color) -> void:
	draw_string(get_theme_default_font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func draw_chart() -> void:
	var bounds := Rect2(Vector2.ZERO,chart.size)
	chart.draw_rect(bounds,Color("081b22"))
	var visible_world := Rect2(-chart.size*.5/pixels_per_meter,chart.size/pixels_per_meter)
	for x in range(floori(visible_world.position.x/20),ceili(visible_world.end.x/20)+1):
		var px := project(Vector2(x*20,0)).x
		chart.draw_line(Vector2(px,0),Vector2(px,chart.size.y),Color(.3,.7,.7,.09),1)
	for z in range(floori(visible_world.position.y/20),ceili(visible_world.end.y/20)+1):
		var py := project(Vector2(0,z*20)).y
		chart.draw_line(Vector2(0,py),Vector2(chart.size.x,py),Color(.3,.7,.7,.09),1)
	for segment in contours:
		if not visible_world.grow(20).has_point(segment[0]): continue
		chart.draw_line(project(segment[0]),project(segment[1]),Color(.3,.65,.65,.19),1,true)
	for feature in features:
		if not visible_world.intersects(feature.bounds): continue
		var polygon := PackedVector2Array()
		for point in feature.points: polygon.append(project(point))
		chart.draw_colored_polygon(polygon,Color(.18,.37,.4,.48) if feature.road else Color(.25,.46,.47,.42))
		polygon.append(polygon[0])
		chart.draw_polyline(polygon,Color(.38,.64,.63,.25),1,true)
	var world_box := Rect2(project(Vector2(-extent,-extent)),Vector2.ONE*extent*2*pixels_per_meter)
	chart.draw_rect(world_box,Color(GOLD,.5),false,1)
	var center := chart.size*.5
	var radius := minf(center.x,center.y)-8
	for fraction in [.5,1.0]: chart.draw_arc(center,radius*fraction,0,TAU,64,Color(CYAN,.13),1,true)
	# A faint sweep supplies motion without flashing or hiding the cartography.
	chart.draw_line(center,center+Vector2.UP.rotated(scan)*radius,Color(CYAN,.16),1,true)
	var player_point := project(player_position)
	var fov := PackedVector2Array([player_point,player_point+Vector2.UP.rotated(camera_heading-.48)*radius*.3,player_point+Vector2.UP.rotated(camera_heading+.48)*radius*.3])
	chart.draw_colored_polygon(fov,Color(CYAN,.07))
	var safe := bounds.grow(-10)
	var occupied := PackedVector2Array([player_point])
	var ordered: Array=markers.filter(func(m): return m.kind not in ["threat","teammate"])+markers.filter(func(m): return m.kind in ["threat","teammate"])
	for marker in ordered:
		var point := project(marker.point)
		if not safe.has_point(point):
			if not marker.persistent: continue
			var delta := point-center
			var factor := minf((center.x-10)/maxf(absf(delta.x),.001),(center.y-10)/maxf(absf(delta.y),.001))
			point=center+delta*factor
			var outward := delta.normalized()
			chart.draw_line(point-outward*8,point,Color(marker.color,.7),1,true)
		if marker.kind in ["threat","teammate"]:
			var true_point := point
			for attempt in 32:
				var overlaps := false
				for other in occupied:
					if point.distance_to(other)<18: overlaps=true
				if not overlaps and safe.has_point(point): break
				point=true_point+Vector2.RIGHT.rotated(attempt*TAU/8)*(20+floori(attempt/8.0)*15)
			point=point.clamp(safe.position,safe.end)
			if point.distance_to(true_point)>1: chart.draw_line(true_point,point,Color(marker.color,.65),1,true)
			occupied.append(point)
		draw_symbol(chart,point,marker.kind,marker.color,7 if marker.kind=="threat" else 4)
	chart.draw_circle(player_point,8,Color(.01,.05,.07,.95))
	chart.draw_arc(player_point,8,0,TAU,32,Color(CYAN,.4),1,true)
	var arrow := PackedVector2Array()
	for point in [Vector2(0,-8),Vector2(5,6),Vector2(0,3),Vector2(-5,6)]: arrow.append(player_point+point.rotated(player_heading))
	chart.draw_colored_polygon(arrow,Color("d7ffff"))
	chart.draw_string(get_theme_default_font(),Vector2(chart.size.x*.5-4,14),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,11,CYAN)
	var bar_length := 50*pixels_per_meter
	chart.draw_line(Vector2(9,chart.size.y-10),Vector2(9+bar_length,chart.size.y-10),MUTED,2)
	chart.draw_string(get_theme_default_font(),Vector2(9,chart.size.y-16),"50 m",HORIZONTAL_ALIGNMENT_LEFT,-1,10,MUTED)

func draw_symbol(canvas: Control, point: Vector2, kind: String, tint: Color, radius: float) -> void:
	match kind:
		"supply": canvas.draw_circle(point,radius*.65,tint)
		"threat":
			canvas.draw_texture_rect(WOLF,Rect2(point-Vector2.ONE*(radius+3),Vector2.ONE*(radius+3)*2),false)
		"teammate":
			canvas.draw_circle(point,radius+2,Color("102b32"))
			canvas.draw_circle(point,radius,tint,false,1.5,true)
			canvas.draw_line(point-Vector2(0,2),point+Vector2(0,2),tint,2)
		"camp":
			canvas.draw_polyline(PackedVector2Array([point+Vector2(-radius,radius),point+Vector2(-radius,-1),point+Vector2(0,-radius-2),point+Vector2(radius,-1),point+Vector2(radius,radius),point+Vector2(-radius,radius)]),tint,1.5,true)
		"relay":
			canvas.draw_polyline(PackedVector2Array([point+Vector2(0,-radius-1),point+Vector2(radius+1,0),point+Vector2(0,radius+1),point+Vector2(-radius-1,0),point+Vector2(0,-radius-1)]),tint,1.5,true)
		"exit":
			canvas.draw_rect(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2),tint,false,1.5)
			canvas.draw_line(point+Vector2(-2,0),point+Vector2(radius+3,0),tint,1.5,true)
