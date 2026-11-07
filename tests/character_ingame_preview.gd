extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.start_mode(0)
	root.size=Vector2i(1440,900)
	root.content_scale_size=Vector2i(1440,900)
	var player: CharacterBody3D=scene.get_node("Player")
	for i in 30: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/survivor-ingame-back.png")
	player.camera_yaw=PI+.38
	player.camera_distance=3.2
	for i in 15: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/survivor-ingame-front.png")
	Input.action_press("move_forward")
	for i in 28: await physics_frame
	Input.action_release("move_forward")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/survivor-ingame-walk.png")
	print("IN-GAME CHARACTER RENDER: PASS")
	quit()
