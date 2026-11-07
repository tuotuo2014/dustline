extends RefCounted
## Sand-buried boulevard, modelled as hollow damaged buildings rather than backdrop boxes.
const Builder = preload("res://reference_industrial.gd")
var b: Builder
var w: Node3D
var site: Node3D
var rng := RandomNumberGenerator.new()
var m: Dictionary

static func build(world: Node3D, district: Node3D) -> void:
	var city := new()
	city.w=world
	city.site=district
	city.b=Builder.new()
	city.b.setup(world,district,291083)
	city.m=city.b.m
	city.rng.seed=871130
	city._build()

func _build() -> void:
	site.set_meta("landmark","沉沙旧城")
	site.set_meta("safe_loot_positions",[Vector3(-7,0,62),Vector3(7,0,35),Vector3(-7,0,-3),Vector3(7,0,-40),Vector3(0,0,-70)])
	b.box(site,"CrackedSandBuriedBoulevard",Vector3(0,-.006,0),Vector3(24,.05,176),m.asphalt)
	for z in range(-82,83,10):
		b.box(site,"FadedCenterLine",Vector3(-.18,.024,z),Vector3(.12,.016,3.8),m.roadmark)
		b.box(site,"FadedCenterLine",Vector3(.18,.024,z),Vector3(.12,.016,3.8),m.roadmark)
	for side in [-1.0,1.0]:
		_sand_bank(side)
		for z in [-77.0,-42.0,0.0,42.0,75.0]:
			b.box(site,"FracturedKerb",Vector3(side*12.3,.16,z),Vector3(.4,.32,6),m.concrete,true)
		for z in [-58.0,-16.0,28.0,68.0]: _streetlight(Vector3(side*13.5,0,z),side)
	# Main ruined blocks lean visually into the boulevard without closing the road.
	var buildings := [
		[Vector3(-38,0,61),11,28.0,29.0,PI*.5,0],
		[Vector3(-40,0,18),9,31.0,29.0,PI*.5,1],
		[Vector3(-38,0,-25),8,30.0,27.0,PI*.5,2],
		[Vector3(-42,0,-65),7,26.0,26.0,PI*.5,3],
		[Vector3(39,0,59),4,29.0,28.0,-PI*.5,4],
		[Vector3(39,0,17),6,30.0,28.0,-PI*.5,5],
		[Vector3(39,0,-26),8,30.0,28.0,-PI*.5,6],
		[Vector3(42,0,-65),9,27.0,27.0,-PI*.5,7]
	]
	for data in buildings:
		_building(b.node(site,"CollapsedResidentialBlock",data[0],data[4]),data[1],data[2],data[3],data[5])
	_bus(b.node(site,"SandBuriedCityBus",Vector3(-15.4,.22,40),.22),true)
	_bus(b.node(site,"CollapsedCommuterBus",Vector3(-18.4,.30,-8),-.33),false)
	_truck(b.node(site,"AbandonedMilitaryTruck",Vector3(16.2,.05,29),-.27))
	_car(b.node(site,"CrushedSedan",Vector3(15.3,.05,-28),.5))
	_car(b.node(site,"BurntSedan",Vector3(-16.5,.15,-60),-.8))
	_traffic_signal(Vector3(11.5,0,51),-1.0)
	_traffic_signal(Vector3(-11.5,0,-38),1.0)
	_radio_tower(b.node(site,"RooftopRadioMast",Vector3(59,0,-53)))
	# Side alleys and courtyards give each building a useful ground-level interior.
	for side in [-1.0,1.0]:
		for z in [-46.0,-3.0,39.0]:
			b.box(site,"BuriedSideStreet",Vector3(side*46,.003,z),Vector3(66,.03,5.2),m.asphalt)
		for z in [-76.0,-32.0,11.0,54.0]:
			b.rubble(site,Vector3(side*23,0,z),Vector2(6,9),32,.75)
		for z in [-71.0,66.0]:
			var hoarding := b.node(site,"WeatheredRoadSign",Vector3(side*19,0,z),side*.14)
			b.rod(hoarding,Vector3(-1,0,0),Vector3(-1,4.3,0),.06)
			b.rod(hoarding,Vector3(1,0,0),Vector3(1,4.3,0),.06)
			b.box(hoarding,"OldEnamelDirectionBoard",Vector3(0,3.5,0),Vector3(4.8,1.7,.12),m.teal)
			b.label(hoarding,"沉沙旧城" if side<0 else "CITY / 03",Vector3(0,3.6,.08),38)

