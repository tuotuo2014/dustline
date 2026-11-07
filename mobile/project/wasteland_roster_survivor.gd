extends "res://reference_survivor.gd"
## Three complete rebuilt identities with distinct anatomy, tailoring and hair silhouettes.
const Faces = preload("res://roster_face_sculpt.gd")
const IDENTITY_SKIN = preload("res://roster_skin.gdshader")
@export_range(1,3) var archetype := 1
var ponytail: Node3D
var _identity_clock := 0.0

func _make_materials() -> void:
	super._make_materials()
	var palette := ["c39479","be998a","af8971"]
	for key in ["skin","face","lid","lip","eye","ear_inner"]:
		materials[key].shader=IDENTITY_SKIN
		materials[key].set_shader_parameter("identity_id",archetype)
	for key in ["skin","face","lid"]:
		materials[key].set_shader_parameter("base_color",Color(palette[archetype-1]))
	materials.face.set_shader_parameter("face_detail",1.0)
	materials.lid.set_shader_parameter("face_detail",1.0)
	materials.lip.set_shader_parameter("base_color",Color("a87367" if archetype<3 else "8e695b"))
	materials.skin_dark=_worn("795645",.84,0,.025,1)
	materials.hair=StandardMaterial3D.new()
	materials.hair.albedo_color=Color("241b17" if archetype==1 else ("10151c" if archetype==2 else "96938b"))
	materials.hair.roughness=.94
	materials.hair.metallic_specular=.07
	materials.hair_light=materials.hair.duplicate()
	materials.cloth=_worn("8a7054" if archetype==1 else ("3c5d70" if archetype==2 else "6b6350"),.94,0,.32)
	materials.pants=_worn("514a3e" if archetype==1 else ("252e34" if archetype==2 else "383b33"),.96,0,.28)
	materials.leather=_worn("6e3627" if archetype==1 else ("293a33" if archetype==2 else "624030"),.79,0,.36)
	materials.scarf=_worn("a18d6b" if archetype==1 else "333d3d",.98,0,.35)
	materials.vest=_worn("85735a" if archetype==1 else ("1b2228" if archetype==2 else "665b42"),.94,0,.3)
	materials.edge=_worn("aa9170" if archetype==1 else ("5b7381" if archetype==2 else "968065"),.90,0,.25)
	materials.metal=_worn("727b79",.48,.72,.22,3)
	materials.rust=_worn("9d4830" if archetype==1 else "655943",.72,.50,.44,3)
	materials.brass=_worn("bc9754",.44,.74,.24,3)
	materials.cape=_worn("897254" if archetype==1 else "70654d",.94,0,.35)
	materials.cape.set_shader_parameter("cloth_motion",1.0)
	materials.cyber=StandardMaterial3D.new()
	materials.cyber.albedo_color=Color("a82d2d")
	materials.cyber.emission_enabled=true
	materials.cyber.emission=Color("f52227")
	materials.cyber.emission_energy_multiplier=1.6
	materials.cyber.roughness=.22

func _face_profile(y: float) -> Vector4:
	return Faces.profile(archetype,y)

func _face_z(x: float,y: float) -> float:
	return Faces.surface_z(archetype,x,y)

func _eye_point(side: float,t: float,upper: bool,opening := 1.0) -> Vector3:
	return Faces.eye_point(archetype,side,t,upper,opening)

func _build_head() -> void:
	super._build_head()
	head.set_meta("identity",["lin_jin","ling_ya","old_mo"][archetype-1])
	head.scale=Vector3(.96,.92,1.0) if archetype<3 else Vector3(1.03,.94,1.02)
	# Lips share the high density topology but use a softer, full female contour.
	if archetype<3:
		var lips := head.get_node("Lips") as MeshInstance3D
		var arrays := lips.mesh.surface_get_arrays(0)
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var p: Vector3=arrays[Mesh.ARRAY_VERTEX][i]
			p.x*=.91 if archetype==1 else .94
			p.y=.065+(p.y-.065)*1.32
			p.z=_face_z(p.x,p.y)-.0016
			arrays[Mesh.ARRAY_VERTEX][i]=p
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_face_mesh_arrays(arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX]))
		lips.mesh=mesh
	if archetype==1:
		var scar: Array=[]
		for i in 12:
			var y := .133-i*.002
			var x := -.057+i*.0009
			scar.append(Vector3(x,y,_face_z(x,y)-.0007))
		_tube(head,"CheekScar",scar,.00065,materials.lip)
		_ring(head,"BronzeEarring",Vector3(-.093,.081,-.003),.013,.0015,materials.brass)
	elif archetype==2:
		_build_optic()
	else:
		_build_beard()

