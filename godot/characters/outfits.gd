class_name Outfits
extends RefCounted
# ------------------------------------------------------------------------------------------------ look fields
# Optional per-character look fields (cast batch B1, 2026-11-10). All are optional: a look without them (every
# player save) draws exactly as before. NPC looks set them in tools/godot_additions.mjs. Colours are 0xRRGGBB ints
# (or "#rrggbb" strings).
#   Race parts (Parts.features): each race has defaults, these override one at a time.
#     raceParts: false          start from no race parts at all (then add some back with the keys below)
#     tail:    false | "saiyan" | "frost" | "cat"     (Saiyan default "saiyan", FrostDemon "frost")
#     dome:    false | true     Frost Demon head dome (FrostDemon default true; form_looks dome colour still applies)
#     shells:  false | true     Frost Demon shoulder domes + chest plate (FrostDemon default true)
#     antenna: false | "namek" | "long" | "buu"      (Namekian "namek", Majin "buu"; "long" = two long feelers)
#     ears:    false | "pointed" Namek/Kai pointed ears (Namekian default "pointed")
#     patches: false | true     Namekian pink arm patches (Namekian default true)
#   Hair (Hair.base_style):
#     hairAnyRace: true         draw look.hair even on a hairless race (Namekian/FrostDemon/Majin). Races with hair
#                               (Saiyan/HalfSaiyan/Human) draw every style, also ones the creator does not offer them.
#     hair adds the NPC-only styles "Mohawk", "AngelCrest", "Dreadlocks".
#     hairRgb: 0xRRGGBB         base hair colour instead of the 6-colour hairColor palette (form_looks hair colours
#                               still replace it during a form and it comes back after).
#   Eyes:   eyeRgb: 0xRRGGBB    base eye colour (instead of the race default); form_looks eyes still win in a form.
#   Outfit (Outfits.for_look):
#     outfitRgb:  0xRRGGBB      the outfit's main colour instead of the outfitTint palette entry
#     outfitRgb2: 0xRRGGBB      accent colour: sash, wristbands, undershirt and armour trim (where the outfit has them)
#     outfitParts: {part: colour | false}   per-part override, applied last. Parts: top, pants, shoes, sash, wrist,
#                               undershirt, gloves, collar, cape, boot_trim, laces (colour = add/recolour, false =
#                               remove), plate / trim (armour colours; plate on an outfit without armour adds a
#                               cuirass), pads (bool, armour shoulder pads), sleeves / vest (bool), cloth (0..1 looseness).
#   Costume: look.costume may be one id or an array of ids (Parts.costume), e.g. ["halo", "potara"].
# Cast batch B3 (Frieza Force, Frost Demons, Z-era Saiyans):
#   outfit "FriezaForce": battle armour with big flared shoulder flaps, hip flaps and a ribbed belly panel; outfitRgb =
#                               the body suit, plate = white chest plate, trim (outfitRgb2) = flaps/belly/belt colour.
#                               outfitParts flaps / belly (bool) switch those pieces (also on any armoured outfit).
#   outfit "FrostBody":         no clothes at all (a Frost Demon's natural body): every region shows the skin, so
#                               forms recolour the whole body. outfitParts can still paint chitin: {top: 0xe8f0ec}.
#   outfitParts value "skin":   that region shows the skin (e.g. {pants: "skin"}).
#   domeRgb / shellRgb:         Frost dome colour and shoulder/chest shell colour (default purple dome, bone-white
#                               shells); form_looks dome / shells still win during a form.
#   skinMetal: 0..1             metallic skin outside forms (Mecha Frigor).
#   form_looks extras (Parts.form_extras): shells (colour), chitin (colour of the torso, forearm guards and shins: two-tone
#                               Frost forms), gear (array of Parts.gear ids worn only in that form, e.g. horns).
#   New gear ids: scouter, scouter_red, scouter_purple, scouter_blue, frost_horns, frost_horns_big, cold_horns,
#                 third_crest, head_spikes, mustache, tiara, red_bands, cap, four_eyes.
#   Forms (cast batch B2, Fighter.set_form / form_look):
#     form: "SSJ2"              drawn in this form from the start (NPCs only; Majinn Vegara)
#     formLooks: {form: lookId}  show a form with this character's own form_looks entry, e.g. {"SSJ": "SSJBroly"}
#     form_looks entries may set fur: 0xRRGGBB (red Super Saiyan 4 fur on arms and chest).
# Cast batch B4 (Boo saga, Cyborgs, Cel, Red Ribbon; characters/cast_b4.gd):
#   outfit "RRUniform":         Red Ribbon uniform: jacket = outfitRgb/tint, darker trousers, black belt + boots, red
#                               chest badge (NPCs only, not in ALL).
#   outfitParts badge / epaulettes / cape_collar: colour | false   chest badge disc, gold shoulder boards, a tall
#                               stand-up wizard collar behind the head (Babido). Bare torso: {top: "skin", sleeves: false}.
#   skinPattern: "spots" | "plates" | "majin"   on the bare skin: Cel spots, cyborg panel seams, Boo's soft glossy tone
#                               with a lighter belly; patternRgb = spot / seam colour.
#   faceRgb:  the front of the face in its own colour (Cel's white face).
#   mark: "majin" (+ majinMarkRgb)   the Majin "M" on the forehead (painted; B5's faceMarks/markRgb are separate).
#   wingRgb:  colour of the cell_wings gear.
#   New gear ids: cell_crest, cell_wings, cell_tail, cell_beak, m_belt, android_dome, rr_cap, gamma_helmet,
#                 gamma_helmet2, pui_helmet, dabura_horns, scarf_orange, scarf_red, eyepatch, gero_beard, hoops.
#   Look-only Cel stages in form_looks: CellImperfect, CellSemiPerfect, CellPerfect, CellSuperPerfect (gear tail/beak).
# Cast batch B6 (Namekians, demons, animals, creatures; characters/creature_bodies.gd, all look.costume ids):
#   namek_turban, pilaf_hat, ninja_hood, pig_head, cat_head, dog_head, monkey_head, big_mustache, plant_head, bat_wings,
#   demon_crest, oni_horns, prop_cane, prop_staff, prop_katana, prop_turtle_shell, suspenders; creature bodies
#   battle_walker / oracle_fish hide the humanoid and draw a mech / a fish in a bowl instead.
# Cast batch B5 (Earth humans; Parts.facial_hair + characters/face_gear.gd, called from Parts.dress):
#   hair adds "CenterPart", "Bob", "TwinTails", "Afro", "BigCurly", "Topknot", "SidePonytail", "ShoulderStraight", "Slick".
#   moustache: "thick" (B3's bar moustache) | "bushy" | "long" | "thin";  beard: "long" | "full" | "short" | "goatee";
#     facialHairRgb (default: the hair colour, so hairColor 5 gives white).
#   glasses: "round" | "sunglasses" | "square" (+ glassesRgb frame colour).
#   hat: "skullcap" | "pompom" | "beanie" | "bandana" | "headband" | "turban" | "ribbon" (+ hatRgb, hatRgb2 = ball/jewel).
#   thirdEye: true.   faceMarks: ["dots", "cheek_circles", "scar_cheek", "scar_eye"] (+ markRgb).
#   jewellery: ["champion_belt", "earrings", "bracelets", "necklace"] (+ jewelRgb, default gold).
#   neckwear: "scarf" | "fur_collar" (+ neckRgb).
# Cast fixes (2026-11-13; characters/skirt.gd, NPC-only outfits, not in ALL):
#   outfit "Dress":             a sleeveless knee-length dress (Bulna): outfitRgb = the dress, bare legs, outfitRgb2 =
#                               the shoes. outfitParts sleeves: true gives it sleeves (young Bulna).
#   outfit "LongDress":         a long side-slit dress over trousers (Chi-Mei): outfitRgb = the dress, outfitRgb2 = the
#                               sash; outfitParts pants = the trousers ("skin" = bare legs).
#   outfitParts skirt: colour | false   a skirt on any outfit (two halves worn on the thighs, so the hem follows the
#                               legs); skirtLen: metres below the hip joint (0.42 knee, 0.66 mid-shin, 0.84 ankle).
#   form_looks robeOff: true    the cape and look.costume pieces are hidden during that form (Orange Piccor).
# ------------------------------------------------------------------------------------------------
# What each outfit is made of (ported from web/src/character/cage_model.js outfitParts): colours for the
# body regions plus extra pieces (armour plate/pads, cape, collar, gloves). `tint` is the player's outfit colour.
# cloth: how loose the clothes are (Cloth: 0 skin-tight suit/armour .. 1 very baggy gi); boot_trim / laces: the boots'
# cuff trim line and wrap laces (defaults in BodyRegions.colours; laces the boot colour = plain boots).

