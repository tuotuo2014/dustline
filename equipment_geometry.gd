extends RefCounted
## Small manufactured forms with real bevels and a controlled triangle budget.
static var _cache: Dictionary={}

static func beveled_box(size: Vector3, bevel: float) -> ArrayMesh:
	var key := str(size)+":"+str(bevel)
	if _cache.has(key): return _cache[key]
	var half := size*.5
	var b := clampf(bevel,.00001,minf(half.x,minf(half.y,half.z))*.90)
	var core := half-Vector3.ONE*b
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u := (axis+1)%3
		var v := (axis+2)%3
		var values_u := [-half[u],-core[u],core[u],half[u]]
		var values_v := [-half[v],-core[v],core[v],half[v]]
		for sign_value in [-1.0,1.0]:
			for y in 3:
				for x in 3:
					var order := [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)] if sign_value>0 else [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]
					for corner in order:
						var raw := Vector3.ZERO
						raw[axis]=half[axis]*sign_value
						raw[u]=values_u[x+corner.x]
						raw[v]=values_v[y+corner.y]
						var center := raw.clamp(-core,core)
						var normal := (raw-center).normalized()
						st.set_normal(normal)
						st.set_uv(Vector2(raw[u]/size[u]+.5,raw[v]/size[v]+.5))
						st.add_vertex(center+normal*b)
	st.index()
	var mesh := st.commit()
	_cache[key]=mesh
	return mesh

static func formed_shell(profile: Array[Vector4], sides: int = 16) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in profile.size()-1:
		for i in sides:
			for corner in [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
				var p := profile[row+corner.y]
				var a: float= TAU*float(i+corner.x)/sides
				var ca := cos(a)
				var sa := sin(a)
				st.set_uv(Vector2(float(i+corner.x)/sides,float(row+corner.y)/(profile.size()-1)))
				st.add_vertex(Vector3(signf(ca)*pow(absf(ca),.55)*p.y,signf(sa)*pow(absf(sa),.55)*p.z+p.w,p.x))
	for last in [false,true]:
		var p := profile[-1] if last else profile[0]
		for i in sides:
			var order := [i+1,i] if last else [i,i+1]
			st.set_uv(Vector2(.5,.5))
			st.add_vertex(Vector3(0,p.w,p.x))
			for j in order:
				var a: float= TAU*j/sides
				st.set_uv(Vector2(cos(a),sin(a))*.5+Vector2(.5,.5))
				st.add_vertex(Vector3(signf(cos(a))*pow(absf(cos(a)),.55)*p.y,signf(sin(a))*pow(absf(sin(a)),.55)*p.z+p.w,p.x))
	st.generate_normals()
	st.index()
	return st.commit()
