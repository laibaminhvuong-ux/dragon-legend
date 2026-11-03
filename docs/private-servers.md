# Private co-op sessions

This feature is **owner-hosted**, following the user's revised request. It uses the running game itself; no rented host, extra server executable, service download or 24/7 deployment is required. A room ends for everyone when its owner leaves or closes the game. Its old code stops working.

## Play

1. Create your fighter in solo play, or use an existing slot.
2. On the title screen choose **Server**, then select the fighter slot you want to bring. Level, forms, techniques, equipment, quest progress and appearance are imported. Slots are not reset to level one.
3. The owner chooses **Create server** and shares the displayed **six-digit code**, then chooses **Enter server**. Up to eight players, including the owner, can connect.
4. Friends choose **Join server**, select their own fighter slot and enter the code. On the same LAN/Wi-Fi, leave Host address empty to discover the owner automatically.
5. Internet friends also need the owner's reachable host address, for example `ws://203.0.113.10:8910` (example address only). TCP 8910 must reach the owner's computer through the router and firewall. The optional automatic router setup uses UPnP when supported; it cannot bypass carrier-grade NAT, blocked UPnP or restrictive firewalls. The owner can instead forward TCP 8910 manually or friends can use a trusted VPN. UDP 8911 is LAN discovery only and does not need Internet forwarding.
6. **Esc leaves co-op.** If a friend leaves, the room stays open; if the owner leaves, everyone disconnects and the code expires.

A six-digit invite authenticates a room; without an external directory/relay it cannot globally locate a home computer by itself. There is no public server list. Direct `ws://` connections are not encrypted. Use a trusted VPN or a properly configured `wss://` proxy for secure Internet transport. No external relay/directory is bundled or secretly provisioned.

## Playing across countries (e.g. America ↔ Vietnam)
The six-digit code finds a room on the **same Wi-Fi/LAN** only. Across the Internet the friend must reach the owner's PC directly. Options, easiest first:
1. **A free private-network app such as Tailscale (or ZeroTier)** on both PCs: no router changes, works behind most home and mobile connections. The owner creates the room; the friend types the owner's Tailscale address in **Host address** as `ws://100.x.y.z:8910` (shown in the Tailscale app), plus the code.
2. **Router port forwarding:** forward TCP 8910 on the owner's router to the owner's PC, then the friend uses `ws://<owner's public IP>:8910`. This does not work if the owner's internet provider uses carrier-grade NAT (common on mobile and some home plans).
3. **Automatic router setup (UPnP)** checkbox: tries option 2 automatically; many routers block it.

The first time the owner creates a room, Windows asks whether to allow The Dragon Legend on the network. Choose **Allow** (private networks; also public if your Wi-Fi is marked public). Distance adds delay: expect roughly 0.2–0.3 s between America and Vietnam, so fights feel slightly behind; your own movement is predicted locally and stays smooth.

## Fighter saves

The game backs up the selected slot to `user://co_op_backups/slot_<index>_<timestamp>.json` before connecting. Authoritative progress received from the host is saved back to **that selected slot**, periodically and when leaving. Other fighter slots are not replaced. Local progress imports are intentionally allowed for private friend sessions; this is not a ranked anti-cheat economy.

New friends arrive near the owner on the owner's current map. Their quests and unlocks remain their own. Nearby party members share PvE kill rewards and quest kill credit for matching active objectives. Players are not targets of friendly fire. Quests, items, form changes, travel and stat spending are validated by the host; clients cannot issue direct damage, XP or teleport commands. Online menus do not pause the host's simulation. Enemy/world state exists for this session only; fighter progress survives locally.

## Architecture

- `network/host.gd`: in-process TCP/WebSocket host, LAN discovery responder, optional UPnP mapping and shutdown.
- `network/service.gd`, `room.gd`: invite authentication, capacity/rate limits, input sanitization, imported profiles, party simulation, shared enemies/projectiles and nearby kill credit.
- `network/client.gd`: WebSocket or direct owner transport, LAN discovery, backup/save and disconnect handling.
- `network/game_mirror.gd`, `story_mirror.gd`: route online UI commands to the host rather than awarding progress locally.
- `network/play_session.gd`, `play_root.gd`: server snapshots, local movement prediction, friend presentation, world rebuilds and online UI.
- `ui/server_menu.gd`: Create/Join, slot picker, code and host-address UI; opened from `slot_select.gd`.

The offline play path and save schema remain intact. `RuleCombat.party` and `world_authority` are opt-in; their defaults retain single-player behavior. Only one combat authority advances shared enemy AI/projectiles per map per simulation step. Packet protocol version is currently 1.

## Validation before shipping

Run normal regressions:

```bash
tools/godot_test.sh --check-data
```

Run actual socket integration on a machine that permits local network sockets:

```bash
tools/godot_test.sh coop-sockets
```

That opt-in test performs two real WebSocket handshakes and joins. The normal suite also exercises the owner transport in process, imported max-level fighters, party combat and rewards, disconnects, code invalidation, invalid requests, UI creation and online scene snapshots. Separately test two actual PCs: LAN code discovery, Windows firewall permission, remote address/port forwarding, owner shutdown and recovery of the imported fighter slot. No two-PC Internet test or router mapping should be claimed solely from a headless unit test.

Godot transport reference: [WebSocketPeer](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html). Room discovery and gameplay authority are implemented in this repository, rather than supplied by Godot's transport class.