func _build_optic() -> void:
	var optic := _pivot(head,"RedOpticalImplant",Vector3(.037,.151,_face_z(.037,.151)-.010))
	_disc(optic,"TitaniumSocket",Vector3.ZERO,.028,.010,materials.metal)
	_disc(optic,"RecessedBlackLens",Vector3(0,0,-.006),.023,.005,materials.black)
	_ring(optic,"RetainingRing",Vector3(0,0,-.010),.024,.002,materials.rust)
	_disc(optic,"RubyGlass",Vector3(0,0,-.010),.016,.004,materials.cyber)
	_ring(optic,"FocusRing",Vector3(0,0,-.014),.011,.0013,materials.metal)
	_disc(optic,"SensorCore",Vector3(0,0,-.015),.006,.002,materials.cyber)
	for i in 6:
		var a := i*TAU/6
		_ellipsoid(optic,"OpticScrew",Vector3(cos(a)*.026,sin(a)*.026,-.008),Vector3(.0025,.0025,.0015),materials.brass)
	_tube(head,"TempleOpticCable",[Vector3(.062,.161,-.063),Vector3(.083,.16,-.032),Vector3(.091,.141,.014),Vector3(.087,.092,.040)],.0028,materials.black)
	_tube(head,"SignalWire",[Vector3(.065,.175,-.056),Vector3(.083,.18,-.023),Vector3(.09,.14,.024)],.0012,materials.cyber)
	for i in 3:
		_tube(head,"TempleContact",[Vector3(.067,.181+i*.010,-.049),Vector3(.081,.187+i*.009,-.029)],.001,materials.cyber)

func _build_torso() -> void:
	torso=_pivot(self,"Torso",TORSO_REST)
	var woman := archetype<3
	var waist := .145 if woman else .185
	var shoulder := .200 if woman else .239
	_cloth_form(torso,"InnerGarment",Vector3.ZERO,[Vector4(-.10,waist+.016,.10,.005),Vector4(.04,waist,.096,0),Vector4(.19,waist+.012,.115,-.004),Vector4(.33,shoulder-.015,.137,-.005),Vector4(.44,shoulder-.005,.113,.004),Vector4(.49,.069,.063,.006)],materials.vest,.003)
	if archetype==2:
		_cloth_form(torso,"ExposedMidriff",Vector3.ZERO,[Vector4(-.019,.147,.105,.0),Vector4(.038,.148,.111,.0),Vector4(.099,.155,.117,-.002),Vector4(.136,.160,.120,-.003)],materials.skin,.0002)
		_tube(torso,"Navel",[Vector3(0,.043,-.103),Vector3(.001,.053,-.104)],.0014,materials.crease)
	_cloth_form(torso,"TrousersWaist",Vector3.ZERO,[Vector4(-.15,waist+.018,.109,.005),Vector4(-.05,waist+.015,.108,.003),Vector4(.002,waist+.008,.102,0)],materials.pants,.002)
	_loft(torso,"Neck",Vector3(0,.48,.010),[Vector4(0,.048 if woman else .058,.045,0),Vector4(.07,.044 if woman else .052,.044,.002),Vector4(.12,.043 if woman else .050,.043,.002)],materials.skin)
	_open_jacket(shoulder,waist)
	_loft(torso,"UtilityBelt",Vector3.ZERO,[Vector4(-.030,waist+.022,.119,0),Vector4(.015,waist+.022,.119,0)],materials.leather,48)
	_rounded_box(torso,"BeltBuckle",Vector3(0,-.006,-.127),Vector3(.065,.043,.018),materials.metal)
	_rounded_box(torso,"BuckleHole",Vector3(0,-.006,-.139),Vector3(.044,.025,.006),materials.black)
	for side in [-1.0,1.0]:
		_ribbon(torso,"ShoulderHarness",[Vector3(side*(waist-.02),.026,-.124),Vector3(side*(shoulder-.046),.26,-.146),Vector3(side*(shoulder-.05),.45,-.102),Vector3(side*(shoulder-.075),.481,.044),Vector3(side*.10,.32,.148)],.025 if woman else .031,materials.leather)
		_rounded_box(torso,"StrapBuckle",Vector3(side*(shoulder-.05),.354,-.150),Vector3(.035,.046,.013),materials.metal)
		_rounded_box(torso,"BuckleInset",Vector3(side*(shoulder-.05),.354,-.158),Vector3(.020,.026,.004),materials.black)
	# A soft rolled cowl with continuous folds, rather than the original respirator mantle.
	_cloth_form(torso,"ScarfCollar",Vector3(0,.475,.008),[Vector4(-.015,.103,.091,0),Vector4(.01,.108,.094,0),Vector4(.05,.093,.081,.007),Vector4(.085,.066,.061,.012)],materials.scarf,.003)
	scarf_tail=_pivot(torso,"ScarfTail",Vector3(0,.475,-.082))
	_cloth_form(scarf_tail,"FoldedCowl",Vector3.ZERO,[Vector4(-.18,.024,.012,-.060),Vector4(-.10,.099,.025,-.032),Vector4(-.025,.126,.037,.007),Vector4(.043,.085,.039,.016)],materials.scarf,.004)
	for i in 4:
		_tube(scarf_tail,"CowlFold",[Vector3(-.09,.024-i*.024,.003),Vector3(-.045,-.005-i*.032,-.050),Vector3(.026,-.019-i*.031,-.053),Vector3(.094,.015-i*.024,-.012)],.0028,materials.scarf)
	_build_cape()