func _broken(floor_id: int, bay: int, identity: int, side_id := 0) -> bool:
	var center := 1+identity%4
	var damage_floor := 2+identity%3
	return floor_id>=damage_floor and floor_id<=damage_floor+3 and absf(float(bay-center))<(1.35 if floor_id<damage_floor+2 else 2.2) and side_id<2

func _building(p: Node3D, floors: int, width: float, depth: float, identity: int) -> void:
	const FLOOR := 3.65
	var bay_width := width/7.0
	p.set_meta("floors",floors)
	# Partial concrete slabs expose depth through the windows; missing corners vary per building.
	for floor_id in range(1,floors+1):
		var y := floor_id*FLOOR
		var remaining_width := width if floor_id<floors-1 else width-bay_width*(1.0+identity%2)
		b.box(p,"ExposedFloorSlab",Vector3((width-remaining_width)*.5,y,0),Vector3(remaining_width,.25,depth),m.concrete,true)
		if floor_id==floors:
			for x in range(-int(remaining_width*.4),int(remaining_width*.4),3):
				b.rod(p,Vector3(x,y,-depth*.4),Vector3(x+.12,y+rng.randf_range(1.0,2.2),-depth*.4),.024,m.steel)
	for side_id in 4:
		var face := b.node(p,"PerforatedFacade",Vector3.ZERO,side_id*PI*.5)
		var span := width if side_id%2==0 else depth
		var reach := depth*.5 if side_id%2==0 else width*.5
		var bays := 7
		var bw := span/bays
		for floor_id in floors:
			var y := floor_id*FLOOR
			for bay in bays:
				var x := -span*.5+(bay+.5)*bw
				var broken := _broken(floor_id,bay,identity,side_id)
				if floor_id==floors-1 and bay<1+identity%2: broken=true
				if broken:
					# Exposed inner brick edges and bent reinforcement define irregular holes.
					if (floor_id+bay)%2==0:
						var fragment := b.box(face,"JaggedExposedBrickEdge",Vector3(x-bw*.40,y+.76,reach-.08),Vector3(.55,1.4,.52),m.brick,true)
						fragment.rotation.z=.16
						b.rod(face,Vector3(x,y+.15,reach),Vector3(x+.55,y+1.7,reach+.23),.027,m.steel)
					continue
				# Ground-floor portals are wide and truly open for entering buildings.
				var door := floor_id==0 and (bay==2 or bay==3 or bay==4)
				if not door:
					b.box(face,"ChippedWindowSpandrel",Vector3(x,y+.70,reach),Vector3(bw-.10,1.4,.46),m.plaster,true)
					b.box(face,"ExposedBrickSill",Vector3(x,y+1.43,reach+.04),Vector3(bw-.48,.13,.56),m.brick)
					b.box(face,"DeepWindowLintel",Vector3(x,y+3.45,reach),Vector3(bw-.10,.40,.46),m.plaster,true)
					# Human-scaled residential openings, with thick wall cheeks and deep shadow reveals.
					var cheek := (bw-1.48)*.5
					for sx in [-1.0,1.0]:
						b.box(face,"DeepWindowReveal",Vector3(x+sx*(.74+cheek*.5),y+2.42,reach),Vector3(cheek,1.88,.54),m.plaster,true)
					if (bay+floor_id+identity)%4==0:
						b.box(face,"RemainingWindowMullion",Vector3(x,y+2.38,reach+.09),Vector3(.045,1.72,.09),m.steel)
					if (bay*3+floor_id+identity)%7==0:
						var v := PackedVector3Array([Vector3(x-.68,y+1.51,reach+.06),Vector3(x-.68,y+2.8,reach+.06),Vector3(x+.24,y+1.51,reach+.06)])
						w._surface(face,"RemainingGlassShard",v,PackedInt32Array([0,1,2]),m.glass,true)
				if bay==0 or not door or bay==4:
					b.box(face,"ScarredConcretePier",Vector3(x-bw*.5,y+FLOOR*.5,reach),Vector3(.40,FLOOR,.53),m.concrete,true)
				if floor_id>0 and (floor_id+bay+identity)%8==0:
					b.box(face,"HangingRustBalconySlab",Vector3(x,y+.17,reach+.78),Vector3(bw-.6,.18,1.6),m.concrete,true)
					for dx in [-bw*.36,0.0,bw*.36]: b.rod(face,Vector3(x+dx,y+.25,reach+1.45),Vector3(x+dx,y+1.14,reach+1.45),.023,m.steel)
					b.rod(face,Vector3(x-bw*.36,y+1.14,reach+1.45),Vector3(x+bw*.36,y+1.14,reach+1.45),.032,m.rust)
				if (floor_id*3+bay+identity)%11==0 and floor_id>1:
					b.box(face,"AbandonedAirConditioner",Vector3(x+bw*.3,y+1.9,reach+.45),Vector3(.85,.6,.7),m.teal)
					for sy in [-.15,0.0,.15]: b.box(face,"ACVent",Vector3(x+bw*.3,y+1.9+sy,reach+.815),Vector3(.61,.026,.025),m.black)
			b.box(face,"FacadeFloorBand",Vector3(0,y+.11,reach+.04),Vector3(span,.16,.52),m.concrete)
		# Notches in the parapet preserve the collapsed roofline.
		for bay in range(2+identity%2,7):
			b.box(face,"BrokenRoofParapet",Vector3(-span*.5+(bay+.5)*bw,floors*FLOOR+.42,reach),Vector3(bw-.24,.84,.38),m.plaster,true)
	# Sparse interior columns leave the entrances and cross-building route clear.
	for x in [-width*.32,width*.32]:
		for z in [-depth*.28,depth*.28]:
			b.box(p,"InternalStructuralColumn",Vector3(x,floors*FLOOR*.5,z),Vector3(.55,floors*FLOOR,.55),m.concrete,true)
	for floor_id in range(1,floors):
		if floor_id%2==identity%2:
			b.box(p,"ExposedRoomPartition",Vector3(0,floor_id*FLOOR+1.4,-depth*.15),Vector3(width*.7,2.8,.22),m.brick,true)
	# The collapsed corner spills fragments beside, never across, the boulevard.
	b.rubble(p,Vector3(-width*.38,0,depth*.58),Vector2(width*.20,2.7),38,1.15)
	if identity in [0,4]:
		b.box(p,"GroundFloorFadedShopSign",Vector3(width*.2,3.06,depth*.5+.33),Vector3(width*.45,.76,.15),m.ochre)
		b.label(p,"百货商场" if identity==0 else "修理 / GARAGE",Vector3(width*.2,3.08,depth*.5+.43),37)

