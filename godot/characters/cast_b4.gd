class_name CastB4
extends RefCounted
# Cast batch B4 (Buu saga, Cyborgs, Cel, Red Ribbon; 2026-11-10): skin patterns, face colour, Majin forehead mark,
# Cel wings / crest / stinger tail, Red Ribbon badge and epaulettes, wizard cape collar, and the B4 gear ids.
# Look fields (documented at the top of outfits.gd):
#   skinPattern: "spots" | "plates" | "majin"   painted on the bare skin (outfit_body.gdshaderinc skin_pattern)
#   patternRgb:  colour of the spots / plate seams (default dark green spots, grey seams)
#   faceRgb:     the front of the face in its own colour (Cel's white face)
#   mark: "majin"  the Majin "M" on the forehead; majinMarkRgb its colour
#   wingRgb:     colour of the cell_wings gear (default dark purple)
# outfitParts extras (Outfits.for_look passes unknown colour keys through): badge (Red Ribbon badge on the left chest),
# epaulettes (gold shoulder boards), cape_collar (a tall stand-up collar behind the head: wizard cape).

const PATTERNS := {"spots": 1, "plates": 2, "majin": 3}

## Shader uniforms for the look's skin pattern, face colour and forehead mark (Fighter._build).
static func apply(f: Fighter) -> void:
	var l := f.look
	var pat := int(PATTERNS.get(str(l.get("skinPattern", "")), 0))
	f.material.set_shader_parameter("skin_pattern", pat)
	var pc := Outfits.rgb(l.get("patternRgb"))
	if pc < 0:
		pc = 0x1e3a12 if pat == 1 else 0x8a8a96
	f.material.set_shader_parameter("pattern_color", Parts.hx(pc))
	var fc := Outfits.rgb(l.get("faceRgb"))
	f.material.set_shader_parameter("face_tint", Color(Parts.hx(fc), 1.0) if fc >= 0 else Color(1, 1, 1, 0))
	f.material.set_shader_parameter("forehead_mark", 1.0 if str(l.get("mark", "")) == "majin" else 0.0)
	var mc := Outfits.rgb(l.get("majinMarkRgb"))
	f.material.set_shader_parameter("mark_color", Parts.hx(mc if mc >= 0 else 0x1a0e0e))

## Outfit extras after Parts.dress: Red Ribbon badge, epaulettes, wizard cape collar.
static func dress(f: Fighter, parts: Dictionary) -> void:
	var chest := Parts._fit(f, Vector3(0, 1.3, 0.0), Parts._sc(f, "shoulders"), Parts._sc(f, "chest"))
	if Outfits.rgb(parts.get("badge")) >= 0:   # a red disc with a white rim, high on the left chest
		f.add_piece("DEF-spine.003", chest, Parts._mesh("rr_badge", func(g: Geo) -> void:
			g.cylinder(Transform3D(Basis.from_euler(Vector3(PI / 2 - 0.25, 0, 0)), Vector3(0.075, 1.33, 0.118)), 0.026, 0.026, 0.008, 18)), Parts.material(Parts.hx(Outfits.rgb(parts.badge)), 0.5))
		f.add_piece("DEF-spine.003", chest, Parts._mesh("rr_badge_rim", func(g: Geo) -> void:
			g.torus(Transform3D(Basis.from_euler(Vector3(PI / 2 - 0.25, 0, 0)), Vector3(0.075, 1.33, 0.12)), 0.026, 0.004, 18, 6)), Parts.material(Color.hex(0xf2f2f2ff), 0.5))
	if Outfits.rgb(parts.get("epaulettes")) >= 0:   # flat gold shoulder boards with a fringe
		var pad := sqrt(Parts._sc(f, "upper_arm") * Parts._sc(f, "shoulders"))
		for s in [1, -1]:
			var pc := Vector3(s * 0.2, 1.485, -0.06)
			var moved := Vector3(pc.x * Parts._sc(f, "shoulders"), pc.y, pc.z)
			f.add_piece("DEF-upper_arm." + ("L" if s > 0 else "R"), Transform3D(Basis.from_scale(Vector3.ONE * pad), moved - Basis.from_scale(Vector3.ONE * pad) * pc), Parts._mesh("epaulette%d" % s, func(g: Geo) -> void:
				g.box(Transform3D(Basis.from_euler(Vector3(0, 0, -s * 0.25)), pc), Vector3(0.13, 0.016, 0.085))
				for k in 5:
					g.cylinder(Transform3D(Basis.IDENTITY, pc + Vector3(s * 0.06, -0.022, -0.034 + k * 0.017)), 0.005, 0.005, 0.035, 6)), Parts.material(Parts.hx(Outfits.rgb(parts.epaulettes)), 0.35, 0.6))
	if Outfits.rgb(parts.get("cape_collar")) >= 0:   # Babido: a tall flared collar standing up behind the head
		f.add_piece("DEF-spine.003", Transform3D.IDENTITY, Parts._mesh("cape_collar", func(g: Geo) -> void:
			g.sheet(Transform3D(Basis.from_euler(Vector3(PI - 0.45, 0, 0)), Vector3(0, 1.45, -0.07)), 0.34, 0.3, 8, 4)), Parts.material(Parts.hx(Outfits.rgb(parts.cape_collar)), 0.8, 0.0, true))

