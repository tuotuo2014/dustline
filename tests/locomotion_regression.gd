extends SceneTree

var failures: Array[String] = []
var checks := 0
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
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

func add_box(world: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func reset_player(position: Vector3 = Vector3.ZERO) -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_SPACE]:
		key(code, false)
	player.position = position
	player.velocity = Vector3.ZERO
	player.camera_yaw = 0.0
	await frames(35)

func run() -> void:
	Input.use_accumulated_input = false
	var world := Node3D.new()
	root.add_child(world)
	add_box(world, Vector3(0,-.5,0), Vector3(100,1,100))
	var scene: Node3D = load("res://main.tscn").instantiate()
	player = scene.get_node("Player")
	scene.remove_child(player)
	scene.free()
	world.add_child(player)
	await reset_player()
	check(player.is_on_floor(), "Player must begin grounded")
	key(KEY_W, true)
	await frames(45)
	var walk_speed := Vector2(player.velocity.x,player.velocity.z).length()
	check(absf(walk_speed-1.8)<.05, "W must use the brisker walking speed")
	key(KEY_SHIFT, true)
	await frames(40)
	var run_speed := Vector2(player.velocity.x,player.velocity.z).length()
	check(run_speed>walk_speed*1.6, "Holding Shift must visibly increase movement speed")
	check(player.character.run_blend>.9, "Sprint must blend into running animation")
	key(KEY_D, true)
	await frames(40)
	check(Vector2(player.velocity.x,player.velocity.z).length()<run_speed+.05, "Diagonal running must not exceed straight running speed")
	key(KEY_SHIFT, false)
	await frames(35)
	check(Vector2(player.velocity.x,player.velocity.z).length()<walk_speed+.05, "Releasing Shift must return to walking speed")
	await reset_player()
	key(KEY_SPACE, true)
	var peak := 0.0
	var airborne_transitions := 0
	var was_grounded := true
	var saw_air_pose := false
	for i in 120:
		await frames(1)
		peak = maxf(peak, player.position.y)
		if was_grounded and not player.is_on_floor():
			airborne_transitions += 1
		was_grounded = player.is_on_floor()
		saw_air_pose = saw_air_pose or player.character.airborne_blend>.8
	check(peak>1.0 and peak<1.5, "Space must jump to a useful, bounded height")
	check(airborne_transitions==1, "Holding Space must not automatically jump again on landing")
	check(saw_air_pose, "Jump must use an airborne body pose")
	check(player.is_on_floor() and absf(player.position.y)<.03, "Jump must return to ground level")
	check(player.character.airborne_blend<.01 and player.character.landing<.01, "Landing must settle back to the normal pose")
	key(KEY_SPACE, false)
	await frames(2)
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	key(KEY_SPACE, true)
	await frames(10)
	key(KEY_SPACE, false)
	await frames(2)
	var upward_speed := player.velocity.y
	key(KEY_SPACE, true)
	await frames(2)
	check(not player.is_on_floor() and player.velocity.y<upward_speed, "Pressing Space in midair must not cause a second jump")
	check(player.position.z<-.25, "Running jumps must retain forward movement")
	await reset_player()
	player.position = Vector3(0,.45,0)
	for i in 40:
		await frames(1)
		if not player.is_on_floor() and player.position.y<.16:
			break
	key(KEY_SPACE, true)
	var buffered_jump := false
	for i in 15:
		await frames(1)
		buffered_jump = buffered_jump or player.velocity.y>5.0
	check(buffered_jump, "A jump pressed just before landing must trigger on ground contact")
	await reset_player(Vector3(48,0,0))
	key(KEY_D, true)
	key(KEY_SHIFT, true)
	var left_ledge := false
	for i in 60:
		await frames(1)
		if not player.is_on_floor():
			left_ledge = true
			break
	key(KEY_SPACE, true)
	await frames(2)
	check(left_ledge and player.velocity.y>5.0, "A jump just after leaving a ledge must retain its short grace period")
	await reset_player()
	var wall := add_box(world, Vector3(-3,2,0), Vector3(1,4,6))
	key(KEY_A, true)
	key(KEY_SHIFT, true)
	await frames(80)
	check(player.position.x> -2.3, "Running must respect wall collision")
	check(player.character.gait<.02, "A blocked character must stop cycling its feet and arms")
	wall.queue_free()
	await reset_player()
	var ceiling := add_box(world, Vector3(0,2.35,0), Vector3(5,.2,5))
	await frames(2)
	key(KEY_SPACE, true)
	var ceiling_peak := 0.0
	for i in 60:
		await frames(1)
		ceiling_peak = maxf(ceiling_peak, player.position.y)
	check(ceiling_peak<.43, "Jump must stop at a low ceiling")
	check(player.is_on_floor(), "Ceiling collision must not leave the player stuck in the air")
	ceiling.queue_free()
	for code in [KEY_W, KEY_A, KEY_D, KEY_SHIFT, KEY_SPACE]:
		key(code, false)
	print("LOCOMOTION REGRESSION: %s; %d checks; walk %.2f m/s, run %.2f m/s, jump %.2f m" % ["PASS" if failures.is_empty() else "FAIL",checks,walk_speed,run_speed,peak])
	quit(0 if failures.is_empty() else 1)