func _sand_bank(side: float) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var xs := [8.0,11.0,16.0,21.0,25.0]
	for row in 35:
		var z := -85.0+row*5.0
		for col in 5:
			var h := 0.02
			if col>0: h=sin(float(col)*PI/4.0)*(.65+sin(z*.063+side)*.40+sin(z*.17)*.17)*2.0
			vertices.append(Vector3(side*xs[col],h,z))
	for row in 34:
		for col in 4:
			var k := row*5+col
			if side>0: indices.append_array([k,k+5,k+6,k,k+6,k+1])
			else: indices.append_array([k,k+6,k+5,k,k+1,k+6])
	var mesh: MeshInstance3D=w._surface(site,"DriftingSandBank",vertices,indices,m.sand,true)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape=mesh.mesh.create_trimesh_shape()
	body.add_child(shape)
	mesh.add_child(body)

func _streetlight(pos: Vector3, side: float) -> void:
	var p := b.node(site,"BrokenBoulevardLamp",pos)
	b.rod(p,Vector3.ZERO,Vector3(.22*side,7.3,0),.085,m.steel)
	b.rod(p,Vector3(.22*side,7.3,0),Vector3(-2.2*side,7.7,0),.065,m.steel)
	b.box(p,"DeadLampHousing",Vector3(-2.35*side,7.66,0),Vector3(1.05,.18,.45),m.teal)
	b.box(p,"LampConcreteFoot",Vector3(0,.28,0),Vector3(.5,.56,.5),m.concrete,true)

