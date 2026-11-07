extends "res://survivor.gd"
## Anatomical wasteland survivor, rebuilt on the established articulated rig.
## All silhouette meshes are shared by the player and the actual roster preview.

const REFERENCE_SURFACE = preload("res://reference_surface.gdshader")
const REMODEL = preload("res://survivor_remodel_geometry.gd")
# Adult face proportions stay fixed beneath the softly layered hairstyle.
const HEAD_PROPORTIONS := Vector3(.97,.89,1.02)
const FACE_RINGS := [
	Vector4(0,.030,.032,-.014),Vector4(.012,.048,.046,-.014),
	Vector4(.028,.064,.055,-.010),Vector4(.048,.073,.061,-.003),
	Vector4(.075,.074,.066,.004),Vector4(.103,.078,.073,.006),
	Vector4(.13,.087,.081,.007),Vector4(.153,.084,.080,.009),
	Vector4(.177,.083,.083,.013),Vector4(.201,.081,.082,.016),
	Vector4(.224,.073,.075,.018),Vector4(.243,.056,.059,.019),
	Vector4(.257,.027,.03,.019),Vector4(.262,.002,.003,.019)]

var cape: Node3D
var hair_rng := RandomNumberGenerator.new()
var _face_lids: Array[MeshInstance3D] = []
var _face_time := 0.0
var _blink_timer := 2.8
var _blink_elapsed := 1.0
var _finger_joints: Array[Node3D] = []

func _ready() -> void:
	super._ready()
	REMODEL.batch_rigid_details(self)
	set_meta("model_revision",2)
	set_meta("geometry_style","anatomical_wasteland_v2")

func _make_materials() -> void:
	materials.skin=_worn("b88970",.61,.0,.045,1)
	materials.face=materials.skin.duplicate()
	materials.face.set_shader_parameter("face_detail",1.0)
	materials.lid=materials.face.duplicate()
	materials.lid.set_shader_parameter("eyelid_detail",1.0)
	materials.skin_dark=_worn("654638",.84,0,.025,1)
	materials.crease=_worn("946e58",.76,0,0,1)
	materials.ear_inner=_worn("a27661",.76,0,.025,1)
	materials.lip=_worn("956957",.64,0,.025,7)
	materials.hair=_worn("251e19",.78,0,.04,2)
	materials.hair_light=_worn("302720",.79,0,.045,2)
	materials.eye=_worn("c7bfb1",.21,0,0,6)
	materials.iris=_worn("576151",.27,0,0,1)
	materials.black=_worn("171715",.86,0,.13,5)
	materials.cloth=_worn("75634d",.94,0,.35)
	materials.pants=_worn("5c5645",.95,0,.38)
	materials.leather=_worn("493526",.81,0,.32)
	materials.edge=_worn("897659",.93,0,.45)
	materials.metal=_worn("4c4d43",.64,.68,.47,3)
	materials.rust=_worn("694025",.8,.3,.5,3)
	materials.scarf=_worn("484036",.98,0,.65)
	materials.bandage=_worn("71624a",.97,0,.64)
	materials.sole=_worn("26251f",.96,0,.57,5)
	materials.wood=_worn("794624",.76,0,.48,4)
	materials.brass=_worn("81724a",.55,.72,.6,3)
	materials.cape=_worn("5e5847",.97,0,.42)
	materials.cape.set_shader_parameter("cloth_motion",1.0)
	materials.vest=_worn("3e4838",.94,0,.30)

