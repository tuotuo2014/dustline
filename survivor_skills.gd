extends Node3D
## All timers and effects advance from the active game tick, never during menus.
const Catalog = preload("res://character_catalog.gd")
const Effects = preload("res://model_effects.gd")
const Equipment = preload("res://equipment_geometry.gd")
var game: Node3D
var cooldowns := [0.0,0.0,0.0,0.0]
var active_id := -1
var active_remaining := 0.0
var scan_markers: Array[Dictionary]=[]
var effects: Array[Node3D]=[]
var drone: Node3D
var beam: MeshInstance3D
var _clock := 0.0
var _trail_clock := 0.0

func reset_round() -> void:
	cancel_active()
	cooldowns=[0.0,0.0,0.0,0.0]
	_clock=0

func cancel_active() -> void:
	active_id=-1
	active_remaining=0
	for marker in scan_markers:
		if is_instance_valid(marker.node): marker.node.queue_free()
	scan_markers.clear()
	for effect in effects:
		if is_instance_valid(effect): effect.queue_free()
	effects.clear()
	if is_instance_valid(drone): drone.queue_free()
	if is_instance_valid(beam): beam.queue_free()
	drone=null
	beam=null
	if is_instance_valid(game) and is_instance_valid(game.player): game.player.cancel_dash()

func activate() -> bool:
	if not game.active: return false
	var id: int=game.player.character_id
	var info := Catalog.skill(id)
	if cooldowns[id]>0.0:
		game._show_toast("%s还需 %d 秒恢复"%[info.name,ceili(cooldowns[id])],2.0)
		return false
	if id==2 and not game.actor_grounded(game.player):
		game._show_toast("落地后按 C 使用疾影突进。",2.0)
		return false
	cancel_active()
	if id==2 and not game.player.begin_dash(): return false
	active_id=id
	active_remaining=info.duration
	cooldowns[id]=info.cooldown * (game.coop.cooldown_for_actor() if is_instance_valid(game.coop) and game.coop.in_round else game.profile.cooldown_multiplier(id))
	var origin: Vector3=game.player.global_position
	match id:
		0:
			_scan()
			_pulse(origin,Catalog.skill(0).accent,24.0,1.0)
			game._show_toast("拾荒直觉：已标记 %d 处物资 / 信标，持续 10 秒。"%scan_markers.size(),4.0)
		1:
			game.player.play_shock_action()
			var struck := 0
			for mutant in game.mutants:
				var offset: Vector3=mutant.global_position-origin
				if Vector2(offset.x,offset.z).length()>12.0 or absf(offset.y)>3.0: continue
				var query := PhysicsRayQueryParameters3D.create(origin+Vector3(0,1.1,0),mutant.global_position+Vector3(0,1.1,0),1,[game.player.get_rid()])
				if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
				mutant.apply_shock(origin)
				struck+=1
			_pulse(origin,Catalog.skill(1).accent,12.0,.65)
			game._show_toast("磁能震荡：击退 %d 只狼兽，打断攻击并眩晕 3 秒。"%struck,4.0)
		2:
			_trail_clock=0
			game._show_toast("疾影突进  ·  突进期间躲避扑咬",2.0)
		3:
			_make_drone()
			game._show_toast("维修无人机上线  ·  每秒恢复 3 点生命，持续 12 秒",4.0)
	game._update_hud()
	return true

