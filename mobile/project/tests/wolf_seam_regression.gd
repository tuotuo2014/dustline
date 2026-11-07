extends SceneTree
## A closed skin must survive the complete gait, independently of the fur cards.

var failures: Array[String]=[]
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var wolf := preload("res://mutant_wolf.gd").new()
	root.add_child(wolf)
	var surface_count := 0
	var face_count := 0
	for instance in wolf.find_children("*","MeshInstance3D",true,false):
		for surface in instance.mesh.get_surface_count():
			var material: ShaderMaterial=instance.mesh.surface_get_material(surface)
			var kind := float(material.get_shader_parameter("surface_kind"))
			# Guard hairs are ribbons, and scars are decals laid over the closed skin.
			if is_equal_approx(kind,1.0) or is_equal_approx(kind,4.0): continue
			var arrays: Array=instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if kind>6.5:
				indices=indices.slice(0,indices.size()/7)
			face_count+=indices.size()/3
			surface_count+=1
			_assert_closed(vertices,indices,"%s surface %s" % [instance.get_parent().name,surface])
	_check(surface_count>40,"all solid rig surfaces inspected")
	# Probe caps separately: the exterior must face out even with back-face culling.
	var probe := preload("res://mutant_wolf.gd").new()
	probe._long_form(probe,[Vector4(-1,.2,.3,0),Vector4(1,.2,.3,0)],"probe",12,2)
	var profile: Dictionary=probe._batches[probe.get_instance_id()].surfaces.probe
	_assert_caps(profile,Vector3(0,0,-1),Vector3(0,0,1),12)
	probe._batches.clear()
	probe._taper(probe,[Vector3.ZERO,Vector3(0,-1,0)],[Vector2(.2,.2),Vector2(.1,.1)],"probe",12,2)
	var taper: Dictionary=probe._batches[probe.get_instance_id()].surfaces.probe
	_assert_caps(taper,Vector3.UP,Vector3.DOWN,12)
	probe.free()
	var max_hip_error := 0.0
	var max_joint_error := 0.0
	var max_body_motion := 0.0
	for frame in 1800:
		var speed: float=[0.0,1.0,2.0,3.6,5.6,7.5][mini(frame/300,5)]
		wolf.animate(1.0/60.0,speed,frame%240>180)
		max_body_motion=maxf(max_body_motion,wolf.torso.rotation.length())
		for leg in wolf.legs:
			var body_socket: Vector3=wolf.torso.transform*leg.hip
			max_hip_error=maxf(max_hip_error,body_socket.distance_to(leg.upper.position))
			max_hip_error=maxf(max_hip_error,body_socket.distance_to(leg.socket.position))
			var upper_end: Vector3=leg.upper.transform*Vector3(0,-float(leg.upper_length),0)
			var lower_end: Vector3=leg.lower.transform*Vector3(0,-float(leg.lower_length),0)
			max_joint_error=maxf(max_joint_error,upper_end.distance_to(leg.lower.position))
			max_joint_error=maxf(max_joint_error,lower_end.distance_to(leg.hock.position if leg.hind else leg.paw.position))
			if leg.hind:
				var hock_end: Vector3=leg.hock.transform*Vector3(0,-float(leg.hock.get_meta("rest_length")),0)
				max_joint_error=maxf(max_joint_error,hock_end.distance_to(leg.paw.position))
	_check(max_body_motion>.015,"test covers torso roll and pitch")
	_check(max_hip_error<.00001,"shoulder and hip sockets follow the complete body transform")
	_check(max_joint_error<.00001,"all four articulated limbs stay connected through walk, sprint and bite")
	print("WOLF SEAMS: %d checks, %d solid surfaces, %d base triangles, hip drift %.8f m, joint drift %.8f m" % [checks,surface_count,face_count,max_hip_error,max_joint_error])
	wolf.free()
	if failures.is_empty(): print("WOLF SEAMS PASS")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _assert_closed(vertices: PackedVector3Array, indices: PackedInt32Array, label: String) -> void:
	var weld: Dictionary={}
	var welded: Array[int]=[]
	welded.resize(vertices.size())
	for index in vertices.size():
		var key := vertices[index].snapped(Vector3(.000001,.000001,.000001))
		if not weld.has(key): weld[key]=weld.size()
		welded[index]=weld[key]
	var edges: Dictionary={}
	for face in range(0,indices.size(),3):
		var a := welded[indices[face]]
		var b := welded[indices[face+1]]
		var c := welded[indices[face+2]]
		if a==b or b==c or a==c: continue # Sphere poles share one geometric vertex.
		for pair in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var edge := Vector2i(mini(pair.x,pair.y),maxi(pair.x,pair.y))
			edges[edge]=edges.get(edge,0)+1
	var boundary := 0
	for count in edges.values():
		if count!=2: boundary+=1
	_check(boundary==0,"%s is watertight (%d open/nonmanifold edges)" % [label,boundary])

func _assert_caps(data: Dictionary, start_normal: Vector3, end_normal: Vector3, sides: int) -> void:
	for end in 2:
		var outward := start_normal if end==0 else end_normal
		var offset: int=data.i.size()-sides*6+end*sides*3
		for index in range(offset,offset+sides*3,3):
			var a: Vector3=data.v[data.i[index]]
			var b: Vector3=data.v[data.i[index+1]]
			var c: Vector3=data.v[data.i[index+2]]
			_check((c-a).cross(b-a).normalized().dot(outward)>.99,"solid end cap faces out")

func _check(condition: bool, label: String) -> void:
	checks+=1
	if not condition: failures.append(label)
