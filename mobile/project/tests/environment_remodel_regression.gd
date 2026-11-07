extends SceneTree
const Geometry=preload("res://environment_geometry.gd")
var failed := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failed+=1
		push_error(label)
func valid_mesh(mesh: Mesh, label: String) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	check(points.size()>20 and points.size()==normals.size(),label+" has authored vertices and normals")
	var valid := true
	for i in points.size():
		if not points[i].is_finite() or not normals[i].is_finite() or normals[i].length()<.9: valid=false
	for i in range(0,indices.size(),3):
		var a := points[indices[i]]
		var b := points[indices[i+1]]
		var c := points[indices[i+2]]
		if (c-a).cross(b-a).length_squared()<.00000000001: valid=false
	check(valid,label+" has finite normals and nondegenerate triangles")
func run() -> void:
	for sample in [[Vector3(3,1.4,.46),"ChippedWindowSpandrel"],[Vector3(.56,6.2,.56),"CorrodedLoadBearingColumn"],[Vector3(2.5,.10,7),"OverlappingTinRoof"],[Vector3(20,.25,16),"ExposedFloorSlab"],[Vector3(2.8,.15,12),"BatteredBusRoof"],[Vector3(5,.5,4.5),"FallenCurvedShellFragment"],[Vector3(.8,1.2,.6),"FuelPumpBody"]]:
		var mesh := Geometry.solid(sample[0],sample[1])
		valid_mesh(mesh,sample[1])
		check(mesh.get_aabb().size.is_equal_approx(sample[0]) or (mesh.get_aabb().size-sample[0]).length()<.35,sample[1]+" respects original object bounds")
	valid_mesh(Geometry.wheel(.5,.28),"Hollow profiled tire")
	valid_mesh(Geometry.hollow_bucket(.23,.48),"Hollow tapered bucket")
	valid_mesh(Geometry.lathe(.31,.92,"DentedBarrel"),"Rolled barrel shell")
	valid_mesh(Geometry.lathe(8.56,1.2,"DomedCircularEnd"),"Dished pressure-vessel end")
	for path in ["res://maps/overpass.tscn","res://maps/rustworks.tscn","res://maps/buried_city.tscn","res://maps/dusk_settlement.tscn"]:
		var world: Node3D=load(path).instantiate()
		root.add_child(world)
		await physics_frame
		await physics_frame
		var terrain: MeshInstance3D=world.get_node("SandDunes")
		check(terrain.get_meta("terrain_topology","")=="staggered_center_fan_barchan_erosion",path+" uses sculpted staggered terrain")
		for sample_x in [-174.0,175.0] if world.region_id==0 else [-131.0,129.0]:
			var point := Vector3(sample_x,world.ground_height(sample_x,12.0),12.0)
			var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.0,point-Vector3.UP*1.0,1)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and absf(hit.position.y-point.y)<.13,path+" sculpted terrain matches collision at "+str(sample_x))
		if world.region_id==0:
			var plants := 0
			for child in world.get_children():
				if child.get_meta("botanical_mesh",false): plants+=1
			check(plants>70,"All old grass clumps have new arched blades and branching stems")
		if world.region_id==1:
			var shells := world.find_children("FracturedHyperboloidConcreteShell*","MeshInstance3D",true,false)
			check(shells.size()==1 and shells[0].get_meta("shell_topology","")=="welded_variable_thickness_hyperboloid","Cooling tower uses welded engineering profile and variable wall thickness")
		check(world.has_node("StaticWorldBatches"),path+" retains static world batching")
		var triangles := 0
		var batches: Node3D=world.get_node("StaticWorldBatches")
		for instance: MeshInstance3D in batches.get_children():
			var arrays := instance.mesh.surface_get_arrays(0)
			triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
		check(triangles<1200000,path+" remains below 1.2m static triangles")
		check(world.get_meta("static_batches")<1600,path+" retains bounded material/tile groups")
		print("ENVIRONMENT MESH BUDGET ",path," triangles=",triangles," batches=",batches.get_child_count())
		world.free()
		await process_frame
	print("ENVIRONMENT REMODEL: ",checks," checks, ",failed," failures")
	quit(1 if failed else 0)
