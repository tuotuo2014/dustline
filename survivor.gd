extends Node3D
## A human-proportioned survivor, facing -Z with the boot soles at y = 0.
## Rest transforms stay separate from animation offsets to prevent detached anatomy.

const SURFACE = preload("res://survivor_surface.gdshader")
const TORSO_REST := Vector3(0.0, 1.0, 0.0)
const HIP_HEIGHT := 0.96
const THIGH_LENGTH := 0.40
const SHIN_LENGTH := 0.40
# Keep the reference walking poses at the requested brisker pace. Distances
# are metres per complete left/right cycle, not a fixed animation playback rate.
const WALK_SPEED := 1.8
const WALK_STRIDE := 1.46
const RUN_STRIDE := 4.40
const HEAD_PROFILE := [
	Vector4(0,.028,.034,-.019), Vector4(.012,.046,.047,-.008),
	Vector4(.035,.064,.058,0),Vector4(.060,.073,.068,.006),
	Vector4(.085,.083,.076,.006),Vector4(.115,.088,.081,.004),
	Vector4(.14,.087,.084,.005),Vector4(.168,.084,.086,.009),
	Vector4(.195,.083,.087,.012),Vector4(.22,.077,.079,.015),
	Vector4(.243,.061,.063,.019),Vector4(.258,.035,.037,.019),
	Vector4(.264,.002,.003,.019)]

var torso: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var ankles: Array[Node3D] = []
var arms: Array[Node3D] = []
var elbows: Array[Node3D] = []
var scarf_tail: Node3D
var phase := 0.0
var breath := 0.0
var gait := 0.0
var run_blend := 0.0
var airborne_blend := 0.0
var landing := 0.0
var _was_grounded := true
var _last_vertical_speed := 0.0
var materials: Dictionary = {}
var motion_acceleration := Vector2.ZERO
var turn_blend := 0.0
var _acceleration_target := Vector2.ZERO
var _turn_target := 0.0
var foot_contacts := [false, false]
var ground_heights: Array[float] = [0.0, 0.0]
var ground_normals: Array[Vector3] = [Vector3.UP, Vector3.UP]
var _ground_height_targets: Array[float] = [0.0, 0.0]
var _ground_normal_targets: Array[Vector3] = [Vector3.UP, Vector3.UP]
var _ground_valid: Array[bool] = [false, false]
var _ground_context_enabled := false
var _foot_locked: Array[bool] = [false, false]
var _foot_locks: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _takeoff := 0.0
var _turn_step := 0.0

# Samples are expressed relative to the character root, so the same articulated
# rig works in the game, the roster preview, and independent animation tests.
func set_ground_context(heights: Array[float], normals: Array[Vector3], valid: Array[bool]) -> void:
	_ground_context_enabled = true
	for i in 2:
		_ground_valid[i] = valid[i]
		_ground_height_targets[i] = clampf(heights[i], -.32, .32) if valid[i] else 0.0
		_ground_normal_targets[i] = normals[i].normalized() if valid[i] else Vector3.UP

func ground_sample_points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in 2:
		result.append(_foot_locks[i] if _foot_locked[i] else ankles[i].global_position)
	return result

func notify_jump() -> void:
	# A short visible push-off accompanies the immediate physical jump; it never
	# holds a buffered jump input while waiting for an anticipation animation.
	_takeoff = 1.0
	_foot_locked = [false, false]

func _ready() -> void:
	_make_materials()
	_build_torso()
	_build_head()
	for side in [-1.0, 1.0]:
		_build_arm(side)
		_build_leg(side)
	_build_equipment()
	animate(0.0, 0.0, true)

func _make_materials() -> void:
	materials.skin = _material("b68568", 0.64, 0.0, 0.07)
	materials.face = materials.skin.duplicate()
	materials.face.set_shader_parameter("stubble",0.6)
	materials.skin_dark = _material("916348", 0.72, 0.0, 0.06)
	materials.lip = _material("a77b68", 0.7, 0.0, 0.04)
	materials.hair = _material("29231e", 0.91, 0.0, 0.18)
	materials.hair_light = _material("322a22", 0.95, 0.0, 0.15)
	materials.eye = _material("c8baa2", 0.32, 0.0, 0.0)
	materials.iris = _material("5c6857", 0.28, 0.0, 0.1)
	materials.black = _material("141715", 0.65, 0.0, 0.06)
	materials.cloth = _material("555948", 0.94, 0.0, 0.28, 1.0)
	materials.pants = _material("42473d", 0.98, 0.0, 0.23, 1.0)
	materials.leather = _material("584032", 0.86, 0.0, 0.34)
	materials.edge = _material("9a7e59", 0.88, 0.0, 0.24)
	materials.metal = _material("696c61", 0.59, 0.65, 0.34)
	materials.rust = _material("874c34", 0.8, 0.28, 0.33)
	materials.scarf = _material("915d41", 0.96, 0.0, 0.23, 1.0)
	materials.bandage = _material("a49a7b", 0.95, 0.0, 0.25, 1.0)
	materials.sole = _material("252820", 0.98, 0.0, 0.27)

