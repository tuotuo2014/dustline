extends SceneTree
var failed := 0
var checks := 0
var game: Node3D
var view: SubViewport
var path := "/private/tmp/tutorial-guidance-%d.json"%OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failed+=1
		push_error(message)
func settle() -> void:
	for i in 8: await process_frame
func step(id: String) -> void:
	game.tutorial._clear_marker()
	game.tutorial.step=game.tutorial.STEPS.find(id)
	game.tutorial.step_id=id
	game.tutorial._refresh()
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","")
	view=SubViewport.new()
	view.size=Vector2i(1600,1000)
	view.own_world_3d=true
	root.add_child(view)
	game=load("res://main.tscn").instantiate()
	view.add_child(game)
	game.start_mode(0)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player._update_camera()
	var panel: Control=game.hud._tutorial_panel
	var pointer: Control=panel._pointer
	for size in [Vector2i(1600,1000),Vector2i(1280,720),Vector2i(1050,760)]:
		view.size=size
		for id in game.tutorial.STEPS:
			step(id)
			await settle()
			check(panel._illustration.texture!=null,"Illustration loads for "+id)
			check(panel._checklist.text.count("\n")==2,"Three actionable instructions for "+id)
			var rect: Rect2=panel._card.get_global_rect()
			check(Rect2(Vector2.ZERO,Vector2(size)).encloses(rect),"Guide stays in viewport: "+id+str(size))
			for hud_control in [game.hud._vitals,game.hud._prompt_box]:
				check(not hud_control.is_visible_in_tree() or not rect.intersects(hud_control.get_global_rect()),"Guide avoids visible HUD: "+id+str(size))
			check(pointer.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Arrows do not capture input")
	step("skill")
	await settle()
	check(pointer._active and pointer.target_rect.encloses(game.hud._skill_button.get_global_rect()),"Skill arrow outlines actual clickable button")
	step("survival")
	await settle()
	check(pointer.target_rect.encloses(game.hud._health.get_global_rect()),"Healing lesson highlights actual health bar")
	step("loot")
	await settle()
	check(pointer._active and is_instance_valid(game.tutorial.marker),"Supply lesson has screen and world arrows")
	var old_target: Area3D=game.tutorial.target
	old_target.set_meta("taken",true)
	game.tutorial._refresh()
	await settle()
	check(game.tutorial.target!=old_target and is_instance_valid(game.tutorial.target),"Unavailable loot is replaced with a live target")
	var camera: Camera3D=game.player.get_node("Camera3D")
	pointer.data={"world_target":camera.global_position+camera.global_basis.z*10,"pointer_label":"behind"}
	await settle()
	check(pointer.behind_target and pointer.edge_target and pointer.screen_point.is_finite(),"Behind-camera target produces a finite edge arrow")
	check(Rect2(Vector2.ZERO,Vector2(view.size)).has_point(pointer.screen_point),"Offscreen pointer remains visible")
	pointer.data={"world_target":camera.global_position-camera.global_basis.z*10+camera.global_basis.x*4,"pointer_label":"front"}
	await settle()
	check(not pointer.behind_target and pointer.screen_point.is_finite(),"Arrow returns to a front-facing target")
	game.open_menu()
	await settle()
	check(not pointer.is_visible_in_tree(),"Pause hides guiding arrows")
	game.resume_game()
	await settle()
	check(pointer.is_visible_in_tree(),"Continue restores guiding arrows")
	game.tutorial.skip()
	await settle()
	check(not pointer.is_visible_in_tree() and game.hud._mission.is_visible_in_tree(),"Finishing removes arrows and restores normal mission HUD")
	game.free()
	view.free()
	await settle()
	for suffix in ["",".bak",".tmp",".bak.tmp",".tutorial.cfg",".tutorial.cfg.tmp"]: DirAccess.remove_absolute(path+suffix)
	print("TUTORIAL GUIDANCE: %d checks, %d failures"%[checks,failed])
	quit(1 if failed else 0)