func _open_jacket(shoulder: float,waist: float) -> void:
	var low := .126 if archetype==2 else -.08
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in 33:
		var t := r/32.0
		var y := lerpf(low,.46,t)
		var width := lerpf(waist+.019,shoulder+.009,smoothstep(.0,.87,t))-.006*exp(-pow((t-.28)/.20,2))
		var depth := .122+sin(t*PI)*(.022 if archetype<3 else .026)
		for c in 65:
			var a := lerpf(-PI*.34,PI*1.34,c/64.0)
			var fold := sin(a*9+t*5)*.0018+sin(t*24-a*2)*.0024*exp(-pow((t-.18)/.22,2))
			verts.append(Vector3(cos(a)*(width+fold),y,sin(a)*(depth+fold)+.005))
			if r<32 and c<64:
				var k := r*65+c
				indices.append_array([k,k+1,k+66,k,k+66,k+65])
	_surface(torso,"OpenTailoredJacket",verts,indices,materials.cloth,true)
	for side in [-1.0,1.0]:
		var lapel := [Vector3(side*(shoulder-.042),.466,-.089),Vector3(side*.064,.359,-.154),Vector3(side*.104,.265,-.156),Vector3(side*(shoulder-.020),.40,-.115)]
		_surface(torso,"LeatherLapel",PackedVector3Array(lapel),PackedInt32Array([0,1,2,0,2,3]),materials.leather if archetype!=2 else materials.cloth,true)
		_tube(torso,"LapelSeam",[lapel[0],lapel[1],lapel[2]],.0012,materials.edge)
		_ellipsoid(torso,"LapelSnap",lapel[1]+Vector3(side*.017,.025,-.002),Vector3(.010,.010,.004),materials.metal)
		if archetype!=2:
			_rounded_box(torso,"CoatChestPocket",Vector3(side*.125,.204,-.132),Vector3(.09,.102,.015),materials.leather)
			_tube(torso,"PocketStitch",[Vector3(side*.08,.24,-.145),Vector3(side*.16,.24,-.145)],.001,materials.edge)
	for i in 4:
		_ellipsoid(torso,"CoatButton",Vector3(-.085,low+.045+i*.071,-.121),Vector3(.008,.008,.004),materials.brass)

func _build_cape() -> void:
	cape=_pivot(torso,"SplitCoatTails",Vector3.ZERO)
	if archetype==2: return
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for panel in 2:
		var start := -.36*PI if panel==0 else .52*PI
		var end := .48*PI if panel==0 else 1.36*PI
		var base := vertices.size()
		for r in 31:
			var t := r/30.0
			for c in 49:
				var a := lerpf(start,end,c/48.0)
				var hem := -.57-.038*sin(a*3)+.018*sin(c*1.71)+.008*sin(c*3.3)
				var y := lerpf(.055,hem,t)
				var width := lerpf(.17 if archetype==1 else .20,.29,t)
				var depth := lerpf(.126,.215,t)
				var fold := t*(sin(a*16-t*4)*.011+sin(a*29)*.005)
				vertices.append(Vector3(cos(a)*(width+fold),y,sin(a)*(depth+fold)+.012+t*.025))
				if r<30 and c<48:
					var k := base+r*49+c
					if r>27 and c%19==0: continue
					indices.append_array([k,k+1,k+50,k,k+50,k+49])
	_surface(cape,"WeatheredCoatPanels",vertices,indices,materials.cape,true)

