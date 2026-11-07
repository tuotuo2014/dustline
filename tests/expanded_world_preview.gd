extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var view := SubViewport.new()
	view.size=Vector2i(1600,1000)
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var scene: Node3D=load("res://main.tscn").instantiate()
	view.add_child(scene)
	var player: Node3D=scene.get_node("Player")
	player.set_physics_process(false)
	var hud: CanvasLayer=scene.get_node("UI")
	hud._select_character(1)
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://previews/character-selection.png")
	hud.visible=false
	hud._character_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	player.visible=false
	var camera := Camera3D.new()
	camera.fov=64
	camera.far=850
	scene.add_child(camera)
	camera.current=true
	var shots := [
		["expanded-world",Vector3(158,155,233),Vector3(0,0,-18)],
		["wasteland-station",Vector3(-69,2.6,-34),Vector3(-92,2,-62)],
		["wasteland-foundry",Vector3(73,3.6,-51),Vector3(99,5,-84)],
		["wasteland-settlement",Vector3(-55,3,118),Vector3(-89,3,100)],
		["wasteland-checkpoint",Vector3(28,2.2,-133),Vector3(8,2,-159)]
	]
	for shot in shots:
		camera.position=shot[1]
		camera.look_at(shot[2])
		for i in 10: await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://previews/"+shot[0]+".png")
	print("EXPANDED WORLD GPU PREVIEW: PASS")
	quit()
