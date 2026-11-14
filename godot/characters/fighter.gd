class_name Fighter
extends Node3D
# A fighter or NPC: the CC0 Quaternius humanoid (53-bone rig, 46 animations) dressed as one of our characters.
# Same contract as the JS model: Fighter.create(look) -> update(dt, anim), set_form(id), set_ki_color(hex),
# set_hair_color(hex), dispose(). Models face +Z; the parent sets rotation.y = yaw.
# look = { race, skin, face, hair, hairColor, build, outfit, outfitTint, female, kiColor, kiColorHex }
# plus optional NPC fields (race-part toggles, hairAnyRace, hairRgb, eyeRgb, outfitRgb/outfitRgb2/outfitParts):
# documented at the top of outfits.gd

const BASE := preload("res://assets/characters/ual/AnimationLibrary_Godot_Standard.gltf")
const OUTFIT_SHADER := preload("res://characters/shaders/outfit.gdshader")
const HAIR_SHADER := preload("res://characters/shaders/hair.gdshader")
# Anime look (cel shading + ink outline + baggy cloth): only fighters with look.shading = "cel" (Gokan for now,
# set in tools/godot_additions.mjs); everyone else keeps the earlier lit look
const OUTFIT_TOON := preload("res://characters/shaders/outfit_toon.gdshader")
const HAIR_TOON := preload("res://characters/shaders/hair_toon.gdshader")
const OUTLINE := preload("res://characters/shaders/outline.gdshader")
const PRO_ANIMS := preload("res://assets/characters/ual/pro.res")
static var _toon_hair: ShaderMaterial
static var _outline_mat: ShaderMaterial
static var _toon_mats: Dictionary = {}   # [StandardMaterial3D, ink] -> its cel-shaded copy
static var _toon_set: Dictionary = {}    # the copies themselves
const FACES := {"Calm": 0, "Fierce": 1, "Smirk": 2, "Determined": 3, "Cold": 4}
const BASE_EYES := {"FrostDemon": 0xb4142a, "Majin": 0x1a1a1a}
static var _hair_material: ShaderMaterial

var look: Dictionary
var race: Dictionary
var body: Node3D          # the imported scene (Skeleton3D + mesh + AnimationPlayer)
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var body_mesh: MeshInstance3D
var material: ShaderMaterial
var hair: MeshInstance3D
var hair_base := ""       # base hair style ("" = bald)
var hair_color: Color
var skin: Color
var base_scale := Vector3.ONE
var cape: MeshInstance3D
var cape_base: Transform3D
var dome: MeshInstance3D
var form_id := ""
var feet: FootPlacement
var _hair_spring := Vector2.ZERO
var _cape_spring := Vector2.ZERO
var anim: AnimController
var form_aura: Aura
var charge_aura: Aura
var kaioken_aura: Aura
var ape: GreatApe
var presentation: Dictionary = {}
var _charge_time := 0.0
var _t := 0.0
var _attachments: Dictionary = {}   # bone -> BoneAttachment3D
var _skin_pieces: Array = []        # [MeshInstance3D, shade]
var _form_nodes: Array[Node] = []
var sculpt: Dictionary = {}       # BodySculpt profile for this look
var face_params: Dictionary = {}  # FaceShape: this character's own face
var _head_xform := Transform3D.IDENTITY
var _hair_fit := Transform3D.IDENTITY   # Hair.skull_fit: hairAnyRace hair on a hairless race's skull
var _joint_shift: Dictionary = {}   # HeroBody: how far each joint moved from the original mannequin
var hero: Dictionary = {}           # HeroBody.wear() result (empty on the original mannequin)
var cloth: Dictionary = {}          # Cloth.params: how loose this outfit's clothes are
var sash_tails: MeshInstance3D      # the sash knot's hanging tails (sway with movement)
var sash_base: Transform3D
var skirt: Array = []               # Skirt: the skinned skirt MeshInstance3D (follows the thighs on the GPU)
var _sash_spring := Vector2.ZERO
const HAIR_MOTION_RANGE := 25.0     # m from the camera: closer fighters' hair moves (Hair.Motion), farther holds still
var hair_motion: Hair.Motion        # created on first use
var _hair_motion_on := false
var _wind_local := Vector3.ZERO     # the wind in the fighter's own frame this frame (zero when motion is off)

