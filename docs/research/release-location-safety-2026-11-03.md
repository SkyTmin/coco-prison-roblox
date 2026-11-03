# Location edges and server recovery — 2026-11-03

Owner request: players must not fall off a location; invisible boundaries are allowed. No Studio mutation, publication, real-profile/resource mutation or commits were performed by this agent. Initial implementation was offline; after parent found malformed cloud extents, a specifically authorized read-only Edit inspection covered MountainFoot and Pyramid only.

## Existing behavior and concrete gaps

All 30 configured location ids and their actual builder root names were checked. Twenty-three builders already construct invisible `EdgeWall` parts; sixteen also construct `VoidCatch` parts. The other seven depend on visible scenery/shells alone. Existing walls typically extend only to local Y−50, so a character escaping below that height can pass underneath them. The old void handler checks current overlap with a thin net; a sufficiently large replicated movement can skip the net entirely.

The old `LavaService` rescue chooses the first global `LocationSpawn` matching a location id and does not check faction, exact containing region, character replacement or a competing teleport after its streaming wait. That is unsuitable for private copies and faction arrivals. Its old four-HP void penalty could also kill a player because of a scenery escape.

| Config id | Builder | Existing invisible edges | Existing void net |
| --- | --- | --- | --- |
| prison | build-prison | no | no |
| quarry | build-quarry | no | no |
| mountain_foot | build-mountain-foot | yes | no |
| underworld | build-underworld | no | no |
| pyramid | build-pyramid | yes | no |
| royal_garden | build-royal-garden | yes | no |
| sunken_lighthouse | build-sunken-lighthouse | yes | no |
| end_castle | build-end-castle | yes | yes |
| spider_lair | build-spider-lair | no | no |
| snowy_hand | build-snowy-hand | yes | no |
| market | build-market | yes | yes |
| leprechaun_valley | build-leprechaun-valley | yes | yes |
| castle | build-castle | yes | yes |
| inside_out | build-inside-out | yes | yes |
| kyoto | build-kyoto | yes | yes |
| farm | build-farm | yes | yes |
| barn | build-barn | yes | yes |
| edge_gate | build-edge-gate | yes | yes |
| tree | build-tree | yes | yes |
| church | build-church | yes | yes |
| purgatory | build-purgatory | yes | yes |
| eden | build-eden | yes | yes |
| cherubim | build-cherubim | yes | yes |
| gate | build-gate | yes | yes |
| paradise | build-paradise | yes | yes |
| basement | build-basement | no | no |
| fraction_base | build-fraction-base | no | no |
| gang_base | build-gang-base | no; closed house shell | no |
| ghetto | build-ghetto | yes | no |
| warzone | build-warzone | yes | no |

Builder paths are `scripts/<builder>.luau`. Later composite builders retain their source fragments in `scripts/locations/<id>`. No generated config or design decision was edited.

## Changes

`src/shared/LocationBounds.luau` measures the current map, rather than copying builder coordinates. Rotation-aware world extents include anchored collidable scenery and the complete configured mine volume, including empty or rebuilding mines whose live ore is parented elsewhere. NPC rigs, non-colliding lighting/effect volumes, old void nets and previously generated safety walls cannot inflate the measurement. Existing edge walls contribute their horizontal extent so Terrain-water areas remain accessible; their arbitrary vertical dimensions do not become the legal floor/ceiling.

Four thin, transparent, collidable exterior walls are installed under each region's `LocationSafety` model. Their inner faces are outside the measured footprint. They are non-queryable, do not cast shadows and add no horizontal floor or ceiling. Wall depth extends below the lowest legal geometry; the server recovery plane is twelve studs below that geometry, with sixty-four studs of upper collision clearance [decision]. These are clearances, not invented map coordinates. Reapplying updates the same four parts and ignores them during measurement.

The public Ghetto excludes `GangMineRooms`; each of its four rooms is measured separately. This prevents an ordinary fall from the district being accepted merely because paid private rooms exist three hundred studs lower. The prison's detached Showcase is also separate, preserving its teleport spot and preventing a giant envelope across the empty gap. The gang-house template is supported by the Edit patch, and `GangHouseService.ensure` registers every newly created private clone after tagging it. Existing copies are discovered at server startup too.

`WorldSafetyService` checks authoritative character positions. A position below the recovery plane or outside the exterior bounds is detected even if a wall/net was crossed between frames. It observes a valid new destination before evaluating the old region, so ordinary location teleports do not bounce back. A newly spawned character physically at the prison is not moved to a stale distant profile location. An existing net delegates to this service and cannot redirect a player into an unrelated location below them.