func _build_torso() -> void:
	torso = _pivot(self, "Torso", TORSO_REST)
	# Continuous pelvis, waist, chest and sloped shoulders; no floating box torso.
	_loft(torso, "Jacket", Vector3.ZERO, [
		Vector4(-0.105, .175, .102, .003), Vector4(-.09, .183, .112, 0),
		Vector4(.0, .165, .101, 0), Vector4(.12, .163, .107, 0),
		Vector4(.25, .199, .125, -.004), Vector4(.36, .226, .13, 0),
		Vector4(.43, .224, .115, .004), Vector4(.48, .155, .085, .004),
		Vector4(.505, .07, .062, 0)], materials.cloth, 40, .78)
	_loft(torso, "TrousersWaist", Vector3.ZERO, [
		Vector4(-.15,.16,.098,0), Vector4(-.10,.172,.105,0),
		Vector4(.01,.165,.099,0)], materials.pants)
	_loft(torso, "LeatherBelt", Vector3.ZERO, [
		Vector4(-.016,.169,.109,0), Vector4(.026,.169,.11,0)], materials.leather, 40, .72)
	_rounded_box(torso, "BeltBuckle", Vector3(0,.006,-.114), Vector3(.071,.046,.013), materials.metal)
	_rounded_box(torso, "BuckleInset", Vector3(0,.006,-.124), Vector3(.044,.024,.004), materials.leather)
	for side in [-1.0,1.0]:
		_rounded_box(torso,"VestPanel",Vector3(side*.109,.264,-.113),Vector3(.173,.31,.071),materials.leather)
		_rounded_box(torso,"ChestPocket",Vector3(side*.114,.224,-.158),Vector3(.116,.124,.038),materials.cloth)
		_rounded_box(torso,"PocketFlap",Vector3(side*.114,.274,-.181),Vector3(.122,.035,.017),materials.edge)
		_ellipsoid(torso,"PocketSnap",Vector3(side*.114,.27,-.192),Vector3(.012,.012,.007),materials.metal)
		_tube(torso,"VestStitch",[Vector3(side*.196,.122,-.119),Vector3(side*.196,.33,-.131),Vector3(side*.153,.405,-.106)],.002,materials.edge)
		# Fabric wrinkles follow the ribcage and waist rather than adding rigid blocks.
		for i in 3:
			_tube(torso,"JacketFold",[Vector3(side*.08,.048+i*.019,-.091),Vector3(side*.135,.064+i*.019,-.10),Vector3(side*.17,.059+i*.019,-.083)],.004,materials.cloth)
	_tube(torso,"Zipper",[Vector3(0,.055,-.109),Vector3(0,.365,-.14),Vector3(0,.425,-.115)],.004,materials.metal)
	_loft(torso,"Neck",Vector3(0,.46,0),[
		Vector4(0,.056,.051,.01),Vector4(.07,.05,.047,.0),Vector4(.13,.052,.048,0)],materials.skin)
	_loft(torso,"ScarfCollar",Vector3(0,.46,0),[
		Vector4(-.011,.086,.079,0),Vector4(.0,.095,.088,0),Vector4(.035,.085,.082,0),
		Vector4(.07,.068,.066,0),Vector4(.079,.058,.057,0)],materials.scarf,40)
	for i in 3:
		var pts: Array[Vector3] = []
		for j in 25:
			var a := TAU*j/24.0
			pts.append(Vector3(cos(a)*(.086-i*.006),.469+i*.022,sin(a)*(.081-i*.006)))
		_tube(torso,"ScarfFold",pts,.004,materials.scarf)
	scarf_tail = _pivot(torso,"ScarfTail",Vector3(-.035,.47,-.09))
	_loft(scarf_tail,"FoldedCloth",Vector3.ZERO,[Vector4(-.22,.025,.006,-.04),Vector4(-.15,.045,.01,-.06),Vector4(-.06,.035,.013,-.03),Vector4(0,.041,.014,0)],materials.scarf,24,.65)

