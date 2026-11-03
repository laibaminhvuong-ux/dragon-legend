extends Node3D
# Combat presentation (port of web/src/combat/view.js, with better effects). Reads RuleCombat's entities and
# events only; it never awards damage or rewards. Enemies are Fighters with name tags and health bars; ki blasts
# glow and trail sparks; beams have a hot core and an impact burst; hits spark and float damage numbers.

const ENERGY := preload("res://fx/shaders/energy.gdshader")
const GLOW := preload("res://fx/shaders/glow_point.gdshader")
const BAR := preload("res://fx/shaders/bar.gdshader")

var combat: RuleCombat
var camera: Camera3D
var views: Dictionary = {}      # enemy id -> {fighter, tag, bar}
var balls: Dictionary = {}      # projectile id -> Node3D
var effects: Array = []         # {node, life, kind}
var avatar: Node3D
var _energy_mat: ShaderMaterial
var _bar_mat: ShaderMaterial
var _ball_mesh: SphereMesh
var flourish_root: Node3D
var audio: CombatAudio
var _attack_poses: Dictionary = {}
var _reactions: Dictionary = {}
var _charge_age := 0.0
var _last_form := ""
var _last_dash := false
var _reaction_serial := 0
var _bar_mesh: QuadMesh

func _init(c: RuleCombat, cam: Camera3D) -> void:
	name = "Combat"
	combat = c
	camera = cam
	_energy_mat = ShaderMaterial.new(); _energy_mat.shader = ENERGY
	_bar_mat = ShaderMaterial.new(); _bar_mat.shader = BAR
	_ball_mesh = SphereMesh.new(); _ball_mesh.radius = 0.17; _ball_mesh.height = 0.34; _ball_mesh.radial_segments = 16; _ball_mesh.rings = 8
	_bar_mesh = QuadMesh.new(); _bar_mesh.size = Vector2(1.35, 0.12)
	flourish_root = Node3D.new(); flourish_root.name = "Flourishes"; add_child(flourish_root)
	audio = CombatAudio.new(); audio.name = "CombatAudio"; add_child(audio)
	Events.attack.connect(_on_attack)
	Events.damage.connect(_on_damage)
	Events.beam.connect(_on_beam)
	Events.avatar_strike.connect(_on_avatar_strike)

func _exit_tree() -> void:
	for sig: Signal in [Events.attack, Events.damage, Events.beam, Events.avatar_strike]:
		for c in sig.get_connections():
			if c.callable.get_object() == self:
				sig.disconnect(c.callable)

static func _label(text: String, color: Color, size := 34) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(0.06, 0.08, 0.15)
	l.outline_size = 10
	l.font_size = size
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.fixed_size = false
	return l

static func _hex(v: Variant, fallback := 0x63cfff) -> Color:
	return Color.hex(((int(v) if v != null else fallback) << 8) | 0xff)

func _on_damage(d: Dictionary) -> void:
	var pos: Vector3 = RuleRuntime.vector(d.get("pos", Vector3.ZERO))
	var player_hit := str(d.get("id", "")) == "player"
	var entity := _entity(str(d.get("id","")))
	var weight := clampf(float(d.get("amount",0))/maxf(1,float(entity.get("maxHealth",100)))*5,0.2,1.0)
	var incoming: Vector3 = pos-combat.p.pos if not player_hit else combat.p.pos-_nearest_enemy_position()
	var yaw := float(entity.get("yaw",0))
	_reaction_serial += 1
	_reactions[str(d.get("id",""))] = {"serial":_reaction_serial,"left":0.35,"hitWeight":weight,"hitSide":clampf(incoming.x*cos(yaw)-incoming.z*sin(yaw),-1,1)}
	_push_player_presentation()
	_flourish("impact",pos,Color("9cdcff") if d.get("blocked",false) else Color("ffbc62"),incoming)
	audio.play_cue("guard" if d.get("blocked",false) else "hit",pos,weight)
	var l := _label(("GUARD " if d.get("blocked", false) else "") + str(d.get("amount", "")), Color("#ff8279") if player_hit else Color("#ffe294"), 42)
	l.position = pos + Vector3(randf_range(-0.3, 0.3), 0.2, 0)
	add_child(l)
	effects.append({"node": l, "life": 1.0, "kind": "text"})
	Burst.spawn(self, pos, Color(1.0, 0.75, 0.4) if not d.get("blocked", false) else Color(0.6, 0.85, 1.0), 0.7)
	while effects.size() > 32:
		_remove(effects.pop_front())

