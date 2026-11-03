# Release preparation: Ghetto, capture and mine lighting

Scope: owner's release request, world/NPC/capture part and mine-lighting part. Source/build-script review and isolated tests only. No Studio, real purchases, keys, passes, profiles, map changes, commits or publishing were used by this agent.

## Current behavior → changes

### Warzone capture

Previously all four configured beacons were simultaneously capturable and independently held. That contradicted the release instruction for one randomly appearing active point per server.

WarzoneService now selects one existing tagged beacon at random on server startup. Only that point accepts capture progress. After its configured hold ends, all previous ownership/scores/benefits are cleared and one random existing beacon starts the next round; selecting the same location again is allowed. A map with no available beacon does not activate a nonexistent objective. Studio debug capture also preserves the single-active-point invariant.

Existing numeric rules remain unchanged: **60 blocks** to capture, **−1 rival score** per block, idle decay after **90 seconds**, and a **30-minute hold** [existing config decisions/wiki]. The four potential locations remain Money/northeast, Blocks/northwest, Mobs/southwest, Haste/southeast [builder coordinates]. Inactive pads can still supply ordinary mine resources, but never capture score or a faction benefit.

The replicated point state includes `Active`. Inactive beams are hidden, capture signs are hidden outside the active/unheld state, inactive cards/boards say so, and the faction count is out of **one** [owner]. Boards and faction cards identify the courtyard direction. Announcements specify the active location, required digging action and bonus; victory states the winning faction, bonus, duration and next random appearance. Haste reconciliation and multiplier reads ignore inactive points.

Touched: `WarzoneService`, Shared `Warzone`, `WarzoneHud`, `FactionWindow`, new `Strings/ReleaseWorld`.

### Ghetto interactions

The source already implements the trader, black market, mason, pass dealer, private-mine gate/exit, treasure event, mobs and private mine leases. They are not reported as missing features. The prior private-arrival/pass-charge and bat fixes remain in the baseline.

Changes:

- Trader rejects invalid/non-integer counts instead of silently purchasing one item.
- NPC purchases respect current `GangHouseService.allowed` ownership, including a BlackMarket tagged inside a gang house.
- Treasure hold is tied to the living current character, current Ghetto/gang eligibility, range and standing position. Walking away, changing character/access or leaving a completed hold stale cancels it. The damage listener survives the brief `HoldEnded`/`Triggered` ordering handoff; a completed hold cannot be replayed later.
- Treasure reward is confirmed before removing the chest; an uncreditable wallet leaves it available. Full-backpack overflow still falls beside the chest and now says so explicitly.
- Mason/gate prompt details state the actual requirements. The mason success message states the multiplier/duration and directs the player to activate the stored booster in the booster menu.

The private-mine success/failed-channel behavior was already covered by the preceding actual-source combat/world fixture and remains unchanged by this release pass.

## NPC and interactable map