func _build_arm(side: float) -> void:
	super._build_arm(side)
	var arm: Node3D=arms[-1]
	var elbow: Node3D=elbows[-1]
	var hand: Node3D=elbow.get_node("Hand")
	arm.position.x=side*(.214 if archetype<3 else .251)
	if archetype<3:
		arm.scale=Vector3(.82,1,.88)
	var mechanical := archetype==1 and side<0
	if mechanical:
		_remove_named(arm,["TornSleeve","SleeveTailorSeam","RepairedSleevePatch"])
		_remove_named(elbow,["Elbow","RolledSleeve","LeatherBracer","BracerStrap","BracerBuckle"])
		_robotic_segment(arm,.255,.066,materials.rust,true)
		_robotic_segment(elbow,.244,.049,materials.rust,false)
		_ellipsoid(arm,"RustShoulderShell",Vector3(side*.008,.004,0),Vector3(.173,.145,.153),materials.rust)
		for x in [-.037,.037]:
			_ring(arm,"ShoulderVent",Vector3(x,-.006,-.072),.016,.004,materials.metal)
			_disc(arm,"ShoulderVentInset",Vector3(x,-.006,-.074),.009,.003,materials.black)
	elif archetype==3 or archetype==2:
		_remove_named(elbow,["LeatherBracer","BracerStrap","BracerBuckle"])
		_robotic_segment(elbow,.237,.048,materials.metal,false)
	if mechanical or archetype==3:
		for mesh in hand.find_children("*","MeshInstance3D",true,false):
			mesh.material_override=materials.metal if archetype==3 else materials.rust
			if "Stitch" in str(mesh.name) or "Seam" in str(mesh.name): mesh.visible=false
		for finger in hand.get_children():
			if finger is Node3D and finger.has_meta("finger_index"):
				_ring(finger,"KnuckleBearing",Vector3(0,-.002,-.011),.0055,.0014,materials.metal)
				_tube(finger,"FingerTendon",[Vector3(.003,0,.008),Vector3(.003,-.025,.008)],.0014,materials.black)
		_rounded_box(hand,"DorsalPlate",Vector3(0,-.011,-.028),Vector3(.063,.052,.013),materials.metal)
		for x in [-.023,.023]:
			_ellipsoid(hand,"HandRivet",Vector3(x,-.025,-.037),Vector3(.005,.005,.003),materials.brass)
	if archetype==3:
		_ellipsoid(arm,"SteelShoulderPlate",Vector3(side*.010,.020,-.006),Vector3(.160,.074,.147),materials.metal)
		for x in [-.044,.044]:
			_ellipsoid(arm,"ShoulderBolt",Vector3(x,.0,-.068),Vector3(.010,.010,.005),materials.brass)

func _robotic_segment(parent: Node3D,length: float,width: float,plate: Material,upper: bool) -> void:
	_loft(parent,"ExposedMechanism",Vector3.ZERO,[Vector4(-length,.021,.023,0),Vector4(-length*.82,.032,.033,0),Vector4(-.036,.034,.035,0),Vector4(.014,.027,.026,0)],materials.black,32)
	_cloth_form(parent,"ArmorCasing",Vector3(0,-length*.42,-.020),[Vector4(-length*.38,width*.72,width*.38,0),Vector4(-length*.15,width*.88,width*.47,0),Vector4(length*.28,width,width*.45,0),Vector4(length*.35,width*.80,width*.38,0)],plate,.00035)
	for side in [-1.0,1.0]:
		_tube(parent,"HydraulicPiston",[Vector3(side*width*.77,-.048,.019),Vector3(side*width*.68,-length+.034,.025)],.007,materials.metal)
		_tube(parent,"CableBundle",[Vector3(side*width*.43,-.020,.037),Vector3(side*width*.48,-length*.5,.041),Vector3(side*width*.39,-length+.012,.027)],.003,materials.black)
		for y in [-.062,-length+.051]:
			_ellipsoid(parent,"CasingRivet",Vector3(side*width*.60,y,-.050),Vector3(.006,.006,.004),materials.metal)
	_ring(parent,"JointBearing",Vector3(0,-length,-.012),width*.56,.009,materials.metal)
	_disc(parent,"HingeCore",Vector3(0,-length,-.017),width*.30,.013,materials.black)
	if not upper:
		for i in 4:
			_rounded_box(parent,"CoolingSlot",Vector3(0,-.071-i*.026,-.046),Vector3(width*.6,.006,.008),materials.black)

