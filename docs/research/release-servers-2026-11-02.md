# Release: common server bosses, durable reward locks, server affinity

Implementation completed 2026-11-03 for the owner's 2026-11-02 release request. No Studio, publish, real invitations, production profiles, or live MemoryStore writes were used by this agent. Parent owns live integration and platform capacity.

## Before → after

| Area | Previous behavior | Implemented behavior |
| --- | --- | --- |
| Boss ownership | `BossState`/`BossState_Studio` was one last-writer-wins HP/damage/timer record per boss across servers. | Each public server owns its common arena bosses and its own respawn timers. No reserved/solo boss server is created. The local rig-recovery snapshot remains, but all shared boss-state reads/writes are removed. Old MemoryStore records are ignored. |
| Repeat reward | A player could receive the same boss reward on another server. | `bossRewardUntil[bossId] = killedAt + card.respawnSeconds`, in the player's durable profile. The fractional Unix timestamp is the same value used for the boss's `RespawnAt`. There is no separate reward duration and no six-hour boss cooldown. |
| Locked helpers | Their damage could reduce everybody else's reward fraction. | Damage by locked helpers and players absent from the location is excluded from the eligible reward denominator. Helpers can still fight. They receive zero items/money/boss-stat increment, and do not advance boss-kill gang quests. The existing minimum eligible damage fraction remains. |
| Last hit | The actual final hitter exclusively controlled the bonus. | If the final hitter is locked/absent, the highest-damage eligible contributor receives the last-hit money/loot bonus; equal damage uses the lower UserId. |
| Persistence | Boss rewards became spendable through ordinary `Mutate`. | Immutable reward plans are queued, journaled with `SaveNow`, then grant + cooldown + receipt + queue removal are confirmed together through `MutateDurable` before live delivery. Different bosses and delayed cycles cannot overwrite one pending slot. |
| Return routing | Normal matchmaking could place a returner elsewhere. | A server-side six-hour assignment prefers the previous public JobId when its presence is fresh and it has room. The initial `assignedAt`/`untilAt` survive rejoins, friend overrides, and fallback changes. |
| Friends/invites | No affinity override contract. | Engine `FollowUserId` overrides old affinity. Native invite launch data can carry an opaque server-issued ticket; only a matching server-side record supplies the destination. UI agent connected the existing native prompt to this remote. |

Sources for the behavior changes are the owner's release instruction and follow-up clarifications. Numeric engineering choices below are implementation decisions, not recovered wiki values.

## Files and integration

- `src/server/Services/BossService.luau`: server-local lifecycle; takes the kill snapshot, computes plans, starts `BossRewardService`; chat remains damage/share/money only.
- `BossRewardPolicy.luau`: eligibility, shares, queue, idempotent grant/receipt, inventory overflow to stash, pending-death routing.
- `BossRewardService.luau`: preparatory journal, durable grant, retries on profile load and every three seconds; no RNG reroll during retry.
- `DeathService.luau`: a death during a pending boss checkpoint retains the pending award ids belonging to that death. Later awards and later respawn inventory do not join the old death. Settlement waits for boss and shared-storage transfers to finish.
- `ServerAffinityService.luau`: assignments/presence/invite tickets, routing, bounded fallback, native invite remote. Bootstrap is connected by parent in `init.server.luau`.
- `src/shared/Strings/ReleaseServers.luau`: four locales; connected by parent in Strings.
- UI agent added `bossRewardPending` to `Profile.CanExport` and progress-reset refusal; existing reset whitelist preserves reward clocks/receipts. Parent owns the corresponding shared-storage busy/pending integration.

No generated config, wiki balance data, or design-decisions file was changed by this work. All nineteen existing respawn durations are consumed directly from the boss cards. Existing HP, attacks, loot ranges, book bonuses, and spawn locations remain authoritative.

## Persistence boundaries and explicit limits

1. **Before first acknowledged journal:** plans exist only in server memory/live profile. A crash before any successful save can lose this unconfirmed kill's reward. Nothing has been granted or externally exported, so this does not duplicate a reward. Once the queue is saved, another server can recover it.
2. **Applied write, lost acknowledgement:** live rewards remain unavailable and the pending queue keeps exports blocked. Retrying the same immutable plan in the same session or loading the saved profile after a rejoin gives one grant. A successful saved receipt prevents replay. The queue is chronological; only the settled id is removed, so a second award arriving while a write yields remains queued.
3. **Wallet limit:** an amount that does not fit is retained in the pending queue, with its loot and original deadline intact. It is neither truncated nor discarded. Settlement resumes when ordinary spending makes room. Overflow items go to stash as before.
4. **Death during a write:** pending loot belongs to the death that captured that award id. The existing escrow is durably consumed before world loot/killer-money output. A crash after consumption can lose ephemeral output; that deliberate at-most-once boundary avoids replay duplication. New post-respawn loot and later unrelated awards are separate.
5. **Feedback/secondary progress:** initial chat reports only payouts confirmed during the immediate settlement attempt. A later recovery uses the private reward toast rather than revising an old chat line. Gang quest progress is sent only for initially confirmed eligible recipients; it is not a cross-store outbox and is not replayed after a crash/recovery. Thus a failed initial settlement can miss this secondary quest credit even though the player's money/items recover. This is an explicit remaining consistency limit.
6. **Infrastructure:** tests mock persistence, including staged/live transforms and failures on either side of a write. They do not validate Roblox backend quotas or crash behavior of the existing profile lease implementation. Normal unrelated gameplay mutations retain their existing persistence semantics.

