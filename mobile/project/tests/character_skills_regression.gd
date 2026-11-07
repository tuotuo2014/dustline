extends SceneTree
var game: Node3D
var player: CharacterBody3D
var skill: Node3D
var failed := 0
var count := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok:
		failed+=1
		push_error(label)
	else: print("PASS: "+label)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func press_c() -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_C
		event.physical_keycode=KEY_C
		event.pressed=down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1)
func begin(id: int,pos := Vector3(0,.035,65)) -> void:
	game.open_menu()
	game.hud._select_character(id)
	game.start_mode(0)
	game.damage_grace=9999
	player.global_position=pos
	player.velocity=Vector3.ZERO
	for i in game.mutants.size():
		var m: CharacterBody3D=game.mutants[i]
		m.global_position=game._ground(Vector3(-180,0,-180+i*4))
		m.home=m.global_position
		m.patrol_goal=m.global_position
	await frames(12)
func wall(pos: Vector3,size: Vector3) -> StaticBody3D:
	var node := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=size
	shape.shape=box
	node.add_child(shape)
	node.position=pos
	game.add_child(node)
	return node
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	player=game.player
	skill=game.skills
	await frames(5)
	await press_c()
	check(skill.cooldowns==[0.0,0.0,0.0,0.0],"Entry menu rejects ability activation")
	await begin(0,Vector3(0,.035,19))
	await press_c()
	check(skill.scan_markers.size()>0 and skill.scan_markers.size()<=16,"C creates bounded nearby salvage markers")
	check(skill.cooldowns[0]>21 and skill.active_id==0,"Survey uses its own 22 second cooldown")
	var old_cd: float=skill.cooldowns[0]
	var old_size: int=skill.scan_markers.size()
	await press_c()
	check(skill.scan_markers.size()==old_size and skill.cooldowns[0]<old_cd,"Cooldown blocks duplicate casts and duplicate markers")
	var item: Area3D=skill.scan_markers[0].target
	game._collect(item)
	await frames(2)
	check(skill.scan_markers.size()<old_size,"Collected salvage loses its scan marker")
	game.open_menu()
	var paused_cd: float=skill.cooldowns[0]
	var paused_duration: float=skill.active_remaining
	await frames(35)
	await press_c()
	check(skill.cooldowns[0]==paused_cd and skill.active_remaining==paused_duration,"Menus freeze ability durations and cooldowns")
	game.hud._select_character(1)
	game.hud._select_character(0)
	check(skill.cooldowns[0]==paused_cd and skill.scan_markers.is_empty(),"Switching cancels effects while preserving used cooldown")
	game.resume_game()
	skill.tick(30)
	check(skill.cooldowns[0]==0,"Ability becomes ready when active play cooldown elapses")
	await begin(1)
	var near: CharacterBody3D=game.mutants[0]
	var occluded: CharacterBody3D=game.mutants[1]
	var distant: CharacterBody3D=game.mutants[2]
	near.global_position=Vector3(0,0,60)
	occluded.global_position=Vector3(5,0,65)
	distant.global_position=Vector3(0,0,85)
	for m in [near,occluded,distant]:
		m.home=m.global_position
		m.patrol_goal=m.global_position
	var barrier := wall(Vector3(2.5,1.6,65),Vector3(.30,3.2,8))
	await frames(2)
	near._set_state("lunge")
	await press_c()
	check(near.state=="stunned" and near.stun_remaining>2.8,"Mechanical shock immediately interrupts an attacking wolf")
	check(occluded.stun_remaining==0 and distant.stun_remaining==0,"Shock respects solid walls and 12m reach")
	var start := near.global_position
	await frames(12)
	check(near.global_position.distance_to(start)>.3,"Shock knocks the wolf back through actual physics")
	check(skill.cooldowns[1]>19 and skill.effects.size()>0,"Shock creates a visible pulse and starts cooldown")
	await frames(185)
	check(near.stun_remaining==0 and near.state!="stunned","Wolf recovers after the stun expires")
	barrier.free()
	await begin(2)
	game.damage_grace=0
	game.health=70
	start=player.global_position
	await press_c()
	check(player.is_dashing(),"C starts the cyber scout's ground dash")
	game.take_damage(18,true)
	check(game.health==70,"Dash evades bite damage during its active window")
	game.take_damage(1,false)
	check(game.health==69,"Dash does not block environmental damage")
	await frames(25)
	var distance := Vector2(player.position.x-start.x,player.position.z-start.z).length()
	check(distance>5.8 and distance<8.5 and not player.is_dashing(),"Dash travels a short finite distance and ends")
	game.take_damage(18,true)
	check(game.health==51,"Bite damage returns after the dash ends")
	await begin(2)
	barrier=wall(Vector3(0,1.6,62),Vector3(10,3.2,.3))
	await frames(2)
	await press_c()
	await frames(30)
	check(player.position.z>62.4,"Dash cannot pass through a solid wall")
	barrier.free()
	await begin(2)
	player.position.y=2
	await frames(2)
	await press_c()
	check(not player.is_dashing() and skill.cooldowns[2]==0,"Airborne dash is rejected without spending cooldown")
	await begin(3)
	game.health=40
	await press_c()
	check(is_instance_valid(skill.drone) and skill.drone.find_children("Rotor*","Node3D",true,false).size()==4,"Old Mo deploys a four-rotor repair companion")
	var health_before: float=game.health
	await frames(60)
	check(game.health>health_before+2.8 and game.health<health_before+3.2,"Repair companion actually restores three health per second")
	var drone_before: Vector3=skill.drone.global_position
	player.position.x+=4
	await frames(30)
	check(skill.drone.global_position.distance_to(drone_before)>2.0,"Repair drone follows its moving owner")
	game.open_menu()
	health_before=game.health
	var drone_paused: Vector3=skill.drone.global_position
	paused_cd=skill.cooldowns[3]
	await frames(35)
	check(game.health==health_before and skill.drone.global_position==drone_paused and skill.cooldowns[3]==paused_cd,"Pause freezes repair, drone motion, and recharge")
	game.resume_game()
	skill.tick(20)
	await frames(1)
	check(absf(game.health-76.0)<.12 and not is_instance_valid(skill.drone),"Complete deployment heals at most 36 then despawns")
	await begin(3)
	game.health=99
	await press_c()
	await frames(60)
	check(game.health==100,"Repair healing caps at maximum health")
	game.open_menu()
	game.hud._select_character(0)
	check(not is_instance_valid(skill.drone) and skill.cooldowns[3]>30,"Switching ends the old companion but keeps its cooldown")
	game.resume_game()
	game.restart_game()
	check(skill.cooldowns==[0.0,0.0,0.0,0.0] and skill.active_id==-1,"Restart cleans every effect and refreshes all four cooldowns")
	game._update_hud()
	check("拾荒直觉" in game.hud._skill_button.text and not game.hud._skill_button.disabled,"HUD shows the selected survivor's ready skill")
	# Pointer activation tests that the HUD consumes the click without dragging the camera.
	var button: Button=game.hud._skill_button
	await frames(2)
	var point := button.get_global_transform_with_canvas()*(button.size*.5)
	for down in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index=MOUSE_BUTTON_LEFT
		mouse.pressed=down
		mouse.position=point
		mouse.global_position=point
		root.push_input(mouse,true)
		await frames(2)
	check(skill.cooldowns[0]>0 and not player.rotating_camera,"Clicking the actual HUD skill button activates without camera leakage")
	game._update_hud()
	check(game.hud._skill_button.disabled and game.hud._skill_progress.value<1,"HUD displays cooldown and disables repeated activation")
	print("CHARACTER SKILLS REGRESSION: %d checks; %d failures"%[count,failed])
	quit(1 if failed else 0)
