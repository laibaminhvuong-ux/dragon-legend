class_name CoopGameMirror
extends RuleGame
var connection: WeakRef
func send(name: String,args: Array = []) -> void:
	if connection!=null and connection.get_ref()!=null: connection.get_ref().command(name,args)
func select_form(id: String) -> Variant: send("form",[id]); return null
func choose_form_path(path: String) -> Variant: send("path",[path]); return null
func customize_appearance(changes: Dictionary) -> Variant: send("appearance",[changes]); return null
func equip_accessory(id: String) -> Variant: send("accessory",[id]); return null
func equip_outfit(id: String) -> bool: send("outfit",[id]); return true
func spend_stat_point(stat: String,amount: Variant = 1) -> Variant: send("stat",[stat,amount]); return null
func toggle_favorite_form(id: String) -> Variant: send("favorite",[id]); return true
class CombatMirror extends RuleCombat:
	var remote: Dictionary = {}
	func set_technique(id: String) -> bool: game.send("technique",[id]); return true
	func snapshot() -> Dictionary: return remote if not remote.is_empty() else super.snapshot()
	func avatar_state() -> Dictionary:
		return remote.get("avatar",{}).merged({"pos":p.pos,"yaw":p.yaw},true)
class KaiokenMirror extends RuleKaioken:
	var remote: Dictionary = {}
	func select(rank: int) -> Variant: game.send("kaioken_rank",[rank]); return null
	func snapshot() -> Dictionary: return remote if not remote.is_empty() else super.snapshot()
	func multiplier() -> float: return float(remote.get("multiplier",1))