## Affinity contract and platform evidence

`ServerAffinity_v1` holds each user's assignment. `ServerPresence_v1` publishes public-server occupancy every twenty seconds with a sixty-second TTL. An opaque invite ticket lasts one hour, and issuing tickets is limited to once per five seconds per player [implementation decisions]. Assignment validity is the stored initial expiry, even when the MemoryStore key TTL is renewed.

A normal join reads its assignment; fresh/not-full target presence permits **one** redirect attempt after a successful profile checkpoint. Closed, stale, full, throwing, or `TeleportInitFailed` paths leave the player on the current public server and preserve the original window's expiry. No retry loop, reserved-server creation, or kick is used. A MemoryStore outage degrades to the current server. A failed first presence heartbeat does not disable subsequent heartbeats or new join handling. Studio/private servers skip affinity routing.

Roblox documents server-side `TeleportAsync`, public target `TeleportOptions.ServerInstanceId`, and `TeleportInitFailed` after a request has begun. Teleport integration must be tested in the Roblox client; Studio cannot exercise it. Secure currency/inventory data belongs in persistent stores, not teleport payloads. The implementation sends no economic data through teleport options. [Roblox teleport guide](https://create.roblox.com/docs/projects/teleport)

`Player.FollowUserId` is read-only and not replicated. Launch data is accessible through `GetJoinData` and can originate in public URLs, so raw client text does not select a JobId here. The service resolves only opaque tokens in its own server-side invite map; unrelated or forged launch/teleport data cannot override an assignment. [Player API](https://create.roblox.com/docs/reference/engine/classes/Player)

Roblox's native invite prompt supports `ExperienceInviteOptions.LaunchData` and selection of friends. The UI agent uses that native flow; tests never opened or sent an invitation. Expired/unresolvable tickets fall back to ordinary assignment behavior unless the engine's friend-follow signal independently supplies an override. [Invite prompt guide](https://create.roblox.com/docs/production/promotion/invite-prompts)

## Verification

Lune executable: `C:/Users/user/AppData/Local/Temp/coco-case-warzone-qa/lune.exe`.

| Check | Result | What it establishes |
| --- | --- | --- |
| `scripts/qa-release-servers-offline.luau` | **61 PASS** | Actual reward policy/service and extracted unchanged production reward function; all nineteen real boss cards have exact respawn deadlines; eligible split/locked final hitter/chat/quest behavior; journal and uncertain-write faults; same-session/rejoin replay; simultaneous/delayed queues; wallet and stash boundaries; death during write. Actual affinity module with mocked engine/store/teleport: six-hour initial expiry, one redirect, follow override, opaque invite, forged data, full/closed/stale/throw/init-failure, save failure, outage, Studio skip. |
| `scripts/qa-death-storage-offline.luau` | **22 PASS** | Actual death service plus boss policy: pending death, item ownership across two deaths, durable consume faults/rejoin, killer/refund behavior, resolved boss loot exported once. |
| `scripts/qa-combat-world-offline.luau` | **44 PASS** | Existing combat/world regression, including new HurtService impulse mock. |
| `scripts/qa-release-world-offline.luau` | **43 PASS** | Existing release world/capture/NPC/mining lighting regression. |
| Selene changed production; StyLua changed source/fixtures; `git diff --check` | **PASS** | No changed-source lint/parse/format/whitespace failures. Parent runs aggregate build/suite integration. |

## Exact live acceptance scenarios still required

1. Use two **public Roblox servers** of the same published place. Damage the same boss differently: verify HP/damage/respawn in the second server never changes from the first. No resource-spending or production reward test was run by this agent.
2. On controlled accounts, kill boss A with eligible players; record kill Unix, configured respawn seconds, and profile deadline. Move one rewarded player to the other server, help kill A before the deadline, and verify zero repeat rewards without dilution of eligible teammates. Let the helper land the last hit and verify the eligible top hitter's bonus. Kill B and verify its independent eligibility. Repeat A at the exact deadline boundary.
3. Rejoin within the initial six-hour window while the assigned server remains alive/open: one redirect lands in that JobId. Repeat near the deadline without extending it. Stop/fill the target and confirm one bounded fallback; deliberately trigger a last-moment teleport failure and confirm no loop/kick.
4. Join an actual friend's server, then use the native invite flow with a second account: explicit friend/invite joining overrides old affinity. Also test expired invite tickets and full inviter server fallback. Sending real invitations remains an owner-operated acceptance step.
5. Test Creative reset on an account with a reward clock: reset keeps the clock and receipt; reset/export is refused while a reward is pending. Confirm the merged shared-storage busy state follows both storage and boss pending work.
6. Group balance for late bosses, native-phone controls/rendering, server load/quotas, platform MaxPlayers, and full live teleport acceptance are not established by these fixtures.
