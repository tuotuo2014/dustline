extends SceneTree
## Actual character geometry under fixed portrait lighting, including a blink check.

var portraits: Array[SubViewport] = []
var rigs: Array[Node3D] = []

func _initialize() -> void:
	call_deferred("render_portraits")

func render_portraits() -> void:
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	for angle in 2:
		var viewport := SubViewport.new()
		viewport.size=Vector2i(640,800)
		viewport.own_world_3d=true
		viewport.msaa_3d=Viewport.MSAA_4X
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		portraits.append(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		var rig := preload("res://reference_survivor.gd").new()
		world.add_child(rig)
		rigs.append(rig)
		var environment := Environment.new()
		environment.background_mode=Environment.BG_COLOR
		environment.background_color=Color("202829")
		environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color=Color("c2c6c5")
		environment.ambient_light_energy=.46
		environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
		environment.ssao_enabled=true
		environment.ssao_radius=.10
		environment.ssao_intensity=1.0
		var environment_node := WorldEnvironment.new()
		environment_node.environment=environment
		world.add_child(environment_node)
		var light := DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-28,-34,0)
		light.light_color=Color("ffe1c4")
		light.light_energy=1.65
		light.shadow_enabled=true
		world.add_child(light)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees=Vector3(-16,140,0)
		fill.light_color=Color("bfd4df")
		fill.light_energy=.65
		world.add_child(fill)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov=23
		camera.position=Vector3(.0,1.731,-.92) if angle==0 else Vector3(.47,1.731,-.79)
		camera.look_at(Vector3(0,1.706,.0))
		camera.current=true
		var display := TextureRect.new()
		display.texture=viewport.get_texture()
		display.position=Vector2(angle*640,0)
		display.size=Vector2(640,800)
		root.add_child(display)
	for frame in 16: await process_frame
	await RenderingServer.frame_post_draw
	var sheet := Image.create(1280,800,false,Image.FORMAT_RGBA8)
	for i in portraits.size():
		var portrait := portraits[i].get_texture().get_image()
		portrait.convert(Image.FORMAT_RGBA8)
		portrait.save_png("res://previews/survivor-portrait-%s.png" % ("front" if i==0 else "angle"))
		sheet.blit_rect(portrait,Rect2i(0,0,640,800),Vector2i(i*640,0))
	sheet.save_png("res://previews/survivor-portraits.png")
	for rig in rigs:
		rig._blink_elapsed=.07
		rig.animate_face(0.0,0.0)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	portraits[0].get_texture().get_image().save_png("res://previews/survivor-portrait-blink.png")
	print("PORTRAIT PREVIEW PASS: front, three-quarter, closed eyelids")
	quit()