func _build_leg(side: float) -> void:
	super._build_leg(side)
	if archetype<3:
		legs[-1].scale=Vector3(.86,1,.90)
		legs[-1].position.x=side*.10
	if archetype==2:
		for y in [-.14,-.27]:
			_loft(legs[-1],"ThighHarness",Vector3.ZERO,[Vector4(y-.010,.105,.108,0),Vector4(y+.010,.105,.108,0)],materials.leather,40)
		_rounded_box(legs[-1],"ThighBuckle",Vector3(side*.104,-.14,-.035),Vector3(.010,.028,.035),materials.metal)

func _build_equipment() -> void:
	var shoulder := .155 if archetype<3 else .18
	_rounded_box(torso,"CompactPack",Vector3(0,.26,.158),Vector3(.22,.29,.092),materials.leather)
	for side in [-1.0,1.0]:
		_rounded_box(torso,"UtilityPouch",Vector3(side*(shoulder+.03),-.062,.0),Vector3(.097,.15,.101),materials.leather)
		_rounded_box(torso,"PouchFlap",Vector3(side*(shoulder+.03),-.006,-.049),Vector3(.10,.044,.013),materials.edge)
		_ellipsoid(torso,"PouchClasp",Vector3(side*(shoulder+.03),-.012,-.059),Vector3(.009,.011,.004),materials.brass)
	if archetype==1:
		_loft(torso,"WaterBottle",Vector3(.155,-.06,-.104),[Vector4(-.074,.022,.022,0),Vector4(-.065,.030,.028,0),Vector4(.044,.030,.028,0),Vector4(.060,.017,.016,0),Vector4(.081,.011,.011,0)],materials.metal,32)
		_rounded_box(torso,"BottleCap",Vector3(.155,.025,-.104),Vector3(.027,.020,.024),materials.black)
		_ribbon(torso,"DiagonalLeatherStrap",[Vector3(-.153,.403,-.153),Vector3(-.072,.240,-.155),Vector3(.091,.011,-.144)],.027,materials.leather)
	elif archetype==2:
		_ribbon(torso,"Bandolier",[Vector3(-.16,.425,-.126),Vector3(-.047,.28,-.153),Vector3(.14,.127,-.131)],.031,materials.leather)
		for i in 21:
			var p := Vector3(-.16,.425,-.15).lerp(Vector3(.14,.127,-.153),i/20.0)
			var cell := _loft(torso,"BrassSupplyCell",p,[Vector4(-.023,.004,.004,0),Vector4(.017,.004,.004,0),Vector4(.023,.002,.002,0)],materials.brass,12)
			cell.rotation.z=-.76
	else:
		for settings in [Vector3(-.126,.305,.025),Vector3(-.134,.188,.020),Vector3(.127,.260,.031),Vector3(.127,.105,.045)]:
			_gear(torso,Vector3(settings.x,settings.y,-.156),settings.z)
		_rounded_box(torso,"ToolRoll",Vector3(.189,-.125,-.046),Vector3(.089,.21,.067),materials.leather)
		for i in 4:
			var x := .158+i*.018
			_tube(torso,"ToolHandle",[Vector3(x,-.074,-.078),Vector3(x,.043+i*.009,-.078)],.004,materials.metal)
			_rounded_box(torso,"DriverGrip",Vector3(x,-.039,-.078),Vector3(.013,.064,.012),materials.wood)
		_gear(torso,Vector3(-.22,-.007,-.042),.027)
		_build_wrench(torso,Vector3(-.115,.225,-.174))