| Object / authored location | Source path | Successful result | Refusal / cancellation behavior |
| --- | --- | --- | --- |
| GhettoTrader, kiosk by public arrival | `build-ghetto` → tag `GhettoTrader` → GhettoService prompt → `OpenMenu(ghettoTrader)` → ExchangeWindow → `GhettoBuy(trader, id, count)` | Configured ordinary keys/ancient stars enter inventory; exact dollar price deducted | Invalid count/id, dead/distant player or foreign house cannot purchase; insufficient money/full bag reports error with no deduction |
| BlackMarketDealer, walled market yard; tagged gang-base counterparts | `BlackMarket` → GhettoService → ExchangeWindow → `GhettoBuy(black, id)` | Configured item delivered; personal level-scaled price paid; server stock decremented once | Below level **20** [wiki/config], exhausted stock, full bag, insufficient money, distance or house permission refusal; hourly stock timer is mirrored to UI |
| Mason, near arrival at local x −10/z 142 [builder] | `GhettoMason` → GhettoMineService.act | Stone/cobblestone progress accumulates to **200**; stores blocks **×1.5 for 15 min** [owner/existing decision] | Requires gang/Ghetto upgrade; full booster storage retains completed progress so claiming later does not re-charge stones |
| Pass dealer, near arrival at local x +10/z 142 [builder] | `GhettoPassDealer` → GhettoMineService.act | **64 iron ore → one gang mine pass** [existing decision] | Insufficient ore/full inventory/gang access failure preserves resources |
| Mine gate, local z −142 [builder] | `GhettoMineGate` → enter → LocationService.Request → claim callback | Available room leased for **10 min** after successful channel; pass consumed once; same-gang reentry free [existing decision] | Needs **three online gang members** [existing source/decision], pass and Ghetto upgrade; combat, channel movement/death, missing destination, race loss or changed eligibility do not spend pass |
| Four private-room arrival/exit parts [builder] | `GhettoMineExit`, private `LocationSpawn` → LocationService | Normal exit to public Ghetto; only chosen private arrival permits entry | Public teleport excludes private arrivals; lease/ownership enforcement evicts strangers/expired users; fall history resets on authoritative reposition |
| Treasure chest, one of six authored treasure locations [builder] | `TreasurePoint` → GhettoService spawn/hold/capture → reward | One configured weighted reward and one chest statistic; public winner message | Hold **10 s** [existing config]; current character/range/access/standing/damage validation; stale hold rejected; full bag clearly reports world overflow; wallet-cap refusal preserves chest |
| Rats/zombies/bats | Ghetto MobSpawn tags → MobService | Existing ordinary combat/drop/progression paths | Eight rat anchors, two groups of three zombie anchors, five bat anchors [builder/preceding decision]; this pass does not change mob balance |
| Warzone beacons and ore pads | WarzonePoint/WarzoneBeam + `warzone_<id>` mines → DigService.OnDug → WarzoneService | One active point, faction capture score, winning contribution statistics and configured faction benefit | Inactive/held/unaffiliated digging never starts another capture; normal dig validation still owns block outcomes |

Read-only scenery such as market stalls, cars, decorative court/house doors and treasure markers is not misrepresented as an unimplemented NPC. Prompts are attached to tagged parts, not arbitrary scenery names.

## Mine lighting coverage

All authored mine-anchor builders were searched for anchor construction and PointLight/SurfaceLight/SpotLight sources. Every mine builder has decorative lighting, but that does not establish underground floor coverage: many lamps sit above a rim, path or roof. For example Basement's decorative helper caps range at **24 studs** and brightness at **0.65**, while normal progression grids are **128×48×128 studs** [source/config]. Quarry uses several decorative ranges/intensities but its mine is **160×64×160 studs** [source/config]. Ghetto private rooms have ceiling lamps but also extend down below the surface. No claim about current cloud brightness is made from source alone.

Coverage groups reviewed:

- Prison main/small, Quarry, Basement stone/ore, faction mini-mines, Ghetto private rooms and four Warzone pads.
- All progression builders: Mountain Foot, Underworld, Pyramid, Royal Garden, Sunken Lighthouse, End Castle, Spider Lair, Snowy Hand, Market, Leprechaun Valley, Castle, Inside Out, Kyoto, Farm, Barn, Edge Gate, Tree, Church, Purgatory, Eden, Cherubim, Gate and Paradise.
- Gang-base authored scenery itself contains no independent MineAnchor; dynamic/tagged anchors inherit the shared registration path.

New Shared `MineLighting.Apply(anchor, sizeBlocks)` places low-intensity, shadowless fill lights inside the whole mining volume. It uses attachments only, preserving collision/query geometry and decorative lamps. World-axis placement matches MineService even if an anchor is rotated. The grid is idempotent and updates/removes only its own named attachments when dimensions change.

