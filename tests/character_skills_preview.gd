extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,760)
	var view := SubViewport.new()
	view.size=Vector2i(1600,1000)
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game: Node3D=load("res://main.tscn").instantiate()
	view.add_child(game)
	var camera := Camera3D.new()
	camera.fov=50
	game.add_child(camera)
	for id in 4:
		game.open_menu()
		game.hud._select_character(id)
		game.start_mode(0)
		game.player.global_position=game._ground(Vector3(-11,0,26))
		game.player.velocity=Vector3.ZERO
		game.player.get_node("Body").rotation.y=0
		game.damage_grace=9999
		for i in 15: await physics_frame
		if id==1:
			game.mutants[0].global_position=game.player.global_position+Vector3(-3,0,-2)
			game.mutants[0]._set_state("chase")
		game.health=70 if id==3 else 100
		game.use_character_skill()
		for i in (10 if id==1 or id==2 else 26): await physics_frame
		camera.current=true
		var center: Vector3=game.player.global_position+Vector3(0,1.05,0)
		camera.position=center+Vector3(4.7,2.1,-5.3)
		camera.look_at(center)
		game.set_physics_process(false)
		game.player.set_physics_process(false)
		game._update_hud()
		for i in 7: await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://previews/character-skill-%d.png"%id)
		game.set_physics_process(true)
		game.player.set_physics_process(true)
	game.open_menu()
	game.hud._select_character(3)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://previews/character-selection-skills.png")
	print("CHARACTER SKILLS GPU PREVIEW: PASS")
	quit()
