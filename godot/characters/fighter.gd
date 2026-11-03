class_name Fighter
extends Node3D
# A fighter or NPC: the CC0 Quaternius humanoid (53-bone rig, 46 animations) dressed as one of our characters.
# Same contract as the JS model: Fighter.create(look) -> update(dt, anim), set_form(id), set_ki_color(hex),
# set_hair_color(hex), dispose(). Models face +Z; the parent sets rotation.y = yaw.
# look = { race, skin, face, hair, hairColor, build, outfit, outfitTint, female, kiColor, kiColorHex }

const BASE := preload("res://assets/characters/ual/AnimationLibrary_Godot_Standard.gltf")
const OUTFIT_SHADER := preload("res://characters/shaders/outfit.gdshader")
const HAIR_SHADER := preload("res://characters/shaders/hair.gdshader")
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
var anim: AnimController
var form_aura: Aura
var charge_aura: Aura
var kaioken_aura: Aura
var ape: GreatApe
var _t := 0.0
var _attachments: Dictionary = {}   # bone -> BoneAttachment3D
var _skin_pieces: Array = []        # [MeshInstance3D, shade]
var _form_nodes: Array[Node] = []

static func create(l: Dictionary) -> Fighter:
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
	body_mesh.mesh = BodyRegions.dressed_mesh(body_mesh)
	material = ShaderMaterial.new()
	material.shader = OUTFIT_SHADER
	body_mesh.material_override = material
	race = Tables().races.get(str(look.get("race", "Human")), Tables().races.get("Human", {}))
	var skins: Array = race.get("skins", [0xf1c8a0])
	# NPCs may set an exact skin colour (e.g. King Yemmo's red) outside the race palette
	skin = Parts.hx(look.skinHex) if look.get("skinHex") != null else Parts.hx(skins[clampi(int(look.get("skin", 0)), 0, skins.size() - 1)])
	var hair_cols: Array = Tables().appearance.get("HAIR_COLORS", [0x141414])
	hair_color = Parts.hx(hair_cols[clampi(int(look.get("hairColor", 0)), 0, hair_cols.size() - 1)])
	var tints: Array = Tables().appearance.get("TINTS", [0xe86a1a])
	var tint := int(tints[clampi(int(look.get("outfitTint", 0)), 0, tints.size() - 1)])
	var parts := Outfits.parts(str(look.get("outfit", "TurtleGi")), tint)
	material.set_shader_parameter("colors", BodyRegions.colours(parts))
	material.set_shader_parameter("plate_gloss", 1.0 if parts.has("armor") else 0.0)
	material.set_shader_parameter("face", int(FACES.get(str(look.get("face", "Calm")), 0)))
	material.set_shader_parameter("brow_color", hair_color.darkened(0.3) if race.get("hairStyles", []).size() > 1 else skin.darkened(0.45))
	_set_skin(skin, 0.0)
	_set_eyes(int(BASE_EYES.get(race.get("id", ""), 0x2a1d14)))
	var build := {"height": 1.0, "width": 1.0, "depth": 1.0}
	for b: Dictionary in Tables().appearance.get("BUILDS", []):
		if b.id == look.get("build", "Average"):
			build = b
	base_scale = Vector3(float(build.width), float(build.height), float(build.depth))
	body.scale = base_scale
	Parts.dress(self, parts, str(race.get("id", "")), skin)
	Parts.costume(self, str(look.get("costume", "")))
	if cape != null:
		cape_base = cape.transform
	hair_base = Hair.base_style(look, race)
	if hair_base != "":
		hair = add_piece("DEF-head", Hair.HEAD_SPACE, Hair.mesh(hair_base), hair_material())
		_set_hair(hair_color, 0.0)
	anim = AnimController.new(self)

## Per-frame update with the JS anim contract (see AnimController); also swings the cape.
func update(dt: float, a: Dictionary = {}) -> void:
	if dt <= 0.0:
		return
	_t += dt
	anim.update(dt, a)
	if a.get("charging", false) and charge_aura == null:
		var cl: Dictionary = Tables().appearance.get("KI_CHARGE_LOOK", {}).duplicate()
		cl["color"] = ki_color()
		charge_aura = Aura.create(cl)
		charge_aura.name = "ChargeAura"
		body.add_child(charge_aura)
	if charge_aura != null:
		charge_aura.visible = a.get("charging", false)
		if charge_aura.visible: charge_aura.update(dt)
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
	if cape != null:
		cape.transform = cape_base * Transform3D(Basis.from_euler(Vector3(minf(0.9, float(a.get("speed", 0.0)) * 0.08) + sin(_t * 3.0) * 0.03, 0, 0)), Vector3.ZERO)

static func hair_material() -> ShaderMaterial:
	if _hair_material == null:
		_hair_material = ShaderMaterial.new()
		_hair_material.shader = HAIR_SHADER
	return _hair_material

# ----------------------------------------------------------------------------------- pieces on bones
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
	mi.transform = skeleton.get_bone_global_rest(i).affine_inverse() * frame
	_attachment(bone).add_child(mi)
	return mi

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

func _set_eyes(hex: int) -> void:
	material.set_shader_parameter("eye_color", Parts.hx(hex))

func _set_hair(c: Color, glow: float) -> void:
	if hair != null:
		hair.set_instance_shader_parameter("hair_color", c)
		hair.set_instance_shader_parameter("glow", glow)

func set_hair_color(hex: Variant) -> void:
	if hex != null:
		hair_color = Parts.hx(hex)
	if form_id == "" or not (Tables().form_looks.get(form_id, {}).get("hair") is Dictionary):
		_set_hair(hair_color, 0.0)

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
	var F: Dictionary = Tables().form_looks.get(id, {})
	if F.is_empty():
		return
	var fh: Variant = F.get("hair")
	if fh is Dictionary:
		var style := Hair.form_style(str(fh.get("style", "same")), hair_base)
		if hair == null:
			hair = add_piece("DEF-head", Hair.HEAD_SPACE, Hair.mesh(style), hair_material())
			_form_nodes.append(hair)
		else:
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
	var sc := base_scale
	if F.get("scale") != null: sc = base_scale * float(F.scale)
	if F.get("bulk") is Array: sc = base_scale * Vector3(float(F.bulk[0]), float(F.bulk[1]), float(F.bulk[2]))
	if F.get("slim", false): sc = base_scale * Vector3(0.95, 1.01, 0.95)
	body.scale = sc
	if id == "SSJ4":
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

func _ssj4_fur() -> void:
	var fur := Parts.material(Color.hex(0xa72437ff), 0.95)
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
	_set_eyes(int(BASE_EYES.get(race.get("id", ""), 0x2a1d14)))
	material.set_shader_parameter("brows", 1.0)
	if dome != null:
		dome.material_override = Parts.material(Color.hex(0x8a3ab8ff), 0.15, 0.1)
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
