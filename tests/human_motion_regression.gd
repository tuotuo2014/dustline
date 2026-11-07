extends SceneTree
## Tests actual foot planting and ground probes with an isolated physical world.
const PlayerScript = preload("res://player.gd")
var checks := 0
var failures: Array[String] = []
var player: CharacterBody3D
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func floor_box(rotation_z: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = Vector3(0, -.5, 0)
	body.rotation.z = rotation_z
	var shape := BoxShape3D.new()
	shape.size = Vector3(160, 1, 160)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	return body

func run() -> void:
	Input.use_accumulated_input = false
	world = Node3D.new()
	root.add_child(world)
	var floor_node := floor_box()
	player = PlayerScript.new()
	player.collision_mask = 5
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .30
	shape.height = 1.86
	collider.shape = shape
	collider.position.y = .93
	player.add_child(collider)
	var body := Node3D.new()
	body.name = "Body"
	player.add_child(body)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	player.add_child(camera)
	world.add_child(player)
	await frames(45)
	check(player.is_on_floor(), "Isolated character must stand on the physics floor")
	check(player.character._ground_valid[0] and player.character._ground_valid[1], "Each boot must sample physical ground independently")
	key(KEY_W, true)
	await frames(30)
	var swing_samples := 0
	var same_direction := 0
	for frame in 120:
		var rig: Node3D = player.character
		var old_knees: Array[Vector3] = [rig.to_local(rig.knees[0].global_position), rig.to_local(rig.knees[1].global_position)]
		var old_hands: Array[Vector3] = [rig.to_local(rig.elbows[0].get_node("Hand").global_position), rig.to_local(rig.elbows[1].get_node("Hand").global_position)]
		await frames(1)
		for side in 2:
			var knee_dz: float = rig.to_local(rig.knees[side].global_position).z - old_knees[side].z
			var hand_dz: float = rig.to_local(rig.elbows[side].get_node("Hand").global_position).z - old_hands[side].z
			if absf(knee_dz) > .002 and absf(hand_dz) > .002:
				swing_samples += 1
				if knee_dz * hand_dz > 0: same_direction += 1
	check(swing_samples > 180 and same_direction == 0, "Actual controller must swing each hand opposite its own thigh throughout steady walking")
	print("ACTUAL CONTROLLER ARM DIRECTIONS: %d samples; %d same-direction motions" % [swing_samples,same_direction])
	key(KEY_W, false)
	await frames(30)
	var max_drift := 0.0
	var drift := 0.0
	var contacts := 0
	var observed_lean := 0.0
	for frame in 170:
		if frame == 0: key(KEY_W, true)
		if frame == 35: key(KEY_D, true)
		if frame == 62: key(KEY_W, false)
		if frame == 90: key(KEY_D, false)
		if frame == 115: key(KEY_A, true)
		if frame == 145: key(KEY_A, false)
		var old_feet: Array[Vector3] = [player.character.ankles[0].global_position, player.character.ankles[1].global_position]
		var old_lock: Array = player.character._foot_locked.duplicate()
		await frames(1)
		observed_lean = maxf(observed_lean, absf(player.character.torso.rotation.z))
		for i in 2:
			if old_lock[i] and player.character._foot_locked[i]:
				var foot: Vector3 = player.character.ankles[i].global_position
				var travel := Vector2(foot.x - old_feet[i].x, foot.z - old_feet[i].z).length()
				max_drift = maxf(max_drift, travel)
				drift += travel
				contacts += 1
	check(contacts > 80, "Starts, stops, and turns must retain measurable planted-foot contact")
	check(drift / maxi(1, contacts) < .006 and max_drift < .035, "World-space feet must not slide while the body changes direction")
	check(observed_lean > .025, "Direction changes must transfer body weight instead of rotating a rigid mannequin")
	await frames(40)
	check(player.character.gait < .001 and player.velocity.length() < .001, "Braking must settle fully without an endlessly cycling gait")
	check(player.character.arms[0].rotation.z < 0 and player.character.arms[1].rotation.z > 0, "Resting arms must hang at their corresponding sides")
	var idle_y: float = player.character.torso.position.y
	await frames(25)
	check(absf(player.character.torso.position.y - idle_y) > .0001, "Idle breathing must continue after motion stops")
	var phase_before: float = player.character.phase
	player.character.set_motion_context(Vector3.ZERO, 4.0)
	player.set_controls_enabled(false)
	for i in 35:
		player.character.animate(1.0 / 60.0, 0.0, true)
	check(absf(player.character.phase - phase_before) > .1 and player.character.gait > .2, "A sharp turn at low speed must reposition feet")
	player.set_controls_enabled(true)
	floor_node.free()
	var slope_angle := deg_to_rad(12.0)
	var slope := floor_box(slope_angle)
	player.reset_for_round(Vector3(0, .25, 0))
	await frames(100)
	var surface_normal := slope.global_basis.y.normalized()
	var surface_point := slope.to_global(Vector3(0, .5, 0))
	check(player.is_on_floor(), "Ground snapping must keep the player on a walkable slope")
	check(absf(player.character.ground_heights[0] - player.character.ground_heights[1]) > .025, "The two boots must adapt to different terrain heights")
	var minimum_clearance := INF
	for i in 2:
		var ankle: Node3D = player.character.ankles[i]
		check(ankle.global_basis.y.dot(surface_normal) > .998, "Each boot sole must align with the local ground normal")
		var sole := ankle.get_node("Sole") as MeshInstance3D
		var aabb := sole.mesh.get_aabb()
		for corner in 8:
			minimum_clearance = minf(minimum_clearance, surface_normal.dot(sole.to_global(aabb.get_endpoint(corner)) - surface_point))
	check(minimum_clearance > -.012, "Ground-adapted soles must not penetrate the slope")
	key(KEY_D, true)
	await frames(110)
	key(KEY_D, false)
	await frames(35)
	check(player.is_on_floor() and player.position.x > 2.0 and player.position.y > .35, "The actual controller must walk uphill without losing floor contact")
	for id in 4:
		player.select_character(id)
		await frames(8)
		check(player.character._ground_context_enabled and player.character.ankles.size() == 2, "Character %d must inherit both terrain-aware legs" % id)
		player.reset_for_round(Vector3(0, .25, 0))
		await frames(30)
		key(KEY_SPACE, true)
		await frames(1)
		key(KEY_SPACE, false)
		check(player.velocity.y > 5.0 and player.character._takeoff > .0, "Character %d must push off immediately with visible jump anticipation" % id)
		await frames(70)
		check(player.is_on_floor() and player.character.landing < .001, "Character %d must recover naturally from landing" % id)
	print("HUMAN MOTION REGRESSION: %s; %d checks; planted mean %.6f m, maximum %.6f m, slope clearance %.4f m" % ["PASS" if failures.is_empty() else "FAIL", checks, drift / maxi(1, contacts), max_drift, minimum_clearance])
	quit(0 if failures.is_empty() else 1)