static func create(l: Dictionary) -> Fighter:
	WorldWind.ensure_globals()   # the hair shaders read wind_time
	var f := Fighter.new()
	f.name = "Fighter"
	f.look = l
	f._build()
	return f

func _build() -> void:
	body = BASE.instantiate()
	add_child(body)
	skeleton = body.find_children("*", "Skeleton3D", true, false)[0]
	anim_player = body.find_children("*", "AnimationPlayer", true, false)[0]
	body_mesh = body.find_children("*", "MeshInstance3D", true, false)[0]
	var hero_kind := hero_body_kind()
	if hero_kind != "":   # new CC0 body (HeroBody), worn on our rig
		hero = HeroBody.wear(hero_kind, skeleton, body_mesh)   # already carries mannequin-space rest positions
		_joint_shift = hero.shift
	else:
		body_mesh.mesh = BodyRegions.dressed_mesh(body_mesh)
	face_params = FaceShape.params(FaceShape.seed_for(look))
	if str(look.get("age", "")) == "child":
		face_params.nose = float(face_params.nose) * 0.65   # a small button nose
	sculpt = BodySculpt.combine(BodySculpt.profile_for(look), face_params.sculpt)
	var unsculpted: ArrayMesh = body_mesh.mesh
	body_mesh.mesh = BodySculpt.sculpted(unsculpted, sculpt)
	_head_xform = BodySculpt.head_xform(sculpt)
	material = ShaderMaterial.new()
	material.shader = OUTFIT_SHADER
	body_mesh.material_override = material
	race = Tables().races.get(str(look.get("race", "Human")), Tables().races.get("Human", {}))
	var skins: Array = race.get("skins", [0xf1c8a0])
	# NPCs may set an exact skin colour (e.g. King Yemmo's red) outside the race palette
	skin = Parts.hx(look.skinHex) if look.get("skinHex") != null else Parts.hx(skins[clampi(int(look.get("skin", 0)), 0, skins.size() - 1)])
	var hair_cols: Array = Tables().appearance.get("HAIR_COLORS", [0x141414])
	hair_color = Parts.hx(hair_cols[clampi(int(look.get("hairColor", 0)), 0, hair_cols.size() - 1)])
	if Outfits.rgb(look.get("hairRgb")) >= 0:   # a free hair colour outside the palette
		hair_color = Parts.hx(Outfits.rgb(look.get("hairRgb")))
	var tints: Array = Tables().appearance.get("TINTS", [0xe86a1a])
	var tint := int(tints[clampi(int(look.get("outfitTint", 0)), 0, tints.size() - 1)])
	var parts := Outfits.for_look(look, tint)
	cloth = Cloth.params(parts, look)
	body_mesh.mesh = Cloth.dressed(body_mesh.mesh, unsculpted, cloth)
	material.set_shader_parameter("cloth", float(cloth.amount))
	material.set_shader_parameter("sleeve_end", float(cloth.sleeve))
	material.set_shader_parameter("boot_top", float(cloth.boot_top))
	material.set_shader_parameter("boot_detail", clampf(float(cloth.boots), 0.0, 1.0))
	material.set_shader_parameter("colors", BodyRegions.colours(parts))
	material.set_shader_parameter("plate_gloss", 1.0 if parts.has("armor") else 0.0)
	material.set_shader_parameter("face", int(FACES.get(str(look.get("face", "Calm")), 0)))
	var eyes_v: Vector4 = face_params.eyes
	match str(look.get("age", "")):
		"child": eyes_v.x *= 1.45   # big round eyes
		"teen": eyes_v.x *= 1.18

	material.set_shader_parameter("face_eyes", eyes_v)
	var brows_v: Vector4 = face_params.brows
	if look.get("female", false):
		brows_v.x *= 0.6   # finer brows
	material.set_shader_parameter("face_brows", brows_v)
	material.set_shader_parameter("feminine", 1.0 if look.get("female", false) else 0.0)
	material.set_shader_parameter("face_mouth", face_params.mouth)
	var has_hair: bool = race.get("hairStyles", []).size() > 1 or Hair.base_style(look, race) != ""
	material.set_shader_parameter("brow_color", hair_color.darkened(0.3) if has_hair else skin.darkened(0.45))
	_set_skin(skin, 0.0)
	_set_eyes(base_eyes())
	CastB4.apply(self)   # look.skinPattern / faceRgb / mark (cast batch B4)
	var build := {"height": 1.0, "width": 1.0, "depth": 1.0}
	for b: Dictionary in Tables().appearance.get("BUILDS", []):
		if b.id == look.get("build", "Average"):
			build = b
	base_scale = Vector3(float(build.width), float(build.height) * float(sculpt.get("height", 1.0)), float(build.depth))
	if not hero.is_empty() and float(hero.height) < 0.95:   # a teen body: keep its proportions, heights from the sculpt
		base_scale *= 1.0 / float(hero.height)
	body.scale = base_scale
	Parts.dress(self, parts, str(race.get("id", "")), skin)
	CastB4.dress(self, parts)   # Red Ribbon badge, epaulettes, wizard cape collar (outfitParts)
	var costumes: Variant = look.get("costume", "")
	var before := skeleton.find_children("*", "MeshInstance3D", true, false)
	for c: Variant in (costumes if costumes is Array else [costumes]):
		Parts.costume(self, str(c))
	for mi: Node in skeleton.find_children("*", "MeshInstance3D", true, false):
		if not before.has(mi):   # costume pieces (turbans, hats, props) count as the robe: form_looks robeOff hides them
			mi.set_meta("robe", true)
	if cape != null:
		cape_base = cape.transform
	if sash_tails != null:
		sash_base = sash_tails.transform
	hair_base = Hair.base_style(look, race)
	if not (race.get("hairStyles", []) as Array).size() > 1 and hair_base != "":   # hairAnyRace on a hairless race's skull
		_hair_fit = Hair.skull_fit(Hair.skull(unsculpted), Hair.skull(body_mesh.mesh))
	if hair_base != "":
		hair = _add_hair(hair_base)
		_set_hair(hair_color, 0.0)
	if not anim_player.has_animation_library("pro"):   # Universal Animation Library Pro clips on our rig (tools_bake_anims.gd)
		anim_player.add_animation_library("pro", PRO_ANIMS)
	anim = AnimController.new(self)
	if not hero.is_empty():
		anim.mod.hips_shift = hero.hips   # animations hold the hips at the mannequin's height
	_toonify()
	feet = FootPlacement.new()
	feet.name = "FootPlacement"
	skeleton.add_child(feet)
	if str(look.get("form", "")) != "":   # an NPC drawn in a form by default (Majinn Vegara in Super Saiyan 2)
		set_form(str(look.form))