func _worn(hex: String, rough: float, metal: float, wear: float, kind := 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=REFERENCE_SURFACE
	mat.set_shader_parameter("base_color",Color(hex))
	mat.set_shader_parameter("roughness_value",rough)
	mat.set_shader_parameter("metal_value",metal)
	mat.set_shader_parameter("wear",wear)
	mat.set_shader_parameter("weave",1.0 if kind==0 else 0.0)
	mat.set_shader_parameter("material_kind",float(kind))
	return mat

func _build_torso() -> void:
	torso=_pivot(self,"Torso",TORSO_REST)
	_cloth_form(torso,"Jacket",Vector3.ZERO,[
		Vector4(-.10,.185,.112,.006),Vector4(-.04,.183,.116,0),Vector4(.10,.183,.123,0),
		Vector4(.25,.218,.135,.0),Vector4(.39,.25,.132,.004),Vector4(.46,.23,.117,.003),
		Vector4(.5,.085,.066,0)],materials.cloth,.009)
	_loft(torso,"Neck",Vector3(0,.48,.016),[Vector4(0,.060,.051,0),Vector4(.045,.051,.045,0),Vector4(.105,.048,.043,.003),Vector4(.15,.046,.041,.006)],materials.skin)
	_cloth_form(torso,"TrousersWaist",Vector3.ZERO,[Vector4(-.15,.172,.113,.01),Vector4(-.05,.182,.113,0),Vector4(.03,.18,.11,0)],materials.pants,.003)
	_cloth_form(torso,"PlateCarrier",Vector3(0,.03,0),[
		Vector4(.018,.184,.133,0),Vector4(.12,.201,.148,0),Vector4(.29,.222,.154,0),
		Vector4(.37,.206,.143,0)],materials.vest,.0015)
	# Rows of stitched MOLLE webbing, central seams and brass fasteners.
	for row in 5:
		var y := .093+row*.055
		for col in 5:
			var x := (col-2)*.063
			_rounded_box(torso,"Webbing",Vector3(x,y,-.147+absf(x)*.105),Vector3(.06,.019,.012),materials.edge)
			_tube(torso,"Stitch",[Vector3(x-.027,y-.006,-.154+absf(x)*.105),Vector3(x+.027,y-.006,-.154+absf(x)*.105)],.0008,materials.vest)
	for side in [-1.0,1.0]:
		_ribbon(torso,"Harness",[Vector3(side*.162,.021,-.135),Vector3(side*.179,.22,-.159),Vector3(side*.19,.4,-.139),Vector3(side*.15,.48,-.051),Vector3(side*.13,.47,.1)],.04,materials.leather)
		_rounded_box(torso,"HarnessBuckle",Vector3(side*.18,.294,-.177),Vector3(.05,.057,.018),materials.metal)
		_rounded_box(torso,"BuckleOpening",Vector3(side*.18,.294,-.188),Vector3(.032,.037,.003),materials.black)
		_ribbon(torso,"BuckleBar",[Vector3(side*.2,.295,-.192),Vector3(side*.16,.295,-.192)],.007,materials.brass)
	_loft(torso,"Belt",Vector3.ZERO,[Vector4(-.036,.185,.124,0),Vector4(.014,.185,.124,0)],materials.leather,48,.75)
	_rounded_box(torso,"BeltBuckle",Vector3(.018,-.009,-.134),Vector3(.08,.051,.02),materials.metal)
	for x in [-.137,-.077,.097,.15]:
		_rounded_box(torso,"BeltLoop",Vector3(x,-.006,-.125+absf(x)*.1),Vector3(.018,.065,.009),materials.vest)
	scarf_tail=_pivot(torso,"ScarfTail",Vector3(0,.43,-.105))
	_cloth_form(scarf_tail,"CowlFront",Vector3.ZERO,[
		Vector4(-.18,.075,.02,-.048),Vector4(-.11,.135,.024,-.026),Vector4(-.027,.149,.034,0),
		Vector4(.09,.105,.082,.072),Vector4(.125,.065,.049,.08)],materials.scarf,.005)
	for i in 5:
		var y := .271+i*.042
		_tube(torso,"ScarfDrape",[Vector3(-.108,y+.06,-.10),Vector3(-.063,y+.017,-.157),Vector3(.019,y,-.174),Vector3(.097,y+.052,-.111)],.004,materials.scarf)
	_build_cape()
	_build_respirator()
	for side in [-1.0,1.0]:
		_tube(torso,"JacketTailorSeam",[Vector3(side*.176,-.055,-.075),Vector3(side*.184,.12,-.106),Vector3(side*.218,.305,-.096)],.0013,materials.edge)
		_rounded_box(torso,"CollarFastening",Vector3(side*.148,.455,-.086),Vector3(.026,.044,.009),materials.leather)
		_ellipsoid(torso,"CollarSnap",Vector3(side*.148,.452,-.093),Vector3(.008,.008,.004),materials.brass)

func _build_head() -> void:
	head=_pivot(torso,"Head",Vector3(0,.566,0))
	head.scale=HEAD_PROPORTIONS
	_face_lids.clear()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const SEGMENTS := 112
	const ROWS := 96
	for row in ROWS+1:
		var y := .262*row/ROWS
		var profile := _face_profile(y)
		for col in SEGMENTS+1:
			var angle := TAU*col/SEGMENTS
			var x := cos(angle)*profile.y
			var z := sin(angle)*profile.z+profile.w
			if sin(angle)<0.0: z=_face_z(x,y)
			vertices.append(Vector3(x,y,z))
			if row<ROWS and col<SEGMENTS:
				var k := row*(SEGMENTS+1)+col
				indices.append_array([k,k+1,k+SEGMENTS+2,k,k+SEGMENTS+2,k+SEGMENTS+1])
	_surface(head,"Face",vertices,indices,materials.face)
	for side in [-1.0,1.0]:
		_build_face_eye(side)
		_build_face_ear(side)
		var nostril_x: float=side*.0104
		var nostril_z := _face_z(nostril_x,.101)-.0008
		_ellipsoid(head,"Nostril",Vector3(nostril_x,.1008,nostril_z),Vector3(.0038,.0017,.0015),materials.skin_dark).rotation.z=-side*.19
	# A vermilion border and separate, curved lip planes keep the mouth restrained.
	var lip_vertices := PackedVector3Array()
	var lip_indices := PackedInt32Array()
	for lip_row in 9:
		for lip_col in 49:
			var t := lip_col/48.0
			var x := lerpf(-.0275,.0275,t)
			var fullness := pow(sin(t*PI),.85)
			var cupid := .0015*exp(-pow((absf(x)-.0082)/.0052,2))
			var upper := .065+fullness*.0025+cupid
			var lower := .065-fullness*.0045
			var v := lip_row/8.0
			var y := lerpf(lower,upper,v)
			var z := _face_z(x,y)-fullness*(.0007+sin(v*PI)*.0015)
			lip_vertices.append(Vector3(x,y,z))
			if lip_row<8 and lip_col<48:
				var k := lip_row*49+lip_col
				lip_indices.append_array([k,k+1,k+50,k,k+50,k+49])
	_surface(head,"Lips",lip_vertices,lip_indices,materials.lip,true)
	var mouth_line: Array=[]
	for step in 25:
		var x := lerpf(-.0271,.0271,step/24.0)
		var y := .0649-.0006*sin(step/24.0*PI)
		mouth_line.append(Vector3(x,y,_face_z(x,y)-.0023*pow(sin(step/24.0*PI),.7)-.0003))
	_tube(head,"Mouth",mouth_line,.00028,materials.skin_dark)
	_build_hair()

func _face_profile(y: float) -> Vector4:
	# Cubic interpolation removes the old horizontal contour steps in side light.
	var ring := 0
	while ring<FACE_RINGS.size()-2 and y>FACE_RINGS[ring+1].x: ring+=1
	var b: Vector4=FACE_RINGS[ring]
	var c: Vector4=FACE_RINGS[ring+1]
	var a: Vector4=FACE_RINGS[maxi(0,ring-1)]
	var d: Vector4=FACE_RINGS[mini(FACE_RINGS.size()-1,ring+2)]
	var t := clampf((y-b.x)/(c.x-b.x),0,1)
	var result: Vector4=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
	result.x=y
	return result

func _face_z(x: float,y: float) -> float:
	var profile := _face_profile(y)
	var s := sqrt(maxf(0.0,1.0-pow(x/maxf(profile.y,.001),2)))
	var front := pow(s,2.5)
	var z := -pow(s,.64)*profile.z+profile.w
	# Connected facial planes: a clean nose bridge, defined malar arch and
	# a shallow hollow under the cheek flow into an angular but human jaw.
	var bridge := .0180*exp(-pow((y-.142)/.034,2)-pow((x-.0007)/.0095,2))
	var tip := .0268*exp(-pow((y-.111)/.0105,2)-pow((x-.0006)/.0105,2))
	var wings := .0082*exp(-pow((y-.104)/.0068,2)-pow((absf(x)-.0115)/.0048,2))
	var cheek := .0102*exp(-pow((y-.126)/.020,2)-pow((absf(x)-.057)/.017,2))
	var cheek_hollow := .0032*exp(-pow((y-.091)/.018,2)-pow((absf(x)-.054)/.019,2))
	var mouth_plane := .0060*exp(-pow((y-.066)/.017,2)-pow(x/.031,2))
	var philtrum := .0012*exp(-pow((y-.083)/.010,2)-pow(x/.0028,2))
	var chin := .0100*exp(-pow((y-.024)/.013,2)-pow(x/.027,4))
	var chin_fold := .0023*exp(-pow((y-.044)/.0045,2)-pow(x/.024,2))
	var mandible := .0040*exp(-pow((y-.048)/.013,2)-pow((absf(x)-.063)/.014,2))
	var socket := .0075*exp(-pow((y-.151)/.012,2)-pow((absf(x)-.037)/.019,2))
	var brow_plane := .0083*exp(-pow((y-.165)/.009,2)-pow((absf(x)-.037)/.028,2))
	var lower_orbit := .0027*exp(-pow((y-.137)/.006,2)-pow((absf(x)-.037)/.020,2))
	var nasolabial := .0011*exp(-pow((absf(x)-(.018+(.106-y)*.30))/.0038,2)-pow((y-.082)/.026,4))
	var alar_fold := .0016*exp(-pow((absf(x)-.0150)/.0025,2)-pow((y-.105)/.006,2))
	var lower_lip := .0016*exp(-pow((y-.058)/.0055,2)-pow(x/.022,4))
	return z-(bridge+tip+wings+cheek+mouth_plane+chin+mandible+brow_plane+lower_orbit+lower_lip-socket-philtrum-cheek_hollow-chin_fold-nasolabial-alar_fold)*front

func _eye_point(side: float,t: float,upper: bool,opening := 1.0) -> Vector3:
	var x := side*.037+lerpf(-.0164,.0164,t)
	var arc := pow(sin(t*PI),.83)
	var tilt := side*(x-side*.037)*.060
	var y := .1508+tilt+arc*((.0039 if upper else -.0033)*opening-.0010*(1.0-opening))
	# The rim follows the actual sculpted face rather than a floating eye disc.
	var z := _face_z(x,y)-.00050-arc*.00055
	return Vector3(x,y,z)

func _build_face_eye(side: float) -> void:
	var pivot := _pivot(head,"Eye",Vector3(side*.037,.1508,0))
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in 9:
		for col in 49:
			var t := col/48.0
			var upper := _eye_point(side,t,true)
			var lower := _eye_point(side,t,false)
			var point := lower.lerp(upper,row/8.0)
			point.z-=sin(row/8.0*PI)*sin(t*PI)*.0013
			vertices.append(point-pivot.position)
			if row<8 and col<48:
				var k := row*49+col
				indices.append_array([k,k+1,k+50,k,k+50,k+49])
	var eye_mesh := _surface(pivot,"EyeWhite",vertices,indices,materials.eye,true)
	eye_mesh.set_instance_shader_parameter("eye_side",side)
	for upper in [true,false]:
		_build_face_lid(side,upper)
	# Tiny tear ducts and lid creases are joined to the socket surface.
	var duct_x: float=side*.0222
	_ellipsoid(head,"TearDuct",Vector3(duct_x,.1506,_face_z(duct_x,.1508)-.0022),Vector3(.0022,.0014,.001),materials.lip)
	var crease: Array=[]
	for step in 25:
		var t := .08+step/24.0*.84
		var point := _eye_point(side,t,true)
		point.y+=.0025*sin(t*PI)
		point.z=_face_z(point.x,point.y)-.00016
		crease.append(point)
	_tube(head,"LidCrease",crease,.00019,materials.crease)

func _build_face_lid(side: float,upper: bool) -> void:
	var vertices := PackedVector3Array()
	var closed := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in 6:
		var v := row/5.0
		for col in 49:
			var t := col/48.0
			var edge := _eye_point(side,t,upper)
			var shut := _eye_point(side,t,upper,0.0)
			var outside := edge
			outside.y+=(.0054 if upper else -.0042)*pow(sin(t*PI),.7)
			outside.z=_face_z(outside.x,outside.y)-.00012
			var point := edge.lerp(outside,v)
			point.z-=sin(v*PI)*.00015
			var shut_point := shut.lerp(outside,v)
			shut_point.z-=sin(v*PI)*.00020
			vertices.append(point)
			closed.append(shut_point)
			if row<5 and col<48:
				var k := row*49+col
				if upper: indices.append_array([k,k+1,k+50,k,k+50,k+49])
				else: indices.append_array([k,k+50,k+1,k,k+49,k+50])
	var base_arrays := _face_mesh_arrays(vertices,indices)
	var closed_arrays := _face_mesh_arrays(closed,indices)
	# Match the surrounding skin normals along the seam; no raised eye-mask edge.
	for row in 6:
		var match_weight := smoothstep(.35,1.0,row/5.0)
		for col in 49:
			var k := row*49+col
			var p: Vector3=vertices[k]
			var nx := (_face_z(p.x+.0001,p.y)-_face_z(p.x-.0001,p.y))/.0002
			var ny := (_face_z(p.x,p.y+.0001)-_face_z(p.x,p.y-.0001))/.0002
			var skin_normal := Vector3(nx,ny,-1).normalized()
			base_arrays[Mesh.ARRAY_NORMAL][k]=base_arrays[Mesh.ARRAY_NORMAL][k].lerp(skin_normal,match_weight).normalized()
			closed_arrays[Mesh.ARRAY_NORMAL][k]=closed_arrays[Mesh.ARRAY_NORMAL][k].lerp(skin_normal,match_weight).normalized()
	# Blend shapes contain only deformed vertex/normal/tangent arrays.
	closed_arrays[Mesh.ARRAY_INDEX]=null
	var mesh := ArrayMesh.new()
	mesh.add_blend_shape("Blink")
	mesh.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,base_arrays,[closed_arrays])
	var node := MeshInstance3D.new()
	node.name="UpperLid" if upper else "LowerLid"
	node.mesh=mesh
	node.material_override=materials.lid
	head.add_child(node)
	_face_lids.append(node)

