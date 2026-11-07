extends SceneTree
## Physical gait properties measured from the shared four-character rig. These
## checks deliberately observe contacts/poses rather than reproducing its curves.
const Survivor = preload("res://reference_survivor.gd")
const Roster = preload("res://wasteland_roster_survivor.gd")
const DT := 1.0 / 120.0
const SAMPLES := 1440
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func sole_height(ankle: Node3D) -> float:
	var sole: MeshInstance3D = ankle.get_node("Sole")
	var bounds := sole.mesh.get_aabb()
	var height := INF
	for corner in 8:
		height = minf(height, sole.to_global(bounds.get_endpoint(corner)).y)
	return height

func measure(rig: Node3D, speed: float) -> Dictionary:
	rig.reset_motion()
	for frame in 240:
		rig.animate(DT, speed, true)
	var contacts := 0
	var double_support := 0
	var flight := 0
	var physical_flight := 0
	var finite := true
	var maximum_joint_step := 0.0
	var maximum_joint_phase := 0.0
	var maximum_joint_label := ""
	var maximum_foot_step := 0.0
	var minimum_sole := INF
	var maximum_stance_height := 0.0
	var arm_min: Array[float] = [INF, INF]
	var arm_max: Array[float] = [-INF, -INF]
	var elbow_min := INF
	var elbow_max := -INF
	var hand_sum := Vector2.ZERO
	var foot_sum := Vector2.ZERO
	var hand_sq := Vector2.ZERO
	var foot_sq := Vector2.ZERO
	var product := Vector2.ZERO
	var previous_contact: Array = rig.foot_contacts.duplicate()
	var previous_feet: Array[Vector3] = [rig.ankles[0].position, rig.ankles[1].position]
	var previous_knees: Array[Quaternion] = [rig.knees[0].quaternion, rig.knees[1].quaternion]
	var previous_ankles: Array[Quaternion] = [rig.ankles[0].quaternion, rig.ankles[1].quaternion]
	for side in 2:
		previous_feet[side] = rig.to_local(rig.ankles[side].global_position)
	for frame in SAMPLES:
		rig.animate(DT, speed, true)
		var heights: Array[float] = [sole_height(rig.ankles[0]), sole_height(rig.ankles[1])]
		if rig.foot_contacts[0] and rig.foot_contacts[1]: double_support += 1
		if not rig.foot_contacts[0] and not rig.foot_contacts[1]: flight += 1
		if heights[0] > .015 and heights[1] > .015: physical_flight += 1
		for side in 2:
			if rig.foot_contacts[side] and not previous_contact[side]: contacts += 1
			previous_contact[side] = rig.foot_contacts[side]
			var foot: Vector3 = rig.to_local(rig.ankles[side].global_position)
			var knee: Quaternion = rig.knees[side].quaternion
			var ankle: Quaternion = rig.ankles[side].quaternion
			finite = finite and foot.is_finite() and knee.is_finite() and ankle.is_finite()
			var knee_step := previous_knees[side].angle_to(knee)
			var ankle_step := previous_ankles[side].angle_to(ankle)
			if maxf(knee_step, ankle_step) > maximum_joint_step:
				maximum_joint_step = maxf(knee_step, ankle_step)
				maximum_joint_phase = fposmod(rig.phase / TAU + side * .5, 1.0)
				maximum_joint_label = "knee" if knee_step >= ankle_step else "ankle"
			maximum_foot_step = maxf(maximum_foot_step, previous_feet[side].distance_to(foot))
			previous_feet[side] = foot
			previous_knees[side] = knee
			previous_ankles[side] = ankle
			minimum_sole = minf(minimum_sole, heights[side])
			if rig.foot_contacts[side]: maximum_stance_height = maxf(maximum_stance_height, heights[side])
			var arm_angle: float = rig.arms[side].rotation.x
			arm_min[side] = minf(arm_min[side], arm_angle)
			arm_max[side] = maxf(arm_max[side], arm_angle)
			elbow_min = minf(elbow_min, rig.elbows[side].rotation.x)
			elbow_max = maxf(elbow_max, rig.elbows[side].rotation.x)
			var hand: Node3D = rig.elbows[side].get_node("Hand")
			var hand_z: float = rig.torso.to_local(hand.global_position).z
			hand_sum[side] += hand_z
			foot_sum[side] += foot.z
			hand_sq[side] += hand_z * hand_z
			foot_sq[side] += foot.z * foot.z
			product[side] += hand_z * foot.z
	var correlation := Vector2.ZERO
	for side in 2:
		var covariance := product[side] / SAMPLES - hand_sum[side] * foot_sum[side] / (SAMPLES * SAMPLES)
		var hand_variance := hand_sq[side] / SAMPLES - pow(hand_sum[side] / SAMPLES, 2)
		var foot_variance := foot_sq[side] / SAMPLES - pow(foot_sum[side] / SAMPLES, 2)
		correlation[side] = covariance / maxf(.0000001, sqrt(hand_variance * foot_variance))
	return {"cadence": contacts * 60.0 / (SAMPLES * DT), "double": double_support / float(SAMPLES),
		"flight": flight / float(SAMPLES), "physical_flight": physical_flight / float(SAMPLES),
		"finite": finite, "joint_step": maximum_joint_step, "joint_phase": maximum_joint_phase, "joint_label": maximum_joint_label, "foot_step": maximum_foot_step,
		"minimum_sole": minimum_sole, "stance_height": maximum_stance_height,
		"arm_ranges": Vector2(arm_max[0] - arm_min[0], arm_max[1] - arm_min[1]),
		"elbow_min": elbow_min, "elbow_max": elbow_max, "correlation": correlation}

