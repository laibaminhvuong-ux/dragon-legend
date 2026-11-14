extends TestCase
# Task C visual leftovers (2026-11-13): skinned dress skirts checked on real animation poses (no slit, the legs stay
# inside), Meros / Chelai hair on human heads covering the back of the skull.

## Poses the skeleton at time t of a clip: the clip's bone rotations only (positions stay the body's own rest).
func _pose(f: Fighter, a: Animation, t: float) -> void:
	f.skeleton.reset_bone_poses()
	for tr in a.get_track_count():
		if a.track_get_type(tr) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := f.skeleton.find_bone(str(a.track_get_path(tr).get_concatenated_subnames()))
		if bone >= 0:
			f.skeleton.set_bone_pose_rotation(bone, a.rotation_track_interpolate(tr, t))

## Whether the segment p-q crosses triangle (a, b, c).
func _crosses(p: Vector3, q: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var hit: Variant = Geometry3D.segment_intersects_triangle(p, q, a, b, c)
	return hit != null

func test_skirt_on_animated_poses() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	var clips := ["Walk", "Jog_Fwd", "Sprint", "pro/Jog_Left_Loop", "pro/Jog_Right_Loop", "pro/Jog_Bwd_Loop", "pro/Kick", "pro/PunchKick_Enter", "Jump_Start"]
	for id: String in ["bulma", "chichi"]:   # knee-length and long dress
		var f := Fighter.create(chars[id].look)
		var mi: MeshInstance3D = f.skirt[0]
		var arr := mi.mesh.surface_get_arrays(0)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var rest_pts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols := Skirt.COLS + 1
		var hem0 := Skirt.ROWS * cols
		var rest_gap := rest_pts[hem0].distance_to(rest_pts[hem0 + 1])
		var length := rest_pts[0].y - rest_pts[hem0].y
		var worst_gap := 0.0
		var pokes: Array[String] = []
		var sampled := 0
		var swing := 0.0   # widest thigh swing seen (the poses really move the legs)
		for clip: String in clips:
			if not f.anim_player.has_animation(clip):
				continue
			var a := f.anim_player.get_animation(clip)
			for k in 12:
				var t := a.length * k / 12.0
				_pose(f, a, t)
				sampled += 1
				var pts := Skirt.posed(f, mi)
				# one closed skirt: neighbouring hem points never pull apart (a slit would be a jump)
				for c in Skirt.COLS:
					worst_gap = maxf(worst_gap, pts[hem0 + c].distance_to(pts[hem0 + c + 1]))
				ok(pts[hem0].distance_to(pts[hem0 + Skirt.COLS]) < 1e-4, "%s %s %.2f: closed at the front centre" % [id, clip, t])
				# the thighs stay inside: the leg line from the hip joint down the upper thigh crosses no skirt triangle
				for side: String in ["L", "R"]:
					var hip := Skirt.global_pose(f.skeleton, f.skeleton.find_bone("DEF-thigh." + side)).origin
					var knee := Skirt.global_pose(f.skeleton, f.skeleton.find_bone("DEF-shin." + side)).origin
					var hips_down := Skirt.global_pose(f.skeleton, f.skeleton.find_bone("DEF-hips")).basis * f.skeleton.get_bone_global_rest(f.skeleton.find_bone("DEF-hips")).basis.inverse() * Vector3.DOWN
					swing = maxf(swing, rad_to_deg((knee - hip).angle_to(hips_down)))
					var q := hip + (knee - hip).normalized() * minf(length * 0.7, hip.distance_to(knee) * 0.6)
					for i in range(0, idx.size(), 3):
						if _crosses(hip, q, pts[idx[i]], pts[idx[i + 1]], pts[idx[i + 2]]):
							pokes.append("%s %.2f %s" % [clip, t, side])
							break
		ok(sampled >= 60, "%s: sampled real clips (%d poses)" % [id, sampled])
		ok(swing > 45.0, "%s: the clips swing the thighs (%.0f degrees)" % [id, swing])
		# one mesh cannot open a slit; in a full stride the hem between the legs stretches (front/back centre shared by both
		# thighs), which must stay a bounded stretch, not a vertex flying off
		ok(worst_gap < 0.6, "%s: hem stays continuous (widest step %.3f m, rest %.3f m)" % [id, worst_gap, rest_gap])
		ok(pokes.is_empty(), "%s: thighs stay inside the skirt (%s)" % [id, ", ".join(pokes.slice(0, 6))])
		f.free()

func test_skirt_weights() -> void:
	var front := Skirt.weights(0.0, 1.0)
	near(front.y, front.z, 1e-6, "front centre: both thighs share the hem")
	var back := Skirt.weights(PI, 1.0)
	near(back.y, back.z, 1e-6, "back centre: both thighs share the hem")
	ok(Skirt.weights(PI * 0.5, 1.0).y > 0.75 and Skirt.weights(-PI * 0.5, 1.0).z > 0.75, "over each leg: its own thigh")
	near(Skirt.weights(0.7, 0.0).x, 1.0, 1e-6, "the waistband stays on the hips")
	for a in [0.0, 0.5, 1.6, 3.0, -2.0]:
		var w := Skirt.weights(a, 0.6)
		near(w.x + w.y + w.z, 1.0, 1e-5, "weights sum to 1 at %.1f" % a)

func test_meros_chelai_hair() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	for row: Array in [["merus", "roundbob"], ["cheelai", "pixie"]]:
		var look: Dictionary = chars[row[0]].look
		eq(str(look.race), "Human", "%s: a human head under the hair" % row[0])
		var f := Fighter.create(look)
		ok(f.hair != null and f.hair.mesh == Hair.mesh(row[1]), "%s wears %s" % row)
		eq(f._hair_fit, Transform3D.IDENTITY, "%s: no hairless-skull refit" % row[0])
		var sk := Hair.skull(f.body_mesh.mesh)
		var rest := f.skeleton.get_bone_global_rest(f.skeleton.find_bone("DEF-head")) * f.hair.transform
		var back_low := 9.0; var crown_low := 9.0
		for p: Vector3 in f.hair.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var q: Vector3 = rest * p
			if absf(q.x) < 0.03 and q.z < -0.06:
				back_low = minf(back_low, q.y)
			if absf(q.x) < 0.03 and absf(q.z) < 0.05:
				crown_low = minf(crown_low, q.y)
		ok(crown_low < float(sk.top) + 0.03, "%s: on the scalp (%.3f vs crown %.3f)" % [row[0], crown_low, float(sk.top)])
		ok(back_low < float(sk.top) - 0.15, "%s: covers the back of the head to the nape (%.3f, crown %.3f)" % [row[0], back_low, float(sk.top)])
		f.free()
	for style: String in ["pixie", "roundbob"]:   # the shell faces outwards (clockwise seen from outside, lit)
		var a := Hair.mesh(style).surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var outward := 0; var total := 0
		for i in range(0, ix.size(), 3):
			var n := (v[ix[i + 1]] - v[ix[i]]).cross(v[ix[i + 2]] - v[ix[i]])
			if n.length() < 1e-9:
				continue
			total += 1
			if n.dot((v[ix[i]] + v[ix[i + 1]] + v[ix[i + 2]]) / 3.0 - Vector3(0, 0.05, -0.008)) < 0.0:
				outward += 1
		ok(outward > total * 0.95, "%s: shell faces outwards (%d/%d)" % [style, outward, total])
