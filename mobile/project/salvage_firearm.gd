extends Node3D
## Reclaimed single-shot repulsor. Gameplay clocks advance only from the active round.
const Equipment = preload("res://equipment_geometry.gd")
const Effects = preload("res://model_effects.gd")
const RANGE := 32.0
const SHOT_INTERVAL := .75
const AIM_ASSIST := deg_to_rad(8.0)
const SURFACE = preload("res://survivor_surface.gdshader")
var game: Node3D
var weapon: Node3D
var muzzle: Node3D
var flash: Node3D
var flash_light: OmniLight3D
var cooldown := 0.0
var aim_remaining := 0.0
var flash_remaining := 0.0
var last_impact := Vector3.ZERO
var last_hit: Node3D
var _tracers: Array[Dictionary] = []
var _mounted_character: Node3D
var _shot_yaw := 0.0
var _shot_pitch := 0.0

func _ready() -> void:
	# The character animates first; a short firing pose is applied afterward.
	process_physics_priority = 100

func refresh_loadout() -> void:
	if is_instance_valid(weapon):
		weapon.get_parent().remove_child(weapon)
		weapon.queue_free()
	weapon = null
	muzzle = null
	flash = null
	flash_light = null
	_mounted_character = null
	aim_remaining = 0.0
	flash_remaining = 0.0
	if not is_instance_valid(game) or game.profile == null or game.profile.equipped != "repulsor" or not game.profile.owned.has("repulsor"):
		return
	var character: Node3D = game.player.character
	if not is_instance_valid(character) or character.elbows.size() < 2:
		return
	var hand := character.elbows[1].get_node_or_null("Hand") as Node3D
	if hand == null:
		return
	_mounted_character = character
	weapon = Node3D.new()
	weapon.name = "SalvageRepulsor"
	hand.add_child(weapon)
	weapon.position = Vector3(0,-.043,-.002)
	weapon.rotation.x = -PI/2.0
	_build_weapon()

func reset_round() -> void:
	cooldown = 0.0
	aim_remaining = 0.0
	flash_remaining = 0.0
	last_hit = null
	for item in _tracers:
		if is_instance_valid(item.node): item.node.queue_free()
	_tracers.clear()
	refresh_loadout()

func tick(delta: float) -> void:
	if not is_instance_valid(game) or not game.active:
		return
	cooldown = maxf(0.0,cooldown-delta)
	aim_remaining = maxf(0.0,aim_remaining-delta)
	flash_remaining = maxf(0.0,flash_remaining-delta)
	if is_instance_valid(flash): flash.visible = flash_remaining > 0.0
	if is_instance_valid(flash_light): flash_light.visible = flash_remaining > 0.0
	for index in range(_tracers.size()-1,-1,-1):
		_tracers[index].remaining -= delta
		if _tracers[index].remaining <= 0:
			if is_instance_valid(_tracers[index].node): _tracers[index].node.queue_free()
			_tracers.remove_at(index)

func _physics_process(_delta: float) -> void:
	if is_instance_valid(game) and game.active and aim_remaining > 0 and is_instance_valid(weapon):
		_apply_firing_pose()

func _apply_firing_pose() -> void:
	var character: Node3D = game.player.character
	if character != _mounted_character: return
	game.player.get_node("Body").rotation.y = _shot_yaw
	var recoil := clampf((cooldown-(SHOT_INTERVAL-.16))/.16,0,1)
	var weight := smoothstep(0.0,.15,aim_remaining)
	character.arms[1].rotation = character.arms[1].rotation.lerp(Vector3(1.19+_shot_pitch+recoil*.1,-.025,.02),weight)
	character.elbows[1].rotation = character.elbows[1].rotation.lerp(Vector3(.38,0,0),weight)
	var hand: Node3D = character.elbows[1].get_node("Hand")
	hand.rotation = hand.rotation.lerp(Vector3.ZERO,weight)

