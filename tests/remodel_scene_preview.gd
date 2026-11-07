extends SceneTree
var game: Node3D
var view: SubViewport
var camera: Camera3D
var save_path := "/tmp/dustline-remodel-showcase-%d.json"%OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func capture(title: String, eye: Vector3, target: Vector3) -> void:
	camera.global_position=eye
	camera.look_at(target)
	camera.current=true
	for i in 6:
		await process_frame
		RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png("res://previews/remodel-"+title+".png")
	print("REMODEL CAPTURE "+title)
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	RenderingServer.render_loop_enabled=false
	view=SubViewport.new()
	view.size=Vector2i(1280,800)
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_2X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game=load("res://main.tscn").instantiate()
	view.add_child(game)
	game.set_physics_process(false)
	camera=Camera3D.new()
	camera.fov=55
	game.add_child(camera)
	for id in 4:
		game._on_region_selected(id)
		game.start_mode(0)
		game.player.set_physics_process(false)
		game.hud._hud.hide()
		var origins := [Vector3(13,3,8),Vector3(-25,6,28),Vector3(-6,3.7,52),Vector3(-12,4,61)]
		var targets := [Vector3(10,1.1,0),Vector3(-39,3,13),Vector3(-15,2,40),Vector3(-21,2,53)]
		await capture("scene-%d"%id,origins[id],targets[id])
		if id==3:
			var exit_pos: Vector3=game.extraction.global_position
			await capture("exit-beacon",exit_pos+Vector3(8,5,10),exit_pos+Vector3(0,5,0))
	game._on_region_selected(0)
	game.start_mode(0)
	game.hud._hud.hide()
	game.player.global_position=game._ground(Vector3(0,0,60))
	game.player.velocity=Vector3.ZERO
	game.player.set_physics_process(false)
	game.repel_mutants()
	for flare in game.flare_nodes: game.Effects.tick(flare,.55,1)
	await capture("signal-flare",game.player.global_position+Vector3(1.5,1.5,2.0),game.player.global_position+Vector3(0,.8,0))
	game.free()
	view.free()
	for suffix in ["",".bak",".tmp",".bak.tmp",".tutorial.cfg"]: DirAccess.remove_absolute(save_path+suffix)
	print("REMODEL SCENE GPU PREVIEW: PASS")
	quit()