func _gear(parent: Node3D,pos: Vector3,radius: float) -> void:
	_ring(parent,"BrassGearRim",pos,radius*.77,radius*.15,materials.brass)
	_disc(parent,"GearAxle",pos,radius*.23,.012,materials.metal)
	for i in 12:
		var a := i*TAU/12
		var spoke := _rounded_box(parent,"GearTooth",pos+Vector3(cos(a),sin(a),0)*radius,Vector3(radius*.29,radius*.26,.009),materials.brass)
		spoke.rotation.z=a
		if i%2==0:
			_tube(parent,"GearSpoke",[pos+Vector3(cos(a),sin(a),0)*radius*.22,pos+Vector3(cos(a),sin(a),0)*radius*.68],radius*.07,materials.brass)

func _build_wrench(parent: Node3D,pos: Vector3) -> void:
	var wrench := _pivot(parent,"HangingWrench",pos)
	wrench.rotation.z=-.16
	_rounded_box(wrench,"SteelHandle",Vector3(0,0,0),Vector3(.016,.183,.009),materials.metal)
	_ring(wrench,"RingSpanner",Vector3(0,-.101,0),.016,.005,materials.metal)
	for side in [-1.0,1.0]:
		_tube(wrench,"OpenJaw",[Vector3(0,.083,0),Vector3(side*.017,.103,0),Vector3(side*.012,.123,0)],.006,materials.metal)

func _remove_named(parent: Node,names: Array) -> void:
	for child in parent.get_children():
		for label in names:
			if str(child.get_meta("part_name",str(child.name))).begins_with(label):
				child.free()
				break

func animate(delta: float,horizontal_speed: float,grounded: bool,vertical_speed: float=0.0) -> void:
	super.animate(delta,horizontal_speed,grounded,vertical_speed)
	_identity_clock+=delta
	if is_instance_valid(ponytail):
		ponytail.rotation.x=sin(phase+.4)*gait*.11+run_blend*.20+landing*.05
		ponytail.rotation.z=-turn_blend*.10+sin(_identity_clock*1.8)*.018

