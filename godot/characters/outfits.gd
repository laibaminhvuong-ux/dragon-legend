class_name Outfits
extends RefCounted
# What each outfit is made of (ported from web/src/character/cage_model.js outfitParts): colours for the
# body regions plus extra pieces (armour plate/pads, cape, collar, gloves). `tint` is the player's outfit colour.
# cloth: how loose the clothes are (Cloth: 0 skin-tight suit/armour .. 1 very baggy gi); boot_trim / laces: the boots'
# cuff trim line and wrap laces (defaults in BodyRegions.colours; laces the boot colour = plain boots).

const ALL := ["TurtleGi", "WeightedGi", "CraneGi", "SaiyanArmor", "EliteArmor", "SaiyanSuit", "FrostArmor",
	"PrideTrooper", "NamekRobe", "GiantsRobe", "AngelRobe", "CapsuleCorp", "MajinVest"]

static func parts(outfit: String, tint: int) -> Dictionary:
	match outfit:
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