Recovery selects an existing arrival inside the exact region: own-faction spawn, own gang's exact clone, or the same private room with a still-valid gang lease. It never picks a global first or nearest spawn. Private arrivals are excluded from public Ghetto recovery. No pass is spent or purchased. When no authorized target exists, safety does not invent a destination; the existing membership/lease eviction flows remain responsible for revocation.

Streaming is bounded to three seconds. During that wait the root is temporarily anchored to prevent further falling. After the wait, recovery rechecks the character, health, location, position, target, region and access rights. A competing teleport, respawn, removed house or expired lease cancels the old recovery. The previous anchored state is restored. Successful rescue cancels a pending travel channel, resets fall history immediately before moving and clears both linear and angular velocity. Scenery rescue does not remove health or combat attribution. Real lava/fire damage and genuine falls within legal map bounds retain their existing behavior.

Narrow integration edits: `init.server.luau`, `GangHouseService`, `LocationService.CancelForRecovery`, and the void-only branch of `LavaService`. No movement/PvP, profile persistence, mine reset or NPC interaction implementation was changed.

## Validation

`scripts/qa-location-safety-offline.luau`: **230 PASS**, actual shared/server modules with synthetic isolated engine geometry and mock players. The suite checks all thirty config ids against real builder root identities, rotation-aware bounds, full legal mine depth, four private rooms, detached Showcase, water-edge preservation, idempotence, excluded NPC/volume/net geometry, every public location's fast-fall recovery, private clone creation, faction/house/lease routing, horizontal tunneling, ordinary jumps and deep shafts, valid teleports, foreign-net rejection, initial stale profile location, and streaming error/teleport/respawn/death/target-removal/access-revocation races. Fourteen additional assertions reproduce the exact malformed legacy walls below, their narrow correction, idempotence, intact distant scenery and refusal to guess changed/unrelated layouts.

Existing suites: combat/world **52 PASS**, release-world **43 PASS**. These remain mock/actual-source checks, not live physics acceptance. Targeted Selene (zero errors/warnings), StyLua, whitespace and Rojo build pass. The Rojo artifact is only a local source validation build in Temp, not a replacement for the cloud map. Synthetic fixture coordinates are explicitly not evidence of actual cloud map dimensions.

`scripts/patch-location-safety.luau` is an Edit-only idempotent map patch. It returns JSON with each actual measured root, min/max extent, recovery Y and contributing solid count, plus missing configured ids. With the complete map and template, expected coverage is 35 static regions: 30 locations including the gang template, four private Ghetto rooms and Showcase. Runtime public coverage is 34 regions plus one for each existing/new gang clone.

### Parent cloud check: two malformed legacy wall pairs

Parent applied the first patch in Edit and observed 35 regions with no missing ids, but the MountainFoot/Pyramid bounds extended approximately 150,000 studs in negative Z. A specifically authorized read-only inspection in cloud Studio `87811915-5710-4d94-a805-ebec948f17a8` (place `92594200898716`) identified exactly these outliers:

| Existing path | Position | Size |
| --- | --- | --- |
| MountainFoot.Edge.EdgeWall | (2116, 1650, −150142) | (4, 500, 584) |
| MountainFoot.Edge.EdgeWall | (2684, 1650, −150142) | (4, 500, 584) |
| Pyramid.Edge.EdgeWall | (4082, 4650, −159159) | (4, 500, 636) |
| Pyramid.Edge.EdgeWall | (4718, 4650, −159159) | (4, 500, 636) |

Those same malformed literals existed in `build-mountain-foot.luau` and `build-pyramid.luau`. Their intact north/south walls place the side-wall centre at `(284 + −300)/2 = −8` and `(318 + −318)/2 = 0`, respectively. The two builder literals are corrected. `LocationBounds.RepairLegacyEdges` repairs only these named roots' exact four-wall `Edge` groups, after checking transparent anchored collision parts, axis alignment, matching heights, perpendicular spans/widths, and the pair's common misplaced Z. It changes only the two bad side-wall Z coordinates and refuses an unfamiliar/asymmetric layout. Repeated application repairs zero more parts.

The real MountainFoot backdrop has anchored mountain rock/snow down to Z−948; this scenery remains included. Expected corrected conservative bounds are MountainFoot `(2052,1448,−948)` to `(2748,1872,286)` and Pyramid `(4080,4448,−320)` to `(4720,4686,320)`, based on actual inspected solids and the intact wall extents. No general size clamp or whole-map rebuild is used.