func _traffic_signal(pos: Vector3, side: float) -> void:
	var p := b.node(site,"BrokenTrafficSignal",pos)
	b.rod(p,Vector3.ZERO,Vector3(0,6.2,0),.11,m.steel)
	b.rod(p,Vector3(0,6.1,0),Vector3(side*7.1,6.35,0),.075,m.steel)
	b.rod(p,Vector3(0,4.9,0),Vector3(side*3.4,6.23,0),.047,m.steel)
	b.box(p,"EmptySignalHousing",Vector3(side*7,5.65,.02),Vector3(.60,1.52,.46),m.ochre)
	for y in [5.17,5.63,6.08]:
		b.cylinder(p,"DeadTrafficLamp",Vector3(side*7,y,.269),.17,.08,m.black,Vector3(PI*.5,0,0))
		b.box(p,"LampSunVisor",Vector3(side*7,y+.15,.34),Vector3(.4,.06,.32),m.steel)

func _wheel(p: Node3D, pos: Vector3, radius: float, rim_material: Material) -> void:
	w._wheel_detail(p,pos,radius,rim_material)

func _bus(p: Node3D, whole_roof: bool) -> void:
	p.rotation.z=.11 if whole_roof else -.12
	p.rotation.x=-.045 if whole_roof else .055
	b.box(p,"CorrodedBusChassis",Vector3(0,.5,0),Vector3(2.55,.28,11.9),m.steel,true)
	w._vehicle_sides(p,2.70,11.9,1.48,[-3.8,3.7],.66,m.pale)
	for end in [-1.0,1.0]: b.box(p,"PressedCoachEndPanel",Vector3(0,1.02,end*5.91),Vector3(2.58,.86,.10),m.pale,true)
	for side in [-1.0,1.0]:
		b.box(p,"FadedBusStripe",Vector3(side*1.367,1.25,0),Vector3(.025,.23,11.4),m.ochre)
		for z in [-5.4,-3.6,-1.8,0.0,1.8,3.6,5.4]:
			b.box(p,"BusWindowPillar",Vector3(side*1.34,2.06,z),Vector3(.08,1.34,.08),m.rust)
		b.box(p,"BusWindowTopRail",Vector3(side*1.35,2.71,0),Vector3(.09,.11,11.55),m.rust)
		for z in [-4.5,-2.7,-.9,.9,2.7,4.5]:
			b.box(p,"BusWindowSill",Vector3(side*1.35,1.48,z),Vector3(.09,.09,1.74),m.steel)
			if int(absf(z)*10)%3==0:
				var vertices := PackedVector3Array([Vector3(side*1.355,1.55,z-.75),Vector3(side*1.355,2.30,z-.75),Vector3(side*1.355,1.55,z+.2)])
				w._surface(p,"BusGlassShard",vertices,PackedInt32Array([0,1,2]),m.glass,true)
		for z in [-3.7,3.8]: _wheel(p,Vector3(side*1.4,.63,z),.60,m.rust)
	for z in [-5.92,5.92]:
		b.box(p,"BusEndPillars",Vector3(-1.25,2.1,z),Vector3(.12,1.45,.14),m.rust)
		b.box(p,"BusEndPillars",Vector3(1.25,2.1,z),Vector3(.12,1.45,.14),m.rust)
		b.box(p,"WindshieldDivider",Vector3(0,2.08,z),Vector3(.06,1.35,.08),m.steel)
		b.box(p,"BusCorrodedBumper",Vector3(0,.68,z+.06*signf(z)),Vector3(2.86,.21,.24),m.rust,true)
		for x in [-.83,.83]: b.cylinder(p,"BrokenBusHeadlight",Vector3(x,1.12,z+.07*signf(z)),.16,.06,m.black,Vector3(PI*.5,0,0))
	if whole_roof:
		b.box(p,"BatteredBusRoof",Vector3(0,2.79,0),Vector3(2.8,.15,12),m.pale,true)
	else:
		b.box(p,"CollapsedBusRoof",Vector3(.16,2.75,-2.1),Vector3(2.7,.12,7.6),m.rust,true)
		for z in [2.0,3.8,5.4]: b.rod(p,Vector3(-1.35,2.75,z),Vector3(1.35,2.75,z),.032,m.steel)
	for z in [-4.6,-2.8,-1.0,.8,2.6,4.4]:
		for x in [-.8,.8]:
			b.box(p,"TornBusSeat",Vector3(x,1.15,z),Vector3(.62,.18,.6),m.wood)
			b.box(p,"BusSeatBack",Vector3(x,1.5,z-.30),Vector3(.62,.72,.12),m.rubber)
	b.label(p,"03",Vector3(0,2.44,5.99),22,Color("9f9169"))

