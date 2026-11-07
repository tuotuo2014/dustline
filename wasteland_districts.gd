extends RefCounted
## Five hand-composed landmarks. Architecture is hollow, with collision only on solid parts.
const Layout = preload("res://world_layout.gd")
var w: Node3D
var rng := RandomNumberGenerator.new()
var m: Dictionary = {}

static func build(world: Node3D) -> void:
	var builder := new()
	builder.w=world
	builder.rng.seed=59031
	builder._materials()
	for district in Layout.DISTRICTS:
		var site := Node3D.new()
		site.name=district.id.to_pascal_case()
		site.set_meta("district_id",district.id)
		site.position=district.position
		site.position.y=world.ground_height(site.position.x,site.position.z)
		world.add_child(site)
		match district.id:
			"service_station": builder._station(site)
			"foundry": builder._foundry(site)
			"settlement": builder._settlement(site)
			"checkpoint": builder._checkpoint(site)
			"scrapyard": builder._scrapyard(site)

func _materials() -> void:
	m=w.materials.duplicate()
	m.brick=w._material("795143",8)
	m.pale_brick=w._material("9a8870",8)
	m.wood=w._material("675447",9)
	m.faded_red=w._material("8a4436",3,.90,.22)
	m.faded_teal=w._material("426766",3,.88,.28)
	m.faded_yellow=w._material("ad8b48",3,.9,.25)
	m.rust=w._material("6d4430",2,.88,.45)
	m.darksteel=w._material("3b403b",2,.83,.6)
	m.plaster=w._material("b0a18a",1)
	m.marking=w._material("b9ad8b",10,.97)
	m.tar=w._material("292d2b",6,.96)
	for key in ["brick","pale_brick","wood","faded_red","faded_teal","faded_yellow","rust","darksteel","plaster","marking","tar"]:
		w.materials["district_"+key]=m[key]

func _box(p: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material, collision := false) -> MeshInstance3D:
	return w._box(p,label,pos,size,mat,collision)

func _rod(p: Node3D, a: Vector3, b: Vector3, radius := .035, mat: Material = null) -> void:
	w._rod(p,a,b,radius,mat if mat else m.rust)

func _cylinder(p: Node3D, label: String, pos: Vector3, radius: float, height: float, mat: Material, collision := false) -> void:
	w._disc(p,label,pos,radius,height,mat,Vector3.ZERO)
	if collision:
		var body := StaticBody3D.new()
		body.position=pos
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius=radius
		cylinder.height=height
		shape.shape=cylinder
		body.add_child(shape)
		p.add_child(body)