func run() -> void:
	var baseline: Array[Dictionary] = []
	for id in 4:
		var rig: Node3D = Survivor.new() if id == 0 else Roster.new()
		if id > 0: rig.archetype = id
		root.add_child(rig)
		var results: Array[Dictionary] = []
		for speed in [1.8, 7.8]:
			var running: bool = speed > 2.0
			var label := "Character %d %s" % [id, "run" if running else "walk"]
			var data := measure(rig, speed)
			results.append(data)
			check(data.finite, label + " keeps every knee, ankle and foot finite")
			check(data.joint_step < .28 and data.foot_step < .10, label + " has continuous joint rotations and foot paths, including loop wrap")
			check(data.minimum_sole > -.012 and data.stance_height < .025, label + " plants soles on the ground without clipping or floating")
			if running:
				check(data.cadence >= 170 and data.cadence <= 230, label + " uses a human sprint cadence of 170–230 steps/minute")
				check(data.flight > .15 and data.physical_flight > .10, label + " has a visible flight phase with both soles above the ground")
			else:
				check(data.cadence >= 140 and data.cadence <= 155, label + " uses the requested brisk walking cadence of 140–155 steps/minute")
				check(data.double > .05 and data.flight == 0, label + " retains double support and never becomes an airborne jog")
				check(data.arm_ranges.x > .35 and data.arm_ranges.y > .35 and data.arm_ranges.x < .85 and data.arm_ranges.y < .85, label + " uses a restrained, visible shoulder swing")
				check(data.correlation.x < -.55 and data.correlation.y < -.55, label + " swings each hand opposite its same-side foot")
				check(data.elbow_min > .10 and data.elbow_max < .45, label + " keeps walking elbows relaxed instead of pumping in a running pose")
			print("GAIT %s: %.1f steps/min; double %.3f; flight %.3f / physical %.3f; joint step %.4f; foot step %.4f; stance height %.4f; arm correlation %s" % [label, data.cadence, data.double, data.flight, data.physical_flight, data.joint_step, data.foot_step, data.stance_height, data.correlation])
			print("MAX JOINT %s: %s at foot cycle %.5f" % [label, data.joint_label, data.joint_phase])
		if id == 0:
			baseline = results
		else:
			for gait_index in 2:
				check(absf(results[gait_index].cadence - baseline[gait_index].cadence) < .1 and absf(results[gait_index].double - baseline[gait_index].double) < .001 and absf(results[gait_index].flight - baseline[gait_index].flight) < .001, "Character %d inherits the same %s gait timing" % [id, "walk" if gait_index == 0 else "run"])
		rig.free()
	print("VIDEO GAIT REGRESSION: %s; %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
