extends SceneTree
var save_path := "/tmp/dustline-yellow-menu-%d.json"%OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	RenderingServer.render_loop_enabled=false
	var view := SubViewport.new()
	view.size=Vector2i(1600,1000)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game: Node3D=load("res://main.tscn").instantiate()
	view.add_child(game)
	for resolution in [Vector2i(1600,1000),Vector2i(1280,720),Vector2i(760,900)]:
		view.size=resolution
		game.hud._layout()
		for i in 12:
			await process_frame
			RenderingServer.force_draw(false)
		view.get_texture().get_image().save_png("res://previews/yellow-menu-%dx%d.png"%[resolution.x,resolution.y])
		print("MENU CAPTURE ",resolution)
	game.free()
	view.free()
	for suffix in ["",".bak",".tmp",".bak.tmp",".tutorial.cfg",".tutorial.cfg.tmp"]: DirAccess.remove_absolute(save_path+suffix)
	print("YELLOW MENU GPU: PASS")
	quit()