func _node(parent: Node3D, label: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name=label
	n.position=pos
	n.rotation.y=yaw
	parent.add_child(n)
	return n

func _sign(parent: Node3D, text: String, pos: Vector3, width: float, color: Material, yaw := 0.0, size := 48) -> void:
	var n := _node(parent,"WeatheredSign",pos,yaw)
	_box(n,"SignBackplate",Vector3.ZERO,Vector3(width,1.14,.13),color)
	for x in [-width*.46,width*.46]:
		for y in [-.40,.40]:
			w._disc(n,"Rivet",Vector3(x,y,.085),.024,.024,m.darksteel,Vector3(PI*.5,0,0))
	var label := Label3D.new()
	label.name="PaintedLettering"
	label.text=text
	label.position=Vector3(0,-.025,.087)
	label.font=load("res://assets/fonts/NotoSansSC.ttf")
	label.font_size=size
	label.pixel_size=.011
	label.modulate=Color("d6c6a7")
	label.outline_size=0
	label.no_depth_test=false
	label.shaded=true
	n.add_child(label)

func _pad(p: Node3D, size: Vector2, pos := Vector3.ZERO) -> void:
	_box(p,"BrokenConcreteApron",pos+Vector3(0,-.035,0),Vector3(size.x,.08,size.y),m.concrete)
	for x in range(-int(size.x*.5)+3,int(size.x*.5),4):
		_box(p,"ExpansionJoint",pos+Vector3(x,.009,0),Vector3(.028,.007,size.y-.6),m.tar)

func _rubble(p: Node3D, center: Vector3, spread: Vector2, count: int) -> void:
	for i in count:
		var point := center+Vector3(rng.randf_range(-spread.x,spread.x),.025,rng.randf_range(-spread.y,spread.y))
		var global_point := p.to_global(point)
		var reserved := false
		for target in Layout.RELAYS+[Layout.EXIT]:
			if Vector2(global_point.x-target.x,global_point.z-target.z).length()<5.0: reserved=true
		if reserved: continue
		var scale := rng.randf_range(.12,.52)
		w._chunk(p,point,Vector3(scale*1.5,scale*.58,scale),m.brick if i%3 else m.concrete)
		if i%5==0:
			var plate := _box(p,"TornSheetMetal",point+Vector3(.2,.05,0),Vector3(scale*1.8,.025,scale*.9),m.rust)
			plate.rotation=Vector3(.15,rng.randf_range(-PI,PI),-.12)

func _crate(p: Node3D, pos: Vector3, size := Vector3(1,.8,1)) -> void:
	w._wood_crate(p,pos,size,m.wood)

func _station(p: Node3D) -> void:
	_pad(p,Vector2(29,28),Vector3(0,0,-1))
	# The missing canopy panels and exposed lattice cast broken bands of sunlight.
	for x in [-8.2,8.2]:
		for z in [-1.3,8.4]:
			_box(p,"CanopyColumn",Vector3(x,2.25,z),Vector3(.25,4.5,.25),m.faded_red,true)
			_box(p,"ColumnFoot",Vector3(x,.25,z),Vector3(.48,.5,.48),m.concrete,true)
	for z in [-2.3,3.5,9.4]:
		_box(p,"CanopyCrossbeam",Vector3(0,4.50,z),Vector3(19,.18,.18),m.rust)
		for x in range(-9,9,3):
			_rod(p,Vector3(x,4.5,z),Vector3(x+1.5,4.98,z),.042)
			_rod(p,Vector3(x+1.5,4.98,z),Vector3(x+3,4.5,z),.042)
	for x in [-9.0,-4.5,0.0,4.5,9.0]:
		_box(p,"CanopyPurlin",Vector3(x,4.95,3.55),Vector3(.1,.09,12.0),m.rust)
	for x in [-6.8,-2.3,2.3,6.8]:
		for z in [.2,6.3]:
			if x>1 and z<1: continue
			_box(p,"SurvivingCanopyPanel",Vector3(x,5.01,z),Vector3(4.43,.07,5.98),m.white_paint)
	_box(p,"FadedCanopyFascia",Vector3(0,4.86,9.55),Vector3(19,.55,.13),m.faded_red)
	_sign(p,"落日 / FUEL",Vector3(0,4.9,9.65),6.0,m.faded_red,0,40)
	for x in [-5.0,5.0]:
		_box(p,"PumpIsland",Vector3(x,.16,3),Vector3(1.8,.32,5.3),m.concrete,true)
		for z in [1.4,4.6]: _fuel_pump(p,Vector3(x,.32,z))
	# Shop frontage has real open windows and a two metre doorway.
	var shop := _node(p,"ServiceShop",Vector3(-1,0,-11.0))
	_box(shop,"RearWall",Vector3(0,1.8,-3.4),Vector3(20,3.6,.4),m.pale_brick,true)
	for side in [-1.0,1.0]: _box(shop,"ShopSideWall",Vector3(side*10,1.8,0),Vector3(.4,3.6,6.8),m.pale_brick,true)
	for x in [-9.8,-5.2,-1.2,2.0,6.0,9.8]: _box(shop,"FrontPier",Vector3(x,1.8,3.4),Vector3(.36,3.6,.38),m.plaster,true)
	_box(shop,"FrontLintel",Vector3(0,3.2,3.4),Vector3(20,.65,.4),m.plaster,true)
	for x in [-7.5,-3.2,4.0,8.0]:
		_box(shop,"ShopWindowSill",Vector3(x,.61,3.4),Vector3(3.5,1.22,.34),m.faded_teal,true)
		_box(shop,"WindowFrame",Vector3(x,1.92,3.43),Vector3(.055,1.35,.075),m.darksteel)
	_box(shop,"RemainingShopRoof",Vector3(-4,3.68,-.15),Vector3(12,.18,7.3),m.concrete)
	for x in [-9.0,-6.0,-3.0,0.0,3.0,6.0,9.0]: _rod(shop,Vector3(x,3.55,-3.5),Vector3(x,3.55,3.6),.075)
	_box(shop,"AbandonedCounter",Vector3(-5,.53,-.7),Vector3(6,1.06,.7),m.wood,true)
	for x in [-6.0,-3.0,2.5]: _crate(shop,Vector3(x,0,-2),Vector3(.9,.7,.8))
	_sign(shop,"补给商店 · SUPPLIES",Vector3(-4,3.07,3.63),6.3,m.faded_teal,0,34)
	var fallen := _box(p,"FallenPriceBoard",Vector3(-14,1.65,5),Vector3(2.8,3.1,.16),m.faded_red,true)
	fallen.rotation.z=.17
	for y in [.95,1.55,2.15]: _box(p,"EmptyPriceSlot",Vector3(-14,y,5.13),Vector3(1.95,.35,.04),m.black)
	_rubble(p,Vector3(-7,0,-6),Vector2(6,.8),25)
	_wreck(p,Vector3(11.5,0,14),-.4,m.faded_yellow)

func _fuel_pump(p: Node3D, pos: Vector3) -> void:
	var n := _node(p,"AbandonedFuelPump",pos)
	_box(n,"PumpBody",Vector3(0,.71,0),Vector3(.64,1.42,.56),m.faded_red,true)
	_box(n,"PumpHead",Vector3(0,1.42,0),Vector3(.76,.67,.61),m.white_paint,true)
	_box(n,"DeadDisplay",Vector3(0,1.49,.315),Vector3(.48,.23,.025),m.black)
	for x in [-.15,0.0,.15]: _box(n,"DisplaySegment",Vector3(x,1.49,.331),Vector3(.072,.11,.009),m.marking)
	for i in 12:
		var t := i/12.0
		var u := (i+1)/12.0
		_rod(n,Vector3(.43+sin(t*PI)*.35,1.45-t*.55,.0),Vector3(.43+sin(u*PI)*.35,1.45-u*.55,.0),.023,m.rubber)
	_box(n,"FuelNozzle",Vector3(.43,.91,.02),Vector3(.09,.25,.12),m.darksteel)

func _foundry(p: Node3D) -> void:
	_pad(p,Vector2(36,31))
	# Narrow structural bays leave a continuous clear central floor and open portals.
	for side in [-1.0,1.0]:
		for z in [-12.0,-6.0,0.0,6.0,12.0]:
			_box(p,"FactoryPillar",Vector3(side*14,4.15,z),Vector3(.62,8.3,.65),m.concrete,true)
		for z in [-9.0,-3.0,3.0,9.0]:
			_box(p,"BrickSideWall",Vector3(side*14,1.35,z),Vector3(.4,2.7,5.4),m.brick,true)
			_box(p,"FactoryWindowLintel",Vector3(side*14,6.1,z),Vector3(.45,.36,5.5),m.concrete)
			_box(p,"UpperBrickSpandrel",Vector3(side*14,7.35,z),Vector3(.43,2.0,5.4),m.brick)
			for dz in [-1.7,0.0,1.7]: _rod(p,Vector3(side*14,2.8,z+dz),Vector3(side*14,5.9,z+dz),.025,m.darksteel)
			_rod(p,Vector3(side*14,4.3,z-2.7),Vector3(side*14,4.3,z+2.7),.033,m.darksteel)
	for x in [-10.3,10.3]:
		_box(p,"FactoryEndWall",Vector3(x,3.8,-12),Vector3(7.0,7.6,.5),m.brick,true)
		_box(p,"FactoryFrontPier",Vector3(x,2.7,12),Vector3(7.0,5.4,.5),m.brick,true)
	_box(p,"FactoryPortalHeader",Vector3(0,7.3,-12),Vector3(14.4,1.4,.55),m.concrete)
	for z in [-12.0,-6.0,0.0,6.0,12.0]:
		_rod(p,Vector3(-14,8.3,z),Vector3(0,11.0,z),.13,m.darksteel)
		_rod(p,Vector3(0,11.0,z),Vector3(14,8.3,z),.13,m.darksteel)
		_rod(p,Vector3(-14,8.3,z),Vector3(14,8.3,z),.1,m.darksteel)
		for x in [-10.0,-5.0,0.0,5.0,10.0]:
			_rod(p,Vector3(x,8.3,z),Vector3(x,11.0-absf(x)*.193,z),.06)
			_rod(p,Vector3(x-2.3,8.3,z),Vector3(x,11.0-absf(x)*.193,z),.055)
	for x in [-10.0,-5.0,0.0,5.0,10.0]: _rod(p,Vector3(x,11-absf(x)*.193,-12),Vector3(x,11-absf(x)*.193,12),.06)
	var roof := _box(p,"RemainingFactoryRoof",Vector3(-7,9.78,-6.0),Vector3(14.3,.1,11.5),m.rust)
	roof.rotation.z=.190
	_sign(p,"铁河熔炼厂 · 07",Vector3(-9.5,4.35,12.31),7.0,m.darksteel,0,37)
	_cylinder(p,"ChimneyBase",Vector3(-18,1.3,-8),2.5,2.6,m.concrete,true)
	_cylinder(p,"TallBrickChimney",Vector3(-18,11.8,-8),1.42,21,m.brick,true)
	for y in [3.0,8.0,13.0,18.0,21.8]: _cylinder(p,"ChimneyCollar",Vector3(-18,y,-8),1.48,.22,m.rust)
	_cylinder(p,"ChimneyBlackOpening",Vector3(-18,22.32,-8),1.25,.01,m.black)
	for y in range(3,22):
		_rod(p,Vector3(-18.38,y,-6.51),Vector3(-17.62,y,-6.51),.025)
	for x in [-18.38,-17.62]: _rod(p,Vector3(x,2.8,-6.51),Vector3(x,21.4,-6.51),.033)
	# Old furnace and a pipe bank stay along the west wall, away from the relay.
	_box(p,"FurnaceBase",Vector3(-8,.65,1),Vector3(5,1.3,5),m.concrete,true)
	_cylinder(p,"SmelterVessel",Vector3(-8,2.5,1),1.65,3.0,m.rust,true)
	_cylinder(p,"SmelterRim",Vector3(-8,4.03,1),1.77,.20,m.darksteel)
	for z in [-6.0,-2.0,2.0,6.0]:
		_rod(p,Vector3(-12.5,3,z),Vector3(-12.5,6,z),.13,m.rust)
		_rod(p,Vector3(-12.5,6,z),Vector3(-8,6,z),.13,m.rust)
		_cylinder(p,"PipeValveStem",Vector3(-12.5,3.6,z),.23,.065,m.darksteel)
	_box(p,"OverheadCraneRail",Vector3(0,7.5,5),Vector3(26,.32,.32),m.faded_yellow)
	_box(p,"CraneTrolley",Vector3(-4,7.18,5),Vector3(1.8,.48,1.05),m.faded_yellow)
	_rod(p,Vector3(-4,7,5),Vector3(-4,4.8,5),.025,m.darksteel)
	_rubble(p,Vector3(-11,0,15),Vector2(6,2),35)

func _settlement(p: Node3D) -> void:
	_pad(p,Vector2(33,30),Vector3(0,0,-3))
	_facade(p,Vector3(-1,0,-12.5),0,3,m.pale_brick)
	_facade(p,Vector3(-15,0,-1),PI*.5,2,m.brick)
	_facade(p,Vector3(17,0,-4),-PI*.5,2,m.plaster)
	# Courtyard stays open: the pump, rubble and planters are tucked around its edge.
	_cylinder(p,"DryWellRim",Vector3(-6,.53,8),1.2,1.06,m.concrete,true)
	_cylinder(p,"DryWellOpening",Vector3(-6,1.068,8),.91,.012,m.black)
	_rod(p,Vector3(-7.25,0,8),Vector3(-7.25,2.4,8),.07)
	_rod(p,Vector3(-4.75,0,8),Vector3(-4.75,2.4,8),.07)
	_rod(p,Vector3(-7.25,2.4,8),Vector3(-4.75,2.4,8),.09)
	for x in [-11.0,12.0]:
		_box(p,"CourtyardPlanter",Vector3(x,.34,10.5),Vector3(2.7,.68,1.7),m.concrete,true)
		_box(p,"PlanterDust",Vector3(x,.686,10.5),Vector3(2.33,.03,1.32),m.sand)
	_sign(p,"余烬街 / EMBER",Vector3(13.1,2.5,2.7),3.8,m.faded_teal,PI*.5,30)
	for x in [-9.0,8.0]:
		_rod(p,Vector3(x,0,13.5),Vector3(x,4.0,13.5),.06,m.darksteel)
		_box(p,"StreetLampHood",Vector3(x,4.0,13.5),Vector3(.6,.17,.6),m.darksteel)
	_rubble(p,Vector3(-12,0,-9),Vector2(2,5),36)
	_rubble(p,Vector3(13,0,-11),Vector2(1.5,3),22)
	_wreck(p,Vector3(-3,0,16),.12,m.faded_teal)
	# A sagging line and small torn cloth patches give the abandoned homes human scale.
	for i in 10:
		var x := -12+i*2.4
		_rod(p,Vector3(x,5.5-sin(i/10.0*PI)*.5,-4),Vector3(x+2.4,5.5-sin((i+1)/10.0*PI)*.5,-4),.012,m.darksteel)
	for i in 3:
		var cloth := _box(p,"ForgottenCloth",Vector3(-3+i*1.5,4.5,-4),Vector3(.65,1.1,.018),m.faded_teal if i%2 else m.wood)
		cloth.rotation.z=.07*(i-1)

func _facade(parent: Node3D, pos: Vector3, yaw: float, floors: int, material: Material) -> void:
	var p := _node(parent,"HollowTenement",pos,yaw)
	var height := floors*3.2
	# Five bays, five real openings per floor; the middle ground-floor bay is a door.
	for floor_index in floors:
		var base := floor_index*3.2
		for i in 6:
			_box(p,"MasonryPier",Vector3(-8+i*3.2,base+1.6,0),Vector3(.57,3.2,.48),material,true)
		for i in 5:
			var x := -6.4+i*3.2
			var doorway := floor_index==0 and (i==1 or i==3)
			if not doorway:
				_box(p,"WindowApron",Vector3(x,base+.52,0),Vector3(2.67,1.04,.48),material,true)
				_box(p,"WindowSill",Vector3(x,base+1.04,.12),Vector3(2.85,.11,.64),m.concrete)
				_rod(p,Vector3(x,base+1.09,.055),Vector3(x,base+2.65,.055),.024,m.wood)
				_rod(p,Vector3(x-1.2,base+1.82,.055),Vector3(x+1.2,base+1.82,.055),.025,m.wood)
			_box(p,"WindowLintel",Vector3(x,base+2.96,0),Vector3(2.67,.48,.49),material,true)
		_box(p,"FacadeFloorBand",Vector3(0,base+3.12,.02),Vector3(16.7,.16,.60),m.concrete)
		if floor_index>0:
			_box(p,"BrokenUpperFloor",Vector3(-3.3,base,-3),Vector3(9.9,.22,6),m.concrete)
			for x in [2.0,3.0,4.0]: _rod(p,Vector3(x,base,-3.8),Vector3(x+.2,base-.15,-2.4),.018)
	for x in [-8.0,8.0]:
		_box(p,"TenementSideWall",Vector3(x,height*.5,-3.1),Vector3(.45,height,6.2),material,true)
	_box(p,"RearRoomWall",Vector3(0,1.5,-6.0),Vector3(16,3,.42),material,true)
	_box(p,"RoofCornice",Vector3(-2,height+.11,0),Vector3(12,.28,.73),m.concrete)
	for x in [-5.8,.6]:
		_box(p,"ShallowBalcony",Vector3(x,3.23,.73),Vector3(2.5,.14,1.4),m.concrete)
		for dx in [-1.12,-.56,0.0,.56,1.12]: _rod(p,Vector3(x+dx,3.30,1.3),Vector3(x+dx,4.22,1.3),.025,m.darksteel)
		_rod(p,Vector3(x-1.2,4.22,1.3),Vector3(x+1.2,4.22,1.3),.038,m.darksteel)
	for y in [.4,height-1.0]: _rod(p,Vector3(8.35,y,-.4),Vector3(8.35,minf(y+5,height),-.4),.06,m.darksteel)
	_box(p,"FadedDoorAwning",Vector3(-3.2,2.88,.75),Vector3(2.75,.10,1.4),m.faded_teal)
	_box(p,"OldShopShutter",Vector3(6.4,1.4,-.06),Vector3(2.5,2.4,.09),m.faded_red,true)
	for y in range(1,11): _box(p,"ShutterSlat",Vector3(6.4,.21+y*.22,.01),Vector3(2.48,.025,.04),m.rust)
	for x in [-6.0,5.0]:
		_box(p,"WallRenderPatch",Vector3(x,.65,.258),Vector3(1.25,1.0,.018),m.plaster)
		_box(p,"DerelictAirUnit",Vector3(x,5.6,.36),Vector3(1,.6,.62),m.white_paint)
		for i in 5: _box(p,"AirUnitVent",Vector3(x,5.42+i*.08,.682),Vector3(.77,.029,.018),m.darksteel)

func _checkpoint(p: Node3D) -> void:
	_pad(p,Vector2(32,24))
	for x in [-10.0,10.0]:
		var hut := _node(p,"GuardHouse",Vector3(x,0,1.0))
		_box(hut,"GuardhouseRear",Vector3(0,1.65,-2.5),Vector3(4.7,3.3,.3),m.pale_brick,true)
		for side in [-1.0,1.0]:
			_box(hut,"GuardhouseSideBase",Vector3(side*2.35,.7,0),Vector3(.28,1.4,5),m.pale_brick,true)
			_box(hut,"GuardhouseSideLintel",Vector3(side*2.35,3.0,0),Vector3(.29,.65,5),m.pale_brick)
			for z in [-2.5,0.0,2.5]: _box(hut,"GuardhouseWindowPost",Vector3(side*2.35,2,z),Vector3(.22,1.3,.16),m.darksteel)
		for xx in [-1.8,1.8]: _box(hut,"DoorSide",Vector3(xx,1.65,2.5),Vector3(1.0,3.3,.3),m.pale_brick,true)
		_box(hut,"GuardhouseRoof",Vector3(0,3.4,0),Vector3(5.4,.18,5.7),m.concrete)
		_box(hut,"GuardDesk",Vector3(0,.78,-1.65),Vector3(2.5,.13,.65),m.wood)
		for xx in [-1.0,1.0]: _box(hut,"DeskLeg",Vector3(xx,.35,-1.65),Vector3(.08,.7,.08),m.darksteel)
	for x in [-7.0,7.0]:
		_box(p,"GantryUpright",Vector3(x,3.8,-6.5),Vector3(.35,7.6,.35),m.rust,true)
		_box(p,"GantryBase",Vector3(x,.5,-6.5),Vector3(.9,1.0,.9),m.concrete,true)
		_rod(p,Vector3(x,5.7,-6.5),Vector3(x*.7,7.5,-6.5),.07)
	_box(p,"CheckpointGantry",Vector3(0,7.55,-6.5),Vector3(14.7,.24,.24),m.rust)
	_sign(p,"北线检查站 / NORTH",Vector3(0,6.65,-6.36),9,m.faded_yellow,0,43)
	for x in [-13.0,-8.8,8.8,13.0]:
		for z in [-10.0,9.0]:
			_box(p,"ConcreteRoadBarrier",Vector3(x,.55,z),Vector3(3.4,1.1,.85),m.concrete,true)
			for dx in [-.9,0.0,.9]:
				var stripe := _box(p,"BarrierWarningStripe",Vector3(x+dx,.55,z+.435),Vector3(.25,.8,.012),m.faded_yellow)
				stripe.rotation.z=-.4
	for side in [-1.0,1.0]:
		for z in [-9.0,-3.0,3.0,9.0]:
			_rod(p,Vector3(side*16,0,z),Vector3(side*16,2.9,z),.055,m.darksteel)
			if z<9:
				for y in [1.0,2.0,2.7]: _rod(p,Vector3(side*16,y,z),Vector3(side*16,y,z+6),.019,m.rust)
				for j in 5:
					_rod(p,Vector3(side*16,.3,z+j*1.2),Vector3(side*16,2.65,z+j*1.2+1.0),.009,m.darksteel)
					_rod(p,Vector3(side*16,2.65,z+j*1.2),Vector3(side*16,.3,z+j*1.2+1.0),.009,m.darksteel)
	for x in [-4.0,4.0]:
		for z in [-12.0,0.0,12.0]: _box(p,"FadedLaneMark",Vector3(x,.015,z),Vector3(.16,.01,4.0),m.marking)
	_crate(p,Vector3(-13.5,0,4))
	_rubble(p,Vector3(12,0,-7),Vector2(2,1),18)

func _scrapyard(p: Node3D) -> void:
	_pad(p,Vector2(38,34),Vector3(0,0,1))
	_container(p,Vector3(-10,0,-8),0,m.faded_teal)
	_container(p,Vector3(-10,2.7,-8),.035,m.faded_red)
	_container(p,Vector3(10,0,-4),PI*.5,m.faded_yellow)
	_container(p,Vector3(-2,0,13),0,m.faded_red)
	# A skeletal lifting frame anchors the silhouette above the low stacked scrap.
	for x in [-6.0,6.0]:
		_box(p,"ScrapGantryLeg",Vector3(x,4,3),Vector3(.33,8,.42),m.faded_yellow,true)
		_box(p,"GantryFoot",Vector3(x,.15,3),Vector3(2.8,.3,1.1),m.darksteel,true)
		_rod(p,Vector3(x,5,3),Vector3(x*.66,8,3),.13,m.darksteel)
	_box(p,"SalvageCraneBeam",Vector3(0,8,3),Vector3(14,.42,.6),m.faded_yellow)
	_box(p,"CraneMotor",Vector3(1,7.63,3),Vector3(1.35,.54,.75),m.rust)
	for x in [.85,1.15]: _rod(p,Vector3(x,7.5,3),Vector3(x,4.6,3),.017,m.darksteel)
	_rod(p,Vector3(1,4.6,3),Vector3(1.35,4.2,3),.05,m.darksteel)
	_rod(p,Vector3(1.35,4.2,3),Vector3(1.5,4.48,3),.05,m.darksteel)
	for i in 4:
		_wreck(p,Vector3(-11+i*4.6,0,6.3),rng.randf_range(-.3,.3),m.faded_red if i%2 else m.faded_teal)
	# Dismantled chassis and a rack of warped steel sheets fill the western edge.
	for i in 3:
		var rack := _node(p,"SalvagedSteelStack",Vector3(-18,0,-3+i*5.4),rng.randf_range(-.2,.2))
		for j in 5:
			var plate := _box(rack,"WarpedScrapPlate",Vector3(0,.2+j*.17,0),Vector3(3.5,.09,2.3),m.rust if j%2 else m.white_paint)
			plate.rotation=Vector3(.03*j,.03*j,-.025*j)
		_box(rack,"SteelStackCollision",Vector3(0,.37,0),Vector3(3.4,.7,2.2),m.darksteel,true)
	for x in [-5.5,-3.9,-2.3]: _crate(p,Vector3(x,0,-12.5),Vector3(1.3,1.1,1.2))
	_sign(p,"拆解场 / SALVAGE",Vector3(2,3.3,14.65),8,m.faded_red,0,43)
	_rubble(p,Vector3(13,0,13),Vector2(3,3),38)
	_rubble(p,Vector3(-13,0,13),Vector2(3,2),26)

func _container(p: Node3D, pos: Vector3, yaw: float, paint: Material) -> void:
	var n := _node(p,"OpenCargoContainer",pos,yaw)
	# One open end: the visible floor is flush enough to walk through.
	_box(n,"ContainerFloor",Vector3(0,.055,0),Vector3(6.2,.11,2.6),m.darksteel)
	for z in [-1.3,1.3]:
		_box(n,"ContainerSide",Vector3(0,1.34,z),Vector3(6.2,2.65,.07),paint,true)
		for x in range(-14,15): _box(n,"CorrugatedFlute",Vector3(x*.21,1.35,z*1.028),Vector3(.062,2.45,.045),paint)
		for y in [.12,2.64]: _box(n,"ContainerEdgeRail",Vector3(0,y,z),Vector3(6.2,.11,.11),m.rust)
	_box(n,"ContainerRoof",Vector3(0,2.67,0),Vector3(6.2,.10,2.6),paint)
	_box(n,"ContainerClosedEnd",Vector3(-3.1,1.35,0),Vector3(.09,2.65,2.6),paint,true)
	for z in [-1.28,1.28]:
		_box(n,"ContainerCornerCasting",Vector3(3.1,1.35,z),Vector3(.16,2.7,.16),m.rust,true)
		var door := _node(n,"OpenContainerDoor",Vector3(3.12,0,z),-.92*signf(z))
		_box(door,"ContainerDoor",Vector3(0,1.35,-signf(z)*.59),Vector3(.075,2.65,1.16),paint,true)
		_rod(door,Vector3(.06,.25,-signf(z)*.56),Vector3(.06,2.4,-signf(z)*.56),.025,m.darksteel)
	_box(n,"FadedContainerCode",Vector3(-1,1.85,1.347),Vector3(1.1,.29,.012),m.marking)

func _wreck(p: Node3D, local_pos: Vector3, yaw: float, paint: Material) -> void:
	var position := p.to_global(local_pos)
	position.y=0
	w._car(position,yaw,paint)
