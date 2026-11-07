extends RefCounted
## Ground-level visual factories. The gameplay controller owns all interaction.

const Equipment = preload("res://equipment_geometry.gd")
const SURFACE = preload("res://wasteland_surface.gdshader")
static var _materials: Dictionary = {}

static func pickup(kind: String) -> Area3D:
	var area := Area3D.new()
	area.name="MedkitPickup" if kind=="medkit" else "ScrapPickup"
	area.collision_layer=2
	area.collision_mask=1
	area.set_meta("kind",kind)
	if kind=="scrap": area.add_to_group("scrap_pickups")
	var shape := CollisionShape3D.new()
	shape.name="PickupShape"
	var sphere := SphereShape3D.new()
	sphere.radius=1.1
	shape.shape=sphere
	shape.position.y=.45
	area.add_child(shape)
	var model := _group(area,"Model")
	var steel := _mat("625a48",3,.82,.45)
	var dark := _mat("292b25",4)
	var oxide := _mat("704832",2,.92,.24)
	if kind=="medkit":
		var enamel := _mat("696f57",7,.88)
		var ivory := _mat("b8b297",7,.95)
		_shape(model,Vector3.ZERO,Equipment.formed_shell([Vector4(-.19,.25,.105,.16),Vector4(-.16,.285,.145,.16),Vector4(.16,.285,.145,.16),Vector4(.19,.25,.105,.16)],20),enamel)
		_box(model,Vector3(0,.265,0),Vector3(.585,.025,.39),dark)
		_box(model,Vector3(0,.3,0),Vector3(.59,.057,.4),enamel)
		for x in [-.23,.23]:
			_box(model,Vector3(x,.255,-.209),Vector3(.041,.09,.018),steel)
			_box(model,Vector3(x,.17,.196),Vector3(.034,.085,.013),steel)
			_box(model,Vector3(x,.075,-.13),Vector3(.037,.05,.032),dark)
		_rod(model,Vector3(-.1,.338,0),Vector3(-.1,.411,0),.012,steel)
		_rod(model,Vector3(.1,.338,0),Vector3(.1,.411,0),.012,steel)
		_rod(model,Vector3(-.1,.411,0),Vector3(.1,.411,0),.019,dark)
		_box(model,Vector3(0,.22,-.198),Vector3(.17,.045,.008),ivory)
		_box(model,Vector3(0,.22,-.2),Vector3(.048,.17,.008),ivory)
		_box(model,Vector3(0,.332,0),Vector3(.17,.006,.044),ivory)
		_box(model,Vector3(0,.333,0),Vector3(.045,.006,.16),ivory)
		_label(area,"MED",Vector3(0,.13,-.211),24,.0014,Color("d3cbb3"),false).rotation.y=PI
	else:
		_shape(model,Vector3.ZERO,Equipment.formed_shell([Vector4(-.205,.26,.074,.12),Vector4(-.18,.305,.10,.12),Vector4(.17,.305,.10,.12),Vector4(.205,.25,.074,.12)],16),oxide)
		_box(model,Vector3(.015,.225,.01),Vector3(.67,.035,.45),steel).rotation.z=.06
		for x in [-.27,.27]:
			_box(model,Vector3(x,.13,-.22),Vector3(.035,.23,.024),steel)
			for y in [.045,.2]: _sphere(model,Vector3(x,y,-.237),.018,dark)
		var plate := _box(model,Vector3(-.09,.295,.015),Vector3(.28,.023,.4),oxide)
		plate.rotation=Vector3(.11,.28,.16)
		var coil := _ring(model,Vector3(.18,.31,-.05),.057,.092,steel)
		coil.rotation=Vector3(PI*.5,0,.24)
		for i in 3:
			_rod(model,Vector3(-.2+i*.07,.28,.14),Vector3(-.16+i*.07,.44,.12),.017,steel)
		_box(model,Vector3(.12,.31,.12),Vector3(.17,.15,.12),dark)
		for x in [.063,.18]:
			_rod(model,Vector3(x,.39,.12),Vector3(x,.43,.12),.009,steel)
		_box(model,Vector3(-.19,.244,-.1),Vector3(.087,.009,.11),_mat("997951",7))
	_merge_static(model)
	limit_pickup_detail(area)
	var lamp_color := Color("84aaa0") if kind=="medkit" else Color("b68b48")
	var locator := _sphere(area,Vector3(0,.54,0),.022,_lamp_material(lamp_color,.8))
	locator.name="Locator"
	locator.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	locator.visibility_range_end=90.0
	return area

