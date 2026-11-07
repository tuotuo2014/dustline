extends Node3D
## Articulated mutant wolf. Faces -Z; paws rest on y = 0.
## Visuals only: the owning CharacterBody3D handles movement and damage.

const SURFACE = preload("res://mutant_surface.gdshader")
const BODY_PROFILE := [
	Vector4(-1.09,.17,.24,1.48), Vector4(-.89,.33,.44,1.40),
	Vector4(-.65,.405,.52,1.35), Vector4(-.34,.40,.49,1.32),
	Vector4(.01,.33,.37,1.29), Vector4(.37,.26,.25,1.29),
	Vector4(.69,.32,.33,1.30), Vector4(.96,.30,.31,1.29),
	Vector4(1.17,.21,.245,1.26), Vector4(1.31,.012,.035,1.29)]
const SKULL_PROFILE := [
	Vector4(-.82,.081,.052,-.012), Vector4(-.73,.132,.080,.006),
	Vector4(-.57,.164,.109,.025), Vector4(-.38,.198,.145,.065),
	Vector4(-.23,.263,.193,.085), Vector4(-.03,.259,.231,.069),
	Vector4(.14,.207,.196,.044), Vector4(.23,.01,.025,.012)]

var torso: Node3D
var head: Node3D
var jaw: Node3D
var tail: Node3D
var ears: Array[Node3D] = []
var legs: Array[Dictionary] = []
var materials: Dictionary = {}
var phase := 0.0
var breath := 0.0
var gait := 0.0
var attack_blend := 0.0
var alert := false
var rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}

func _ready() -> void:
	rng.seed=764019
	_make_materials()
	torso=_node(self,"LivingTorso",Vector3.ZERO)
	_build_body()
	_build_head()
	_build_tail()
	for side in [-1.0,1.0]:
		_build_leg(side,false)
		_build_leg(side,true)
	_flush_all()
	animate(0.0,0.0)

func set_alert(value: bool) -> void:
	alert=value

func animate(delta: float, speed: float, attacking: bool=false) -> void:
	if torso==null: return
	breath+=delta
	gait=move_toward(gait,clampf(speed/.8,0.0,1.0),delta*5.0)
	attack_blend=move_toward(attack_blend,1.0 if attacking else 0.0,delta*6.0)
	var running := clampf((speed-2.0)/3.6,0.0,1.0)
	var stride := lerpf(.80,1.32,running)
	phase+=delta*maxf(speed,.0)/stride*TAU
	var bob := sin(phase*2.0)*.024*gait+sin(breath*2.3)*.007
	torso.position.y=bob-.045*running*gait
	torso.rotation.z=sin(phase)*.013*gait
	torso.rotation.x=sin(phase*2.0)*.016*gait
	head.rotation.x=-.06*running*gait-.055*attack_blend+sin(breath*2.3)*.009
	head.rotation.y=sin(breath*.72)*.034*(1.0-gait)*(0.3 if alert else 1.0)
	jaw.rotation.x=lerpf(.14,-.19,attack_blend)-sin(breath*3.2)*.009-attack_blend*.018*sin(breath*15.0)
	tail.rotation.x=-.10+running*.15+sin(phase)*.04*gait
	tail.rotation.y=sin(breath*1.7)*.13+sin(phase)*.075*gait
	for i in ears.size():
		ears[i].rotation.z=(.10 if i==0 else -.10)*(attack_blend*.9+sin(breath*1.1+i)*.12)
	for i in legs.size():
		var leg: Dictionary=legs[i]
		var offset: float=0.0 if i==0 or i==3 else .5
		var cycle := fposmod(phase/TAU+offset,1.0)
		var reach: float
		var lift := 0.0
		if cycle<.62:
			reach=lerpf(-stride*.5,stride*.5,cycle/.62)
		else:
			var swing := (cycle-.62)/.38
			reach=lerpf(stride*.5,-stride*.5,swing)
			lift=sin(swing*PI)*lerpf(.18,.31,running)
		var foot: Vector3=leg.rest_foot
		foot.z+=reach*gait
		foot.y+=lift*gait
		# The shoulder/hip sockets move with the breathing and rolling torso.
		# Following only its Y offset used to pull the limbs out of their sockets.
		var hip: Vector3=torso.transform*leg.hip
		var ankle := foot+Vector3(0,.31,.22) if leg.hind else foot
		var knee := _joint(hip,ankle,leg.upper_length,leg.lower_length,-1.0 if leg.hind else 1.0)
		_align(leg.upper,hip,knee)
		_align(leg.lower,knee,ankle)
		if leg.hind: _align(leg.hock,ankle,foot)
		leg.socket.position=hip
		leg.paw.position=foot
		leg.paw.rotation.x=-lift*.55*gait