func _face_mesh_arrays(vertices: PackedVector3Array,indices: PackedInt32Array) -> Array:
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
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_INDEX]=indices
	return arrays

func _build_face_ear(side: float) -> void:
	# One continuous pinna with a rolled helix, recessed concha and attached lobe.
	# The old stacked ellipsoids made ears look like separate beads.
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in 13:
		var r := row/12.0
		for col in 49:
			var a := TAU*col/48.0
			var lobe := maxf(0.0,-cos(a))
			var y := .119+cos(a)*(.022-lobe*.002)*r
			var z := .010+sin(a)*(.013-lobe*.003)*r
			var roll := exp(-pow((r-.80)/.14,2))*.0034
			var antihelix := exp(-pow((r-.47)/.12,2))*.0018*(.5+.5*cos(a))
			var x := side*(.085+.009*sin(r*PI*.5)+roll+antihelix-.002*(1-r))
			vertices.append(Vector3(x,y,z))
			if row<12 and col<48:
				var k := row*49+col
				if side>0: indices.append_array([k,k+50,k+1,k,k+49,k+50])
				else: indices.append_array([k,k+1,k+50,k,k+50,k+49])
	_surface(head,"Ear",vertices,indices,materials.skin,true)
	_ellipsoid(head,"EarCanal",Vector3(side*.089,.117,-.001),Vector3(.0025,.007,.005),materials.ear_inner)
	_ellipsoid(head,"EarTragus",Vector3(side*.091,.113,-.002),Vector3(.004,.007,.005),materials.skin)

