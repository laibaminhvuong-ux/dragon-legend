extends Node3D
# The story drawn in the world (port of web/src/world/story_view.js): NPCs (Fighters or wish dragons) with name
# tags and quest markers, dragon orbs and supply crates, travel pads, and a beam of light over the objective.
# Reads RuleStory only.

const ORB := preload("res://fx/shaders/orb.gdshader")
const GLOW := preload("res://fx/shaders/glow_point.gdshader")
const ENERGY := preload("res://fx/shaders/energy.gdshader")
const MARKERS := {"!": ["!", "#ffd23a"], "side": ["!", "#f2f2f2"], "?": ["?", "#ffd23a"], "⚔": ["⚔", "#ff5a4a"], "✈": ["✈", "#7fd3ff"]}

var story: RuleStory
var combat: RuleCombat
var npcs: Dictionary = {}       # id -> {model, tag, marker, marker_key, data, yaw}
var pickups: Dictionary = {}    # "quest:index" -> Node3D
var pads := Node3D.new()
var _pad_key := ""
var beacon := Node3D.new()
var _beam: MeshInstance3D
var _beacon_label: Label3D
var _t := 0.0
var _since := 1.0
var _orb_mat: ShaderMaterial
var _ball: SphereMesh
var _energy: ShaderMaterial

func _init(s: RuleStory, c: RuleCombat) -> void:
	name = "Story"
	story = s
	combat = c
	add_child(pads)
	add_child(beacon)
	_orb_mat = ShaderMaterial.new(); _orb_mat.shader = ORB
	_energy = ShaderMaterial.new(); _energy.shader = ENERGY
	_ball = SphereMesh.new(); _ball.radius = 0.32; _ball.height = 0.64; _ball.radial_segments = 32; _ball.rings = 16
	var cyl := CylinderMesh.new(); cyl.top_radius = 0.35; cyl.bottom_radius = 0.35; cyl.height = 120.0; cyl.radial_segments = 24; cyl.cap_top = false; cyl.cap_bottom = false
	_beam = MeshInstance3D.new(); _beam.mesh = cyl; _beam.material_override = _energy; _beam.position.y = 63.2
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.set_instance_shader_parameter("energy_color", Color("#ffc83a"))
	beacon.add_child(_beam)
	_beacon_label = _label("", Color("#ffe08a"), 30)
	_beacon_label.position.y = 4.2
	beacon.add_child(_beacon_label)
	refresh()

static func _label(text: String, color: Color, size := 34, outline := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.font_size = size
	l.pixel_size = 0.0062
	l.outline_size = 10 if outline else 0
	l.outline_modulate = Color(0, 0, 0, 0.55)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l

func refresh() -> void:
	_sync_npcs()
	_sync_pickups()
	_sync_pads()

func _sync_npcs() -> void:
	var seen := {}
	var enemy_keys := {}
	if combat != null:
		for e: Dictionary in combat.enemies:
			enemy_keys[str(e.get("key", ""))] = true
	for n: Dictionary in story.npcs():
		var id := str(n.id)
		if enemy_keys.has(id):
			continue
		seen[id] = true
		var e: Dictionary = npcs.get(id, {})
		var sc := float(n.get("scale", 1.0))
		if e.is_empty():
			var model: Node3D
			if n.get("dragon") != null:
				model = WishDragon.create(str(n.dragon))
			else:
				model = Fighter.create(n.look if n.get("look") is Dictionary else {"race": "Human"})
			model.scale = Vector3.ONE * sc
			model.position = Vector3(float(n.x), float(n.y), float(n.z))
			model.rotation.y = float(n.get("rot", 0.0))
			add_child(model)
			if n.get("boss", false) and model is Fighter:
				var aura := Aura.create({"color": 0xff3a3a, "core": 0xffb0a0, "size": 1.0, "flicker": 0.9, "sparks": 0})
				model.body.add_child(aura)
				model.set_meta("boss_aura", aura)
			var tag := _label(str(n.name), Color("#ffb0a8") if n.get("boss", false) else Color.WHITE)
			tag.position = model.position + Vector3(0, 2.15 * sc + 0.25, 0)
			add_child(tag)
			e = {"model": model, "tag": tag, "marker": null, "marker_key": "", "data": n, "yaw": float(n.get("rot", 0.0))}
			npcs[id] = e
		e.data = n
		var key := ""
		if n.get("marker") != null and str(n.marker) != "":
			key = "side" if (str(n.marker) == "!" and not n.get("main", false)) else str(n.marker)
		if key != e.marker_key:
			if e.marker != null:
				(e.marker as Node).queue_free()
				e.marker = null
			if key != "":
				var m: Array = MARKERS.get(key, [key, "#ffd23a"])
				var mk := _label(m[0], Color(m[1]), 96, true)
				mk.position = Vector3(float(n.x), float(n.y) + 2.15 * sc + 1.0, float(n.z))
				add_child(mk)
				e.marker = mk
			e.marker_key = key
	for id: String in npcs.keys():
		if not seen.has(id):
			var e: Dictionary = npcs[id]
			e.model.dispose()
			(e.tag as Node).queue_free()
			if e.marker != null: (e.marker as Node).queue_free()
			npcs.erase(id)

func _sync_pickups() -> void:
	var seen := {}
	var looks: Dictionary = RuleTables.table("orb_looks") if RuleTables.table("orb_looks") is Dictionary else {}
	for p: Dictionary in story.pickups():
		var key := "%s:%s" % [p.questId, p.index]
		seen[key] = true
		if pickups.has(key):
			continue
		var g := Node3D.new()
		g.position = Vector3(float(p.x), float(p.y), float(p.z))
		if str(p.item) == "supplies":
			var crate := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.9, 0.7, 0.9)
			crate.mesh = bm; crate.material_override = Parts.material(Color.hex(0x8a6a3aff), 0.8); crate.position.y = -0.25
			g.add_child(crate)
		else:
			var orb: Dictionary = looks.get(str(p.item), looks.get("dragon_ball", {"scale": 1.0, "color": 0xff8a20}))
			var ball := MeshInstance3D.new(); ball.mesh = _ball; ball.material_override = _orb_mat
			ball.scale = Vector3.ONE * float(orb.get("scale", 1.0))
			ball.set_instance_shader_parameter("stars", int(p.index) % 7 + 1)
			ball.set_instance_shader_parameter("glow", Color.hex((int(orb.get("color", 0xff8a20)) << 8) | 0xff))
			ball.set_instance_shader_parameter("ghost", 1.0 if orb.get("projection", false) else 0.0)
			g.add_child(ball)
			if orb.get("projection", false):
				var tag := _label("Cosmic retrieval beacon", Color("#ffe39a"))
				tag.position.y = 1.7
				g.add_child(tag)
		var glow := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(2.4, 2.4)
		var gm := ShaderMaterial.new(); gm.shader = GLOW; gm.set_shader_parameter("tint", Color(1.0, 0.63, 0.25))
		q.material = gm; glow.mesh = q; glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(glow)
		var light := OmniLight3D.new(); light.light_color = Color(1.0, 0.7, 0.35); light.light_energy = 1.2; light.omni_range = 4.0
		g.add_child(light)
		add_child(g)
		pickups[key] = g
	for k: String in pickups.keys():
		if not seen.has(k):
			(pickups[k] as Node).queue_free()
			pickups.erase(k)

