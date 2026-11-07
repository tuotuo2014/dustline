extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	root.size=Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	var player: CharacterBody3D=scene.get_node("Player")
	player.visible=false
	player.set_physics_process(false)
	scene.get_node("UI").visible=false
	var camera := Camera3D.new()
	camera.fov=68
	camera.far=500
	scene.add_child(camera)
	camera.position=Vector3(-1.5,2.2,21)
	camera.look_at(Vector3(-2,5,-42))
	camera.current=true
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/overpass-world.png")
	camera.position=Vector3(12,1.1,11)
	camera.look_at(Vector3(10,.9,-.7))
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/overpass-cars.png")
	camera.current=false
	player.get_node("Camera3D").current=true
	player.visible=true
	player.set_physics_process(true)
	scene.get_node("UI").visible=true
	for i in 25: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/overpass-gameplay.png")
	print("OVERPASS GPU RENDER: PASS")
	quit()
