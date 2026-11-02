# Server boundaries follow-up — 2026-11-02

Baseline: `stage-1`, `a3ffec7`. Read-only source audit; no Studio, live profiles, map writes or production edits. Checked movement/PvP/mining intents, economical remote inputs, bootstrap order and mine/teleport replication. Storage settlement is covered by the economy/storage audit. The four findings below are specific incorrect-result paths, not a generic rate-limit checklist.

## SB-01 — P1: NaN DropItem count can poison coins and bypass payment funds checks

**Primary:** `src/server/Services/ItemDropService.luau:279,319–333`.

The remote accepts any numeric `count`, without `count == count`/finite validation. For a valid inventory slot containing a droppable sellable block, a NaN count reaches `math.clamp(math.floor(count), 1, stack.count)`. NaN is not repaired by these arithmetic operations. `amount >= current.count` is false, so `current.count -= amount` makes the authoritative stack count NaN. This mutation occurs before the drop instance/attribute creation: a later engine rejection of a NaN drop attribute would not undo it.

The corruption has a concrete economic continuation:

1. Near the seller, `InventoryService.sellAll` (`InventoryService.luau:307–323`) multiplies `stack.count` into the sale total, with no finite check; `EconomyService.luau:129–131` adds that total into `p.coins`. The source profile now has NaN coins.
2. Shop checks such as `profile.coins < units(price) * count` (`EconomyService.luau:164`) return false for NaN; subtraction leaves NaN while granting ordinary finite goods.
3. More seriously, `/pay` validates a finite requested amount but checks the balance only with `profile.coins < sum` (`ChatCommandService.luau:139–151`). With NaN balance that refusal does not run. The sender stays NaN and the receiver gains normal finite currency. Thus corruption is not confined to the malformed sender's save; valid recipient balances can be inflated.

**Trigger:** A connected real profile with a sellable block invokes the malformed DropItem count, sells at the normal NPC, then pays a normal finite amount to another eligible player. No spoofed client-supplied price or direct profile write is needed. Normal proximity, level and recipient settings still apply.

**Consequence:** Invalid item/currency state, free purchases and a route to mint finite currency into other accounts. Save errors on the malformed source profile do not make the transferred value safe.

**Confidence:** High source-level counterexample. IEEE NaN arithmetic/comparison behavior and complete call chain were checked; the malformed remote was not sent to Studio or a live server. Cross-player pickup of the malformed dropped object is *not* required for this finding and is not claimed.

**Fix direction:** Reject non-finite/NaN counts before mutation; enforce positive finite integers at shared inventory mutation boundaries; reject non-finite balances/derived totals before any economic operation and avoid saving corrupted state as normal. Add an isolated regression covering DropItem → sell → pay; do not reproduce on real accounts.

## SB-02 — P1: cosmetic movement snapshots can manufacture grounded critical hits

**Primary:** `src/server/Services/MotionService.luau:74–78,117–127`; `src/server/Services/CombatService.luau:394–429`.

Motion validates finiteness and bounds each reported position within **30 studs** of the server root. It does not bound inter-snapshot vertical velocity against the actual root trajectory or require reports to agree with grounded state. Combat then treats those reports as authority for the *attacker's own* critical eligibility: `observedGrounded` raycasts from `MotionService.rootAt(player)`, and `observedCrit` gets vertical velocity from `MotionService.verticalSpeed(player)`.

**Source counterexample:** A living grounded character is stationary on a flat floor, not sprinting, seated, climbing, swimming, flying, in webs or under forbidden effects. The weapon is fully charged. Two finite increasing Motion reports at actual-root Y+10 and Y+9, separated by 0.03 seconds, are both inside the 30-stud drift allowance; their one-stud separation does not trigger the 20-stud teleport-history clear. Derived vertical speed is −33.3 studs/s. A short downward grounding ray from Y+9 misses the floor. `Attack(..., falling=true, ...)` therefore satisfies `Combat.canCrit(charge, true, false, false)` while the physical character remains grounded. There is no separate requirement that actual FloorMaterial be Air or actual state be Freefall.

**Consequence:** The attacker can repeatedly obtain the **×1.5 base damage** critical multiplier on charged ground attacks. This does not require teleporting/flying the actual character. Range/line-of-sight still use the actual head for contact, so the counterexample is specifically forged critical eligibility, not an assertion of unlimited melee reach.

**Confidence:** High source-level counterexample; packet delivery and a live critical were not exercised. Existing render-history/target rewind functionality is intentional, but using client-adjusted attacker pose as proof of real falling crosses a different authority boundary.

**Fix direction:** Keep lag compensation for the displayed target while obtaining attacker grounding/falling eligibility from a separately validated physical trajectory. Cover stationary-ground forged offsets, honest jump-apex delay, ladders, water, sprint and snapshot loss.

## SB-03 — P2: DigStart can select fully buried cells because LoS excludes the entire mine

**Primary:** `src/server/Services/DigService.luau:110–123`.

`inRange` excludes `{character, part.Parent}` from its ray. `part.Parent` is the mine folder, containing **all** its block Parts. MineService creates/registers those Parts for every populated cell (`MineService.luau:195–218,253–277`), and there is no exposure check in lookup or DigService.check.

