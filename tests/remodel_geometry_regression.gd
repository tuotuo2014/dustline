extends SceneTree
const Equipment = preload("res://equipment_geometry.gd")
const Effects = preload("res://model_effects.gd")
const Props = preload("res://wasteland_interactables.gd")
const Loot = preload("res://economy_props.gd")
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count+=1
	if ok: print("PASS: "+label)
	else:
		failed+=1
		push_error(label)
func inspect_mesh(mesh: Mesh, label: String, oriented: bool = true) -> void:
	var good := true
	var faces := 0
	for surface in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(surface)
		var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
		var ix: PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if ix.is_empty():
			for i in v.size(): ix.append(i)
		for i in v.size():
			if not v[i].is_finite() or not n[i].is_finite() or n[i].length()<.8: good=false
		for i in range(0,ix.size(),3):
			var normal := (v[ix[i+2]]-v[ix[i]]).cross(v[ix[i+1]]-v[ix[i]])
			if normal.length_squared()<1e-18: good=false
			if oriented and normal.normalized().dot(n[ix[i]]+n[ix[i+1]]+n[ix[i+2]])<-.001: good=false
		faces+=ix.size()/3
	check(good,label+" finite nondegenerate correctly facing surfaces")
	check(faces>0 and faces<18000,label+" bounded mesh detail")
func run() -> void:
	inspect_mesh(Equipment.beveled_box(Vector3(.5,.3,.4),.025),"Machined equipment casing")
	inspect_mesh(Equipment.formed_shell([Vector4(-.2,.11,.12,0),Vector4(0,.18,.17,.01),Vector4(.2,.12,.13,0)]),"Contoured manufactured shell")
	for item in [Props.pickup("scrap"),Props.pickup("medkit"),Props.relay(1),Props.shelter(true),Props.shelter(false),Props.extraction(),Loot.pickup("coin"),Loot.pickup("watch"),Loot.pickup("chip"),Loot.pickup("gold")]:
		root.add_child(item)
		var surfaces: Array= item.find_children("*","MeshInstance3D",true,false)
		check(surfaces.size()>0 and surfaces.size()<35,item.name+" uses bounded material batches")
		var valid := true
		for node in surfaces:
			if node.mesh.get_aabb().size.length()<=0: valid=false
		check(valid,item.name+" has actual visible solid geometry")
		item.free()
	for effect in [Effects.wave(Color.ORANGE),Effects.dash(Color.CYAN),Effects.column(Color.GREEN),Effects.flare()]:
		root.add_child(effect)
		check(effect.find_children("*","CollisionObject3D",true,false).is_empty(),effect.name+" never blocks movement or raycasts")
		check(effect.find_children("*","MeshInstance3D",true,false).size()<20,effect.name+" has bounded transparent geometry")
		Effects.tick(effect,.25,.4)
		var good := true
		for node in effect.find_children("*","MeshInstance3D",true,false):
			if node.material_override is ShaderMaterial:
				if not is_equal_approx(node.material_override.get_shader_parameter("opacity"),.4): good=false
		check(good,effect.name+" obeys explicit lifetime opacity")
		effect.free()
	print("REMODEL SOLIDS / EFFECTS: %d checks; %d failures"%[count,failed])
	quit(1 if failed else 0)