func _build_head() -> void:
	head = _pivot(torso,"Head",Vector3(0,.572,0))
	# A shaped jaw, cheekbones and cranium; eight-head adult proportions.
	_loft(head,"Face",Vector3.ZERO,HEAD_PROFILE,materials.face,64,1.0,true)
	# The nose bridge and cheeks are sculpted into the continuous face surface.
	for side in [-1.0,1.0]:
		_ellipsoid(head,"Nostril",Vector3(side*.014,.086,-.098),Vector3(.006,.0025,.006),materials.skin_dark)
		_ellipsoid(head,"Ear",Vector3(side*.087,.111,.009),Vector3(.032,.061,.032),materials.skin)
		_ellipsoid(head,"EarConcha",Vector3(side*.101,.112,-.003),Vector3(.009,.032,.017),materials.skin_dark)
		_ellipsoid(head,"EarLobe",Vector3(side*.091,.088,.006),Vector3(.014,.019,.017),materials.skin)
		var x: float = side*.039
		_ellipsoid(head,"EyeSocket",Vector3(x,.141,-.071),Vector3(.044,.023,.019),materials.skin)
		_ellipsoid(head,"EyeWhite",Vector3(x,.143,-.08),Vector3(.033,.012,.009),materials.eye)
		_ellipsoid(head,"Iris",Vector3(x,.143,-.086),Vector3(.013,.013,.005),materials.iris)
		_ellipsoid(head,"Pupil",Vector3(x,.143,-.089),Vector3(.006,.008,.002),materials.black)
		_ellipsoid(head,"EyeGlint",Vector3(x-.002,.146,-.0905),Vector3(.002,.002,.001),materials.eye)
		_tube(head,"UpperEyelid",[Vector3(x-.019,.141,-.079),Vector3(x-.01,.15,-.085),Vector3(x+.006,.151,-.085),Vector3(x+.019,.142,-.078)],.002,materials.skin)
		_tube(head,"LowerEyelid",[Vector3(x-.018,.14,-.079),Vector3(x,.136,-.085),Vector3(x+.018,.14,-.079)],.0018,materials.skin)
		_tube(head,"BrowRidge",[Vector3(x-side*.021,.164,-.078),Vector3(x,.167,-.083),Vector3(x+side*.024,.162,-.076)],.0025,materials.skin)
		_tube(head,"Eyebrow",[Vector3(x-side*.018,.168,-.081),Vector3(x,.171,-.085),Vector3(x+side*.023,.165,-.079)],.002,materials.hair)
		_tube(head,"CheekCrease",[Vector3(side*.025,.086,-.073),Vector3(side*.033,.07,-.067),Vector3(side*.035,.058,-.061)],.0005,materials.skin_dark)
	# Thin lips sit in the face plane, with a closed mouth and defined chin.
	_tube(head,"UpperLip",[Vector3(-.027,.06,-.065),Vector3(-.01,.063,-.074),Vector3(0,.061,-.076),Vector3(.01,.063,-.074),Vector3(.027,.06,-.065)],.0019,materials.lip)
	_tube(head,"Mouth",[Vector3(-.026,.058,-.066),Vector3(0,.057,-.077),Vector3(.026,.058,-.066)],.0014,materials.skin_dark)
	_tube(head,"LowerLip",[Vector3(-.023,.055,-.066),Vector3(0,.052,-.076),Vector3(.023,.055,-.066)],.0022,materials.lip)
	# A healed scar and restrained stubble keep the face readable and human.
	_tube(head,"HealedScar",[Vector3(.062,.123,-.063),Vector3(.061,.112,-.069),Vector3(.056,.093,-.067)],.0008,materials.lip)
	_build_hair()

func _build_hair() -> void:
	# A close-cut scalp with a swept crown and an open forehead.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const SEGMENTS := 64
	const RINGS := 14
	for r in RINGS+1:
		for j in SEGMENTS+1:
			var a := TAU*j/SEGMENTS
			var lower := _hairline(a)
			var t := r/float(RINGS)
			var p := _hair_point(a,lerpf(lower,.264,t))
			vertices.append(p)
			normals.append(Vector3(p.x/.091,(p.y-.166)/.11,(p.z-.017)/.094).normalized())
			if r<RINGS and j<SEGMENTS:
				var k := r*(SEGMENTS+1)+j
				indices.append_array([k,k+1,k+SEGMENTS+2,k,k+SEGMENTS+2,k+SEGMENTS+1])
	_mesh(head,"CroppedHair",vertices,normals,indices,materials.hair)
	for i in 45:
		var a := TAU*i/45.0
		var pts: Array[Vector3] = []
		var lower := _hairline(a)+.008
		for j in 12:
			var t := j/11.0
			pts.append(_hair_point(a+t*.12,lerpf(lower,.256,t),.0027))
		_tube(head,"SweptHair",pts,.00065,materials.hair_light)

func _hairline(angle: float) -> float:
	return .135+.062*pow(-sin(angle),.4) if sin(angle)<0 else .135-.046*sin(angle)

func _hair_point(angle: float, y: float, margin := .002) -> Vector3:
	var profile: Vector4 = HEAD_PROFILE[-1]
	for i in HEAD_PROFILE.size()-1:
		if y<=HEAD_PROFILE[i+1].x:
			profile=HEAD_PROFILE[i].lerp(HEAD_PROFILE[i+1],clampf((y-HEAD_PROFILE[i].x)/(HEAD_PROFILE[i+1].x-HEAD_PROFILE[i].x),0,1))
			break
	return Vector3(cos(angle)*(profile.y+margin),y+.002,signf(sin(angle))*pow(absf(sin(angle)),.65 if sin(angle)<0 else 1.0)*(profile.z+margin)+profile.w)

