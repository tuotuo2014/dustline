extends Node3D
## Navigable 3D desert overpass, arranged to match reference/overpass-reference.png.
const SURFACE = preload("res://wasteland_surface.gdshader")
const SKY = preload("res://wasteland_sky.gdshader")
const Geometry = preload("res://environment_geometry.gd")
const Layout = preload("res://world_layout.gd")
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}
var bridge: Node3D
@export_range(0,3) var region_id := 0

func _ready() -> void:
	rng.seed=71903
	_make_materials()
	_lighting()
	_terrain()
	if region_id==0:
		_overpass()
		_set_dressing()
		_roads_and_trails()
		preload("res://wasteland_districts.gd").build(self)
		_open_country()
	else:
		_reference_region()
	_batch_static_geometry() 
	set_region_atmosphere(region_id)

func _make_materials() -> void:
	materials.sand=_material("aa8a64",0)
	materials.concrete=_material("999589",1)
	materials.red_paint=_material("703b26",2,.83,.35)
	materials.white_paint=_material("999783",3,.84,.36)
	materials.rubber=_material("282722",4)
	materials.stone=_material("77756b",5)
	materials.asphalt=_material("35332d",6)
	materials.rebar=_material("4d3421",2,.89,.60)
	materials.metal=_material("514b3d",3,.77,.60)
	materials.grass=_material("69583b",7)
	materials.glass=_material("262f2b",7,.37,.12)
	materials.black=_material("1c201d",4)
	# Landmark-specific surfaces keep brick, timber and faded road paint visually distinct.
	materials.brick=_material("704b3d",8,.91,.05)
	materials.wood=_material("5b493a",9,.96,.0)
	materials.roadmark=_material("b7a78a",10,.88,.0)

