extends RefCounted
## Geometry helpers for the second character sculpt. No animation nodes are merged.

static func sewn_bag(size: Vector3) -> Dictionary:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const ROWS := 12
	const SIDES := 32
	for row in ROWS+1:
		var t := row/float(ROWS)
		var y := (t-.5)*size.y
		var fullness := .88+.12*sin(t*PI)
		var bottom := smoothstep(0.0,.15,t)
		var top := 1.0-smoothstep(.85,1.0,t)
		for col in SIDES+1:
			var a := TAU*col/SIDES
			var x := signf(cos(a))*pow(absf(cos(a)),.37)*size.x*.5*fullness
			var z := signf(sin(a))*pow(absf(sin(a)),.34)*size.z*.5
			z*=.78+.22*minf(bottom,top)
			# A soft front panel sags into the gusset while sewn corners pull taut.
			var front := pow(maxf(0.0,-sin(a)),4)
			z-=front*sin(t*PI)*size.z*.07
			z+=front*exp(-pow((t-.18)/.10,2))*.025*size.z
			x+=sin(a*7+t*4)*sin(t*PI)*size.x*.012
			vertices.append(Vector3(x,y,z))
			if row<ROWS and col<SIDES:
				var k := row*(SIDES+1)+col
				indices.append_array([k,k+1,k+SIDES+2,k,k+SIDES+2,k+SIDES+1])
	for end in [0,ROWS]:
		var k := vertices.size()
		vertices.append(Vector3(0,(end/float(ROWS)-.5)*size.y,0))
		for col in SIDES:
			var edge: int=end*(SIDES+1)+col
			if end==0: indices.append_array([k,edge+1,edge])
			else: indices.append_array([k,edge,edge+1])
	return {"vertices":vertices,"indices":indices}

static func append_hair_lock(buffers: Dictionary,points: PackedVector3Array,width: float,color: Color) -> void:
	var base: int=buffers.vertices.size()
	const SIDES := 8
	for row in points.size():
		var t := row/float(points.size()-1)
		var tangent := (points[mini(row+1,points.size()-1)]-points[maxi(0,row-1)]).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		if side.length_squared()<.01: side=Vector3.RIGHT
		var outward := side.cross(tangent).normalized()
		var taper := pow(1.0-t,.72)*lerpf(.30,1.0,smoothstep(0.0,.12,t))
		for col in SIDES:
			var a := TAU*col/SIDES
			var across := cos(a)
			var normal := (side*across*.3+outward*sin(a)).normalized()
			buffers.vertices.append(points[row]+side*across*width*taper+outward*sin(a)*.0012*taper)
			buffers.normals.append(normal)
			buffers.colors.append(color*(.91+.09*cos(a*4)))
			if row<points.size()-1:
				var k := base+row*SIDES+col
				var next := base+row*SIDES+(col+1)%SIDES
				buffers.indices.append_array([k,next,next+SIDES,k,next+SIDES,k+SIDES])

static func batch_rigid_details(root: Node3D) -> void:
	# Restrict merging to rigid trim under the same pivot and material. Fingers,
	# eyelid morphs, eyes, cloth panels, attachments and all public rig names stay.
	for child in root.get_children():
		if child is Node3D: batch_rigid_details(child)
	var groups: Dictionary={}
	for child in root.get_children():
		if not child is MeshInstance3D or child.mesh==null or child.get_child_count()>0: continue
		if not child.visible: continue
		if child.mesh is ArrayMesh and child.mesh.get_blend_shape_count()>0: continue
		var label: String=child.get_meta("part_name",str(child.name))
		var trim := false
		for tag in ["Stitch","Seam","Webbing","Rivet","Snap","Button","Loop","MeshSpoke","MeshRing","GearTooth","GearSpoke","BrassSupplyCell","SoleTread","OpticScrew","ShoulderBolt","HandRivet"]:
			if tag in label: trim=true
		if not trim or child.material_override==null: continue
		var id: int=child.material_override.get_instance_id()
		if not groups.has(id): groups[id]=[]
		groups[id].append(child)
	for group in groups.values():
		if group.size()<2: continue
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		var names := PackedStringArray()
		for node: MeshInstance3D in group:
			names.append(node.name)
			var normal_basis := node.transform.basis.inverse().transposed()
			for surface in node.mesh.get_surface_count():
				var arrays: Array=node.mesh.surface_get_arrays(surface)
				var offset := vertices.size()
				var mesh_vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var mesh_normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				for i in mesh_vertices.size():
					vertices.append(node.transform*mesh_vertices[i])
					normals.append((normal_basis*mesh_normals[i]).normalized())
				if arrays[Mesh.ARRAY_INDEX]!=null:
					for i in arrays[Mesh.ARRAY_INDEX]: indices.append(offset+i)
				else:
					for i in mesh_vertices.size(): indices.append(offset+i)
		var arrays: Array=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_INDEX]=indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var merged := MeshInstance3D.new()
		merged.name="SewnAndMachinedDetails"
		merged.mesh=mesh
		merged.material_override=group[0].material_override
		merged.set_meta("merged_parts",names)
		root.add_child(merged)
		for node in group: node.free()

static func formed_armor(size: Vector3) -> Dictionary:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var profiles := [Vector3(-.5,.38,.26),Vector3(-.46,.72,.62),Vector3(-.34,.91,.87),Vector3(-.10,1.0,1.0),Vector3(.19,.96,.95),Vector3(.37,.78,.76),Vector3(.47,.55,.45),Vector3(.50,.24,.12)]
	const SIDES := 32
	for row in profiles.size():
		var p: Vector3=profiles[row]
		for col in SIDES+1:
			var a := TAU*col/SIDES
			var x := signf(cos(a))*pow(absf(cos(a)),.76)*size.x*.5*p.y
			var z := sin(a)*size.z*.5*p.z
			# Pressed central rib and flattened side flanges change the silhouette.
			z-=pow(maxf(0,-sin(a)),8)*size.z*.08*sin((p.x+.5)*PI)
			vertices.append(Vector3(x,p.x*size.y,z))
			if row<profiles.size()-1 and col<SIDES:
				var k := row*(SIDES+1)+col
				indices.append_array([k,k+1,k+SIDES+2,k,k+SIDES+2,k+SIDES+1])
	for end in [0,profiles.size()-1]:
		var k := vertices.size()
		vertices.append(Vector3(0,profiles[end].x*size.y,0))
		for col in SIDES:
			var edge: int=end*(SIDES+1)+col
			if end==0: indices.append_array([k,edge+1,edge])
			else: indices.append_array([k,edge,edge+1])
	return {"vertices":vertices,"indices":indices}