func tick(delta: float) -> void:
	_clock+=delta
	for i in 4: cooldowns[i]=maxf(0.0,cooldowns[i]-delta)
	for effect in effects.duplicate():
		if not is_instance_valid(effect):
			effects.erase(effect)
			continue
		var life: float=effect.get_meta("life")-delta
		effect.set_meta("life",life)
		if life<=0:
			effects.erase(effect)
			effect.queue_free()
			continue
		var t := 1.0-life/float(effect.get_meta("duration"))
		if effect.has_meta("radius"):
			var radius := lerpf(.5,float(effect.get_meta("radius")),t)
			effect.scale=Vector3(radius,1,radius)
		Effects.tick(effect,float(effect.get_meta("duration"))-life,1.0-t)
	if active_remaining<=0: return
	var step := minf(delta,active_remaining)
	active_remaining=maxf(0.0,active_remaining-delta)
	match active_id:
		0:
			for marker in scan_markers.duplicate():
				if not is_instance_valid(marker.target) or marker.target.get_meta("taken",false) or marker.target.get_meta("active",false):
					marker.node.queue_free()
					scan_markers.erase(marker)
					continue
				var distance: float=game.player.global_position.distance_to(marker.target.global_position)
				marker.label.text="%s · %dm"%[marker.title,roundi(distance)]
				Effects.tick(marker.node,_clock,.75+.25*sin(_clock*2.0))
		2:
			_trail_clock-=delta
			if _trail_clock<=0:
				_trail_clock=.055
				_trail(game.player.global_position,game.player.get_node("Body").rotation.y)
		3:
			if is_instance_valid(game.coop) and game.coop.in_round:
				game.coop.team.heal_nearby(game.coop.context_peer if game.coop.context_peer>0 else game.coop.local_id(),3.0*step)
			else:
				game.health=minf(game.max_health,game.health+3.0*step)
			if is_instance_valid(drone):
				var target: Vector3=game.player.global_position+game.player.get_node("Body").global_basis*Vector3(.76,0,.20)+Vector3(0,1.78+sin(_clock*3.2)*.06,0)
				drone.global_position=drone.global_position.lerp(target,1.0-exp(-delta*8.0))
				drone.rotation.y=lerp_angle(drone.rotation.y,game.player.get_node("Body").rotation.y,1.0-exp(-delta*4.0))
				for rotor in drone.find_children("Rotor*","Node3D",true,false): rotor.rotation.y+=delta*35
				var chest: Vector3=game.player.global_position+Vector3(0,1.12,0)
				var vector := chest-drone.global_position
				beam.global_position=drone.global_position+vector*.5
				beam.basis=Basis(Quaternion(Vector3.UP,vector.normalized()))
				beam.scale=Vector3(1,vector.length(),1)
				beam.material_override.set_shader_parameter("phase",_clock)
	if active_remaining<=0:
		active_id=-1
		for marker in scan_markers: marker.node.queue_free()
		scan_markers.clear()
		if is_instance_valid(drone): drone.queue_free()
		if is_instance_valid(beam): beam.queue_free()
		drone=null
		beam=null

func status(id: int) -> Dictionary:
	var info := Catalog.skill(id)
	var time: float=cooldowns[id]
	var active_text := "生效中 %.1f 秒"%active_remaining if active_id==id and active_remaining>0 else ""
	return {"name":info.name,"description":info.description,"cooldown":time,"maximum":info.cooldown * game.profile.cooldown_multiplier(id),"ready":time<=0.0,"state":active_text if not active_text.is_empty() else ("冷却 %d 秒"%ceili(time) if time>0 else "技能就绪"),"accent":info.accent}

func _scan() -> void:
	var candidates: Array[Node3D]=[]
	for item in game.pickups:
		if is_instance_valid(item) and not item.get_meta("taken",false) and item.global_position.distance_to(game.player.global_position)<=65:
			candidates.append(item)
	for relay in game.relays:
		if not relay.get_meta("active",false) and relay.global_position.distance_to(game.player.global_position)<=65:
			candidates.append(relay)
	candidates.sort_custom(func(a: Node3D,b: Node3D) -> bool: return a.global_position.distance_squared_to(game.player.global_position)<b.global_position.distance_squared_to(game.player.global_position))
	for item in candidates.slice(0,16):
		var marker := Node3D.new()
		marker.name="SalvageSensorMarker"
		marker.position=item.global_position+Vector3(0,1.8,0)
		add_child(marker)
		var title := "信标" if item in game.relays else ("医疗包" if item.get_meta("kind","")=="medkit" else "零件")
		if item.has_meta("display_name"): title=str(item.get_meta("display_name"))
		var label := Label3D.new()
		label.font=load("res://assets/fonts/NotoSansSC.ttf")
		label.text=title
		label.font_size=32
		label.pixel_size=.00062
		label.fixed_size=true
		label.no_depth_test=true
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate=Catalog.skill(0).accent
		label.outline_size=3
		marker.add_child(label)
		var locator := Effects.mesh_node(marker,"SurveyProjection",Effects.band(.36,.045,-1.63,32),Effects.material(Catalog.skill(0).accent,2,.9))
		locator.visibility_range_end=70

		scan_markers.append({"target":item,"node":marker,"label":label,"title":title})