## How far the body is visually lunging forward right now (metres, world scale).
func lunge_world() -> float:
	return body.position.z * scale.z

## Per-frame update with the JS anim contract (see AnimController); also swings the cape.
func update(dt: float, a: Dictionary = {}) -> void:
	if dt <= 0.0:
		return
	a = a.duplicate()
	a.merge(presentation,true)
	a.yaw = rotation.y
	_t += dt
	_charge_time = minf(2.0,_charge_time+dt) if a.get("charging",false) else 0.0
	anim.update(dt, a)
	var grounded: bool = a.get("onGround",true) and not a.get("flying",false) and not a.get("dead",false) and not a.get("dashing",false) and not anim.kicking() and ape==null
	var foot_weight := 1.0 if float(a.get("speed",0))<0.5 else 0.25
	feet.weight = lerpf(feet.weight,foot_weight if grounded else 0.0,1.0-exp(-dt*14))
	if a.get("charging", false) and charge_aura == null:
		var cl: Dictionary = Tables().appearance.get("KI_CHARGE_LOOK", {}).duplicate()
		cl["color"] = ki_color()
		charge_aura = Aura.create(cl)
		charge_aura.name = "ChargeAura"
		body.add_child(charge_aura)
	if charge_aura != null:
		charge_aura.visible = a.get("charging", false)
		if charge_aura.visible:
			charge_aura.scale = Vector3.ONE*(0.72+0.28*smoothstep(0,1.5,_charge_time))
			charge_aura.update(dt)
	var kk: bool = bool(a.get("kaioken", false))
	if kk and kaioken_aura == null:
		kaioken_aura = Aura.create(Tables().kaioken.get("aura", {}))
		kaioken_aura.name = "KaiokenAura"
		body.add_child(kaioken_aura)
	if kaioken_aura != null:
		kaioken_aura.visible = kk
		if kk: kaioken_aura.update(dt)
	if form_aura != null:
		form_aura.update(dt)
	if ape != null:
		ape.update(dt, a)
	if hair != null:
		if not hair.has_meta("motion_base"):
			hair.set_meta("motion_base",hair.transform)
		var hair_rest: Transform3D = hair.get_meta("motion_base")
		var target := sin(_t*22)*minf(1,_charge_time)*0.012
		_hair_spring = MotionStyle.spring(_hair_spring.x,_hair_spring.y,target,dt,20)
		if absf(_hair_spring.x)<0.00001 and _charge_time==0: _hair_spring = Vector2.ZERO
		hair.transform = hair_rest*Transform3D(Basis.from_euler(Vector3(0,0,_hair_spring.x)),Vector3.ZERO)
	_secondary_motion(dt)
	if cape != null:
		var target := minf(0.9,float(a.get("speed",0))*0.08)+sin(_t*(14 if _charge_time>0 else 3))*(0.07 if _charge_time>0 else 0.03)
		target += _wind_lift(0.05, 3.1)   # a headwind lifts the cape back, a tailwind presses it forward
		_cape_spring = MotionStyle.spring(_cape_spring.x,_cape_spring.y,target,dt,10)
		cape.transform = cape_base*Transform3D(Basis.from_euler(Vector3(_cape_spring.x,0,0)),Vector3.ZERO)
	if sash_tails != null:   # the sash tails lift and flutter with speed (pivot: the knot)
		var sp := float(a.get("speed",0))
		var target := minf(0.75,sp*0.07)+sin(_t*(9.0 if sp>2.0 else 2.2))*(0.06 if sp>2.0 else 0.025)+(0.12 if _charge_time>0 else 0.0)*sin(_t*16)
		target += _wind_lift(0.04, 4.3)
		_sash_spring = MotionStyle.spring(_sash_spring.x,_sash_spring.y,target,dt,12)
		var flutter := sin(_t*(11.0 if sp>2.0 else 2.6)+0.7)*(0.1 if sp>2.0 else 0.03)
		sash_tails.transform = sash_base*Transform3D(Basis.from_euler(Vector3(-_sash_spring.x,0,flutter)),Vector3.ZERO)   # lifts away from the thighs

