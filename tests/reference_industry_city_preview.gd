extends SceneTree
class PreviewWorld extends "res://overpass_world.gd":
	func _ready() -> void:
		_make_materials()
		_lighting()
		_box(self,"PreviewDesert",Vector3(0,-.1,0),Vector3(1000,.2,1000),materials.sand,true)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var view := SubViewport.new()
	view.size=Vector2i(1600,1000)
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := PreviewWorld.new()
	view.add_child(world)
	var industry := Node3D.new()
	world.add_child(industry)
	preload("res://reference_industrial.gd").build(world,industry)
	var city := Node3D.new()
	city.position=Vector3(300,0,0)
	world.add_child(city)
	preload("res://reference_city.gd").build(world,city)
	world._batch_static_geometry()
	world.set_region_atmosphere(1)
	var camera := Camera3D.new()
	camera.fov=68
	camera.far=1000
	world.add_child(camera)
	camera.current=true
	var shots := [
		["reference-industrial",Vector3(14,5.0,80),Vector3(-17,18,-10)],
		["reference-city",Vector3(298,3.0,67),Vector3(302,9.0,-40)],
		["reference-cooling-tower",Vector3(8,6,8),Vector3(40,25,-37)]
	]
	for shot in shots:
		world.set_region_atmosphere(2 if shot[0]=="reference-city" else 1)
		camera.position=shot[1]
		camera.look_at(shot[2])
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://previews/"+shot[0]+".png")
	print("REFERENCE INDUSTRY CITY GPU PREVIEW: PASS")
	quit()
