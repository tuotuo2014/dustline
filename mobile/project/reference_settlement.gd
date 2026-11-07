extends "res://reference_industrial.gd"
## Twilight settlement: hollow ruined shells, walk-in tin homes and occupied-looking yards.
## Dynamic cloth and embers opt out of the world's static geometry merger.

var _smoke_texture: ImageTexture

static func build(world: Node3D, district: Node3D = null) -> void:
	var root := district
	if root==null:
		root=Node3D.new()
		root.name="DuskSettlement"
		root.position=Vector3(0,world.ground_height(0,0),0)
		world.add_child(root)
	var b := new()
	b.setup(world,root,778931)
	root.set_meta("district_id","dusk_settlement")
	b._settlement()

func _settlement() -> void:
	m.tin=_dusk_material("687576",0)
	m.blue=_dusk_material("3e535b",0)
	m.red=_dusk_material("744031",0)
	m.rust=_dusk_material("795640",0)
	m.steel=_dusk_material("393f42",0)
	m.ochre=_dusk_material("8e7548",0)
	m.plaster=_dusk_material("85888b",1)
	m.lightplaster=_dusk_material("aaa69b",1)
	m.concrete=_dusk_material("92908a",1)
	m.soot=_dusk_material("3c4347",1)
	m.wood=_dusk_material("5b5145",2)
	m.brick=_dusk_material("78604d",3)
	m.linen=_dusk_material("ab9c88",2)
	site.set_meta("landmark","暮火聚落")
	site.set_meta("reference_scene","暮光下的废城棚户区")
	site.set_meta("safe_loot_positions",[Vector3(-12,0,42),Vector3(13,0,-2),Vector3(-32,0,-10),Vector3(33,0,48),Vector3(58,0,5)])
	# Dirt boulevard has real wheel-rut strips. Mission corridors stay 14m wide.
	box(site,"CompactedDirtStreet",Vector3(0,-.015,0),Vector3(14,.025,176),m.sand)
	for x in [-3.8,-2.45,2.45,3.8]:
		for z in range(-82,85,12):
			var rut := box(site,"OldWheelRut",Vector3(x+rng.randf_range(-.12,.12),.008,z),Vector3(.30,.014,rng.randf_range(7,11)),m.soot)
			rut.rotation.y=rng.randf_range(-.012,.012)
	for z in [-65.0,-22.0,23.0,68.0]:
		for side in [-1.0,1.0]:
			box(site,"ShantyAlley",Vector3(side*28,.005,z),Vector3(42,.02,4.4),m.sand)
	# Low inhabited silhouettes form the foreground; tall open shells frame the street.
	var shacks := [
		[Vector3(-21,0,53),-.08,0],[Vector3(-22,0,21),.03,1],
		[Vector3(-22,0,-17),-.045,2],[Vector3(-20,0,-59),.08,1],
		[Vector3(23,0,57),.04,2],[Vector3(22,0,19),-.04,1],
		[Vector3(22,0,-16),.03,0],[Vector3(24,0,-61),-.06,2],
		[Vector3(-66,0,37),.08,2],[Vector3(-65,0,-7),-.06,0],
		[Vector3(66,0,35),-.06,1],[Vector3(67,0,-7),.03,2]]
	for i in shacks.size():
		var entry: Array=shacks[i]
		var shack := node(site,"WalkInTinHome%02d"%i,entry[0],entry[1])
		_shack(shack,entry[2],i)
		_merge_colliders(shack)
	for info in [[Vector3(-67,0,67),4,0],[Vector3(67,0,68),5,1],
		[Vector3(-67,0,-40),6,2],[Vector3(68,0,-42),5,3],
		[Vector3(-62,0,-73),5,1],[Vector3(65,0,-76),4,0]]:
		var ruin := node(site,"HollowResidentialRuin%d_%d"%[info[0].x,info[0].z],info[0])
		_ruin(ruin,info[1],info[2])
		_merge_colliders(ruin)
	for i in 6:
		_car(node(site,"RustedStreetCar",Vector3(10.8+i%2*2.1,0,49-i*20),-.10+i*.11),i)
	_car(node(site,"BurntCourtyardVan",Vector3(-32,0,7),-.35),7)
	for z in [-62.0,-20.0,24.0,66.0]:
		for side in [-1.0,1.0]: _utility_pole(Vector3(side*10.0,0,z))
	for side in [-1.0,1.0]:
		for i in 3:
			_wire(site,Vector3(side*10,7.3,-62+i*42),Vector3(side*10,7.3,-20+i*42),1.2,.019,m.black)
	_wire(site,Vector3(-10,7.3,24),Vector3(10,7.3,24),.7,.022,m.black)
	_factory(node(site,"DistantDeadFactory",Vector3(27,0,-89)))
	for point in [Vector3(-11.8,0,58),Vector3(30,0,-10)]: _campfire(node(site,"SettlementFire",point),true)
	for i in 65:
		var sign_x := -1.0 if i%2==0 else 1.0
		var p := Vector3(sign_x*rng.randf_range(7.8,9.5),.01,rng.randf_range(-82,83))
		w._chunk(site,p,Vector3(rng.randf_range(.16,.6),.10,rng.randf_range(.13,.40)),m.concrete)
	for point in [Vector3(-3.2,.035,59),Vector3(3.5,.035,27),Vector3(-2,.035,-11),Vector3(2.2,.035,-46)]: _mud_puddle(point)
	for z in [-48.0,-5.0,31.0,70.0]:
		for side in [-1.0,1.0]:
			for i in 17:
				var point := Vector3(side*13+rng.randf_range(-1.5,1.5),.07,z+rng.randf_range(-1.5,1.5))
				var scale := rng.randf_range(.16,.52)
				w._chunk(site,point,Vector3(scale,scale*.32,scale*.7),m.concrete if i%3 else m.brick)
	label(site,"暮火聚落",Vector3(-9.5,3.7,76),36,Color("cbb092"))
	box(site,"SettlementEntranceBoard",Vector3(-9.5,3.7,75.92),Vector3(4.7,1.05,.11),m.blue)
	for x in [-11.4,-7.6]: rod(site,Vector3(x,0,75.9),Vector3(x,4.3,75.9),.06,m.rust)

