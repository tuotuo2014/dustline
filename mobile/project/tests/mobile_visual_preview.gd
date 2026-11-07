extends SceneTree
## Exact-size phone frames: viewport output is independent of a Mac's Retina scale.
var game: Node3D
var view: SubViewport
var suffix := "mobile"
var checks := 0
var failed := 0
var profile_path := "/tmp/dustline-phone-preview-%d.json"%OS.get_process_id()

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks+=1
	if not value:
		failed+=1
		push_error(label)

func frames(count := 5) -> void:
	for i in count: await process_frame

func capture(label: String) -> void:
	await frames(10)
	RenderingServer.force_draw(false)
	await process_frame
	var file := "res://previews/phone-%s-%s.png"%[suffix,label]
	var result := view.get_texture().get_image().save_png(file)
	check(result==OK,"Capture "+file)
	print("CAPTURE ",file)
	if game.active:
		var controls: CanvasLayer=game.player.mobile_controls
		check(controls.controls_visible,"Gameplay touch overlay is visible")
		for action in controls.button_regions:
			check(controls.safe_rect.encloses(controls.action_rect(action)),"Button inside safe area: "+action)
		for panel in [game.hud._vitals,game.hud._mission_box,game.hud._minimap]:
			if not panel.is_visible_in_tree(): continue
			for action in controls.button_regions:
				check(not panel.get_global_rect().intersects(controls.action_rect(action)),"HUD avoids "+str(action))

func run() -> void:
	RenderingServer.render_loop_enabled=false
	OS.set_environment("DUSTLINE_PROFILE_PATH",profile_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	for argument in OS.get_cmdline_user_args():
		if argument=="--compatibility": suffix="web"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://previews"))
	root.size=Vector2i(960,540)
	view=SubViewport.new()
	view.size=Vector2i(1280,720)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game=load("res://main.tscn").instantiate()
	view.add_child(game)
	# Offscreen captures must keep running when the test window loses OS focus.
	game.get_node("MobileRuntime").free()
	await capture("entry")
	game.start_mode(0)
	check(game.active,"Start enters active gameplay before screenshots")
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await capture("play")
	view.size=Vector2i(1560,720)
	await capture("wide")
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","")
	game.tutorial.start()
	await capture("tutorial")
	game.open_menu()
	await capture("pause")
	game.queue_free()
	await frames(3)
	print("MOBILE VISUAL: %d checks; %d failures"%[checks,failed])
	quit(1 if failed else 0)