static func limit_pickup_detail(area: Area3D) -> void:
	for child in area.find_children("*","GeometryInstance3D",true,false):
		var geometry := child as GeometryInstance3D
		geometry.visibility_range_end=55.0
		geometry.visibility_range_end_margin=5.0
		geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func relay(index: int) -> Node3D:
	var node := Node3D.new()
	node.name="RadioRelay%02d"%index
	node.set_meta("index",index)
	node.set_meta("active",false)
	var model := _group(node,"RelayStructure")
	var steel := _mat("777464",3,.84,.55)
	var rusty := _mat("68422b",2,.9,.45)
	var black := _mat("262a27",4)
	_box(model,Vector3(0,.07,0),Vector3(.94,.14,.82),_mat("857965",1))
	for x in [-.35,.35]:
		for z in [-.28,.28]:
			_rod(model,Vector3(x,.14,z),Vector3(x*.34,1.24,z*.34),.025,rusty)
			_box(model,Vector3(x,.153,z),Vector3(.1,.027,.1),steel)
	_shape(model,Vector3.ZERO,Equipment.formed_shell([Vector4(-.22,.29,.42,.68),Vector4(-.19,.315,.455,.68),Vector4(.19,.315,.455,.68),Vector4(.22,.29,.42,.68)],20),steel)
	for z in [-.14,.14]:
		for x in [-.32,.32]:
			_rod(model,Vector3(x,.4,z),Vector3(x,.98,z),.018,rusty)
	_box(model,Vector3(0,.72,-.231),Vector3(.53,.73,.022),_mat("5c6559",3,.9,.25))
	_box(model,Vector3(0,.914,-.253),Vector3(.38,.2,.02),black)
	for i in 6:
		_box(model,Vector3(0,.4+i*.035,-.251),Vector3(.39,.012,.019),black)
	for x in [-.235,.235]:
		for y in [.38,1.04]: _sphere(model,Vector3(x,y,-.258),.011,rusty)
	_rod(model,Vector3(.15,.65,-.27),Vector3(.15,.8,-.27),.014,black)
	_rod(model,Vector3(0,1.03,0),Vector3(0,2.95,0),.036,steel)
	_rod(model,Vector3(-.39,1.2,0),Vector3(.39,1.2,0),.018,rusty)
	_rod(model,Vector3(-.39,1.2,0),Vector3(0,2.08,0),.014,rusty)
	_rod(model,Vector3(.39,1.2,0),Vector3(0,2.08,0),.014,rusty)
	_rod(model,Vector3(-.78,2.76,0),Vector3(.78,2.76,0),.016,steel)
	for i in 5:
		var x := -.64+i*.32
		var span := .4-absf(x)*.14
		_rod(model,Vector3(x,2.76,-span),Vector3(x,2.76,span),.01,steel)
	_box(model,Vector3(0,2.735,0),Vector3(.13,.1,.12),black)
	_rod(model,Vector3(.05,1.14,.06),Vector3(.05,2.67,.06),.009,black)
	for y in [1.38,1.88,2.38]: _ring(model,Vector3(0,y,0),.038,.05,rusty)
	_box(model,Vector3(-.22,1.22,-.03),Vector3(.17,.18,.16),black)
	# A real shallow parabolic receiver with ribs replaces a flat plate detail.
	var dish_v := PackedVector3Array()
	var dish_i := PackedInt32Array()
	for row in 7:
		var radius := .012+.32*row/6.0
		for segment in 33:
			var angle := float(segment)*TAU/32
			dish_v.append(Vector3(.46+cos(angle)*radius,1.72+sin(angle)*radius,.03-radius*radius*.7))
			if row<6 and segment<32:
				var k := row*33+segment
				dish_i.append_array([k,k+33,k+34,k,k+34,k+1])
	_surface(model,dish_v,dish_i,steel,true)
	_rod(model,Vector3(.46,1.72,-.02),Vector3(.46,1.72,-.25),.012,rusty)
	_rod(model,Vector3(0,1.4,0),Vector3(.46,1.72,0),.024,steel)
	_merge_static(model)
	_collider(node,Vector3(0,.58,0),Vector3(.72,1.16,.56))
	var lamp := _sphere(node,Vector3(-.22,1.3,-.03),.077,_lamp_material(Color("c08d44"),1.2))
	lamp.name="StatusLamp"
	var glow := OmniLight3D.new()
	glow.name="StatusGlow"
	glow.position=Vector3(-.22,1.37,-.12)
	glow.omni_range=1.8
	glow.light_energy=.24
	node.add_child(glow)
	var label := _label(node,"",Vector3(0,1.84,0),42,.0024,Color("c8a06a"),true)
	label.name="StatusLabel"
	set_relay_active(node,false)
	return node

