extends CharacterBody3D
## Kinematic wilderness predator. All time advances through tick, so menus pause it.
signal attack_landed(damage: float)
const Wolf = preload("res://mutant_wolf.gd")
const Layout = preload("res://world_layout.gd")
var playable_extent := Layout.EXTENT
var visual: Node3D
var patrol_seed := 130
var home := Vector3.ZERO
var patrol_goal := Vector3.ZERO
var fear_source := Vector3.ZERO
var state := "patrol"
var state_time := 0.0
var cooldown := 0.0
var lost_sight := 0.0
var patrol_time := 0.0
var rng := RandomNumberGenerator.new()
var _attack_done := false
var _avoid_side := 1.0
var threat_marker: Label3D
var stun_remaining := 0.0
var _shock_velocity := Vector3.ZERO
var projectile_fear_remaining := 0.0
var projectile_fear_source := Vector3.ZERO

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	floor_snap_length = .5
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .62
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = .9
	add_child(collision)
	visual = Wolf.new()
	visual.name = "MutantWolf"
	add_child(visual)
	threat_marker = Label3D.new()
	threat_marker.position.y = 2.7
	threat_marker.font_size = 56
	threat_marker.pixel_size = .007
	threat_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	threat_marker.no_depth_test = false
	threat_marker.outline_size = 10
	threat_marker.visible = false
	add_child(threat_marker)
	home = global_position
	rng.seed = patrol_seed
	_avoid_side = -1.0 if patrol_seed % 2 == 0 else 1.0
	_choose_patrol()

func _choose_patrol() -> void:
	var angle := rng.randf_range(0, TAU)
	var distance := rng.randf_range(4, 9)
	patrol_goal = home + Vector3(cos(angle)*distance,0,sin(angle)*distance)
	patrol_goal.x = clampf(patrol_goal.x,-playable_extent+6.0,playable_extent-6.0)
	patrol_goal.z = clampf(patrol_goal.z,-playable_extent+6.0,playable_extent-6.0)
	patrol_time = rng.randf_range(5.0,9.0)

func _set_state(next: String) -> void:
	if state == next:
		return
	state = next
	state_time = 0.0
	_attack_done = false
	if state == "windup":
		velocity.x = 0.0
		velocity.z = 0.0
	threat_marker.visible = state in ["chase","windup","lunge"]
	threat_marker.text = "!!" if state in ["windup","lunge"] else "!"
	threat_marker.modulate = Color("f78358") if state in ["windup","lunge"] else Color("f1ce74")
	visual.set_alert(state in ["chase","windup","lunge"])

func tick(delta: float, target: CharacterBody3D, target_safe: bool, scared: bool) -> void:
	state_time += delta
	if stun_remaining>0.0:
		stun_remaining=maxf(0.0,stun_remaining-delta)
		velocity.x=_shock_velocity.x
		velocity.z=_shock_velocity.z
		velocity.y=-.5 if is_on_floor() else velocity.y-22.0*delta
		move_and_slide()
		global_position.x=clampf(global_position.x,-playable_extent+2,playable_extent-2)
		global_position.z=clampf(global_position.z,-playable_extent+2,playable_extent-2)
		_shock_velocity=_shock_velocity.move_toward(Vector3.ZERO,delta*18.0)
		visual.animate(delta,0.0,false)
		if stun_remaining<=0.0:
			cooldown=maxf(cooldown,1.2)
			_set_state("patrol")
		return
	projectile_fear_remaining = maxf(0.0,projectile_fear_remaining-delta)
	cooldown = maxf(0.0,cooldown-delta)
	patrol_time -= delta
	var offset := target.global_position - global_position
	offset.y = 0
	var distance := offset.length()
	var in_sight := distance < 32.0 and _can_see(target)
	lost_sight = 0.0 if in_sight else lost_sight + delta
	var desired := Vector3.ZERO
	var movement_speed := 0.0
	if scared or projectile_fear_remaining > 0.0:
		_set_state("flee")
		var source := fear_source if scared else projectile_fear_source
		var away := global_position - source
		away.y = 0
		if away.length_squared() < .01:
			away = Vector3.RIGHT
		desired = away.normalized()
		movement_speed = 6.2
	elif target_safe:
		_set_state("patrol")
		if distance < 8.0:
			desired = -offset.normalized()
			movement_speed = 2.6
		else:
			desired = _patrol_direction()
			movement_speed = 1.3
	else:
		if state == "flee":
			_set_state("patrol")
		if state == "patrol" and in_sight and distance < (30.0 if target.velocity.length() > 5.0 else 24.0):
			_set_state("chase")
		if state in ["chase","windup","lunge"] and (distance > 44.0 or lost_sight > 4.0):
			_set_state("patrol")
		match state:
			"patrol":
				desired = _patrol_direction()
				movement_speed = 1.3
			"chase":
				desired = offset.normalized()
				movement_speed = 4.9 if distance > 3.5 else 0.0
				if distance < 3.6 and cooldown <= 0 and in_sight:
					_set_state("windup")
			"windup":
				desired = offset.normalized()
				movement_speed = 0.0
				if state_time >= .75:
					_set_state("lunge")
			"lunge":
				desired = -global_basis.z
				movement_speed = 6.7 if state_time < .3 else 0.0
				if distance < 2.4:
					movement_speed = 0.0
					velocity.x = 0.0
					velocity.z = 0.0
				if state_time >= .18 and state_time <= .48 and not _attack_done:
					if distance < 3.4 and absf(target.global_position.y-global_position.y) < 1.5 and desired.dot(offset.normalized()) > .45 and _can_see(target):
						_attack_done = true
						attack_landed.emit(18.0)
				if state_time >= .65:
					cooldown = 2.0
					_set_state("chase")
	if movement_speed > 0:
		desired = _steer(desired)
	if desired.length_squared() > .001 and state != "lunge":
		rotation.y = lerp_angle(rotation.y,atan2(-desired.x,-desired.z),1.0-exp(-delta*5.0))
	velocity.x = move_toward(velocity.x,desired.x*movement_speed,delta*12.0)
	velocity.z = move_toward(velocity.z,desired.z*movement_speed,delta*12.0)
	velocity.y = -.5 if is_on_floor() else velocity.y-22.0*delta
	var before := global_position
	move_and_slide()
	global_position.x = clampf(global_position.x,-playable_extent+2.0,playable_extent-2.0)
	global_position.z = clampf(global_position.z,-playable_extent+2.0,playable_extent-2.0)
	var traveled := Vector2(global_position.x-before.x,global_position.z-before.z).length()/maxf(delta,.00001)
	visual.animate(delta,traveled,state in ["windup","lunge"])

