extends Node3D
const DRAW_RANGE := 200.0   # metres; enemies further away are hidden and not animated
# Combat presentation (port of web/src/combat/view.js, with better effects). Reads RuleCombat's entities and
# events only; it never awards damage or rewards. Enemies are Fighters with name tags and health bars; ki blasts
# glow and trail sparks; beams have a hot core and an impact burst; hits spark and float damage numbers.

const ENERGY := preload("res://fx/shaders/energy.gdshader")
const GLOW := preload("res://fx/shaders/glow_point.gdshader")
const BAR := preload("res://fx/shaders/bar.gdshader")

var combat: RuleCombat
var camera: Camera3D
var views: Dictionary = {}      # enemy id -> {fighter, tag, bar}
var effects: Array = []         # {node, life, kind}
var avatar: Node3D
var _energy_mat: ShaderMaterial
var _bar_mat: ShaderMaterial
var flourish_root: Node3D
var audio: CombatAudio
var skill_fx: SkillDirector   # Codex's per-skill effects and sound bank (presentation rebuild 2026-11-04)
var _attack_poses: Dictionary = {}
var _reactions: Dictionary = {}
var _charge_age := 0.0
var _last_form := ""
var _last_dash := false
var _reaction_serial := 0
var _hitstops: Dictionary = {}   # fighter id -> {serial, value}: impact freeze for attacker and victim (visual only)
var _bar_mesh: QuadMesh

func _init(c: RuleCombat, cam: Camera3D) -> void:
	name = "Combat"
	combat = c
	camera = cam
	_energy_mat = ShaderMaterial.new(); _energy_mat.shader = ENERGY
	_bar_mat = ShaderMaterial.new(); _bar_mat.shader = BAR
	_bar_mesh = QuadMesh.new(); _bar_mesh.size = Vector2(1.35, 0.12)
	flourish_root = Node3D.new(); flourish_root.name = "Flourishes"; add_child(flourish_root)
	audio = CombatAudio.new(); audio.name = "CombatAudio"; add_child(audio)
	Events.attack.connect(_on_attack)
	Events.damage.connect(_on_damage)
	Events.avatar_strike.connect(_on_avatar_strike)
	# Skill casts, beams, projectiles and hit impacts/sounds are all drawn by the director (no duplicate generic FX here).
	skill_fx = SkillDirector.new(); skill_fx.name = "SkillFX"; add_child(skill_fx)
	skill_fx.bind(Events, _resolve_fighter, str(Settings.get_value("quality")) if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root.has_node("Settings") else "medium")
	skill_fx.ghost_factory = _ghost

func _exit_tree() -> void:
	for sig: Signal in [Events.attack, Events.damage, Events.avatar_strike]:
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
	# style reactions (Codex's damage fields): launch, a knockback shove, or a stagger
	var reaction := "launch" if d.get("launch", false) else ("knockback" if float(d.get("knockback", 0.0)) >= 0.45 else ("stagger" if d.has("stagger") else ""))
	_reactions[str(d.get("id",""))] = {"serial":_reaction_serial,"left":maxf(0.35, float(d.get("stagger", 0.0))),"hitWeight":weight,
		"hitSide":clampf(incoming.x*cos(yaw)-incoming.z*sin(yaw),-1,1),"reaction":reaction}
	var hs := float(d.get("hitstop", 0.0))
	if hs > 0.0:
		for who: String in [str(d.get("id","")), str(d.get("source_id",""))]:
			if who != "":
				_hitstops[who] = {"serial": _reaction_serial, "value": hs}
	_push_player_presentation()
	var l := _label(("GUARD " if d.get("blocked", false) else "") + str(d.get("amount", "")), Color("#ff8279") if player_hit else Color("#ffe294"), 42)
	l.position = pos + Vector3(randf_range(-0.3, 0.3), 0.2, 0)
	add_child(l)
	effects.append({"node": l, "life": 1.0, "kind": "text"})
	while effects.size() > 32:
		_remove(effects.pop_front())

func _on_avatar_strike(d: Dictionary) -> void:
	var pos: Vector3 = RuleRuntime.vector(d.get("pos", Vector3.ZERO))
	Burst.spawn(self, pos + Vector3.UP, Color(0.75, 0.85, 1.0), 2.5)

func _remove(e: Dictionary) -> void:
	var n: Node = e.node
	if is_instance_valid(n):
		n.queue_free()

## The live Fighter for an event's actor id: "player" (and our own co-op id), enemies, co-op friends.
func _resolve_fighter(id: String) -> Node3D:
	if id == "player" or id == "":
		return get_parent().get_node_or_null("Player") as Node3D if get_parent() != null else null
	if views.has(id):
		return views[id].fighter
	var friends: Variant = get_parent().get("friends") if get_parent() != null else null
	if friends is Dictionary and (friends as Dictionary).has(id):
		return friends[id].fighter
	return null

func _skill_actors() -> Array:
	var out: Array = [combat.p]
	var friends: Variant = get_parent().get("friends") if get_parent() != null else null
	if friends is Dictionary:
		for id: String in friends:
			var st: Variant = friends[id].get("state")
			if st is Dictionary:
				var row: Dictionary = (st as Dictionary).duplicate()
				if row.get("skillState") is Dictionary and not (row.skillState as Dictionary).is_empty():
					row.skillState = (row.skillState as Dictionary).duplicate(); row.skillState.actor_id = id
				out.append(row)
	return out

