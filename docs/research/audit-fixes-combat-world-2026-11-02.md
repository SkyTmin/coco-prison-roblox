# Combat and world audit fixes — 2026-11-02

Scope: CW-01 through CW-06, the conditional teleport/fall finding CW-07, and grounded-critical spoof SB-02. Changes are source and targeted map-patch artifacts. This agent did not access Studio, change a live map/profile, publish or commit. Parent coordinates the cloud sync, generated configs and repository-wide checks.

## Resulting behavior

| Finding | Change | Evidence |
| --- | --- | --- |
| CW-01 private gang mines | Every private Arrival receives `LocationSpawn` and `PrivateArrival`; public LocationService and void rescue routing exclude private arrivals. `LocationService.Request` accepts a trusted server completion callback. A pass and lease are committed only after the channel, destination and gang checks pass. Owner reentry stays free; another gang winning the room, lost membership/minimum online members, missing pass, invalid arrival, cancellation or an expired free-entry lease cannot charge the player. | Actual LocationService/GhettoMineService fixture: successful arrival, movement cancellation, same-gang reentry, public routing, concurrent foreign claim, missing tag, reduced online membership, expired free reentry. |
| CW-02 Trainer | Strength multiplies primary melee and arrow damage before outgoing books; Java secondary sweep retains its fixed damage. Agility rolls on incoming player/mob/boss strikes before the hurt-immunity window is consumed. Fire ticks are explicitly non-dodgeable. Existing configured rates are unchanged. | Actual CombatService/TrainerService fixture checks melee and arrow damage, sweep, dodge threshold, landed hit following dodge, and non-dodgeable burning. |
| CW-03 Tank healing | Capacity changes preserve current HP and clamp on capacity loss. Fresh characters still begin full; the existing explicit EconomyService level-up heal remains responsible for level-up healing. | Executes the actual bootstrap capacity block: repeated Tank swaps at low health create no healing, fresh spawn remains full, removal clamps health. |
| CW-04 Warzone Haste | The point owns a separate Haste source. Warzone reconciles current faction and current character on faction changes, respawn and ticks. NeedsService combines it with personal/event Haste and removes only the point source when entitlement ends. | Actual NeedsService/WarzoneService reconciliation checks member grant, replacement character, stronger potion, faction leave, potion expiry, rejoin and point expiry. |
| CW-05 Flame | Each Flame tick checks current FireResistance, including resistance acquired after the arrow hit. Initial arrow impact behavior is unchanged. | Actual BowService burn loop: resistant victim, resistance expiry and resistance acquired during burning. Book fire already checked FireResistance; no BookService change was needed for this finding. |
| CW-06 Ghetto bats | Shared idempotent GhettoLayout helper adds five bat spawn anchors with eight-stud wander radius [decision], reused by the full builder and a small cloud patch. Adds Ghetto to bat config metadata through design-decisions. | Actual helper on isolated Lune Instances: four private rooms repaired, five spawns created, repeat creates none, inferred raised-map origin matches explicit builder origin [fixture results]. |
| CW-07 teleport/fall | Explicit `FallService.Reset(player)` immediately before authoritative reposition clears only the old trajectory. Tracks are scoped to the current character. Integrated in Location/GangHouse/Faction/GhettoMine/Lava paths; parent/economy agent integrated Profile restore and Mine evacuation/rescue. | Actual FallService: high-to-low teleport causes no inherited fall damage; a real ten-block fall after reset still deals seven HP [vanilla/fixture]. |
| SB-02 grounded crit spoof | Attacker critical grounding and falling velocity come from the physical root, while target render-history reconciliation remains intact. Accepted cosmetic Motion offsets cannot make a physically grounded attacker critical-hit. | Actual MotionService accepts the finite forged descending reports; actual CombatService rejects their grounded critical, retains a real falling critical and rejects an ascending critical. |

No generic fall grace period or distance threshold was added: a real fall from a teleport destination is still tracked. No network ownership or general movement anti-cheat claim is made by the critical fix.

## Changed files

- Combat/health: `src/server/Services/CombatService.luau`, `TrainerService.luau`, `BowService.luau`, `src/server/init.server.luau`.
- Effects: `src/server/Services/NeedsService.luau`, `WarzoneService.luau`.
- Routing/fall: `src/server/Services/LocationService.luau`, `GhettoMineService.luau`, `FallService.luau`, `FactionService.luau`, `GangHouseService.luau`, `LavaService.luau`.
- Map/config: `src/shared/GhettoLayout.luau`, `scripts/build-ghetto.luau`, `scripts/patch-ghetto-audit.luau`, `scripts/design-decisions.json` (only `mobs.bat.locations` in this agent's changes).
- Fixture: `scripts/qa-combat-world-offline.luau`.

ProfileService/MineService edits are owned by the parent/economy agent and are not attributed to this agent. No MotionService production change was required. Generated `src/shared/Config/mobs.json` must come from the parent's final `node scripts/build-configs.mjs` run.

## Validation and deployment

`lune run scripts/qa-combat-world-offline.luau` passes **44 checks** [fixture result]. The fixture loads actual production modules and the actual bootstrap health block with mocked Roblox services, time, RNG, profiles, raycasts and characters. It exposes private functions only in the test loader; production source has no fixture hooks. GhettoLayout uses real isolated Lune Instances; its Position alias is translated to equivalent CFrame.Position for Lune compatibility.

All changed production Luau files pass Selene with **zero errors, warnings or parse errors** [tool result]. Changed Luau was formatted with StyLua; `git diff --check` is clean. Full Rojo/build/config checks belong to the parent's consolidated validation.

Cloud application: sync the changed source, including Shared.GhettoLayout, then run `scripts/patch-ghetto-audit.luau` in Edit mode against the existing Ghetto. It repairs only arrival tags/attributes and adds missing named bat spawn anchors; it does not rebuild scenery. Expected first run on the audited map: four arrivals and five new bat spawns; repeat: four arrivals and zero new spawns [fixture/decision]. Restart Play through the normal parent workflow so services bind the updated map.

These isolated fixtures do not establish native Roblox physics/network timing, on-map bat navigation, real group boss balance, native-phone behavior or server load. Those acceptance checks remain separate from the source fixes and require the corresponding live scenarios.