func _material(hex: String, kind: int, rough := .94, metal := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=SURFACE
	mat.set_shader_parameter("base_color",Color(hex))
	mat.set_shader_parameter("kind",float(kind))
	mat.set_shader_parameter("roughness_value",rough)
	mat.set_shader_parameter("metal_value",metal)
	return mat

func _lighting() -> void:
	var sun_direction := Vector3(-.53,.22,-.82).normalized()
	var sun := DirectionalLight3D.new()
	sun.name="Sunset"
	add_child(sun)
	sun.look_at_from_position(sun_direction*100,Vector3.ZERO)
	sun.light_color=Color("ffe0b0")
	sun.light_energy=1.95
	sun.light_angular_distance=.8
	sun.shadow_enabled=true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance=100
	sun.shadow_bias=.035
	sun.shadow_normal_bias=1.0
	var env := Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader=SKY
	sky_mat.set_shader_parameter("sun_direction",sun_direction)
	sky.sky_material=sky_mat
	sky.radiance_size=Sky.RADIANCE_SIZE_256
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy=.65
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure=1.05
	env.ssao_enabled=true
	env.ssao_radius=1.4
	env.ssao_intensity=1.5
	env.ssil_enabled=false
	env.ssil_radius=4
	env.ssil_intensity=.65
	env.glow_enabled=true
	env.glow_intensity=.55
	env.glow_bloom=.035
	env.glow_hdr_threshold=1.8
	env.volumetric_fog_enabled=true
	env.volumetric_fog_density=.0010
	env.volumetric_fog_albedo=Color("c5bbaa")
	env.volumetric_fog_length=150
	env.volumetric_fog_ambient_inject=.6
	env.fog_enabled=true
	env.fog_density=.0005
	env.fog_light_color=Color("aca392")
	env.fog_sky_affect=.15
	var environment := WorldEnvironment.new()
	environment.name="DesertAtmosphere"
	environment.environment=env
	add_child(environment)

func ground_height(x: float, z: float) -> float:
	if region_id>0:
		# Local flat district floor; surrounding dunes close its own horizon.
		var rim := smoothstep(108.0,158.0,maxf(absf(x),absf(z)))
		var dune_crest := _crescent_dune(x,z,Vector2(126,-22),Vector2(32,73),10.0)+_crescent_dune(-x,z,Vector2(133,43),Vector2(41,61),13.0)
		var scarp := smoothstep(116.0,134.0,absf(z))*(3.0+2.0*sin(x*.09+sin(z*.08)))
		return 2.5+rim*(12.0+sin(x*.037+z*.014)*4.0+sin(z*.046-x*.021)*2.5)+dune_crest+scarp
	# The spawn and central exploration corridor are level; dunes rise at the sides.
	var bank := smoothstep(7.0,28.0,absf(x))
	var near := bank*(.52+sin(x*.068+z*.027)*.58+sin(z*.085-x*.018)*.38+sin(x*.23+z*.08)*.055)
	var edge := smoothstep(125.0,245.0,maxf(absf(x),absf(z)))
	var rolling := (1.1+sin(x*.021+z*.008)*.65+sin(z*.029-x*.009)*.5)*edge*3.6
	# A smooth rampart beyond the traversable land forms a natural distant horizon.
	var rim := smoothstep(218.0,310.0,maxf(absf(x),absf(z)))
	var ridges := rim*(14.0+sin(x*.037+z*.014)*7.0+sin(z*.046-x*.021)*4.5)
	var sculpted := _crescent_dune(x,z,Vector2(-174,12),Vector2(25,56),3.6)+_crescent_dune(x,z,Vector2(175,-9),Vector2(23,44),3.2)
	var drainage := -smoothstep(130.0,158.0,absf(x))*.60*exp(-pow((z-36.0-sin(x*.034)*11.0)/4.5,2.0))
	return near+bank*(rolling+ridges)+sculpted+drainage

func _crescent_dune(x: float, z: float, center: Vector2, footprint: Vector2, height: float) -> float:
	var q := Vector2((x-center.x)/footprint.x,(z-center.y)/footprint.y)
	if absf(q.x)>1.4 or absf(q.y)>1.0: return 0.0
	# Bowed crest, long windward slope and short leeward slip face form a barchan.
	var crest := .26*(1.0-q.y*q.y)
	var along := q.x-crest
	var slope := maxf(0.0,1.0-absf(along)/(.36 if along>0.0 else 1.16))
	var tapered := pow(maxf(0.0,1.0-q.y*q.y),1.5)
	return height*slope*slope*(3.0-2.0*slope)*tapered

func _terrain() -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var cells := 256 if region_id==0 else 128
	var size := Layout.TERRAIN_SIZE if region_id==0 else 320.0
	# Alternating offsets remove the old square tessellation; a sampled cell centre
	# carries each crest/erosion valley into both rendered and collidable geometry.
	for row in cells+1:
		for col in cells+1:
			var x := (col/float(cells)-.5)*size
			var z := (row/float(cells)-.5)*size
			if col>0 and col<cells: x+=sin(row*1.73+col*.71)*size/cells*.12
			if row>0 and row<cells: z+=sin(col*1.39-row*.57)*size/cells*.12
			vertices.append(Vector3(x,ground_height(x,z),z))
	for row in cells:
		for col in cells:
			var k := row*(cells+1)+col
			var corners := [k,k+1,k+cells+2,k+cells+1]
			var center := Vector3.ZERO
			for corner: int in corners: center+=vertices[corner]*.25
			center.y=ground_height(center.x,center.z)
			var c := vertices.size()
			vertices.append(center)
			for i in 4: indices.append_array([corners[i],corners[(i+1)%4],c])
	var ground := _surface(self,"SandDunes",vertices,indices,materials.sand)
	ground.set_meta("terrain_topology","staggered_center_fan_barchan_erosion")
	var floor_body := StaticBody3D.new()
	floor_body.name="TerrainCollision"
	var shape := CollisionShape3D.new()
	shape.shape=ground.mesh.create_trimesh_shape()
	floor_body.add_child(shape)
	add_child(floor_body)

func _overpass() -> void:
	bridge=Node3D.new()
	bridge.name="BrokenOverpass"
	bridge.position.x=7
	bridge.rotation.y=.22
	add_child(bridge)
	_bridge_span(-11,85,true)
	_bridge_span(-125,-29,false)
	for z in [-112.0,-87.0,-62.0,-37.0,2.0,27.0,52.0,77.0]:
		_box(bridge,"PierCap",Vector3(0,7.65,z),Vector3(10.2,1.3,2.25),materials.concrete,true)
		for x in [-3.3,3.3]:
			_box(bridge,"BridgePier",Vector3(x,3.62,z),Vector3(1.45,7.25,1.75),materials.concrete,true)
			_box(bridge,"PierFooting",Vector3(x,.1,z),Vector3(2.4,.3,2.55),materials.concrete,true)
			_box(bridge,"Bearing",Vector3(x,8.4,z),Vector3(1.65,.23,1.94),materials.black)

func _bridge_span(start: float, end: float, broken_at_start: bool) -> void:
	var solid_start := start+2.2 if broken_at_start else start
	var solid_end := end if broken_at_start else end-2.2
	var center := (solid_start+solid_end)*.5
	var length := solid_end-solid_start
	_box(bridge,"ConcreteDeck",Vector3(0,9.52,center),Vector3(10.8,.64,length),materials.concrete,true)
	_box(bridge,"RoadSurface",Vector3(0,9.862,center),Vector3(9.65,.044,length),materials.asphalt)
	for x in [-4.2,-2.1,0.0,2.1,4.2]:
		_box(bridge,"BridgeGirder",Vector3(x,8.76,center),Vector3(.42,1.0,length),materials.concrete)
		_box(bridge,"GirderFoot",Vector3(x,8.3,center),Vector3(.84,.16,length),materials.concrete)
	for side in [-1.0,1.0]:
		_box(bridge,"Parapet",Vector3(side*5.23,10.17,center),Vector3(.36,.8,length),materials.concrete)
		_rod(bridge,Vector3(side*5.22,10.88,solid_start),Vector3(side*5.22,10.88,solid_end),.046,materials.rebar)
		for z in range(int(solid_start)+1,int(solid_end),5):
			_rod(bridge,Vector3(side*5.22,10.52,z),Vector3(side*5.22,10.9,z),.033,materials.rebar)
	var edge_z := start if broken_at_start else end
	var direction := -1.0 if broken_at_start else 1.0
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in 19:
		var x := -5.4+i*.6
		var jagged := rng.randf_range(-.85,.7)
		var front_z := edge_z+direction*jagged
		var back_z := solid_start if broken_at_start else solid_end
		vertices.append_array([Vector3(x,9.84,front_z),Vector3(x,9.84,back_z),Vector3(x,9.2,front_z-direction*.25),Vector3(x,9.2,back_z)])
		if i<18:
			var k := i*4
			indices.append_array([k,k+4,k+5,k,k+5,k+1,k+2,k+7,k+6,k+2,k+3,k+7,k,k+2,k+6,k,k+6,k+4])
	var fracture := _surface(bridge,"FracturedDeckEdge",vertices,indices,materials.concrete,true)
	# Reinforcement protrudes from concrete; all fragments rest on the structure or ground.
	for i in 26:
		var x := rng.randf_range(-5.2,5.2)
		var y := rng.randf_range(9.21,9.8)
		var p := Vector3(x,y,edge_z)
		var tip := p+Vector3(rng.randf_range(-.4,.4),rng.randf_range(-1.0,.3),direction*rng.randf_range(.7,2.6))
		_rod(bridge,p,p.lerp(tip,.57)+Vector3(0,.12,0),.018,materials.rebar)
		_rod(bridge,p.lerp(tip,.57)+Vector3(0,.12,0),tip,.018,materials.rebar)
	for i in 13:
		var p := Vector3(rng.randf_range(-5,5),9.08,edge_z+direction*rng.randf_range(-.7,.1))
		_chunk(bridge,p,Vector3(rng.randf_range(.35,.9),rng.randf_range(.25,.65),rng.randf_range(.4,1)),materials.concrete)
	for x in [-4.2,-2.1,0.0,2.1,4.2]:
		_chunk(bridge,Vector3(x,8.25,edge_z-direction*.9),Vector3(.85,.7,2.4),materials.concrete)

func _set_dressing() -> void:
	# Fixed landmarks establish the reference composition; scatter fills the gaps.
	_car(Vector3(10.2,0,0),-.12,materials.red_paint)
	_car(Vector3(19.5,0,10),-.42,materials.white_paint)
	_car(Vector3(15,0,-7),.25,materials.red_paint)
	_car(Vector3(3,0,-31),-.2,materials.white_paint)
	_car(Vector3(-6,0,-47),.75,materials.red_paint)
	_car(Vector3(26,0,-18),1.9,materials.red_paint)
	_sign(Vector3(16.6,0,3),-.25,-.10,"DEAD END")
	_sign(Vector3(4.5,0,-14),.32,.35,"ROUTE 07")
	_pipe(Vector3(-8,0,9),.64,2.4,Vector3(0,.2,PI*.5))
	_pipe(Vector3(-12,0,-5),.40,1.7,Vector3(.25,.6,PI*.5))
	_tire(self,Vector3(15,ground_height(15,14)+.15,14),.63,true)
	_tire(self,Vector3(-5,ground_height(-5,-7)+.40,-7),.47,false)
	_industrial_tanks(Vector3(-40,0,-52))
	for center in [Vector3(5,0,-12),Vector3(12,0,-3),Vector3(-4,0,-26),Vector3(21,0,9),Vector3(-7,0,14)]:
		for i in 17:
			var p: Vector3=center+Vector3(rng.randf_range(-4.2,4.2),0,rng.randf_range(-3.0,3.0))
			if absf(p.x)<2: continue
			p.y=ground_height(p.x,p.z)
			var size := Vector3(rng.randf_range(.28,1.8),rng.randf_range(.14,.78),rng.randf_range(.28,1.5))
			_chunk(self,p,size,materials.concrete,size.y>.45)
	for i in 320:
		var p := Vector3(rng.randf_range(-65,65),0,rng.randf_range(-75,65))
		if absf(p.x)<2.2 and p.z>-25: continue
		p.y=ground_height(p.x,p.z)
		var s := rng.randf_range(.055,.34)
		_chunk(self,p,Vector3(s*1.7,s*.45,s),materials.stone)
	for i in 78:
		var p := Vector3(rng.randf_range(-60,60),0,rng.randf_range(-63,46))
		if absf(p.x)<3: continue
		p.y=ground_height(p.x,p.z)
		_grass(p,rng.randf_range(.22,.57))
	for i in 16:
		var p := Vector3(rng.randf_range(-25,27),0,rng.randf_range(-32,20))
		if absf(p.x)<2.4: continue
		p.y=ground_height(p.x,p.z)+.12
		var plate := _box(self,"DiscardedPanel",p,Vector3(rng.randf_range(.4,1.3),.035,rng.randf_range(.4,1.2)),materials.white_paint)
		plate.rotation=Vector3(rng.randf_range(-.25,.25),rng.randf_range(-PI,PI),rng.randf_range(-.25,.25))


func _roads_and_trails() -> void:
	# Connected, terrain-conforming old roads retain broken margins and drifting sand.
	for end in [Vector3(-90,0,-56),Vector3(99,0,-80),Vector3(-87,0,100),Vector3(10,0,-155),Vector3(118,0,118)]:
		_road_ribbon(Vector3(0,0,18),end,5.6)
	_road_ribbon(Vector3(10,0,-155),Layout.EXIT,5.0)
	for i in 10:
		var p := Vector3(-9.0+sin(i*.72)*.8,0,-142+i*29)
		p.y=ground_height(p.x,p.z)
		_box(self,"RoadsideMarker",p+Vector3(0,.48,0),Vector3(.14,.96,.14),materials.white_paint,true)
		_box(self,"RustReflector",p+Vector3(0,.78,.08),Vector3(.12,.11,.022),materials.red_paint)

func _road_ribbon(a: Vector3, b: Vector3, width: float) -> void:
	var direction := (b-a).normalized()
	var side := Vector3(-direction.z,0,direction.x)
	var segments := ceili(a.distance_to(b)/1.8)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in segments+1:
		var center := a.lerp(b,float(i)/segments)
		for j in 7:
			var across := (j/6.0-.5)*width
			if j in [0,6]: across+=(sin(i*4.76+j*1.31)*.27+sin(i*.7)*.16)
			var p := center+side*across
			p.y=ground_height(p.x,p.z)+.026
			vertices.append(p)
			if i<segments and j<6:
				var k := i*7+j
				# Missing shoulders and occasional patches expose the sand beneath.
				if (j==0 or j==5) and i%13 in [1,2,6]: continue
				if i%31==12 and j in [2,3]: continue
				indices.append_array([k,k+7,k+8,k,k+8,k+1])
	_surface(self,"WeatheredRoad",vertices,indices,materials.asphalt,true)
	for i in range(1,segments-2,5):
		var center := a.lerp(b,(i+.4)/segments)
		var paint_vertices := PackedVector3Array()
		for offset in [side*-.045-direction*.74,side*.045-direction*.74,side*.045+direction*.74,side*-.045+direction*.74]:
			var p: Vector3=center+offset
			p.y=ground_height(p.x,p.z)+.030
			paint_vertices.append(p)
		_surface(self,"FadedRoadLine",paint_vertices,PackedInt32Array([0,1,2,0,2,3]),materials.roadmark,true)

func _open_country() -> void:
	# Mid-distance dressing fills the expanded playable area while the central test corridor stays clear.
	for i in 210:
		var p := Vector3(rng.randf_range(-198,198),0,rng.randf_range(-198,198))
		if absf(p.x)<10.0 or absf(p.z)<10.0: continue
		if Layout.district_name(p)!="灰烬荒原": continue
		p.y=ground_height(p.x,p.z)+.02
		var stone_mat: Material = materials.stone if i%3 else materials.concrete
		var size := Vector3(rng.randf_range(.35,2.2),rng.randf_range(.12,1.1),rng.randf_range(.35,1.9))
		_chunk(self,p,size,stone_mat,size.y>.74)
	for i in 96:
		var p := Vector3(rng.randf_range(-190,190),0,rng.randf_range(-190,190))
		if absf(p.x)<13 or absf(p.z)<13: continue
		if Layout.district_name(p)!="灰烬荒原": continue
		p.y=ground_height(p.x,p.z)
		_grass(p,rng.randf_range(.24,.8))
	# Distant skeletal utility poles add scale to the horizon.
	for point in [Vector3(-176,0,-12),Vector3(-144,0,-92),Vector3(153,0,-130),Vector3(178,0,58),Vector3(-150,0,160)]:
		var base := Vector3(point.x,ground_height(point.x,point.z),point.z)
		_box(self,"UtilityPole",base+Vector3(0,3.8,0),Vector3(.18,7.6,.18),materials.wood,true)
		_rod(self,base+Vector3(-2.0,7.0,0),base+Vector3(2.0,7.0,0),.035,materials.rebar)
		_rod(self,base+Vector3(-1.5,7.0,0),base+Vector3(-1.5,8.3,0),.022,materials.rebar)
		_rod(self,base+Vector3(1.5,7.0,0),base+Vector3(1.5,8.3,0),.022,materials.rebar)

func _batch_static_geometry() -> void:
	# Merge static pieces per material and 32m tile. Source transforms and their collision children
	# remain intact; batching only replaces visual surfaces, never physics or landmark roots.
	var batches: Dictionary = {}
	var minimap_features: Array = []
	var sources := find_children("*","MeshInstance3D",true,false)
	for node in sources:
		var source := node as MeshInstance3D
		if source.name=="SandDunes" or source.mesh==null or source.get_meta("no_batch",false): continue
		var transform_to_root := global_transform.affine_inverse()*source.global_transform
		var center := transform_to_root*source.mesh.get_aabb().get_center()
		var tile := Vector2i(floori(center.x/32.0),floori(center.z/32.0))
		# Tiny bolts and debris need neither distant draws nor individual shadows.
		# Keep every collider and the full silhouettes of roads/buildings intact.
		var size := source.mesh.get_aabb().size*transform_to_root.basis.get_scale().abs()
		# Cache real architectural footprints before visual surfaces are merged.
		if minf(size.x,size.z)>.65 and maxf(size.x,size.z)>2.0:
			var points := PackedVector2Array()
			for corner in 8:
				var point: Vector3=transform_to_root*source.mesh.get_aabb().get_endpoint(corner)
				points.append(Vector2(point.x,point.z))
			points=Geometry2D.convex_hull(points)
			if points.size()>3:
				points.remove_at(points.size()-1)
				var bounds := Rect2(points[0],Vector2.ZERO)
				for point in points: bounds=bounds.expand(point)
				minimap_features.append({"points":points,"bounds":bounds,"road":size.y<.5})
		var extent := maxf(size.x,maxf(size.y,size.z))
		var detail := 0 if extent>.9 else (1 if extent>.25 else 2)
		for surface_index in source.mesh.get_surface_count():
			var mat: Material=source.material_override if source.material_override else source.mesh.surface_get_material(surface_index)
			if mat==null: continue
			var key := "%d_%d_%d_%d" % [tile.x,tile.y,mat.get_instance_id(),detail]
			if not batches.has(key):
				batches[key]={"mat":mat,"detail":detail,"origin":Vector3((tile.x+.5)*32,0,(tile.y+.5)*32),"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"indices":PackedInt32Array()}
			var batch: Dictionary=batches[key]
			var data := source.mesh.surface_get_arrays(surface_index)
			var offset: int=batch.vertices.size()
			var normal_basis := transform_to_root.basis.inverse().transposed()
			for point in data[Mesh.ARRAY_VERTEX]: batch.vertices.append(transform_to_root*point-batch.origin)
			for normal in data[Mesh.ARRAY_NORMAL]: batch.normals.append((normal_basis*normal).normalized())
			if data[Mesh.ARRAY_INDEX]!=null and data[Mesh.ARRAY_INDEX].size()>0:
				for index in data[Mesh.ARRAY_INDEX]: batch.indices.append(offset+index)
			else:
				for index in data[Mesh.ARRAY_VERTEX].size(): batch.indices.append(offset+index)
		source.mesh=null
	var output := Node3D.new()
	output.name="StaticWorldBatches"
	add_child(output)
	for key in batches:
		var batch: Dictionary=batches[key]
		var data := []
		data.resize(Mesh.ARRAY_MAX)
		data[Mesh.ARRAY_VERTEX]=batch.vertices
		data[Mesh.ARRAY_NORMAL]=batch.normals
		data[Mesh.ARRAY_INDEX]=batch.indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
		var instance := MeshInstance3D.new()
		instance.name="WorldTile_"+key
		instance.mesh=mesh
		instance.material_override=batch.mat
		instance.position=batch.origin
		if batch.detail>0:
			instance.visibility_range_end=95.0 if batch.detail==1 else 55.0
			instance.visibility_range_end_margin=8.0
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		output.add_child(instance)
	set_meta("minimap_features",minimap_features)
	set_meta("original_static_pieces",sources.size())
	set_meta("static_batches",batches.size())

func _car(pos: Vector3, yaw: float, paint: Material) -> void:
	var car := Node3D.new()
	car.name="WreckedSedan"
	car.position=pos+Vector3(0,ground_height(pos.x,pos.z),0)
	car.rotation.y=yaw+PI*.5
	add_child(car)
	_wreck_sedan(car,paint,Vector3(1.75,1.55,4.3))

func _vehicle_sides(parent: Node3D, width: float, length: float, top: float, wheels: Array, radius: float, mat: Material) -> void:
	# Continuous stamped body panels wrap around real wheel-arch cutouts.
	var outline := PackedVector2Array([Vector2(-length*.5,.34)])
	for wheel_z: float in wheels:
		outline.append(Vector2(wheel_z-radius,.34))
		for j in 11:
			var a := PI-j*PI/10.0
			outline.append(Vector2(wheel_z+cos(a)*radius,radius*.96+sin(a)*radius))
		outline.append(Vector2(wheel_z+radius,.34))
	outline.append_array([Vector2(length*.5,.34),Vector2(length*.5,top*.80),Vector2(length*.45,top*.94),Vector2(length*.22,top),Vector2(-length*.30,top),Vector2(-length*.47,top*.94),Vector2(-length*.5,top*.80)])
	for side in [-1.0,1.0]:
		var body := MeshInstance3D.new()
		body.name="PressedBodyWithOpenWheelArches"
		body.mesh=Geometry.extrusion(outline,.065)
		body.material_override=mat
		body.position.x=side*width*.5
		body.rotation.y=PI*.5
		parent.add_child(body)
		for wheel_z: float in wheels:
			for i in 10:
				var a := PI*i/10.0
				var b := PI*(i+1)/10.0
				_rod(parent,Vector3(side*(width*.5+.014),radius*.96+sin(a)*radius,-wheel_z+cos(a)*radius),Vector3(side*(width*.5+.014),radius*.96+sin(b)*radius,-wheel_z+cos(b)*radius),.019,materials.rebar)

func _wheel_detail(parent: Node3D, pos: Vector3, radius: float, rim: Material) -> void:
	var wheel := MeshInstance3D.new()
	wheel.name="ProfiledTireWithRecessedHub"
	wheel.mesh=Geometry.wheel(radius,radius*.57)
	wheel.material_override=materials.rubber
	wheel.position=pos
	wheel.rotation.z=PI*.5
	parent.add_child(wheel)
	var side := signf(pos.x)
	var outer := pos+Vector3(side*radius*.30,0,0)
	_disc(parent,"StampedWheelRim",outer,radius*.59,.055,rim,Vector3(0,0,PI*.5))
	_disc(parent,"RecessedAxleHub",outer+Vector3(side*.035,0,0),radius*.22,.09,materials.metal,Vector3(0,0,PI*.5))
	for i in 5:
		var a := i*TAU/5.0
		_disc(parent,"WheelLug",outer+Vector3(side*.037,cos(a)*radius*.34,sin(a)*radius*.34),radius*.045,.035,materials.rebar,Vector3(0,0,PI*.5))

func _wreck_sedan(car: Node3D, paint: Material, dimensions := Vector3(2.1,1.8,4.6)) -> void:
	var width := dimensions.x
	var length := dimensions.z
	var height := dimensions.y
	var wheel_z := length*.31
	var radius := width*.21
	var belt := height*.63
	_vehicle_sides(car,width,length,belt,[-wheel_z,wheel_z],radius*1.06,paint)
	_box(car,"UnderbodyFrame",Vector3(0,.43,0),Vector3(width*.86,.24,length*.94),materials.black,true)
	for side in [-1.0,1.0]:
		_box(car,"InnerDoorStructure",Vector3(side*width*.45,.77,0),Vector3(.09,.48,length*.38),materials.metal,true)
		for z in [-wheel_z,wheel_z]: _wheel_detail(car,Vector3(side*width*.51,radius,z),radius,materials.metal)
		for z in [-length*.27,length*.23]:
			_rod(car,Vector3(side*width*.49,belt,z),Vector3(side*width*.40,height-.07,z*.71),.041,paint)
		_rod(car,Vector3(side*width*.48,belt,-length*.015),Vector3(side*width*.41,height-.06,-length*.015),.036,materials.metal)
		_rod(car,Vector3(side*width*.50,belt,-length*.29),Vector3(side*width*.50,belt,length*.25),.022,materials.metal)
		for z in [-length*.17,length*.12]:
			_box(car,"RecessedDoorHandle",Vector3(side*(width*.5+.035),belt-.10,z),Vector3(.027,.045,.19),materials.black)
	var roof := MeshInstance3D.new()
	roof.name="CrownedSedanRoof"
	roof.mesh=Geometry.roof(Vector3(width*.86,.13,length*.43))
	roof.material_override=paint
	roof.position=Vector3(0,height-.045,-length*.01)
	car.add_child(roof)
	var hood := _box(car,"CrushedSlopingHood",Vector3(0,belt-.035,length*.365),Vector3(width*.95,.13,length*.29),paint,true)
	hood.rotation.x=.075
	var trunk := _box(car,"TaperedTrunkLid",Vector3(0,belt-.04,-length*.385),Vector3(width*.94,.12,length*.23),paint,true)
	trunk.rotation.x=-.06
	for side in [-1.0,1.0]:
		_box(car,"SeatCushion",Vector3(side*width*.23,.76,length*.04),Vector3(width*.34,.16,.48),materials.black)
		var seat := _box(car,"ReclinedSeatBack",Vector3(side*width*.23,1.02,-length*.025),Vector3(width*.34,.52,.14),materials.black)
		seat.rotation.x=-.12
		_disc(car,"HeadlampBezel",Vector3(side*width*.34,belt-.17,length*.51),.14,.085,materials.metal,Vector3(PI*.5,0,0))
		_disc(car,"MissingHeadlampLens",Vector3(side*width*.34,belt-.17,length*.523),.105,.016,materials.black,Vector3(PI*.5,0,0))
	_box(car,"InsetRadiator",Vector3(0,belt-.22,length*.507),Vector3(width*.42,.25,.05),materials.black)
	for i in 7: _box(car,"RadiatorSlat",Vector3((i-3)*width*.055,belt-.22,length*.519),Vector3(.025,.21,.02),materials.metal)
	for z in [-length*.51,length*.52]: _box(car,"BentPressedBumper",Vector3(0,.46,z),Vector3(width*1.03,.13,.17),materials.metal)
	_box(car,"RearBenchSeat",Vector3(0,.87,-length*.19),Vector3(width*.72,.32,.45),materials.black)

func _wood_crate(parent: Node3D, pos: Vector3, size: Vector3, wood: Material) -> void:
	var frame := _box(parent,"CrateCollisionEnvelope",pos+Vector3(0,size.y*.5,0),size,wood,true)
	frame.mesh=null
	var rows := maxi(3,int(size.y/.19))
	for side in [-1.0,1.0]:
		for row in rows:
			var y := (row+.5)*size.y/rows
			_box(parent,"IndividualCratePlank",pos+Vector3(0,y,side*(size.z*.5-.025)),Vector3(size.x-.07,size.y/rows-.012,.055),wood)
			_box(parent,"EndGrainCratePlank",pos+Vector3(side*(size.x*.5-.025),y,0),Vector3(.055,size.y/rows-.012,size.z-.10),wood)
		for x in [-.38,.38]:
			_box(parent,"CrateCornerCleat",pos+Vector3(size.x*x,size.y*.5,side*(size.z*.5+.016)),Vector3(.065,size.y,.040),materials.metal)
	for i in 5:
		_box(parent,"SpacedCrateLidBoard",pos+Vector3((i-2)*size.x/5.0,size.y-.025,0),Vector3(size.x/5.0-.012,.055,size.z),wood)

func _tire(parent: Node3D, pos: Vector3, radius: float, flat: bool) -> void:
	var tire := MeshInstance3D.new()
	tire.name="DiscardedProfiledTire"
	tire.position=pos
	if not flat: tire.rotation.x=PI*.5
	tire.mesh=Geometry.wheel(radius,radius*.65)
	tire.material_override=materials.rubber
	parent.add_child(tire)

func _pipe(pos: Vector3, radius: float, length: float, rotation: Vector3) -> void:
	var pipe := Node3D.new()
	pipe.name="RustedPipe"
	pipe.position=pos+Vector3(0,ground_height(pos.x,pos.z)+radius,0)
	pipe.rotation=rotation
	add_child(pipe)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in 4:
		var r := radius if row<2 else radius-.065
		var y := -length*.5 if row%2==0 else length*.5
		for i in 49:
			var a := TAU*i/48
			vertices.append(Vector3(cos(a)*r,y,sin(a)*r))
	for i in 48:
		indices.append_array([i,i+1,i+50,i,i+50,i+49,98+i,147+i,148+i,98+i,148+i,99+i,i,98+i,99+i,i,99+i,i+1,49+i,50+i,148+i,49+i,148+i,147+i])
	_surface(pipe,"HollowPipe",vertices,indices,materials.white_paint,true)

func _sign(pos: Vector3, yaw: float, tilt: float, words: String) -> void:
	var sign_node := Node3D.new()
	sign_node.position=pos+Vector3(0,ground_height(pos.x,pos.z),0)
	sign_node.rotation=Vector3(0,yaw,tilt)
	sign_node.name="RoadSign"
	add_child(sign_node)
	for x in [-.47,.47]: _rod(sign_node,Vector3(x,0,0),Vector3(x,2.5,0),.031,materials.rebar)
	_box(sign_node,"SignPanel",Vector3(0,2.28,0),Vector3(1.74,.97,.049),materials.white_paint,true)
	_box(sign_node,"FadedEnamel",Vector3(0,2.28,.03),Vector3(1.64,.87,.009),materials.red_paint)
	var text := Label3D.new()
	text.text=words+"\nNO THROUGH ROAD"
	text.font_size=58
	text.pixel_size=.0024
	text.modulate=Color("aea28b")
	text.position=Vector3(0,2.29,.044)
	sign_node.add_child(text)

func _industrial_tanks(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name="AbandonedTankFarm"
	root.position=pos
	add_child(root)
	for i in 3:
		var p := Vector3(i*5.0,2.8,0)
		_disc(root,"StorageTank",p,2.1,5.6,materials.white_paint,Vector3.ZERO)
		for j in 20:
			var a := TAU*j/20.0
			_rod(root,p+Vector3(cos(a)*2,2.8,sin(a)*2),p+Vector3(cos(a)*2,3.25,sin(a)*2),.035,materials.rebar)
		for j in 20:
			var a := TAU*j/20.0
			var b := TAU*(j+1)/20.0
			_rod(root,p+Vector3(cos(a)*2,3.25,sin(a)*2),p+Vector3(cos(b)*2,3.25,sin(b)*2),.035,materials.rebar)
	_disc(root,"Silo",Vector3(-4,5.1,1),.8,10.2,materials.concrete,Vector3.ZERO)

func _grass(pos: Vector3, height: float) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var plant_rng := RandomNumberGenerator.new()
	plant_rng.seed=hash(str(pos))
	# Bent, keeled leaves have a continuous arched silhouette and taper to sharp tips.
	for leaf in 18:
		var angle := plant_rng.randf_range(0,TAU)
		var outward := Vector3(cos(angle),0,sin(angle))
		var lateral := Vector3(-sin(angle),0,cos(angle))
		var rise := height*plant_rng.randf_range(.55,1.20)
		var lean := height*plant_rng.randf_range(.35,.82)
		var root := outward*plant_rng.randf_range(0,height*.10)
		var offset := vertices.size()
		for segment in 7:
			var t := segment/6.0
			var center := root+outward*lean*t*t+Vector3.UP*rise*(t-.25*t*t)
			var width := height*.029*(1.0-t)*(.5+sin(t*PI)*.65)+.0003
			vertices.append_array([pos+center-lateral*width,pos+center+Vector3.UP*width*.55,pos+center+lateral*width])
			if segment<6:
				var k := offset+segment*3
				indices.append_array([k,k+3,k+4,k,k+4,k+1,k+1,k+4,k+5,k+1,k+5,k+2])
	# Three dry branched stems with seed pods distinguish scrub from flat grass cards.
	for branch in 3:
		var angle := branch*TAU/3.0+.35
		var out := Vector3(cos(angle),0,sin(angle))
		for segment in 5:
			var a := Vector3.UP*height*segment*.21+out*height*pow(segment/5.0,2.0)*.19
			var b := Vector3.UP*height*(segment+1)*.21+out*height*pow((segment+1)/5.0,2.0)*.19
			_plant_tube(vertices,indices,pos+a,pos+b,height*.010*(1.0-segment*.13))
			if segment>1:
				var twig := b+out*height*.22+Vector3.UP*height*.08
				_plant_tube(vertices,indices,pos+b,pos+twig,height*.006)
				_plant_tube(vertices,indices,pos+twig,pos+twig+Vector3.UP*height*.09,height*.024)
	var plant := _surface(self,"CurvedLeafDryScrub",vertices,indices,materials.grass,true)
	plant.set_meta("botanical_mesh",true)

func _plant_tube(vertices: PackedVector3Array, indices: PackedInt32Array, a: Vector3, b: Vector3, radius: float) -> void:
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.RIGHT).normalized()
	var other := axis.cross(side).normalized()
	var offset := vertices.size()
	for row in 2:
		for i in 5:
			var angle := i*TAU/5.0
			vertices.append((a if row==0 else b)+(side*cos(angle)+other*sin(angle))*radius*(1.0 if row==0 else .52))
	for i in 5:
		var next := (i+1)%5
		indices.append_array([offset+i,offset+next,offset+next+5,offset+i,offset+next+5,offset+i+5])

func _chunk(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, collide := false) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const SIDES := 7
	for row in 3:
		for i in SIDES:
			var angle := TAU*i/SIDES
			var factor := rng.randf_range(.68,1.0)*(.45 if row==2 else 1.0)
			vertices.append(Vector3(cos(angle)*size.x*.5*factor,size.y*row*.5,sin(angle)*size.z*.5*factor))
			if row<2:
				var k := row*SIDES+i
				var next := row*SIDES+(i+1)%SIDES
				indices.append_array([k,next,next+SIDES,k,next+SIDES,k+SIDES])
	for i in range(1,SIDES-1): indices.append_array([SIDES*2,SIDES*2+i,SIDES*2+i+1])
	var mesh := MeshInstance3D.new()
	mesh.name="AngularMasonryFragment"
	mesh.mesh=Geometry.faceted(vertices,indices)
	mesh.material_override=mat
	parent.add_child(mesh)
	mesh.position=pos
	mesh.rotation.y=rng.randf_range(-PI,PI)
	if collide:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		collision.shape=mesh.mesh.create_convex_shape()
		body.add_child(collision)
		mesh.add_child(body)

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material, collide := false) -> MeshInstance3D:
	var mesh: ArrayMesh=Geometry.solid(size,label)
	var instance := MeshInstance3D.new()
	instance.name=label
	instance.mesh=mesh
	instance.position=pos
	instance.material_override=mat
	parent.add_child(instance)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size=size
		shape.shape=box
		body.add_child(shape)
		instance.add_child(body)
	return instance

func _rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=from.distance_to(to)
	mesh.radial_segments=24 if radius>.4 else (16 if radius>.08 else 8)
	var instance := MeshInstance3D.new()
	instance.mesh=mesh
	instance.position=(from+to)*.5
	instance.basis=Basis(Quaternion(Vector3.UP,(to-from).normalized()))
	instance.material_override=mat
	parent.add_child(instance)

func _disc(parent: Node3D, label: String, pos: Vector3, radius: float, height: float, mat: Material, rotation: Vector3) -> void:
	var mesh: ArrayMesh=Geometry.lathe(radius,height,label,40 if radius>2.0 else 24)
	var instance := MeshInstance3D.new()
	instance.name=label
	instance.mesh=mesh
	instance.position=pos
	instance.rotation=rotation
	instance.material_override=mat
	parent.add_child(instance)

func _surface(parent: Node3D, label: String, vertices: PackedVector3Array, indices: PackedInt32Array, mat: Material, double_sided := false) -> MeshInstance3D:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,indices.size(),3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		var normal := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a]+=normal
		normals[b]+=normal
		normals[c]+=normal
	for i in normals.size(): normals[i]=normals[i].normalized()
	if double_sided:
		var count := vertices.size()
		vertices.append_array(vertices)
		var back_normals := PackedVector3Array()
		for n in normals: back_normals.append(-n)
		normals.append_array(back_normals)
		var back_indices := PackedInt32Array()
		for i in range(0,indices.size(),3): back_indices.append_array([count+indices[i],count+indices[i+2],count+indices[i+1]])
		indices.append_array(back_indices)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := MeshInstance3D.new()
	instance.name=label
	instance.mesh=mesh
	instance.material_override=mat
	parent.add_child(instance)
	return instance

