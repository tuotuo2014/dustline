extends SceneTree

const PROPS = preload("res://economy_props.gd")
var viewports: Array[SubViewport] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	RenderingServer.render_loop_enabled=false
	root.size = Vector2i(1200,1000)
	var kinds := ["coin","watch","chip","gold"]
	for index in kinds.size():
		var viewport := SubViewport.new()
		viewport.size = Vector2i(600,500)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("252a28")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("c1cdd2")
		environment.ambient_light_energy = .72
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.ssao_enabled = true
		environment.ssao_radius = .09
		environment.ssao_intensity = 1.3
		var env := WorldEnvironment.new()
		env.environment = environment
		world.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-49,-34,0)
		light.light_color = Color("ffdfb9")
		light.light_energy = 2.5
		light.shadow_enabled = true
		world.add_child(light)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-27,134,0)
		fill.light_color = Color("b4c8dc")
		fill.light_energy = 1.0
		world.add_child(fill)
		var item := PROPS.pickup(kinds[index])
		world.add_child(item)
		item.get_node("PickupLabel").position.y = .51
		assert(item.get_meta("value")>0)
		assert(item.get_meta("kind")==kinds[index])
		assert(is_equal_approx(item.get_node("PickupShape").shape.radius,.55))
		assert(item.find_children("*","StaticBody3D").is_empty())
		var floor_mesh := MeshInstance3D.new()
		var floor_shape := BoxMesh.new()
		floor_shape.size = Vector3(3,.03,3)
		floor_mesh.position.y = -.018
		floor_mesh.mesh = floor_shape
		floor_mesh.material_override = PROPS.PARTS._mat("74654f",0,.98)
		world.add_child(floor_mesh)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(.64,.78,-1.07)
		camera.look_at(Vector3(0,.19,.035))
		camera.fov = 33
		camera.current = true
		var display := TextureRect.new()
		display.position = Vector2(index%2*600,index/2*500)
		display.size = Vector2(600,500)
		display.texture = viewport.get_texture()
		root.add_child(display)
	for frame in 18: await process_frame
	if DisplayServer.get_name()=="headless":
		print("ECONOMY PROPS PASS: 4 distinct assets, values, pickup triggers and no solid blockers")
		quit()
		return
	RenderingServer.force_draw(false)
	var sheet := Image.create(1200,1000,false,Image.FORMAT_RGBA8)
	for i in viewports.size():
		var picture := viewports[i].get_texture().get_image()
		picture.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(picture,Rect2i(0,0,600,500),Vector2i(i%2*600,i/2*500))
	sheet.save_png("res://previews/remodel-valuable-pickups.png")
	print("ECONOMY PROPS PREVIEW PASS: previews/remodel-valuable-pickups.png")
	quit()