func _truck(p: Node3D) -> void:
	b.box(p,"TruckFrame",Vector3(0,.71,0),Vector3(2.55,.30,7.8),m.steel,true)
	b.box(p,"TruckHood",Vector3(0,1.55,2.4),Vector3(2.38,.68,2.1),m.teal,true)
	b.box(p,"CabLowerHalf",Vector3(0,1.37,.62),Vector3(2.5,.85,1.65),m.teal,true)
	b.box(p,"CabRoof",Vector3(0,2.90,.5),Vector3(2.64,.15,1.85),m.teal,true)
	for x in [-1.20,0.0,1.20]: b.box(p,"CabWindshieldPillar",Vector3(x,2.36,1.31),Vector3(.09,1.0,.09),m.rust)
	for x in [-1.20,1.20]: b.box(p,"CabRearPillar",Vector3(x,2.33,-.33),Vector3(.11,1.05,.11),m.rust)
	b.box(p,"TruckBedFloor",Vector3(0,1.22,-2.20),Vector3(2.7,.18,3.6),m.wood,true)
	for side in [-1.0,1.0]:
		for y in [1.52,1.87,2.22]: b.box(p,"TruckBedWoodenSlat",Vector3(side*1.37,y,-2.15),Vector3(.10,.23,3.65),m.wood,true)
		for z in [-3.7,-2.2,-.7]: b.box(p,"TruckBedUpright",Vector3(side*1.41,1.92,z),Vector3(.08,1.40,.13),m.rust)
		for z in [-2.9,-1.5,2.2]: _wheel(p,Vector3(side*1.42,.72,z),.71,m.teal)
		b.rod(p,Vector3(side*1.24,2.33,.9),Vector3(side*1.65,2.43,1.0),.02,m.steel)
		b.box(p,"TruckSideMirror",Vector3(side*1.67,2.41,1),Vector3(.08,.27,.16),m.rust)
	b.box(p,"RustedTruckGrille",Vector3(0,1.4,3.49),Vector3(1.38,.74,.07),m.black)
	for x in [-.52,-.26,0.0,.26,.52]: b.box(p,"TruckGrilleBar",Vector3(x,1.4,3.54),Vector3(.07,.73,.04),m.teal)
	b.box(p,"TruckFrontBumper",Vector3(0,.85,3.61),Vector3(2.81,.21,.26),m.steel,true)
	for x in [-.99,.99]: b.cylinder(p,"BrokenTruckHeadlight",Vector3(x,1.51,3.5),.2,.07,m.black,Vector3(PI*.5,0,0))
	b.rod(p,Vector3(1.28,1.2,-.5),Vector3(1.28,3.5,-.5),.065,m.rust)

func _car(p: Node3D) -> void:
	w._wreck_sedan(p,m.teal,Vector3(1.98,1.76,4.65))

func _radio_tower(p: Node3D) -> void:
	for y in range(0,34,4):
		var radius := 3.4-float(y)*.065
		var next_radius := 3.4-float(y+4)*.065
		for side in 4:
			var a := side*PI*.5+PI*.25
			var next := (side+1)*PI*.5+PI*.25
			var v := Vector3(cos(a)*radius,y,sin(a)*radius)
			var up := Vector3(cos(a)*next_radius,y+4,sin(a)*next_radius)
			var side_up := Vector3(cos(next)*next_radius,y+4,sin(next)*next_radius)
			b.rod(p,v,up,.10,m.rust)
			b.rod(p,v,side_up,.052,m.steel)
			b.rod(p,v,Vector3(cos(next)*radius,y,sin(next)*radius),.052,m.steel)
	b.ring(p,"RadioMaintenancePlatform",Vector3(0,29,0),3.5,.25,m.steel)
	b.ring(p,"PlatformSafetyRail",Vector3(0,30.1,0),3.7,.03,m.rust)
	for i in 12:
		var a := i*TAU/12.0
		b.rod(p,Vector3(cos(a)*3.7,29,sin(a)*3.7),Vector3(cos(a)*3.7,30.1,sin(a)*3.7),.032,m.rust)
	for x in [-1.0,0.0,1.0]: b.rod(p,Vector3(x,30,0),Vector3(x,38+absf(x)*-3,0),.046,m.steel)
	for side in [-1.0,1.0]:
		b.box(p,"CellularAntennaPanel",Vector3(side*1.3,31,0),Vector3(.38,2.5,.22),m.pale)
		b.rod(p,Vector3(side*3.0,0,0),Vector3(side*1.0,27,0),.024,m.steel)