const ALL := ["TurtleGi", "WeightedGi", "CraneGi", "SaiyanArmor", "EliteArmor", "SaiyanSuit", "FrostArmor",
	"PrideTrooper", "NamekRobe", "GiantsRobe", "AngelRobe", "CapsuleCorp", "MajinVest", "FriezaForce"]
## A region colour that shows the skin instead of cloth (BodyRegions.colours).
const SKIN := -1

static func parts(outfit: String, tint: int) -> Dictionary:
	match outfit:
		"FriezaForce":   # cast batch B3: Frieza Force battle armour (suit = tint, white plate, yellow-brown flaps)
			return {"top": tint, "pants": tint, "shoes": 0xf2f2f2, "wrist": tint, "armor": {"plate": 0xf4f2ea, "trim": 0xc8963a, "pads": false, "flaps": true, "belly": true}, "cloth": 0.0, "boot_trim": 0xc8963a, "laces": 0xf2f2f2}
		"FrostBody":   # cast batch B3: no clothes, the natural Frost Demon body (not offered to players)
			return {"top": SKIN, "pants": SKIN, "shoes": SKIN, "cloth": 0.0, "boot_trim": SKIN, "laces": SKIN}
		"RRUniform":   # cast batch B4: Red Ribbon uniform (jacket = tint, darker trousers, black belt and boots, badge; NPCs only)
			return {"top": tint, "pants": _shade(tint, 0.78), "shoes": 0x1a1a1e, "sash": 0x1a1a1e, "sleeves": true, "cloth": 0.4, "boot_trim": 0x1a1a1e, "laces": 0x1a1a1e, "badge": 0xc8202a}
		"SaiyanArmor", "EliteArmor":
			return {"top": 0x1c2a5c, "pants": 0x1c2a5c, "shoes": 0xf2f2f2, "sleeves": true, "armor": {"plate": 0xf4f2ea, "trim": 0xd8b04a if outfit == "EliteArmor" else tint, "pads": true}, "cloth": 0.0, "boot_trim": 0xd8b04a if outfit == "EliteArmor" else 0x1c2a5c, "laces": 0xf2f2f2}
		"FrostArmor":
			return {"top": 0x2a1c3c, "pants": 0x2a1c3c, "shoes": 0xe8e8e8, "sleeves": true, "armor": {"plate": 0xf0eef6, "trim": tint, "pads": true}, "cloth": 0.0, "boot_trim": 0x6a3a9a, "laces": 0xe8e8e8}
		"SaiyanSuit":
			return {"top": _shade(tint, 0.55), "pants": _shade(tint, 0.55), "shoes": 0xf2f2f2, "gloves": 0xf2f2f2, "sleeves": true, "cloth": 0.0, "boot_trim": _shade(tint, 0.55), "laces": 0xf2f2f2}
		"PrideTrooper":
			return {"top": 0xb8202a, "pants": 0x161616, "shoes": 0x161616, "gloves": 0x161616, "sash": 0x161616, "sleeves": true, "cloth": 0.15, "boot_trim": 0xb8202a, "laces": 0x161616}
		"NamekRobe":
			return {"top": tint, "pants": tint, "shoes": 0x6a3a22, "sash": 0x3a8acf, "cape": 0xf4f2ea, "wrist": 0x3a8acf, "cloth": 0.85, "boot_trim": 0xc89a5a}
		"GiantsRobe":
			return {"top": 0x3a2a4a, "pants": 0x3a2a4a, "shoes": 0x2a1a12, "cape": 0x8a1a2a, "sleeves": true, "cloth": 0.75, "boot_trim": 0x8a1a2a}
		"AngelRobe":
			return {"top": tint, "pants": tint, "shoes": 0x1a1a1a, "sash": 0x1a1a1a, "collar": 0xd8b04a, "sleeves": true, "cloth": 0.7, "boot_trim": 0xd8b04a}
		"CapsuleCorp":
			return {"top": tint, "pants": 0x2a3a5a, "shoes": 0x2a2a2a, "sleeves": true, "cloth": 0.35, "boot_trim": 0xf2f2f2, "laces": 0x2a2a2a}
		"MajinVest":
			return {"top": 0x241a2e, "pants": 0xf2f0ea, "shoes": 0x1a1a1a, "sash": 0x111111, "wrist": 0xd8b04a, "vest": true, "cloth": 0.9}
		"Dress":   # 2026-11-13: sleeveless knee-length dress, bare legs (NPC only)
			return {"top": tint, "pants": SKIN, "shoes": 0xc8323a, "skirt": tint, "skirtLen": 0.42, "vest": true, "cloth": 0.0, "boot_trim": 0x3a4a8a, "laces": 0xf2f2f2}
		"LongDress":   # 2026-11-13: long side-slit dress over trousers, sash at the waist (NPC only)
			return {"top": tint, "pants": _shade(tint, 0.6), "shoes": 0xc8323a, "sash": _shade(tint, 0.45), "skirt": tint, "skirtLen": 0.7, "vest": true, "cloth": 0.0, "boot_trim": 0xf2f2f2}
		"CraneGi":
			return {"top": tint, "pants": _shade(tint, 0.75), "shoes": 0x1a1a1a, "sash": 0x1a1a1a, "cloth": 0.9}
		"WeightedGi":
			return {"top": tint, "pants": tint, "shoes": 0x1d3a8a, "sash": 0x1d3a8a, "wrist": 0x1d3a8a, "undershirt": 0x1d3a8a, "cloth": 1.0}
		_:  # TurtleGi
			return {"top": tint, "pants": tint, "shoes": 0x1d3a8a, "sash": 0x1d3a8a, "wrist": 0x1d3a8a, "undershirt": 0x1d3a8a, "cloth": 1.0}

