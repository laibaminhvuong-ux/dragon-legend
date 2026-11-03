class_name Fighter
extends Node3D
# A fighter or NPC: the CC0 Quaternius humanoid (53-bone rig, 46 animations) dressed as one of our characters.
# Same contract as the JS model: Fighter.create(look) -> update(dt, anim), set_form(id), set_ki_color, dispose.
# look = { race, skin (index into the race's skins), face, hair, hairColor (index), build, outfit, outfitTint (index),
#          female, kiColor, accessory }

const BASE := preload("res://assets/characters/ual/AnimationLibrary_Godot_Standard.gltf")
const OUTFIT_SHADER := preload("res://characters/shaders/outfit.gdshader")

var look: Dictionary
var body: Node3D          # the imported scene (Skeleton3D + mesh + AnimationPlayer)
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var body_mesh: MeshInstance3D
var material: ShaderMaterial

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
	_apply_look()
	anim_player.play("Idle")

func _apply_look() -> void:
	var race: Dictionary = Tables().races.get(look.get("race", "Human"), {})
	var skins: Array = race.get("skins", [0xf1c8a0])
	var skin := Color.hex((int(skins[clampi(int(look.get("skin", 0)), 0, skins.size() - 1)]) << 8) | 0xff)
	var tints: Array = Tables().appearance.get("TINTS", [0xe86a1a])
	var tint := int(tints[clampi(int(look.get("outfitTint", 0)), 0, tints.size() - 1)]) if not tints.is_empty() else 0xe86a1a
	var parts := Outfits.parts(str(look.get("outfit", "TurtleGi")), tint)
	material.set_shader_parameter("colors", BodyRegions.colours(parts, skin))
	material.set_shader_parameter("plate_gloss", 1.0 if parts.has("armor") else 0.0)
	var build := {"height": 1.0, "width": 1.0, "depth": 1.0}
	for b: Dictionary in Tables().appearance.get("BUILDS", []):
		if b.id == look.get("build", "Average"):
			build = b
	body.scale = Vector3(float(build.width), float(build.height), float(build.depth))

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
