extends RefCounted
## Recoverable valuables. The round controller owns collecting and cashing out.

const Equipment = preload("res://equipment_geometry.gd")
const PARTS = preload("res://wasteland_interactables.gd")
const FONT = preload("res://assets/fonts/NotoSansSC.ttf")
const CATALOG := {
	"coin": {"display_name":"旧世金币", "value":15, "accent":Color("e5bd69")},
	"watch": {"display_name":"古董腕表", "value":55, "accent":Color("cf96dc")},
	"chip": {"display_name":"军用数据芯", "value":100, "accent":Color("7fdde5")},
	"gold": {"display_name":"封存金锭", "value":180, "accent":Color("f0d788")}
}
const ALIASES := {"coin_cache":"coin", "old_watch":"watch", "data_core":"chip", "gold_bar":"gold"}
static var _metals: Dictionary = {}

static func pickup(kind: String) -> Area3D:
	kind = ALIASES.get(kind,kind)
	if not CATALOG.has(kind):
		push_error("Unknown valuable pickup: %s" % kind)
		return null
	var item: Dictionary = CATALOG[kind]
	var area := Area3D.new()
	area.name = "%sPickup" % kind.to_pascal_case()
	area.collision_layer = 2
	area.collision_mask = 1
	area.add_to_group("valuable_pickups")
	area.set_meta("kind", kind)
	area.set_meta("display_name", item.display_name)
	area.set_meta("value", item.value)
	var shape := CollisionShape3D.new()
	shape.name = "PickupShape"
	var sphere := SphereShape3D.new()
	sphere.radius = .55
	shape.shape = sphere
	shape.position.y = .24
	area.add_child(shape)
	var model := PARTS._group(area, "Model")
	match kind:
		"coin": _coins(model)
		"watch": _watch(model)
		"chip": _data_core(model)
		"gold": _gold_bar(model)
	PARTS._merge_static(model)
	PARTS.limit_pickup_detail(area)
	var locator := PARTS._sphere(area,Vector3(0,.49,0),.018,PARTS._lamp_material(item.accent,1.0))
	locator.name = "Locator"
	locator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	locator.visibility_range_end = 90.0
	var tag := PARTS._label(area,item.display_name,Vector3(0,.65,0),32,.0026,item.accent,true)
	tag.name = "PickupLabel"
	tag.font = FONT
	tag.outline_size = 5
	tag.visibility_range_end = 12.0
	tag.visibility_range_end_margin = 2.0
	tag.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return area