func _effect_mat(color: Color,alpha := .8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color(color,alpha)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled=true
	mat.emission=color
	mat.emission_energy_multiplier=1.4
	return mat

func _pulse(origin: Vector3,color: Color,radius: float,duration: float) -> void:
	var root := Effects.wave(color)
	root.name="SkillShockwave"
	root.position=origin+Vector3(0,.14,0)
	root.set_meta("life",duration)
	root.set_meta("duration",duration)
	root.set_meta("radius",radius)
	add_child(root)
	effects.append(root)

func _trail(origin: Vector3,yaw: float) -> void:
	var root := Effects.dash(Catalog.skill(2).accent)
	root.name="DashIonTrail"
	root.position=origin+Vector3(0,.90,0)
	root.rotation.y=yaw
	root.set_meta("life",.34)
	root.set_meta("duration",.34)
	add_child(root)
	effects.append(root)

func _make_drone() -> void:
	drone=Node3D.new()
	drone.name="RepairCompanion"
	add_child(drone)
	drone.position=game.player.global_position+Vector3(.75,1.78,.2)
	var teal := _solid(Color("486c63"),.68,.52)
	var metal := _solid(Color("606b68"),.54,.48)
	var dark := _solid(Color("252b29"),.72,.15)
	var brass := _solid(Color("b59b5a"),.62,.44)
	var eye := _solid(Color("b3eac6"),.15,.0)
	eye.emission_enabled=true
	eye.emission=Color("69dba5")
	eye.emission_energy_multiplier=2.0
	var hull := MeshInstance3D.new()
	hull.name="PressedDroneShell"
	hull.mesh=Equipment.formed_shell([Vector4(-.145,.16,.09,0),Vector4(-.11,.20,.13,0),Vector4(.10,.20,.12,0),Vector4(.145,.14,.085,0)],20)
	hull.material_override=teal
	drone.add_child(hull)
	_box(drone,"Undercarriage",Vector3(0,-.16,.02),Vector3(.26,.07,.19),dark)
	_box(drone,"FacePanel",Vector3(0,0,-.153),Vector3(.35,.20,.021),metal)
	for side in [-1.0,1.0]:
		_sphere(drone,"LensBezel",Vector3(side*.095,.025,-.174),Vector3(.093,.093,.035),brass)
		_sphere(drone,"OpticalEye",Vector3(side*.095,.025,-.195),Vector3(.059,.059,.018),eye)
		for z in [-.20,.20]:
			_box(drone,"MotorArm",Vector3(side*.25,0,z*.68),Vector3(.18,.024,.038),metal)
			var rotor := Node3D.new()
			rotor.name="Rotor_%d_%d"%[int(side),roundi(z*10)]
			rotor.position=Vector3(side*.34,.025,z)
			drone.add_child(rotor)
			_box(rotor,"PropellerBlade",Vector3.ZERO,Vector3(.24,.009,.034),dark)
			_box(rotor,"CrossBlade",Vector3.ZERO,Vector3(.034,.010,.24),dark)
			var guard := MeshInstance3D.new()
			guard.name="PropellerGuard"
			var ring := TorusMesh.new()
			ring.inner_radius=.127
			ring.outer_radius=.139
			ring.rings=32
			ring.ring_segments=6
			guard.mesh=ring
			guard.position=rotor.position
			guard.material_override=metal
			drone.add_child(guard)
			_sphere(rotor,"MotorCap",Vector3(0,-.010,0),Vector3(.05,.07,.05),metal)
		for y in [-.06,.09]:
			_sphere(drone,"PanelRivet",Vector3(side*.165,y,-.17),Vector3(.017,.017,.010),brass)
	for i in 4: _box(drone,"CoolingGrille",Vector3(-.065+i*.043,-.06,-.17),Vector3(.026,.009,.008),dark)
	_box(drone,"Antenna",Vector3(.10,.20,.035),Vector3(.009,.17,.009),metal)
	_sphere(drone,"StatusLight",Vector3(.10,.29,.035),Vector3(.03,.03,.03),eye)
	var light := OmniLight3D.new()
	light.light_color=Color("72d3a9")
	light.light_energy=.45
	light.omni_range=2.5
	drone.add_child(light)
	beam=MeshInstance3D.new()
	beam.name="RestorationBeam"
	var line := CylinderMesh.new()
	line.height=1
	line.top_radius=.008
	line.bottom_radius=.048
	line.radial_segments=12
	beam.mesh=line
	beam.material_override=Effects.material(Catalog.skill(3).accent,3,.9)
	beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)

func _solid(color: Color,rough: float,metal: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=rough
	mat.metallic=metal
	return mat

func _box(parent: Node3D,label: String,pos: Vector3,size: Vector3,mat: Material) -> void:
	var mesh := Equipment.beveled_box(size,minf(size.x,minf(size.y,size.z))*.16)
	var node := MeshInstance3D.new()
	node.name=label
	node.position=pos
	node.mesh=mesh
	node.material_override=mat
	parent.add_child(node)

func _sphere(parent: Node3D,label: String,pos: Vector3,size: Vector3,mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.height=1
	mesh.radius=.5
	mesh.radial_segments=24
	mesh.rings=12
	var node := MeshInstance3D.new()
	node.name=label
	node.position=pos
	node.scale=size
	node.mesh=mesh
	node.material_override=mat
	parent.add_child(node)
