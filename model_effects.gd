extends RefCounted
## Bounded, layered effect geometry. All temporal updates are driven by gameplay clocks.
const FX_SHADER = preload("res://model_effects.gdshader")

static func material(color: Color, mode: int = 0, intensity: float = 1.4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader=FX_SHADER
	m.set_shader_parameter("tint",color)
	m.set_shader_parameter("effect_mode",mode)
	m.set_shader_parameter("energy",intensity)
	return m

static func mesh_node(parent: Node3D, title: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name=title
	node.mesh=mesh
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func band(radius: float, width: float, height: float, segments: int = 72, sweep: float = TAU, start: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
			var u: float= (float(i)+corner.x)/segments
			var a: float= start+u*sweep
			var r: float= radius+(corner.y-.5)*width
			st.set_uv(Vector2(u,corner.y))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(cos(a)*r,height,sin(a)*r))
	return st.commit()

static func ribbon(points: Array[Vector3], width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size()-1:
		var tangent := (points[i+1]-points[i]).normalized()
		var across := tangent.cross(Vector3.FORWARD if absf(tangent.z)<.85 else Vector3.UP).normalized()*width*.5
		var corners: Array[Vector3]=[points[i]-across,points[i]+across,points[i+1]+across,points[i+1]-across]
		for index in [0,1,2,0,2,3]:
			st.set_uv(Vector2(float(i+(1 if index>1 else 0))/(points.size()-1),1.0 if index in [1,2] else 0.0))
			st.set_normal(tangent.cross(across).normalized())
			st.add_vertex(corners[index])
	return st.commit()

static func wave(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name="LayeredShockwave"
	mesh_node(root,"LeadingPressureRim",band(1,.035,0),material(color,0,1.65))
	mesh_node(root,"DustWake",band(.94,.16,-.02),material(Color("a78d6b"),1,.15))
	for i in 5:
		mesh_node(root,"BrokenIonArc%d"%i,band(.84,.018,.09,14,.72,float(i)*TAU/5),material(color,2,1.1))
	return root

static func dash(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name="SlipstreamAfterimage"
	for i in 5:
		var x := (float(i)-2.0)*.105
		var points: Array[Vector3]=[Vector3(x,-.65,.38),Vector3(x*.95,-.1,.16),Vector3(x*.7,.48,0),Vector3(x*.45,.67,.12)]
		mesh_node(root,"VelocityFilament%d"%i,ribbon(points,.025 if i%2==0 else .012),material(color,2,1.5))
	mesh_node(root,"GroundDisplacement",band(.26,.23,-.87,28),material(Color("a18a69"),1,.1))
	return root

static func column(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name="ExtractionBeaconVolume"
	for i in 2:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius=.18 if i==0 else .64
		cylinder.bottom_radius=.55 if i==0 else 1.48
		cylinder.height=36
		cylinder.radial_segments=32
		cylinder.cap_top=false
		cylinder.cap_bottom=false
		var node := mesh_node(root,"ExtractionLightColumn" if i==0 else "SoftBeaconEnvelope",cylinder,material(color,3,1.15 if i==0 else .5))
		node.position.y=18
	mesh_node(root,"LandingHalo",band(3.95,.13,.13),material(color,0,1.0))
	for i in 8:
		mesh_node(root,"LandingGuide%d"%i,band(3.6,.18,.14,6,.24,float(i)*TAU/8),material(color,2,1.2))
	return root

static func flare() -> Node3D:
	var root := Node3D.new()
	root.name="BurningSignal"
	var casing := CylinderMesh.new()
	casing.height=.28
	casing.top_radius=.026
	casing.bottom_radius=.031
	casing.radial_segments=12
	var body := StandardMaterial3D.new()
	body.albedo_color=Color("5b3124")
	body.roughness=.83
	mesh_node(root,"SpentSignalCasing",casing,body).position.y=.03
	for i in 4:
		var angle := float(i)*TAU/4
		var points: Array[Vector3]=[Vector3.ZERO,Vector3(cos(angle)*.035,.20,sin(angle)*.035),Vector3(cos(angle+.5)*.08,.46,sin(angle+.5)*.08),Vector3(cos(angle+1)*.04,.71,sin(angle+1)*.04)]
		mesh_node(root,"CombustionRibbon%d"%i,ribbon(points,.14),material(Color("ff9b48"),4,2.5))
	for i in 8:
		var a: float= float(i)*2.4
		var points: Array[Vector3]=[Vector3(cos(a)*.04,.18,sin(a)*.04),Vector3(cos(a)*.14,.5+float(i%3)*.13,sin(a)*.14)]
		mesh_node(root,"RisingEmber%d"%i,ribbon(points,.013),material(Color("ffd99b"),2,2))
	mesh_node(root,"SignalSmoke",ribbon([Vector3(0,.4,0),Vector3(.07,.9,.02),Vector3(.16,1.5,.08),Vector3(.25,2.2,.13)],.7),material(Color("66554a"),1,.0))
	return root

static func tick(root: Node3D, elapsed: float, fade: float = 1.0) -> void:
	for item in root.find_children("*","MeshInstance3D",true,false):
		if item.material_override is ShaderMaterial and item.material_override.shader==FX_SHADER:
			item.material_override.set_shader_parameter("phase",elapsed)
			item.material_override.set_shader_parameter("opacity",clampf(fade,0,1))