static func set_relay_active(node: Node3D, active: bool) -> void:
	node.set_meta("active",active)
	var color := Color("72b6b0") if active else Color("bd8b4e")
	var lamp := node.get_node_or_null("StatusLamp") as MeshInstance3D
	if lamp: lamp.material_override=_lamp_material(color,1.15 if active else .75)
	var glow := node.get_node_or_null("StatusGlow") as OmniLight3D
	if glow: glow.light_color=color
	var label := node.get_node_or_null("StatusLabel") as Label3D
	if label:
		label.text="RELAY %02d\n%s"%[int(node.get_meta("index",1)),"ONLINE" if active else "OFFLINE"]
		label.modulate=color

static func shelter(is_base: bool=false) -> Node3D:
	var node := Node3D.new()
	node.name="FieldBase" if is_base else "StormShelter"
	node.set_meta("is_base",is_base)
	node.set_meta("shelter_radius",2.3)
	var model := _group(node,"CanopyStructure")
	var steel := _mat("5f5d4c",3,.9,.45)
	var dark := _mat("454339",4)
	var canvas := _mat("716449" if is_base else "655d46",7,.99)
	for x in [-2.33,2.33]:
		for z in [-2.33,2.33]:
			_rod(model,Vector3(x,.04,z),Vector3(x,2.96,z),.043,steel)
			_box(model,Vector3(x,.032,z),Vector3(.25,.064,.25),steel)
			_collider(node,Vector3(x,1.5,z),Vector3(.13,3,.13))
			_rod(model,Vector3(x,2.78,z),Vector3(x*1.18,.03,z*1.18),.009,dark)
			_rod(model,Vector3(x*1.18,0,z*1.18),Vector3(x*1.18,.24,z*1.18),.016,steel)
	for z in [-2.33,2.33]: _rod(model,Vector3(-2.33,2.96,z),Vector3(2.33,2.96,z),.027,steel)
	for x in [-2.33,0.0,2.33]:
		var y := 3.13 if x==0 else 2.96
		_rod(model,Vector3(x,y,-2.33),Vector3(x,y,2.33),.027,steel)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const STEPS := 24
	for row in STEPS+1:
		for col in STEPS+1:
			var x := lerpf(-2.54,2.54,col/float(STEPS))
			var z := lerpf(-2.54,2.54,row/float(STEPS))
			var y := 2.99+.23*(1.0-absf(x)/2.54)-.12*sin(col*PI/STEPS)*sin(row*PI/STEPS)
			var attachment := minf(absf(x),minf(absf(x-2.33),absf(x+2.33)))
			y+=.024*sin(z*5.6+x*.5)*smoothstep(0.0,.7,attachment)+.008*sin(z*11.0)*absf(x)/2.54
			if row==0 or row==STEPS: y-=.035+.021*sin(x*9.4)
			vertices.append(Vector3(x,y,z))
			if row<STEPS and col<STEPS:
				var k := row*(STEPS+1)+col
				indices.append_array([k,k+1,k+STEPS+1,k+1,k+STEPS+2,k+STEPS+1])
	_surface(model,vertices,indices,canvas,true)
	for z in [-2.5,2.5]:
		for x in [-2.0,-1.0,0.0,1.0,2.0]:
			var seam_y := 2.98+.18*(1.0-absf(x)/2.54)
			_box(model,Vector3(x,seam_y,z),Vector3(.07,.008,.13),_mat("928269",7))
	if is_base:
		var wood := _mat("736048",7)
		_box(model,Vector3(1.8,.29,1.93),Vector3(.88,.58,.63),wood)
		for x in [1.46,2.14]: _box(model,Vector3(x,.3,1.605),Vector3(.045,.61,.02),steel)
		for y in [.09,.5]: _box(model,Vector3(1.8,y,1.595),Vector3(.93,.04,.025),steel)
		_box(model,Vector3(2.20,1.85,2.28),Vector3(.58,.51,.018),canvas)
		var paint := _mat("c0bca3",7)
		for sign_z in [2.263,2.297]:
			_box(model,Vector3(2.20,1.85,sign_z),Vector3(.33,.075,.009),paint)
			_box(model,Vector3(2.20,1.85,sign_z),Vector3(.078,.32,.009),paint)
		_label(node,"FIELD BASE",Vector3(0,3.43,0),52,.003,Color("c1b291"),true)
	else:
		_label(node,"STORM SHELTER",Vector3(0,3.4,0),44,.0026,Color("b6ae98"),true)
	_merge_static(model)
	var lantern := _sphere(node,Vector3(0,2.8,-2.13),.068,_lamp_material(Color("c1a06b"),1.3))
	lantern.name="CanopyLantern"
	return node