func _on_beam(b: Dictionary) -> void:
	var from: Vector3 = RuleRuntime.vector(b.from)
	var to: Vector3 = RuleRuntime.vector(b.to)
	var color := _hex(b.get("color"))
	audio.play_cue("beam",from,1.4)
	_flourish("surge",from,color)
	var dir := to - from
	var length := dir.length()
	if length < 0.01:
		return
	var holder := Node3D.new()
	add_child(holder)
	holder.position = from.lerp(to, 0.5)
	holder.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
	for layer: Array in [[0.16, 0.2, 1.6], [0.42, 0.55, 0.8]]:   # hot core, coloured sheath
		var c := CylinderMesh.new(); c.top_radius = layer[0]; c.bottom_radius = layer[1]; c.height = length; c.radial_segments = 16; c.rings = 1
		var mi := MeshInstance3D.new(); mi.mesh = c; mi.material_override = _energy_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("energy_color", color)
		mi.set_instance_shader_parameter("strength", layer[2])
		holder.add_child(mi)
	effects.append({"node": holder, "life": 0.45, "kind": "beam"})
	Burst.spawn(self, from, color, 0.8)
	Burst.spawn(self, to, color, 2.2)

func _on_avatar_strike(d: Dictionary) -> void:
	var pos: Vector3 = RuleRuntime.vector(d.get("pos", Vector3.ZERO))
	Burst.spawn(self, pos + Vector3.UP, Color(0.75, 0.85, 1.0), 2.5)

func _remove(e: Dictionary) -> void:
	var n: Node = e.node
	if is_instance_valid(n):
		n.queue_free()

