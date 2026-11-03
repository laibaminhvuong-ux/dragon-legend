class_name MotionStyle
extends RefCounted
# Presentation profiles only. Never multiply simulation speed or damage with these values.
static func for_form(id: String) -> Dictionary:
	var p := {"weight":1.0,"aggression":0.35,"calm":0.0,"stance":0.0}
	if id in ["UIOmen", "UIPerfected", "UITrue"]:
		p.calm = 1.0; p.aggression = 0.05; p.weight = 0.75
	elif id == "UltraEgo":
		p.aggression = 1.0; p.stance = 0.12
	elif id in ["LegendarySSJ", "SSJGrade3", "Giant", "Oozaru", "GoldenOozaru"]:
		p.weight = 1.7; p.aggression = 0.8; p.stance = 0.16
	elif id in ["SSJ3", "Beast", "SSJRage", "PureMajin"]:
		p.aggression = 0.85; p.stance = 0.08
	elif id in ["SSJGod", "SSJBlue", "SSJFullPower", "PotentialUnleashed"]:
		p.calm = 0.5; p.aggression = 0.2
	return p
# Anticipation, sharp extension and recovery; a new serial can interrupt at any time.
static func strike(age: float,duration: float) -> float:
	var phase := clampf(age / maxf(0.01,duration),0.0,1.0)
	if phase < 0.16:
		return -sin(phase / 0.16 * PI * 0.5) * 0.18
	if phase < 0.38:
		return lerpf(-0.18,1.0,smoothstep(0.16,0.38,phase))
	return 1.0 - smoothstep(0.38,1.0,phase)

# Exact critically damped scalar spring: stable across frame rates and pauses.
static func spring(value: float,velocity: float,target: float,dt: float,frequency: float = 12.0) -> Vector2:
	var omega := maxf(0.01,frequency)
	var offset := value-target
	var temp := (velocity+omega*offset)*maxf(0,dt)
	var decay := exp(-omega*maxf(0,dt))
	return Vector2(target+(offset+temp)*decay,(velocity-omega*temp)*decay)
