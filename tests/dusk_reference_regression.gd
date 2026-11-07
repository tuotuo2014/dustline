extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, description: String) -> void:
	if not condition:
		failures+=1
		push_error(description)
	else: print("PASS: "+description)
func run() -> void:
	var world: Node3D=load("res://maps/dusk_settlement.tscn").instantiate()
	root.add_child(world)
	for i in 3: await physics_frame
	var site: Node3D=world.get_node("DuskSettlement")
	check(site!=null,"Twilight district constructed")
	check(site.find_children("WalkInTinHome*","Node3D",true,false).size()==12,"Twelve distinct walk-in tin homes")
	check(site.find_children("HollowResidentialRuin*","Node3D",true,false).size()==6,"Six hollow multi-storey ruined blocks")
	check(site.find_children("WindStirredLaundry*","MeshInstance3D",true,false).size()==48,"48 dynamically swaying cloth pieces")
	check(site.find_children("WarmCourtyardFirelight*","OmniLight3D",true,false).size()==2,"Two restrained shadow-casting courtyard lights")
	var shape := CapsuleShape3D.new()
	shape.radius=.4
	shape.height=1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=1
	var targets := [Vector3(0,0,65),Vector3(0,0,-82),Vector3(-42,0,-45),Vector3(42,0,-34),Vector3(-42,0,32)]
	for i in targets.size():
		query.transform=Transform3D(Basis.IDENTITY,site.global_position+targets[i]+Vector3(0,1.12,0))
		check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Mission endpoint %d clear"%i)
	for z in range(-80,81,8):
		for x in [0,-42,42]:
			query.transform=Transform3D(Basis.IDENTITY,site.global_position+Vector3(x,1.12,z))
			check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Travel lane x%d z%d clear"%[x,z])
	for home: Node3D in site.find_children("WalkInTinHome*","Node3D",true,false):
		query.transform=Transform3D(Basis.IDENTITY,home.to_global(Vector3(.07,1.12,3.6)))
		check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),home.name+" has open entrance")
	world.queue_free()
	for i in 4: await process_frame
	print("DUSK REFERENCE REGRESSION: %d failures"%failures)
	quit(1 if failures else 0)