func animate_face(delta: float,horizontal_speed: float) -> void:
	_face_time+=delta
	_blink_timer-=delta
	if _blink_timer<=0.0:
		_blink_elapsed=0.0
		_blink_timer=3.2+1.35*(.5+.5*sin(_face_time*1.73))
	_blink_elapsed+=delta
	# Quick closure, a brief contact, and a gentler reopening.
	var blink := 0.0
	if _blink_elapsed<.062: blink=smoothstep(0.0,.062,_blink_elapsed)
	elif _blink_elapsed<.092: blink=1.0
	elif _blink_elapsed<.20: blink=1.0-smoothstep(.092,.20,_blink_elapsed)
	for lid in _face_lids: lid.set_blend_shape_value(0,blink)
	materials.eye.set_shader_parameter("eye_closure",blink)
	materials.lid.set_shader_parameter("eye_closure",blink)
	var gaze_weight := 1.0-clampf(horizontal_speed/7.8,0.0,1.0)*.55
	materials.eye.set_shader_parameter("eye_gaze",Vector2(sin(_face_time*.41)*.0007,sin(_face_time*.27)*.00025)*gaze_weight)

func _build_hair() -> void:
	hair_rng.seed=9271
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const ROWS := 32
	const COLS := 112
	for row in ROWS+1:
		for col in COLS+1:
			var a := TAU*col/COLS
			vertices.append(_styled_hair_point(a,lerpf(_hair_short_line(a),.262,row/float(ROWS))))
			if row<ROWS and col<COLS:
				var k := row*(COLS+1)+col
				indices.append_array([k,k+1,k+COLS+2,k,k+COLS+2,k+COLS+1])
	var undercoat := ShaderMaterial.new()
	undercoat.shader=preload("res://reference_hair.gdshader")
	undercoat.set_shader_parameter("hair_color",Color("201b17"))
	undercoat.set_shader_parameter("skin_color",materials.skin.get_shader_parameter("base_color"))
	_surface(head,"CroppedSides",vertices,indices,undercoat)
	var fibres := {
		"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"colors": PackedColorArray(), "indices": PackedInt32Array()
	}
	# A close temple fade supports the swept top. Fine roots follow the scalp,
	# with consistent upward/backward flow instead of a forward-hanging fringe.
	for strand in 1700:
		var a := hair_rng.randf_range(0,TAU)
		var low := _hair_short_line(a)
		var start_y := lerpf(low+.012,.252,hair_rng.randf())
		var end_y := maxf(low-.001,start_y-hair_rng.randf_range(.018,.04))
		var sweep := hair_rng.randf_range(-.14,.07)
		var lift := hair_rng.randf_range(.0003,.0011)
		var tip := .0002
		if start_y<.208: end_y=maxf(low,start_y-hair_rng.randf_range(.004,.011))
		if strand>=550 and strand<1650:
			start_y=hair_rng.randf_range(maxf(.208,low+.008),.255)
			end_y=minf(.260,start_y+hair_rng.randf_range(.020,.043))
			sweep=hair_rng.randf_range(-.65,-.32)
			lift=hair_rng.randf_range(.0008,.0022)
		elif strand>=1650:
			start_y=hair_rng.randf_range(.218,.254)
			end_y=minf(.260,start_y+hair_rng.randf_range(.006,.018))
			sweep=hair_rng.randf_range(-.55,-.23)
			lift=hair_rng.randf_range(.002,.003)
			tip=hair_rng.randf_range(.0015,.0035)
		var points := PackedVector3Array()
		var wobble := hair_rng.randf_range(0,TAU)
		for step in 17:
			var t := step/16.0
			var angle := a+sweep*(t*.65+t*t*.35)
			var y := lerpf(start_y,end_y,t)
			var outward := Vector3(cos(angle),smoothstep(.193,.26,y),sin(angle)).normalized()
			var point := _styled_hair_point(angle,y)+outward*(.00018+sin(t*PI)*lift+pow(t,3)*tip)
			point.x+=sin(t*PI)*sin(t*4.0+wobble)*.00045
			points.append(point)
		var shade := Color("322a22")*hair_rng.randf_range(.79,1.16)
		shade.a=1.0
		_hair_append_fibre(fibres,points,hair_rng.randf_range(.000075,.00014),shade,hair_rng.randf_range(.015,.04))
	# Broad, shallow quiff layers rise from the exposed forehead and sweep back
	# diagonally. Each lock contains fine individual fibres, not a solid spike.
	for lock in 32:
		var a := PI+.28+lock/31.0*(PI-.56)
		var root_y := _hair_short_line(a)+hair_rng.randf_range(.001,.022)
		var start := _styled_hair_point(a,root_y)
		var end_a := clampf(TAU-a+.40,.28,PI-.28)
		var end_y := hair_rng.randf_range(.232,.248)
		var end := _styled_hair_point(end_a,end_y)+Vector3(-.003,.0005,.001)
		var quiff := .280+.018*exp(-pow((start.x-.018)/.068,2))+hair_rng.randf_range(-.003,.003)
		var c1 := Vector3(start.x*.70-.019,quiff,start.z*.74)
		var c2 := Vector3(end.x*.60-.025,quiff-.012,end.z*.40)
		var width := hair_rng.randf_range(.0055,.0080)
		var lock_points := PackedVector3Array()
		for knot in 13:
			lock_points.append(start.bezier_interpolate(c1,c2,end,knot/12.0))
		REMODEL.append_hair_lock(fibres,lock_points,width,Color("2a231e"))
		for strand in 40:
			var spread := hair_rng.randf_range(-1,1)
			var depth := hair_rng.randf_range(-.0012,.0012)
			var start_t := hair_rng.randf_range(0,.11)
			var height_offset := hair_rng.randf_range(-.002,.002)
			var points := PackedVector3Array()
			for step in 19:
				var t := step/18.0
				var curve_t := lerpf(start_t,1.0,t)
				var point := start.bezier_interpolate(c1,c2,end,curve_t)
				point+=Vector3(width*spread*(1-t*.72),(depth+height_offset)*sin(t*PI),spread*.0015*sin(t*PI))
				points.append(point)
			var shade := Color("342b23")*hair_rng.randf_range(.82,1.16)
			shade.a=1.0
			_hair_append_fibre(fibres,points,hair_rng.randf_range(.000085,.00014),shade,.025)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=fibres.vertices
	arrays[Mesh.ARRAY_NORMAL]=fibres.normals
	arrays[Mesh.ARRAY_COLOR]=fibres.colors
	arrays[Mesh.ARRAY_INDEX]=fibres.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var strand_material := StandardMaterial3D.new()
	strand_material.vertex_color_use_as_albedo=true
	strand_material.vertex_color_is_srgb=true
	strand_material.roughness=.78
	strand_material.metallic_specular=.20
	var node := MeshInstance3D.new()
	node.name="WildFineHair"
	node.mesh=mesh
	node.material_override=strand_material
	node.set_meta("strand_count",2980)
	node.set_meta("style","weathered_side_swept_layers")
	head.add_child(node)