func update_view(dt: float) -> void:
	audio.set_paused(dt<=0)
	_update_avatar(dt)
	_update_player_presentation(dt)
	for id: String in _reactions.keys():
		_reactions[id].left -= dt
		if _reactions[id].left<=0: _reactions.erase(id)
	var seen := {}
	for e: Dictionary in combat.enemies:
		var id := str(e.id)
		seen[id] = true
		var v: Dictionary = views.get(id, {})
		if v.is_empty():
			var f := Fighter.create(e.look if e.get("look") is Dictionary else {"race": "Human"})
			f.scale = Vector3.ONE * float(e.get("scale", 1.0))
			add_child(f)
			var tag := _label("%s · Lv. %d" % [e.name, int(e.level)], Color("#ffd17c") if e.get("boss", false) else Color("#f3d9d9"))
			add_child(tag)
			var bar := MeshInstance3D.new(); bar.mesh = _bar_mesh; bar.material_override = _bar_mat
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bar)
			v = {"fighter": f, "tag": tag, "bar": bar}
			views[id] = v
		var alive := float(e.health) > 0.0
		var f: Fighter = v.fighter
		f.visible = alive; v.tag.visible = alive; v.bar.visible = alive
		if not alive:
			continue
		var pos: Vector3 = e.pos
		var vel: Vector3 = e.vel
		f.position = pos
		f.rotation.y = float(e.yaw)
		f.set_terrain(combat.zone)
		f.presentation = _presentation(e)
		f.update(dt, {"yaw":e.yaw,"speed": Vector2(vel.x, vel.z).length(), "onGround": e.get("onGround", true), "attackSerial": e.attackSerial,
			"attackKind": e.attackKind, "hurt": float(e.get("hurtUntil", 0.0)) > combat.clock})
		var height := 2.2 * float(e.get("scale", 1.0))
		(v.tag as Label3D).position = pos + Vector3(0, height + 0.3, 0)
		(v.tag as Label3D).modulate = Color("#ff6655") if float(e.get("windup", 0.0)) > 0.0 else (Color("#ffd17c") if e.get("boss", false) else Color("#f3d9d9"))
		var bar: MeshInstance3D = v.bar
		bar.position = pos + Vector3(0, height, 0)
		bar.set_instance_shader_parameter("fill", clampf(float(e.health) / maxf(1.0, float(e.maxHealth)), 0.0, 1.0))
		bar.set_instance_shader_parameter("flash", 1.0 if float(e.get("windup", 0.0)) > 0.0 else 0.0)
	for id: String in views.keys():
		if not seen.has(id):
			var v: Dictionary = views[id]
			(v.fighter as Fighter).dispose(); (v.tag as Node).queue_free(); (v.bar as Node).queue_free()
			views.erase(id)
	var shots := {}
	for b: Dictionary in combat.projectiles:
		var id := str(b.id)
		shots[id] = true
		var n: Node3D = balls.get(id)
		if n == null:
			n = _make_ball(_hex(b.get("color")))
			add_child(n)
			balls[id] = n
		n.position = RuleRuntime.vector(b.pos)
	for id: String in balls.keys():
		if not shots.has(id):
			var n: Node3D = balls[id]
			Burst.spawn(self, n.position, n.get_meta("color"), 0.9)
			n.queue_free()
			balls.erase(id)
	for i in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[i]
		e.life -= dt
		var n: Node3D = e.node
		if e.life <= 0.0 or not is_instance_valid(n):
			_remove(e)
			effects.remove_at(i)
		elif e.kind == "text":
			n.position.y += dt * 0.9
			(n as Label3D).modulate.a = clampf(e.life * 2.0, 0.0, 1.0)
		elif e.kind == "beam":
			for mi: MeshInstance3D in n.get_children():
				mi.set_instance_shader_parameter("strength", clampf(e.life / 0.45, 0.0, 1.0) * 1.4)

func _make_ball(color: Color) -> Node3D:
	var root := Node3D.new()
	root.set_meta("color", color)
	var core := MeshInstance3D.new(); core.mesh = _ball_mesh; core.material_override = _energy_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.set_instance_shader_parameter("energy_color", color)
	core.set_instance_shader_parameter("strength", 1.6)
	root.add_child(core)
	var halo := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(1.1, 1.1)
	var hm := ShaderMaterial.new(); hm.shader = GLOW; hm.set_shader_parameter("tint", color)
	q.material = hm; halo.mesh = q
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var trail := CPUParticles3D.new()
	trail.amount = 24; trail.lifetime = 0.35; trail.local_coords = false
	trail.direction = Vector3.ZERO; trail.spread = 180.0; trail.initial_velocity_min = 0.2; trail.initial_velocity_max = 0.8
	trail.gravity = Vector3.ZERO; trail.scale_amount_min = 0.5; trail.scale_amount_max = 1.0
	var tq := QuadMesh.new(); tq.size = Vector2(0.14, 0.14); tq.material = hm
	trail.mesh = tq
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trail)
	return root

# ---- the Ultra Instinct energy avatar (port of fx/ultra_instinct_avatar.js)
var _av_time := 0.0
var _av_pulse := 0
var _av_strike := 1.0
var _av_arms: Array[Node3D] = []
var _av_impact: MeshInstance3D