**Trigger:** At a legitimate mine and level, submit DigStart for a buried valuable cell within the accepted reach, with a hit point on that cell, while several intact mine blocks lie between the player's eyes and it. The whole mine is excluded, so the ray cannot detect any of the obstructing blocks. The ordinary server timer then grants that selected block. A modified client can choose the replicated buried resource without digging intervening low-value cells.

**Consequence:** Server-authorized mining through intact layers and selective extraction of valuable buried material. Static-world walls still block the ray; this finding concerns mine cells specifically.

**Confidence:** High from the explicit exclusion and complete cell registration. The comment explains that this was introduced to tolerate a predicted previous block under latency, but the implementation exempts every mine block, not just recently confirmed/predicted predecessors. This audit did not mine anything in Studio.

**Fix direction:** Limit latency tolerance to validated recently broken cells or otherwise require the selected cell to be reachable through exposed/cleared mine cells. Preserve normal sequential instant mining under realistic latency.

## SB-04 — P2: new DigStart bypasses the whole timer for one-tick blocks

**Primary:** `src/server/Services/DigService.luau:435–439`.

The previous dig is completed synchronously when elapsed time is `>= needed + pause - TICK`. For ordinary instant mining, Config returns **0.05 seconds** and no pause (`src/shared/Config/init.luau:407–417`), so that comparison is elapsed `>= 0`. A second DigStart can complete the previous block immediately rather than waiting for its server timer. `complete` rechecks target/tool/generation but never checks elapsed time itself (`DigService.luau:289–310`).

**Trigger:** With a legitimately instant-breaking tool/material, send a sequence of valid new DigStart intents sooner than 50ms. The first starts the timer; the next immediately finishes it and starts another. The token bucket is **25/s with a burst of 10** (`DigService.luau:411–423`), so it permits a near-immediate first burst and approximately 25 blocks/s sustained, beyond the documented 20/s instant rate. Old delayed callbacks see a replaced token and do not undo the early completion.

**Consequence:** A modified client can exceed the authoritative normal mining rate and gain blocks/rewards faster; latency grace controls success rather than merely accommodating request ordering.

**Confidence:** High arithmetic/control-flow counterexample, not a measured live throughput claim. A zero-time sequence of ten accepted requests completes the first nine immediately; the last retains its 50ms timer. Real scheduling will spread packets, but the 40ms sustained request interval still passes the zero threshold.

**Fix direction:** Enforce the elapsed break/pause budget inside completion and queue the next valid intent rather than crediting unfinished work early. Preserve generation invalidation and jitter handling.

## Checks that did not yield another strong finding

- Motion rejects NaN/infinite coordinates, yaw and report timestamps; limits incoming report rate, ignores non-increasing timestamps and expires stale history. Requested rewind is clamped to 0.3 seconds and prediction is separately bounded. SB-02 exploits finite accepted samples, not missing numeric validation there.
- Attack requires a living humanoid and normalized finite-sized direction, applies a minimum intent interval, checks range/arc/static obstruction and rechecks character/held stack at contact. Player/gang/faction protection is authoritative. Boss hurt immunity is per contributor. The earlier Tank/Trainer findings are in the combat/world report and are not duplicated here.
- Dig accepts only registered live cells, rejects rebuilding mines, checks level/gang lease/reach/tool/inventory/sleep, stores generation/tool identity, and rechecks at completion. DigFinish is a no-op. These checks prevent direct client amounts and stale generation grants, but do not close SB-03/SB-04.
- Economy prices/exchange output/upgrade requirements are server-defined. Exchange count is bounded; inventory slot/move count guards reject NaN; /pay and /rubb reject non-finite requested amounts. Their reliance on valid existing balances is why SB-01 must be repaired at both the remote input and economic invariant boundaries.
- Bootstrap starts avatar setup before profile/spawn consumers, mine registration before digging, Motion before Combat, and Location before dynamic gang arrivals. MineReplicationService.Start runs inside MineService.Start. No additional deterministic bootstrap failure was found from this read.
- Fast mine removal has no incoming result handler, IDs are not recycled during a server lifetime, batches are bounded, nearby recipients only, and authoritative object replication remains the fallback. Regeneration changes generation and disables digging while rebuilding. No additional stale-ID/removal exploit was found.
- Teleport validates destination and entitlements server-side, channels/cancels on movement/combat/death, rechecks on completion and streams the destination. Missing private-room arrival tags and conditional fall-history carryover are already recorded in the combat/world audit.

## Evidence and limits

Read the existing `network-validation-2026-11-02.json` two-client PASS/PARTIAL evidence and its caveat linking to `network-latency-2026-11-02.json`. Existing normal-path network checks remain valid; neither finite malicious pose offsets nor NaN economic inputs are closed by latency/removal tests. No WAN, load, native-mobile or adversarial live fixture was run here. Safe local arithmetic models checked the NaN comparison chain, accepted-position critical counterexample and instant-timer threshold; these are explicitly source/model evidence, not actual engine tests.