## Hair secondary motion (Hair.Motion -> the hair shaders' hair_sway): hair lags the fighter's motion and leans with
## the wind. Off on the "low" graphics quality and beyond HAIR_MOTION_RANGE from the camera (crowds stay cheap).
func _secondary_motion(dt: float) -> void:
	var on := WorldWind.hair_motion_enabled() and _near_camera()
	_wind_local = Vector3.ZERO
	if not on:
		if _hair_motion_on:
			_hair_motion_on = false
			if hair_motion != null:
				hair_motion.reset()
			if hair != null:
				hair.set_instance_shader_parameter("hair_sway", Vector4.ZERO)
		return
	_hair_motion_on = true
	var wind := WorldWind.vector()
	var inside := is_inside_tree()
	if wind != Vector3.ZERO:
		_wind_local = (global_transform.basis if inside else transform.basis).inverse() * wind
	if hair == null:
		return
	if hair_motion == null:
		hair_motion = Hair.Motion.new()
	var off := hair_motion.step(dt, global_position if inside else position, wind)
	var local := hair.global_transform.basis.inverse() * off if inside else off   # into the hair mesh's own space
	hair.set_instance_shader_parameter("hair_sway", Vector4(local.x, local.y, local.z, minf(wind.length() / WorldWind.AIR_SPEED, 1.5)))