func _update_avatar(dt: float) -> void:
	var st := combat.avatar_state()
	var active: bool = st.get("active", false)
	if not active:
		if avatar != null:
			avatar.queue_free(); avatar = null; _av_arms.clear()
		return
	var A: Dictionary = Data.avatar
	if avatar == null:
		avatar = _build_avatar(A)
		add_child(avatar)
	_av_time += dt; _av_strike += dt
	var pos: Vector3 = st.pos
	var yaw := float(st.yaw)
	avatar.position = Vector3(pos.x - sin(yaw) * 0.8, pos.y, pos.z - cos(yaw) * 0.8)
	avatar.rotation.y = yaw
	var pulse := int(st.get("pulse", 0))
	if pulse != _av_pulse:
		_av_pulse = pulse; _av_strike = 0.0
	var punch := sin(_av_strike / 0.45 * PI) if _av_strike < 0.45 else 0.0
	_av_arms[0].rotation.x = -punch * 1.5 if _av_pulse % 2 else -0.2
	_av_arms[1].rotation.x = -0.2 if _av_pulse % 2 else -punch * 1.5
	_av_impact.visible = _av_strike < 0.45
	_av_impact.scale = Vector3.ONE * (0.1 + minf(1.0, _av_strike / 0.45) * 1.1)
	for mi: MeshInstance3D in avatar.find_children("*", "MeshInstance3D", true, false):
		mi.set_instance_shader_parameter("strength", (float(A.get("opacity", 0.35)) + sin(_av_time * 5.0) * 0.025) * 2.2)

func _build_avatar(A: Dictionary) -> Node3D:
	var root := Node3D.new(); root.name = "InstinctAvatar"
	root.scale = Vector3.ONE * float(A.get("scale", 3.0))
	var col := _hex(A.get("color", 0x9fd8ff)); var core_col := _hex(A.get("coreColor", 0xffffff))
	var ball := SphereMesh.new(); ball.radius = 1.0; ball.height = 2.0; ball.radial_segments = 14; ball.rings = 8
	var make := func(parent: Node3D, c: Color, pos: Vector3, sc: Vector3, mesh: Mesh = null) -> MeshInstance3D:
		var mi := MeshInstance3D.new(); mi.mesh = mesh if mesh != null else ball; mi.material_override = _energy_mat
		mi.position = pos; mi.scale = sc
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("energy_color", c)
		parent.add_child(mi); return mi
	make.call(root, col, Vector3(0, 1.12, 0), Vector3(0.34, 0.48, 0.2))
	make.call(root, col, Vector3(0, 0.78, 0), Vector3(0.24, 0.2, 0.17))
	var head := Node3D.new(); head.position = Vector3(0, 1.73, 0); root.add_child(head)
	make.call(head, col, Vector3.ZERO, Vector3(0.17, 0.2, 0.145))
	var spike := CylinderMesh.new(); spike.top_radius = 0.0; spike.bottom_radius = 0.1; spike.height = 0.3; spike.radial_segments = 6
	for sign: float in [-1.0, 1.0]:
		var box := BoxMesh.new()
		make.call(head, core_col, Vector3(sign * 0.07, 0.018, 0.141), Vector3(0.065, 0.016, 0.012), box)
		(make.call(head, core_col, Vector3(sign * 0.12, 0.18, -0.025), Vector3(0.8, 1, 0.8), spike) as Node3D).rotation.z = sign * -0.5
		make.call(root, col, Vector3(sign * 0.14, 0.37, 0), Vector3(0.13, 0.38, 0.13))
	make.call(head, core_col, Vector3(0, 0.23, -0.04), Vector3(1, 1.2, 1), spike)
	for sign: float in [-1.0, 1.0]:
		var pivot := Node3D.new(); pivot.position = Vector3(sign * 0.34, 1.4, 0); root.add_child(pivot)
		make.call(pivot, col, Vector3(sign * 0.045, -0.3, 0), Vector3(0.12, 0.34, 0.12))
		make.call(pivot, core_col, Vector3(sign * 0.055, -0.66, 0.015), Vector3(0.12, 0.12, 0.11))
		_av_arms.append(pivot)
	var ring := TorusMesh.new(); ring.inner_radius = 0.975; ring.outer_radius = 1.025; ring.rings = 32; ring.ring_segments = 5
	_av_impact = make.call(root, core_col, Vector3(0, 0.025, float(A.get("range", 6.0)) / float(A.get("scale", 3.0)) * 0.55), Vector3.ONE * 0.05, ring)
	return root

# Presentation signals carry no gameplay commands and never mutate entities.
func _entity(id: String) -> Dictionary:
	if id=="player": return combat.p
	for e: Dictionary in combat.enemies:
		if e.id==id: return e
	return {}
