class_name RuleCutsceneRules
extends RefCounted
const SCENE_RANGE := 24.0
var seen: Dictionary
var story_bosses: Dictionary = {}
var npcs: Dictionary = {}
func _init(slot: Dictionary) -> void:
	if not slot.has("story"):
		slot.story = {}
	if not slot.story.has("flags"):
		slot.story.flags = {}
	if not slot.story.flags.get("scenes") is Dictionary:
		slot.story.flags.scenes = {}
	seen = slot.story.flags.scenes
	for n: Dictionary in RuleTables.table("npcs"):
		npcs[n.id] = n
	for q: Dictionary in RuleTables.table("quests"):
		for s: Dictionary in q.steps:
			if s.type=="defeat" and s.get("count",1)==1 and not s.enemy.begins_with("patrol_"):
				story_bosses[s.enemy] = true
func speaker_name(id: String,boss_name: Variant) -> String:
	if id=="you":
		return "You"
	var n: Dictionary = npcs.get(id,{})
	return RuleTables.table("characters")[n.who].name if not n.is_empty() else str(boss_name) if boss_name!=null else id
func scene_lines(enemy: String,kind: String,boss_name: Variant = null) -> Array:
	var lines: Array = RuleTables.table("cutscenes").get(enemy,{}).get(kind,[])
	if lines.is_empty():
		var name: String = str(boss_name) if boss_name!=null else speaker_name(enemy,null)
		lines = [["boss","So, you're the one they sent? I am %s. Prepare yourself." % name],["you","Let's go."]] if kind=="before" else [["boss","How... how could I lose to you..."]]
	var out: Array = []
	for line: Array in lines:
		var speaker: String = enemy if line[0]=="boss" else line[0]
		out.append({"speaker":speaker,"name":speaker_name(speaker,boss_name),"text":RuleRuntime.rename_text(line[1])})
	return out
func before_for(encounters: Array,pos: Vector3) -> Variant:
	for e: Dictionary in encounters:
		var key: String = "before:"+e.key
		if not e.get("boss",false) or not story_bosses.has(e.key) or seen.get(key,false) or Vector2(e.x-pos.x,e.z-pos.z).length()>SCENE_RANGE:
			continue
		seen[key] = true
		return {"kind":"before","enemy":e.key,"lines":scene_lines(e.key,"before",e.get("name"))}
	return null
func after_for(enemy: String,boss_name: Variant = null) -> Variant:
	var key: String = "after:"+enemy
	if not story_bosses.has(enemy) or seen.get(key,false):
		return null
	seen[key] = true
	return {"kind":"after","enemy":enemy,"lines":scene_lines(enemy,"after",boss_name)}
