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

## The outfit parts for a look: its palette tint or own colours (look.outfitRgb / outfitRgb2 / outfitParts, see the top).
static func for_look(look: Dictionary, palette_tint: int) -> Dictionary:
	var main := rgb(look.get("outfitRgb"))
	var p := parts(str(look.get("outfit", "TurtleGi")), main if main >= 0 else palette_tint)
	var accent := rgb(look.get("outfitRgb2"))
	if accent >= 0:
		for k: String in ACCENT:
			if p.has(k): p[k] = accent
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
