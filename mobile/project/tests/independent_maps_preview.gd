extends SceneTree
var save_path := "/private/tmp/dustline-map-preview-%d.json"%OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	RenderingServer.render_loop_enabled=false
	var view := SubViewport.new()
	view.size=Vector2i(1280,800)
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_2X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game: Node3D=load("res://main.tscn").instantiate()
	view.add_child(game)
	game.set_physics_process(false)
	for id in 4:
		game._on_region_selected(id)
		game.start_mode(0)
		game.player.set_physics_process(false)
		game.player.camera_pitch=-.18
		game.player._update_camera()
		game._update_hud()
		for frame in 12:
			await process_frame
			RenderingServer.force_draw(false)
		view.get_texture().get_image().save_png("res://previews/independent-map-%d.png"%id)
		print("INDEPENDENT MAP RENDER: ",id," ",game.world.scene_file_path)
	game.open_menu()
	for frame in 5:
		await process_frame
		RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png("res://previews/independent-map-menu.png")
	game.free()
	view.free()
	for suffix in ["",".bak",".tmp",".bak.tmp",".tutorial.cfg"]: DirAccess.remove_absolute(save_path+suffix)
	print("INDEPENDENT MAPS GPU PREVIEW: PASS")
	quit()
