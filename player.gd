extends CharacterBody3D

const Survivor = preload("res://reference_survivor.gd")
const Layout = preload("res://world_layout.gd")
var playable_extent := Layout.EXTENT
const CharacterCatalog = preload("res://character_catalog.gd")
const RosterSurvivor = preload("res://wasteland_roster_survivor.gd")

@export var speed := 1.8
@export var sprint_speed := 7.8
@export var jump_velocity := 7.4
@export var acceleration := 18.0
@export var gravity := 22.0
var collected := 0
var character: Node3D
var character_id := 0
var camera_yaw := 0.0
var camera_pitch := -0.11
var camera_distance := 5.5
var rotating_camera := false
var scope_enabled := false
var _scope_saved_fov := 60.0
var _scope_saved_mouse := Input.MOUSE_MODE_VISIBLE
var _scope_saved_cursor := Vector2.ZERO
var _camera_drag_buttons := 0
var _mouse_position_before_drag := Vector2.ZERO
var _mouse_mode_before_drag := Input.MOUSE_MODE_VISIBLE
var _jump_buffer_remaining := 0.0
var _coyote_remaining := 0.0
var controls_enabled := true
var _previous_motion := Vector3.ZERO
var dash_remaining := 0.0
var _shock_pose_remaining := 0.0
var _dash_direction := Vector3.FORWARD

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	_jump_buffer_remaining = 0.0
	if not enabled:
		set_scope(false)
		_end_camera_drag()

func reset_for_round(spawn: Vector3) -> void:
	set_scope(false)
	_end_camera_drag()
	dash_remaining = 0.0
	global_position = spawn
	velocity = Vector3.ZERO
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	camera_yaw = 0.0
	camera_pitch = -0.11
	camera_distance = 5.5
	$Body.rotation = Vector3.ZERO
	_previous_motion = Vector3.ZERO
	if is_instance_valid(character):
		character.reset_motion()

func select_character(id: int) -> void:
	var next_id := clampi(id, 0, 3)
	if next_id == character_id and is_instance_valid(character):
		return
	cancel_dash()
	var old_position := character.position if is_instance_valid(character) else Vector3.ZERO
	var old_rotation := character.rotation if is_instance_valid(character) else Vector3.ZERO
	if is_instance_valid(character):
		$Body.remove_child(character)
		character.queue_free()
	character = null
	if next_id == 0:
		character = Survivor.new()
	else:
		character = RosterSurvivor.new()
		character.archetype = next_id
	character.name = "Survivor_%d" % next_id
	character_id = next_id
	$Body.add_child(character)
	character.position = old_position
	character.rotation = old_rotation
	character.reset_motion()

func character_info() -> Dictionary:
	return CharacterCatalog.get_info(character_id)

func _ready() -> void:
	floor_snap_length = .28
	character = Survivor.new()
	character.name = "Survivor"
	$Body.add_child(character)