func _near_camera() -> bool:
	if not is_inside_tree():
		return true
	var cam := get_viewport().get_camera_3d()
	return cam == null or cam.global_position.distance_squared_to(global_position) < HAIR_MOTION_RANGE * HAIR_MOTION_RANGE

## Cape / sash lift from the wind along the fighter's back (radians): `k` per m/s, fluttering at `rate`.
func _wind_lift(k: float, rate: float) -> float:
	if _wind_local == Vector3.ZERO:
		return 0.0
	return clampf(-_wind_local.z * k, -0.25, 0.5) + sin(_t * rate * (1.0 + _wind_local.length() * 0.08)) * minf(_wind_local.length(), 10.0) * 0.006

static func hair_material() -> ShaderMaterial:
	if _hair_material == null:
		_hair_material = ShaderMaterial.new()
		_hair_material.shader = HAIR_SHADER
	return _hair_material

# ----------------------------------------------------------------------------------- pieces on bones
# ----------------------------------------------------------------------------------- sockets
## Named attach points for skill VFX and sound (Codex's skill catalogue): bone + rest-pose offset (metres, model space).
const SOCKETS := {
	"hand_l": ["DEF-hand.L", Vector3(0.80, 1.44, -0.065)], "hand_r": ["DEF-hand.R", Vector3(-0.80, 1.44, -0.065)],
	"chest": ["DEF-spine.003", Vector3(0, 1.32, 0.12)], "head": ["DEF-head", Vector3(0, 1.68, 0)],
	"pelvis": ["DEF-hips", Vector3(0, 0.92, 0)], "foot_l": ["DEF-foot.L", Vector3(0.089, 0.05, 0.05)],
	"foot_r": ["DEF-foot.R", Vector3(-0.089, 0.05, 0.05)], "aura_root": ["", Vector3(0, 0.0, 0)],
	"cast_origin": ["DEF-spine.003", Vector3(0, 1.3, 0.45)],
}

## World transform of a named socket (see SOCKETS); it follows the animated skeleton and the body's scale.
## Unknown names return the fighter's own transform.
func socket(socket_name: String) -> Transform3D:
	var def: Array = SOCKETS.get(socket_name, ["", Vector3.ZERO])
	var bone: String = def[0]
	var rest_point: Vector3 = def[1]
	var me := global_transform if is_inside_tree() else transform
	if bone == "" or skeleton == null:
		return me * Transform3D(Basis.IDENTITY, rest_point * base_scale)
	var i := skeleton.find_bone(bone)
	if i < 0:
		return me
	var to_skeleton := Transform3D.IDENTITY   # skeleton space -> fighter space (works outside the tree too)
	var n: Node = skeleton
	while n != null and n != self:
		if n is Node3D:
			to_skeleton = (n as Node3D).transform * to_skeleton
		n = n.get_parent()
	var rest := skeleton.get_bone_global_rest(i)
	var pose := skeleton.get_bone_global_pose(i)
	return me * to_skeleton * pose * rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest_point)

func _attachment(bone: String) -> BoneAttachment3D:
	if not _attachments.has(bone):
		var a := BoneAttachment3D.new()
		a.name = bone
		a.bone_name = bone
		skeleton.add_child(a)
		_attachments[bone] = a
	return _attachments[bone]