func _nearest_enemy_position() -> Vector3:
	var nearest: Vector3 = combat.p.pos-Vector3(sin(combat.p.yaw),0,cos(combat.p.yaw))
	var best := INF
	for e: Dictionary in combat.enemies:
		var d: float = e.pos.distance_squared_to(combat.p.pos)
		if e.health>0 and d<best:
			best = d; nearest = e.pos
	return nearest
func _on_attack(d: Dictionary) -> void:
	var e := _entity(str(d.get("id","")))
	if e.is_empty(): return
	var kind := str(d.get("kind","jab"))
	if kind=="melee": kind = str(e.attackKind)
	if kind=="projectile": kind = "ki"
	_attack_poses[str(e.id)] = {"serial":e.attackSerial,"kind":kind}
	_push_player_presentation()
	var pos: Vector3 = e.pos+Vector3.UP*1.1
	if kind in ["jab","cross","hook","leg kick"]:
		var fx := _flourish("arc",pos,Color("d9efff"))
		fx.rotation.y = e.yaw
		audio.play_cue("whoosh",pos)
func _presentation(e: Dictionary) -> Dictionary:
	var a := {}
	var vel: Vector3 = e.get("vel",Vector3.ZERO)
	var yaw := float(e.get("yaw",0))
	a.dashSide = clampf((vel.x*cos(yaw)-vel.z*sin(yaw))/maxf(1,Vector2(vel.x,vel.z).length()),-1,1)
	a.dashBack = minf(0,(vel.x*sin(yaw)+vel.z*cos(yaw))/maxf(1,Vector2(vel.x,vel.z).length()))
	var id := str(e.id)
	if _attack_poses.has(id):
		if _attack_poses[id].serial==e.attackSerial:
			a.attackKind = _attack_poses[id].kind
		else: _attack_poses.erase(id)
	if _reactions.has(id):
		a.reactionSerial = _reactions[id].serial
		a.hitWeight = _reactions[id].hitWeight
		a.hitSide = _reactions[id].hitSide
	if id=="player":
		var ray := combat.aim_state()
		var dir: Vector3 = ray.dir
		a.aimPitch = asin(clampf(dir.y,-1,1))
		a.beamCharge = combat.snapshot().beamCharge
		a.dead = e.health<=0
	return a
func _flourish(kind: String,pos: Vector3,color: Color,direction := Vector3.FORWARD) -> CombatFlourish:
	while flourish_root.get_child_count()>=24:
		var old := flourish_root.get_child(0)
		flourish_root.remove_child(old); old.queue_free()
	var f := CombatFlourish.create(kind,color,direction)
	flourish_root.add_child(f)
	f.position = pos
	return f
func _update_player_presentation(dt: float) -> void:
	if get_parent()==null: return
	var fighter := get_parent().get_node_or_null("Player") as Fighter
	if fighter==null: return
	fighter.set_terrain(combat.zone)
	fighter.presentation = _presentation(combat.p)
	var charging: bool = combat.p.charging and combat.p.health>0
	_charge_age = minf(2,_charge_age+dt) if charging else 0.0
	audio.update_player(combat.p,combat.p.pos,_charge_age/2)
	var color := _hex(RuleRuntime.ki_color(combat.game.slot.appearance))
	if str(combat.p.form)!=_last_form:
		_last_form = str(combat.p.form)
		if _last_form!="":
			_flourish("surge",combat.p.pos+Vector3.UP*0.1,color)
			audio.play_cue("surge",combat.p.pos,MotionStyle.for_form(_last_form).weight)
	if combat.p.dashing and not _last_dash:
		_flourish("surge",combat.p.pos+Vector3.UP*0.6,color)
	_last_dash = combat.p.dashing

func _push_player_presentation() -> void:
	if get_parent()==null: return
	var fighter := get_parent().get_node_or_null("Player") as Fighter
	if fighter!=null: fighter.presentation = _presentation(combat.p)