func _hair_short_line(a: float) -> float:
	var front := maxf(0,-sin(a))
	var low := .139+.077*pow(front,.52) if sin(a)<0 else .139-.032*sin(a)
	# A restrained M-shaped hairline opens the forehead and temples.
	return low+.0035*cos(a)*front+.0018*sin(a*3.0+.7)*front+.00032*sin(a*73.0)

func _styled_hair_point(a: float,y: float) -> Vector3:
	var p := _scalp_point(a,y)
	var top := smoothstep(.19,.256,y)
	var crest := smoothstep(.23,.262,y)
	var front := maxf(-sin(a),0.0)
	# Broad curved volume, not disconnected upright spikes. The crest sweeps
	# to the wearer's left, with soft low ridges separating the overlapping layers.
	var wave := sin(a*5.0+y*64.0)*.0014+sin(a*9.0-y*45.0)*.0006
	var fullness := top*(.0017+front*.0015+wave)*(1.0-crest*.6)
	p+=Vector3(cos(a)*fullness,top*(.005+crest*.003)+wave*top*(1.0-crest),sin(a)*fullness)
	p.x-=crest*.006
	p.z+=crest*.005
	return p

func _hair_append_fibre(buffers: Dictionary, points: PackedVector3Array, radius: float, shade: Color, dust := .0) -> void:
	# Smooth-normal triangular micro tubes share one ArrayMesh and one draw call.
	# This remains opaque, avoiding transparency sorting and alpha shimmer.
	const SIDES := 3
	var sampled := PackedVector3Array()
	for knot in range(0,points.size(),2): sampled.append(points[knot])
	if sampled[-1]!=points[-1]: sampled.append(points[-1])
	points=sampled
	var base: int=buffers.vertices.size()
	var previous_normal := Vector3.ZERO
	for row in points.size():
		var t := row/float(points.size()-1)
		var tangent := (points[mini(row+1,points.size()-1)]-points[maxi(row-1,0)]).normalized()
		var axis := Vector3.UP if absf(tangent.y)<.92 else Vector3.RIGHT
		var normal := tangent.cross(axis).normalized()
		if row>0:
			normal=(previous_normal-tangent*previous_normal.dot(tangent)).normalized()
		var binormal := normal.cross(tangent).normalized()
		previous_normal=normal
		var taper := lerpf(1.0,.055,pow(t,1.7))*lerpf(.3,1.0,smoothstep(0.0,.11,t))
		for side in SIDES:
			var angle := TAU*side/SIDES
			var radial := cos(angle)*normal+sin(angle)*binormal
			buffers.vertices.append(points[row]+radial*radius*taper)
			buffers.normals.append(radial)
			buffers.colors.append(shade.lerp(Color("89765a"),smoothstep(.42,1.0,t)*dust))
			if row<points.size()-1:
				var k := base+row*SIDES+side
				var next := base+row*SIDES+(side+1)%SIDES
				buffers.indices.append_array([k,next,next+SIDES,k,next+SIDES,k+SIDES])

func _scalp_point(a: float, y: float) -> Vector3:
	# Match the smoothed face profile so no scalp peaks through between locks.
	var profile := _face_profile(clampf(y,0,.262))
	var crown := smoothstep(.204,.258,y)
	return Vector3(cos(a)*(profile.y+.0025),y+.0022+crown*.006,signf(sin(a))*pow(absf(sin(a)),.52 if sin(a)<0 else 1.0)*(profile.z+.0025)+profile.w)

func _build_arm(side: float) -> void:
	var arm := _pivot(torso,"LeftArm" if side<0 else "RightArm",Vector3(side*.252,.431,0))
	arms.append(arm)
	_cloth_form(arm,"TornSleeve",Vector3.ZERO,[Vector4(-.274,.054,.055,0),Vector4(-.22,.067,.068,0),Vector4(-.12,.078,.078,0),Vector4(-.04,.079,.076,0),Vector4(.026,.053,.054,0)],materials.cloth,.004)
	var elbow := _pivot(arm,"Elbow",Vector3(0,-.272,0))
	elbows.append(elbow)
	_ellipsoid(elbow,"Elbow",Vector3.ZERO,Vector3(.111,.12,.12),materials.cloth)
	_cloth_form(elbow,"RolledSleeve",Vector3.ZERO,[Vector4(-.245,.039,.038,0),Vector4(-.17,.047,.05,0),Vector4(-.06,.06,.06,0),Vector4(.01,.052,.056,0)],materials.cloth,.003)
	_cloth_form(elbow,"LeatherBracer",Vector3(0,-.12,0),[Vector4(-.09,.046,.043,0),Vector4(-.055,.05,.051,0),Vector4(.075,.057,.058,0)],materials.wood,.0007)
	for y in [-.185,-.06]:
		_loft(elbow,"BracerStrap",Vector3.ZERO,[Vector4(y-.01,.055,.058,0),Vector4(y+.01,.055,.058,0)],materials.leather)
		_rounded_box(elbow,"BracerBuckle",Vector3(side*.053,y,-.009),Vector3(.008,.03,.025),materials.metal)
	var hand := _pivot(elbow,"Hand",Vector3(0,-.265,0))
	_cloth_form(hand,"LeatherGlove",Vector3.ZERO,[Vector4(-.056,.029,.021,-.002),Vector4(-.038,.037,.024,-.001),Vector4(-.015,.039,.025,.001),Vector4(.009,.031,.022,0),Vector4(.025,.023,.020,0)],materials.leather,.0005)
	# Thumb eminence is joined to the palm under the glove rather than a sphere.
	_loft(hand,"ThumbPad",Vector3(-side*.025,-.009,.003),[Vector4(-.027,.010,.014,-.002),Vector4(-.006,.017,.019,0),Vector4(.018,.012,.012,0)],materials.leather,20)
	for finger in 4:
		var finger_root := _pivot(hand,"FingerJoint",Vector3(-.027+finger*.018,-.046+absf(1.5-finger)*.004,-.004))
		finger_root.set_meta("finger_index",finger)
		_finger_joints.append(finger_root)
		var length := .029-absf(1.5-finger)*.003
		_loft(finger_root,"GlovedFinger",Vector3.ZERO,[Vector4(-length,.0068,.008,0),Vector4(-.014,.0086,.010,0),Vector4(.003,.0076,.009,0)],materials.leather,16)
		var knuckle := _pivot(finger_root,"DistalJoint",Vector3(0,-length,0))
		knuckle.rotation.x=.34
		_loft(knuckle,"FingerTip",Vector3.ZERO,[Vector4(-length,.004,.005,0),Vector4(-length+.004,.007,.008,0),Vector4(-.007,.0077,.009,0),Vector4(.003,.0077,.009,0)],materials.skin,16)
		_ellipsoid(knuckle,"FingerNail",Vector3(0,-length+.010,-.0058),Vector3(.008,.010,.0016),materials.crease)
		_tube(finger_root,"FingerStitch",[Vector3(.006,-.004,-.006),Vector3(.006,-length+.004,-.006)],.00055,materials.edge)
		_ellipsoid(finger_root,"KnucklePad",Vector3(0,-.008,-.008),Vector3(.012,.011,.006),materials.leather)
	var thumb := _pivot(hand,"Thumb",Vector3(-side*.034,-.011,-.004))
	thumb.rotation=Vector3(.25,0,side*.50)
	_loft(thumb,"ThumbGlove",Vector3.ZERO,[Vector4(-.038,.005,.007,-.007),Vector4(-.029,.009,.010,-.006),Vector4(-.010,.011,.012,0),Vector4(.007,.009,.010,0)],materials.leather,20)
	for i in 3:
		_tube(hand,"GloveSeam",[Vector3(-.02+i*.02,.005,-.026),Vector3(-.02+i*.02,-.035,-.026)],.001,materials.edge)
	_tube(arm,"SleeveTailorSeam",[Vector3(side*.065,.006,.039),Vector3(side*.074,-.10,.034),Vector3(side*.057,-.255,.025)],.0013,materials.edge)
	var patch := _rounded_box(arm,"RepairedSleevePatch",Vector3(side*.071,-.137,-.010),Vector3(.007,.068,.057),materials.vest)
	patch.rotation.z=side*.05
	for row in 6:
		var y := -.163+row*.010
		_tube(arm,"PatchStitch",[Vector3(side*.076,y,-.038),Vector3(side*.076,y+.004,-.033)],.0007,materials.edge)

