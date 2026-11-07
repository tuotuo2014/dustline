extends RefCounted
## Shared authored mesh profiles. Geometry stays inside the existing collision bounds.
## Every face carries a geometric normal; bevels, folds and openings survive static batching.
static var cache: Dictionary = {}

static func _face(v: PackedVector3Array, n: PackedVector3Array, ix: PackedInt32Array, points: Array, outward: Vector3) -> void:
	var start := v.size()
	var normal: Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
	if normal.dot(outward)<0.0:
		points.reverse()
		normal=-normal
	for p: Vector3 in points:
		v.append(p)
		n.append(normal)
	for i in range(1,points.size()-1): ix.append_array([start,start+i,start+i+1])

static func _mesh(v: PackedVector3Array, n: PackedVector3Array, ix: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=v
	arrays[Mesh.ARRAY_NORMAL]=n
	arrays[Mesh.ARRAY_INDEX]=ix
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func solid(size: Vector3, label: String) -> ArrayMesh:
	var lower := label.to_lower()
	if "curvedshellfragment" in lower: return curved_fragment(size)
	if ("beam" in lower or "girder" in lower or "piperackcolumn" in lower or "loadbearingcolumn" in lower) and size[size.max_axis_index()]>size[size.min_axis_index()]*3.0:
		return rolled_section(size)
	if "floorslab" in lower or "balconyslab" in lower or "concretedeck" in lower:
		return fractured_slab(size)
	if "roof" in lower and ("bus" in lower or "cab" in lower): return roof(size)
	var sheet := ("sheet" in lower or "tinroof" in lower or "awning" in lower or "factoryroof" in lower or "canopypanel" in lower) and size.min_axis_index()!=size.max_axis_index()
	if sheet and size[size.min_axis_index()]<.16 and size[size.max_axis_index()]>.6:
		return corrugated(size)
	var damaged := "broken" in lower or "chipped" in lower or "fractured" in lower or "scarred" in lower or "jagged" in lower
	if damaged and size.z<1.0 and size.x>.45 and size.y>.4:
		return broken_wall(size,int(label.hash())%7)
	var edge := minf(size[size.min_axis_index()]*.17,.085)
	if "roof" in lower or "hood" in lower or "bumper" in lower or "body" in lower: edge=minf(size[size.min_axis_index()]*.34,.18)
	if "column" in lower or "pier" in lower: edge=minf(size[size.min_axis_index()]*.19,.12)
	var key := "box:%s:%.3f"%[size,edge]
	if cache.has(key): return cache[key]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ix := PackedInt32Array()
	var h := size*.5
	# Six inset faces, twelve chamfer strips and eight cut corners form a closed solid.
	for axis in 3:
		var b := (axis+1)%3
		var c := (axis+2)%3
		for sign_value in [-1.0,1.0]:
			var points: Array=[]
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p := Vector3.ZERO
				p[axis]=sign_value*h[axis]
				p[b]=corner.x*(h[b]-edge)
				p[c]=corner.y*(h[c]-edge)
				points.append(p)
			var outward := Vector3.ZERO
			outward[axis]=sign_value
			_face(v,n,ix,points,outward)
	for axis in 3:
		var b := (axis+1)%3
		var c := (axis+2)%3
		for sb in [-1.0,1.0]:
			for sc in [-1.0,1.0]:
				var points: Array=[]
				for corner in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
					var p := Vector3.ZERO
					p[axis]=corner.x*(h[axis]-edge)
					p[b]=sb*(h[b]-edge*corner.y)
					p[c]=sc*(h[c]-edge*(1.0-corner.y))
					points.append(p)
				var outward := Vector3.ZERO
				outward[b]=sb
				outward[c]=sc
				_face(v,n,ix,points,outward)
	for sx in [-1.0,1.0]:
		for sy in [-1.0,1.0]:
			for sz in [-1.0,1.0]:
				var sign_value := Vector3(sx,sy,sz)
				_face(v,n,ix,[Vector3(h.x,h.y-edge,h.z-edge)*sign_value,Vector3(h.x-edge,h.y,h.z-edge)*sign_value,Vector3(h.x-edge,h.y-edge,h.z)*sign_value],sign_value)
	var mesh := _mesh(v,n,ix)
	cache[key]=mesh
	return mesh

static func extrusion(outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ix := PackedInt32Array()
	var triangulated := Geometry2D.triangulate_polygon(outline)
	for sign_value in [-1.0,1.0]:
		for t in range(0,triangulated.size(),3):
			var points: Array=[]
			for j in 3:
				var p := outline[triangulated[t+j]]
				points.append(Vector3(p.x,p.y,sign_value*thickness*.5))
			_face(v,n,ix,points,Vector3(0,0,sign_value))
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var outward := Vector3(b.y-a.y,a.x-b.x,0)
		_face(v,n,ix,[Vector3(a.x,a.y,-thickness*.5),Vector3(b.x,b.y,-thickness*.5),Vector3(b.x,b.y,thickness*.5),Vector3(a.x,a.y,thickness*.5)],outward)
	return _mesh(v,n,ix)

static func broken_wall(size: Vector3, identity: int) -> ArrayMesh:
	var x := size.x*.5
	var y := size.y*.5
	var cut := minf(size.y*.24,size.x*.18)
	var phase := float(abs(identity)%4)*.025
	var outline := PackedVector2Array([Vector2(-x,-y),Vector2(x,-y),Vector2(x,y-cut*.45),Vector2(x*.64,y-cut),Vector2(x*.53,y-cut*.40),Vector2(x*.13,y-cut*(.42+phase)),Vector2(-x*.18,y),Vector2(-x*.37,y-cut*.28),Vector2(-x,y-cut*.14)])
	return extrusion(outline,size.z)

static func corrugated(size: Vector3) -> ArrayMesh:
	var key := "fold:%s"%size
	if cache.has(key): return cache[key]
	var axis := size.min_axis_index()
	var horizontal := 0 if axis!=0 else 2
	var vertical := 2 if axis==1 else 1
	var width := size[horizontal]
	var height := size[vertical]
	var thickness := maxf(.008,minf(.016,size[axis]*.28))
	var depth := maxf(.009,size[axis]*.43)
	var strips := clampi(int(width/.18)*4,8,160)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ix := PackedInt32Array()
	for i in strips:
		for front in [-1.0,1.0]:
			var points: Array=[]
			for corner in [Vector2(i,-1),Vector2(i+1,-1),Vector2(i+1,1),Vector2(i,1)]:
				var p := Vector3.ZERO
				p[horizontal]=(corner.x/strips-.5)*width
				p[vertical]=corner.y*height*.5
				p[axis]=sin(corner.x*PI*.5)*depth+front*thickness*.5
				# Slight folded lip gives recycled sheet a physically rolled edge.
				if int(corner.x)==0 or int(corner.x)==strips: p[axis]*=.35
				points.append(p)
			var outward := Vector3.ZERO
			outward[axis]=front
			_face(v,n,ix,points,outward)
		for border in [-1.0,1.0]:
			var points: Array=[]
			for corner in [Vector2(i,-1),Vector2(i+1,-1),Vector2(i+1,1),Vector2(i,1)]:
				var p := Vector3.ZERO
				p[horizontal]=(corner.x/strips-.5)*width
				p[vertical]=border*height*.5
				var fold := sin(corner.x*PI*.5)*depth
				var lip := .35 if int(corner.x)==0 or int(corner.x)==strips else 1.0
				p[axis]=(fold+corner.y*thickness*.5)*lip
				points.append(p)
			var outward := Vector3.ZERO
			outward[vertical]=border
			_face(v,n,ix,points,outward)
	for border in [-1.0,1.0]:
		var points: Array=[]
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var p := Vector3.ZERO
			p[horizontal]=border*width*.5
			p[vertical]=corner.x*height*.5
			var fold := 0.0 if border<0 else sin(strips*PI*.5)*depth
			p[axis]=(fold+corner.y*thickness*.5)*.35
			points.append(p)
		var outward := Vector3.ZERO
		outward[horizontal]=border
		_face(v,n,ix,points,outward)
	var mesh := _mesh(v,n,ix)
	cache[key]=mesh
	return mesh

static func lathe(radius: float, height: float, label: String, segments := 32) -> ArrayMesh:
	var lower := label.to_lower()
	var profile := PackedVector2Array()
	var h := height*.5
	if "domedcircularend" in lower:
		profile=PackedVector2Array([Vector2(radius,-h*.16),Vector2(radius*.97,h*.12),Vector2(radius*.88,h*.46),Vector2(radius*.68,h*.77),Vector2(radius*.39,h*.94),Vector2(radius*.02,h)])
	elif "barrel" in lower or "drum" in lower:
		profile=PackedVector2Array([Vector2(radius*.90,-h),Vector2(radius,-h*.94),Vector2(radius*.965,-h*.82),Vector2(radius*.985,-h*.55),Vector2(radius*1.01,-h*.50),Vector2(radius*.98,-h*.44),Vector2(radius*.98,h*.44),Vector2(radius*1.01,h*.50),Vector2(radius*.985,h*.55),Vector2(radius*.965,h*.82),Vector2(radius,h*.94),Vector2(radius*.90,h)])
	elif "tank" in lower or "vessel" in lower or "domed" in lower:
		var shoulder := minf(height*.18,radius*.30)
		profile=PackedVector2Array([Vector2(radius*.82,-h),Vector2(radius*.95,-h+shoulder*.35),Vector2(radius,-h+shoulder),Vector2(radius,h-shoulder),Vector2(radius*.95,h-shoulder*.35),Vector2(radius*.82,h)])
	elif "chimney" in lower or "stack" in lower and height>4.0:
		profile=PackedVector2Array([Vector2(radius,-h),Vector2(radius*.98,-h*.8),Vector2(radius*.91,h*.8),Vector2(radius*.90,h)])
	else:
		var edge := minf(radius*.09,height*.19)
		profile=PackedVector2Array([Vector2(radius-edge,-h),Vector2(radius,-h+edge),Vector2(radius,h-edge),Vector2(radius-edge,h)])
	return revolve(profile,segments,true)

static func revolve(profile: PackedVector2Array, segments: int, capped: bool) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ix := PackedInt32Array()
	for row in profile.size():
		var tangent: Vector2=profile[mini(row+1,profile.size()-1)]-profile[maxi(0,row-1)]
		var normal := Vector2(tangent.y,-tangent.x).normalized()
		for i in segments+1:
			var angle := i*TAU/segments
			v.append(Vector3(cos(angle)*profile[row].x,profile[row].y,sin(angle)*profile[row].x))
			n.append(Vector3(cos(angle)*normal.x,normal.y,sin(angle)*normal.x))
			if row<profile.size()-1 and i<segments:
				var k := row*(segments+1)+i
				if profile[row].x>.00001: ix.append_array([k,k+1,k+segments+2])
				if profile[row+1].x>.00001: ix.append_array([k,k+segments+2,k+segments+1])
	if capped:
		for row in [0,profile.size()-1]:
			var points: Array=[]
			for i in segments:
				var angle := i*TAU/segments
				points.append(Vector3(cos(angle)*profile[row].x,profile[row].y,sin(angle)*profile[row].x))
			_face(v,n,ix,points,Vector3.DOWN if row==0 else Vector3.UP)
	return _mesh(v,n,ix)

static func roof(size: Vector3) -> ArrayMesh:
	# Broad coach roof has a shallow curved crown and folded rain gutters.
	var outline := PackedVector2Array([Vector2(-size.x*.5,-size.y*.5),Vector2(size.x*.5,-size.y*.5),Vector2(size.x*.49,size.y*.05),Vector2(size.x*.40,size.y*.42),Vector2(0,size.y*.5),Vector2(-size.x*.40,size.y*.42),Vector2(-size.x*.49,size.y*.05)])
	return extrusion(outline,size.z)

static func wheel(radius: float, width: float) -> ArrayMesh:
	var profile := PackedVector2Array([Vector2(radius*.55,-width*.45),Vector2(radius*.74,-width*.55),Vector2(radius*.91,-width*.49),Vector2(radius,-width*.29),Vector2(radius,width*.29),Vector2(radius*.91,width*.49),Vector2(radius*.74,width*.55),Vector2(radius*.55,width*.45),Vector2(radius*.55,-width*.45)])
	return revolve(profile,32,false)

static func _oriented(mesh: ArrayMesh, basis: Basis) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		vertices[i]=basis*vertices[i]
		normals[i]=basis*normals[i]
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

static func rolled_section(size: Vector3) -> ArrayMesh:
	var axis := size.max_axis_index()
	var width := size.x if axis!=0 else size.z
	var height := size.y if axis!=1 else size.z
	var x := width*.5
	var y := height*.5
	var flange := minf(width,height)*.17
	var web := minf(width,height)*.15
	var outline := PackedVector2Array([Vector2(-x,-y),Vector2(x,-y),Vector2(x,-y+flange),Vector2(web,-y+flange),Vector2(web,y-flange),Vector2(x,y-flange),Vector2(x,y),Vector2(-x,y),Vector2(-x,y-flange),Vector2(-web,y-flange),Vector2(-web,-y+flange),Vector2(-x,-y+flange)])
	var mesh := extrusion(outline,size[axis])
	if axis==0: return _oriented(mesh,Basis(Vector3.UP,PI*.5))
	if axis==1: return _oriented(mesh,Basis(Vector3.RIGHT,PI*.5))
	return mesh

static func fractured_slab(size: Vector3) -> ArrayMesh:
	var x := size.x*.5
	var z := size.z*.5
	var cut := minf(minf(size.x,size.z)*.06,.8)
	var outline := PackedVector2Array([Vector2(-x+cut,-z),Vector2(x,-z),Vector2(x,z-cut),Vector2(x-cut*.5,z-cut*.75),Vector2(x-cut,z),Vector2(-x+cut*.3,z),Vector2(-x,z-cut*.2),Vector2(-x,-z+cut*.5)])
	return _oriented(extrusion(outline,size.y),Basis(Vector3.RIGHT,PI*.5))

static func hollow_bucket(radius: float, height: float) -> ArrayMesh:
	var profile := PackedVector2Array([Vector2(radius*.78,0),Vector2(radius,height*.94),Vector2(radius*.99,height),Vector2(radius*.91,height),Vector2(radius*.90,height*.94),Vector2(radius*.70,.035),Vector2(0,.035)])
	return revolve(profile,28,false)

static func faceted(vertices: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ix := PackedInt32Array()
	for i in range(0,indices.size(),3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i+1]]
		var c := vertices[indices[i+2]]
		_face(v,n,ix,[a,b,c],(c-a).cross(b-a))
	return _mesh(v,n,ix)

static func curved_fragment(size: Vector3) -> ArrayMesh:
	var outline := PackedVector2Array()
	for i in 9:
		var t := i/8.0
		outline.append(Vector2((t-.5)*size.x,sin(t*PI)*size.y*.75-size.y*.25))
	for i in range(8,-1,-1):
		var t := i/8.0
		outline.append(Vector2((t-.5)*size.x,sin(t*PI)*size.y*.75-size.y*.48))
	return extrusion(outline,size.z)
