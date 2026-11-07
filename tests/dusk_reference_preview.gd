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
	var world: Node3D=load("res://maps/dusk_settlement.tscn").instantiate()
	view.add_child(world)
	world.set_region_atmosphere(3)
	var camera := Camera3D.new()
	camera.fov=64
	camera.far=1100
	view.add_child(camera)
	camera.current=true
	var origin := Vector3(0,world.ground_height(0,0),0)
	var shots := [
		["reference-dusk-street",Vector3(2.8,2.0,76),Vector3(-5,3.5,17)],
		["reference-dusk-courtyard",Vector3(-9,1.8,72),Vector3(-21,1.9,59)],
		["reference-dusk-overview",Vector3(112,84,123),Vector3(0,7,0)]]
	for shot in shots:
		camera.position=origin+shot[1]
		camera.look_at(origin+shot[2])
		for i in 14: await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://previews/"+shot[0]+".png")
	view.queue_free()
	for i in 4: await process_frame
	print("DUSK REFERENCE GPU PREVIEW: PASS")
	quit()
