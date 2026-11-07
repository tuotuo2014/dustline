extends SceneTree
## Observe the real controller, collision floor and ground-locked feet in the map.
const STEP := 1.0/60.0
const OUT := "/tmp/dustline-ingame-walk"

class StepDriver extends Node:
	var player: CharacterBody3D
	var pending := 0
	func _physics_process(delta: float) -> void:
		if pending > 0:
			player._physics_process(delta)
			pending -= 1

func _initialize() -> void:
	call_deferred("run")

func freeze_callbacks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze_callbacks(child)

func run() -> void:
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(640,720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(OUT)
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_mode(0)
	var player: CharacterBody3D = game.player
	player.reset_for_round(game._ground(Vector3(0,0,60)) + Vector3.UP*.03)
	for frame in 35: await physics_frame
	freeze_callbacks(game)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(640,720)
	root.content_scale_size = Vector2i(640,720)
	game.get_node("UI").visible = false
	var driver := StepDriver.new()
	driver.player = player
	root.add_child(driver)
	var preview_view := SubViewport.new()
	preview_view.size = Vector2i(640,720)
	preview_view.msaa_3d = Viewport.MSAA_4X
	preview_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(preview_view)
	var camera := Camera3D.new()
	preview_view.add_child(camera)
	camera.current = true
	camera.fov = 32
	var font := load("res://assets/fonts/NotoSansSC.ttf")
	var label := Label.new()
	label.position = Vector2(20,20)
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",24)
	label.add_theme_color_override("font_color",Color("ffdc94"))
	preview_view.add_child(label)
	Input.action_press("move_forward")
	driver.pending = 90
	while driver.pending > 0: await process_frame
	var offsets := [Vector3(1.9,1.5,-3.7),Vector3(4.15,1.5,0),Vector3(2.1,1.5,3.6)]
	var titles := ["正面 · 实际行走", "侧面 · 实际行走", "背面 · 实际行走"]
	for frame in 48:
		driver.pending = 2
		while driver.pending > 0: await process_frame
		var sheet := Image.create(1920,720,false,Image.FORMAT_RGBA8)
		for view in 3:
			label.text = titles[view]
			camera.global_position = player.global_position + offsets[view]
			camera.look_at(player.global_position + Vector3(0,.95,0))
			await process_frame
			RenderingServer.force_draw(false)
			var image := camera.get_viewport().get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(image,Rect2i(0,0,640,720),Vector2i(view*640,0))
		var path := OUT+"/%03d.png" % frame
		sheet.save_png(path)
		if frame%12==0: print("IN-GAME WALK %s; phase %.3f; gait %.2f; position %s" % [path,player.character.phase/TAU,player.character.gait,player.position])
	Input.action_release("move_forward")
	game.queue_free()
	await process_frame
	print("IN-GAME WALK CAPTURE: 48 frames, real movement and terrain")
	quit()