func fire(target: Vector3 = Vector3.INF) -> bool:
	if not is_instance_valid(game) or not game.active or game.round_over or game.profile == null:
		return false
	if game.profile.equipped != "repulsor" or not game.profile.owned.has("repulsor"):
		_feedback("尚未装备枪械：完成撤离后可在营地军械铺购买。")
		return false
	if cooldown > 0.0:
		return false
	if game.round_ammo <= 0:
		_feedback("驱狼枪弹药已耗尽，撤离后可补充弹药。")
		return false
	if not is_instance_valid(weapon) or _mounted_character != game.player.character:
		refresh_loadout()
	game.round_ammo -= 1
	cooldown = SHOT_INTERVAL
	aim_remaining = .68
	flash_remaining = .08
	var origin: Vector3 = game.player.global_position+Vector3(0,1.1,0)
	var direction := Vector3.FORWARD.rotated(Vector3.UP,game.player.camera_yaw)
	if target==Vector3.INF and game.has_method("weapon_target"): target=game.weapon_target()
	var precise := target.is_finite() and origin.distance_squared_to(target)>.0001
	if precise: direction=(target-origin).normalized()
	_shot_yaw=atan2(-direction.x,-direction.z)
	_shot_pitch=asin(clampf(direction.y,-1,1))
	_apply_firing_pose()
	var endpoint := origin+direction*RANGE
	var hit := _ray(origin,endpoint)
	# A wall along the firing line always stops the shot. A narrow assist cone
	# only helps when the direct line is unobstructed and the candidate is visible.
	if hit.is_empty() and not precise:
		var assist := _assisted_target(origin,direction)
		if is_instance_valid(assist):
			hit = _ray(origin,assist.global_position+Vector3(0,1.0,0))
	last_hit = null
	last_impact = endpoint if hit.is_empty() else hit.position
	if not hit.is_empty():
		var collider = hit.get("collider")
		if is_instance_valid(collider) and collider.has_method("apply_projectile_hit"):
			last_hit = collider
			collider.apply_projectile_hit(game.player.global_position)
			_scatter_pack(collider,game.player.global_position)
			_feedback("命中狼兽：打断扑咬并击退，附近狼群开始退避。")
	if is_instance_valid(flash): flash.visible = true
	if is_instance_valid(flash_light): flash_light.visible = true
	var visual_origin: Vector3 = muzzle.global_position if is_instance_valid(muzzle) else origin
	_spawn_tracer(visual_origin,last_impact)
	return true