func _build_hair() -> void:
	hair_rng.seed=62100+archetype*123
	var cap_vertices := PackedVector3Array()
	var cap_indices := PackedInt32Array()
	for row in 41:
		for col in 129:
			var a := TAU*col/128
			var y := lerpf(_identity_hairline(a),.262,row/40.0)
			cap_vertices.append(_identity_scalp(a,y))
			if row<40 and col<128:
				var k := row*129+col
				cap_indices.append_array([k,k+1,k+130,k,k+130,k+129])
	_surface(head,"SculptedHairCap",cap_vertices,cap_indices,materials.hair)
	_ellipsoid(head,"CrownFoundation",Vector3(.006 if archetype==2 else -.003,.273,.022),Vector3(.044,.021,.050),materials.hair)
	var fibres := _new_fibres()
	var count := 0
	for i in 1600:
		var a := hair_rng.randf_range(0,TAU)
		var start_y := hair_rng.randf_range(.218,.259)
		var end_y := hair_rng.randf_range(_identity_hairline(a),maxf(_identity_hairline(a)+.001,.226))
		var points := PackedVector3Array()
		for j in 13:
			var t := j/12.0
			var angle := a+(.19 if archetype<3 else -.46)*sin(t*PI*.7)
			var y := lerpf(start_y,end_y,t)
			var p := _identity_scalp(angle,y)
			var lift := sin(t*PI)*(.0015+.0006*sin(a*11))
			p+=Vector3(cos(angle),.5,sin(angle))*lift
			points.append(p)
		_append_identity_strand(fibres,points)
		count+=1
	if archetype==1:
		# Gathered low ponytail plus parted, loose strands around the cheeks.
		for side in [-1.0,1.0]:
			var lock_points := PackedVector3Array()
			for step in 17:
				var t := step/16.0
				lock_points.append(Vector3(side*.035,.269,-.009).bezier_interpolate(Vector3(side*.090,.258,-.075),Vector3(side*.100,.144,-.100),Vector3(side*.072,.046,-.065),t))
			_hair_lock_foundation(lock_points,.014,materials.hair)
			for i in 320:
				var spread := hair_rng.randf_range(-.010,.010)
				var root_point := Vector3(side*(.012+hair_rng.randf_range(0,.034)),.266+hair_rng.randf_range(0,.007),-.009)
				var end := Vector3(side*(.071+spread),hair_rng.randf_range(.027,.10),-.065+hair_rng.randf_range(-.015,.015))
				var points := PackedVector3Array()
				for j in 17:
					var t := j/16.0
					var p := root_point.bezier_interpolate(Vector3(side*.090,.258,-.075),Vector3(side*(.10+spread),.144,-.100),end,t)
					p.x+=sin(t*PI)*spread
					points.append(p)
				_append_identity_strand(fibres,points)
				count+=1
		ponytail=_pivot(head,"LowPonytail",Vector3(0,.075,.101))
		_loft(ponytail,"LeatherHairTie",Vector3.ZERO,[Vector4(-.01,.026,.024,0),Vector4(.012,.026,.024,0)],materials.leather,32)
		var tail := _new_fibres()
		for i in 1200:
			var a := hair_rng.randf_range(0,TAU)
			var radius := sqrt(hair_rng.randf())
			var length := hair_rng.randf_range(.205,.273)
			var points := PackedVector3Array()
			for j in 19:
				var t := j/18.0
				var spread := (.018+.022*sin(t*PI))*radius*pow(1.0-t,.35)
				var p := Vector3(sin(t*4.2)*.024+cos(a)*spread,-length*t,.036*sin(t*PI*.8)+sin(a)*spread+.040*t)
				p.x+=sin(t*8+a)*.003*t
				points.append(p)
			_append_identity_strand(tail,points)
		_commit_fibres(ponytail,tail,"PonytailFineStrands",1200)
	elif archetype==2:
		# Jaw-length asymmetrical bob: an actual curved shell supports separate fine fibres.
		var shell := PackedVector3Array()
		var inds := PackedInt32Array()
		for r in 25:
			for c in 97:
				var a := lerpf(-.17*PI,1.17*PI,c/96.0)
				shell.append(_bob_point(a,r/24.0))
				if r<24 and c<96:
					var k := r*97+c
					inds.append_array([k,k+1,k+98,k,k+98,k+97])
		_surface(head,"BobSilhouette",shell,inds,materials.hair,true)
		for i in 1300:
			var a := hair_rng.randf_range(-.17*PI,1.17*PI)
			var points := PackedVector3Array()
			for j in 17:
				var t := j/16.0
				var p := _bob_point(a+.025*sin(t*PI),t)
				p+=Vector3(cos(a),0,sin(a))*(.0016+.0006*sin(a*17))
				points.append(p)
			_append_identity_strand(fibres,points,i%40==0)
			count+=1
		for lock in 8:
			var lock_x := lerpf(-.081,.015,lock/7.0)
			var lock_hem := .145+.042*absf(lock_x/.085)
			var lock_points := PackedVector3Array()
			for step in 17:
				var t := step/16.0
				lock_points.append(Vector3(.037,.270,-.006).bezier_interpolate(Vector3(-.035,.287,-.083),Vector3(lock_x-.024,.198,-.102),Vector3(lock_x,lock_hem,-.086),t))
			_hair_lock_foundation(lock_points,.009,materials.hair)
			for i in 80:
				var spread := hair_rng.randf_range(-.0055,.0055)
				var start := Vector3(.037+spread,.269+hair_rng.randf_range(0,.006),-.006)
				var x := lerpf(-.081,.015,lock/7.0)+spread
				var end_y := .145+.042*absf(x/.085)+hair_rng.randf_range(-.006,.006)
				var points := PackedVector3Array()
				for j in 17:
					var t := j/16.0
					points.append(start.bezier_interpolate(Vector3(-.035,.287,-.083),Vector3(x-.024,.198,-.102),Vector3(x,end_y,-.086),t))
				_append_identity_strand(fibres,points,lock==0 and i%4==0)
				count+=1
	else:
		# Fine flyaway white strands follow an aged, receding silhouette.
		for i in 1200:
			var a := hair_rng.randf_range(PI+.3,TAU-.3)
			var root_point := _identity_scalp(a,hair_rng.randf_range(.219,.250))
			var end_a := TAU-a+.2
			var end := _identity_scalp(end_a,hair_rng.randf_range(.205,.239))
			var spread := hair_rng.randf_range(-.009,.009)
			var points := PackedVector3Array()
			for j in 17:
				var t := j/16.0
				var p := root_point.bezier_interpolate(Vector3(root_point.x-.012,.274+spread,-.045),Vector3(end.x-.023,.272+spread,.070),end,t)
				p.x+=sin(t*PI)*spread
				points.append(p)
			_append_identity_strand(fibres,points)
			count+=1
	_commit_fibres(head,fibres,"IdentityFineHair",count)