func _build_leg(side: float) -> void:
	# Keep the tested sole and joint transforms, replace the old narrow trousers.
	super._build_leg(side)
	var leg: Node3D=legs[-1]
	var knee: Node3D=knees[-1]
	var ankle: Node3D=ankles[-1]
	for label in ["TrouserThigh","CargoPocket","CargoFlap"]:
		leg.get_node(label).free()
	for label in ["TrouserShin","KneePad","KneePlate"]:
		knee.get_node(label).free()
	_cloth_form(leg,"CargoTrousers",Vector3.ZERO,[Vector4(-.4,.066,.071,0),Vector4(-.33,.083,.089,0),Vector4(-.20,.098,.10,.008),Vector4(-.1,.103,.104,.005),Vector4(.03,.092,.091,0)],materials.pants,.005)
	_cloth_form(knee,"WrinkledTrouserShin",Vector3.ZERO,[Vector4(-.37,.05,.052,0),Vector4(-.29,.068,.078,.004),Vector4(-.17,.076,.081,.004),Vector4(-.06,.073,.076,0),Vector4(.02,.065,.069,0)],materials.pants,.005)
	_rounded_box(leg,"CargoPocket",Vector3(side*.094,-.197,.01),Vector3(.048,.185,.14),materials.cloth)
	_rounded_box(leg,"CargoFlap",Vector3(side*.119,-.128,.01),Vector3(.012,.041,.143),materials.edge)
	_ellipsoid(knee,"WornKneeArmor",Vector3(0,-.015,-.06),Vector3(.142,.188,.066),materials.edge)
	for x in [-.048,.048]:
		for y in [-.068,.038]:
			_ellipsoid(knee,"KneeRivet",Vector3(x,y,-.086),Vector3(.009,.009,.005),materials.metal)
	_cloth_form(ankle,"BootGaiter",Vector3(0,.018,.0),[Vector4(-.045,.056,.071,0),Vector4(.015,.06,.065,0),Vector4(.089,.058,.063,0),Vector4(.12,.062,.069,0)],materials.leather,.003)
	for i in 4:
		_rounded_box(ankle,"SoleTread",Vector3(0,-.142,-.15+i*.067),Vector3(.132,.023,.017),materials.sole)
	_refine_boot(ankle)

func _refine_boot(ankle: Node3D) -> void:
	for label in ["Boot","ToeCap"]:
		ankle.get_node(label).free()
	var sections := [Vector4(-.187,.006,.010,-.116),Vector4(-.178,.034,.025,-.113),
		Vector4(-.147,.054,.041,-.108),Vector4(-.094,.058,.047,-.099),
		Vector4(-.035,.057,.071,-.081),Vector4(.034,.055,.072,-.078),
		Vector4(.073,.050,.056,-.092),Vector4(.083,.026,.041,-.105)]
	var smooth_sections: Array=[]
	for i in sections.size()-1:
		var a: Vector4=sections[maxi(0,i-1)]
		var b: Vector4=sections[i]
		var c: Vector4=sections[i+1]
		var d: Vector4=sections[mini(sections.size()-1,i+2)]
		for j in 3:
			var t := j/3.0
			var p: Vector4=.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
			p.x=lerpf(b.x,c.x,t)
			smooth_sections.append(p)
	smooth_sections.append(sections[-1])
	sections=smooth_sections
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in sections.size():
		var profile: Vector4=sections[row]
		for col in 41:
			var a := col/40.0*TAU
			vertices.append(Vector3(cos(a)*profile.y,profile.w+sin(a)*profile.z,profile.x))
			if row<sections.size()-1 and col<40:
				var k := row*41+col
				indices.append_array([k,k+42,k+1,k,k+41,k+42])
	_surface(ankle,"SculptedBootUpper",vertices,indices,materials.leather)
	for side in [-1.0,1.0]:
		_tube(ankle,"BootWeltStitch",[Vector3(side*.026,-.134,-.18),Vector3(side*.052,-.132,-.145),Vector3(side*.06,-.133,-.055),Vector3(side*.052,-.132,.063)],.0008,materials.edge)
		_tube(ankle,"BootPanelSeam",[Vector3(side*.040,-.079,-.144),Vector3(side*.052,-.059,-.074),Vector3(side*.047,.026,-.009)],.0011,materials.leather)

