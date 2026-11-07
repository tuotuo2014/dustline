extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failed+=1
		push_error(label)
	else: print("PASS: "+label)
func run() -> void:
	var game: Node3D=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_mode(0)
	game.damage_grace=9999
	var player: CharacterBody3D=game.get_node("Player")
	for i in 5: await physics_frame
	var world: Node3D=game.world
	var districts := 0
	for node in world.get_children():
		if node.has_meta("district_id"):
			districts+=1
			check(node.find_children("*","StaticBody3D",true,false).size()>5,"Solid architecture retains colliders in "+str(node.get_meta("district_id")))
	check(districts==5,"Five distinguishable playable districts")
	check(int(world.get_meta("static_batches"))<int(world.get_meta("original_static_pieces"))/3,"World detail is batched without removing physics")
	for x in [-205.0,205.0]:
		for z in [-205.0,205.0]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(x,40,z),Vector3(x,-10,z))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and absf(hit.position.y-world.ground_height(x,z))<.10,"Visual terrain agrees with collision at expanded corner "+str(Vector2(x,z)))
	player.global_position=Vector3(0,.2,90)
	player.velocity=Vector3.ZERO
	for i in 35: await physics_frame
	check(player.global_position.z>89 and player.is_on_floor(),"Player can stand and move beyond old 66m boundary")
	var sphere := SphereShape3D.new()
	sphere.radius=.34
	var blocked: Array[String]=[]
	for point in game.RELAY_POSITIONS+[game.EXIT_POSITION]+game.LOOT_POSITIONS:
		var param := PhysicsShapeQueryParameters3D.new()
		param.shape=sphere
		var approach: Vector3=point+Vector3(0,0,1.3) if point in game.RELAY_POSITIONS or point==game.EXIT_POSITION else point
		param.transform.origin=game._ground(approach)+Vector3(0,.9,0)
		param.collide_with_areas=false
		param.collision_mask=1
		param.exclude=[player.get_rid()]
		var hits := world.get_world_3d().direct_space_state.intersect_shape(param,8)
		if not hits.is_empty():
			for hit in hits: print("OCCUPIED ",point," by ",hit.collider.get_path())
			blocked.append(str(point))
	check(blocked.is_empty(),"Mission and salvage approach space is clear; blocked: "+str(blocked))
	print("EXPANDED WORLD REGRESSION: %d checks, %d failures"%[checks,failed])
	quit(1 if failed else 0)