func _sync_pads() -> void:
	var list: Array = story.pads()
	var key := ",".join(list.map(func(p: Dictionary) -> String: return str(p.zone)))
	if key == _pad_key:
		return
	_pad_key = key
	for c in pads.get_children():
		c.queue_free()
	for p: Dictionary in list:
		var g := Node3D.new()
		g.position = Vector3(float(p.x), float(p.y) + 0.05, float(p.z))
		var ring := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = 1.03; t.outer_radius = 1.17
		ring.mesh = t; ring.material_override = _energy; ring.set_instance_shader_parameter("energy_color", Color("#3aa0ff"))
		g.add_child(ring)
		var col := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = 1.0; c.bottom_radius = 1.0; c.height = 6.0; c.cap_top = false; c.cap_bottom = false
		col.mesh = c; col.position.y = 3.0; col.material_override = _energy
		col.set_instance_shader_parameter("energy_color", Color("#3aa0ff")); col.set_instance_shader_parameter("strength", 0.35)
		col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(col)
		var tag := _label(str(p.name), Color("#bfe6ff"), 30); tag.position.y = 2.4
		g.add_child(tag)
		pads.add_child(g)

func update_view(dt: float, player_pos: Vector3) -> void:
	_t += dt
	_since += dt
	if _since > 0.3:
		_since = 0.0
		refresh()
	for e: Dictionary in npcs.values():
		var n: Dictionary = e.data
		var d := Vector2(player_pos.x - float(n.x), player_pos.z - float(n.z)).length()
		var want := atan2(player_pos.x - float(n.x), player_pos.z - float(n.z)) if d < 7.0 else float(n.get("rot", 0.0))
		var diff := fposmod(want - float(e.yaw) + PI, TAU) - PI
		e.yaw = float(e.yaw) + diff * minf(1.0, dt * 4.0)
		var model: Node3D = e.model
		model.rotation.y = e.yaw
		model.call("update", dt, {"talking": d < 4.0})
		if model.has_meta("boss_aura"):
			(model.get_meta("boss_aura") as Aura).update(dt)
		if e.marker != null:
			(e.marker as Node3D).position.y = float(n.y) + 2.15 * float(n.get("scale", 1.0)) + 1.0 + sin(_t * 3.0) * 0.08
	for g: Node3D in pickups.values():
		g.get_child(0).rotation.y += dt * 1.5
	var w: Variant = story.waypoint()
	beacon.visible = w is Dictionary and Vector2(float(w.x) - player_pos.x, float(w.z) - player_pos.z).length() > 5.0
	if w is Dictionary:
		beacon.position = Vector3(float(w.x), float(w.y), float(w.z))
		_beacon_label.text = str(w.get("text", ""))
		var dist := Vector2(float(w.x) - player_pos.x, float(w.z) - player_pos.z).length()
		var k := maxf(1.0, dist / 18.0)
		_beacon_label.pixel_size = 0.0062 * k * 1.2
		_beacon_label.position.y = 4.2 + k * 1.2
	_beam.set_instance_shader_parameter("strength", 0.13 + sin(_t * 2.0) * 0.04)
