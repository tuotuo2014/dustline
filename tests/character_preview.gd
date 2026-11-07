extends SceneTree

func _initialize() -> void:
	call_deferred("render_character")

func render_character() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var character := preload("res://reference_survivor.gd").new()
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
	camera.fov=34
	world.add_child(camera)
	camera.position=Vector3(1.7,1.6,-3.9)
	camera.look_at(Vector3(0,.94,0))
	camera.current=true
	root.size=Vector2i(1100,1100)
	root.content_scale_size=Vector2i(1100,1100)
	root.msaa_3d=Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute("res://previews")
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/survivor-front.png")
	camera.position=Vector3(-1.6,1.55,3.9)
	camera.look_at(Vector3(0,.94,0))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/survivor-back.png")
	camera.position=Vector3(.27,1.73,-.85)
	camera.look_at(Vector3(0,1.72,-.015))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/survivor-face.png")
	print("CHARACTER PREVIEWS SAVED")
	quit()
