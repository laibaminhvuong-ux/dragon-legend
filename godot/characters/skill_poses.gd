class_name SkillPoses
extends RefCounted
# Body poses for each skill (presentation rebuild 2026-11-04), keyed by the catalogue's `pose` id
# (data/skill_presentation.json). Each pose has a "hold" key pose (gathering, while the technique is held or charging)
# and a "release" key pose (the throw / thrust / burst), layered by PoseModifier on top of the animation clip.
# Rotations use PoseModifier's convention (JS model): x = pitch (+x tips a hanging limb backwards, so -1.5 lifts an arm
# straight ahead and -3.0 straight up), z = roll (+0.3 on the left arm swings it outwards; mirrored on the right),
# y = twist. Keys: body (hips), chest, neck, armL/armR (upper arms), foreL/foreR (forearms; -x bends the elbow).
# Poses that leave both arms empty fall back to the clip (melee combos use the punch clips).

static func _sym(arm: Vector3, fore: Vector3) -> Dictionary:
	return {"armL": arm, "armR": Vector3(arm.x, -arm.y, -arm.z), "foreL": fore, "foreR": Vector3(fore.x, -fore.y, -fore.z)}

static func _k(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.merge(extra, true)
	return out

static var _poses: Dictionary = {}

static func all() -> Dictionary:
	if not _poses.is_empty():
		return _poses
	var forward := _sym(Vector3(-1.45, 0, -0.22), Vector3(-0.1, 0, 0))          # both palms thrust straight ahead
	_poses = {
		# Energy Wave / Kamehameha: cupped hands drawn back to the right hip, body coiled; then both palms thrust forward
		"cupped_wave": {
			"hold": {"body": Vector3(0, 0.45, 0), "chest": Vector3(0.15, 0.35, 0), "neck": Vector3(0, -0.6, 0),
				"armL": Vector3(0.1, 0, -0.75), "foreL": Vector3(-1.6, 0, 0), "armR": Vector3(0.55, 0, 0.1), "foreR": Vector3(-1.5, 0, 0)},
			"release": _k(forward, {"body": Vector3(0, -0.12, 0), "chest": Vector3(0.1, -0.1, 0)})},
		# Galick-style: both palms drawn out to one side, body twisted away; then swung across into a forward push
		"side_palm_wave": {
			"hold": {"body": Vector3(0, -0.55, 0), "chest": Vector3(0, -0.4, 0), "neck": Vector3(0, 0.75, 0),
				"armL": Vector3(-0.9, 0, 0.9), "foreL": Vector3(-0.3, 0, 0), "armR": Vector3(-0.9, 0, -0.35), "foreR": Vector3(-1.2, 0, 0)},
			"release": _k(forward, {"chest": Vector3(0.12, 0.1, 0)})},
		# Final-Flash-style: both arms spread wide to the sides, chest open; then clapped together straight ahead
		"wide_palm_release": {
			"hold": _k(_sym(Vector3(-0.2, 0, 1.25), Vector3(-0.15, 0, 0)), {"chest": Vector3(-0.22, 0, 0), "neck": Vector3(-0.15, 0, 0)}),
			"release": _k(_sym(Vector3(-1.5, 0, -0.32), Vector3(0, 0, 0)), {"chest": Vector3(0.12, 0, 0)})},
		# Tri Beam: hands raised in front of the face making a triangle window; then pushed forward
		"triangle_hands": {
			"hold": _k(_sym(Vector3(-1.25, 0, -0.38), Vector3(-1.05, 0, 0)), {"neck": Vector3(0.1, 0, 0)}),
			"release": _k(_sym(Vector3(-1.55, 0, -0.3), Vector3(-0.35, 0, 0)), {"chest": Vector3(0.1, 0, 0)})},
		# Exploding demon wave: palms pulled back to the waist, then a two-hand shove
		"open_palm_surge": {
			"hold": _k(_sym(Vector3(0.5, 0, 0.25), Vector3(-1.4, 0, 0)), {"chest": Vector3(-0.15, 0, 0)}),
			"release": _k(forward, {"chest": Vector3(0.18, 0, 0), "body": Vector3(0.12, 0, 0)})},
		# Masenko: both hands raised to the forehead, then swept forward
		"forehead_push": {
			"hold": _k(_sym(Vector3(-2.2, 0, -0.25), Vector3(-1.6, 0, 0)), {"chest": Vector3(-0.15, 0, 0), "neck": Vector3(-0.1, 0, 0)}),
			"release": _k(_sym(Vector3(-1.75, 0, -0.25), Vector3(-0.15, 0, 0)), {"chest": Vector3(0.08, 0, 0)})},
		# Solar flare: palms spread over the face, then thrown wide open
		"face_flare": {
			"hold": _k(_sym(Vector3(-1.9, 0, -0.1), Vector3(-1.9, 0, 0)), {"neck": Vector3(0.15, 0, 0)}),
			"release": _k(_sym(Vector3(-2.3, 0, 1.0), Vector3(-0.2, 0, 0)), {"chest": Vector3(-0.2, 0, 0), "neck": Vector3(-0.2, 0, 0)})},
		# Spirit Bomb: both arms straight up, gathering; then hurled forward and down
		"overhead_sphere": {
			"hold": _k(_sym(Vector3(-2.95, 0, 0.12), Vector3(-0.05, 0, 0)), {"chest": Vector3(-0.2, 0, 0), "neck": Vector3(-0.45, 0, 0)}),
			"release": _k(_sym(Vector3(-1.7, 0, -0.1), Vector3(-0.05, 0, 0)), {"chest": Vector3(0.3, 0, 0), "body": Vector3(0.15, 0, 0)})},
		# Death Ball: right index finger raised high (orb above it), left hand at the hip; then thrown forward
		"raised_finger_orb": {
			"hold": {"armR": Vector3(-3.0, 0, -0.05), "foreR": Vector3(-0.05, 0, 0), "armL": Vector3(0.2, 0, 0.15), "foreL": Vector3(-1.1, 0, 0),
				"neck": Vector3(-0.2, 0, 0)},
			"release": {"armR": Vector3(-1.6, 0, 0.05), "foreR": Vector3(-0.05, 0, 0), "armL": Vector3(0.25, 0, 0.15), "foreL": Vector3(-1.0, 0, 0),
				"chest": Vector3(0.15, -0.15, 0)}},
		# single-hand shots: arm straight out at the target, the other hand back at the hip
		"palm_shot": {
			"hold": {"armR": Vector3(-1.1, 0, -0.1), "foreR": Vector3(-0.5, 0, 0), "chest": Vector3(0, 0.2, 0)},
			"release": {"armR": Vector3(-1.55, 0, -0.15), "foreR": Vector3(0, 0, 0), "chest": Vector3(0.05, -0.3, 0), "armL": Vector3(0.35, 0, 0.1),
				"foreL": Vector3(-0.8, 0, 0)}},
		"one_hand_burst": {
			"hold": {"armR": Vector3(0.45, 0, 0.15), "foreR": Vector3(-1.3, 0, 0), "chest": Vector3(0, 0.45, 0), "body": Vector3(0, 0.25, 0),
				"armL": Vector3(-1.2, 0, -0.4), "foreL": Vector3(-0.4, 0, 0)},
			"release": {"armR": Vector3(-1.55, 0, -0.18), "foreR": Vector3(0, 0, 0), "chest": Vector3(0.12, -0.35, 0), "body": Vector3(0, -0.15, 0),
				"armL": Vector3(0.3, 0, 0.2), "foreL": Vector3(-0.9, 0, 0)}},
		"finger_lance": {
			"hold": {"armR": Vector3(-1.4, 0, -0.1), "foreR": Vector3(-0.35, 0, 0), "armL": Vector3(0.1, 0, 0.05), "foreL": Vector3(-0.3, 0, 0)},
			"release": {"armR": Vector3(-1.55, 0, -0.12), "foreR": Vector3(0, 0, 0), "chest": Vector3(0, -0.15, 0)}},
		"destruction_palm": {
			"hold": {"armR": Vector3(-1.2, 0, 0.35), "foreR": Vector3(-1.2, 0, 0), "chest": Vector3(-0.1, 0.25, 0), "neck": Vector3(0, -0.2, 0)},
			"release": {"armR": Vector3(-1.5, 0, -0.1), "foreR": Vector3(-0.05, 0, 0), "chest": Vector3(0.1, -0.2, 0)}},
		# Special Beam Cannon: two fingers held to the forehead, then thrust out at the target
		"two_finger_focus": {
			"hold": {"armR": Vector3(-2.15, 0, -0.35), "foreR": Vector3(-1.85, 0, 0), "neck": Vector3(0.12, 0, 0), "chest": Vector3(0, 0.2, 0),
				"armL": Vector3(0.15, 0, 0.1), "foreL": Vector3(-0.6, 0, 0)},
			"release": {"armR": Vector3(-1.6, 0, -0.1), "foreR": Vector3(0, 0, 0), "chest": Vector3(0.05, -0.25, 0)}},
		"forehead_transfer": {
			"hold": {"armR": Vector3(-2.15, 0, -0.35), "foreR": Vector3(-1.85, 0, 0), "neck": Vector3(0.18, 0, 0)},
			"release": {"armR": Vector3(-2.15, 0, -0.35), "foreR": Vector3(-1.85, 0, 0), "neck": Vector3(0.25, 0, 0), "chest": Vector3(0.1, 0, 0)}},
		# Destructo Disc: right arm raised overhead holding the disc, then a sidearm sweep forward
		"disc_throw": {
			"hold": {"armR": Vector3(-2.8, 0, 0.35), "foreR": Vector3(-0.25, 0, 0), "chest": Vector3(-0.1, 0.25, 0), "armL": Vector3(-0.6, 0, 0.3),
				"foreL": Vector3(-0.4, 0, 0)},
			"release": {"armR": Vector3(-1.4, 0, -0.55), "foreR": Vector3(-0.1, 0, 0), "chest": Vector3(0.18, -0.45, 0), "body": Vector3(0, -0.2, 0),
				"armL": Vector3(0.3, 0, 0.35), "foreL": Vector3(-0.6, 0, 0)}},
		# Kaioken: fists clenched low and out, chest thrown open, head back (a roar)
		"strain_activation": {
			"hold": _k(_sym(Vector3(0.3, 0, 0.55), Vector3(-1.2, 0, 0)), {"chest": Vector3(-0.32, 0, 0), "neck": Vector3(-0.35, 0, 0)}),
			"release": _k(_sym(Vector3(0.35, 0, 0.75), Vector3(-1.0, 0, 0)), {"chest": Vector3(-0.4, 0, 0), "neck": Vector3(-0.45, 0, 0)})},
		"healing_breath": {
			"hold": _k(_sym(Vector3(-0.35, 0, 0.35), Vector3(-0.55, 0, 0)), {"chest": Vector3(-0.15, 0, 0), "neck": Vector3(-0.2, 0, 0)}),
			"release": _k(_sym(Vector3(-0.2, 0, 0.6), Vector3(-0.2, 0, 0)), {"chest": Vector3(-0.25, 0, 0), "neck": Vector3(-0.3, 0, 0)})},
		"tentacle_cast": {
			"hold": {"neck": Vector3(0.25, 0, 0), "chest": Vector3(0.1, 0, 0), "armR": Vector3(-1.0, 0, -0.1), "foreR": Vector3(-0.6, 0, 0)},
			"release": {"neck": Vector3(0.35, 0, 0), "chest": Vector3(0.15, 0, 0), "armR": Vector3(-1.5, 0, -0.1), "foreR": Vector3(0, 0, 0)}},
		"evasive_step": {
			"hold": {"body": Vector3(0, 0, 0.25), "chest": Vector3(0, 0, -0.1)},
			"release": _k(_sym(Vector3(-0.4, 0, 0.3), Vector3(-0.8, 0, 0)), {"body": Vector3(-0.1, 0, -0.3)})},
		"controlled_breath": {
			"hold": _k(_sym(Vector3(0.05, 0, 0.18), Vector3(-0.35, 0, 0)), {"chest": Vector3(-0.08, 0, 0)}),
			"release": _k(_sym(Vector3(0.05, 0, 0.25), Vector3(-0.25, 0, 0)), {"chest": Vector3(-0.12, 0, 0)})},
		"instinct_focus": {
			"hold": _k(_sym(Vector3(-0.25, 0, 0.28), Vector3(-0.45, 0, 0)), {"neck": Vector3(0.08, 0, 0)}),
			"release": _k(_sym(Vector3(-0.45, 0, 0.35), Vector3(-0.6, 0, 0)), {"chest": Vector3(-0.1, 0, 0)})},
		"avatar_manifest": {
			"hold": _k(_sym(Vector3(-0.6, 0, 0.9), Vector3(-0.3, 0, 0)), {"chest": Vector3(-0.25, 0, 0), "neck": Vector3(-0.3, 0, 0)}),
			"release": _k(_sym(Vector3(-2.4, 0, 0.75), Vector3(-0.1, 0, 0)), {"chest": Vector3(-0.3, 0, 0), "neck": Vector3(-0.4, 0, 0)})},
		"barrier_brace": {
			"hold": _k(_sym(Vector3(-1.3, 0, -0.35), Vector3(-1.5, 0, 0)), {"chest": Vector3(0.12, 0, 0)}),
			"release": _k(_sym(Vector3(-1.0, 0, 0.9), Vector3(-0.3, 0, 0)), {"chest": Vector3(-0.15, 0, 0)})},
		"fusion_choreography": {
			"hold": {"armL": Vector3(-0.2, 0, 1.3), "armR": Vector3(-0.2, 0, 0.8), "foreL": Vector3(-0.1, 0, 0), "foreR": Vector3(-1.0, 0, 0),
				"body": Vector3(0, 0, 0.12)},
			"release": {"armL": Vector3(-0.2, 0, -0.6), "armR": Vector3(-0.2, 0, -1.2), "foreL": Vector3(-0.9, 0, 0), "foreR": Vector3(-0.1, 0, 0),
				"body": Vector3(0, 0, -0.12)}},
	}
	return _poses

static func has_pose(id: String) -> bool:
	return all().has(id)

## The pose id's key pose ("hold" or "release"), or {} for poses that use the clip (melee, claw flurry).
static func key(id: String, which: String) -> Dictionary:
	return (all().get(id, {}) as Dictionary).get(which, {})