func set_region_atmosphere(id: int, storm: bool = false) -> void:
	var env: Environment=$DesertAtmosphere.environment
	var sun: DirectionalLight3D=$Sunset
	var sky_mat: ShaderMaterial=env.sky.sky_material
	var dusk := id==3
	var industrial := id==1
	var direction := Vector3(-.53,.10 if dusk else (.35 if industrial else .22),-.82).normalized()
	sun.look_at_from_position(direction*100,Vector3.ZERO)
	sun.light_energy=.72 if dusk else (1.55 if industrial else 1.95)
	sun.light_color=Color("ffab65") if dusk else (Color("ffe9c5") if industrial else Color("ffe0b0"))
	env.ambient_light_energy=.52 if dusk else .65
	env.tonemap_exposure=1.08 if dusk else 1.05
	env.volumetric_fog_albedo=Color("737b99") if dusk else Color("c5bbaa")
	env.fog_light_color=Color("69708f") if dusk else Color("aca392")
	env.volumetric_fog_density=.013 if storm else (.0017 if dusk else .0010)
	env.fog_density=.005 if storm else (.0007 if dusk else .0005)
	sky_mat.set_shader_parameter("sun_direction",direction)
	sky_mat.set_shader_parameter("twilight",1.0 if dusk else 0.0)
	sky_mat.set_shader_parameter("overcast",.7 if industrial else 0.0)

func _reference_region() -> void:
	var district := Node3D.new()
	district.name=["","Rustworks","BuriedCity","DuskSettlement"][region_id]
	district.set_meta("district_id",Layout.REGIONS[region_id].id)
	district.position.y=ground_height(0,0)
	add_child(district)
	# Load only the selected builder; no other destination geometry is instantiated.
	var builders := ["","res://reference_industrial.gd","res://reference_city.gd","res://reference_settlement.gd"]
	load(builders[region_id]).build(self,district)