func _build_equipment() -> void:
	_rounded_box(torso,"Backpack",Vector3(0,.249,.16),Vector3(.294,.36,.15),materials.vest)
	for side in [-1.0,1.0]:
		_rounded_box(torso,"MagazinePouch",Vector3(side*.131,.08,-.158),Vector3(.077,.158,.071),materials.leather)
		_rounded_box(torso,"PouchFlap",Vector3(side*.131,.143,-.198),Vector3(.079,.045,.012),materials.edge)
		_ellipsoid(torso,"PouchButton",Vector3(side*.131,.139,-.207),Vector3(.011,.011,.005),materials.brass)
	_rounded_box(torso,"HipSatchel",Vector3(-.213,-.095,.009),Vector3(.114,.207,.117),materials.leather)
	_ellipsoid(torso,"Canteen",Vector3(.22,-.019,.08),Vector3(.105,.172,.09),materials.metal)
	_rounded_box(torso,"CanteenCap",Vector3(.22,.074,.08),Vector3(.036,.025,.035),materials.black)

func _build_respirator() -> void:
	var mask := _pivot(torso,"Respirator",Vector3(0,.448,-.209))
	_loft(mask,"RubberFacepiece",Vector3.ZERO,[Vector4(-.085,.025,.032,0),Vector4(-.042,.062,.042,0),Vector4(.021,.061,.048,0),Vector4(.07,.036,.032,.004),Vector4(.10,.018,.018,.009)],materials.black,48)
	for side in [-1.0,1.0]:
		var filter := _pivot(mask,"FilterLeft" if side<0 else "FilterRight",Vector3(side*.066,-.012,-.019))
		filter.rotation.y=side*.3
		_disc(filter,"Canister",Vector3.ZERO,.047,.039,materials.metal)
		_disc(filter,"FilterGrille",Vector3(0,0,-.022),.037,.005,materials.black)
		_ring(filter,"BrassRim",Vector3(0,0,-.023),.041,.003,materials.brass)
		_ring(filter,"OuterRim",Vector3(0,0,-.015),.047,.003,materials.brass)
		for i in 6:
			_ring(filter,"MeshRing",Vector3(0,0,-.026),.009+i*.005,.00055,materials.metal)
		for i in 16:
			var a := TAU*i/16.0
			_tube(filter,"MeshSpoke",[Vector3(cos(a)*.006,sin(a)*.006,-.027),Vector3(cos(a)*.037,sin(a)*.037,-.027)],.0006,materials.metal)
	_disc(mask,"ExhaleValve",Vector3(0,-.061,-.033),.019,.012,materials.metal)
	_ring(mask,"ValveRim",Vector3(0,-.061,-.041),.017,.002,materials.brass)
	for side in [-1.0,1.0]:
		_ribbon(torso,"MaskStrap",[Vector3(side*.061,.477,-.194),Vector3(side*.087,.543,-.018),Vector3(side*.053,.552,.06)],.014,materials.black)

func _build_cape() -> void:
	cape=_pivot(torso,"TatteredCape",Vector3.ZERO)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const ROWS := 30
	const COLS := 72
	for row in ROWS+1:
		var t := row/float(ROWS)
		for col in COLS+1:
			var a := lerpf(-.19*PI,1.19*PI,col/float(COLS))
			var spread := smoothstep(0,.28,t)
			var width := lerpf(.102,.315,spread)+t*.022
			var depth := lerpf(.099,.202,spread)+t*.13
			var hem := -.33+.33*pow(absf(cos(a)),1.7)+.080*cos(a)+.010*sin(col*4.71)+.006*sin(col*1.27)
			var y := lerpf(.511,hem,t)
			var folds := sin(a*13+t*7)*.014*spread + sin(a*27-t*4)*.006
			var point := Vector3(cos(a)*(width+folds),y,sin(a)*(depth+folds)+.026)
			if sin(a)<0: point.z-=.018
			vertices.append(point)
			if row<ROWS and col<COLS:
				var k := row*(COLS+1)+col
				var torn := row>ROWS-2 and (col%23==0 or col==51)
				if not torn: indices.append_array([k,k+1,k+COLS+2,k,k+COLS+2,k+COLS+1])
	_surface(cape,"RaggedMantle",vertices,indices,materials.cape,true)
	for i in range(1,COLS,5):
		var point := vertices[ROWS*(COLS+1)+i]
		_tube(cape,"FrayedHem",[point,point+Vector3(sin(i)*.007,-.019-(i%5)*.006,.008)],.0009,materials.edge)
	# Collapsed hood above the cape, with a visibly hollow opening.
	var hood_vertices := PackedVector3Array()
	var hood_indices := PackedInt32Array()
	for row in 9:
		var t := row/8.0
		for col in 49:
			var a := lerpf(-.08,PI+.08,col/48.0)
			hood_vertices.append(Vector3(cos(a)*lerpf(.103,.143,t),.540-.09*t+sin(a)*.017,.036+sin(a)*lerpf(.100,.132,t)))
			if row<8 and col<48:
				var k := row*49+col
				hood_indices.append_array([k,k+1,k+50,k,k+50,k+49])
	_surface(cape,"FoldedHood",hood_vertices,hood_indices,materials.scarf,true)
	var hood_pts: Array = []
	for i in 33:
		var a := lerpf(-.08,PI+.08,i/32.0)
		hood_pts.append(Vector3(cos(a)*.103,.540+sin(a)*.017,.036+sin(a)*.100))
	_tube(cape,"HoodRim",hood_pts,.005,materials.scarf)
	_tube(cape,"HoodSeam",hood_pts,.0008,materials.edge)

func animate(delta: float, horizontal_speed: float, grounded: bool, vertical_speed: float = 0.0) -> void:
	super.animate(delta,horizontal_speed,grounded,vertical_speed)
	animate_face(delta,horizontal_speed)
	cape.rotation.x=sin(phase+.4)*gait*.009+run_blend*.035+landing*.025
	cape.rotation.z=lerpf(cape.rotation.z,-turn_blend*gait*.065,1.0-exp(-delta*5.0))
	materials.cape.set_shader_parameter("cloth_clock",breath)
	materials.cape.set_shader_parameter("cloth_movement",gait*(.35+run_blend*.65))
	materials.cape.set_shader_parameter("cloth_turn",turn_blend)
	for finger in _finger_joints:
		var index: int=finger.get_meta("finger_index")
		finger.rotation.x=.11+run_blend*.14+sin(breath*.6+index*.5)*.016
		finger.get_node("DistalJoint").rotation.x=.26+run_blend*.21+airborne_blend*.08

