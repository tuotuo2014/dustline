extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var rig=load("res://reference_survivor.gd").new()
	root.add_child(rig)
	check(rig.head.scale.is_equal_approx(Vector3(.97,.89,1.02)),"Adult head proportions must remain unchanged")
	check(rig._finger_joints.size()==8,"Both gloves need four articulated fingers")
	check(rig._face_lids.size()==4,"Both eyes require working upper and lower lids")
	var max_blink:=0.0
	var min_blink:=1.0
	for frame in 360:
		rig.animate(1.0/60,0.0,true)
		var blink: float=rig._face_lids[0].get_blend_shape_value(0)
		max_blink=maxf(max_blink,blink)
		min_blink=minf(min_blink,blink)
	check(max_blink>.95 and min_blink<.001,"Idle face must close and reopen its eyes")
	var average_drift:=0.0
	var contact_samples:=0
	var min_sole:=INF
	var contact_count: Array[int]=[0,0]
	for speed in [1.8,7.8]:
		rig.reset_motion()
		for frame in 120: rig.animate(1.0/60,speed,true)
		for frame in 240:
			var old_feet: Array[Vector3]=[rig.ankles[0].global_position,rig.ankles[1].global_position]
			var old_contact: Array=rig.foot_contacts.duplicate()
			rig.position.z-=speed/60.0
			rig.animate(1.0/60,speed,true)
			for i in 2:
				if old_contact[i] and rig.foot_contacts[i]:
					average_drift+=absf(rig.ankles[i].global_position.z-old_feet[i].z)
					contact_samples+=1
				if rig.foot_contacts[i]: contact_count[i]+=1
				var sole: MeshInstance3D=rig.ankles[i].get_node("Sole")
				var bounds: AABB=sole.global_transform*sole.mesh.get_aabb()
				min_sole=minf(min_sole,bounds.position.y)
	check(contact_samples>100,"Both gaits must contain measurable planted-foot phases")
	check(contact_count[0]>50 and contact_count[1]>50,"Both feet must take turns making contact")
	check(average_drift/maxi(1,contact_samples)<.003,"A planted foot should stay in place while the body advances")
	check(min_sole>-.012,"Heel/toe roll must not bury boot soles below the ground")
	rig.set_motion_context(Vector3(0,0,-18),0)
	for frame in 30: rig.animate(1.0/60,1.8,true)
	var forward_lean: float=rig.torso.rotation.x
	rig.set_motion_context(Vector3(0,0,18),0)
	for frame in 30: rig.animate(1.0/60,1.8,true)
	check(rig.torso.rotation.x>forward_lean+.055,"Acceleration and braking need opposite weight responses")
	rig.set_motion_context(Vector3.ZERO,4.0)
	for frame in 30: rig.animate(1.0/60,1.8,true)
	var left_lean: float=rig.torso.rotation.z
	rig.set_motion_context(Vector3.ZERO,-4.0)
	for frame in 30: rig.animate(1.0/60,1.8,true)
	check(left_lean>rig.torso.rotation.z+.035,"Turn banking must respond to both directions")
	rig.set_motion_context(Vector3.ZERO,0)
	for frame in 25: rig.animate(1.0/60,1.8,false,6.0)
	var rise_knee: float=rig.knees[0].rotation.x
	for frame in 25: rig.animate(1.0/60,1.8,false,-6.0)
	check(rig.knees[0].rotation.x>rise_knee+.4,"Descending legs must extend in preparation for landing")
	rig.animate(1.0/60,0.0,true)
	check(rig.landing>.3 and rig.torso.position.y<.985,"Landing must absorb the impact through the hips")
	var landing_floor:=INF
	for frame in 60:
		rig.animate(1.0/60,0.0,true)
		for ankle in rig.ankles:
			var sole: MeshInstance3D=ankle.get_node("Sole")
			var bounds: AABB=sole.global_transform*sole.mesh.get_aabb()
			landing_floor=minf(landing_floor,bounds.position.y)
	check(landing_floor>-.012,"Landing compression must keep soles out of the ground")
	check(rig.landing<.001 and absf(rig.torso.position.y-1.0)<.005,"Idle recovers its natural standing height")
	rig.set_motion_context(Vector3(9,0,-15),4)
	for frame in 30: rig.animate(1.0/60,7.8,true)
	rig.reset_motion()
	check(rig.gait==0 and rig.run_blend==0 and rig.turn_blend==0 and rig.motion_acceleration==Vector2.ZERO,"New rounds must clear previous movement inertia")
	print("CHARACTER MOTION REGRESSION: %s; %d checks; stance drift %.4f m/frame; sole clearance %.4f m" % ["PASS" if failures.is_empty() else "FAIL",checks,average_drift/maxi(1,contact_samples),min_sole])
	quit(0 if failures.is_empty() else 1)
