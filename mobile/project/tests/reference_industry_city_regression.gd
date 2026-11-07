extends SceneTree
class PreviewWorld extends "res://overpass_world.gd":
	func _ready() -> void:
		_make_materials()
		_box(self,"PreviewDesert",Vector3(0,-.1,0),Vector3(1000,.2,1000),materials.sand,true)
var passes := 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, description: String) -> void:
	if not ok:
		push_error(description)
		quit(1)
		return
	passes+=1
func clear_capsule(world: Node3D, point: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius=.32
	shape.height=1.85
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3(0,.97,0))
	query.collision_mask=1
	return world.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
func run() -> void:
	var world := PreviewWorld.new()
	root.add_child(world)
	var industry := Node3D.new()
	world.add_child(industry)
	preload("res://reference_industrial.gd").build(world,industry)
	var city := Node3D.new()
	city.position=Vector3(300,0,0)
	world.add_child(city)
	preload("res://reference_city.gd").build(world,city)
	await physics_frame
	await physics_frame
	for district in [industry,city]:
		for z in range(-80,81,4):
			for x in [-5.5,0.0,5.5]:
				verify(clear_capsule(world,district.position+Vector3(x,0,z)),"Boulevard blocked at "+str(district.position+Vector3(x,0,z)))
		for point in district.get_meta("safe_loot_positions"):
			verify(clear_capsule(world,district.position+point),"Loot spot blocked at "+str(district.position+point))
	for p in [Vector3(-21,0,-62),Vector3(68,0,-17),Vector3(-18,0,44)]:
		for x in [-6.0,0.0,6.0]:
			for z in [-6.0,0.0,6.0]:
				verify(clear_capsule(world,p+Vector3(x,0,z)),"Industrial relay clearance at "+str(p+Vector3(x,0,z)))
	for p in [Vector3(-72,0,-33),Vector3(72,0,14),Vector3(-73,0,61)]:
		for x in [-6.0,0.0,6.0]:
			for z in [-6.0,0.0,6.0]:
				verify(clear_capsule(world,city.position+p+Vector3(x,0,z)),"City relay clearance at "+str(p+Vector3(x,0,z)))
	world._batch_static_geometry()
	await physics_frame
	await physics_frame
	for district in [industry,city]:
		for z in range(-80,81,8): verify(clear_capsule(world,district.position+Vector3(0,0,z)),"Batched collision blocks corridor")
	print("REFERENCE DISTRICTS: ",passes," clearance checks passed")
	quit()
