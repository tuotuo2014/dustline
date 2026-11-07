extends SceneTree
## Observe visible joints rather than animation coefficients: a recovering knee
## can lead its ankle, so ankle/hand correlation alone misses a brief same-side lead.
const STEP := 1.0 / 60.0
const WALK_SPEED := 1.8
const NEUTRAL_DISTANCE := .012
const SHOULDER_LIMIT := .12
const ELBOW_LIMIT := .08
var checks := 0
var failures: Array[String] = []
var observed_samples := 0
var observed_mismatches := 0
var largest_shoulder_step := 0.0
var largest_elbow_step := 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func snapshot(rig: Node3D) -> Dictionary:
	return {
		"shoulders": [rig.arms[0].quaternion, rig.arms[1].quaternion],
		"elbows": [rig.elbows[0].quaternion, rig.elbows[1].quaternion],
		"knees": [rig.to_local(rig.knees[0].global_position).z, rig.to_local(rig.knees[1].global_position).z],
		"hands": [rig.to_local(rig.elbows[0].get_node("Hand").global_position).z, rig.to_local(rig.elbows[1].get_node("Hand").global_position).z]
	}

func sample(rig: Node3D, before: Dictionary, result: Dictionary) -> void:
	# Convert real world joints back into the actor's forward frame; rotation of
	# the actor and inherited shoulder transforms must not change the assertion.
	var left_knee: Vector3 = rig.to_local(rig.knees[0].global_position)
	var right_knee: Vector3 = rig.to_local(rig.knees[1].global_position)
	var left_hand: Vector3 = rig.to_local(rig.elbows[0].get_node("Hand").global_position)
	var right_hand: Vector3 = rig.to_local(rig.elbows[1].get_node("Hand").global_position)
	var knee_order := left_knee.z - right_knee.z
	var hand_order := left_hand.z - right_hand.z
	# A 12 mm dead zone tolerates the visually neutral passing pose, but the old
	# quarter-cycle error (about 21 mm at the knees / 40 mm at the hands) is visible.
	if absf(knee_order) > NEUTRAL_DISTANCE and absf(hand_order) > NEUTRAL_DISTANCE:
		result.samples += 1
		if knee_order * hand_order > 0.0:
			result.mismatches += 1
			if result.first_mismatch < 0.0:
				result.first_mismatch = fposmod(rig.phase / TAU, 1.0)
	for i in 2:
		result.shoulder_step = maxf(result.shoulder_step, before.shoulders[i].angle_to(rig.arms[i].quaternion))
		result.elbow_step = maxf(result.elbow_step, before.elbows[i].angle_to(rig.elbows[i].quaternion))
		var knee_velocity: float = ((left_knee.z if i == 0 else right_knee.z) - before.knees[i]) / STEP
		var hand_velocity: float = ((left_hand.z if i == 0 else right_hand.z) - before.hands[i]) / STEP
		# Sorting the left/right positions misses an arm moving in the SAME
		# direction as its own thigh. Check derivatives in the actor's frame.
		if absf(knee_velocity) > .10 and absf(hand_velocity) > .10:
			result.direction_samples += 1
			if knee_velocity * hand_velocity > 0:
				result.same_direction += 1

func new_result() -> Dictionary:
	return {"samples": 0, "mismatches": 0, "first_mismatch": -1.0, "shoulder_step": 0.0, "elbow_step": 0.0, "direction_samples": 0, "same_direction": 0}

func verify(result: Dictionary, label: String, minimum_samples: int) -> void:
	check(result.samples >= minimum_samples, label + " must contain clear alternating forward poses")
	check(result.mismatches == 0, "%s must lead with the opposite hand; %d mismatches, first phase %.4f" % [label, result.mismatches, result.first_mismatch])
	check(result.shoulder_step < SHOULDER_LIMIT and result.elbow_step < ELBOW_LIMIT,
		"%s must keep shoulders/elbows continuous at 60 fps; %.4f / %.4f radians" % [label, result.shoulder_step, result.elbow_step])
	observed_samples += result.samples
	observed_mismatches += result.mismatches
	largest_shoulder_step = maxf(largest_shoulder_step, result.shoulder_step)
	largest_elbow_step = maxf(largest_elbow_step, result.elbow_step)

func step_rig(rig: Node3D, speed: float, previous_speed: float) -> void:
	rig.position += rig.basis * Vector3(0, 0, -speed * STEP)
	rig.set_motion_context(Vector3(0, 0, -(speed - previous_speed) / STEP), 0.0)
	rig.animate(STEP, speed, true)

func run() -> void:
	for id in 4:
		var rig: Node3D
		if id == 0:
			rig = load("res://reference_survivor.gd").new()
		else:
			rig = load("res://wasteland_roster_survivor.gd").new()
			rig.archetype = id
		root.add_child(rig)
		rig.rotation.y = id * .63
		var heights: Array[float] = [0.0, 0.0]
		var normals: Array[Vector3] = [Vector3.UP, Vector3.UP]
		var valid: Array[bool] = [true, true]
		rig.set_ground_context(heights, normals, valid)
		for frame in 120:
			step_rig(rig, WALK_SPEED, WALK_SPEED)
		var steady := new_result()
		for frame in 480:
			var before := snapshot(rig)
			step_rig(rig, WALK_SPEED, WALK_SPEED)
			sample(rig, before, steady)
		verify(steady, "Character %d steady walk" % id, 360)
		check(steady.direction_samples > 700 and steady.same_direction == 0,
			"Character %d must move each hand opposite its own thigh, not just sort the poses: %d same-direction samples / %d" % [id,steady.same_direction,steady.direction_samples])
		print("Character %d actual swing directions: %d samples, %d same-direction motions" % [id,steady.direction_samples,steady.same_direction])
		for start_phase in [0.0, .125, .25, .5, .625, .75]:
			rig.reset_motion()
			rig.set_ground_context(heights, normals, valid)
			rig.phase = start_phase * TAU
			rig.animate(0.0, 0.0, true)
			var transition := new_result()
			var speed := 0.0
			for frame in 105:
				var before := snapshot(rig)
				var previous_speed := speed
				speed = move_toward(speed, WALK_SPEED if frame < 45 else 0.0, 18.0 * STEP)
				step_rig(rig, speed, previous_speed)
				sample(rig, before, transition)
			verify(transition, "Character %d start/stop at %.3f cycle" % [id, start_phase], 25)
			check(rig.gait < .001 and rig.run_blend < .001, "Character %d must settle after braking" % id)
			check(absf(rig.arms[0].rotation.x - rig.arms[1].rotation.x) < .01
				and absf(rig.elbows[0].rotation.x - rig.elbows[1].rotation.x) < .01,
				"Character %d arms must return to a relaxed symmetric rest after braking" % id)
		rig.free()
	print("WALK CROSSBODY REGRESSION: %s; %d checks; %d clear poses, %d same-side leads; max shoulder/elbow step %.5f / %.5f radians" % [
		"PASS" if failures.is_empty() else "FAIL", checks, observed_samples, observed_mismatches, largest_shoulder_step, largest_elbow_step])
	quit(0 if failures.is_empty() else 1)
