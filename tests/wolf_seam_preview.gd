extends SceneTree

func _initialize() -> void:
	call_deferred("render_wolf")

func render_wolf() -> void:
	RenderingServer.render_loop_enabled=false
	var world := Node3D.new()
	root.add_child(world)
	var character := preload("res://mutant_wolf.gd").new()
	world.add_child(character)
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("1c2426")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("b5c4ca")
	environment.ambient_light_energy=.5
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled=true
	environment.ssao_radius=.3
	environment.ssao_intensity=1.25
	var env := WorldEnvironment.new()
	env.environment=environment
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-38,-28,0)
	light.light_color=Color("ffdfbc")
	light.light_energy=2.2
	light.shadow_enabled=true
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-18,145,0)
	fill.light_color=Color("b7d5e1")
	fill.light_energy=.8
	world.add_child(fill)
	var plane := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size=Vector2(200,200)
	plane.mesh=floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color=Color("353c3a")
	floor_mat.roughness=.95
	plane.material_override=floor_mat
	world.add_child(plane)
	var camera := Camera3D.new()
	camera.fov=37
	world.add_child(camera)
	camera.position=Vector3(4.4,2.65,-5.8)
	camera.look_at(Vector3(0,1.14,.05))
	camera.current=true
	root.size=Vector2i(1100,1100)
	root.content_scale_size=Vector2i(1100,1100)
	root.msaa_3d=Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute("res://previews")
	var shots := [
		["idle-left",Vector3(5.4,1.55,.2),0.0,false,0],
		["idle-right",Vector3(-5.4,1.55,.2),0.0,false,0],
		["walk-left",Vector3(5.4,1.55,.2),1.7,false,43],
		["run-right",Vector3(-5.4,1.55,.2),5.6,false,61],
		["run-left",Vector3(5.4,1.55,.2),5.6,false,11],
		["bite",Vector3(3.8,1.65,-4.5),5.6,true,25],
		["underside",Vector3(4.7,.25,.1),5.6,false,21]
	]
	for shot in shots:
		for frame in int(shot[4]): character.animate(1.0/60.0,shot[2],shot[3])
		camera.position=shot[1]
		camera.look_at(Vector3(0,1.14,.05))
		for frame in 8: await process_frame
		RenderingServer.force_draw(false)
		var path := "res://previews/wolf-seams-%s.png" % shot[0]
		root.get_texture().get_image().save_png(path)
		print("WOLF SEAMS CAPTURE %s" % shot[0])
	print("WOLF SEAMS GPU PREVIEWS SAVED")
	world.queue_free()
	await process_frame
	quit()
