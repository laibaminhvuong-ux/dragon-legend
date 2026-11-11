extends TestCase
# Cast batch B2: Saiyans, fusions and forms. Per-character form variants (look.formLooks), a default form (look.form),
# the form_looks fur field, the new fusion rows and the tail-less adult Saiyans.

func _fur(f: Fighter) -> bool:
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == Parts._meshes.get("fur_chest"):
			return true
	return false

func test_form_variants() -> void:
	var forms: Dictionary = Fighter.Tables().form_looks
	var f := Fighter.create({"race": "Saiyan", "hair": "LongSpiky", "formLooks": {"SSJ": "SSJBroly", "SSJ2": "NoSuchLook"}})
	eq(f.form_look("SSJ"), forms.SSJBroly, "formLooks points SSJ at the variant")
	eq(f.form_look("SSJ2"), forms.SSJ2, "an unknown variant falls back to the shared look")
	eq(f.form_look("SSJ3"), forms.SSJ3, "forms without a variant use the shared look")
	f.set_form("SSJ")
	eq(f.form_id, "SSJ", "the form id stays the rules id")
	eq(f.form_aura.look.color, forms.SSJBroly.aura.color, "variant aura")
	f.set_form("")
	f.free()

func test_default_form_and_fur() -> void:
	var f := Fighter.create({"race": "Saiyan", "hair": "Swept", "form": "SSJ2"})
	eq(f.form_id, "SSJ2", "look.form draws the NPC in that form")
	ok(f.form_aura != null, "with its aura")
	f.set_form("")
	eq(f.form_id, "", "and it can still go back to base")
	f.free()
	var g := Fighter.create({"race": "Saiyan", "hair": "Spiky", "formLooks": {"SSJ4": "SSJ4Gogeta"}})
	g.set_form("SSJ4")
	ok(_fur(g), "Super Saiyan 4 variant keeps the red fur")
	g.set_form("")
	ok(not _fur(g), "fur removed with the form")
	g.free()

func test_b2_cast_data() -> void:
	var chars: Dictionary = Fighter.Tables().characters
	for id: String in ["gogeta", "vegito"]:
		ok(chars.has(id), "%s exists" % id)
		ok(not str(chars[id].name).contains("Gogeta") and not str(chars[id].name).contains("Vegito"), "%s keeps a renamed display name" % id)
	for id: String in ["goku", "vegeta", "goku_black", "broly", "cabba", "paragus", "kefla", "gogeta", "vegito", "majin_vegeta"]:
		eq(Parts.features("Saiyan", chars[id].look).tail, "", "%s: no tail" % id)
	eq(Parts.features("Saiyan", chars.goku_kid.look).tail, "saiyan", "young Gokan keeps his tail")
	var forms: Dictionary = Fighter.Tables().form_looks
	for k: String in ["SSJRose", "SSJBlueKaioken", "SSJBlueEvolved", "Wrathful", "SSJKefla", "JirenFullPower", "ToppoGoD", "SSJ4Gogeta", "SSJ4Daima", "SSJBroly"]:
		ok(forms.has(k), "form look %s" % k)
	for id: String in ["majin_vegeta", "gogeta", "vegito", "broly", "kefla", "goku_black"]:
		var f := Fighter.create(chars[id].look)
		ok(f.body != null, "%s builds" % id)
		f.free()