func _input(event: InputEvent) -> void:
	if scope_enabled and controls_enabled and event is InputEventMouseMotion:
		camera_yaw=wrapf(camera_yaw-event.screen_relative.x*.0015,-PI,PI)
		# The scope camera uses -camera_pitch: positive screen Y must look down.
		camera_pitch=clampf(camera_pitch+event.screen_relative.y*.001,-1.15,1.15)
		_update_camera()
		get_viewport().set_input_as_handled()
		return
	if not rotating_camera:
		return
	# Finish the drag even if a GUI control would consume the release event.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var button_mask: int = 1 << (event.button_index - 1)
		if event.pressed:
			_camera_drag_buttons |= button_mask
		else:
			_camera_drag_buttons &= ~button_mask
			if _camera_drag_buttons == 0:
				_end_camera_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		# Screen pixels keep sensitivity consistent when the game window is resized.
		camera_yaw = wrapf(camera_yaw - event.screen_relative.x * 0.006, -PI, PI)
		camera_pitch = clampf(camera_pitch - event.screen_relative.y * 0.004, -1.15, 0.2)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_end_camera_drag()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if scope_enabled: return
		if event.button_index==MOUSE_BUTTON_LEFT:
			_begin_camera_drag(event.button_index)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(2.1, camera_distance - 0.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(10.0, camera_distance + 0.4)
		else:
			return
		get_viewport().set_input_as_handled()

func _begin_camera_drag(button: MouseButton) -> void:
	if button!=MOUSE_BUTTON_LEFT or scope_enabled: return
	if not rotating_camera:
		_mouse_position_before_drag = get_viewport().get_mouse_position()
		_mouse_mode_before_drag = Input.mouse_mode
		if _mouse_mode_before_drag==Input.MOUSE_MODE_HIDDEN: _mouse_mode_before_drag=Input.MOUSE_MODE_VISIBLE
		rotating_camera = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_drag_buttons |= 1 << (button - 1)

func _end_camera_drag(restore_position: bool = true) -> void:
	if not rotating_camera:
		return
	rotating_camera = false
	_camera_drag_buttons = 0
	Input.mouse_mode = _mouse_mode_before_drag
	if restore_position and _mouse_mode_before_drag in [Input.MOUSE_MODE_VISIBLE,Input.MOUSE_MODE_HIDDEN] and get_window().has_focus():
		Input.warp_mouse(_mouse_position_before_drag)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_scope(false)
		_end_camera_drag(false)

func _exit_tree() -> void:
	set_scope(false)
	_end_camera_drag(false)

func set_scope(value: bool) -> void:
	if value==scope_enabled: return
	var camera := get_node_or_null("Camera3D") as Camera3D
	if camera==null: return
	if value:
		_end_camera_drag()
		_scope_saved_fov=camera.fov
		_scope_saved_mouse=Input.mouse_mode
		if _scope_saved_mouse==Input.MOUSE_MODE_HIDDEN: _scope_saved_mouse=Input.MOUSE_MODE_VISIBLE
		_scope_saved_cursor=get_viewport().get_mouse_position()
		camera.fov=rad_to_deg(2.0*atan(tan(deg_to_rad(_scope_saved_fov)*.5)/4.0))
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	else:
		camera.fov=_scope_saved_fov
		camera_pitch=clampf(camera_pitch,-1.15,.2)
		Input.mouse_mode=_scope_saved_mouse
		if get_window().has_focus(): Input.warp_mouse(_scope_saved_cursor)
	scope_enabled=value
	$Body.visible=not value
	_update_camera()

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		_update_camera()
		return
	var input_vec := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_vec.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_vec.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_vec.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_vec.y += 1.0
	if input_vec == Vector2.ZERO:
		input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_vec.x, 0.0, input_vec.y).rotated(Vector3.UP, camera_yaw).normalized()
	var previous_yaw: float = $Body.rotation.y
	var movement_speed := sprint_speed if Input.is_action_pressed("sprint") else speed
	velocity.x = move_toward(velocity.x, direction.x * movement_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * movement_speed, acceleration * delta)
	var dashing := dash_remaining > 0.0
	if dashing:
		dash_remaining=maxf(0.0,dash_remaining-delta)
		velocity.x=_dash_direction.x*18.0
		velocity.z=_dash_direction.z*18.0
	if direction.length_squared() > 0.0 and not dashing:
		$Body.rotation.y = lerp_angle($Body.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 10.0))
	# Brief input buffering and ledge grace keep jumps responsive without air jumps.
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	_coyote_remaining = .10 if is_on_floor() else maxf(0.0, _coyote_remaining - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_remaining = .12
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		velocity.y = jump_velocity
		character.notify_jump()
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0
	var previous_position := global_position
	move_and_slide()
	global_position.x = clampf(global_position.x, -playable_extent, playable_extent)
	global_position.z = clampf(global_position.z, -playable_extent, playable_extent)
	var traveled := Vector2(global_position.x - previous_position.x, global_position.z - previous_position.z)
	var actual_velocity := Vector3(traveled.x,0,traveled.y)/maxf(delta,.00001)
	var local_acceleration: Vector3 = $Body.global_basis.inverse() * ((actual_velocity-_previous_motion)/maxf(delta,.00001))
	var turn_rate: float = angle_difference(previous_yaw,$Body.rotation.y)/maxf(delta,.00001)
	character.set_motion_context(local_acceleration,turn_rate)
	_update_ground_context()
	_previous_motion = actual_velocity
	character.animate(delta, traveled.length() / maxf(delta, .00001), is_on_floor(), velocity.y)
	if _shock_pose_remaining>0:
		_shock_pose_remaining=maxf(0.0,_shock_pose_remaining-delta)
		character.arms[0].rotation.x=-1.05*sin((1.0-_shock_pose_remaining/.65)*PI)
	_update_camera()

func _update_ground_context() -> void:
	var heights: Array[float] = [0.0, 0.0]
	var normals: Array[Vector3] = [Vector3.UP, Vector3.UP]
	var valid: Array[bool] = [false, false]
	if is_on_floor():
		var sample_points: Array[Vector3] = character.ground_sample_points()
		for i in 2:
			var sample := sample_points[i]
			sample.y = global_position.y
			var query := PhysicsRayQueryParameters3D.create(sample + Vector3.UP * .50, sample - Vector3.UP * .62, 1, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.normal.y > .65:
				heights[i] = character.to_local(hit.position).y
				normals[i] = character.global_basis.inverse() * hit.normal
				valid[i] = true
	character.set_ground_context(heights, normals, valid)

func _update_camera() -> void:
	if scope_enabled:
		$Camera3D.global_position=global_position+Vector3(0,1.62,0)
		$Camera3D.rotation=Vector3(-camera_pitch,camera_yaw,0)
		return
	var target := global_position + Vector3(0.0, 1.25, 0.0)
	var offset := Vector3(0.0, 0.0, camera_distance).rotated(Vector3.RIGHT, camera_pitch).rotated(Vector3.UP, camera_yaw)
	var endpoint := target + offset
	var query := PhysicsRayQueryParameters3D.create(target, endpoint, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		endpoint = hit.position + hit.normal * 0.2
	$Camera3D.global_position = endpoint
	$Camera3D.look_at(target)

func begin_dash() -> bool:
	if not controls_enabled or not is_on_floor() or dash_remaining>0:
		return false
	_dash_direction=-$Body.global_basis.z
	_dash_direction.y=0
	_dash_direction=_dash_direction.normalized()
	dash_remaining=.38
	return true

func cancel_dash() -> void:
	_shock_pose_remaining=0
	if dash_remaining>0:
		velocity.x=0
		velocity.z=0
	dash_remaining=0

func is_dashing() -> bool:
	return dash_remaining>0.0

func play_shock_action() -> void:
	_shock_pose_remaining=.65