func _build_arm(side: float) -> void:
	var arm := _pivot(torso,"LeftArm" if side<0 else "RightArm",Vector3(side*.235,.431,0))
	arms.append(arm)
	_loft(arm,"Sleeve",Vector3.ZERO,[Vector4(-.277,.046,.049,0),Vector4(-.20,.054,.057,0),Vector4(-.075,.071,.07,0),Vector4(.0,.07,.068,0),Vector4(.039,.033,.04,0)],materials.cloth)
	var elbow := _pivot(arm,"Elbow",Vector3(0,-.272,0))
	elbows.append(elbow)
	_ellipsoid(elbow,"ElbowCloth",Vector3.ZERO,Vector3(.094,.095,.10),materials.cloth)
	_loft(elbow,"Forearm",Vector3.ZERO,[Vector4(-.247,.033,.032,0),Vector4(-.16,.041,.043,0),Vector4(-.075,.05,.051,0),Vector4(.01,.046,.048,0)],materials.cloth)
	for i in 5:
		_loft(elbow,"WristWrap",Vector3.ZERO,[Vector4(-.225+i*.021,.037+i*.001,.04,0),Vector4(-.212+i*.021,.038+i*.001,.041,0)],materials.bandage,24)
	var hand := _pivot(elbow,"Hand",Vector3(0,-.268,0))
	_ellipsoid(hand,"Glove",Vector3(0,-.018,0),Vector3(.068,.09,.043),materials.leather)
	for i in 4:
		_ellipsoid(hand,"Finger",Vector3(-.024+i*.016,-.075+absf(1.5-i)*.005,-.006),Vector3(.015,.055,.023),materials.skin)
	_ellipsoid(hand,"Thumb",Vector3(-side*.038,-.02,-.006),Vector3(.02,.06,.023),materials.skin).rotation.z=side*.32
	if side<0:
		_rounded_box(arm,"SalvagedShoulderPlate",Vector3(-.025,.015,0),Vector3(.161,.099,.154),materials.metal)
		for z in [-.049,.049]:
			_ellipsoid(arm,"ShoulderRivet",Vector3(-.063,.06,z),Vector3(.012,.007,.012),materials.rust)
	else:
		_rounded_box(arm,"SleevePatch",Vector3(.065,-.108,-.019),Vector3(.014,.096,.078),materials.scarf)

func _build_leg(side: float) -> void:
	var leg := _pivot(self,"LeftLeg" if side<0 else "RightLeg",Vector3(side*.102,HIP_HEIGHT,0))
	legs.append(leg)
	_loft(leg,"TrouserThigh",Vector3.ZERO,[Vector4(-.4,.059,.061,0),Vector4(-.29,.069,.074,0),Vector4(-.12,.086,.088,.007),Vector4(.035,.083,.082,0)],materials.pants)
	_rounded_box(leg,"CargoPocket",Vector3(side*.077,-.18,.01),Vector3(.048,.164,.12),materials.cloth)
	_rounded_box(leg,"CargoFlap",Vector3(side*.103,-.117,.01),Vector3(.012,.035,.12),materials.edge)
	var knee := _pivot(leg,"Knee",Vector3(0,-THIGH_LENGTH,0))
	knees.append(knee)
	_ellipsoid(knee,"KneeCloth",Vector3.ZERO,Vector3(.119,.126,.126),materials.pants)
	_loft(knee,"TrouserShin",Vector3.ZERO,[Vector4(-.37,.045,.048,0),Vector4(-.27,.058,.06,.009),Vector4(-.10,.063,.066,.008),Vector4(.018,.058,.064,0)],materials.pants)
	_rounded_box(knee,"KneePad",Vector3(0,-.01,-.059),Vector3(.106,.131,.038),materials.leather)
	_rounded_box(knee,"KneePlate",Vector3(0,-.009,-.08),Vector3(.079,.086,.014),materials.metal)
	for i in 3:
		_tube(knee,"TrouserFold",[Vector3(-.039,-.195-i*.034,-.037),Vector3(.003,-.21-i*.034,-.05),Vector3(.037,-.197-i*.034,-.035)],.004,materials.pants)
	var ankle := _pivot(knee,"Ankle",Vector3(0,-SHIN_LENGTH,0))
	ankles.append(ankle)
	_loft(ankle,"BootShaft",Vector3.ZERO,[Vector4(-.068,.053,.065,.008),Vector4(.09,.049,.055,0),Vector4(.11,.051,.057,0)],materials.leather)
	_rounded_box(ankle,"Boot",Vector3(0,-.081,-.053),Vector3(.121,.139,.264),materials.leather)
	_rounded_box(ankle,"Sole",Vector3(0,-.139,-.054),Vector3(.13,.04,.276),materials.sole)
	_rounded_box(ankle,"ToeCap",Vector3(0,-.078,-.143),Vector3(.114,.077,.084),materials.leather)
	for i in 5:
		var y := -.055+i*.027
		var z := -.067+maxf(0.0,y)*.2
		_tube(ankle,"BootLace",[Vector3(-.024,y,z),Vector3(.023,y+.011,z-.003)],.0023,materials.edge)
		_tube(ankle,"BootLace",[Vector3(.024,y,z),Vector3(-.023,y+.011,z-.003)],.0023,materials.edge)

