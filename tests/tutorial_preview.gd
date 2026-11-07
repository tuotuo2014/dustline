extends SceneTree
var game: Node3D
var view: SubViewport
var failed := false
var profile_path := "/tmp/dustline-tutorial-preview-%d.json"%OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	for i in 12: await process_frame
	RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png("res://previews/"+label+".png")
	if game.hud._tutorial_panel.is_visible_in_tree():
		var card: Rect2=game.hud._tutorial_panel._card.get_global_rect()
		for control in [game.hud._mission,game.hud._vitals,game.hud._prompt_box]:
			if control.is_visible_in_tree() and card.intersects(control.get_global_rect()):
				failed=true
				push_error("Tutorial overlaps HUD in "+label)
		if not Rect2(Vector2.ZERO,Vector2(view.size)).encloses(card):
			failed=true
			push_error("Tutorial exceeds viewport in "+label)
	print("CAPTURE "+label)
func step(id: String) -> void:
	game.tutorial._clear_marker()
	game.tutorial.step=game.tutorial.STEPS.find(id)
	game.tutorial.step_id=id
	game.tutorial._refresh()
func run() -> void:
	RenderingServer.render_loop_enabled=false
	OS.set_environment("DUSTLINE_PROFILE_PATH",profile_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","")
	root.size=Vector2i(1000,700)
	view=SubViewport.new()
	view.size=Vector2i(1600,1000)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game=load("res://main.tscn").instantiate()
	view.add_child(game)
	game.start_mode(0)
	game.set_physics_process(false)
	await capture("tutorial-welcome")
	for id in game.tutorial.STEPS:
		step(id)
		await capture("tutorial-"+id)
	view.size=Vector2i(1280,720)
	await capture("tutorial-compact")
	step("skill")
	await capture("tutorial-compact-skill")
	step("loot")
	await capture("tutorial-compact-loot")
	view.size=Vector2i(1050,760)
	await capture("tutorial-narrow")
	game.open_menu()
	await capture("tutorial-menu")
	game.queue_free()
	for i in 3: await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp",".tutorial.cfg",".tutorial.cfg.tmp"]: DirAccess.remove_absolute(profile_path+suffix)
	print("TUTORIAL GPU PREVIEW: "+("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