## Afterimage: a frozen copy of the caster's actual model in its current pose (visual only, no scripts or physics).
func _ghost(id: String, color: Variant) -> Node3D:
	var f := _resolve_fighter(id) as Fighter
	if f == null or not is_instance_valid(f):
		return null
	var ghost := Node3D.new()
	var mat := StandardMaterial3D.new()
	var c: Color = color if color is Color else _hex(color)
	mat.albedo_color = Color(c.r, c.g, c.b, 0.35)
	mat.emission_enabled = true; mat.emission = c; mat.emission_energy_multiplier = 1.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh if mi.skin == null else _baked_pose(mi)
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.transform = f.global_transform.affine_inverse() * mi.global_transform
		ghost.add_child(copy)
	# the effect is placed at the cast socket; put the copy back where the fighter stands
	ghost.ready.connect(func() -> void: ghost.global_transform = f.global_transform if is_instance_valid(f) else ghost.global_transform, CONNECT_ONE_SHOT)
	return ghost

## The skinned body in its current pose as a static mesh (for afterimages).
static func _baked_pose(mi: MeshInstance3D) -> Mesh:
	var baked: Variant = mi.call("bake_mesh_from_current_skeleton_pose") if mi.has_method("bake_mesh_from_current_skeleton_pose") else null
	return baked if baked is Mesh else mi.mesh

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
		# far-away enemies (open-world maps have trainees in every area) are neither drawn nor animated
		var near: bool = (e.pos as Vector3).distance_squared_to(combat.p.pos) < DRAW_RANGE * DRAW_RANGE
		var f: Fighter = v.fighter
		f.visible = alive and near; v.tag.visible = alive and near; v.bar.visible = alive and near
		if not alive or not near:
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
	skill_fx.set_paused(dt <= 0)
	skill_fx.sync_projectiles(combat.projectiles)
	skill_fx.update_actor_states(_skill_actors())
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
	if str(d.get("phase", "release")) not in ["release", ""]:
		return   # prepare / cancel / recovery / dodge are presentation-only (SkillDirector)
	var e := _entity(str(d.get("id","")))
	if e.is_empty(): return
	var kind := str(d.get("kind","jab"))
	if kind=="melee": kind = str(e.attackKind)
	if str(d.get("strike","")) != "": kind = str(d.strike)   # host-chosen combo strike (jab/cross/hook/uppercut/knee/...)
	if kind=="projectile": kind = "ki"
	var recipe := SkillCatalog.get_skill(str(d.get("move_id","")))
	_attack_poses[str(e.id)] = {"serial":e.attackSerial,"kind":kind,"pose":str(d.get("pose","")),"finisher":bool(d.get("finisher",false)),
		"style":str(d.get("style","")),"move":str(d.get("finisher_move",d.get("dash_move",d.get("move","")))),"comboStep":int(d.get("combo_step",1)),
		"hold_min":float(recipe.get("hold_min",0.0)),"release_window":float(recipe.get("release_window",0.45)),"recovery":float(recipe.get("recovery",0.45))}
	_push_player_presentation()
	var pos: Vector3 = e.pos+Vector3.UP*1.1
	if kind in ["jab","cross","hook","leg kick","uppercut","palm_strike","knee","spin_kick","axe_kick"]:
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
			a.skillReleasePose = _attack_poses[id].get("pose","")
			a.finisher = _attack_poses[id].get("finisher",false)
			if str(_attack_poses[id].get("style","")) != "":
				a.style = _attack_poses[id].style
				a.move = _attack_poses[id].move
				a.comboStep = _attack_poses[id].comboStep
			a.skillHoldMin = _attack_poses[id].get("hold_min",0.0)
			a.skillReleaseWindow = _attack_poses[id].get("release_window",0.45)
			a.skillRecovery = _attack_poses[id].get("recovery",0.45)
		else: _attack_poses.erase(id)
	var st: Variant = e.get("skillState")
	if st is Dictionary and str((st as Dictionary).get("phase","")) == "prepare":
		a.skillHoldPose = str(st.get("pose",""))
		a.skillHold = 0.55 + 0.45 * clampf(float(st.get("charge",0)),0,1)
	if not a.has("style"):
		a.style = str(e.get("style", "turtle"))
	a.inCombat = _in_combat(e)
	if _hitstops.has(id):
		a.hitstop = _hitstops[id].value
		a.hitstopSerial = _hitstops[id].serial
	if _reactions.has(id):
		a.reaction = _reactions[id].get("reaction", "")
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
## Whether a fighter should stand in its fighting guard: the player near a hostile enemy (or locked on), an enemy
## that is hostile and near the player.
func _in_combat(e: Dictionary) -> bool:
	if float(e.get("health", 1.0)) <= 0.0:
		return false
	if str(e.get("id", "")) == "player":
		if combat.snapshot().get("target") is Dictionary:
			return true
		for o: Dictionary in combat.enemies:
			if float(o.health) > 0.0 and _hostile(o) and (o.pos as Vector3).distance_squared_to(combat.p.pos) < 144.0:
				return true
		return false
	return _hostile(e) and (e.pos as Vector3).distance_squared_to(combat.p.pos) < 225.0

static func _hostile(e: Dictionary) -> bool:
	return not str(e.get("key", "")).begins_with("patrol_") or bool(e.get("provoked", false))

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
