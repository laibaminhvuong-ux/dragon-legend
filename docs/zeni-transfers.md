# Sending zeni in private co-op

Any connected player can send zeni to any other connected player in the same room, including guest-to-guest, guest-to-owner and owner-to-guest. Players may be on different maps. The host validates and executes every request; the sender is never required to be the server owner. No real-world payments, fees or new currency are involved.

## Menu/API contract for Claude

```gdscript
var peers: Array = game.zeni_recipients() # [{id: String, name: String}], excludes self
var error: Variant = game.give_zeni(selected_player_id, amount)
if error is String:
    # Show refusal using the menu's normal toast/error handling.
    pass
```

Solo RuleGame returns `Join a server to send zeni` and an empty recipient list, without changing the fighter. Online CoopGameMirror checks connectivity and the numeric amount, then sends `command("give_zeni", [target_player_id, amount])`. Null means the request was **queued**, not that it has settled. The existing connection.failed signal reports host refusals. The mirror never predicts/debits/credits a local balance.

Use the selected **player id**, not a name or list index. Names need not be unique; a recipient can disconnect while the menu is open. Refresh the list when showing/updating the menu and handle the host's refusal if the selection becomes stale. Parse amount input to a numeric whole value before calling; formatted text such as `"5,000"` is not a valid API amount. No confirmation dialog is required by these rules.

`CoopRoom.player_list()` and new snapshot `players` contain all connected room members as `{id,name}`, including members on other maps or in menus. Mirror.zeni_recipients filters snapshot.self. Existing `friends` remain limited to the current map for avatar rendering; do not use them as the transfer roster. Roster data contains names/ids, not other players' balances or connection tokens.

## Validation and limits

| Rule | Value/behavior |
|---|---|
| Amount | Whole numeric value, at least 1 |
| Numeric JSON form | 5 and 5.0 accepted; 5.5, booleans, strings, null, containers, NaN/infinity rejected |
| Per-transfer maximum | 1,000,000,000 zeni |
| Supported wallet range | Whole balance from 0 through 1,000,000,000,000 inclusive |
| Funds | Amount cannot exceed sender's current host-side balance |
| Recipient | Another currently connected member of the sender's room |
| Refused recipients | Self, unknown/disconnected player, player from another room |
| Receiver capacity | Reject before addition if the credit would exceed the wallet maximum |
| Rate | One successful transfer per simulated room second per sender |

Both existing balances are validated; invalid/unsupported balances are refused, never silently repaired or clamped by a transfer. Amount and balance limits keep arithmetic exactly representable in JSON numbers and well inside Godot integer overflow limits. Invalid attempts do not consume the successful-transfer cooldown. Receiving does not consume that player's own send cooldown; another guest may send immediately. The normal per-connection packet limiter still applies to repeated invalid requests. There is no owner-only check, map/distance requirement, level/race requirement or combat lock.

## Atomic host commit and receipts

RuleZeniTransfer.plan is a pure validation/staging function. CoopRoom then prepares saved copies of both fighter slots, commits debit/credit to both live game slots and both saved room slots, increments each participant's zeniRevision and the sender's cooldown, then emits notifications/stats. No yield or event callback occurs between the two wallet writes. Rejection leaves both wallets, saved slots, revisions and successful-send cooldown unchanged. A third-party observer never sees an event after just one wallet has changed.

The currency sum is conserved. Transfer updates preserve the remaining fighter progress and slot data. No additional save schema version is needed: currency remains `slot.zeni`; roster, receipts, cooldowns and revisions are ephemeral room/session state.

Sender notification: `Sent 5,000 zeni to <name>`.

Receiver notification: `<name> sent you 5,000 zeni`.

Both participants receive the same private event:

```json
{
  "name": "zeniTransfer",
  "data": {
    "transfer_id": "123456:1",
    "from_id": "friend:sender",
    "to_id": "friend:receiver",
    "from_name": "Bình",
    "to_name": "Chi",
    "amount": 5000
  }
}
```