func _build_equipment() -> void:
	_rounded_box(torso,"Backpack",Vector3(0,.257,.159),Vector3(.277,.349,.137),materials.cloth)
	_rounded_box(torso,"BackpackLid",Vector3(0,.41,.172),Vector3(.285,.075,.146),materials.leather)
	_rounded_box(torso,"BackpackPocket",Vector3(0,.215,.238),Vector3(.201,.148,.044),materials.leather)
	for side in [-1.0,1.0]:
		_tube(torso,"ShoulderStrap",[Vector3(side*.129,.066,-.112),Vector3(side*.155,.344,-.15),Vector3(side*.142,.454,-.067),Vector3(side*.128,.46,.06),Vector3(side*.104,.34,.227)],.015,materials.leather)
		_rounded_box(torso,"StrapBuckle",Vector3(side*.15,.332,-.166),Vector3(.046,.06,.014),materials.metal)
		_tube(torso,"PackWebbing",[Vector3(side*.069,.09,.236),Vector3(side*.069,.43,.245)],.008,materials.edge)
	_ellipsoid(torso,"Canteen",Vector3(.217,.055,.075),Vector3(.106,.178,.084),materials.metal)
	_rounded_box(torso,"CanteenCap",Vector3(.216,.148,.075),Vector3(.044,.029,.045),materials.leather)
	_rounded_box(torso,"BeltPouch",Vector3(-.193,.009,-.018),Vector3(.108,.143,.096),materials.leather)
	# A rolled blanket sits across the pack, never beneath the feet.
	var roll := _pivot(torso,"Bedroll",Vector3(0,.052,.178))
	roll.rotation.z=PI*.5
	_loft(roll,"Blanket",Vector3.ZERO,[Vector4(-.165,.058,.061,0),Vector4(-.157,.066,.066,0),Vector4(.157,.066,.066,0),Vector4(.165,.058,.061,0)],materials.bandage)
	for x in [-.095,.095]:
		_loft(roll,"BlanketStrap",Vector3.ZERO,[Vector4(x-.009,.068,.068,0),Vector4(x+.009,.068,.068,0)],materials.leather)

func set_motion_context(local_acceleration: Vector3, yaw_speed: float) -> void:
	_acceleration_target = Vector2(clampf(-local_acceleration.z/18.0,-1.0,1.0),clampf(local_acceleration.x/18.0,-1.0,1.0))
	_turn_target = clampf(yaw_speed/5.0,-1.0,1.0)

func reset_motion() -> void:
	phase = 0.0
	gait = 0.0
	run_blend = 0.0
	airborne_blend = 0.0
	landing = 0.0
	_turn_target = 0.0
	turn_blend = 0.0
	motion_acceleration = Vector2.ZERO
	_acceleration_target = Vector2.ZERO
	_was_grounded = true
	_last_vertical_speed = 0.0
	_takeoff = 0.0
	_turn_step = 0.0
	_ground_context_enabled = false
	_ground_valid = [false, false]
	ground_heights = [0.0, 0.0]
	ground_normals = [Vector3.UP, Vector3.UP]
	_ground_height_targets = [0.0, 0.0]
	_ground_normal_targets = [Vector3.UP, Vector3.UP]
	_foot_locked = [false, false]
	foot_contacts = [false, false]
	animate(0.0,0.0,true)