func _sheet(p: Node3D, title: String, pos: Vector3, width: float, height: float, material: Material, yaw := 0.0, collide := true) -> void:
	var panel := node(p,title,pos,yaw)
	box(panel,"PatchedSheet",Vector3.ZERO,Vector3(width,height,.055),material,collide)
	for xx in [-width*.46,width*.46]:
		for yy in [-height*.43,height*.43]:
			cylinder(panel,"RoofingNail",Vector3(xx,yy,.092),.019,.016,m.steel,Vector3(PI*.5,0,0))

func _shack(p: Node3D, variant: int, index: int) -> void:
	var paint: Material=[m.tin,m.blue,m.red][variant]
	var width := 10.0+variant*.7
	var depth := 6.7
	var height := 3.1+variant*.18
	p.set_meta("walk_in",true)
	# Ground floor has no raised threshold; a 1.65m open doorway remains navigable.
	box(p,"PackedInteriorFloor",Vector3(0,.012,0),Vector3(width,.025,depth),m.wood)
	_sheet(p,"BackTinWall",Vector3(0,height*.5,-depth*.5),width,height,paint,0)
	for side in [-1.0,1.0]:
		_sheet(p,"SideTinWall",Vector3(side*width*.5,height*.5,0),depth,height,m.tin,PI*.5)
		box(p,"TimberCornerPost",Vector3(side*(width*.5-.1),height*.5,depth*.5),Vector3(.17,height,.18),m.wood,true)
	# Front wall comprises separate window sill/header/piers around a genuine open window.
	_sheet(p,"LeftFrontSheet",Vector3(-width*.5+.7,height*.5,depth*.5),1.4,height,paint)
	_sheet(p,"RightFrontSheet",Vector3(width*.5-1.35,height*.5,depth*.5),2.7,height,paint)
	_sheet(p,"WindowSillSheet",Vector3(-2.2,.57,depth*.5),2.25,1.14,paint)
	_sheet(p,"WindowHeaderSheet",Vector3(-2.2,height-.25,depth*.5),2.25,.5,paint)
	_sheet(p,"DoorLintelSheet",Vector3(.10,height-.30,depth*.5),1.7,.60,paint)
	for x in [-3.37,-1.04,-.74,.94]: box(p,"ReclaimedWindowDoorFrame",Vector3(x,height*.5,depth*.5+.045),Vector3(.13,height,.16),m.wood)
	box(p,"WindowShelf",Vector3(-2.2,1.15,depth*.5+.07),Vector3(2.48,.11,.32),m.wood)
	var shutter := box(p,"HalfDetachedWindowShutter",Vector3(-3.35,1.99,depth*.5+.35),Vector3(.88,1.36,.075),m.wood)
	shutter.rotation.y=.66
	var door := node(p,"ProppedOpenDoor",Vector3(.94,1.15,depth*.5),-.92)
	box(door,"SalvagedDoor",Vector3(-.70,0,0),Vector3(1.4,2.3,.065),m.wood,true)
	for h in [-.82,.75]: box(door,"DoorCrossBrace",Vector3(-.7,h,.06),Vector3(1.34,.12,.075),m.rust)
	# Roof strips and narrow ridges create real raking-light corrugation.
	for x in range(-6,7):
		var roof := box(p,"OverlappingTinRoof",Vector3(x*.91,height+.08,0),Vector3(.96,.05,depth+1.4),paint)
		roof.rotation.z=-.018*variant
	for z in [-3.2,0.0,3.25]: rod(p,Vector3(-width*.58,height-.1,z),Vector3(width*.58,height-.1,z),.058,m.wood)
	# Front porch, fences and clutter avoid the doorway and circulation lanes.
	for x in [-width*.51,width*.51]:
		box(p,"PorchSupport",Vector3(x,1.75,7.8),Vector3(.15,3.5,.15),m.wood,true)
		rod(p,Vector3(x,3.42,7.8),Vector3(x,height,2.9),.09,m.wood)
	var porch_roof := box(p,"PatchedPorchAwning",Vector3(0,3.46,6.05),Vector3(width+1,.055,4.2),m.tin)
	porch_roof.rotation.x=.035
	_fence(p,Vector3(-width*.52,0,7.9),Vector3(-width*.52,0,11.3),index)
	_fence(p,Vector3(-width*.52,0,11.3),Vector3(-.8,0,11.3),index)
	_fence(p,Vector3(2.7,0,11.3),Vector3(width*.52,0,11.3),index+1)
	_generator(node(p,"PortableGenerator",Vector3(-3.5,0,8.3),.18))
	_crate(p,Vector3(-2.5,0,5.1))
	_bucket(p,Vector3(3.8,0,7.2))
	# Furnishing is visible through the door/window and physically walk-around.
	box(p,"ImprovisedBed",Vector3(-3.1,.35,-1.7),Vector3(1.8,.42,2.45),m.wood,true)
	box(p,"DustyBedroll",Vector3(-3.1,.62,-1.7),Vector3(1.64,.17,2.2),m.linen)
	box(p,"WorkTable",Vector3(3.2,.93,-1.7),Vector3(2.4,.12,1.0),m.wood,true)
	for xx in [2.25,4.1]:
		for zz in [-2.03,-1.38]: rod(p,Vector3(xx,0,zz),Vector3(xx,.91,zz),.048,m.steel)
	cylinder(p,"DustyRoofWaterDrum",Vector3(-2,height+.73,-1.3),.58,1.2,m.tin)
	for y in [height+.26,height+1.08]: cylinder(p,"TankBand",Vector3(-2,y,-1.3),.59,.045,m.rust)
	_wire(p,Vector3(-width*.5,3.13,7.8),Vector3(width*.5,3.13,7.8),.26,.013,m.black)
	for i in 4:
		_cloth(p,Vector3(-3.6+i*1.7,2.89,7.8),Vector2(.74+rng.randf()*.30,1.0+rng.randf()*.30),index+i)
	for i in 9:
		w._chunk(p,Vector3(rng.randf_range(-5,5),.035,-depth*.5-.5-rng.randf()),Vector3(.35,.15,.26),m.brick)

