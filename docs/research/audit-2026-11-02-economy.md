# Economy, progression and inventory audit — 2026-11-02

Baseline: `stage-1`, `a3ffec7`. Audit only; no production edits, Studio operations, real-profile fixtures, commits or publishing. Read `CLAUDE.md`, the recent `PROGRESS.md` journal and relevant `GAME-DESIGN.md` sections. The latest owner rule takes precedence: 100 actually removed cells at ×2 means 100 clean, 200 orange and 200 in the applicable upgrade counter; copied drops are not cells. The old Plastolom half-layer/200 cap is not a requirement.

## Result

Four actionable P2 defects are supported directly by the current code. None requires guessing a balance value. The strongest current-change interaction is the missing achievement event after book AoE: the new shared counters are correct, but their consumers are not all updated.

### E1 — P2: Book AoE permanently omits some block achievements and delays others

- **Locations:** `src/server/Services/BookService.luau:736–744`; `src/server/Services/DigService.luau:384,398`; `src/server/Services/AchievementService.luau:40–64`; `src/shared/Achievements.luau:60–65`.
- **Trigger:** Start with `p.dug.coal_block = 31`, no claimed coal-block tier, then trigger Hammer/Plastolom on an adjacent stone cell so that the extra cells include a coal block. The first achievement threshold is 32. Alternatively, cross an upgrade-counter card's threshold entirely through extra cells and stop mining.
- **Actual:** BookService gives drops and calls `MiningStats.credit` for extra cells, but never calls the achievement service or increments `p.dug`. DigService calls `AchievementService.OnDug` only for the initial block, **before** the AoE. Coal-block progress remains 31 and its first reward is permanently missed for that cell. For a counter-backed card, the displayed counter grows but the milestone is not awarded until a later manual dig of that card's block. Worse, if the card has no claimed entry yet and the player rejoins first, `ProfileService.luau:306–311` treats its newly satisfied tiers as migration history and marks them claimed without payment. There is no login/periodic reward catch-up.
- **Expected:** Every actual extra cell contributes to its achievement, and a crossed milestone is evaluated after the batch has been credited. This does not require changing orange/clean arithmetic or restoring an old AoE cap.
- **Evidence:** The generated achievement catalog contains **45 cards without an upgrade counter**; they read only `p.dug`, including `coal_block`, `red_sand`, `lapis_block`, `iron_block`, `gold_block`, and `diamond_block`. The initial block's path is the only mining caller of `AchievementService.OnDug`.
- **Confidence:** High, static call-path/data proof. The particular fixture above was not executed in Studio. A fix should process a batch by actual block type, preserve one initial-cell credit, and avoid generating one profile replication/toast per cell unnecessarily.

### E2 — P2: A full booster store permanently consumes achievement rewards

- **Locations:** `src/shared/Boosters.luau:187–202`; `src/server/Services/AchievementService.luau:56–64,99–107`. Capacity is `src/shared/Config/boosters.json:11` (200).
- **Trigger:** Have 200 stored boosters and a sand achievement at tier 3; cross the tier-4 threshold of 256. The same issue applies to stat milestones, including daily reward milestones, when their reward is a booster.
- **Actual:** `Boosters.store` silently returns without storing when capacity would be exceeded. Both achievement grant loops then advance `p.achievements`, append the reward notice, and announce success. Freeing storage later cannot recover it because the tier is already claimed. Thus ordinary gameplay destroys an earned reward without an error or recovery record.
- **Expected:** Either retain the unclaimed reward for retry, put it in guaranteed-reward overflow, or confirm successful delivery before advancing the claimed tier. Purchase capacity checks alone cannot cover automatically awarded achievements.
- **Evidence:** Tier 4 is configured as a block booster. The store function has no success return contract, and both achievement callers unconditionally record the tier after calling it. DailyService checks space for the day's direct booster, but its later `AchievementService.OnStat("dailyClaims")` does not protect the separate milestone reward.
- **Confidence:** High, static deterministic branch proof. No capacity fixture was applied to a real profile.

### E3 — P2: Silk Touch multiplies whole-melon drops by the slice quantity

- **Locations:** `src/server/Services/DigService.luau:320–325`; duplicated in `src/server/Services/BookService.luau:722–731`; configuration `src/shared/Config/blocks.json:63–76`.
- **Trigger:** Equip an axe with Silk Touch, with no gang luck or Trader proc, and break one melon. Silk Touch is valid on axes in the current book catalog, so this needs no invalid tool or exploit remote. Hammer + Silk Touch can also encounter the same resolver.
- **Actual:** The code changes the item ID from `melon_slice` to `melon`, then still rolls the original `[3,7]` `dropCount`. One real melon therefore grants 3–7 whole sellable melons. At the configured $1.40 base price, it pays **$4.20–$9.80** instead of $1.40, before multipliers. Normal slices are explicitly unsellable.
- **Expected:** Silk Touch's base reward is one original block. Apply legitimate extra-item perks separately. The normal 3–7 slice rule should run only when actually dropping slices.
- **Evidence:** Config-driven local Node arithmetic verified the item IDs, quantity range, price and `melon_slice.sellable = false`; both source branches use the range regardless of Silk Touch. `MiningStats` correctly counts one cell despite this inflated inventory payout, so the recent stat fix does not catch it.
- **Confidence:** High. Arithmetic/config verification ran locally; server RNG/drop execution remains a pending isolated fixture.