func _make_materials() -> void:
	materials.hide=_material("454647",.94,0,.30)
	materials.coat=_material("393a3b",.97,7,.24)
	materials.coat_light=_material("777877",.96,7,.20)
	materials.coat_face=_material("737575",.95,8,.22)
	materials.coat_limb=_material("545555",.97,7,.22)
	for coat_key in ["coat","coat_light","coat_face","coat_limb"]:
		materials[coat_key].set_shader_parameter("coat_length",.014 if coat_key=="coat_face" else (.027 if coat_key=="coat_limb" else .050))
	materials.dark_hide=_material("34383b",.96,0,.7)
	materials.fur=_material("848584",.96,1,.34)
	materials.mane=_material("323435",.97,1,.38)
	materials.face=_material("697174",.95,5,.28)
	materials.muzzle=_material("8e9695",.95,0,.37)
	materials.scar=_material("674236",.76,4,.58)
	materials.bone=_material("99836a",.70,2,.28)
	materials.tooth=_material("beb195",.45,2,.19)
	materials.claw=_material("302f27",.38,2,.37)
	materials.nose=_material("262821",.52,3,.23)
	materials.mouth=_material("261b18",.58,4,.22)
	materials.gum=_material("4a3530",.62,4,.20)
	materials.lip=_material("36352b",.73,0,.24)
	materials.paw_pad=_material("39372e",.89,0,.26)
	materials.tongue=_material("7b5041",.61,4,.25)
	materials.eye=_material("907338",.27,6,.12,.008)
	materials.pupil=_material("080b09",.21,3,0)
	materials.glint=_material("ecdaa0",.15,3,0,.25)

