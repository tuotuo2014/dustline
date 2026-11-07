extends SceneTree

var failures: Array[String]=[]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var wolf := load("res://mutant_wolf.gd").new() as Node3D
	root.add_child(wolf)
	_check(wolf.legs.size()==4,"four articulated limbs")
	_check(wolf.ears.size()==2,"two ears")
	_check(wolf.head.position.z<-.9,"wolf faces negative Z")
	var mesh_count := 0
	for instance in wolf.find_children("*","MeshInstance3D",true,false):
		mesh_count+=1
		for surface in instance.mesh.get_surface_count():
			var arrays: Array=instance.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				if not vertex.is_finite():
					failures.append("nonfinite mesh vertex")
					break
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				if not normal.is_finite():
					failures.append("nonfinite mesh normal")
					break
	_check(mesh_count<30,"geometry merged by rig part")
	var highest_paw := .0
	var previous_jaw := wolf.jaw.rotation.x as float
	for frame in 900:
		var speed := 0.0 if frame<60 else (2.0 if frame<400 else 5.3)
		wolf.animate(1.0/60.0,speed,frame>700)
		for leg in wolf.legs:
			highest_paw=maxf(highest_paw,leg.paw.position.y)
			_check(leg.paw.position.y>=.104,"paw stays above ground")
			var lower: Node3D=leg.lower
			var end := lower.transform*Vector3(0,-float(leg.lower_length),0)
			var target: Vector3=leg.hock.position if leg.hind else leg.paw.position
			_check(end.distance_to(target)<.001,"lower limb reaches foot or hock")
	_check(highest_paw>.30,"moving gait lifts paws")
	_check(absf(wolf.jaw.rotation.x-previous_jaw)>.03,"attack articulates jaw")
	_check(wolf.head.transform.is_finite(),"head transform remains finite")
	if failures.is_empty():
		print("MUTANT_VISUAL PASS: rig, finite meshes, grounded paws, limb continuity, walking, running and attack jaw.")
	else:
		for failure in failures: push_error(failure)
	wolf.queue_free()
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	if not condition and not failures.has(label): failures.append(label)
