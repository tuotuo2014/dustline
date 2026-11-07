extends SceneTree
var failures: Array[String] = []
var checks := 0
var player: CharacterBody3D
var controls: CanvasLayer
var game: Node3D

class StubGame extends Node3D:
	var active := true
	var round_over := false
	var hud: Dictionary
	var actions: Array[String] = []
	func start_mode(_mode: int) -> void: pass
	func _unhandled_input(event: InputEvent) -> void:
		for action in ["fire_weapon","character_skill","interact","aim_scope","heal","repel","build_shelter"]:
			if event.is_action_pressed(action): actions.append(action)

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)
	Input.flush_buffered_events()

func drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	root.push_input(event, true)
	Input.flush_buffered_events()

func center(action: String) -> Vector2:
	return controls.button_regions[action].center

func tap(action: String, id: int = 8) -> void:
	touch(id,center(action),true)
	await frames(2)
	touch(id,center(action),false)
	await frames(2)

func run() -> void:
	Input.use_accumulated_input = false
	root.size = Vector2i(1280,720)
	game = StubGame.new()
	root.add_child(game)
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(panel)
	game.hud = {"_hud":panel}
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100,1,100)
	floor_collision.shape = shape
	floor_body.position.y = -.5
	floor_body.add_child(floor_collision)
	game.add_child(floor_body)
	var scene: Node = load("res://main.tscn").instantiate()
	player = scene.get_node("Player")
	scene.remove_child(player)
	scene.free()
	player.position = Vector3.ZERO
	game.add_child(player)
	controls = player.mobile_controls
	await frames(20)
	check(controls.controls_visible,"Touch controls visible during active gameplay")
	var stick: Vector2 = controls.joystick_center
	var radius: float = controls.joystick_radius
	touch(0,stick,true)
	drag(0,stick+Vector2(0,-radius*.5),Vector2(0,-radius*.5))
	await frames(20)
	var partial_speed := Vector2(player.velocity.x,player.velocity.z).length()
	check(partial_speed>.3 and partial_speed<player.speed*.7,"Half joystick must preserve analog walk speed")
	drag(0,stick+Vector2(0,-radius),Vector2(0,-radius*.5))
	await frames(20)
	check(absf(Vector2(player.velocity.x,player.velocity.z).length()-player.speed)<.06,"Full joystick reaches normal walk speed")
	var look_position := Vector2(900,250)
	var yaw: float = player.camera_yaw
	touch(1,look_position,true)
	drag(1,look_position+Vector2(50,15),Vector2(50,15))
	await frames(2)
	check(absf(angle_difference(yaw,player.camera_yaw))>.1,"Second finger rotates camera while moving")
	check(controls.move_finger==0 and controls.look_finger==1,"Movement and view keep separate finger ownership")
	check(player.touch_look_active,"Touch view is exposed to tutorial tracking")
	touch(2,center("jump"),true)
	await frames(5)
	check(player.velocity.y>3 and player.position.y>.1,"Third touch jumps while joystick and camera remain held")
	touch(2,center("jump"),false)
	touch(1,look_position,false)
	check(controls.move_finger==0 and controls.look_finger==-1,"Releasing camera does not cancel movement")
	check(not player.touch_look_active,"Camera release clears touch view flag")
	await tap("sprint")
	await frames(25)
	check(Input.is_action_pressed("sprint") and controls.sprint_toggled,"Sprint button toggles on after release")
	check(Vector2(player.velocity.x,player.velocity.z).length()>player.speed*1.5,"Sprint touch accelerates actual player")
	await tap("sprint")
	check(not Input.is_action_pressed("sprint"),"Second sprint tap returns to walking")
	touch(0,stick,false)
	await frames(35)
	check(Vector2(player.velocity.x,player.velocity.z).length()<.01,"Joystick release stops player")
	for action in ["fire_weapon","character_skill","interact","aim_scope","heal","repel","build_shelter"]:
		await tap(action)
		check(game.actions.has(action),"Touch dispatches real gameplay action: "+action)
		check(not Input.is_action_pressed(action),"Action releases cleanly: "+action)
	var fire_count: int = game.actions.count("fire_weapon")
	touch(5,center("fire_weapon"),true)
	await frames(35)
	touch(5,center("fire_weapon"),false)
	await frames(2)
	check(game.actions.count("fire_weapon")>=fire_count+2,"Holding fire repeats without needing camera finger")
	# Disabling between press and deferred dispatch must cancel the queued press too.
	touch(0,stick+Vector2(0,-radius),true)
	touch(2,center("jump"),true)
	player.set_controls_enabled(false)
	await frames(3)
	check(controls.touch_roles.is_empty() and controls.movement_vector==Vector2.ZERO,"Menu disable releases every finger")
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("move_forward"),"No delayed or stuck actions survive menu opening")
	check(not controls.controls_visible,"Controls hide while player disabled")
	player.set_controls_enabled(true)
	await frames(2)
	await tap("sprint")
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	check(not Input.is_action_pressed("sprint") and not controls.sprint_toggled,"Backgrounding releases sprint toggle")
	var overlay := Button.new()
	overlay.position = look_position - Vector2(60,30)
	overlay.size = Vector2(120,60)
	overlay.text = "教程继续"
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 20
	game.add_child(overlay_layer)
	overlay_layer.add_child(overlay)
	await frames(2)
	touch(4,look_position,true)
	check(controls.look_finger == -1,"Tutorial GUI touch does not start camera gesture")
	touch(4,look_position,false)
	overlay_layer.queue_free()
	await frames(2)
	game.hud._hud.hide()
	await frames(2)
	var old_yaw: float = player.camera_yaw
	touch(3,look_position,true)
	drag(3,look_position+Vector2(90,0),Vector2(90,0))
	touch(3,look_position,false)
	check(is_equal_approx(player.camera_yaw,old_yaw),"Menu touches cannot rotate the gameplay camera")
	game.hud._hud.show()
	await frames(2)
	for action in controls.button_regions:
		var region: Dictionary = controls.button_regions[action]
		var safe: Rect2 = controls.safe_rect
		check(safe.encloses(Rect2(region.center-Vector2.ONE*region.radius,Vector2.ONE*region.radius*2)),"Touch button within usable screen: "+action)
	controls.release_all()
	game.queue_free()
	await frames(3)
	print("MOBILE TOUCH REGRESSION: %s; %d checks"%["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