func _patrol_direction() -> Vector3:
	var offset := patrol_goal-global_position
	offset.y = 0
	if offset.length() < 1.4 or patrol_time <= 0:
		_choose_patrol()
		return Vector3.ZERO
	return offset.normalized()

func _can_see(target: CharacterBody3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3(0,1.4,0),target.global_position+Vector3(0,1.1,0),1,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func _steer(direction: Vector3) -> Vector3:
	if direction.length_squared() < .01:
		return direction
	if _path_clear(direction):
		return direction
	for angle in [.65,1.05,1.5,2.1]:
		for side in [_avoid_side,-_avoid_side]:
			var alternative := direction.rotated(Vector3.UP,angle*side)
			if _path_clear(alternative):
				_avoid_side = side
				return alternative
	return Vector3.ZERO

func _path_clear(direction: Vector3) -> bool:
	var origin := global_position + Vector3(0,.75,0)
	var side := direction.cross(Vector3.UP)*.55
	for lateral in [-1.0,0.0,1.0]:
		var start: Vector3 = origin+side*lateral
		var query := PhysicsRayQueryParameters3D.create(start,start+direction*3.0,1|4,[get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		# The player is approached deliberately; walls and other creatures are avoided.
		if not hit.is_empty() and hit.get("collider").name != "Player":
			return false
	return true

func apply_shock(origin: Vector3) -> void:
	var away := global_position-origin
	away.y=0
	if away.length_squared()<.001: away=Vector3.RIGHT
	_shock_velocity=away.normalized()*7.4
	stun_remaining=3.0
	_set_state("stunned")
	_attack_done=true
	threat_marker.visible=true
	threat_marker.text="···"
	threat_marker.modulate=Color("94d9ed")
	visual.set_alert(false)

func apply_projectile_hit(origin: Vector3) -> void:
	var away := global_position-origin
	away.y = 0
	if away.length_squared() < .001: away = Vector3.RIGHT
	_shock_velocity = away.normalized()*9.0
	# Preserve a longer stun from the character's shock skill.
	stun_remaining = maxf(stun_remaining,1.0)
	apply_projectile_fear(origin,5.0)
	_set_state("stunned")
	_attack_done = true
	threat_marker.visible = true
	threat_marker.text = "↯"
	threat_marker.modulate = Color("ffd092")
	visual.set_alert(false)

func apply_projectile_fear(origin: Vector3,duration: float = 4.0) -> void:
	projectile_fear_source = origin
	projectile_fear_remaining = maxf(projectile_fear_remaining,duration)
	cooldown = maxf(cooldown,1.2)
	_set_state("flee")
	_attack_done = true
	visual.set_alert(false)