`Events.emit_named("zeniTransfer", receipt)` maps to `Events.zeni_transfer(receipt)`. CoopPlaySession forwards the event. The from_id/to_id values deliberately remain the stable server roster ids even on the local sender's screen; compare against connection.latest.self when identifying self. They are not converted to the scene alias `player`. Unrelated room members receive neither the receipt nor these notifications. Notifications/receipts take queue priority over older presentation events; queues remain bounded at 96 entries.

## Saving and failure handling

New snapshot `zeniRevision` belongs to the receiving snapshot's own fighter and advances whenever that fighter sends or receives. Both the owner-local transport and remote WebSocket transport use CoopClient.accept_snapshot. When its revision advances, the client writes its selected slot through the existing atomic SaveStore file writer immediately, before frame delivery; it does not wait for the five-second autosave. Ordinary autosave/exit saves remain. Receipt events are not required to trigger saving, so a presentation queue cannot suppress the wallet write.

A failed local save reports an error through client.failed once, keeps the revision dirty and retries on following snapshots. It does not report the failed disk write as acknowledged or roll back the already committed host pair. Repeated successfully saved revisions do not cause extra immediate writes. Slot backups/imports and existing player progression remain under the original co-op behavior.

The two **host-side wallets/saved room slots** commit atomically. Two players' independent disks and network links are not a distributed transaction: a process crash, failed disk or connection loss before delivery can leave a client with its last received/saved progress. The private owner-hosted room is still ephemeral and closes when the owner leaves; no durable central ledger or reconnect reconciliation was added. Existing private-friend offline fighter imports remain supported. These limits must not be described as bank-style crash-proof persistence or ranked anti-cheat.

## Verification

```sh
tools/godot_test.sh --check-data
# Focused rule/room/client/disk/event checks:
tools/godot_test.sh zeni
# Real WebSocket peers, from an unrestricted terminal:
tools/godot_test.sh zeni-sockets
```

Default tests cover amount/balance boundaries, malformed values, insufficient funds, sender-role independence, self/unknown/disconnected/cross-room recipients, cross-map roster/transfers, unchanged failure state, rate limits, receiver capacity, commit observation, privacy, JSON replication, queue priority, exact/no-prediction mirror calls, typed scene event forwarding, immediate writes to both selected slots with disk reload, failed-write retries, revision deduplication and owner-local send/receive persistence. Test fixtures use temporary profile/backup paths and restore the user's SaveStore path.

The opt-in socket test authenticates two real WebSocket peers and has the **second guest** send to the first; it asserts both snapshots' balances/revisions and receipts. In Codex's restricted environment this attempt was denied at TCPServer.listen (ERR_CANT_CREATE), so it is not a network pass. Claude should run it unrestricted, then wire the Send zeni menu and review actual multi-player behavior before shipping. The existing unrelated co-op socket proof does not by itself certify this new command.

Codex owns the rules/network/API/persistence/tests. Claude owns menu/UI integration and builds/publishing. No build or publication by Codex.

Validation recorded 2026-11-04: native Godot 4.7.2 `tools/godot_test.sh --check-data` **308 passed, 0 failed**, exit 0; 41 generated tables verified (`/tmp/dragon-zeni-full-suite.log`). Focused zeni checks: **17 passed, 0 failed** (`/tmp/dragon-zeni-final-targeted.log`). The failed-local-write fixture intentionally prints SaveStore warnings; existing post-suite focus/resource shutdown diagnostics remain outside the cases. The separate real-socket attempt failed before connection because the sandbox denied TCPServer.listen: **0 passed, 1 failed**, ERR_CANT_CREATE (`/tmp/dragon-zeni-sockets-attempt.log`). This is an unverified transport gate, not a network pass. `git diff --check` passed. Claude's concurrent character/appearance changes were preserved.