func _ray(start: Vector3,finish: Vector3) -> Dictionary:
	var excluded: Array[RID] = [game.player.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(start,finish,1|4,excluded)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _assisted_target(origin: Vector3,direction: Vector3) -> Node3D:
	var target: Node3D
	var best_angle := AIM_ASSIST
	for mutant in game.mutants:
		if not is_instance_valid(mutant): continue
		var offset: Vector3 = mutant.global_position+Vector3(0,1,0)-origin
		if offset.length() > RANGE or offset.length_squared() < .01: continue
		var angle := direction.angle_to(offset)
		if angle >= best_angle: continue
		var sight := _ray(origin,origin+offset)
		if not sight.is_empty() and sight.get("collider") == mutant:
			target = mutant
			best_angle = angle
	return target

func _scatter_pack(struck: Node3D,source: Vector3) -> void:
	for mutant in game.mutants:
		if not is_instance_valid(mutant) or mutant == struck or mutant.global_position.distance_to(struck.global_position) > 5.0: continue
		if not mutant.has_method("apply_projectile_fear"): continue
		var query := PhysicsRayQueryParameters3D.create(struck.global_position+Vector3(0,1.1,0),mutant.global_position+Vector3(0,1.1,0),1,[game.player.get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			mutant.apply_projectile_fear(source,4.0)

func _feedback(message: String) -> void:
	if game.has_method("_show_toast"): game._show_toast(message,3.0)

func _material(color: String,metal: float,wear: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("base_color",Color(color))
	mat.set_shader_parameter("roughness_value",.74 if metal < .5 else .48)
	mat.set_shader_parameter("metal_value",metal)
	mat.set_shader_parameter("wear",wear)
	return mat

func _box(label: String,pos: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	var mesh := Equipment.beveled_box(size,minf(size.x,minf(size.y,size.z))*.18)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	weapon.add_child(node)
	return node

func _rod(label: String,a: Vector3,b: Vector3,radius: float,mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.position = (a+b)*.5
	var axis := (b-a).normalized()
	var across := axis.cross(Vector3.RIGHT if absf(axis.x) < .9 else Vector3.FORWARD).normalized()
	node.basis = Basis(across,axis,across.cross(axis))
	weapon.add_child(node)
	return node

func _build_weapon() -> void:
	var steel := _material("45504e",.82,.42)
	var worn := _material("929185",.68,.38)
	var rust := _material("875338",.46,.55)
	var wood := _material("533d2d",.05,.48)
	var leather := _material("292e29",.02,.27)
	var dark := _material("111819",.2,.2)
	_shell("ForgedReceiver",[Vector4(-.19,.029,.033,.078),Vector4(-.16,.038,.05,.075),Vector4(-.03,.038,.05,.075),Vector4(.04,.029,.037,.07)],steel)
	_box("ReceiverCover",Vector3(0,.128,-.054),Vector3(.059,.012,.18),worn)
	_shell("CarvedWoodenStock",[Vector4(.01,.024,.032,.07),Vector4(.075,.022,.028,.061),Vector4(.14,.032,.039,.04),Vector4(.244,.035,.059,.028),Vector4(.255,.033,.054,.028)],wood)
	_box("StockButt",Vector3(0,.044,.253),Vector3(.067,.107,.018),leather)
	var grip := _box("ContouredGrip",Vector3(0,-.018,.004),Vector3(.048,.134,.055),wood)
	grip.rotation.x=-.18
	for i in 5:
		_box("GripWrap",Vector3(0,-.06+i*.021,.010-i*.003),Vector3(.053,.007,.06),leather)
	_box("TriggerGuardBase",Vector3(0,-.048,-.057),Vector3(.012,.008,.069),steel)
	_box("TriggerGuardFront",Vector3(0,-.017,-.09),Vector3(.012,.067,.009),steel)
	_box("Trigger",Vector3(0,.009,-.053),Vector3(.010,.029,.008),worn).rotation.x = -.2
	_rod("HeavyBarrel",Vector3(0,.096,-.16),Vector3(0,.096,-.46),.026,steel)
	_rod("PumpTube",Vector3(0,.037,-.16),Vector3(0,.037,-.34),.019,dark)
	_shell("CarvedPump",[Vector4(-.338,.025,.020,.04),Vector4(-.32,.035,.031,.04),Vector4(-.22,.035,.031,.04),Vector4(-.196,.026,.023,.04)],wood)
	for i in 6:
		_box("PumpRib",Vector3(0,.040,-.213-i*.019),Vector3(.074,.064,.006),leather)
	for z in [-.174,-.378]:
		_rod("RustBarrelBand",Vector3(0,.096,z-.01),Vector3(0,.096,z+.01),.029,rust)
	_rod("MuzzleRing",Vector3(0,.096,-.456),Vector3(0,.096,-.47),.029,worn)
	_rod("DarkBore",Vector3(0,.096,-.4705),Vector3(0,.096,-.471),.019,dark)
	_box("FrontSight",Vector3(0,.132,-.433),Vector3(.011,.032,.018),worn)
	_box("RearSight",Vector3(0,.148,-.021),Vector3(.052,.019,.014),dark)
	for side in [-1.0,1.0]:
		_box("SidePlate",Vector3(side*.037,.078,-.051),Vector3(.004,.046,.097),rust)
		for z in [-.016,-.09]:
			_rod("ReceiverBolt",Vector3(side*.038,.087,z),Vector3(side*.042,.087,z),.006,worn)
		for i in 4:
			_box("MetalWear",Vector3(side*.040,.052+i*.012,-.044-i*.007),Vector3(.002,.0015,.045),worn).rotation.x = -.1
	_rod("ChargingHandle",Vector3(.029,.084,-.08),Vector3(.067,.084,-.08),.006,steel)
	_rod("HandleCap",Vector3(.062,.07,-.08),Vector3(.062,.098,-.08),.009,leather)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("f6b45b")
	glow.emission_enabled = true
	glow.emission = Color("ffae46")
	glow.emission_energy_multiplier = 2.2
	_box("ChargeIndicator",Vector3(.042,.073,-.031),Vector3(.004,.014,.025),glow)
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0,.096,-.49)
	weapon.add_child(muzzle)
	flash = Node3D.new()
	flash.name = "MuzzleFlash"
	muzzle.add_child(flash)
	for i in 3:
		var a := float(i)*TAU/3
		var points: Array[Vector3]=[Vector3.ZERO,Vector3(cos(a)*.045,sin(a)*.045,-.09),Vector3(cos(a+.3)*.025,sin(a+.3)*.025,-.23)]
		Effects.mesh_node(flash,"MuzzleCombustion%d"%i,Effects.ribbon(points,.065),Effects.material(Color("ffd199"),4,2.3))
	flash.visible = false
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color("ffb66f")
	flash_light.light_energy = 2.2
	flash_light.omni_range = 2.4
	muzzle.add_child(flash_light)
	flash_light.visible = false

func _spawn_tracer(start: Vector3,finish: Vector3) -> void:
	var length := start.distance_to(finish)
	if length < .02: return
	var mesh := CylinderMesh.new()
	mesh.top_radius = .008
	mesh.bottom_radius = .008
	mesh.height = length
	mesh.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("f9d6a0")
	mat.emission_enabled = true
	mat.emission = Color("efbf78")
	mat.emission_energy_multiplier = 2.0
	var tracer := MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.material_override = mat
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer)
	tracer.global_position = (start+finish)*.5
	var axis := (finish-start).normalized()
	var across := axis.cross(Vector3.UP if absf(axis.y) < .9 else Vector3.RIGHT).normalized()
	tracer.global_basis = Basis(across,axis,across.cross(axis))
	_tracers.append({"node":tracer,"remaining":.065})

func _shell(label: String,profile: Array[Vector4],mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name=label
	node.mesh=Equipment.formed_shell(profile)
	node.material_override=mat
	weapon.add_child(node)
	return node