static func extraction() -> Node3D:
	var node := Node3D.new()
	node.name="ExtractionPad"
	node.set_meta("radius",1.6)
	var model := _group(node,"PadStructure")
	var steel := _mat("655e4c",3,.88,.4)
	var mark := _mat("b1a184",7,.95)
	_cylinder(model,Vector3(0,.018,0),1.59,.036,_mat("7e725e",1))
	# Radial load-bearing deck plates, recessed joints and bolted lifting points.
	for section in 8:
		var angle := float(section)*TAU/8
		var panel := _box(model,Vector3(cos(angle)*.78,.047,sin(angle)*.78),Vector3(.64,.035,.38),steel)
		panel.rotation.y=-angle
		for offset in [-.19,.19]:
			var p := Vector3(.83+offset,.07,0).rotated(Vector3.UP,-angle)
			_cylinder(model,p,.017,.008,mark)
	var rim := _ring(model,Vector3(0,.045,0),1.3,1.45,steel)
	rim.scale.y=.13
	for i in 12:
		var angle := i*TAU/12.0
		var dash := _box(model,Vector3(cos(angle)*1.41,.064,sin(angle)*1.41),Vector3(.19,.009,.062),mark)
		dash.rotation.y=-angle+PI*.5
	_box(model,Vector3(0,.045,0),Vector3(.1,.012,1.45),mark)
	for z in [-.675,.675]: _box(model,Vector3(0,.045,z),Vector3(1.18,.012,.1),mark)
	for x in [-1.32,1.32]:
		for z in [-1.32,1.32]:
			_box(model,Vector3(x,.066,z),Vector3(.25,.13,.25),steel)
			_cylinder(model,Vector3(x,.205,z),.072,.19,steel)
			_sphere(model,Vector3(x,.327,z),.075,_lamp_material(Color("aab594"),.8))
			for offset in [-.081,.081]: _rod(model,Vector3(x+offset,.25,z),Vector3(x+offset,.4,z),.008,steel)
			_rod(model,Vector3(x-.081,.4,z),Vector3(x+.081,.4,z),.008,steel)
	_merge_static(model)
	_label(node,"EXTRACTION",Vector3(0,1.55,0),42,.0025,Color("b8b8a0"),true)
	return node