static func _shade(hex: int, k: float) -> int:
	var c := Color.hex((hex << 8) | 0xff) * k
	return (int(c.r8) << 16) | (int(c.g8) << 8) | int(c.b8)

## Accent parts that look.outfitRgb2 recolours.
const ACCENT := ["sash", "wrist", "undershirt"]
## Outfits whose accent colour (outfitRgb2) is the shoes instead (they have no sash/wristbands).
const ACCENT_SHOES := ["Dress"]

## The outfit parts for a look: its palette tint or own colours (look.outfitRgb / outfitRgb2 / outfitParts, see the top).
static func for_look(look: Dictionary, palette_tint: int) -> Dictionary:
	var main := rgb(look.get("outfitRgb"))
	var p := parts(str(look.get("outfit", "TurtleGi")), main if main >= 0 else palette_tint)
	var accent := rgb(look.get("outfitRgb2"))
	if accent >= 0:
		for k: String in ACCENT:
			if p.has(k): p[k] = accent
		if str(look.get("outfit", "")) in ACCENT_SHOES: p.shoes = accent
		if p.has("armor"): p.armor.trim = accent
	var over: Variant = look.get("outfitParts")
	if over is Dictionary:
		for k: String in over:
			var v: Variant = over[k]
			match k:
				"plate", "trim":
					if rgb(v) < 0: continue
					if not p.has("armor"): p.armor = {"plate": rgb(v), "trim": rgb(v), "pads": false}
					p.armor[k] = rgb(v)
				"pads", "flaps", "belly":
					if p.has("armor"): p.armor[k] = v is bool and v
				"sleeves", "vest":
					p[k] = v is bool and v
				"cloth":
					if v is int or v is float: p[k] = clampf(float(v), 0.0, 1.0)
				"skirtLen":
					if v is int or v is float: p[k] = clampf(float(v), 0.15, 0.9)
				_:
					if v is bool and not v: p.erase(k)
					elif v is String and v == "skin": p[k] = SKIN
					elif rgb(v) >= 0: p[k] = rgb(v)
	return p

## A colour field as 0xRRGGBB: an int/float or a "#rrggbb" / "0xrrggbb" string; -1 when unset or invalid.
static func rgb(v: Variant) -> int:
	if v is int or v is float:
		return clampi(int(v), 0, 0xffffff) if float(v) >= 0.0 else -1
	if v is String:
		var t := (v as String).strip_edges().trim_prefix("#").trim_prefix("0x")
		if t.length() == 6 and t.is_valid_hex_number():
			return t.hex_to_int()
	return -1
