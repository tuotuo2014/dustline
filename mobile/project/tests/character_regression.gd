extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.start_mode(0)
	var player: CharacterBody3D = scene.get_node("Player")
	var rig = player.character
	player.set_physics_process(false)
	check(rig.torso.position.distance_to(Vector3(0,1,0))<.02,"Torso must begin at chest height")
	var soles: Array[Node] = rig.find_children("Sole","MeshInstance3D",true,false)
	check(soles.size()==2,"Exactly two boot soles must exist")
	var head: MeshInstance3D = rig.torso.get_node("Head/Face")
	var jacket: MeshInstance3D = rig.torso.get_node("Jacket")
	check(rig.find_children("*Rifle*","Node3D",true,false).is_empty(),"Unarmed character still has a rifle or sling")
	var hands: Array[Node3D] = [rig.elbows[0].get_node("Hand"),rig.elbows[1].get_node("Hand")]
	var hand_min := Vector2(INF,INF)
	var hand_max := Vector2(-INF,-INF)
	var motion_samples := 0.0
	var hand_sum := Vector2.ZERO
	var foot_sum := Vector2.ZERO
	var hand_foot_product := Vector2.ZERO
	for movement in [0.0,7.0,0.0,3.0,0.0]:
		for frame in 240:
			rig.animate(1.0/60.0,movement,true)
			check(rig.torso.position.y>.86 and rig.torso.position.y<1.02,"Weight transfer moved torso beyond the anatomical range")
			check(rig.head.position.distance_to(Vector3(0,.566,0))<.001,"Head root must stay attached to the neck during weight transfer")
			var torso_bounds: AABB = jacket.global_transform*jacket.mesh.get_aabb()
			var head_bounds: AABB = head.global_transform*head.mesh.get_aabb()
			check(torso_bounds.position.y-player.global_position.y>.78,"Torso dropped beneath waist height")
			check(head_bounds.position.y-player.global_position.y>1.42,"Head dropped outside the standing/stride range")
			for sole in soles:
				var bounds: AABB = sole.global_transform*sole.mesh.get_aabb()
				check(bounds.position.y-player.global_position.y>-.012,"A boot sank below the floor")
			for i in 2:
				var hand_position: Vector3=rig.torso.to_local(hands[i].global_position)
				check(hand_position.x*(-1.0 if i==0 else 1.0)>.27,"A hand crossed into the torso during the stride")
				if movement>0.0 and rig.gait>.99:
					hand_min[i]=minf(hand_min[i],hand_position.z)
					hand_max[i]=maxf(hand_max[i],hand_position.z)
					var foot_position: Vector3=rig.to_local(rig.ankles[i].global_position)
					hand_sum[i]+=hand_position.z
					foot_sum[i]+=foot_position.z
					hand_foot_product[i]+=hand_position.z*foot_position.z
			if movement>0.0 and rig.gait>.99:
				motion_samples+=1.0
			if not failures.is_empty(): break
		if not failures.is_empty(): break
	check(motion_samples>100.0,"Not enough walking frames to verify arm motion")
	for i in 2:
		check(hand_max[i]-hand_min[i]>.3,"The empty hand did not swing through a visible stride")
		if motion_samples>0.0:
			var covariance: float=hand_foot_product[i]/motion_samples-(hand_sum[i]/motion_samples)*(foot_sum[i]/motion_samples)
			check(covariance<-.01,"The arm must counter the same-side foot instead of marching with it")
		check(absf(rig.arms[i].rotation.x)<.04,"Arm swing did not settle after stopping")
	# Simulate mapped input against real physics, preserving the existing WASD path.
	# Move above an open part of the real map so scenery cannot block this assertion.
	player.position=Vector3(0,0,65)
	player.set_physics_process(true)
	for i in 30: await physics_frame
	var start := player.global_position
	Input.action_press("move_left")
	for i in 30: await physics_frame
	Input.action_release("move_left")
	check(player.global_position.x<start.x-.3,"Mapped movement did not move the player")
	for i in 35: await physics_frame
	check(Vector2(player.velocity.x,player.velocity.z).length()<.01,"Player did not stop after releasing movement")
	check(player.is_on_floor(),"Player lost contact with the floor")
	check(absf(player.position.y)<.03,"Player origin should stay at sole height")
	# Check that camera orbit and zoom events work without changing rig proportions.
	var button := InputEventMouseButton.new()
	button.button_index=MOUSE_BUTTON_RIGHT
	button.pressed=true
	player._unhandled_input(button)
	var motion := InputEventMouseMotion.new()
	motion.screen_relative=Vector2(140,-25)
	player._input(motion)
	check(absf(player.camera_yaw)>.1,"Camera orbit did not respond")
	button.button_index=MOUSE_BUTTON_WHEEL_UP
	player._unhandled_input(button)
	check(player.camera_distance<5.5,"Camera zoom did not respond")
	button.button_index=MOUSE_BUTTON_RIGHT
	button.pressed=false
	player._input(button)
	check(not player.rotating_camera,"Camera drag did not stop on release")
	print("CHARACTER REGRESSION: %s (unarmed, opposing arm swing, idle, walk, stop, anatomy, soles, movement, camera)" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
