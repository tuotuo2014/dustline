extends SceneTree
var game: Node3D
var view: SubViewport
var failed := 0
var checks := 0
var save_path := "/private/tmp/dustline-minimap-%d.json"%OS.get_process_id()
var render := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failed+=1
		push_error(message)
func settle() -> void:
	for i in 12: await process_frame
	game.hud._minimap.place()
	game.hud._minimap.refresh_markers()
	game.hud._minimap.queue_redraw()
	game.hud._minimap.chart.queue_redraw()
	await process_frame
func capture(label: String) -> void:
	if not render: return
	RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png("res://previews/minimap-"+label+".png")
func layout_check(label: String) -> void:
	var map: Control=game.hud._minimap
	var rect := map.get_global_rect()
	check(Rect2(Vector2.ZERO,Vector2(view.size)).encloses(game.hud._vitals.get_global_rect()),label+" vitals inside viewport")
	check(game.hud._prompt_box.position.y<200 and game.hud._toast.position.y<200,label+" contextual hints moved to top")
	check(Rect2(Vector2.ZERO,Vector2(view.size)).encloses(rect),label+" stays inside viewport")
	for control in [game.hud._vitals,game.hud._mission,game.hud._prompt_box,game.hud._hint,game.hud._tutorial_panel._card,game.hud._toast]:
		check(not control.is_visible_in_tree() or not rect.intersects(control.get_global_rect()),label+" avoids "+control.name)
func run() -> void:
	render=DisplayServer.get_name()!="headless"
	if render: RenderingServer.render_loop_enabled=false
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	view=SubViewport.new()
	view.size=Vector2i(1600,1000)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game=load("res://main.tscn").instantiate()
	view.add_child(game)
	game.set_physics_process(false)
	var map: Control=game.hud._minimap
	check(not map.is_visible_in_tree(),"Map hidden in main menu")
	for region in (1 if "--quick" in OS.get_cmdline_user_args() else 4):
		game._on_region_selected(region)
		game.start_mode(0)
		game.player.set_physics_process(false)
		game.player._update_camera()
		map.rebuild_world()
		await settle()
		check(map.is_visible_in_tree(),"Map shown in expedition")
		check(map.region_name==game.region.name,"Correct independent region")
		check(map.world_id==game.world.get_instance_id(),"Fresh geometry from current world")
		check(not map.features.is_empty(),"Architecture footprints available")
		check(not map.contours.is_empty(),"Actual terrain contours available")
		check(map.project(Vector2.ZERO).is_equal_approx(map.chart.size*.5),"World centered in overview")
		check(map.position.x<50 and map.position.y<100,"Map in top left")
		check(map.markers.filter(func(m): return m.kind=="threat").size()==game.mutants.size(),"Every creature appears regardless of distance")
		for wolf in game.mutants: check(Rect2(Vector2.ZERO,map.chart.size).has_point(map.project(map.flat(wolf.global_position))),"Wolf has true position inside overview")
		check(game.hud._vitals.position.y>view.size.y*.6,"Vitals along bottom")
		check(game.hud._hint.position.y<70,"Instructions at top")
		check(game.hud._mission_box.position.x>view.size.x*.5,"Mission at top right")
		check(map.project(Vector2(0,-10)).y<map.chart.size.y*.5,"North is up")
		check(map.project(Vector2(10,0)).x>map.chart.size.x*.5,"East is right")
		check(map.markers.filter(func(m): return m.kind=="exit").size()==1,"Only current map extraction is marked")
		check(map.markers.filter(func(m): return m.kind=="relay").size()==3,"Three actual relays")
		check(map.chart.mouse_filter==Control.MOUSE_FILTER_IGNORE and map.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Map never captures movement or camera input")
		layout_check("region "+str(region))
		await capture("region-%d"%region)
	game.player.position+=Vector3(12,0,-8)
	game.player.get_node("Body").rotation.y=PI*.5
	game.player.camera_yaw=-PI*.5
	map.refresh_markers()
	check(map.player_position.is_equal_approx(Vector2(game.player.position.x,game.player.position.z)),"Map follows actual movement")
	check(is_equal_approx(map.player_heading,-PI*.5) and is_equal_approx(map.camera_heading,PI*.5),"Independent body and camera headings")
	var pickup: Area3D=game.pickups[0]
	pickup.position=game.player.position+Vector3(3,0,0)
	map.refresh_markers()
	check(map.markers.any(func(m): return m.id==pickup.get_instance_id()),"Nearby pickup visible")
	pickup.set_meta("taken",true)
	map.refresh_markers()
	check(not map.markers.any(func(m): return m.id==pickup.get_instance_id()),"Collected pickup disappears")
	game.relays[0].set_meta("active",true)
	map.refresh_markers()
	check(map.markers.any(func(m): return m.id==game.relays[0].get_instance_id() and m.color==map.GREEN),"Repaired beacon changes state")
	for resolution in [Vector2i(1280,720),Vector2i(1050,760),Vector2i(1920,1080)]:
		view.size=resolution
		game._update_hud()
		await settle()
		layout_check(str(resolution))
		await capture("%dx%d"%[resolution.x,resolution.y])
		game.hud._weapon.text="荒原驱狼枪\nV 开火 · 朝镜头方向 · 弹药 30"
		game.hud._weapon.show()
		await settle()
		layout_check("weapon "+str(resolution))
		await capture("weapon-%dx%d"%[resolution.x,resolution.y])
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","")
	game.tutorial.start()
	view.size=Vector2i(1280,720)
	await settle()
	layout_check("tutorial")
	await capture("tutorial")
	for step_id in ["look","skill","loot"]:
		game.tutorial.step=game.tutorial.STEPS.find(step_id)
		game.tutorial.step_id=step_id
		game.tutorial._refresh()
		await settle()
		layout_check("tutorial "+step_id)
		var pointer: Control=game.hud._tutorial_panel._pointer
		check(not map.get_global_rect().has_point(pointer.screen_point),"Tutorial arrow avoids radar: "+step_id)
		await capture("tutorial-"+step_id)
	game.open_menu()
	var before: int=map.update_count
	await settle()
	check(not map.is_visible_in_tree(),"Hidden when paused")
	check(map.update_count==before,"No radar processing while hidden")
	game.resume_game()
	await settle()
	check(map.is_visible_in_tree(),"Restored on resume")
	game.hud.show_result(true,"测试","测试")
	check(not map.is_visible_in_tree(),"Hidden on result screen")
	game.queue_free()
	for i in 4: await process_frame
	view.queue_free()
	for i in 4: await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp",".tutorial.cfg",".tutorial.cfg.tmp"]: DirAccess.remove_absolute(save_path+suffix)
	print("MINIMAP: %d checks, %d failures"%[checks,failed])
	quit(1 if failed else 0)