### E4 — P2: Selling still ignores the owner's ×5 final money cap

- **Locations:** `src/server/Services/ProfessionService.luau:40–43`; `src/shared/Boosters.luau:145–153`; display duplicate `src/client/SellWindow.luau:29–34`. Owner requirement: `docs/GAME-DESIGN.md:95`.
- **Trigger:** Money profession upgrade 50, with legitimate local, faction and global ×2 money boosters simultaneously active. Each scope has its own queue, so they can overlap.
- **Actual:** Boosters combine additively as `1 + 1 + 1 + 1 = 4`; the profession factor is 1.5, giving **×6**, already 20% above the accepted ×5 cap. Gang/warzone bonuses can increase it further. There is no final clamp in `ProfessionService.moneyMultiplier`, `InventoryService.sellAll`, or `InventoryService.autoSell`. Both normal and book auto-sell use this helper.
- **Expected:** Apply the agreed cap to the final selling multiplier and show the same capped value in the buyer UI.
- **Evidence:** A local Node calculation using the generated `professions.json` and `donate.json` produced ×6. The design doc explicitly identifies the cap as an owner decision and says to introduce it with boosters; boosters are now implemented.
- **Confidence:** High, code plus explicit owner requirement and config arithmetic.

## Verified scope and non-findings

| System | What was checked | Limits / result |
| --- | --- | --- |
| Mining totals and upgrades | Shared `MiningStats`, ordinary dig, Hammer and Plastolom call paths, combo propagation, clean count, type counters, precision | Current 100/200 rule is present; no old layer half/200 cap found. E1 is a downstream consumer omission. Prior journal reports 19 Studio checks; this audit did not repeat or promote them to full acceptance. |
| Level/item progression | Server level and per-item upgrade gates, `requirementHave`, generated level/tool/block configs, profession and skill point calculations, trainer gates | Local data audit: 124 upgrade transitions, no unknown requirement-counter names; 49 level records (2–50), 25 earned skill points. No broken `dropsAs` target or book item target. This validates references, not game balance or every purchased upgrade. |
| Professions / skills / trainer | XP thresholds, spending, derived free points, oblivion reset, potion brewer requirements | Server and JobsWindow use the same XP formula. Money cap is E4. Later trainer costs remain existing design decisions. |
| Books | Item compatibility, duplicate/conflict limits, powder/dispeller, ancient roll III eligibility, delivery staging, mining procs | E1 and E3. Combat book interactions are covered by the combat reviewer, not declared passed here. Tank armor swap healing candidate sent to that reviewer. |
| Inventory / storage / cases | Stack/partial move/quick transfer, armor swap, ender sections, AncientCase staging/overflow, case session checks, money-bag claim | No new deterministic dupe found in the synchronous personal inventory path. Cross-profile/shared-storage durability belongs to the persistence/multiplayer audit. Artifact persistence needs clarification below. |
| Selling / shops / exchanges | Prices and server intents, proximity, partial purchase refund, block locks, shared auto-sell resolver | E3/E4. Full inventory exchanges that would free an input slot are conservatively refused because `canAdd` runs before removing input; possible UX improvement, not item loss. |
| Achievements / artifact mosaic | Counter and non-counter cards, tier payouts, stat milestones, duplicate fragment conversion and assembly | E1/E2. Chance/per-cell semantics beyond achievements need explicit review below. |
| Daily / canteen / referrals | Day boundary and streak logic, direct reward capacity checks, referral idempotent friend record and profile dedupe, newcomer gate, stash overflow | No additional confirmed defect identified. Referral delivery and datastore outage/retry acceptance remain untested here. Daily milestone boosters inherit E2. |
| Boosters / purchases / rewards | Queue scopes, item-to-store conversion, capacity, crystal/ruby payment, receipt grant/save/dedupe path, stash fallback | E2/E4. Generated config has **5 pack** and **24 item** nonzero Developer Product IDs. Receipt correctness under actual retries/crashes cannot be established by this static audit. |
| Potions | Server recipe validation, modifier limits, cooldown/charge, non-stackable metadata, use/recharge | No confirmed economy mutation bug identified. Splash hit rules and real client/physics behavior are outside this economy acceptance. |

## Behavior requiring a decision or targeted acceptance, not promoted to confirmed defects