The Edit patch now requires a short-lived sibling clone of the current LocationBounds ModuleScript and destroys that clone after loading. This avoids Studio Edit's stale `require` cache after source syncs. Returned per-region `repairedEdges` distinguishes actual correction from a no-op rerun. Parent applied the updated patch, saved the cloud Edit place and reopened it, confirming the same place and persisted correction: 35 regions, no missing ids, two repaired walls in each affected region, MountainFoot minimum Z−948 and Pyramid minimum Z−320 as expected. Parent also reported 33 roots and no active lease. This verifies live geometry and persistence only; native edge collision and fallback fall scenarios below remain separate acceptance work. This agent performed no live writes.

## Live verification for root

Prepared bounded STS probe (not executed by this agent): `scripts/qa-release-safety-server.luau`, `scripts/qa-release-safety-client.luau`, and `scripts/make-release-safety-qa.mjs`. Generate the Edit installer with `node scripts/make-release-safety-qa.mjs`; `--cleanup` removes its two scripts. After complete scene recovery, require `qa-release-full-map-preflight.luau` to pass and run one simulated client using `ExecuteMultiplayerTestAsync(1, "release-safety-v1")` with the entire map retained. The old `qa-release-scene-session.luau` lease is disabled after the interrupted-save defect; do not detach scenery or mark it non-Archivable. Full-map testing uses more RAM; use a separate verified QA file if necessary. Parent owns Studio operation.

The 120-second deadline is installed before module loading. Client ACK requires `LoadingBlocked == false`, `RuntimeReady`, a live character and `ClientDebug`; there is no readiness bypass. The server refuses real/nonnegative accounts and requires the existing per-run `TestSessionScope`. Expected successful output has 17 checks: startup proof, four actual collidable exterior-wall ray queries per location (using RespectCanCollide), below-floor fast-fall recovery to that root's own tagged spawn, HP preservation without ForceField, and anchored observation at the actual deepest/mid mine ladder positions. Location/mine/ladder/floor coordinates come from retained geometry and actual anchor sizes. No cells are dug, no map parts are manufactured and no private recovery hook is invoked; the normal WorldSafetyService heartbeat must return the unanchored server-owned falling character. Profile/body/Creative/ForceField snapshots are restored at completion or deadline.

The probe always reports `physicalInput=false`. Queries validate collision configuration, and injected poses validate server fallback/false-rescue behavior; they do not prove native walking contact or ladder climbing. Offline preparation checks: both scripts and the generated installer compile, both scripts no-op outside Studio or under unrelated STS arguments (**7 checks PASS**), Selene reports no errors/warnings, and formatting is checked. The existing 230-case actual-source safety suite remains the broader offline coverage; these compile/gate checks are not reported as live acceptance.

1. Sync `LocationBounds`, `WorldSafetyService`, the four narrow hooks and `LavaService`; in Edit run the patch twice. Save returned measured bounds. Require no missing ids and unchanged guard counts on the second run. Do not rebuild scenery.
2. Inspect the four outside faces and recovery plane in each of the thirty locations. The geometry is read at application time; moving a whole map and rerunning must move its guard too. Check underwater edges in Sunken Lighthouse/Snowy Hand, Market's dock and crypt, Basement's deepest mine, Underworld lava paths and the End Castle/Edge Gate bridges.
3. In disposable QA characters, cross each edge normally and simulate a single-frame move beyond/below it. Normal collision should stop the edge exit; a skipped wall/net should return to the same region with health preserved. Keep test character/profile destinations synchronized; raw QA teleports without profile changes are not normal travel.
4. Walk and jump on mine rims; descend all mine ladders to the deepest bedrock and enter Market's crypt. No safety floor, ceiling or false rescue may obstruct these legal routes. Normal significant falls landing inside the map must still cause ordinary fall damage.
5. Verify a faction member returns to their faction arrival. For gang houses, create two disposable clones without spending real resources; fall from each as its owner and ensure no other gang's spawn is selected. Test a Ghetto private-room recovery only with an existing/isolated valid lease; do not buy a pass for this test.
6. During the streaming wait, respawn or teleport to another location; the old recovery must not move the new character/destination. Exercise lease/membership revocation and removal of a clone. Check anchored state is restored in success and cancellation.
7. Record native client physics/streaming and server startup cost separately. No such live checks were performed by this agent. The walls are conservative outer envelopes, not a new walkable surface across legitimate gaps between islands; falling through an internal void is handled by same-region recovery.