func animate(delta: float, horizontal_speed: float, grounded: bool, vertical_speed: float = 0.0) -> void:
	breath += delta * 1.9
	run_blend = move_toward(run_blend, smoothstep(1.8, 5.6, horizontal_speed), delta * 3.8)
	motion_acceleration = motion_acceleration.lerp(_acceleration_target, 1.0 - exp(-delta * 7.0))
	turn_blend = lerpf(turn_blend, _turn_target, 1.0 - exp(-delta * 8.0))
	_turn_step = lerpf(_turn_step, absf(_turn_target) * (1.0 - smoothstep(.3, 1.3, horizontal_speed)), 1.0 - exp(-delta * 12.0))
	airborne_blend = move_toward(airborne_blend, 0.0 if grounded else 1.0, delta * 10.0)
	if grounded and not _was_grounded:
		landing = clampf(absf(_last_vertical_speed) / 12.0, .15, .8)
		_foot_locked = [false, false]
	landing = move_toward(landing, 0.0, delta * 2.6)
	_takeoff = move_toward(_takeoff, 0.0, delta * 7.5)
	_was_grounded = grounded
	_last_vertical_speed = vertical_speed
	if grounded and gait < .001 and horizontal_speed > .05 and run_blend < .05:
		# Start with the supporting foot beneath the hip. Locking the idle foot
		# at the beginning of a full forward-contact phase overextends it and
		# later teleports the knee when that lock exceeds its reach limit.
		phase = TAU * (.409 / WALK_STRIDE)
	var gait_target := maxf(clampf(horizontal_speed / WALK_SPEED, 0, 1), _turn_step * .42) if grounded else 0.0
	gait = move_toward(gait, gait_target, delta * (6.5 if gait_target > gait else 4.8))
	for i in 2:
		ground_heights[i] = lerpf(ground_heights[i], _ground_height_targets[i] if grounded else 0.0, 1.0 - exp(-delta * 24.0))
		# Ground normals are all upward-facing. Normalized linear interpolation
		# avoids an unstable rotation axis when two slope samples nearly coincide.
		ground_normals[i] = ground_normals[i].lerp(_ground_normal_targets[i] if grounded else Vector3.UP, 1.0 - exp(-delta * 18.0)).normalized()
	# Walking includes double support; sprinting includes a real recovery/flight
	# interval. Matching stride length to actual travel avoids fast marching.
	var stride_distance := lerpf(WALK_STRIDE, RUN_STRIDE, run_blend)
	var reach := lerpf(.409, .396, run_blend)
	var stance := 2.0 * reach / stride_distance
	if grounded:
		phase = fposmod(phase + delta * (horizontal_speed + _turn_step * .55) / stride_distance * TAU, TAU)
	var weight_shift := -sin(phase) * gait * lerpf(.016, .010, run_blend) + sin(breath * .43) * (1.0 - gait) * .004
	var terrain_pelvis := minf(ground_heights[0], ground_heights[1]) * .7 if grounded else 0.0
	# Highest over the supporting foot in walking, lowest during loading in
	# running. A shared hip/chest translation keeps the anatomy connected.
	var step_cycle := fposmod(phase / PI, 1.0)
	var walk_height := -.104 + .048 * pow(sin(step_cycle * PI), 2)
	# Keep a flexed knee at touchdown: a nearly straight IK chain has a
	# singular bend response and used to snap as the sprint foot took weight.
	var run_height := -.145 + .075 * (.5 - .5 * cos((step_cycle - stance) * TAU))
	var pelvis_y := gait * lerpf(walk_height, run_height, run_blend) - landing * .065 + terrain_pelvis
	var pelvis_z := -motion_acceleration.x * gait * .018
	var pelvis_yaw := -cos(phase) * gait * lerpf(.055, .085, run_blend)
	torso.position = TORSO_REST + Vector3(weight_shift, pelvis_y + sin(breath) * .0025 - _takeoff * .019, pelvis_z)
	torso.rotation = Vector3(-gait * lerpf(.022, .17, run_blend) - motion_acceleration.x * .063 - airborne_blend * .045 + landing * .075,
		-pelvis_yaw * .68 + turn_blend * .055,
		-sin(phase) * gait * .016 - motion_acceleration.y * .043 + turn_blend * gait * .052)
	head.rotation = Vector3(-torso.rotation.x * .52 + sin(breath * .7) * .007,
		-torso.rotation.y * .72 + turn_blend * .095 + sin(breath * .31) * (1.0 - gait) * .018,
		-torso.rotation.z * .82)
	scarf_tail.rotation = Vector3(sin(phase + .7) * gait * .05 + run_blend * .05 + landing * .06, 0, -turn_blend * gait * .06)
	var rising := clampf(vertical_speed / 7.4, 0, 1)
	var falling := clampf(-vertical_speed / 7.4, 0, 1)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var cycle := fposmod(phase / TAU + i * .5, 1.0)
		var foot_z: float
		var foot_lift := 0.0
		var foot_pitch := 0.0
		if cycle < stance:
			var planted := cycle / stance
			foot_z = lerpf(-reach, reach, planted)
			foot_pitch = lerpf(.14, .055, run_blend) * (1.0 - smoothstep(0.0, .24, planted)) - lerpf(.24, .36, run_blend) * smoothstep(.70, 1.0, planted)
		else:
			var swing := (cycle - stance) / (1.0 - stance)
			# Cubic recovery continues backward briefly after toe-off, then brings
			# the foot through under the pelvis. Heel recovery peaks early in a run.
			var tangent := minf(stride_distance * (1.0 - stance), .80)
			foot_z = _recovery_z(swing, reach, tangent)
			var lift_phase := pow(swing, lerpf(1.0, .72, run_blend))
			foot_lift = pow(sin(lift_phase * PI), 1.65) * lerpf(.095, .39, run_blend)
			foot_pitch = lerpf(-lerpf(.24, .36, run_blend), lerpf(.14, .055, run_blend), smoothstep(0.0, 1.0, swing)) - sin(swing * PI) * lerpf(.08, .30, run_blend)
		foot_z *= gait
		foot_pitch *= gait
		var normal := ground_normals[i]
		foot_pitch += atan2(normal.z, normal.y) * (1.0 - airborne_blend)
		var foot_roll := -atan2(normal.x, normal.y) * (1.0 - airborne_blend)
		var foot_basis := Basis.from_euler(Vector3(foot_pitch, 0, foot_roll))
		var sole_clearance := _sole_clearance(foot_basis)
		var foot_y := sole_clearance + foot_lift * gait + ground_heights[i]
		var foot_x := side * .102 + side * sin(cycle * TAU) * gait * .007 + turn_blend * gait * .012
		var planted_now := grounded and (cycle < stance or gait < .08) and _ground_valid[i]
		var foot_target := Vector3(foot_x, foot_y, foot_z)
		if _ground_context_enabled:
			if planted_now and not _foot_locked[i]:
				_foot_locks[i] = to_global(foot_target)
				_foot_locked[i] = true
			elif not planted_now:
				_foot_locked[i] = false
			if _foot_locked[i]:
				var locked_local := to_local(_foot_locks[i])
				# A teleport, a dash, or a sharp reversal must not stretch the leg.
				if Vector2(locked_local.x - side * .102, locked_local.z).length() < .47:
					foot_target.x = locked_local.x
					foot_target.z = locked_local.z
				else:
					_foot_locked[i] = false
		var hip_x := side * .102 + weight_shift * .5
		legs[i].position = Vector3(hip_x, HIP_HEIGHT + pelvis_y, pelvis_z - side * pelvis_yaw * .102)
		var hip_y := legs[i].position.y
		var dz := foot_target.z - legs[i].position.z
		var dx := foot_target.x - hip_x
		foot_target.y = maxf(foot_target.y, hip_y - sqrt(maxf(.01, pow(THIGH_LENGTH + SHIN_LENGTH - .001, 2) - dz * dz - dx * dx)))
		var dy := hip_y - foot_target.y
		var lateral_down := Vector2(dx, dy).length()
		var distance := clampf(Vector2(lateral_down, dz).length(), .3, THIGH_LENGTH + SHIN_LENGTH - .001)
		var bend := acos(clampf((THIGH_LENGTH * THIGH_LENGTH + distance * distance - SHIN_LENGTH * SHIN_LENGTH) / (2 * THIGH_LENGTH * distance), -1, 1))
		var hip_angle := atan2(-dz, lateral_down) + bend
		var knee_angle := -(PI - acos(clampf((THIGH_LENGTH * THIGH_LENGTH + SHIN_LENGTH * SHIN_LENGTH - distance * distance) / (2 * THIGH_LENGTH * SHIN_LENGTH), -1, 1)))
		var jump_hip := .24 + rising * .23 - falling * .12 + side * run_blend * .10
		var jump_knee := -.65 - rising * .38 + falling * .26 - side * run_blend * .07
		var hip_roll := atan2(dx, dy) * (1.0 - airborne_blend)
		legs[i].basis = Basis(Vector3.BACK, hip_roll) * Basis(Vector3.RIGHT, lerp_angle(hip_angle, jump_hip, airborne_blend))
		knees[i].rotation.x = lerp_angle(knee_angle, jump_knee, airborne_blend)
		var sole_basis := Basis.from_euler(Vector3(lerpf(foot_pitch, -.12 + falling * .16, airborne_blend), 0, foot_roll))
		ankles[i].basis = (legs[i].basis * knees[i].basis).inverse() * sole_basis
		foot_contacts[i] = grounded and cycle < stance and gait > .9
	# Each arm opposes its own thigh. A shared left-minus-right drive can
	# preserve the pose ordering yet reverse an arm when the OTHER leg moves
	# faster, producing same-side motion during the supporting step.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var knee_local := legs[i].transform * knees[i].position
		var walk_swing := .38 * tanh((knee_local.z - pelvis_z + .12) * 3.6) * gait
		var arm_phase := phase + i * PI - .10
		var run_swing := -cos(arm_phase) * gait * .72 + sin(arm_phase * 2.0) * gait * .018
		# Balance the hand around the hip despite the relaxed elbow bend.
		var walk_rest := lerpf(.015, -.09, gait)
		var arm_swing := lerpf(walk_rest + walk_swing, .015 + run_swing, run_blend)
		var jump_raise := .28 + rising * .30 - falling * .11
		arms[i].rotation = Vector3(lerp_angle(arm_swing, jump_raise, airborne_blend) + landing * .12,
			turn_blend * side * .024 - pelvis_yaw * .15,
			side * (.09 + gait * .011 + airborne_blend * .05) - motion_acceleration.y * .016)
		var walk_elbow := .15 + gait * .07 + walk_swing * .18
		var run_elbow := .15 + gait * .92 - cos(arm_phase - .25) * gait * .13
		var elbow_bend := lerpf(walk_elbow, run_elbow, run_blend)
		elbows[i].rotation = Vector3(lerp_angle(elbow_bend, .68 + rising * .22, airborne_blend), 0, 0)
		var hand := elbows[i].get_node_or_null("Hand") as Node3D
		if hand:
			hand.rotation = Vector3(-.035 + sin(phase + i * PI - .3) * gait * .04, -side * (.90 - run_blend * .18), side * .04)