## Adds a mesh that follows a bone. `frame` is where the mesh's origin sits in model space at the rest pose.
func add_piece(bone: String, frame: Transform3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	var i := skeleton.find_bone(bone)
	if bone == "DEF-head":
		frame = _head_xform * frame
		if not hero.is_empty():   # head pieces (hair, ears, antennae) follow the new head's shape
			frame = (hero.head as Transform3D) * frame
	elif _joint_shift.has(bone):   # pieces are placed for the original mannequin: follow the new body's joint
		frame.origin += _joint_shift[bone]
	mi.transform = skeleton.get_bone_global_rest(i).affine_inverse() * frame
	_attachment(bone).add_child(mi)
	return mi

## The hair piece for a style, refitted to a hairless race's own skull (_hair_fit, model space) when it has one.
func _add_hair(style: String) -> MeshInstance3D:
	var mi := add_piece("DEF-head", Hair.HEAD_SPACE, Hair.mesh(style), hair_material())
	if _hair_fit != Transform3D.IDENTITY:
		var rest := skeleton.get_bone_global_rest(skeleton.find_bone("DEF-head"))
		var h: Transform3D = hero.head if not hero.is_empty() else Transform3D.IDENTITY
		# placed = H * hx * frame; refitted = fit * H * frame (the skull fit replaces the sculpt's rough head scale)
		var placed := rest * mi.transform
		mi.transform = rest.affine_inverse() * _hair_fit * h * _head_xform.affine_inverse() * h.affine_inverse() * placed
	return mi

var _robe_hidden := false
func _show_robe(on: bool) -> void:
	_robe_hidden = not on
	for mi: Node in skeleton.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("robe"):
			(mi as MeshInstance3D).visible = on

## Marks a piece as skin-coloured (shade = its brightness relative to the skin), so forms recolour it.
func add_skin_piece(mi: MeshInstance3D, shade: float) -> void:
	_skin_pieces.append([mi, shade])

# ----------------------------------------------------------------------------------- looks
func _set_skin(c: Color, metal: float) -> void:
	material.set_shader_parameter("skin_color", c)
	material.set_shader_parameter("skin_metal", metal)
	for sp: Array in _skin_pieces:
		var mi: MeshInstance3D = sp[0]
		var m: StandardMaterial3D = mi.material_override
		mi.material_override = Parts.material(Color(c.r * sp[1], c.g * sp[1], c.b * sp[1]), m.roughness, metal)
		if is_anime(): mi.material_override = _toon_copy(mi.material_override)

## Which Universal Base Characters body this look wears (user request 2026-11-06: every fighter and NPC);
## look.body = "classic" keeps the original mannequin ("" when it does).
func hero_body_kind() -> String:
	if str(look.get("body", "")) == "classic":
		return ""
	var age := str(look.get("age", ""))
	var base := "teen" if age == "child" or age == "teen" else "hero"
	return base + ("_female" if look.get("female", false) else "_male")

func is_anime() -> bool:
	if _env_shading == "":
		_env_shading = OS.get_environment("DL_SHADING") + "-"   # dev: DL_SHADING=classic for A/B frame-time checks
	# opt-in per character (user request 2026-11-10: the cloth/cel style is for Gokan only until the custom model arrives)
	return (str(look.get("shading", "")) == "cel" or look.get("anime", false) == true) and _env_shading != "classic-"
static var _env_shading := ""

static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = OUTLINE
	return _outline_mat

## Anime look: the body and hair switch to the cel shaders, every plain piece (belt, bands, tail, armour...) gets a
## cel-shaded copy of its material; the body gets the ink outline (pieces are open shells, a hull would show). Effects (auras, glows) are left alone.
func _toonify() -> void:
	if not is_anime():
		return
	material.shader = OUTFIT_TOON
	material.next_pass = outline_material()
	if _toon_hair == null:
		_toon_hair = ShaderMaterial.new()
		_toon_hair.shader = HAIR_TOON
		# the ink line round the hair too: drawn behind the hair (outline.gdshader's depth offset), so the open
		# underside of the shell stays clean against the head
		_toon_hair.next_pass = outline_material()
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var m: Material = mi.material_override
		if m == _hair_material:
			mi.material_override = _toon_hair
		elif m is StandardMaterial3D:
			mi.material_override = _toon_copy(m, mi.has_meta("ink"))

## `ink`: closed solid pieces (sash, wristbands) also get the ink outline.
static func _toon_copy(m: StandardMaterial3D, ink := false) -> StandardMaterial3D:
	if _toon_set.has(m) or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return m
	var key := [m, ink]
	if not _toon_mats.has(key):
		var t: StandardMaterial3D = m.duplicate()
		t.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		t.specular_mode = BaseMaterial3D.SPECULAR_TOON
		t.roughness = maxf(t.roughness, 0.7)
		t.metallic_specular = 0.2
		if ink:
			t.next_pass = outline_material()
		_toon_mats[key] = t
		_toon_set[t] = true
	return _toon_mats[key]

## The eye colour outside forms: look.eyeRgb, else the race's.
func base_eyes() -> int:
	var own := Outfits.rgb(look.get("eyeRgb"))
	return own if own >= 0 else int(BASE_EYES.get(race.get("id", ""), 0x2a1d14))

func _set_eyes(hex: int) -> void:
	material.set_shader_parameter("eye_color", Parts.hx(hex))

func _set_hair(c: Color, glow: float) -> void:
	if hair != null:
		hair.set_instance_shader_parameter("hair_color", c)
		hair.set_instance_shader_parameter("glow", glow)

func set_hair_color(hex: Variant) -> void:
	if hex != null:
		hair_color = Parts.hx(hex)
	if form_id == "" or not (form_look(form_id).get("hair") is Dictionary):
		_set_hair(hair_color, 0.0)

## Kaiyoken stacked on a form shows that form's Kaiyoken look (both are unlockable in the base game; display only,
## the rules multiply as before). Other forms keep their own look while Kaiyoken is on.
const KAIOKEN_LOOKS := {"SSJ": "SuperKaioken", "SSJBlue": "SSJBlueKaioken"}
static func shown_form(form: String, kaioken: float) -> String:
	return str(KAIOKEN_LOOKS.get(form, form)) if kaioken > 0.0 else form

## The form look this fighter shows for a form id: look.formLooks may point a form at its own variant entry
## (e.g. {"SSJ": "SSJBroly"}: Brolo's green-gold Super Saiyan), else the shared form_looks entry.
func form_look(id: String) -> Dictionary:
	var own: Variant = look.get("formLooks")
	if own is Dictionary and Tables().form_looks.has(str((own as Dictionary).get(id, ""))):
		return Tables().form_looks[str(own[id])]
	return Tables().form_looks.get(id, {})

func set_ki_color(hex: int) -> void:
	look["kiColorHex"] = "#%06x" % hex
	if charge_aura != null:
		charge_aura.set_color(hex)

## The fighter's Ki colour (custom hex or palette index, as the rules resolve it).
func ki_color() -> int:
	return RuleRuntime.ki_color(look)

## Shows a transformation as in the story (data form_looks); "" = base form. Unknown forms show the base look.
func set_form(id: String) -> void:
	if id == form_id:
		return
	_clear_form()
	form_id = id
	anim.set_form(id)
	var F: Dictionary = form_look(id)
	if F.is_empty():
		return
	var fh: Variant = F.get("hair")
	if fh is Dictionary:
		var style := Hair.form_style(str(fh.get("style", "same")), hair_base)
		if hair == null and Hair.race_has_hair(look, race):   # hairless races never grow form hair
			hair = _add_hair(style)
			_form_nodes.append(hair)
		elif hair != null:
			hair.mesh = Hair.mesh(style)
		_set_hair(Parts.hx(fh.color), float(fh.get("glow", 0.3)))
	if F.get("eyes") != null:
		_set_eyes(int(F.eyes))
	if F.get("brows") == false:
		material.set_shader_parameter("brows", 0.0)
	if F.get("skin") != null:
		_set_skin(Parts.hx(F.skin), float(F.get("skinMetal", 0.0)))
	elif F.get("flush") is Array:
		_set_skin(skin.lerp(Parts.hx(F.flush[0]), float(F.flush[1])), 0.0)
	if F.get("dome") != null and dome != null:
		dome.material_override = Parts.material(Parts.hx(F.dome), 0.15, 0.1)
	_form_nodes.append_array(Parts.form_extras(self, F))   # shells / chitin colours, form-only gear (horns)
	var robe_off: Variant = F.get("robeOff", false)
	if robe_off is bool and robe_off:   # fights without cape and costume pieces (Orange Piccor drops cape and turban)
		_show_robe(false)
		var antenna: Variant = look.get("antenna", "namek")
		if str(race.get("id", "")) == "Namekian" and antenna is bool and not antenna:   # the turban had them tucked in
			var ant := Parts.namek_antennae(self, skin, false)
			if F.get("skin") != null:
				ant.material_override = Parts.material(Parts.hx(F.skin) * 0.9, 0.55)
			_form_nodes.append(ant)
	_toonify()
	var sc := base_scale
	if F.get("scale") != null: sc = base_scale * float(F.scale)
	if F.get("bulk") is Array: sc = base_scale * Vector3(float(F.bulk[0]), float(F.bulk[1]), float(F.bulk[2]))
	if F.get("slim", false): sc = base_scale * Vector3(0.95, 1.01, 0.95)
	body.scale = sc
	if F.get("fur") != null:   # Super Saiyan 4: red fur on the arms and chest (form_looks fur colour)
		_ssj4_fur(Parts.hx(F.fur))
	elif id == "SSJ4":
		_ssj4_fur()
	if id == "Oozaru" or id == "GoldenOozaru":
		skeleton.visible = false
		ape = GreatApe.create(id == "GoldenOozaru")
		body.add_child(ape)
		_form_nodes.append(ape)
	if F.get("aura") is Dictionary:
		form_aura = Aura.create(F.aura)
		form_aura.name = "FormAura"
		body.add_child(form_aura)
		form_aura.flare()
		_form_nodes.append(form_aura)

func _ssj4_fur(colour := Color.hex(0xa72437ff)) -> void:
	var fur := Parts.material(colour, 0.95)
	for s in [1, -1]:
		var side := "L" if s > 0 else "R"
		_form_nodes.append(add_piece("DEF-upper_arm." + side, Transform3D.IDENTITY, Parts._mesh("fur_arm%d" % s, func(g: Geo) -> void:
			g.sphere(Transform3D(Basis.from_scale(Vector3(2.0, 1.0, 1.0)), Vector3(s * 0.33, 1.4408, -0.065)), 0.075)), fur))
		_form_nodes.append(add_piece("DEF-forearm." + side, Transform3D.IDENTITY, Parts._mesh("fur_fore%d" % s, func(g: Geo) -> void:
			g.sphere(Transform3D(Basis.from_scale(Vector3(1.9, 0.9, 1.0)), Vector3(s * 0.57, 1.4408, -0.068)), 0.065)), fur))
	_form_nodes.append(add_piece("DEF-spine.002", Transform3D.IDENTITY, Parts._mesh("fur_chest", func(g: Geo) -> void:
		for s in [1, -1]:
			g.sphere(Transform3D(Basis.from_scale(Vector3(0.9, 2.0, 1.4)), Vector3(s * 0.13, 1.25, -0.005)), 0.1)
		g.sphere(Transform3D(Basis.from_scale(Vector3(2.0, 2.0, 0.5)), Vector3(0, 1.25, -0.08)), 0.11)), fur))

func _clear_form() -> void:
	for n in _form_nodes:
		if n == hair:
			hair = null
		var holder := n.get_parent()
		_drop(n)
		if holder is BoneAttachment3D and holder.get_child_count() == 0:
			_attachments.erase((holder as BoneAttachment3D).bone_name)
			_drop(holder)
	_form_nodes.clear()
	form_aura = null
	ape = null
	skeleton.visible = true
	if hair != null:
		hair.mesh = Hair.mesh(hair_base)
		_set_hair(hair_color, 0.0)
	_set_skin(skin, 0.0)
	_set_eyes(base_eyes())
	material.set_shader_parameter("brows", 1.0)
	Parts.form_reset(self)   # own dome/shell colours, outfit colours, look.skinMetal
	if _robe_hidden:
		_show_robe(true)
	body.scale = base_scale

func dispose() -> void:
	_clear_form()
	for au in [charge_aura, kaioken_aura]:
		if au != null: au.dispose()
	charge_aura = null; kaioken_aura = null
	_drop(self)

## Frees a node now (detached first, so it leaves the scene immediately even mid-frame).
static func _drop(n: Node) -> void:
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()

## Data tables (the Data autoload in the game; read directly in headless tools/tests).
static func Tables() -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("Data") and not tree.root.get_node("Data").races.is_empty():
		return tree.root.get_node("Data")
	if _fallback == null:
		_fallback = load("res://core/data.gd").new()
		_fallback.load_dir("res://data")
	return _fallback
static var _fallback: Node

func set_terrain(terrain: RuleZone) -> void:
	feet.terrain = terrain
