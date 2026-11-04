class_name GreatApe
extends Node3D
# The Great Ape form (2026-11-04 rebuild): a real rigged giant (ApeBody: own skeleton + one skinned, fur-sculpted
# mesh) animated with its own clips (ApeClips): idle breathing, heavy knuckle-swinging walk, roar, chest pound,
# stomp, swipe, grab-slam, mouth blast, hurt and a transform-in rise. Clips crossfade; strikes and footfalls kick
# up dust. Same contract as before: GreatApe.create(golden), update(dt, anim). Built at human size (feet at the
# origin, facing +Z); the fighter scales it with the form.

signal footfall(pos: Vector3, strength: float)

const BLEND := 0.22
## The ape looms over the fighters: 1.5x on top of the form's own scale (visual only; hitboxes stay the rules').
const VISUAL_SCALE := 1.5

var golden := false
var rig: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var current := ""
var _time := 0.0
var _clip_t := 0.0
var _last_attack := 0
var _last_reaction := 0
var _swing := 0
var _idle_for := 0.0
var _contact_done := false
var _last_step := 0

static func create(gold: bool) -> GreatApe:
	var g := GreatApe.new()
	g.name = "GoldenGreatApe" if gold else "GreatApe"
	g.golden = gold
	g._build()
	return g

## Builds and caches both ape bodies (about 0.1 s) so the first transformation doesn't hitch; call while loading.
static func warm() -> void:
	for gold in [false, true]:
		(ApeBody.build(gold).root as Node).free()

func _build() -> void:
	var b := ApeBody.build(golden)
	rig = b.root
	skeleton = b.skeleton
	add_child(rig)
	rig.scale = Vector3.ONE * VISUAL_SCALE
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	player.root_node = NodePath("..")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("ape", ApeClips.library())
	play("transform_in", 0.0)

## Crossfades to a clip ("ape/<name>").
func play(clip: String, blend := BLEND) -> void:
	if current == clip and player.current_animation == "ape/" + clip and ApeClips.data()[clip].loop:
		return
	current = clip
	_clip_t = 0.0
	_contact_done = false
	player.play("ape/" + clip, blend)

func _busy() -> bool:
	var d: Dictionary = ApeClips.data().get(current, {})
	return not d.is_empty() and not d.loop and _clip_t < float(d.length) - BLEND

func update(dt: float, anim: Dictionary) -> void:
	_time += dt
	_clip_t += dt
	var speed := float(anim.get("speed", 0.0))
	var serial := int(anim.get("attackSerial", 0))
	var reaction := int(anim.get("reactionSerial", 0))
	if anim.get("dead", false):
		if current != "hurt":
			play("hurt")
	elif serial != 0 and serial != _last_attack:
		_last_attack = serial
		var kind := str(anim.get("attackKind", "jab"))
		if kind in ["beam", "ki", "ultimate", "avatar", "utility"]:
			play("mouth_blast", 0.12)
		elif kind.contains("kick") or kind == "knee":
			play("stomp", 0.12)
		else:
			_swing += 1
			play("swipe" if _swing % 3 != 0 else "grab_slam", 0.12)
	elif anim.get("hurt", false) and reaction != _last_reaction:
		play("hurt", 0.08)
	elif not _busy():
		if anim.get("charging", false):
			play("roar")
		elif speed > 0.5 and not anim.get("flying", false):
			play("walk")
		elif current == "idle" and _idle_for > 9.0:
			play("chest_pound")
			_idle_for = 0.0
		elif current != "idle" and (current in ["walk", "roar"] or not _busy()):
			play("idle", 0.3)
	_last_reaction = reaction
	_idle_for = _idle_for + dt if current == "idle" else 0.0
	# walk speed follows the ground speed; strikes play at full speed
	player.speed_scale = clampf(speed / 3.0, 0.6, 2.0) if current == "walk" else 1.0
	# a lean into flight and dashes on top of whatever plays
	rig.rotation.x = lerpf(rig.rotation.x, (0.6 if anim.get("flying", false) and speed > 2.0 else 0.0) + (0.25 if anim.get("dashing", false) else 0.0),
		1.0 - exp(-dt * 6.0))
	player.advance(dt)
	_ground_hits(dt)

## Footfalls on the walk cycle and the impact of stomps/slams: signal + dust (the scene may shake the camera).
func _ground_hits(_dt: float) -> void:
	if current == "walk":
		var cycle := player.current_animation_position / 1.1
		var step := int(floor(cycle * 2.0))
		if step != _last_step:
			_last_step = step
			_hit(skeleton.get_bone_global_pose(skeleton.find_bone("foot.L" if step % 2 == 0 else "foot.R")).origin, 0.35)
	var d: Dictionary = ApeClips.data().get(current, {})
	var contact := float(d.get("contact", -1.0))
	if contact >= 0.0 and not _contact_done and _clip_t >= contact:
		_contact_done = true
		var where := "foot.R" if current == "stomp" else "hand.R"
		if current in ["roar", "chest_pound", "mouth_blast"]:
			return
		_hit(skeleton.get_bone_global_pose(skeleton.find_bone(where)).origin, 1.0)

func _hit(local_pos: Vector3, strength: float) -> void:
	var world := global_transform * (local_pos * VISUAL_SCALE) if is_inside_tree() else local_pos * VISUAL_SCALE
	footfall.emit(world, strength)
	if is_inside_tree() and get_tree().current_scene != null:
		Burst.spawn(get_tree().current_scene, Vector3(world.x, world.y + 0.1, world.z), Color(0.62, 0.55, 0.45, 0.8),
			(1.2 + 2.5 * strength) * global_transform.basis.get_scale().x * 0.25)