static func _metal(hex: String, roughness: float = .35, metallic: float = .82) -> StandardMaterial3D:
	var key := "%s/%f/%f" % [hex,roughness,metallic]
	if _metals.has(key): return _metals[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.metallic = metallic
	mat.roughness = roughness
	mat.clearcoat_enabled = true
	mat.clearcoat = .25
	mat.clearcoat_roughness = .31
	_metals[key] = mat
	return mat

static func _coins(model: Node3D) -> void:
	var leather := PARTS._mat("564337",7,.97)
	var seam := PARTS._mat("96866a",7,.97)
	var inside := PARTS._mat("25241d",4,.98)
	var gold := _metal("cba054",.3)
	var old_gold := _metal("9c7940",.49)
	# A gathered, open leather pouch with actual folds and a dark interior.
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const SEGMENTS := 40
	var profiles := [Vector2(.105,.014),Vector2(.161,.035),Vector2(.186,.068),Vector2(.193,.12),Vector2(.181,.158),Vector2(.152,.19),Vector2(.16,.217)]
	for row in profiles.size():
		for side in SEGMENTS:
			var angle := TAU*side/float(SEGMENTS)
			var ripple := 1.0 + sin(angle*7.0+.3)*(.012+pow(float(row)/6.0,2)*.085)
			var radius: float = profiles[row].x*ripple
			vertices.append(Vector3(cos(angle)*radius,profiles[row].y+sin(angle*5.0)*.008,sin(angle)*radius*.76))
			if row < profiles.size()-1:
				var a := row*SEGMENTS+side
				var b := row*SEGMENTS+(side+1)%SEGMENTS
				indices.append_array([a,b,a+SEGMENTS,b,b+SEGMENTS,a+SEGMENTS])
	PARTS._surface(model,vertices,indices,leather,true)
	var interior := PARTS._cylinder(model,Vector3(0,.177,0),.155,.012,inside)
	interior.scale.z = .76
	for side in 40:
		var angle := TAU*side/40.0
		var next := angle+TAU/40.0*.65
		PARTS._rod(model,Vector3(cos(angle)*.165,.206,sin(angle)*.126),Vector3(cos(next)*.165,.206,sin(next)*.126),.0023,seam)
	for i in 5:
		PARTS._rod(model,Vector3(.15+i*.011,.193-i*.023,-.045),Vector3(.16+i*.011,.177-i*.023,-.055),.0035,leather)
	PARTS._ring(model,Vector3(.179,.114,-.05),.009,.014,old_gold).rotation.z = .8
	# Small separate piles preserve the recognisable milled edges and stamped faces.
	for stack in 7:
		var a := stack*2.4
		var pos := Vector3(cos(a)*.08,.185,sin(a)*.057)
		for layer in 2+stack%3:
			_coin(model,pos+Vector3(layer*.002,layer*.008,0),gold,old_gold,stack*.6)
	for i in 5:
		_coin(model,Vector3(.17+i*.024,.015+i%2*.009,-.145+sin(i*2.7)*.047),gold,old_gold,i*.9)
	# A torn leather flap and small brass fastening sit beside the dropped coins.
	var flap := PARTS._box(model,Vector3(-.17,.032,.045),Vector3(.105,.013,.19),leather)
	flap.rotation = Vector3(.06,.35,.18)
	PARTS._cylinder(model,Vector3(-.21,.051,.063),.014,.006,old_gold)

static func _coin(model: Node3D, pos: Vector3, gold: Material, old_gold: Material, angle: float) -> void:
	PARTS._cylinder(model,pos,.035,.007,gold)
	for edge in 20:
		var a := float(edge)*TAU/20
		PARTS._rod(model,pos+Vector3(cos(a)*.0349,-.002,sin(a)*.0349),pos+Vector3(cos(a)*.0349,.002,sin(a)*.0349),.00065,old_gold)
	var rim := PARTS._ring(model,pos+Vector3(0,.0045,0),.027,.032,old_gold)
	rim.scale.y = .48
	var stamp := PARTS._box(model,pos+Vector3(0,.005,0),Vector3(.017,.002,.017),old_gold)
	stamp.rotation.y = angle+PI*.25
	for i in 6:
		var a := i*TAU/6.0
		PARTS._sphere(model,pos+Vector3(cos(a)*.022,.005,sin(a)*.022),.0023,old_gold)

static func _watch(model: Node3D) -> void:
	var case_mat := PARTS._mat("423e4b",7,.91)
	var lining := PARTS._mat("28292e",4,.99)
	var gold := _metal("b5a16c",.28)
	var dial := _metal("ddd3b3",.62,.08)
	var ink := PARTS._mat("282a2a",4,.85)
	var leather := PARTS._mat("49372b",7,.93)
	_open_case(model,Vector3(.36,.105,.29),case_mat,lining,gold)
	for z in [-.094,.094]:
		_beveled_box(model,Vector3(0,.122,z),Vector3(.08,.024,.099),.008,leather)
		for x in [-.031,.031]:
			for i in 6:
				PARTS._box(model,Vector3(x,.136,z-.035+i*.012),Vector3(.002,.002,.005),gold)
	for z in [-.127,-.109,-.091]:
		PARTS._cylinder(model,Vector3(0,.138,z),.004,.003,ink)
	PARTS._cylinder(model,Vector3(0,.143,0),.079,.031,gold)
	PARTS._cylinder(model,Vector3(0,.16,0),.069,.005,dial)
	var bezel := PARTS._ring(model,Vector3(0,.163,0),.068,.078,gold)
	bezel.scale.y = .48
	for i in 12:
		var angle := i*TAU/12.0
		var mark := PARTS._box(model,Vector3(sin(angle)*.056,.165,cos(angle)*.056),Vector3(.003,.002,.01 if i%3 else .015),ink)
		mark.rotation.y = angle
	PARTS._rod(model,Vector3(0,.168,0),Vector3(-.024,.168,-.022),.0025,ink)
	PARTS._rod(model,Vector3(0,.169,0),Vector3(.039,.169,-.017),.0019,ink)
	PARTS._rod(model,Vector3(-.009,.17,.027),Vector3(.017,.17,-.044),.0008,gold)
	PARTS._cylinder(model,Vector3(0,.171,0),.005,.003,gold)
	PARTS._rod(model,Vector3(.078,.146,0),Vector3(.087,.146,0),.009,gold)
	PARTS._ring(model,Vector3(0,.164,.025),.012,.014,gold).scale.y = .22
	var brand := PARTS._label(model,"ORION",Vector3(0,.165,-.025),28,.0006,Color("37362c"),false)
	brand.rotation.x = -PI*.5
	brand.rotation.z = PI
	brand.outline_size = 0

static func _data_core(model: Node3D) -> void:
	var casing := PARTS._mat("44585c",3,.72,.5)
	var black := PARTS._mat("222b2d",4,.87)
	var steel := _metal("8d9693",.48)
	var copper := _metal("ba7844",.5)
	var cyan := PARTS._lamp_material(Color("68cadc"),1.3)
	var board := PARTS._mat("344e45",7,.82)
	_beveled_box(model,Vector3(0,.022,0),Vector3(.51,.044,.36),.017,black)
	_beveled_box(model,Vector3(0,.114,0),Vector3(.39,.143,.26),.019,casing)
	_beveled_box(model,Vector3(0,.191,0),Vector3(.33,.017,.213),.009,black)
	PARTS._box(model,Vector3(0,.202,0),Vector3(.21,.011,.166),board)
	_beveled_box(model,Vector3(0,.218,-.003),Vector3(.105,.032,.09),.009,steel)
	PARTS._box(model,Vector3(0,.236,-.003),Vector3(.078,.004,.061),black)
	for x in [-.045,.045]:
		for z in [-.026,-.013,0.0,.013,.026]:
			PARTS._box(model,Vector3(x*1.45,.214,z),Vector3(.025,.006,.006),copper)
	for side in [-1.0,1.0]:
		PARTS._box(model,Vector3(side*.156,.211,0),Vector3(.017,.009,.18),cyan)
		for z in [-.073,0.0,.073]:
			PARTS._box(model,Vector3(side*.156,.22,z),Vector3(.032,.009,.012),steel)
		for i in 7:
			PARTS._box(model,Vector3(side*.198,.112,-.083+i*.027),Vector3(.012,.059,.011),black)
	for x in [-.147,.147]:
		for z in [-.093,.093]:
			PARTS._cylinder(model,Vector3(x,.205,z),.007,.009,steel)
	for x in [-.11,-.073,-.036,0.001,.038,.075,.112]:
		PARTS._box(model,Vector3(x,.107,-.139),Vector3(.016,.052,.02),copper)
	PARTS._rod(model,Vector3(-.14,.044,.17),Vector3(-.12,.048,.23),.006,black)
	PARTS._rod(model,Vector3(-.12,.048,.23),Vector3(.035,.052,.202),.006,black)
	_beveled_box(model,Vector3(.059,.052,.195),Vector3(.057,.035,.033),.006,casing)
	for i in 3:
		PARTS._cylinder(model,Vector3(.112+i*.022,.048,-.17),.007,.006,cyan)
	var serial := PARTS._label(model,"D-07 / ARCHIVE",Vector3(0,.047,.144),24,.00095,Color("b5bdb3"),false)
	serial.rotation.x = -PI*.5
	serial.rotation.z = PI
	serial.outline_size = 0

static func _gold_bar(model: Node3D) -> void:
	var case_mat := PARTS._mat("465247",3,.84,.25)
	var lining := PARTS._mat("333129",4,.98)
	var trim := _metal("91856a",.61)
	var gold := _metal("d1a35b",.29)
	var stamp := _metal("94703c",.53)
	_open_case(model,Vector3(.49,.112,.32),case_mat,lining,trim)
	# The bank ingot has sloping cast sides, bevels and a stamped purity mark.
	var vertices := PackedVector3Array([
		Vector3(-.159,.11,-.084),Vector3(.159,.11,-.084),Vector3(.159,.11,.084),Vector3(-.159,.11,.084),
		Vector3(-.14,.19,-.065),Vector3(.14,.19,-.065),Vector3(.14,.19,.065),Vector3(-.14,.19,.065)
	])
	_flat_surface(model,vertices,[0,1,2,0,2,3,4,7,6,4,6,5,0,4,5,0,5,1,1,5,6,1,6,2,2,6,7,2,7,3,3,7,4,3,4,0],gold)
	var hallmark := PARTS._ring(model,Vector3(-.099,.191,0),.016,.019,stamp)
	hallmark.scale.y = .14
	PARTS._box(model,Vector3(-.099,.192,0),Vector3(.016,.001,.016),stamp).rotation.y = PI*.25
	var label := PARTS._label(model,"FINE GOLD\n999.9",Vector3(.025,.192,0),28,.00105,Color("8c6938"),false)
	label.rotation.x = -PI*.5
	label.rotation.z = PI
	label.outline_size = 0
	# A ripped red security seal makes the opened case read as salvaged cargo.
	var seal := PARTS._mat("80453a",7,.96)
	PARTS._box(model,Vector3(.18,.077,-.169),Vector3(.039,.084,.004),seal).rotation.z = .12
	PARTS._box(model,Vector3(.199,.009,-.22),Vector3(.041,.004,.08),seal).rotation.y = -.3

static func _open_case(model: Node3D, size: Vector3, case_mat: Material, lining: Material, trim: Material) -> void:
	_beveled_box(model,Vector3(0,size.y*.5,0),size,.014,case_mat)
	PARTS._box(model,Vector3(0,size.y+.003,0),Vector3(size.x-.034,.012,size.z-.032),lining)
	for x in [-size.x*.43,size.x*.43]:
		PARTS._box(model,Vector3(x,size.y*.7,-size.z*.52),Vector3(.026,.035,.014),trim)
		PARTS._rod(model,Vector3(x-.019,size.y*.94,size.z*.49),Vector3(x+.019,size.y*.94,size.z*.49),.01,trim)
	var lid := PARTS._group(model,"OpenedLid")
	lid.position = Vector3(0,size.y*.84,size.z*.5)
	lid.rotation.x = -1.12
	_beveled_box(lid,Vector3(0,0,size.z*.49),Vector3(size.x,.035,size.z),.012,case_mat)
	PARTS._box(lid,Vector3(0,.021,size.z*.49),Vector3(size.x-.046,.012,size.z-.042),lining)
	for x in [-size.x*.42,size.x*.42]:
		for z in [size.z*.14,size.z*.84]:
			PARTS._cylinder(lid,Vector3(x,.022,z),.006,.003,trim)
	PARTS._merge_static(lid)

static func _beveled_box(parent: Node3D, pos: Vector3, size: Vector3, bevel: float, mat: Material) -> void:
	PARTS._shape(parent,pos,Equipment.beveled_box(size,bevel),mat)

static func _flat_surface(parent: Node3D, vertices: PackedVector3Array, indices: Array, mat: Material) -> void:
	# Independent face normals retain the crisp little chamfers in close views.
	var expanded := PackedVector3Array()
	var expanded_indices := PackedInt32Array()
	for triangle in range(0,indices.size(),3):
		# Godot faces use clockwise winding when viewed from outside.
		for offset in [0,2,1]:
			expanded_indices.append(expanded.size())
			expanded.append(vertices[indices[triangle+offset]])
	PARTS._surface(parent,expanded,expanded_indices,mat)