func _material(hex: String, rough: float, kind: float, variance: float, glow := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=SURFACE
	mat.set_shader_parameter("base_color",Color(hex))
	mat.set_shader_parameter("roughness_value",rough)
	mat.set_shader_parameter("surface_kind",kind)
	mat.set_shader_parameter("variation",variance)
	mat.set_shader_parameter("glow",glow)
	return mat

func _build_body() -> void:
	_long_form(torso,BODY_PROFILE,"coat",64,5,.012)
	# Scapulae and the powerful rising neck blend into the continuous rib cage.
	_taper(torso,[Vector3(0,1.35,-.77),Vector3(0,1.59,-1.03),Vector3(0,1.78,-1.34)],
		[Vector2(.37,.38),Vector2(.32,.35),Vector2(.255,.27)],"coat",28,7)
	for side in [-1.0,1.0]:
		_organic(torso,Vector3(side*.34,1.49,-.62),Vector3(.18,.39,.31),"coat",Vector3(.08,side*.2,side*.13))
		# Irregular bare flank, with a shadowed recess and the curved remains of ribs.
		_scar_patch(torso,side)
		for rib in 3:
			var z := -.26+rib*.072
			var r := lerpf(.37,.31,rib/2.0)
			_taper(torso,[Vector3(side*(r-.007),1.34,z-.012),Vector3(side*(r+.025),1.24,z),Vector3(side*(r+.016),1.14,z+.030),Vector3(side*(r-.025),1.10,z+.049)],
				[Vector2(.022,.019),Vector2(.028,.022),Vector2(.026,.020),Vector2(.016,.012)],"bone",8,4)
		# Cracked patches are long, irregular ridges following the anatomy.
		for mark in 7:
			var z := rng.randf_range(-.70,.93)
			var y := rng.randf_range(1.36,1.55)
			var profile := _profile(BODY_PROFILE,z)
			var x: float=side*profile.y*.85
			_taper(torso,[Vector3(x,y,z),Vector3(x+side*.013,y-.045,z+.04),Vector3(x+side*.005,y-.080,z+.10)],
				[Vector2(.014,.012),Vector2(.023,.014),Vector2(.003,.004)],"scar",6,3)
	# Individual tapered tufts follow the spine and gravity; no transparent cards.
	for strand in 2900:
		var z := rng.randf_range(-1.0,1.22)
		var a := rng.randf_range(0,TAU)
		var p := _profile(BODY_PROFILE,z)
		var root := Vector3(cos(a)*p.y,p.w+sin(a)*p.z,z)
		var normal := Vector3(cos(a),sin(a),0).normalized()
		var flank := absf(cos(a))>.78 and z>-.29 and z<-.02 and root.y<1.34 and root.y>1.10
		if flank: continue
		var length := rng.randf_range(.042,.125)
		var direction := (normal*.36+Vector3(0,-.25,.85)).normalized()
		if sin(a)>.60 and z<.3:
			length*=2.0
			direction=(normal*.32+Vector3(0,.13,.93)).normalized()
		_fur(torso,root,normal,direction,length,rng.randf_range(.0025,.007),"mane" if sin(a)>.50 else "fur")
	# Lay the coarse shoulder coat over the scapula; its fibers overlap the mobile upper arm.
	for side in [-1.0,1.0]:
		for strand in 640:
			var a := rng.randf_range(0,TAU)
			var p := rng.randf_range(.16,PI-.16)
			var normal := Vector3(side*absf(sin(p)*cos(a)),cos(p),sin(p)*sin(a)).normalized()
			var root := Vector3(side*.34,1.49,-.62)+normal*Vector3(.185,.395,.315)
			_fur(torso,root,normal,(normal*.20+Vector3(0,-.58,.51)).normalized(),rng.randf_range(.072,.17),rng.randf_range(.0025,.005),"mane" if normal.y>.1 else "fur")
	# Thick mane projects up and back around the shoulders and throat.
	for strand in 2350:
		var u := rng.randf()
		var a := rng.randf_range(0,TAU)
		var center := Vector3(0,lerpf(1.40,1.81,u),lerpf(-.85,-1.38,u))
		var radius := lerpf(.37,.26,u)
		var normal := Vector3(cos(a),sin(a)*.76,sin(a)*.35).normalized()
		var root := center+normal*radius
		var direction := (normal*.28+Vector3(0,-.39,.82)).normalized()
		_fur(torso,root,normal,direction,rng.randf_range(.10,.255),rng.randf_range(.0028,.0047),"mane" if sin(a)>.12 else "fur")

func _build_head() -> void:
	head=_node(torso,"SnarlingHead",Vector3(0,1.76,-1.39))
	_long_form(head,SKULL_PROFILE,"coat_face",64,5,.008)
	# The muzzle is part of the skull; the lighter whisker pads sit shallowly on it.
	for side in [-1.0,1.0]:
		_organic(head,Vector3(side*.074,-.007,-.565),Vector3(.082,.069,.175),"coat_face",Vector3(0,side*-.08,0))
		_taper(head,[Vector3(side*.21,.047,-.27),Vector3(side*.185,.059,-.42),Vector3(side*.137,.035,-.60)],
			[Vector2(.012,.012),Vector2(.014,.010),Vector2(.003,.003)],"face",10,6)
		var eye_node := _node(head,"LeftGoldenEye" if side<0 else "RightGoldenEye",Vector3(side*.224,.105,-.295))
		eye_node.rotation.y=-side*.62
		_organic(eye_node,Vector3.ZERO,Vector3(.055,.031,.023),"mouth")
		_organic(eye_node,Vector3(0,.001,-.011),Vector3(.039,.020,.015),"eye")
		_taper(eye_node,[Vector3(-.054,.002,-.013),Vector3(-.026,.022,-.023),Vector3(.022,.020,-.021),Vector3(.052,-.002,-.009)],
			[Vector2(.007,.007),Vector2(.013,.010),Vector2(.012,.011),Vector2(.007,.007)],"dark_hide",10,5)
		_taper(eye_node,[Vector3(-.051,-.007,-.012),Vector3(-.014,-.022,-.018),Vector3(.028,-.018,-.015),Vector3(.052,-.003,-.008)],
			[Vector2(.005,.005),Vector2(.006,.006),Vector2(.007,.006),Vector2(.005,.004)],"lip",10,5)
		# Heavy brow slopes inward, keeping the golden eye inside a real socket.
		_taper(head,[Vector3(side*.143,.134,-.359),Vector3(side*.228,.150,-.281),Vector3(side*.262,.113,-.17)],
			[Vector2(.016,.018),Vector2(.036,.025),Vector2(.022,.018)],"face",16,6)
		_build_ear(side)
		_build_cheek_ruff(side)
		for whisker in 10:
			var z := rng.randf_range(-.67,-.43)
			var y := rng.randf_range(-.05,.029)
			_taper(head,[Vector3(side*.147,y,z),Vector3(side*.23,y+.014,z+.008),Vector3(side*.32,y+.035,z+.031)],
				[Vector2(.0007,.0007),Vector2(.0004,.0004),Vector2(.00006,.00006)],"muzzle",3,3)
		_taper(head,[Vector3(side*.16,-.070,-.61),Vector3(side*.198,-.073,-.41),Vector3(side*.230,-.11,-.20)],
			[Vector2(.019,.017),Vector2(.021,.017),Vector2(.014,.013)],"lip",12,6)
		# Canines arc inward; premolars vary in length and wear.
		_tooth(head,Vector3(side*.150,-.074,-.612),Vector3(side*.145,-.182,-.620),Vector3(side*.117,-.250,-.646),.031)
		for tooth in 6:
			var z := -.22-tooth*.056
			var x: float=side*lerpf(.196,.149,tooth/5.0)
			var length := .039+sin(tooth*1.7)*.013
			_tooth(head,Vector3(x,-.091,z),Vector3(x*.97,-.116,z-.006),Vector3(x*.93,-.091-length,z-.021),.017)
	for incisor in 6:
		var x := (incisor-2.5)*.032
		_tooth(head,Vector3(x,-.069,-.705),Vector3(x,-.100,-.718),Vector3(x*.97,-.119,-.725),.015)
	_organic(head,Vector3(0,-.08,-.42),Vector3(.148,.062,.285),"mouth")
	_build_nose()
	jaw=_node(head,"HingedJaw",Vector3(0,-.119,-.108))
	_long_form(jaw,[Vector4(-.625,.058,.029,-.211),Vector4(-.575,.107,.039,-.218),Vector4(-.41,.129,.049,-.185),
		Vector4(-.22,.144,.075,-.130),Vector4(-.04,.161,.105,-.055),Vector4(.047,.086,.079,-.005)],"dark_hide",48,5,.003)
	_organic(jaw,Vector3(0,-.163,-.326),Vector3(.111,.023,.211),"tongue",Vector3(.20,0,0))
	_taper(jaw,[Vector3(0,-.135,-.14),Vector3(0,-.165,-.31),Vector3(0,-.205,-.50)],
		[Vector2(.004,.003),Vector2(.003,.002),Vector2(.001,.001)],"scar",6,3)
	for side in [-1.0,1.0]:
		_taper(jaw,[Vector3(side*.132,-.066,-.12),Vector3(side*.124,-.131,-.32),Vector3(side*.093,-.185,-.55)],
			[Vector2(.019,.017),Vector2(.017,.016),Vector2(.012,.012)],"gum",8,5)
		_tooth(jaw,Vector3(side*.090,-.18,-.541),Vector3(side*.086,-.094,-.540),Vector3(side*.069,-.057,-.568),.026)
		for tooth in 6:
			var t := tooth/5.0
			var root := Vector3(side*lerpf(.137,.1,t),lerpf(-.054,-.174,t),lerpf(-.12,-.46,t))
			_tooth(jaw,root,root+Vector3(0,.027,-.004),root+Vector3(-side*.01,.061,-.011),.014)
	for incisor in 6:
		var x := (incisor-2.5)*.027
		var root := Vector3(x,-.19,-.58)
		_tooth(jaw,root,root+Vector3(0,.028,-.004),root+Vector3(0,.047,-.009),.012)
	for strand in 1350:
		var z := rng.randf_range(-.34,.16)
		var a := rng.randf_range(0,TAU)
		var p := _profile(SKULL_PROFILE,z)
		var root := Vector3(cos(a)*p.y,p.w+sin(a)*p.z,z)
		var normal := Vector3(cos(a),sin(a),0)
		if absf(cos(a))>.65 and root.y>.045 and root.y<.17 and z<-.20: continue
		_fur(head,root,normal,(normal*.25+Vector3(0,-.15,.91)).normalized(),rng.randf_range(.020,.081),rng.randf_range(.002,.005),"mane")
	for strand in 220:
		var x := rng.randf_range(-.13,.13)
		var z := rng.randf_range(-.51,-.12)
		_fur(jaw,Vector3(x,lerpf(-.26,-.13,inverse_lerp(-.51,-.12,z)),z),Vector3(x*3,-1,.1).normalized(),Vector3(x*.8,-.7,.5).normalized(),rng.randf_range(.035,.13),.0035,"fur")

func _build_nose() -> void:
	# A compact canine nose with a broad, flattened front and recessed nostril folds.
	_long_form(head,[Vector4(-.834,.035,.018,.006),Vector4(-.824,.077,.034,.009),
		Vector4(-.799,.096,.041,.014),Vector4(-.773,.090,.038,.019),Vector4(-.752,.057,.026,.014)],"nose",48,5,.006)
	for side in [-1.0,1.0]:
		_organic(head,Vector3(side*.061,.003,-.820),Vector3(.019,.010,.005),"pupil",Vector3(0,side*.32,side*.27))
		_taper(head,[Vector3(side*.041,.003,-.831),Vector3(side*.053,.013,-.829),Vector3(side*.074,.011,-.819),Vector3(side*.082,-.001,-.807)],
			[Vector2(.003,.003),Vector2(.004,.004),Vector2(.004,.003),Vector2(.002,.002)],"nose",8,4)
	_taper(head,[Vector3(0,.011,-.840),Vector3(0,-.012,-.831),Vector3(0,-.033,-.802),Vector3(0,-.067,-.778)],
		[Vector2(.002,.002),Vector2(.002,.002),Vector2(.003,.003),Vector2(.002,.002)],"mouth",6,4)
	for strand in 680:
		var z := rng.randf_range(-.733,-.28)
		var a := rng.randf_range(-.18,PI+.18)
		var p := _profile(SKULL_PROFILE,z)
		var normal := Vector3(cos(a),sin(a),0)
		var root := Vector3(normal.x*p.y,p.w+normal.y*p.z,z)
		if root.y>.080 and z>-.34 and absf(normal.x)>.72: continue
		_fur(head,root,normal,(normal*.11+Vector3(0,.03,.95)).normalized(),rng.randf_range(.012,.037),.0019,"fur")

func _build_cheek_ruff(side: float) -> void:
	# The cheek ruff widens the wedge-shaped skull and joins it to the neck coat.
	_taper(head,[Vector3(side*.201,.038,-.17),Vector3(side*.242,.012,-.008),Vector3(side*.279,-.042,.118),Vector3(side*.289,-.087,.219)],
		[Vector2(.051,.078),Vector2(.085,.117),Vector2(.076,.105),Vector2(.006,.012)],"coat_light",16,5)
	for strand in 500:
		var t := rng.randf()
		var angle := rng.randf_range(-1.45,1.48)
		var radius := .070+sin(t*PI)*.019
		var root := Vector3(side*(.204+t*.072+cos(angle)*radius),.024-t*.080+sin(angle)*.105,-.13+t*.29)
		var normal := Vector3(side*cos(angle),sin(angle),.12).normalized()
		var direction := Vector3(side*.18,-.21,.85).normalized()
		_fur(head,root,normal,direction,rng.randf_range(.075,.174),rng.randf_range(.002,.0047),"mane" if strand%4 else "fur")
	# A few healed creases travel with the cheek instead of floating across the eye.
	for mark in 2:
		_taper(head,[Vector3(side*.244,.016-mark*.020,-.255),Vector3(side*.263,-.01-mark*.015,-.17),Vector3(side*.251,-.043-mark*.009,-.092)],
			[Vector2(.001,.001),Vector2(.003,.002),Vector2(.0007,.001)],"dark_hide",6,4)

func _build_ear(side: float) -> void:
	var ear := _node(head,"LeftEar" if side<0 else "RightEar",Vector3(side*.195,.208,.046))
	ear.scale=Vector3(1.0,.90,1.0)
	ears.append(ear)
	var tip := .291 if side<0 else .308
	_taper(ear,[Vector3.ZERO,Vector3(side*.021,.079,.007),Vector3(side*.046,.182,.0),Vector3(side*.064,tip,-.026)],
		[Vector2(.091,.060),Vector2(.091,.044),Vector2(.049,.024),Vector2(.001,.002)],"coat_face",20,7)
	_taper(ear,[Vector3(side*.006,.036,-.043),Vector3(side*.024,.090,-.038),Vector3(side*.044,.174,-.024),Vector3(side*.060,tip-.027,-.026)],
		[Vector2(.039,.007),Vector2(.055,.007),Vector2(.028,.006),Vector2(.001,.001)],"dark_hide",16,6)
	for strand in 190:
		var t := rng.randf()
		var sign_side := -1.0 if rng.randf()<.5 else 1.0
		var root := Vector3(side*lerpf(.007,.062,t)+sign_side*lerpf(.090,.005,t),lerpf(.012,tip-.008,t),-.018)
		_fur(ear,root,Vector3(sign_side,.13,-.2).normalized(),Vector3(sign_side*.16,.75,.10).normalized(),rng.randf_range(.017,.052),.0025,"fur")
	for strand in 130:
		var t := rng.randf_range(.08,.68)
		var root := Vector3(side*.05*t+rng.randf_range(-.04,.04)*(1-t),t*tip,-.047+t*.020)
		_fur(ear,root,Vector3(0,0,-1),Vector3(side*.08,.85,-.10).normalized(),rng.randf_range(.021,.057),.0022,"fur")

func _build_tail() -> void:
	tail=_node(torso,"LivingTail",Vector3(0,1.34,1.15))
	var path := [Vector3.ZERO,Vector3(0,-.10,.22),Vector3(.03,-.32,.50),Vector3(.08,-.57,.77),Vector3(.10,-.74,1.02),Vector3(.08,-.79,1.18)]
	_taper(tail,path,[Vector2(.115,.13),Vector2(.168,.18),Vector2(.184,.19),Vector2(.148,.16),Vector2(.09,.093),Vector2(.008,.010)],"coat",24,6)
	for strand in 750:
		var t := rng.randf()
		var center := _curve(path,t)
		var a := rng.randf_range(0,TAU)
		var normal := Vector3(cos(a),sin(a),.25).normalized()
		var root := center+normal*lerpf(.164,.022,t)
		_fur(tail,root,normal,(normal*.4+Vector3(0,-.30,.8)).normalized(),rng.randf_range(.10,.23)*(1.0-t*.35),.005,"mane" if strand%3==0 else "fur")

func _build_leg(side: float, hind: bool) -> void:
	var hip := Vector3(side*(.30 if hind else .355),1.29 if hind else 1.51,.93 if hind else -.69)
	# A rounded, closed socket bridges the body and the mobile limb in every pose.
	var socket := _node(self,"HindHipSocket" if hind else "ForeShoulderSocket",hip)
	_organic(socket,Vector3.ZERO,Vector3(.235,.265,.25) if hind else Vector3(.235,.28,.255),"coat_limb")
	var upper := _node(self,"HindThigh" if hind else "ForeShoulder",hip)
	var lower := _node(self,"HindShin" if hind else "Forearm",hip)
	var hock := _node(self,"Hock",Vector3.ZERO) if hind else null
	var paw := _node(self,"HindPaw" if hind else "ForePaw",Vector3.ZERO)
	var upper_length := .67 if hind else .74
	var lower_length := .60 if hind else .77
	upper.set_meta("rest_length",upper_length)
	lower.set_meta("rest_length",lower_length)
	var rest := Vector3(side*(.32 if hind else .38),.105,1.05 if hind else -.83)
	var upper_r := .22 if hind else .205
	_taper(upper,[Vector3(0,.04,0),Vector3(0,-upper_length*.22,-.012),Vector3(0,-upper_length*.56,.012),Vector3(0,-upper_length,0)],
		[Vector2(upper_r*.70,upper_r*.85),Vector2(upper_r,upper_r*1.11),Vector2(upper_r*.72,upper_r*.83),Vector2(.091,.11)],"coat_limb",24,5)
	_organic(upper,Vector3(0,-upper_length,0),Vector3(.112,.125,.125),"coat_limb")
	_organic(lower,Vector3(0,-.015,0),Vector3(.116,.165,.12),"coat_limb")
	_taper(lower,[Vector3.ZERO,Vector3(0,-lower_length*.16,0),Vector3(0,-lower_length*.52,.010),Vector3(0,-lower_length,0)],
		[Vector2(.104,.108),Vector2(.122,.121),Vector2(.073,.089),Vector2(.056,.061)],"coat_limb",20,5)
	# Long forearm tendons and small scarred knuckles support the stretched silhouette.
	for tendon in [-1.0,1.0]:
		_taper(lower,[Vector3(tendon*.038,-lower_length*.24,-.087),Vector3(tendon*.031,-lower_length*.59,-.071),Vector3(tendon*.024,-lower_length*.94,-.051)],
			[Vector2(.009,.011),Vector2(.008,.008),Vector2(.006,.006)],"dark_hide",8,4)
	_taper(lower,[Vector3(side*.071,-.10,-.064),Vector3(side*.055,-.23,-.08),Vector3(side*.039,-.42,-.053)],
		[Vector2(.014,.008),Vector2(.019,.012),Vector2(.003,.004)],"scar",6,4)
	if hind:
		var hock_length := sqrt(.31*.31+.22*.22)
		hock.set_meta("rest_length",hock_length)
		_taper(hock,[Vector3.ZERO,Vector3(0,-.10,0),Vector3(0,-hock_length,0)],
			[Vector2(.072,.073),Vector2(.052,.054),Vector2(.044,.048)],"coat_limb",16,6)
		_organic(hock,Vector3.ZERO,Vector3(.088,.105,.09),"coat_limb")
	# The wrist/ankle remains filled as the foot pitches during the swing phase.
	_organic(paw,Vector3(0,.012,0),Vector3(.072,.09,.082) if hind else Vector3(.087,.105,.097),"coat_limb")
	_organic(paw,Vector3(0,-.015,-.064),Vector3(.125 if hind else .158,.090,.189 if hind else .204),"coat_limb",Vector3(.10,0,0))
	for toe in 4:
		var x := (toe-1.5)*(.063 if hind else .077)
		var z := -.16+(absf(toe-1.5)-.5)*.026
		_organic(paw,Vector3(x,-.023,z),Vector3(.041,.062,.09),"coat_limb",Vector3(0,-x*.9,0))
		_taper(paw,[Vector3(x,-.012,z-.066),Vector3(x*1.08,-.020,z-.117),Vector3(x*1.10,-.063,z-.17),Vector3(x*1.04,-.103,z-.168)],
			[Vector2(.026,.025),Vector2(.023,.02),Vector2(.012,.013),Vector2(.0007,.001)],"claw",10,5)
		_organic(paw,Vector3(x,.023,z-.03),Vector3(.029,.021,.038),"dark_hide")
		_organic(paw,Vector3(x,-.073,z+.005),Vector3(.033,.020,.063),"paw_pad")
		for crease in 2:
			_taper(paw,[Vector3(x-.023,.017,z+.005+crease*.018),Vector3(x,.031,z+.001+crease*.018),Vector3(x+.023,.017,z+.005+crease*.018)],
				[Vector2(.002,.002),Vector2(.003,.002),Vector2(.002,.002)],"dark_hide",5,2)
	_organic(paw,Vector3(0,-.061,-.039),Vector3(.09,.032,.092),"paw_pad")
	if not hind:
		_taper(lower,[Vector3(-side*.065,-lower_length*.74,.024),Vector3(-side*.085,-lower_length*.82,.040),Vector3(-side*.084,-lower_length*.89,.025)],
			[Vector2(.018,.018),Vector2(.013,.012),Vector2(.0005,.001)],"claw",9,4)
	for strand in 280:
		var t := rng.randf_range(.12,.88)
		var a := rng.randf_range(0,TAU)
		var normal := Vector3(cos(a),0,sin(a))
		var radius := lerpf(.113,.055,t)
		var root := Vector3(normal.x*radius,-lower_length*t,normal.z*radius)
		_fur(lower,root,normal,Vector3(normal.x*.18,-.90,.10).normalized(),rng.randf_range(.021,.065),.0024,"fur")
	for strand in 720:
		var t := rng.randf_range(.0,.84)
		var a := rng.randf_range(0,TAU)
		var normal := Vector3(cos(a),.0,sin(a))
		var radius := upper_r*lerpf(.98,.56,t)+.012*sin(t*PI)
		_fur(upper,Vector3(normal.x*radius,-upper_length*t,normal.z*radius),normal,(normal*.24+Vector3(0,-.94,.18)).normalized(),rng.randf_range(.05,.16),.0038,"fur")
	legs.append({"hip":hip,"rest_foot":rest,"socket":socket,"upper":upper,"lower":lower,"hock":hock,"paw":paw,"hind":hind,"upper_length":upper_length,"lower_length":lower_length})

func _joint(start: Vector3, end: Vector3, length_a: float, length_b: float, bend: float) -> Vector3:
	var delta := end-start
	var distance := clampf(delta.length(),.01,length_a+length_b-.005)
	var along := (length_a*length_a-length_b*length_b+distance*distance)/(2.0*distance)
	var height := sqrt(maxf(length_a*length_a-along*along,.0))
	var direction := delta.normalized()
	var perpendicular := Vector3(0,-direction.z,direction.y).normalized()*bend
	return start+direction*along-perpendicular*height

func _scar_patch(parent: Node3D, side: float) -> void:
	var data := _batch(parent,"scar")
	var offset: int=data.v.size()
	data.v.append(Vector3(side*.366,1.19,-.13))
	data.c.append(Color(.65,.65,.65,1))
	const COUNT := 32
	for point in COUNT+1:
		var a := TAU*point/COUNT
		var rough := 1.0+.13*sin(a*7.0)+.075*cos(a*11.0)
		var y := 1.19+sin(a)*.115*rough
		var z := -.13+cos(a)*.160*rough
		var p := _profile(BODY_PROFILE,z)
		var x := p.y*sqrt(maxf(.02,1.0-pow((y-p.w)/p.z,2.0)))+.008
		data.v.append(Vector3(side*x,y,z))
		data.c.append(Color(.91,.90,.84,1))
		if point<COUNT: data.i.append_array([offset,offset+point+1,offset+point+2])
	_set_batch(parent,"scar",data)

func _align(node: Node3D, start: Vector3, end: Vector3) -> void:
	node.position=start
	node.quaternion=Quaternion(Vector3.DOWN,(end-start).normalized())
	node.scale.y=(end-start).length()/float(node.get_meta("rest_length",1.0))

func _node(parent: Node3D, label: String, location: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name=label
	node.position=location
	parent.add_child(node)
	return node

func _profile(profile: Array, z: float) -> Vector4:
	for i in profile.size()-1:
		if z<=profile[i+1].x:
			var t := clampf(inverse_lerp(profile[i].x,profile[i+1].x,z),0,1)
			return profile[i].cubic_interpolate(profile[i+1],profile[maxi(0,i-1)],profile[mini(profile.size()-1,i+2)],t)
	return profile[-1]

func _long_form(parent: Node3D, profile: Array, mat: String, sides := 40, subdivisions := 4, ripple := .0) -> void:
	var data := _batch(parent,mat)
	var offset: int=data.v.size()
	var rows := (profile.size()-1)*subdivisions
	for row in rows+1:
		var z := lerpf(profile[0].x,profile[-1].x,row/float(rows))
		var p := _profile(profile,z)
		for j in sides+1:
			var a := j*TAU/sides
			var swell := 1.0+ripple*sin(a*5+z*9)+ripple*.5*sin(a*11-z*17)
			data.v.append(Vector3(cos(a)*p.y*swell,p.w+sin(a)*p.z*swell,z))
			data.c.append(Color.WHITE)
			if row<rows and j<sides:
				var k := offset+row*(sides+1)+j
				data.i.append_array([k,k+sides+2,k+1,k,k+sides+1,k+sides+2])
	_close_ring(data,offset,sides,false)
	_close_ring(data,offset+rows*(sides+1),sides,true)
	_set_batch(parent,mat,data)

func _close_ring(data: Dictionary, ring: int, sides: int, reverse: bool) -> void:
	# Closed caps prevent looking through an animated part when a joint turns.
	var center := Vector3.ZERO
	for index in sides: center+=data.v[ring+index]
	center/=sides
	var tip: int=data.v.size()
	data.v.append(center)
	data.c.append(Color.WHITE)
	for index in sides:
		if reverse: data.i.append_array([tip,ring+index+1,ring+index])
		else: data.i.append_array([tip,ring+index,ring+index+1])

func _organic(parent: Node3D, position: Vector3, radius: Vector3, mat: String, rotation_euler := Vector3.ZERO) -> void:
	var data := _batch(parent,mat)
	var offset: int=data.v.size()
	var basis := Basis.from_euler(rotation_euler)
	const ROWS := 12
	const SIDES := 24
	for row in ROWS+1:
		var p := PI*row/ROWS
		for col in SIDES+1:
			var a := TAU*col/SIDES
			var point := Vector3(sin(p)*cos(a),cos(p),sin(p)*sin(a))*radius
			point*=1.0+.023*sin(a*3.0+p*7.0)*sin(p)
			data.v.append(position+basis*point)
			data.c.append(Color.WHITE)
			if row<ROWS and col<SIDES:
				var k := offset+row*(SIDES+1)+col
				data.i.append_array([k,k+SIDES+2,k+1,k,k+SIDES+1,k+SIDES+2])
	_set_batch(parent,mat,data)

func _curve(points: Array, t: float) -> Vector3:
	var index := mini(int(t*(points.size()-1)),points.size()-2)
	var fraction := t*(points.size()-1)-index
	return points[index].cubic_interpolate(points[index+1],points[maxi(index-1,0)],points[mini(index+2,points.size()-1)],fraction)

func _taper(parent: Node3D, points: Array, radii: Array, mat: String, sides := 8, subdivisions := 3, tint := Color.WHITE) -> void:
	var data := _batch(parent,mat)
	var offset: int=data.v.size()
	var rows := (points.size()-1)*subdivisions
	var start_tangent := (points[1]-points[0]).normalized() as Vector3
	var frame_axis := Vector3.UP if absf(start_tangent.y)<.90 else Vector3.RIGHT
	var frame_normal := start_tangent.cross(frame_axis).normalized()
	for row in rows+1:
		var t := row/float(rows)
		var point := _curve(points,t)
		var tangent := (_curve(points,minf(1.0,t+.001))-_curve(points,maxf(0.0,t-.001))).normalized()
		var normal := (frame_normal-tangent*frame_normal.dot(tangent)).normalized()
		frame_normal=normal
		var binormal := normal.cross(tangent).normalized()
		var segment := mini(int(t*(radii.size()-1)),radii.size()-2)
		var radius: Vector2=radii[segment].lerp(radii[segment+1],t*(radii.size()-1)-segment)
		for side in sides+1:
			var a := side*TAU/sides
			data.v.append(point+normal*cos(a)*radius.x+binormal*sin(a)*radius.y)
			var shaded := tint
			if mat=="fur" or mat=="mane":
				shaded=Color(tint.r*lerpf(.78,1.10,t),tint.g*lerpf(.78,1.08,t),tint.b*lerpf(.77,1.04,t),1)
			elif mat=="tooth":
				shaded=Color(lerpf(.64,1.04,t),lerpf(.60,1.02,t),lerpf(.49,.95,t),1)
			data.c.append(shaded)
			if row<rows and side<sides:
				var k := offset+row*(sides+1)+side
				data.i.append_array([k,k+1,k+sides+2,k,k+sides+2,k+sides+1])
	_close_ring(data,offset,sides,true)
	_close_ring(data,offset+rows*(sides+1),sides,false)
	_set_batch(parent,mat,data)

func _tooth(parent: Node3D, root: Vector3, middle: Vector3, tip: Vector3, radius: float) -> void:
	_taper(parent,[root,middle,tip],[Vector2(radius,radius*.77),Vector2(radius*.63,radius*.49),Vector2(.0006,.0006)],"tooth",9,5)

func _fur(parent: Node3D, root: Vector3, normal: Vector3, direction: Vector3, length: float, radius: float, mat: String) -> void:
	# Two crossed curved ribbons retain dense fur while avoiding needle-like tubes.
	var shade := rng.randf_range(.76,1.13)
	var data := _batch(parent,mat)
	var direction_unit := direction.normalized()
	var tangent := normal.cross(direction_unit).normalized()
	if tangent.length_squared()<.1: tangent=normal.cross(Vector3.RIGHT).normalized()
	var positions: Array[Vector3]=[root-normal*.003,root+normal*length*.18+direction_unit*length*.30,root+normal*length*.08+direction_unit*length*.72,root+direction_unit*length]
	for plane in 2:
		var across := tangent if plane==0 else normal.cross(tangent).normalized()
		var offset: int=data.v.size()
		for row in 4:
			var width: float=[.64,.58,.25,.012][row]*radius
			for side in [-1.0,1.0]:
				data.v.append(positions[row]+across*width*side)
				var tip := lerpf(.78,1.06,float(row)/3)
				data.c.append(Color(shade*tip,shade*.982*tip,shade*.945*tip,1))
			if row<3:
				var k := offset+row*2
				data.i.append_array([k,k+1,k+3,k,k+3,k+2])
	_set_batch(parent,mat,data)

func _batch(parent: Node3D, mat: String) -> Dictionary:
	var id := parent.get_instance_id()
	if not _batches.has(id): _batches[id]={"parent":parent,"surfaces":{}}
	if not _batches[id].surfaces.has(mat):
		_batches[id].surfaces[mat]={"v":PackedVector3Array(),"i":PackedInt32Array(),"c":PackedColorArray()}
	return _batches[id].surfaces[mat]

func _set_batch(parent: Node3D, mat: String, data: Dictionary) -> void:
	_batches[parent.get_instance_id()].surfaces[mat]=data

func _flush_all() -> void:
	for batch in _batches.values():
		var mesh := ArrayMesh.new()
		var shadow_mesh := ArrayMesh.new()
		for key in batch.surfaces:
			var data: Dictionary=batch.surfaces[key]
			var normals := PackedVector3Array()
			normals.resize(data.v.size())
			for face in range(0,data.i.size(),3):
				var a: int=data.i[face]
				var b: int=data.i[face+1]
				var c: int=data.i[face+2]
				var n: Vector3=(data.v[c]-data.v[a]).cross(data.v[b]-data.v[a])
				normals[a]+=n
				normals[b]+=n
				normals[c]+=n
			# Weld only normal seams, preserving separate UV-free geometry batches.
			var welded: Dictionary={}
			for index in normals.size():
				var key_position: Vector3=data.v[index].snapped(Vector3(.00001,.00001,.00001))
				welded[key_position]=welded.get(key_position,Vector3.ZERO)+normals[index]
			for index in normals.size():
				var key_position: Vector3=data.v[index].snapped(Vector3(.00001,.00001,.00001))
				normals[index]=welded[key_position].normalized()
			var base_indices: PackedInt32Array=data.i.duplicate()
			var lods: Dictionary={}
			if String(key).begins_with("coat"):
				_add_undercoat_shells(data,normals,String(key))
				# Keep all six fur shells close up; thin subpixel layers in the distance.
				var middle := base_indices.duplicate()
				for shell in [2,4,6]:
					middle.append_array(data.i.slice(shell*base_indices.size(),(shell+1)*base_indices.size()))
				lods[.06]=middle
				lods[.18]=base_indices
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=data.v
			arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_INDEX]=data.i
			arrays[Mesh.ARRAY_COLOR]=data.c
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
			mesh.surface_set_material(mesh.get_surface_count()-1,materials[key])
			# Only the opaque silhouette casts a shadow, not thousands of hair strands.
			if key not in ["fur","mane"]:
				var shadow_arrays := []
				shadow_arrays.resize(Mesh.ARRAY_MAX)
				shadow_arrays[Mesh.ARRAY_VERTEX]=data.v
				shadow_arrays[Mesh.ARRAY_INDEX]=base_indices
				shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,shadow_arrays)
		mesh.shadow_mesh=shadow_mesh
		var instance := MeshInstance3D.new()
		instance.name="SculptedSurfaces"
		instance.mesh=mesh
		instance.visibility_range_end=150.0
		instance.visibility_range_end_margin=10.0
		batch.parent.add_child(instance)
	_batches.clear()

func _add_undercoat_shells(data: Dictionary, normals: PackedVector3Array, material_key: String) -> void:
	var source_v: PackedVector3Array=data.v.duplicate()
	var source_i: PackedInt32Array=data.i.duplicate()
	var source_n := normals.duplicate()
	var coat_length: float=materials[material_key].get_shader_parameter("coat_length")
	for index in data.c.size(): data.c[index]=Color(1,1,1,0)
	for shell in range(1,7):
		var layer := shell/6.0
		var offset: int=data.v.size()
		for index in source_v.size():
			data.v.append(source_v[index]+source_n[index]*coat_length*layer+Vector3(0,-.014,.012)*layer*layer)
			normals.append(source_n[index])
			data.c.append(Color(1,1,1,layer))
		for index in source_i: data.i.append(offset+index)
