class_name RuleStyles
extends RefCounted
const DEFAULT := "turtle"
static func all() -> Dictionary: return RuleTables.table("fighting_styles").get("styles",{})
static func valid(id: Variant) -> bool: return id is String and all().has(id)
static func normalize(id: Variant) -> String: return id if valid(id) else DEFAULT
static func get_style(id: Variant) -> Dictionary: return all().get(normalize(id),{})
static func npc_style(id: String) -> String: return normalize(RuleTables.table("fighting_styles").get("npc_assignments",{}).get(id,DEFAULT))
static func move(style: Variant,step: int,dashing: bool = false) -> Dictionary:
	var tuning := get_style(style)
	var current := posmod(step-1,4)
	var core: Dictionary = tuning.combo[current]
	var chosen: Dictionary = tuning.dash_in if dashing and current==0 else tuning.finisher if current==3 else core
	var out := {"style":tuning.id,"move":chosen.id,"combo_move":core.id,"combo_step":current+1,"combo_length":4,"strike":chosen.strike,"finisher":current==3,
		"chain_window":tuning.chain_window,"lunge":chosen.lunge,"strike_duration":tuning.cadence[current],"socket":"foot_r" if chosen.strike in ["knee","spin_kick","axe_kick"] else "hand_l" if chosen.strike in ["jab","hook"] else "hand_r"}
	if dashing and current==0: out.dash_move = tuning.dash_in.id
	if current==3: out.finisher_move = tuning.finisher.id
	return out
static func reaction(style: Variant,finisher: bool,blocked: bool = false) -> Dictionary:
	var tuning := get_style(style)
	return {"knockback":float(tuning.knockback)*(1.5 if finisher else 1.0)*(.4 if blocked else 1.0),
		"launch":finisher and bool(tuning.finisher.launch) and not blocked,"stagger":float(tuning.stagger)*(1.3 if finisher else 1.0),"hitstop":minf(.09,float(tuning.hitstop)+(.015 if finisher else 0))}
