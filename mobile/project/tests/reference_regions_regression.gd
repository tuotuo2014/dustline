extends SceneTree
const Layout=preload("res://world_layout.gd")
var game: Node3D
var checks := 0
var failures: Array[String]=[]
var save_path := "/tmp/dustline-regions-%d.json"%OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else:
		failures.append(message)
		push_error("FAIL: "+message)
func frames(count: int=3) -> void:
	for i in count: await physics_frame
	await process_frame
func click(button: Control) -> void:
	game.hud._menu_center.get_parent().ensure_control_visible(button)
	await frames(3)
	var pos := button.get_global_transform_with_canvas()*(button.size*.5)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=pos
		event.global_position=pos
		event.button_index=MOUSE_BUTTON_LEFT
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed=down
		root.push_input(event,true)
		await frames(1)
func clear_at(pos: Vector3, radius: float=.48) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius=radius
	shape.height=1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform.origin=pos+Vector3(0,1.02,0)
	query.collision_mask=1
	query.exclude=[game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func supported(pos: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(pos+Vector3(0,.3,0),pos-Vector3(0,.35,0),1,[game.player.get_rid()])
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and absf(hit.position.y-pos.y)<.20
func approach(node: Node3D) -> bool:
	for i in 16:
		var angle := i*TAU/16
		var pos: Vector3=game._ground(node.global_position+Vector3(cos(angle)*2.3,0,sin(angle)*2.3))
		if clear_at(pos) and supported(pos): return true
	return false
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(12)
	check(game.hud._region_picker.item_count==4,"Destination menu includes original and all three new regions")
	check(game.world.region_id==0 and game.world.has_node("BrokenOverpass"),"Initial world loads only the bridge scene")
	check(not game.world.has_node("Rustworks") and not game.world.has_node("BuriedCity") and not game.world.has_node("DuskSettlement"),"Other destination geometry is absent at entry")
	game.set_physics_process(false)
	for id in range(1,4):
		var old_world: Node3D=game.world
		var old_round: Node3D=game.round_root
		game.open_menu()
		game.hud._region_picker.item_selected.emit(id)
		await click(game.hud._mode_buttons[1])
		await frames(5)
		game.player.set_physics_process(false)
		check(not is_instance_valid(old_world) and not is_instance_valid(old_round),"Region %d frees previous map and expedition"%id)
		check(game.world.region_id==id and game.world.scene_file_path==Layout.REGIONS[id].scene,"Region %d loads its own scene resource"%id)
		var roots := ["BrokenOverpass","Rustworks","BuriedCity","DuskSettlement"]
		for other in 4:
			check(game.world.has_node(roots[other])==(other==id),"Region %d contains only its own landmark (check %s)"%[id,roots[other]])
		check(game.find_children("*","WorldEnvironment",true,false).size()==2,"Only active map and character-preview environments remain")
		check(game.extraction_points.size()==1 and game.extraction.get_meta("destination_id")==id,"Region %d only creates its own extraction beacon"%id)
		check(game.player.playable_extent==105 and Layout.inside_playable(game.player.position,0,id),"Player uses local map boundaries")
		for mutant in game.mutants:
			check(mutant.playable_extent==105,"Predator uses local map boundaries")
		if id==1:
			check(game.world.get_node("Rustworks").find_children("*Cooling*","Node3D",true,false).size()>0,"Industrial cooling tower retained")
		if id==2:
			check(game.world.get_node("BuriedCity").find_children("*Bus*","Node3D",true,false).size()>=2,"City buses retained")
			var shells := 0
			for block in game.world.get_node("BuriedCity").get_children():
				if block.has_meta("floors"): shells+=1
			check(shells>=8,"City ruined buildings retained")
		check(game.active and game.region_id==id and game.hud.selected_region_id==id,"Destination %d starts via actual mode button"%id)
		check(game.player.global_position.distance_to(game._ground(Vector3(game.region.base)+Vector3(0,0,1)))<.25,"Region %d arrival is at its camp"%id)
		check(game.extraction.global_position.distance_to(game._ground(game.region.exit))<.01 and game.relays.size()==3,"Region %d has local exit and three relays"%id)
		var paths_ok := true
		for marker in [game.base,game.extraction]+game.relays:
			if not approach(marker):
				paths_ok=false
				print("BLOCKED OBJECTIVE ",id," ",marker.name," ",marker.position)
		check(paths_ok,"Region %d objectives have capsule-clear supported approach"%id)
		var loot_clear := true
		for pickup in game.pickups:
			if not clear_at(pickup.global_position) or not supported(pickup.global_position):
				loot_clear=false
				print("BLOCKED LOOT ",id," ",pickup.get_meta("kind")," ",pickup.global_position)
		check(loot_clear,"Region %d every scrap medkit and valuable is reachable on ground"%id)
		var road_clear := true
		for z in range(-72,54,5):
			var pos: Vector3=game._ground(Vector3(game.region.position)+Vector3(0,0,z))
			if not clear_at(pos) or not supported(pos):
				road_clear=false
				print("BLOCKED ROAD ",id," ",pos)
		check(road_clear,"Region %d central route remains passable end to end"%id)
		check(game.pickups.size()==77 and game.expedition.valuable_count==36,"Region %d has independent supplies and thirty-six valuables"%id)
		var current_world: Node3D=game.world
		game.open_menu()
		game._on_region_selected((id+1)%4)
		game.resume_game()
		check(game.world==current_world and game.region_id==id,"Browsing another map then Continue keeps the current expedition")
		game.restart_game()
		await frames(3)
		check(game.world==current_world and game.region_id==id and game.pickups.size()==77,"Replay reuses current map and resets its supplies")
		var env: Environment=game.world.get_node("DesertAtmosphere").environment
		check(float(env.sky.sky_material.get_shader_parameter("twilight"))==(1.0 if id==3 else 0.0),"Region %d loads matching sky and lighting"%id)
		for pickup in game.pickups:
			if pickup.has_meta("value"):
				game._collect(pickup)
				break
		var bag: int=game.expedition.bag_value
		var bank: int=game.profile.assets
		game.scrap=6
		game.player.global_position=game.extraction.global_position+Vector3(0,0,1.3)
		game.interact()
		check(game.won and game.profile.assets==bank+bag,"Region %d extraction settles real valuables"%id)
		game.open_menu()
		game.start_mode(0)
		await frames(3)
		game.scrap=6
		for relay in game.relays:
			game.player.global_position=relay.global_position+Vector3(0,0,1.5)
			game.interact()
		game.player.global_position=game.base.global_position+Vector3(0,0,1.5)
		game.interact()
		check(game.won and game.repaired==3,"Region %d exploration completes with local relays and camp"%id)
	game.open_menu()
	game._on_region_selected(0)
	game.start_mode(0)
	check(game.region_id==0 and game.base.global_position.distance_to(game._ground(Layout.BASE))<.01,"Original bridge expedition remains available")
	check(game.world.has_node("BrokenOverpass") and not game.world.has_node("DuskSettlement") and game.player.playable_extent==210,"Return to bridge restores map, bounds and removes previous geometry")
	check(game.extraction_points.size()==1,"No extraction markers from other maps remain")
	game._finish(false,"End test","")
	game.queue_free()
	await frames(3)
	for suffix in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(save_path+suffix)
	print("REFERENCE REGIONS: %s; %d checks; %d failures"%["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
