class_name RuleInterior
extends RefCounted
# Interior maps of big buildings (user request, 2026-11-04): each is a small zone ("interior_<style>") holding one
# room centred on the origin, entered from a building's door with the interact key and left through its exit door.
# Sizes in metres; the exit door is on the +z wall, the player arrives just inside it facing into the room.

const STYLES := {
	"home": {"name": "House", "w": 14.0, "d": 12.0, "h": 4.2},
	"tower": {"name": "Tower Lobby", "w": 24.0, "d": 22.0, "h": 7.0},
	"lab": {"name": "Laboratory", "w": 28.0, "d": 22.0, "h": 6.5},
	"temple": {"name": "Temple Hall", "w": 20.0, "d": 26.0, "h": 10.0},
	"hangar": {"name": "Hangar", "w": 34.0, "d": 28.0, "h": 13.0},
}

static func style_of(zone_id: String) -> String:
	return zone_id.trim_prefix("interior_")

static func dims(style: String) -> Dictionary:
	return STYLES.get(style, STYLES.home)

## Furniture that blocks movement: [{"kind", "x", "z", "w", "d", "h"}] (room-local; the view draws the same list).
static func furniture(style: String) -> Array:
	var d := dims(style)
	var w: float = d.w; var dd: float = d.d
	match style:
		"home": return [{"kind": "table", "x": 0.0, "z": -1.0, "w": 2.4, "d": 1.4, "h": 0.8}, {"kind": "bed", "x": -w * 0.5 + 1.6, "z": -dd * 0.5 + 1.8, "w": 2.2, "d": 3.0, "h": 0.6},
			{"kind": "shelf", "x": w * 0.5 - 0.6, "z": -2.0, "w": 0.8, "d": 3.0, "h": 2.2}, {"kind": "stove", "x": w * 0.5 - 1.0, "z": -dd * 0.5 + 1.0, "w": 1.6, "d": 1.2, "h": 1.0}]
		"tower": return [{"kind": "desk", "x": 0.0, "z": -3.0, "w": 6.0, "d": 1.6, "h": 1.1}, {"kind": "pillar", "x": -6.0, "z": 0.0, "w": 1.4, "d": 1.4, "h": 7.0},
			{"kind": "pillar", "x": 6.0, "z": 0.0, "w": 1.4, "d": 1.4, "h": 7.0}, {"kind": "lift", "x": 0.0, "z": -dd * 0.5 + 1.2, "w": 3.6, "d": 2.0, "h": 4.0},
			{"kind": "plant", "x": -9.0, "z": 7.0, "w": 1.2, "d": 1.2, "h": 1.8}, {"kind": "plant", "x": 9.0, "z": 7.0, "w": 1.2, "d": 1.2, "h": 1.8}]
		"lab": return [{"kind": "console", "x": -8.0, "z": -7.0, "w": 6.0, "d": 1.4, "h": 1.2}, {"kind": "console", "x": 8.0, "z": -7.0, "w": 6.0, "d": 1.4, "h": 1.2},
			{"kind": "pod", "x": 0.0, "z": -7.5, "w": 2.6, "d": 2.6, "h": 3.4}, {"kind": "bench", "x": -6.0, "z": 2.0, "w": 5.0, "d": 1.6, "h": 1.0},
			{"kind": "bench", "x": 6.0, "z": 2.0, "w": 5.0, "d": 1.6, "h": 1.0}]
		"temple": return [{"kind": "altar", "x": 0.0, "z": -dd * 0.5 + 3.0, "w": 4.0, "d": 2.0, "h": 1.4}, {"kind": "pillar", "x": -6.0, "z": -5.0, "w": 1.6, "d": 1.6, "h": 10.0},
			{"kind": "pillar", "x": 6.0, "z": -5.0, "w": 1.6, "d": 1.6, "h": 10.0}, {"kind": "pillar", "x": -6.0, "z": 4.0, "w": 1.6, "d": 1.6, "h": 10.0},
			{"kind": "pillar", "x": 6.0, "z": 4.0, "w": 1.6, "d": 1.6, "h": 10.0}]
		"hangar": return [{"kind": "ship", "x": 0.0, "z": -3.0, "w": 12.0, "d": 12.0, "h": 6.0}, {"kind": "crates", "x": -13.0, "z": -10.0, "w": 4.0, "d": 4.0, "h": 3.0},
			{"kind": "crates", "x": 13.0, "z": 6.0, "w": 4.0, "d": 3.0, "h": 2.4}, {"kind": "console", "x": 12.0, "z": -11.0, "w": 5.0, "d": 1.4, "h": 1.2}]
	return []

## Collision boxes (world = room-local + origin) for the walls (doorway gap in the +z wall) and furniture.
static func walls(style: String, ox := 0.0, oz := 0.0) -> Array:
	var d := dims(style)
	var hw: float = float(d.w) * 0.5; var hd: float = float(d.d) * 0.5; var h: float = d.h
	var t := 0.5
	var B := func(x: float, z: float, bw: float, bd: float, bh: float) -> Dictionary:
		return {"x": ox + x, "z": oz + z, "rot": 0.0, "hw": bw, "hd": bd, "height": bh, "radius": sqrt(bw * bw + bd * bd)}
	var out: Array = [B.call(0.0, -hd - t, hw + t, t, h), B.call(-hw - t, 0.0, t, hd + t, h), B.call(hw + t, 0.0, t, hd + t, h),
		B.call(0.0, hd + t, hw + t, t, h)]   # closed room: the exit is the door you interact with
	for f: Dictionary in furniture(style):
		out.append(B.call(float(f.x), float(f.z), float(f.w) * 0.5, float(f.d) * 0.5, float(f.h)))
	return out

## The exit door (inside, on the +z wall) and where you arrive.
static func exit_door(style: String) -> Dictionary:
	var d := dims(style)
	return {"x": 0.0, "z": float(d.d) * 0.5 - 0.6}

static func arrival(style: String) -> Dictionary:
	var d := dims(style)
	return {"x": 0.0, "z": float(d.d) * 0.5 - 2.6, "yaw": PI}