func _cloth_form(parent: Node3D, label: String, pos: Vector3, rings: Array, mat: Material, wrinkles: float) -> MeshInstance3D:
	var detailed: Array = []
	for i in rings.size()-1:
		var before: Vector4=rings[maxi(0,i-1)]
		var current: Vector4=rings[i]
		var next: Vector4=rings[i+1]
		var after: Vector4=rings[mini(rings.size()-1,i+2)]
		for j in 6:
			var t := j/6.0
			var pr: Vector4=.5*((2*current)+(-before+next)*t+(2*before-5*current+4*next-after)*t*t+(-before+3*current-3*next+after)*t*t*t)
			pr.x=lerpf(current.x,next.x,t)
			pr.y=maxf(.001,pr.y)
			pr.z=maxf(.001,pr.z)
			detailed.append(pr)
	detailed.append(rings[-1])
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const SIDES := 48
	var min_y: float=rings[0].x
	var span: float=maxf(.001,rings[-1].x-min_y)
	for row in detailed.size():
		var profile: Vector4=detailed[row]
		var t := (profile.x-min_y)/span
		for col in SIDES+1:
			var a := TAU*col/SIDES
			# Gravity folds travel from shoulders and compressed cuffs, with the
			# broad garment panels left calm instead of uniformly corrugated.
			var cuff := exp(-pow((t-.12)/.18,2))+.45*exp(-pow((t-.87)/.15,2))
			var side_tension := pow(absf(cos(a)),4)
			var fold := wrinkles*(sin(t*30.0+sin(a)*2.8)*cuff*.52+sin(a*8.0+t*4.0)*.19+sin(t*19.0-a*3.0)*side_tension*.24)
			var seam := exp(-pow(sin(a)/.11,2))*.00065
			var x := cos(a)*(profile.y+fold+seam)
			var z := sin(a)*(profile.z+fold*.72)+profile.w
			vertices.append(Vector3(x,profile.x,z))
			if row<detailed.size()-1 and col<SIDES:
				var k := row*(SIDES+1)+col
				indices.append_array([k,k+1,k+SIDES+2,k,k+SIDES+2,k+SIDES+1])
	for end in [0,detailed.size()-1]:
		var ring: Vector4=detailed[end]
		var center := vertices.size()
		vertices.append(Vector3(0,ring.x,ring.w))
		for col in SIDES:
			var k: int=end*(SIDES+1)+col
			if end==0: indices.append_array([center,k+1,k])
			else: indices.append_array([center,k,k+1])
	var result := _surface(parent,label,vertices,indices,mat)
	result.position=pos
	return result

func _rounded_box(parent: Node3D,label: String,pos: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	if "Pack" in label or "Pouch" in label or "Pocket" in label or "Satchel" in label or label=="ToolRoll":
		var geometry := REMODEL.sewn_bag(size)
		var node := _surface(parent,label,geometry.vertices,geometry.indices,mat)
		node.position=pos
		return node
	return super._rounded_box(parent,label,pos,size,mat)

func _tuft(parent: Node3D, label: String, points: Array, width: float, mat: Material) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in points.size():
		var direction: Vector3=(points[mini(row+1,points.size()-1)]-points[maxi(row-1,0)]).normalized()
		var n := direction.cross(Vector3.FORWARD).normalized()
		var b := n.cross(direction).normalized()
		var radius := width*pow(1.0-row/float(points.size()),1.5)
		if row==points.size()-1: radius=.0002
		for col in 9:
			var a := TAU*col/8
			vertices.append(points[row]+n*cos(a)*radius+b*sin(a)*radius*.65)
			if row<points.size()-1 and col<8:
				var k := row*9+col
				indices.append_array([k,k+1,k+10,k,k+10,k+9])
	_surface(parent,label,vertices,indices,mat)

func _ribbon(parent: Node3D, label: String, points: Array, width: float, mat: Material) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in points.size():
		var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var side := tangent.cross(Vector3.FORWARD).normalized()*width*.5
		vertices.append(points[i]-side)
		vertices.append(points[i]+side)
		if i<points.size()-1: indices.append_array([i*2,i*2+1,i*2+3,i*2,i*2+3,i*2+2])
	_surface(parent,label,vertices,indices,mat,true)

func _disc(parent: Node3D, label: String, pos: Vector3, radius: float, depth: float, mat: Material) -> void:
	var node := _loft(parent,label,pos,[Vector4(-depth*.5,radius*.94,radius*.94,0),Vector4(-depth*.38,radius,radius,0),Vector4(depth*.38,radius,radius,0),Vector4(depth*.5,radius*.94,radius*.94,0)],mat,48)
	node.rotation.x=PI*.5

func _ring(parent: Node3D, label: String, pos: Vector3, radius: float, thickness: float, mat: Material) -> void:
	var points: Array = []
	for i in 49:
		var a := TAU*i/48
		points.append(pos+Vector3(cos(a)*radius,sin(a)*radius,0))
	_tube(parent,label,points,thickness,mat)

func _surface(parent: Node3D, label: String, vertices: PackedVector3Array, indices: PackedInt32Array, mat: Material, double_sided := false) -> MeshInstance3D:
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
	# Smooth duplicated ring seams before creating backfaces; a visible seam
	# should come from cloth stitching, not discontinuous shading normals.
	var joined: Dictionary = {}
	for i in vertices.size():
		var key := vertices[i].snapped(Vector3(.000001,.000001,.000001))
		joined[key]=joined.get(key,Vector3.ZERO)+normals[i]
	for i in vertices.size():
		var key := vertices[i].snapped(Vector3(.000001,.000001,.000001))
		normals[i]=joined[key].normalized()
	if double_sided:
		var count := vertices.size()
		vertices.append_array(vertices)
		var back := PackedVector3Array()
		for n in normals: back.append(-n)
		normals.append_array(back)
		var back_indices := PackedInt32Array()
		for i in range(0,indices.size(),3): back_indices.append_array([count+indices[i],count+indices[i+2],count+indices[i+1]])
		indices.append_array(back_indices)
	return _mesh(parent,label,vertices,normals,indices,mat)

func _mesh(parent: Node3D,label: String,vertices: PackedVector3Array,normals: PackedVector3Array,indices: PackedInt32Array,mat: Material) -> MeshInstance3D:
	var node := super._mesh(parent,label,vertices,normals,indices,mat)
	node.set_meta("part_name",label)
	return node

func _ellipsoid(parent: Node3D,label: String,pos: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	if label in ["WornKneeArmor","RustShoulderShell","SteelShoulderPlate"]:
		var geometry := REMODEL.formed_armor(size)
		var plate := _surface(parent,label,geometry.vertices,geometry.indices,mat)
		plate.position=pos
		return plate
	var node := super._ellipsoid(parent,label,pos,size,mat)
	node.set_meta("part_name",label)
	var mesh := node.mesh as SphereMesh
	var extent := maxf(size.x,maxf(size.y,size.z))
	mesh.radial_segments=16 if extent<.028 else 24
	mesh.rings=8 if extent<.028 else 12
	return node