## B4 gear ids (Parts.gear passes every id on here). Head pieces are in Hair.HEAD_SPACE (head centre about (0, 0.06, 0),
## radius about 0.105, +Z is the face).
static func gear(f: Fighter, id: String) -> void:
	match id:
		"cell_crest":   # Cel: two tall skin-coloured crest horns from the sides of the head, a dark cap between them
			f.add_skin_piece(f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("cell_crest", func(g: Geo) -> void:
				for s in [1, -1]:
					g.spike(Vector3(s * 0.062, 0.1, -0.03), 0.24, 0.05, Vector3(s * 0.22, 1.0, -0.2))), Parts.material(f.skin, 0.5)), 1.0)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("cell_cap", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(0.7, 1.0, 1.05)), Vector3(0, 0.07, -0.01)), 0.1, PI * 0.3, PI * 0.5)), Parts.material(Color.hex(0x2a2440ff), 0.4, 0.0, true))
		"cell_wings":   # Cel: two long pointed wing panels folded down the back (look.wingRgb)
			var wc := Outfits.rgb(f.look.get("wingRgb"))
			var mat := Parts.material(Parts.hx(wc if wc >= 0 else 0x3a2e6a), 0.4, 0.05)
			for s in [1, -1]:
				f.add_piece("DEF-spine.003", Transform3D.IDENTITY, Parts._mesh("cell_wing%d" % s, func(g: Geo) -> void:
					var b := Basis.from_euler(Vector3(-0.12, s * 0.3, s * 0.16)) * Basis.from_scale(Vector3(0.17, 0.66, 0.022))
					g.sphere(Transform3D(b, Vector3(s * 0.17, 0.92, -0.2)), 1.0, 10, 16)), mat)
		"cell_tail":   # Imperfect Cel: a long stinger tail down to the ground with a dark barb
			f.add_skin_piece(f.add_piece("DEF-hips", Transform3D.IDENTITY, Parts._mesh("cell_tail", func(g: Geo) -> void:
				g.tube(Parts._offset([Vector3(0, 0, 0), Vector3(0, -0.25, -0.22), Vector3(0.03, -0.62, -0.32), Vector3(0.12, -0.84, -0.18), Vector3(0.16, -0.86, 0.05)], Vector3(0, 0.9, -0.13)), 0.05, 0.03, 28)), Parts.material(f.skin, 0.5)), 1.0)
			f.add_piece("DEF-hips", Transform3D.IDENTITY, Parts._mesh("cell_stinger", func(g: Geo) -> void:
				g.spike(Vector3(0.16, 0.04, -0.08), 0.12, 0.032, Vector3(0.1, 0.0, 1.0))), Parts.material(Color.hex(0x2a2a1aff), 0.4))
		"cell_beak":   # Imperfect Cel: a hard pointed beak-like mouth
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("cell_beak", func(g: Geo) -> void:
				g.spike(Vector3(0, -0.035, 0.09), 0.06, 0.03, Vector3(0, -0.35, 1.0))), Parts.material(Color.hex(0xd8a040ff), 0.45))
		"m_belt":   # Boo: a gold "M" buckle on the front of the belt
			f.add_piece("DEF-hips", Transform3D.IDENTITY, Parts._mesh("m_belt", func(g: Geo) -> void:
				g.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.965, 0.128)), Vector3(0.075, 0.06, 0.01))), Parts.material(Color.hex(0x1a1a1aff), 0.5))
			f.add_piece("DEF-hips", Transform3D.IDENTITY, Parts._mesh("m_belt_m", func(g: Geo) -> void:
				for k: Array in [[-0.022, 0.0], [0.022, 0.0], [-0.009, 0.45], [0.009, -0.45]]:
					g.box(Transform3D(Basis.from_euler(Vector3(0, 0, k[1])), Vector3(k[0], 0.965, 0.135)), Vector3(0.008, 0.04, 0.006))), Parts.material(Color.hex(0xe0b040ff), 0.3, 0.7))
		"android_dome":   # Cyborg 19/20: a pale dome cap over the top of the head with a short spike
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("android_dome", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.04, 1.0, 1.06)), Vector3(0, 0.07, -0.005)), 0.112, PI * 0.28, PI * 0.42)
				g.spike(Vector3(0, 0.18, -0.02), 0.06, 0.012, Vector3(0, 1, -0.2))), Parts.material(Color.hex(0xc8c8d0ff), 0.3, 0.4, true))
		"rr_cap":   # Red Ribbon officer's cap: black crown, short visor, red badge
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("rr_cap", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.08, 0.82, 1.1)), Vector3(0, 0.075, -0.005)), 0.118, PI * 0.36, PI * 0.5)
				g.box(Transform3D(Basis.from_euler(Vector3(-0.2, 0, 0)), Vector3(0, 0.1, 0.122)), Vector3(0.15, 0.008, 0.055))), Parts.material(Color.hex(0x1a1a1eff), 0.6, 0.0, true))
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("rr_cap_badge", func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.from_euler(Vector3(PI / 2 - 0.5, 0, 0)), Vector3(0, 0.145, 0.098)), 0.018, 0.018, 0.006, 14)), Parts.material(Color.hex(0xc8202aff), 0.5))
		"gamma_helmet", "gamma_helmet2":   # Gama 1/2: dark helmet with a tall black crest fin (Gama 2: two swept side fins)
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("gamma_helmet", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.1, 1.06, 1.12)), Vector3(0, 0.055, -0.008)), 0.124, PI * 0.32, PI * 0.64)), Parts.material(Color.hex(0x50505eff), 0.35, 0.3, true))
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh(id + "_fin", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_euler(Vector3(-0.35, 0, 0)) * Basis.from_scale(Vector3(0.14, 0.75, 1.2)), Vector3(0, 0.15, -0.03)), 0.1, 10, 16)
				if id == "gamma_helmet2":
					for s in [1, -1]:
						g.sphere(Transform3D(Basis.from_euler(Vector3(-0.5, s * 0.3, s * -0.6)) * Basis.from_scale(Vector3(0.12, 0.5, 0.9)), Vector3(s * 0.09, 0.1, -0.04)), 0.09, 8, 14)), Parts.material(Color.hex(0x18181cff), 0.3, 0.2))
		"pui_helmet":   # Poi Poi: a white helmet with two short horns out to the sides
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("pui_helmet", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.1, 1.06, 1.12)), Vector3(0, 0.055, -0.008)), 0.126, PI * 0.32, PI * 0.64)
				for s in [1, -1]:
					g.spike(Vector3(s * 0.125, 0.08, -0.01), 0.09, 0.025, Vector3(s, 0.35, 0))), Parts.material(Color.hex(0xf0f0f2ff), 0.35, 0.1, true))
		"dabura_horns":   # Dabora: two short horns from the forehead and a white hair tuft at the back
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("dabura_horns", func(g: Geo) -> void:
				for s in [1, -1]:
					g.tube(Parts._offset([Vector3(0, 0, 0), Vector3(s * 0.02, 0.04, -0.01), Vector3(s * 0.035, 0.085, -0.04)], Vector3(s * 0.04, 0.13, 0.05)), 0.016, 0.002, 12, 8)
				g.spike(Vector3(0, 0.15, 0.04), 0.035, 0.01, Vector3(0, 1, 0.3))), Parts.material(Color.hex(0x2a2226ff), 0.4, 0.1))
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("dabura_tuft", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.1, 0.8, 0.9)), Vector3(0, 0.07, -0.1)), 0.045, 8, 12)), Parts.material(Color.hex(0xf0f0f0ff), 0.85))
		"scarf_orange", "scarf_red":   # a neck scarf with one short end hanging at the front
			var col := 0xe8782a if id == "scarf_orange" else 0xc8202a
			f.add_piece("DEF-spine.003", Parts._fit(f, Vector3(0, 1.47, -0.012), Parts._sc(f, "neck"), Parts._sc(f, "neck")), Parts._mesh("scarf", func(g: Geo) -> void:
				g.torus(Transform3D(Basis.IDENTITY, Vector3(0, 1.475, -0.012)), 0.085, 0.026, 24, 8)
				g.tube(PackedVector3Array([Vector3(0.04, 1.47, 0.09), Vector3(0.055, 1.4, 0.115), Vector3(0.06, 1.32, 0.12)]), 0.024, 0.02, 8, 8)), Parts.material(Color.hex((col << 8) | 0xff), 0.8))
		"eyepatch":   # Commander Rudd: a black patch over the right eye and its strap
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("eyepatch", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.85, 0.35)), Vector3(-0.038, 0.04, 0.104)), 0.024, 8, 12)
				g.torus(Transform3D(Basis.from_euler(Vector3(0.2, 0, 0.25)), Vector3(0, 0.05, 0.0)), 0.108, 0.003, 32, 4)), Parts.material(Color.hex(0x121214ff), 0.6))
		"gero_beard":   # Dr. Gerro: a white beard and moustache
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("gero_beard", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.15, 0.7)), Vector3(0, -0.06, 0.07)), 0.06, 10, 14)
				for s in [1, -1]:
					g.tube(Parts._offset([Vector3(0, 0, 0), Vector3(s * 0.018, -0.004, -0.002), Vector3(s * 0.034, -0.02, -0.012)], Vector3(s * 0.004, -0.016, 0.112)), 0.009, 0.005, 10, 8)), Parts.material(Color.hex(0xf0f0eeff), 0.9))
		"hoops":   # Cyborg 18: gold hoop earrings
			f.add_piece("DEF-head", Hair.HEAD_SPACE, Parts._mesh("hoops", func(g: Geo) -> void:
				for s in [1, -1]:
					g.torus(Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(s * 0.098, -0.03, 0.0)), 0.018, 0.0028, 18, 6)), Parts.material(Color.hex(0xe0b040ff), 0.3, 0.7))