static func _mat(hex: String, kind: int, rough: float=.95, metal: float=0.0) -> ShaderMaterial:
	var key := "%s/%d/%f/%f"%[hex,kind,rough,metal]
	if _materials.has(key): return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader=SURFACE
	mat.set_shader_parameter("base_color",Color(hex))
	mat.set_shader_parameter("kind",float(kind))
	mat.set_shader_parameter("roughness_value",rough)
	mat.set_shader_parameter("metal_value",metal)
	_materials[key]=mat
	return mat

static func _lamp_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color*.55
	mat.roughness=.46
	mat.emission_enabled=true
	mat.emission=color
	mat.emission_energy_multiplier=energy
	return mat

static func _group(parent: Node3D, label: String) -> Node3D:
	var node := Node3D.new()
	node.name=label
	parent.add_child(node)
	return node

static func _shape(parent: Node3D, pos: Vector3, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=mat
	node.position=pos
	parent.add_child(node)
	return node

static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := Equipment.beveled_box(size,minf(.018,minf(size.x,minf(size.y,size.z))*.15))
	return _shape(parent,pos,mesh,mat)

static func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius=radius
	mesh.height=radius*2
	mesh.radial_segments=16
	mesh.rings=8
	return _shape(parent,pos,mesh,mat)

static func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=24
	return _shape(parent,pos,mesh,mat)

static func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var node := _cylinder(parent,(a+b)*.5,radius,a.distance_to(b),mat)
	node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return node

static func _ring(parent: Node3D, pos: Vector3, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius=inner
	mesh.outer_radius=outer
	mesh.rings=36
	mesh.ring_segments=10
	return _shape(parent,pos,mesh,mat)

static func _collider(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=1
	body.position=pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	parent.add_child(body)

static func _label(parent: Node3D, words: String, pos: Vector3, font_size: int, pixel_size: float, color: Color, billboard: bool) -> Label3D:
	var label := Label3D.new()
	label.text=words
	label.font_size=font_size
	label.pixel_size=pixel_size
	label.position=pos
	label.modulate=color
	label.outline_modulate=Color("272823")
	label.outline_size=4
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	label.visibility_range_end=48.0 if billboard else 8.0
	parent.add_child(label)
	return label

static func _surface(parent: Node3D, vertices: PackedVector3Array, indices: PackedInt32Array, mat: Material, double_sided: bool=false) -> void:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,indices.size(),3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		var n := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a]+=n
		normals[b]+=n
		normals[c]+=n
	for i in normals.size(): normals[i]=normals[i].normalized()
	if double_sided:
		var base := vertices.size()
		vertices.append_array(vertices)
		var reverse_normals := PackedVector3Array()
		for n in normals: reverse_normals.append(-n)
		normals.append_array(reverse_normals)
		var reverse_indices := PackedInt32Array()
		for i in range(0,indices.size(),3): reverse_indices.append_array([base+indices[i],base+indices[i+2],base+indices[i+1]])
		indices.append_array(reverse_indices)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_shape(parent,Vector3.ZERO,mesh,mat)

static func _merge_static(group: Node3D) -> void:
	# Collapse decorative primitives into one mesh per shared material.
	# Stateful lamps, labels and collision shapes stay outside these groups.
	var batches: Dictionary = {}
	for child in group.get_children():
		var source := child as MeshInstance3D
		if not source: continue
		var material := source.material_override
		var key := material.get_instance_id()
		if not batches.has(key):
			batches[key]={"mat":material,"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"indices":PackedInt32Array()}
		var batch: Dictionary=batches[key]
		var arrays := source.mesh.surface_get_arrays(0)
		var base: int=batch.vertices.size()
		var normal_basis := source.transform.basis.inverse().transposed()
		for point in arrays[Mesh.ARRAY_VERTEX]: batch.vertices.append(source.transform*point)
		for normal in arrays[Mesh.ARRAY_NORMAL]: batch.normals.append((normal_basis*normal).normalized())
		for index in arrays[Mesh.ARRAY_INDEX]: batch.indices.append(base+index)
		source.free()
	for key in batches:
		var batch: Dictionary=batches[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=batch.vertices
		arrays[Mesh.ARRAY_NORMAL]=batch.normals
		arrays[Mesh.ARRAY_INDEX]=batch.indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		_shape(group,Vector3.ZERO,mesh,batch.mat)
