class_name RuleTutorialRules
extends RefCounted
var flags: Dictionary
var steps: Array = RuleTables.table("tutorial_steps")
var total: int:
	get: return steps.size()
var active: bool:
	get: return (flags.tutorial is int or flags.tutorial is float) and flags.tutorial>=0 and flags.tutorial<total
var index: int:
	get: return int(flags.tutorial) if active else -1
var step: Variant:
	get: return steps[index] if active else null
var counters: Dictionary
var last_serial: Variant = null
var beam_was_held: bool = false
var last_pos: Variant = null
func _init(slot: Dictionary) -> void:
	if not slot.has("story"):
		slot.story = {}
	if not slot.story.has("flags"):
		slot.story.flags = {}
	flags = slot.story.flags
	if not flags.has("tutorial"):
		flags.tutorial = "done" if slot.get("level",1)>1 or not slot.get("quests",{}).is_empty() else 0
	reset()
func reset() -> void:
	counters = {"time":0.0,"look":0.0,"moved":0.0,"flying":0.0,"charging":0.0,"blocking":0.0,"talked":false,"count":{"jump":0,"dash":0,"swing":0,"ki_blast":0,"beam_release":0,"lock_on":0}}
func text(labels: Dictionary = {}) -> String:
	if not active:
		return ""
	var result: String = step.text
	for key: String in labels:
		result = result.replace("{"+key+"}",str(labels[key]))
	return result
func look(amount: float) -> void:
	if active:
		counters.look += absf(amount)
func note(what: String) -> void:
	if active and what=="talk":
		counters.talked = true
func update(dt: float,it: Dictionary,p: Dictionary) -> Variant:
	if not active:
		return null
	counters.time += dt
	if last_pos!=null:
		counters.moved += Vector2(p.pos.x-last_pos.x,p.pos.z-last_pos.z).length()
	last_pos = p.pos
	if p.flying:
		counters.flying += dt
	if p.charging or it.get("charge",false):
		counters.charging += dt
	if p.blocking or it.get("block",false):
		counters.blocking += dt
	for action: String in ["jump","dash","ki_blast","lock_on"]:
		if it.get(action,false):
			counters.count[action] += 1
	if last_serial!=null and p.attackSerial!=last_serial:
		counters.count.swing += 1
	last_serial = p.attackSerial
	if beam_was_held and not it.get("beam",false):
		counters.count.beam_release += 1
	beam_was_held = it.get("beam",false)
	var done: bool = false
	match step.id:
		"look": done = counters.look>1.2
		"move": done = counters.moved>6
		"jump": done = counters.count.jump>=1
		"dash": done = counters.count.dash>=1
		"fly": done = counters.flying>1.5
		"land": done = not p.flying and p.onGround
		"melee": done = counters.count.swing>=3
		"blast": done = counters.count.ki_blast>=1
		"beam": done = counters.count.beam_release>=1
		"charge": done = counters.charging>1.5
		"guard": done = counters.blocking>1
		"lock": done = counters.count.lock_on>=1
		"talk": done = counters.talked
		"menu": done = counters.time>10
	if not done:
		return null
	var id: String = step.id
	flags.tutorial = int(flags.tutorial)+1
	if flags.tutorial>=total:
		flags.tutorial = "done"
	reset()
	return id
func skip() -> void:
	if active:
		flags.tutorial = "skipped"
func restart() -> void:
	flags.tutorial = 0
	reset()