Parameters: **64-stud spacing, 60-stud range, brightness 0.4, warm-neutral RGB 235/231/218** [decision]. A normal progression grid gets **four** lights; Quarry **nine**; small private/Warzone grids **one** [geometry]. The deepest floor and corner probes of representative current dimensions are within range [fixture]. The helper has a bounded grid, not one light per block. It deliberately adds no bloom/neon geometry and does not raise global exposure.

`scripts/patch-mine-lighting.luau` applies this narrowly to existing tagged anchors in Edit mode. The parent must call `require(Shared.MineLighting).Apply(anchor, size)` in MineService.register after determining dimensions, so runtime/dynamic mines receive the same coverage without rebuilding every map.

## Integration requested from parent

1. Append `script.ReleaseWorld` to Strings' parts list (same format, all four locales provided).
2. Add the MineService registration hook above and sync the new shared helper.
3. Run the targeted mine-lighting patch in the existing cloud map, then restart Play through the established workflow.
4. No numeric config changes are required. Update only stale decision metadata if desired: `warzone._perServer` should describe one randomly selected available/held point at startup; `warzone._holdMinutes` should describe the existing hold followed by one random next location. This agent did not edit design-decisions or generated configs.

## Verification

`scripts/qa-release-world-offline.luau`: **43 passing checks** [actual-source fixture result]. Loads real Warzone/shared state, Ghetto service, Ghetto mine NPC handlers, InventoryService and lighting helper. Verifies all random selections, single-active invariant, inactive score refusal, ownership/stat/bonus transfer, hold expiry and Haste revocation; trader totals/malformed counts, black-market eligibility/ownership, treasure hold identity/range/movement/expiry/reward replay, mason partial progress/reward, pass exchange; bounded/idempotent soft lighting and rotated-anchor corner/deep-floor coverage. Service/physics/network boundaries are mocked; lighting uses isolated Lune Instances.

The existing combat/world fixture passes **44 checks** [fixture result], with its handcrafted Warzone point updated to `active=true`. Its HurtService mock additionally supports the parent's new Impulse API.

Changed production files pass Selene with zero errors/warnings/parse errors [tool result]. Parent owns global build/type/runtime checks. A fixture pass does not establish native prompt event ordering under latency, physical navigation, mobile legibility or actual brightness; those remain live scenarios below.

## Exact live scenarios for parent

Use isolated fixtures/test profiles for purchases/consumables; do not spend the owner's real inventory merely to demonstrate an interaction.

1. Start Play with all authored beacons present. Inspect replicated `Active`: exactly one true, one visible beam. Faction window shows held count out of one and inactive cards; the announcement names courtyard, capture action and reward.
2. On an isolated faction profile, dig active pad to the configured threshold. Check progress/rival contest, winner statistics, correct faction multiplier/Haste and one owner. Dig an inactive pad and a held pad: neither gains capture score.
3. In Studio-only debug, expire the held point. Verify the old benefit disappears and exactly one random next point activates. Exercise all four selections and a repeated same-location selection. Check Haste after respawn/faction leave using the existing fixture workflow.
4. At each NPC in the table, verify prompt text, intended window/result and failure messages. Use disposable inventory to test trader totals, exhausted black stock, full bag, mason partial/full-storage claim, pass full-bag refusal, private-mine cancelled/successful/free-reentry/expired paths.
5. Treasure: start, move, take damage, release, die/respawn, lose gang access and attempt delayed completion. None should preserve an invalid hold. A valid stationary hold grants one reward, with correct overflow feedback and no second claim.
6. Apply lighting patch twice: counts stay stable and existing decor remains. Visit Prison main/small, Quarry deepest floor, both Basement mines, a private gang mine, a faction mini-mine, Warzone, and representative bright/dark late locations (e.g. Underworld, Snowy Hand, Paradise). Inspect ore faces, avatar/held-item detail and glare at top/center/floor on desktop and native phone graphics. If necessary tune only the shared low-intensity fill; do not brighten every global scene.