func _fence(p: Node3D, from: Vector3, to: Vector3, variant: int) -> void:
	var length := from.distance_to(to)
	var direction := (to-from).normalized()
	var count := maxi(2,int(length/.31))
	for i in count:
		if (i+variant)%11==3: continue
		var pos := from+direction*(i+.5)*length/count
		var h := 1.2+sin(i*3.1+variant)*.18
		var picket := box(p,"UnevenFencePicket",pos+Vector3(0,h*.5,0),Vector3(.24,h,.07),m.wood,true)
		picket.rotation.y=atan2(-direction.z,direction.x)
		picket.rotation.z=sin(i*1.7)*.035
	for y in [.40,.95]: rod(p,from+Vector3(0,y,0),to+Vector3(0,y,0),.048,m.wood)

func _cloth(p: Node3D, pos: Vector3, size: Vector2, index: int) -> void:
	var shader := Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform vec4 fabric_color : source_color = vec4(0.6,0.51,0.4,1.0);
uniform float fabric_height = 1.1;
uniform float phase = 0.0;
varying vec3 local;
void vertex(){ local=VERTEX; float free_edge=clamp(-VERTEX.y/fabric_height,0.0,1.0); VERTEX.z+=sin(TIME*1.7+VERTEX.x*3.6+phase)*free_edge*.11; VERTEX.x+=sin(TIME*.7+phase)*free_edge*.025; }
void fragment(){ float weave=0.9+0.07*sin(local.x*330.0)*sin(local.y*360.0); float stains=0.86+0.14*sin(local.x*12.0+local.y*4.0); ALBEDO=fabric_color.rgb*weave*stains; ROUGHNESS=1.0; }
"""
	var material := ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("fabric_color",[Color("b6a58a"),Color("817363"),Color("7e8582"),Color("8e664b")][index%4])
	material.set_shader_parameter("fabric_height",size.y)
	material.set_shader_parameter("phase",float(index)*1.37)
	var points := PackedVector3Array()
	var indices := PackedInt32Array()
	for yy in 8:
		for xx in 7:
			points.append(Vector3((xx/6.0-.5)*size.x,-yy/7.0*size.y,sin(xx*1.4)*.027))
	for yy in 7:
		for xx in 6:
			var k := yy*7+xx
			indices.append_array([k,k+1,k+7,k+1,k+8,k+7])
	var mesh: MeshInstance3D=w._surface(p,"WindStirredLaundry%d"%index,points,indices,material,true)
	mesh.position=pos
	mesh.set_meta("no_batch",true)
	mesh.visibility_range_end=90
	for x in [-size.x*.34,size.x*.34]: box(p,"ClothesPeg",pos+Vector3(x,.035,.018),Vector3(.033,.12,.06),m.wood)

func _crate(p: Node3D, pos: Vector3) -> void:
	w._wood_crate(p,pos,Vector3(1.15,.8,.9),m.wood)

func _bucket(p: Node3D, pos: Vector3) -> void:
	var bucket := MeshInstance3D.new()
	bucket.name="OpenGalvanizedBucket"
	bucket.mesh=preload("res://environment_geometry.gd").hollow_bucket(.23,.48)
	bucket.material_override=m.tin
	bucket.position=pos
	p.add_child(bucket)
	for i in 8:
		var a := PI*i/8.0
		var b := PI*(i+1)/8.0
		rod(p,pos+Vector3(cos(a)*.23,.43+sin(a)*.24,0),pos+Vector3(cos(b)*.23,.43+sin(b)*.24,0),.012,m.steel)

func _generator(p: Node3D) -> void:
	box(p,"GeneratorMotor",Vector3(0,.47,0),Vector3(.65,.62,.52),m.steel,true)
	box(p,"GeneratorFuelTank",Vector3(0,.87,0),Vector3(.89,.20,.62),m.ochre)
	cylinder(p,"FuelCap",Vector3(.24,1.0,.08),.055,.035,m.steel)
	for side in [-1.0,1.0]:
		var z: float=side*.39
		for x in [-.52,.52]: rod(p,Vector3(x,.13,z),Vector3(x,.95,z),.037,m.steel)
		rod(p,Vector3(-.52,.95,z),Vector3(.52,.95,z),.037,m.steel)
		rod(p,Vector3(-.52,.13,z),Vector3(.52,.13,z),.037,m.steel)
	box(p,"ControlPanel",Vector3(.37,.54,.302),Vector3(.34,.40,.035),m.black)
	for x in [.27,.45]: cylinder(p,"PowerSocket",Vector3(x,.53,.335),.05,.025,m.tin,Vector3(PI*.5,0,0))
	cylinder(p,"FlywheelHousing",Vector3(-.19,.48,.305),.26,.08,m.rust,Vector3(PI*.5,0,0))
	for i in 8:
		var a := TAU*i/8.0
		rod(p,Vector3(-.19+cos(a)*.10,.48+sin(a)*.10,.356),Vector3(-.19+cos(a)*.23,.48+sin(a)*.23,.356),.013,m.steel)

func _ruin(p: Node3D, floors: int, damage: int) -> void:
	var width := 20.0
	var depth := 14.0
	var storey := 3.45
	p.set_meta("hollow",true)
	p.set_meta("floor_count",floors)
	# Separate structural bays form actual window holes and large blast-open rooms.
	for level in floors:
		var y := level*storey
		var slab_width := width if level<floors-1 else width-6.0
		box(p,"ExposedFloorSlab",Vector3(-1 if level==floors-1 else 0,y-.05,0),Vector3(slab_width,.22,depth),m.concrete,level>0)
		for side in [-1.0,1.0]:
			for bay in 5:
				var x := -8.4+bay*4.2
				var blown := (bay+level+damage)%5==1 and level>0
				if blown:
					_fracture(p,Vector3(x-1.8,y+.12,side*7),Vector3(1.3,1.35,.3),level+bay)
					for k in 3: rod(p,Vector3(x-.8+k*.65,y+.18,side*7),Vector3(x-.7+k*.65,y+.65+k*.25,side*7+.1),.024,m.rust)
					continue
				if level>0 or bay%3!=1:
					box(p,"BrokenWindowParapet",Vector3(x,y+.47,side*7),Vector3(3.85,.94,.34),m.plaster,true)
					box(p,"ExposedBrickSill",Vector3(x,y+.95,side*7),Vector3(3.88,.14,.39),m.brick)
				box(p,"WindowLintel",Vector3(x,y+3.13,side*7),Vector3(3.86,.42,.34),m.lightplaster,true)
				for xx in [-1.70,1.70]: box(p,"WindowJamb",Vector3(x+xx,y+2.0,side*7),Vector3(.20,2.27,.4),m.concrete,true)
				# Broken metal frame remains in the empty opening.
				if bay%2==level%2:
					rod(p,Vector3(x,y+1.06,side*7+.03),Vector3(x,y+2.9,side*7+.03),.033,m.steel)
					rod(p,Vector3(x-1.6,y+1.98,side*7+.03),Vector3(x+1.55,y+1.93,side*7+.03),.03,m.steel)
			for x in [-10.0,-6.2,-2.1,2.1,6.2,10.0]:
				if level==floors-1 and x>4: continue
				box(p,"ReinforcedConcretePier",Vector3(x,y+1.6,side*7),Vector3(.42,3.35,.55),m.concrete,true)
		for side in [-1.0,1.0]:
			for z in [-5.7,-1.2,3.7]:
				if level>1 and z>2 and side<0: continue
				box(p,"HollowSideWallBay",Vector3(side*10,y+1.58,z),Vector3(.34,3.14,3.4),m.soot,true)
		for x in [-7.5,6.5]:
			box(p,"InteriorPartitionStub",Vector3(x,y+1.1,-2.0),Vector3(2.8,2.2,.25),m.brick,true)
		if level>0:
			for i in 8:
				var pp := Vector3(rng.randf_range(-8,8),y+.16,rng.randf_range(-5.8,5.8))
				w._chunk(p,pp,Vector3(rng.randf_range(.4,1.0),.35,.7),m.concrete)
	for x in [-9.4,-6.3,-2.1,2.0]:
		for side in [-1.0,1.0]:
			rod(p,Vector3(x,floors*storey-.2,side*6.8),Vector3(x+.14,floors*storey+1.0+rng.randf(),side*6.8+.1),.029,m.rust)
	for i in 22:
		var point := Vector3(rng.randf_range(-12,12),.05,8.0+rng.randf()*4)
		w._chunk(p,point,Vector3(rng.randf_range(.4,1.4),rng.randf_range(.18,.6),rng.randf_range(.4,1.5)),m.concrete)
	# Irregular exposed fracture silhouette, not a flat decal.
	for i in 5: _fracture(p,Vector3(8.6,floors*storey-3+i*.3,-6+i*2.5),Vector3(2.7,2.0,.45),i+damage)

func _fracture(p: Node3D, origin: Vector3, size: Vector3, seed_offset: int) -> void:
	var vertices := PackedVector3Array([
		Vector3(0,0,0),Vector3(size.x,0,0),Vector3(size.x*.78,size.y*.26,0),
		Vector3(size.x*.93,size.y*.48,0),Vector3(size.x*.46,size.y*.65,0),
		Vector3(size.x*.29,size.y,0),Vector3(0,size.y*.84,0)])
	var points := PackedVector3Array()
	for z in [0.0,size.z]:
		for v in vertices: points.append(v+Vector3(0,0,z))
	var indices := PackedInt32Array()
	for i in range(1,6): indices.append_array([0,i+1,i,7,7+i,8+i])
	for i in 7:
		var next := (i+1)%7
		indices.append_array([i,next,i+7,next,next+7,i+7])
	var piece: MeshInstance3D=w._surface(p,"JaggedMasonryFracture",points,indices,m.brick if seed_offset%2 else m.concrete)
	piece.position=origin

func _car(p: Node3D, index: int) -> void:
	var paint: Material=[m.tin,m.red,m.blue,m.ochre][index%4]
	w._wreck_sedan(p,paint,Vector3(2.20,2.03 if index==7 else 1.88,4.7))
	if index%2==0:
		var plank := box(p,"BoardLeaningAgainstWreck",Vector3(-.85,1.12,2.77),Vector3(.3,2.3,.055),m.wood)
		plank.rotation.x=-.21
		for y in [.40,1.0,1.6]: box(p,"BrokenPalletCrosspiece",Vector3(-.39,y,2.75+(1.12-y)*.19),Vector3(1.32,.13,.05),m.wood)

func _utility_pole(pos: Vector3) -> void:
	box(site,"WeatheredPowerPole",pos+Vector3(0,3.9,0),Vector3(.19,7.8,.19),m.wood,true)
	box(site,"PowerCrossarm",pos+Vector3(0,7.35,0),Vector3(1.6,.13,.16),m.wood)
	for x in [-.6,.6]: cylinder(site,"CeramicInsulator",pos+Vector3(x,7.51,0),.075,.24,m.plaster)
	rod(site,pos+Vector3(0,4.8,0),pos+Vector3(1.15,5.45,0),.027,m.steel)
	cylinder(site,"DeadStreetLamp",pos+Vector3(1.15,5.45,0),.30,.08,m.tin)

func _wire(p: Node3D, a: Vector3, b: Vector3, sag: float, thickness: float, material: Material) -> void:
	for i in 12:
		var t := i/12.0
		var u := (i+1)/12.0
		rod(p,a.lerp(b,t)-Vector3(0,sin(t*PI)*sag,0),a.lerp(b,u)-Vector3(0,sin(u*PI)*sag,0),thickness,material)

func _campfire(p: Node3D, shadowed: bool) -> void:
	for i in 12:
		var a := i*TAU/12
		w._chunk(p,Vector3(cos(a)*.73,.10,sin(a)*.73),Vector3(.38,.24,.30),m.stone)
	for i in 4:
		var log_mesh := box(p,"CharredFirewood",Vector3(0,.17+i*.05,0),Vector3(1.18,.16,.19),m.wood)
		log_mesh.rotation.y=i*.94
	var embers := StandardMaterial3D.new()
	embers.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	embers.albedo_color=Color("ffb95a")
	embers.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	embers.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	embers.albedo_texture=_soft_particle_texture()
	embers.emission_enabled=true
	embers.emission=Color("ff5112")
	embers.emission_energy_multiplier=2.8
	var process := ParticleProcessMaterial.new()
	process.direction=Vector3(0,1,0)
	process.spread=17
	process.initial_velocity_min=.75
	process.initial_velocity_max=1.45
	process.gravity=Vector3(0,.08,0)
	process.scale_min=.32
	process.scale_max=.64
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius=.24
	var curve := Curve.new()
	curve.add_point(Vector2(0,.85))
	curve.add_point(Vector2(.3,1))
	curve.add_point(Vector2(1,0))
	var tex := CurveTexture.new()
	tex.curve=curve
	process.scale_curve=tex
	var particles := GPUParticles3D.new()
	particles.name="LivingFireAndEmbers"
	particles.amount=24
	particles.lifetime=.85
	particles.preprocess=1
	particles.process_material=process
	particles.position.y=.28
	var mesh := QuadMesh.new()
	mesh.size=Vector2(.48,1.25)
	mesh.material=embers
	particles.draw_pass_1=mesh
	particles.visibility_aabb=AABB(Vector3(-2,-1,-2),Vector3(4,5,4))
	p.add_child(particles)
	var glow := OmniLight3D.new()
	glow.name="WarmCourtyardFirelight"
	glow.position=Vector3(0,1,0)
	glow.light_color=Color("ff922f")
	glow.light_energy=5.2
	glow.omni_range=14
	glow.omni_attenuation=1.25
	glow.shadow_enabled=shadowed
	glow.shadow_bias=.06
	p.add_child(glow)
	_smoke(p,Vector3(0,1,0),1.1,Color(.21,.21,.23,.20),10,5.0)

func _factory(p: Node3D) -> void:
	# Hollow hall, masonry infill and an actual sawtooth roof replace the background cube.
	for x in [-2.5,18.5]: box(p,"FactorySideMasonry",Vector3(x,4.6,-7),Vector3(.42,9.2,13),m.soot,true)
	box(p,"FactoryRearWall",Vector3(8,4.6,-13.5),Vector3(21,9.2,.40),m.brick,true)
	for x in [-1.0,4.0,9.0,14.0,18.0]:
		box(p,"FactoryFacadePier",Vector3(x,4.6,-.5),Vector3(.55,9.2,.52),m.concrete,true)
		if x!=9.0:
			box(p,"FactoryWindowApron",Vector3(x+1.5,1.15,-.5),Vector3(2.6,2.3,.32),m.brick,true)
			box(p,"FactoryWindowHeader",Vector3(x+1.5,7.6,-.5),Vector3(2.6,2.9,.32),m.soot,true)
		box(p,"FactoryRoofCrossbeam",Vector3(x,9.1,-7),Vector3(.25,.34,13),m.steel)
	for x in [-.5,4.7,9.9,15.1]:
		var roof := box(p,"SawtoothFactoryRoofSheet",Vector3(x,9.95,-7),Vector3(5.45,.09,13.5),m.steel)
		roof.rotation.z=.30
		var end := MeshInstance3D.new()
		end.name="TriangularSawtoothGable"
		end.mesh=preload("res://environment_geometry.gd").extrusion(PackedVector2Array([Vector2(-2.6,0),Vector2(2.6,0),Vector2(2.6,1.6)]),.19)
		end.position=Vector3(x,9.15,-13.5)
		end.material_override=m.brick
		p.add_child(end)
		box(p,"SawtoothClerestoryFrame",Vector3(x+2.59,9.9,-7),Vector3(.09,1.6,13),m.black)
		for z in [-12.4,-9.5,-6.5,-3.5,-.5]: box(p,"ClerestoryMullion",Vector3(x+2.65,9.9,z),Vector3(.09,1.6,.07),m.steel)

	cylinder(p,"SmokingBrickChimney",Vector3(-7,19,-4),1.65,38,m.brick,Vector3.ZERO,true)
	for h in [8.0,19.0,30.0]:
		ring(p,"ChimneyIronBand",Vector3(-7,h,-4),1.71,.075,m.steel)
		for x in [-.25,.25]: rod(p,Vector3(-7+x,h-7,-2.29),Vector3(-7+x,h+3,-2.29),.024,m.steel)
	for h in range(1,38): rod(p,Vector3(-7.28,h,-2.28),Vector3(-6.72,h,-2.28),.016,m.steel)
	cylinder(p,"StackDarkOpening",Vector3(-7,38.02,-4),1.48,.015,m.black)
	_smoke(p,Vector3(-7,39,-4),5.6,Color(.075,.082,.094,.48),26,14.0)
	for x in [20.0,26.0]:
		cylinder(p,"FactoryAuxiliaryExhaust",Vector3(x,10.5,-6),.56,21,m.rust)
		for h in [5.0,12.0,18.0]: ring(p,"ExhaustRing",Vector3(x,h,-6),.59,.07,m.steel)

func _smoke(p: Node3D, pos: Vector3, spread: float, color: Color, amount: int, life: float) -> void:
	var material := StandardMaterial3D.new()
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=color
	material.roughness=1.0
	material.vertex_color_use_as_albedo=true
	material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture=_irregular_smoke_texture()
	var process := ParticleProcessMaterial.new()
	process.direction=Vector3(-.2,1,.12)
	process.spread=18
	process.angle_min=-180
	process.angle_max=180
	process.angular_velocity_min=-8
	process.angular_velocity_max=12
	process.initial_velocity_min=1.4
	process.initial_velocity_max=2.4
	process.gravity=Vector3(-.025,.035,0)
	process.scale_min=spread*.45
	process.scale_max=spread
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius=spread*.15
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,0))
	gradient.set_color(1,Color(1,1,1,0))
	gradient.add_point(.13,Color.WHITE)
	gradient.add_point(.65,Color(1,1,1,.75))
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient=gradient
	process.color_ramp=gradient_texture
	var curve := Curve.new()
	curve.add_point(Vector2(0,.25))
	curve.add_point(Vector2(1,1.4))
	var curve_texture := CurveTexture.new()
	curve_texture.curve=curve
	process.scale_curve=curve_texture
	var particles := GPUParticles3D.new()
	particles.name="DriftingSmoke"
	particles.amount=amount
	particles.lifetime=life
	particles.preprocess=life
	particles.process_material=process
	particles.position=pos
	var mesh := QuadMesh.new()
	mesh.size=Vector2(2.1,2.1)
	mesh.material=material
	particles.draw_pass_1=mesh
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb=AABB(Vector3(-25,-3,-25),Vector3(50,60,50))
	p.add_child(particles)

func _soft_particle_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,.9))
	gradient.set_color(1,Color(1,1,1,0))
	gradient.add_point(.26,Color(1,1,1,.65))
	gradient.add_point(.68,Color(1,1,1,.12))
	var texture := GradientTexture2D.new()
	texture.gradient=gradient
	texture.width=64
	texture.height=64
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5)
	texture.fill_to=Vector2(1,.5)
	return texture

func _dusk_material(hex: String, kind: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code="""shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.4,0.4,0.4,1.0);
uniform float surface_kind=0.0;
varying vec3 p;
varying vec3 n;
float hash3(vec3 q){q=fract(q*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise3(vec3 q){vec3 i=floor(q),f=fract(q);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
float macro=noise3(p*.65)*.7+noise3(p*2.1)*.3;
vec3 c=tint.rgb*(.74+macro*.45); float rough=.93; float metallic=0.0;
if(surface_kind<.5){
float patch=smoothstep(.62,.77,noise3(p*2.3)+noise3(p*14.0)*.13);
float drip=noise3(vec3(p.x*8.0,p.y*.24,p.z*8.0));
c=mix(c,vec3(.16,.085,.045),patch*.85);c*=.87+drip*.2;rough=.78+patch*.2;metallic=.33*(1.0-patch);
}else if(surface_kind<1.5){
float streak=noise3(vec3(p.x*3.3,p.y*.15,p.z*3.3));c*=.80+streak*.24;
float flake=smoothstep(.7,.83,noise3(p*7.0));c=mix(c,c*.6,flake*.35);
}else if(surface_kind<2.5){
float fibres=noise3(vec3(p.x*31.0,p.y*.8,p.z*31.0));c*=.86+fibres*.21;
}else{
vec2 uv=vec2(abs(n.z)>.5?p.x:p.z,p.y)*vec2(2.6,5.2);uv.x+=mod(floor(uv.y),2.0)*.5;
vec2 f=fract(uv);float mortar=1.0-smoothstep(.025,.065,min(min(f.x,1.0-f.x),min(f.y,1.0-f.y)));
c*=.82+hash3(vec3(floor(uv),1.0))*.28;c=mix(c,vec3(.25,.25,.23),mortar*.7);
} ALBEDO=c;ROUGHNESS=rough;METALLIC=metallic;
}
"""
	var material := ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("tint",Color(hex))
	material.set_shader_parameter("surface_kind",float(kind))
	return material

func _merge_colliders(parent: Node3D) -> void:
	# One compound body per home/ruin keeps all genuine holes and wall shapes while
	# avoiding thousands of independent physics bodies in the expanded world.
	var source_bodies := parent.find_children("*","StaticBody3D",true,false)
	if source_bodies.is_empty(): return
	var body := StaticBody3D.new()
	body.name="BuildingCollision"
	parent.add_child(body)
	for source: StaticBody3D in source_bodies:
		for child in source.get_children():
			if not child is CollisionShape3D: continue
			var local_transform: Transform3D=body.global_transform.affine_inverse()*child.global_transform
			source.remove_child(child)
			body.add_child(child)
			child.transform=local_transform
		source.get_parent().remove_child(source)
		source.free()

func _mud_puddle(pos: Vector3) -> void:
	var points := PackedVector3Array([Vector3.ZERO])
	for i in 17:
		var a := i*TAU/16.0
		var radius := .85+sin(i*2.9)*.12
		points.append(Vector3(cos(a)*radius,0,sin(a)*radius*2.7))
	var indices := PackedInt32Array()
	for i in 16: indices.append_array([0,i+1,i+2])
	var material := StandardMaterial3D.new()
	material.albedo_color=Color("302f2a")
	material.roughness=.16
	material.metallic=.22
	var mesh: MeshInstance3D=w._surface(site,"RainwaterInWheelRut",points,indices,material,true)
	mesh.position=pos

func _irregular_smoke_texture() -> ImageTexture:
	if _smoke_texture: return _smoke_texture
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed=74913
	noise.frequency=.035
	noise.fractal_octaves=3
	for y in 128:
		for x in 128:
			var p := Vector2(x-63.5,y-63.5)/63.5
			var angle := atan2(p.y,p.x)
			var edge := 1.0+.10*sin(angle*5+.4)+.07*sin(angle*9)
			var density := pow(maxf(0.0,1.0-p.length()/edge),1.3)
			var turbulence := noise.get_noise_2d(x,y)*.5+.5
			var alpha := density*smoothstep(.13,.72,turbulence)*.88
			image.set_pixel(x,y,Color(1,1,1,alpha))
	_smoke_texture=ImageTexture.create_from_image(image)
	return _smoke_texture
