extends "res://tests/rules/game_case.gd"
const StoryRules = preload("res://rules/story.gd")
class Session extends RefCounted:
	var slot: Dictionary
	var game: RuleGame
	var story: RefCounted
	var bus := Recorder.new()
	func _init(race: String = "Saiyan") -> void:
		var schema := RuleSchema.new()
		slot = schema.new_slot(schema.default_look(race),1000)
		enter("earth_plains")
	func enter(id: String) -> void:
		slot.zone = id
		slot.position = null
		game = RuleGame.new(0,slot,bus)
		story = StoryRules.new(game,bus)
	func at(p: Dictionary) -> void:
		game.player.pos = Vector3(p.x,p.get("y",game.zone.height_at(p.x,p.z)),p.z)
		game.player.vel = Vector3.ZERO
		game.player.flying = false
		game.player.onGround = true
func go(s: Session,id: String) -> bool:
	if s.story.here()==id:
		return true
	if s.game.zone is RulePlanet and s.game.zone.has_region(id):   # open world: fly across the planet
		s.at(s.game.zone.region_spawn(id))
		s.slot.zone = id
		s.story.update(1.0/60)
		ok(s.story.here()==id,"arrived in "+id)
		return true
	var guide: Variant = s.story.travel_guide()
	ok(guide!=null,"guide from %s to %s; tasks %s" % [s.game.zone.id,id,s.story.tasks_here()])
	if guide==null:
		return false
	s.at(guide)
	grind(s,s.story.travel_level(id))   # travelling needs the destination's level
	var valid: bool = s.story.travel_to(id)
	ok(valid,"travel offered: "+id)
	if valid:
		s.enter(id)
	return valid
## Where a collect spot (area coordinates) is on the loaded map.
func spot_at(s: Session,spot: Dictionary,step: Dictionary) -> Dictionary:
	var z: String = str(spot.get("zone",step.get("zone","")))
	return s.game.zone.place_in(z,spot.x,spot.z) if s.game.zone is RulePlanet else spot
func grind(s: Session,level: int) -> void:
	while s.slot.level<level:
		s.game.add_xp(s.game.progression.xp_to_next(int(s.slot.level)))
func play(s: Session,q: Dictionary) -> void:
	for id: String in q.get("after",[]):
		if not s.story.is_done(id):
			play(s,s.story.quest[id])
	if q.get("automatic",false):
		var form: Dictionary = RuleTables.table("forms")[q.id.substr(5)]
		var edge: Dictionary = form.mastery
		if edge.from not in s.slot.forms:
			play(s,s.story.quest["Form_"+edge.from])
		grind(s,int(q.level))
		eq(s.game.select_form(edge.from),null)
		s.game.add_form_mastery(edge.required+1)
		return
	grind(s,int(q.get("level",1)))
	var giver: Dictionary = s.story.npc[q.giver]
	if not go(s,giver.zone):
		return
	s.at(s.story.npc_pos(giver))
	ok(s.story.accept_quest(q.id),"accept "+q.id)
	if not s.story.is_active(q.id):
		return
	run_steps(s,q)
func run_steps(s: Session,q: Dictionary) -> void:
	for guard: int in 60:
		if not s.story.is_active(q.id):
			break
		var step: Dictionary = s.story.step_of(q)
		match step.type:
			"talk":
				var n: Dictionary = s.story.npc[step.npc]
				if not go(s,n.zone): return
				ok(s.story.visible(n),q.id+" talk visible "+n.id)
				s.at(s.story.npc_pos(n))
				eq(s.story.interact(),"talk",q.id)
			"travel":
				if not go(s,step.zone): return
				s.story.update(1.0/60)
			"reach":
				if not go(s,step.zone): return
				s.at(s.story.at(step))
				s.story.update(1.0/60)
			"defeat":
				if not go(s,step.zone): return
				var before: int = int(s.slot.quests[q.id].step)
				var waypoint: Variant = s.story.waypoint()
				ok(waypoint!=null,q.id+" fight waypoint")
				if waypoint!=null:
					s.at(waypoint)
					s.story.interact()
				eq(int(s.slot.quests[q.id].step),before,"talk cannot win fights")
				for i: int in int(step.get("count",1)):
					s.story.enemy_defeated(step.enemy,step.zone)
			"collect":
				for spot: Dictionary in step.spots:
					if not go(s,spot.get("zone",step.get("zone"))): return
					s.at(spot_at(s,spot,step))
					s.story.update(1.0/60)
			"train":
				if not go(s,step.zone): return
				s.at(s.story.at(step) if step.has("x") else s.game.zone.spawn)
				var it: Dictionary = {}
				s.game.player.charging = false
				match step.get("mode",""):
					"move": s.game.player.vel.x = 4
					"charge": it.charge = true
					"fly": s.game.player.flying = true
				if step.has("requiredForms"):
					s.game.player.form = step.requiredForms[0]
				s.story.update(step.seconds+0.01,it)
			"level":
				grind(s,int(step.level))
				s.story.update(1.0/60)
	ok(not s.story.is_active(q.id),"finished "+q.id)
