class_name CoopStoryMirror
extends RuleStory
var connection: WeakRef
func send(name: String,args: Array = []) -> void:
	if connection!=null and connection.get_ref()!=null: connection.get_ref().command(name,args)
func accept_quest(id: String) -> bool: send("accept",[id]); return true
func abandon_quest(id: String) -> bool: send("abandon",[id]); return true
func travel_to(id: String) -> bool: send("travel",[id]); return true
func buy(id: String) -> Variant: send("buy",[id]); return null
func use_item(id: String) -> bool: send("item",[id]); return true
func interact(_choose: bool = false) -> Variant: send("talk"); return "offer"
func track_quest(id: String) -> bool:
	if not super.track_quest(id): return false
	send("track",[id]); return true

func check_instant(_quest: Dictionary) -> void: pass
func update(_dt: float,_intents: Dictionary = {}) -> void: pass
