class_name RuleHeroCards
extends RefCounted
static func normalize(slot: Dictionary) -> void:
	if not slot.get("rift") is Dictionary: slot.rift={}
	var r: Dictionary=slot.rift
	if not r.get("results") is Dictionary: r.results={}
	var missions: Array=RuleTables.table("rift_missions").missions
	for id: Variant in r.results.keys():
		if not id is String or not missions.any(func(m: Dictionary)->bool:return m.id==id) or not r.results[id] is Dictionary:
			r.results.erase(id);continue
		var row: Dictionary=r.results[id]
		row.stars=clampi(int(row.get("stars",0)) if RuleSchema._number(row.get("stars")) else 0,0,3)
		row.clears=maxi(0,int(row.get("clears",0)) if RuleSchema._number(row.get("clears")) else 0)
	var owned: Array=[]
	var cards: Dictionary=RuleTables.table("hero_cards")
	if r.get("cards") is Array:
		for id: Variant in r.cards:
			if id is String and cards.has(id) and id not in owned: owned.append(id)
	r.cards=owned
	var equipped: Array=["","",""]
	if r.get("equipped") is Array:
		for i: int in mini(3,r.equipped.size()):
			var id: Variant=r.equipped[i]
			if id is String and id in owned and id not in equipped: equipped[i]=id
	r.equipped=equipped
	if not r.get("pending") is String or not missions.any(func(m: Dictionary)->bool:return m.id==r.pending): r.erase("pending")
static func bonus(slot: Dictionary,key: String) -> float:
	var total:=0.0
	var seen: Array=[]
	var cards: Dictionary=RuleTables.table("hero_cards")
	for id: Variant in slot.get("rift",{}).get("equipped",[]):
		if id is String and cards.has(id) and id in slot.rift.get("cards",[]) and id not in seen:
			total+=float(cards[id].effect.get(key,0));seen.append(id)
	return minf(total,.09)
static func catalogue(slot: Dictionary) -> Array:
	var out: Array=[]
	for c: Dictionary in RuleTables.table("hero_cards").values():
		out.append(c.merged({"owned":c.id in slot.rift.cards,"equipped":slot.rift.equipped.find(c.id)},true))
	return out
static func equip(slot: Dictionary,id: String,index: Variant) -> Variant:
	if not RuleSchema._number(index) or float(index)!=floor(float(index)) or index<0 or index>2: return "Choose card slot 1, 2 or 3."
	if id!="" and id not in slot.rift.cards: return "You do not own that Hero Card."
	if id!="" and id in slot.rift.equipped and slot.rift.equipped[int(index)]!=id: return "That card is already equipped."
	slot.rift.equipped[int(index)]=id
	return null
