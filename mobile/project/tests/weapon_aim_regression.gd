extends SceneTree
var game: Node3D
var failures := 0
var checks := 0
var save_path := "/tmp/dustline-aim-%d.json"%OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func frames(count := 3) -> void:
	for i in count: await physics_frame
	await process_frame
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.pressed=pressed
		root.push_input(event,true)
		await frames(1)
func mouse(point: Vector2, code: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=code
	event.pressed=pressed
	root.push_input(event,true)
func move(point: Vector2, relative := Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position=point
	event.relative=relative
	event.screen_relative=relative
	root.push_input(event,true)
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(5)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://previews/"+label+".png")
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	if DisplayServer.get_name()!="headless": RenderingServer.render_loop_enabled=false
	game=load("res://main.tscn").instantiate()
	var funding: Dictionary=game.profile.begin_expedition()
	game.profile.finish_expedition(funding.id,true,1000,0)
	game.profile.purchase("repulsor")
	root.add_child(game)
	game.start_mode(1)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.global_position=game._ground(Vector3(0,0,40))
	game.player.camera_yaw=0
	game.player.camera_pitch=.05
	game.player._update_camera()
	await frames()
	var aim: Control=game.hud._weapon_aim
	var camera: Camera3D=game.player.get_node("Camera3D")
	var wolf: CharacterBody3D=game.mutants[0]
	wolf.global_position=game.player.global_position+Vector3(4,0,-12)
	wolf.set_physics_process(false)
	await frames()
	var point := camera.unproject_position(wolf.global_position+Vector3(0,1,0))
	move(point)
	await frames()
	check(aim.screen_point().distance_to(point)<.1,"Crosshair follows mouse away from center")
	var ammo: int=game.round_ammo
	mouse(point,MOUSE_BUTTON_RIGHT,true)
	mouse(point,MOUSE_BUTTON_RIGHT,false)
	await frames()
	check(game.round_ammo==ammo-1 and not game.player.rotating_camera,"Right click fires one shot without starting camera drag")
	check(game.arsenal.last_hit==wolf,"Off-center cursor ray hits the selected world target")
	await capture("aim-mouse-crosshair")
	game.arsenal.cooldown=0
	var obstacle := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(2,3,.5)
	shape.shape=box
	obstacle.add_child(shape)
	game.add_child(obstacle)
	obstacle.global_position=game.player.global_position+Vector3(2,1,-6)
	await frames()
	game.arsenal.fire(wolf.global_position+Vector3(0,1,0))
	check(game.arsenal.last_hit==null and game.arsenal.last_impact.distance_to(obstacle.global_position)<2,"Muzzle path prevents shooting through cover")
	obstacle.queue_free()
	await frames()
	var old_fov: float=camera.fov
	var old_distance: float=game.player.camera_distance
	await key(KEY_K)
	check(game.player.scope_enabled and is_equal_approx(tan(deg_to_rad(old_fov)*.5)/tan(deg_to_rad(camera.fov)*.5),4),"K enables true four-times optical field of view")
	check(not game.player.get_node("Body").visible and camera.position.distance_to(Vector3(0,1.62,0))<.01,"Scope camera uses eye position and hides own body")
	check(aim.screen_point().distance_to(root.get_visible_rect().size*.5)<.1,"Optical reticle stays centered while scoped")
	var yaw: float=game.player.camera_yaw
	move(root.get_visible_rect().size*.5,Vector2(20,-10))
	check(not is_equal_approx(game.player.camera_yaw,yaw),"Scoped mouse movement adjusts aim")
	var original_yaw: float=game.player.camera_yaw
	var original_pitch: float=game.player.camera_pitch
	for heading in [0.0,1.3,3.13,-3.13]:
		for motion in [Vector2(24,0),Vector2(-24,0),Vector2(0,-24),Vector2(0,24)]:
			game.player.camera_yaw=heading
			game.player.camera_pitch=.12
			game.player._update_camera()
			var previous_basis := camera.global_basis
			move(root.get_visible_rect().size*.5,motion)
			var forward := -camera.global_basis.z
			var rightward := forward.dot(previous_basis.x)
			var upward := forward.dot(previous_basis.y)
			check(rightward*motion.x>0 if motion.x!=0 else upward*motion.y<0,"Scope follows mouse %s at heading %.2f"%[motion,heading])
	game.player.camera_yaw=original_yaw
	game.player.camera_pitch=original_pitch
	game.player._update_camera()
	game.arsenal.cooldown=0
	ammo=game.round_ammo
	mouse(root.get_visible_rect().size*.5,MOUSE_BUTTON_RIGHT,true)
	mouse(root.get_visible_rect().size*.5,MOUSE_BUTTON_RIGHT,false)
	check(game.round_ammo==ammo-1 and game.player.scope_enabled,"Scope supports right-click shooting")
	await capture("aim-sniper-scope")
	check(game.hud._mission_box.modulate.a==0,"Scope hides ordinary HUD panels from the optical view")
	await key(KEY_K)
	check(not game.player.scope_enabled and camera.fov==old_fov and game.player.camera_distance==old_distance and game.player.get_node("Body").visible,"Second K restores third-person camera and body")
	check(game.hud._mission_box.modulate.a>0,"Leaving scope restores ordinary HUD")
	mouse(point,MOUSE_BUTTON_LEFT,true)
	check(game.player.rotating_camera,"Left drag still controls the camera")
	mouse(point,MOUSE_BUTTON_LEFT,false)
	check(not game.player.rotating_camera,"Left release restores cursor")
	await key(KEY_K)
	game.open_menu()
	await frames()
	check(not game.player.scope_enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Pause exits scope and releases cursor")
	ammo=game.round_ammo
	mouse(Vector2(600,400),MOUSE_BUTTON_RIGHT,true)
	mouse(Vector2(600,400),MOUSE_BUTTON_RIGHT,false)
	check(game.round_ammo==ammo,"Menu cannot fire")
	game.resume_game()
	await key(KEY_K)
	game.damage_grace=0
	game.take_damage(10000)
	await frames()
	check(not game.player.scope_enabled and not aim.aiming and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Death clears scope and reticle, restoring UI cursor")
	game.start_mode(1)
	await key(KEY_K)
	check(not game.player.scope_enabled,"No scope without purchased equipped weapon")
	game.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(save_path+suffix)
	print("WEAPON AIM: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