1. **Other mining events bypassed by AoE.** The extra cells do not earn mason/surveyor XP, advance gang `dig` quests, grow combo, roll ordinary keys/artifacts, or roll gang conversion/luck. Those events run only for the initial cell (`DigService.luau:345–385`), whereas `BookService.luau:711–750` updates drops/stats/sales. XP config says `blocks_by_pickaxe` / `blocks_by_shovel`; this is a strong integration gap to resolve. Some chance-per-action exclusions may be intentional balancing, so the audit does not silently define all of them as per-cell. The latest owner count rule by itself does not specify every independent reward proc.
2. **Achievement multiplier consistency.** Counter-backed cards now inherit multiplied upgrade counters, while non-counter cards add exactly one through `p.dug`. Decide whether every achievement is meant to use real cells or multiplied credit; E1 is a bug under either choice.
3. **Artifact-case persistence contradiction.** `GAME-DESIGN.md:227` says its reward stays until taken, and `CaseService.luau:523` calls it a persistent grid. In fact `emptyCase` at 166–170 clears `artifactCase`, and `ProfileService.luau:131–135` restores only ancient overflow. The owner explicitly requested temporary ordinary cases and persistent ancient overflow; confirm whether artifact cases are also temporary. If persistence is intended, closing/walking away/rejoining currently destroys the paid reward, and reopening also requires a new key. This observed behavior is certain; applicability of the persistence requirement is not.
4. **Money combo description.** `GAME-DESIGN.md:99` still says combo affects money. Current selling/auto-sell helpers do not use combo, only block credit does. Unlike the explicit ×5 owner rule, this line is an older design decision in a section with other superseded parameters. Resolve the intended rule before implementing a new multiplier.
5. **Mixed-material/full-bag Hammer.** Initial-cell validation checks room for one initial drop, but extra drops call `InventoryService.add` without retaining overflow (`BookService.luau:719`). Test/decide desired behavior when secondary materials do not fit. Plastolom's `sellOnly` behavior is explicit and was not misreported as a missing inventory reward.

## Real pending tests

No live result below is claimed. All can use throwaway fixture profiles; none requires modifying the owner's saved profile.

1. **Achievement integration:** Mixed stone/coal-block Hammer and full-layer fixtures; start non-counter progress at 31 and counter progress just below a threshold. Verify exact per-type progress, immediate tier grant, no double credit of the initial cell, and idempotence on an empty repeat. Repeat with ×2/combo and auto-sell enabled/disabled.
2. **Guaranteed reward capacity:** At storage 199/200, cross one and several booster milestones, plus dailyClaims 29→30 and 99→100. Verify actual stored/pending rewards and claimed markers, then free space/rejoin and recover any deferred reward exactly once.
3. **Silk Touch reward resolution:** One melon with a Silk Touch axe, ordinary axe, and Hammer + Silk Touch; no extra-item perks, then separate gang luck/Trader variants. Verify item ID, quantity, money, clean/orange counters independently.
4. **Money cap:** Real local/faction/global queues with money upgrade 50, then gang/warzone bonuses. Compare buyer display, manual sale, ordinary auto-sell and book auto-sell; all must agree with the chosen final cap and rounding.
5. **Progression purchases:** Throwaway profiles at level-2/3 and late armor armorer-III/V gates; exact-money and exact fractional-counter boundaries; verify that upgrading only the selected instance preserves its books and never consumes cumulative counters.
6. **Storage/case round trips:** Full bag with last key vs stacked keys, full ancient overflow, claim after walking away/rejoin, manual and quick moves, selected vault section. Resolve artifact persistence first, then test the accepted rule.
7. **Purchases/shared rewards:** Isolated datastore/memory-store fault injection or approved staging: grant followed by failed save, repeat receipt, concurrent receipt callbacks, crash between booster reservation/global write/profile cleanup, referral inviter offline then reconnect. Existing static journaling intent does not prove these failure paths.
8. **Native input:** Real-phone case/inventory gestures, book targeting, potion recipe and recharge controls, purchase confirmation and full-bag recovery. Desktop/fixture success does not establish phone acceptance.

## Local checks actually run

- Confirmed baseline with `git rev-parse --short HEAD` → `a3ffec7`.
- Read-only `rg` call-path searches and focused source/config inspection.
- Node scripts read generated JSON and calculated the money cap counterexample and Silk Touch payout range; enumerated the 45 non-counter achievement cards.
- Node reference audit found zero unknown upgrade counters, zero missing block-drop definitions and zero book target items absent from the tool catalog; counted 124 upgrade transitions and 25 skill points. The first version of that check was corrected to ignore catalog metadata entries without an `items` array, then completed successfully.
- No Luau/Lune executable was available on the active PATH. No tooling was installed. Node arithmetic/data checks are explicitly **not** production Luau execution or Roblox acceptance tests.
