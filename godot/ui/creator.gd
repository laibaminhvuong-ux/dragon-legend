class_name Creator
extends Control
# Create a fighter (port of web/src/ui/creator.js): race, build, skin, face, hair, hair colour, outfit and its
# colour, with a live 3D preview that turns slowly. Randomize, then Create starts the game in that slot.

var main: Node
var slot_index := 0
var look: Dictionary
var _form: VBoxContainer
var _vp: SubViewport
var _fighter: Fighter
var _pivot: Node3D

func _init(m: Node, index: int) -> void:
	main = m
	slot_index = index
	UiKit.ensure_data()
	name = "Creator"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color(0.02, 0.03, 0.06, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 24)
	row.offset_left = 60; row.offset_right = -60; row.offset_top = 40; row.offset_bottom = -40
	add_child(row)
	var left := PanelContainer.new(); left.custom_minimum_size = Vector2(620, 0)
	row.add_child(left)
	var scroll := ScrollContainer.new(); left.add_child(scroll)
	_form = VBoxContainer.new(); _form.add_theme_constant_override("separation", 10)
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form)
	var svc := SubViewportContainer.new(); svc.stretch = true
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(svc)
	_vp = SubViewport.new(); _vp.own_world_3d = true; _vp.transparent_bg = true
	svc.add_child(_vp)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_vp.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 35, 0); sun.light_energy = 1.2; _vp.add_child(sun)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-20, 200, 0); rim.light_energy = 0.6; rim.light_color = Color(0.7, 0.8, 1.0); _vp.add_child(rim)
	var cam := Camera3D.new(); cam.fov = 38; _vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.3, 4.2), Vector3(0, 0.95, 0))
	_pivot = Node3D.new(); _vp.add_child(_pivot)
	look = _fix(RuleSchema.new().default_look(str(_race_order()[0])))
	_draw()

## Keeps every field valid for its race (after a race change or randomize).
func _fix(l: Dictionary) -> Dictionary:
	var out := l.duplicate()
	var race: Dictionary = Data.races.get(str(out.get("race", "Saiyan")), Data.races.values()[0])
	out["race"] = race.id
	if not (race.hairStyles as Array).has(out.get("hair")): out["hair"] = race.hairStyles[0]
	if int(out.get("skin", 0)) >= (race.skins as Array).size(): out["skin"] = 0
	var starters := _starters(str(race.id))
	if not starters.has(out.get("outfit")): out["outfit"] = starters[0]
	return out

static func _race_order() -> Array:
	var o: Variant = RuleTables.table("race_order")
	return o if o is Array and not (o as Array).is_empty() else Data.races.keys()

static func _starters(race_id: String) -> Array:
	var out := []
	for id: String in RuleTables.table("outfit_order"):
		var o: Dictionary = Data.outfits.get(id, {})
		if o.get("starter", false) and (o.get("races") == null or (o.races as Array).has(race_id)):
			out.append(id)
	return out if not out.is_empty() else ["TurtleGi"]

func _draw() -> void:
	for c in _form.get_children():
		_form.remove_child(c); c.queue_free()
	var head := HBoxContainer.new()
	var t := UiKit.label("Create a fighter", "HeaderLarge"); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.button("Randomize", _randomize))
	_form.add_child(head)
	_form.add_child(UiKit.label("Slot %d" % (slot_index + 1), "Muted"))
	var race: Dictionary = Data.races[look.race]
	var order: Array = _race_order()
	_choices("Race", order.map(func(id: String) -> Array: return [id, Data.races[id].name]), look.race, func(v: Variant) -> void:
		look["race"] = v; look = _fix(look); _draw())
	var desc := UiKit.label(RuleRuntime.rename_text(str(race.get("desc", race.get("description", "")))), "Muted", true)
	desc.custom_minimum_size.x = 560
	_form.add_child(desc)
	_choices("Build", Data.appearance.BUILDS.map(func(x: Dictionary) -> Array: return [x.id, x.name]), look.get("build"), func(v: Variant) -> void: look["build"] = v; _draw())
	_swatches("Skin", race.skins, int(look.get("skin", 0)), func(i: int) -> void: look["skin"] = i; _draw())
	_choices("Face", Data.appearance.FACES.map(func(x: Dictionary) -> Array: return [x.id, x.name]), look.get("face"), func(v: Variant) -> void: look["face"] = v; _draw())
	if (race.hairStyles as Array).size() > 1 or race.hairStyles[0] != "None":
		_choices("Hair", (race.hairStyles as Array).map(func(id: String) -> Array: return [id, id]), look.get("hair"), func(v: Variant) -> void: look["hair"] = v; _draw())
		_swatches("Hair colour", Data.appearance.HAIR_COLORS, int(look.get("hairColor", 0)), func(i: int) -> void: look["hairColor"] = i; _draw())
	_choices("Outfit", _starters(str(look.race)).map(func(id: String) -> Array: return [id, Data.outfits[id].name]), look.get("outfit"), func(v: Variant) -> void: look["outfit"] = v; _draw())
	_swatches("Outfit colour", Data.appearance.TINTS, int(look.get("outfitTint", 0)), func(i: int) -> void: look["outfitTint"] = i; _draw())
	var actions := HBoxContainer.new()
	actions.add_child(UiKit.button("Create", _create, true))
	actions.add_child(UiKit.button("Back", func() -> void: main.call("go_menu")))
	_form.add_child(actions)
	_rebuild_preview()

func _choices(label_text: String, options: Array, value: Variant, pick: Callable) -> void:
	_form.add_child(UiKit.label(label_text, "HeaderMedium"))
	var flow := HFlowContainer.new()
	for o: Array in options:
		var id: Variant = o[0]
		var b := UiKit.button(str(o[1]), func() -> void: pick.call(id), str(id) == str(value))
		flow.add_child(b)
	_form.add_child(flow)

func _swatches(label_text: String, colors: Array, value: int, pick: Callable) -> void:
	_form.add_child(UiKit.label(label_text, "HeaderMedium"))
	var flow := HFlowContainer.new()
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color.hex((int(colors[i]) << 8) | 0xff); sb.set_corner_radius_all(20)
		if i == value:
			sb.set_border_width_all(3); sb.border_color = Color.WHITE
		for st: String in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		var idx := i
		b.pressed.connect(func() -> void: pick.call(idx))
		flow.add_child(b)
	_form.add_child(flow)

func _randomize() -> void:
	var order: Array = _race_order()
	var race: Dictionary = Data.races[order.pick_random()]
	var builds: Array = Data.appearance.BUILDS
	look = _fix({"race": race.id, "build": builds.pick_random().id, "skin": randi() % (race.skins as Array).size(),
		"face": (Data.appearance.FACES as Array).pick_random().id, "hair": (race.hairStyles as Array).pick_random(),
		"hairColor": randi() % (Data.appearance.HAIR_COLORS as Array).size(), "outfit": _starters(race.id).pick_random(),
		"outfitTint": randi() % (Data.appearance.TINTS as Array).size(), "kiColor": look.get("kiColor", 0)})
	_draw()

func _create() -> void:
	if SaveStore.create_slot(slot_index, look):
		main.call("start_game", slot_index)
	else:
		Events.emit_named("notify", {"text": "That slot is taken"})

func _rebuild_preview() -> void:
	if _fighter != null:
		_fighter.dispose()
	_fighter = Fighter.create(look)
	_pivot.add_child(_fighter)

func _process(dt: float) -> void:
	if _fighter != null:
		_pivot.rotation.y += dt * 0.5
		_fighter.update(dt, {})
