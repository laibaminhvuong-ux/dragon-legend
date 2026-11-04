class_name SkillEffect
extends Node3D
## One bounded effect. No gameplay state, collision or damage is owned here.
var profile: Dictionary
var packet: Dictionary
var age := 0.0
var sustained := false
var duration := .7
var parts: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var strength := .3
var geometry := "orb"
var segment_count := 24
func setup(recipe: Dictionary,event: Dictionary,phase: String,segments: int = 24) -> void:
	profile = recipe; packet = event.duplicate(true); segment_count = segments
	geometry = str(recipe.get("geometry","orb"))
	if phase=="prepare" and geometry not in ["spirit","eclipse","heavy_orb","disc","focus","avatar","destruction"]: geometry = "gather"
	sustained = phase=="prepare" or phase=="projectile"
	duration = float(recipe.get("lifetime",.7))
	var tint := SkillCatalog.color(event,recipe)
	var accent := Color.hex((int(recipe.get("accent",0xffffff))<<8)|0xff)
	var width := float(recipe.get("width",.3))
	if phase=="impact":
		geometry = "impact" if geometry not in ["disc","spiral","shield","destruction","heal","focus","claw","sunburst"] else geometry
		duration = .38; width = maxf(.25,width)
	if geometry in ["wave","double_wave","wide_wave","needle","lance","triad","spiral","demon_wave","ribbon"] and event.has("to"):
		var end: Vector3 = RuleRuntime.vector(event.to)
		var start: Vector3 = RuleRuntime.vector(event.get("from",event.get("origin",Vector3.ZERO)))
		var delta := end-start
		if delta.length()>.001: quaternion = Quaternion(Vector3.UP,delta.normalized())
		var count := 3 if geometry=="triad" else 2 if geometry=="double_wave" else 1
		for i in count:
			var beam := CylinderMesh.new(); beam.top_radius = width*.2; beam.bottom_radius = width; beam.height = maxf(.01,delta.length()); beam.radial_segments = segments
			var part := add_part(beam,tint); part.position.y = delta.length()/2
			if count>1:
				part.position.x = cos(i*TAU/count)*width; part.position.z = sin(i*TAU/count)*width
		if geometry in ["spiral","ribbon"]: add_helix(delta.length(),width*2,accent)
	else:
		var sphere := SphereMesh.new(); sphere.radius = maxf(.08,width); sphere.height = sphere.radius*2; sphere.radial_segments = segments; sphere.rings = maxi(4,segments/2)
		if geometry=="disc": sphere.height = .06
		if geometry in ["claw","impact","sunburst","destruction"]:
			for i in (8 if geometry=="sunburst" else 5):
				var shard := PrismMesh.new(); shard.size = Vector3(width*.13,width*(2 if geometry=="sunburst" else 1),width*.12)
				var part := add_part(shard,accent); part.rotation.z = i*TAU/5; part.position = Vector3(sin(i*2.4),cos(i*2.4),0)*width*.4
		else: add_part(sphere,tint)
		if geometry=="shield": sphere.is_hemisphere = false
		if geometry in ["afterimage","transfer"]:
			for part in parts: part.scale = Vector3(.45,1.6,.35)
		if geometry in ["spirit","eclipse"] and phase=="prepare": position.y += width*.8
		var ring_count := 3 if geometry in ["spirit","eclipse","avatar","formation","heal","shield","focus","gather"] else 1
		for i in ring_count:
			var torus := TorusMesh.new(); torus.inner_radius = maxf(.06,width*.8); torus.outer_radius = maxf(.1,width); torus.rings = segments; torus.ring_segments = 8
			var ring := add_part(torus,accent); ring.rotation = Vector3(i*.7,0,i*1.1); rings.append(ring)
		if geometry=="spiral": add_helix(width*2,width,accent)
func add_part(mesh: Mesh,color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.mesh = mesh
	var material := ShaderMaterial.new(); material.shader = preload("res://fx/shaders/skill_energy.gdshader"); material.set_shader_parameter("tint",color)
	node.material_override = material; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node); parts.append(node); return node
func add_helix(length: float,width: float,color: Color) -> void:
	var mesh := ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segment_count*4+1:
		var t := float(i)/(segment_count*4); var angle := t*TAU*7
		for offset in [-.07,.07]:
			mesh.surface_set_uv(Vector2(t,offset*5+.5)); mesh.surface_set_normal(Vector3(cos(angle),0,sin(angle)))
			mesh.surface_add_vertex(Vector3(cos(angle)*(width+offset),length*t,sin(angle)*(width+offset)))
	mesh.surface_end(); add_part(mesh,color)
func advance(dt: float) -> bool:
	age += dt
	if geometry=="disc": rotate_y(dt*8)
	if geometry=="destruction": rotate_z(dt*2)
	var progress := clampf(age/maxf(.01,duration),0,1)
	var size := .3+strength*.9 if sustained else 1.0+progress*.7
	scale = Vector3.ONE*size if geometry not in ["wave","double_wave","wide_wave","needle","lance","triad","spiral","demon_wave","ribbon"] else Vector3(1-progress*.5,1,1-progress*.5)
	for i in rings.size():
		rings[i].rotate_y(dt*(1+i*.3)); rings[i].rotate_z(dt*.7)
		if geometry=="heal": rings[i].position.y = fmod(age+i*.3,1)*1.8
	for part in parts:
		(part.material_override as ShaderMaterial).set_shader_parameter("intensity",(.4+strength) if sustained else 1-progress)
	return sustained or age<duration