func _recovery_z(t: float, reach: float, tangent: float) -> float:
	var u := 1.0 - t
	return u*u*u*reach + 3.0*u*u*t*(reach+tangent/3.0) + 3.0*u*t*t*(-reach-tangent/3.0) - t*t*t*reach

func _sole_clearance(orientation: Basis) -> float:
	var clearance := 0.0
	for x in [-.066, .066]:
		for z in [-.192, .084]:
			clearance = maxf(clearance, -(orientation * Vector3(x, -.159, z)).y)
	return clearance + .003

func _material(hex: String, roughness: float, metallic: float, wear: float, weave := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=SURFACE
	mat.set_shader_parameter("base_color",Color(hex))
	mat.set_shader_parameter("roughness_value",roughness)
	mat.set_shader_parameter("metal_value",metallic)
	mat.set_shader_parameter("wear",wear)
	mat.set_shader_parameter("weave",weave)
	return mat

func _pivot(parent: Node3D, label: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name=label
	node.position=pos
	parent.add_child(node)
	return node

func _ellipsoid(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius=.5
	mesh.height=1.0
	mesh.radial_segments=32
	mesh.rings=16
	var node := MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	node.material_override=mat
	node.position=pos
	node.scale=size
	parent.add_child(node)
	return node

func _rounded_box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return _loft(parent,label,pos,[Vector4(-size.y*.5,size.x*.36,size.z*.36,0),Vector4(-size.y*.38,size.x*.5,size.z*.5,0),Vector4(size.y*.38,size.x*.5,size.z*.5,0),Vector4(size.y*.5,size.x*.36,size.z*.36,0)],mat,24,.4)

func _loft(parent: Node3D, label: String, pos: Vector3, rings: Array, mat: Material, segments := 32, power := 1.0, face := false) -> MeshInstance3D:
	if face:
		var detailed: Array = []
		for i in rings.size()-1:
			for j in 4:
				detailed.append(rings[i].lerp(rings[i+1],j/4.0))
		detailed.append(rings[-1])
		rings=detailed
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in rings.size():
		var ring: Vector4 = rings[r]
		for j in segments+1:
			var a := TAU*j/segments
			var x := signf(cos(a))*pow(absf(cos(a)),power)*ring.y
			var z := signf(sin(a))*pow(absf(sin(a)),.65 if face and sin(a)<0 else power)*ring.z+ring.w
			if face and sin(a)<0:
				var bridge := .018*exp(-pow((ring.x-.143)/.038,2)-pow(x/.015,2))
				var tip := .034*exp(-pow((ring.x-.10)/.017,2)-pow(x/.022,2))
				var cheeks := .003*exp(-pow((ring.x-.11)/.028,2)-pow((absf(x)-.053)/.025,2))
				var nostril_wings := .013*exp(-pow((ring.x-.089)/.009,2)-pow((absf(x)-.019)/.012,2))
				z-=bridge+tip+cheeks+nostril_wings
			vertices.append(Vector3(x,ring.x,z))
			if r<rings.size()-1 and j<segments:
				var k := r*(segments+1)+j
				indices.append_array([k,k+1,k+segments+2,k,k+segments+2,k+segments+1])
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	# Godot uses clockwise front faces; reverse the cross product for outward normals.
	for i in range(0,indices.size(),3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		var normal := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a]+=normal
		normals[b]+=normal
		normals[c]+=normal
	for r in rings.size():
		var first := r*(segments+1)
		var seam := (normals[first]+normals[first+segments]).normalized()
		normals[first]=seam
		normals[first+segments]=seam
	for i in normals.size(): normals[i]=normals[i].normalized()
	for end in [0,rings.size()-1]:
		var ring: Vector4=rings[end]
		var start := vertices.size()
		vertices.append(Vector3(0,ring.x,ring.w))
		normals.append(Vector3.DOWN if end==0 else Vector3.UP)
		for j in segments+1:
			vertices.append(vertices[end*(segments+1)+j])
			normals.append(Vector3.DOWN if end==0 else Vector3.UP)
			if j<segments:
				if end==0: indices.append_array([start,start+j+2,start+j+1])
				else: indices.append_array([start,start+j+1,start+j+2])
	var node := _mesh(parent,label,vertices,normals,indices,mat)
	node.position=pos
	return node

func _tube(parent: Node3D, label: String, points: Array, radius: float, mat: Material) -> MeshInstance3D:
	if points.size()>2:
		var smooth: Array = []
		for i in points.size()-1:
			for j in 4:
				smooth.append(points[i].cubic_interpolate(points[i+1],points[maxi(i-1,0)],points[mini(i+2,points.size()-1)],j/4.0))
		smooth.append(points[-1])
		points=smooth
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const SIDES := 8
	for i in points.size():
		var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var axis := Vector3.UP if absf(tangent.y)<.9 else Vector3.RIGHT
		var normal := tangent.cross(axis).normalized()
		var binormal := normal.cross(tangent).normalized()
		for j in SIDES+1:
			var radial := cos(TAU*j/SIDES)*normal+sin(TAU*j/SIDES)*binormal
			vertices.append(points[i]+radial*radius)
			normals.append(radial)
			if i<points.size()-1 and j<SIDES:
				var k := i*(SIDES+1)+j
				indices.append_array([k,k+1,k+SIDES+2,k,k+SIDES+2,k+SIDES+1])
	return _mesh(parent,label,vertices,normals,indices,mat)

func _mesh(parent: Node3D, label: String, vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, mat: Material) -> MeshInstance3D:
	var data := []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX]=vertices
	data[Mesh.ARRAY_NORMAL]=normals
	data[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
	var node := MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	node.material_override=mat
	parent.add_child(node)
	return node