func _identity_hairline(a: float) -> float:
	var front := maxf(0,-sin(a))
	if archetype==3: return .12+.109*pow(front,.50) if sin(a)<0 else .12-.019*sin(a)
	return .118+.092*pow(front,.55) if sin(a)<0 else .118-.033*sin(a)

func _identity_scalp(a: float,y: float) -> Vector3:
	var p := _scalp_point(a,y)
	var crest := smoothstep(.215,.262,y)
	p+=Vector3(cos(a)*.005,crest*.009,sin(a)*.005)
	p.x+=crest*(.010 if archetype==2 else -.007)
	return p

func _bob_point(a: float,t: float) -> Vector3:
	var start := _identity_scalp(a,.235)
	var hem := .024+.026*cos(a)+.003*sin(a*7)
	var end := Vector3(cos(a)*.098,hem,sin(a)*.090+.019)
	return start.bezier_interpolate(Vector3(cos(a)*.111,.229,sin(a)*.106+.023),Vector3(cos(a)*.113,.082,sin(a)*.101+.023),end,t)

func _new_fibres() -> Dictionary:
	return {"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"colors":PackedColorArray(),"indices":PackedInt32Array()}

func _append_identity_strand(buffers: Dictionary,points: PackedVector3Array,red := false) -> void:
	var shade := Color("4a3426") if archetype==1 else (Color("202936") if archetype==2 else Color("b9b6af"))
	if red: shade=Color("7d242c")
	shade*=hair_rng.randf_range(.72,1.24)
	shade.a=1
	_hair_append_fibre(buffers,points,hair_rng.randf_range(.00009,.00018),shade,0)

func _commit_fibres(parent: Node3D,buffers: Dictionary,label: String,count: int) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=buffers.vertices
	arrays[Mesh.ARRAY_NORMAL]=buffers.normals
	arrays[Mesh.ARRAY_COLOR]=buffers.colors
	arrays[Mesh.ARRAY_INDEX]=buffers.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.vertex_color_is_srgb=true
	mat.roughness=.72
	mat.metallic_specular=.26
	var node := MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	node.material_override=mat
	node.set_meta("strand_count",count)
	parent.add_child(node)

func _build_beard() -> void:
	var fibres := _new_fibres()
	for i in 3300:
		var x := hair_rng.randf_range(-.074,.074)
		var y := hair_rng.randf_range(.016,.104)
		var beard_top := .040+.065*pow(absf(x)/.075,1.4)
		if y>beard_top: continue
		var start := Vector3(x,y,_face_z(x,y)-.002)
		var length := hair_rng.randf_range(.006,.016)
		var points := PackedVector3Array()
		for j in 7:
			var t := j/6.0
			points.append(start+Vector3(signf(x)*.003*t,-length*t,-sin(t*PI*.8)*.003))
		_append_identity_strand(fibres,points)
	for side in [-1.0,1.0]:
		for i in 160:
			var x: float = side*hair_rng.randf_range(.002,.028)
			var y := hair_rng.randf_range(.074,.084)
			var start := Vector3(x,y,_face_z(x,y)-.002)
			var points := PackedVector3Array()
			for j in 7:
				var t := j/6.0
				points.append(start+Vector3(side*.011*t,-.011*t,-sin(t*PI)*.003))
			_append_identity_strand(fibres,points)
	_commit_fibres(head,fibres,"WhiteBeardAndMoustache",fibres.vertices.size()/12)

func _hair_lock_foundation(points: PackedVector3Array,width: float,material: Material) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in points.size():
		var t := row/float(points.size()-1)
		var tangent := (points[mini(row+1,points.size()-1)]-points[maxi(0,row-1)]).normalized()
		var side := tangent.cross(Vector3.FORWARD).normalized()
		var half_width := width*pow(1.0-t,.55)*smoothstep(0.0,.20,t)
		for col in 5:
			var s := (col/4.0-.5)*2
			vertices.append(points[row]+side*s*half_width+Vector3(0,0,.002-absf(s)*.002))
			if row<points.size()-1 and col<4:
				var k := row*5+col
				indices.append_array([k,k+1,k+6,k,k+6,k+5])
	_surface(head,"LayeredHairLock",vertices,indices,material,true)
