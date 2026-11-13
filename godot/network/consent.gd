class_name CoopConsent
extends RefCounted
## Co-op join consent (user rule 2026-11-13: the game never takes data from a player's machine without consent).
## A remote join sends CoopCodec.join_message (the chosen fighter only) to the host after the player accepts.
## "Don't ask again" is stored per server in the player's own settings (Settings "coopTrusted"); nothing else is kept.

## LAN discovery has no address until a host answers, so its key is the room code.
static func server_key(url: String,code: String) -> String:
	var u := url.strip_edges().to_lower()
	return u if u!="" else "lan:"+code.strip_edges()

static func remembered(key: String) -> bool:
	var trusted: Variant = Settings.get_value("coopTrusted")
	return trusted is Dictionary and bool(trusted.get(key,false))

static func remember(key: String) -> void:
	var trusted: Variant = Settings.get_value("coopTrusted")
	var next: Dictionary = trusted.duplicate() if trusted is Dictionary else {}
	next[key] = true
	Settings.set_value("coopTrusted",next)

static func forget_all() -> void:
	Settings.set_value("coopTrusted",{})

## Exactly what the dialog tells the player is sent, and to whom.
static func summary(url: String,nickname: String) -> String:
	var to := "the host at "+url.strip_edges() if url.strip_edges()!="" else "the host that answers with this code on your local network"
	return ("Joining sends this to %s, and to no one else:\n" % to
		+"• your name \"%s\"\n" % nickname.left(24)
		+"• the chosen fighter only: look (race, appearance, fighting style), level, XP, stats, forms, moves, outfits, form mastery, quest and story progress, items, Hero Cards and zeni\n"
		+"• a random one-time session key (it identifies you in this room only)\n\n"
		+"Nothing else: no files, no other fighter slots, no settings, no play time or dates, no computer or account details. "
		+"The host runs the room and sends your fighter's progress back to you; it is saved into this slot when you leave.")
