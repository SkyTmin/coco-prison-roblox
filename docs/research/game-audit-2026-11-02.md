# Whole-game omission audit — 2026-11-02

Baseline: `stage-1` at `a3ffec7`. Requested by the owner after the mining-counter changes; three parallel reviewers covered economy, combat/world and UI/mobile. The parent coordinated persistence/network follow-ups, independently checked the strongest findings and investigated the owner's settings report in the confirmed Katorga Studio place (`92594200898716`).

This is a broad source/integration audit, **not a claim that every feature passed a live playthrough**. Findings below remain open unless explicitly marked fixed. Existing boss, network and mining QA evidence is retained with its original limits.

## Fix first

| Priority | Problem / player impact | Evidence and next action |
| --- | --- | --- |
| P1 | Invalid numeric item-drop input can corrupt stack/money arithmetic and bypass affordability checks. | [Server boundaries](audit-2026-11-02-server-boundaries.md). Reject non-finite numbers before mutation; defend inventory/currency invariants and test transfers to another fixture profile. |
| P1 | Cosmetic movement snapshots can manufacture falling critical hits while the character is grounded. | [Server boundaries](audit-2026-11-02-server-boundaries.md). Constrain authoritative critical eligibility independently of arbitrary reported offsets, preserving legitimate latency compensation. |
| P1 | A failed faction-storage read exposes empty writable chests and can erase saved contents. | [S1](audit-2026-11-02-storage.md). **Reproduced with actual Luau source and mock-only storage**: one failed read followed by one write removed the prior stack. Fail closed; allow safe retry. |
| P1 | Inventory/shared-chest saves are independent; a crash can duplicate or lose a transfer. | [S2](audit-2026-11-02-storage.md). Introduce a durable, idempotent transfer protocol and fault-inject both save orders. Merely saving more often does not make the operation atomic. |
| P1 | Expired gang-chest holders can overwrite a newer holder's data. | [S3](audit-2026-11-02-storage.md). Fence writes by lease ownership/version and prevent stale save/release. |
| P1 | An old profile session can overwrite a newer session after the newer owner releases its lock. | [S4](audit-2026-11-02-storage.md). Require the exact acquired ownership token/version on every write, including release. |
| P1 | Trainer Strength/Agility charge resources but do not affect combat. | [CW-02](audit-2026-11-02-combat-world.md). Wire the purchased effects into all intended attack/defense paths before interpreting boss balance. |
| P1 | Repeatedly equipping/removing Tank armor grants free healing. | [CW-03](audit-2026-11-02-combat-world.md). Separate maximum-health changes from healing; test armor swaps, respawn and legitimate level-up health. |
| P1 | Gang-mine entry consumes a pass but its arrival fails teleport validation. | [CW-01](audit-2026-11-02-combat-world.md). All four live private arrivals lack `LocationSpawn`; repair private destination validation without making them public teleport targets, and define cancellation/refund behavior. |

The last four persistence findings are distinct failure modes. Faction storage's already documented single-server design and shared boss-state ownership are additional deployment limitations, not evidence that those systems are absent.

## Next corrections

| Area | Confirmed omissions | Detailed report |
| --- | --- | --- |
| Mining/economy | Book area mining skips achievement events; full booster storage silently consumes earned milestone rewards; Silk Touch gives 3–7 whole melons; the final selling multiplier exceeds the owner's ×5 cap. | [Economy: E1–E4](audit-2026-11-02-economy.md) |
| Combat/world | Warzone Haste fails across respawn/faction changes; bow Flame ignores Fire Resistance; requested Ghetto bats are absent from the authored map. | [Combat/world: CW-04–CW-06](audit-2026-11-02-combat-world.md) |
| UI/mobile | Third-person bow crosshair is overwritten; HUD editing leaves mining/combat active; an effects callback assumes a non-nil character; gang chest paging retargets a selected stack; auction scales portrait-phone text to about 7 pixels. | [UI: UI-01–UI-05](audit-2026-11-02-ui-mobile.md) |
| Mining boundaries | Check the source-supported hidden-cell line-of-sight and early-completion timing findings before changing the fast mining path. | [Server boundaries](audit-2026-11-02-server-boundaries.md) |

The current clean/orange/type-counter rule itself is implemented: 100 real cells at ×2 yields 100 clean, 200 orange and 200 applicable upgrade progress. The audit caught **downstream consumers** that still miss book-area events. Do not revert those counters to the earlier bonus-only interpretation.

## Settings investigation and targeted change

The owner reported that the brightness percentage changed while the picture did not. In the running client, the normal `SetSetting` path applied `PlayerBrightness.Brightness = -0.15/+0.15` at 50/150%. A fixed-camera comparison of the same Courtyards scene, with the settings menu open, showed a clear rendered difference. The original symptom was therefore **not reproduced as a permanently ignored brightness value** in this session.

There was a real responsiveness gap: the displayed percentage changed immediately, but brightness and sensitivity waited for a server profile round trip. The targeted correction applies these three personal preferences locally as soon as their controls change, retains pending values across older profile updates, and reconciles with the server. Server validation and persistence remain authoritative. Rendering coefficients and engine mouse scaling are unchanged.

The Studio mouse automation tool changed pointer positions but emitted only zero `InputChanged.Delta` values. It cannot establish physical mouse sensitivity or camera rotation ratios. Do not call that a passed physical-input test. Native mouse and phone gesture acceptance remain required. Low-quality post-effect behavior is a separate compatibility question; it was not identified as the cause of this user's observation.

## Coverage, evidence and outstanding acceptance

- Reviewed progression, mining, books, rewards, inventory/cases/storage, purchases, trainer/skills/professions, bosses/mobs, world builders/teleports, survival, client input/HUD/settings/localization, network authority and save boundaries. Follow each report for precise files, triggers, confidence and limits.
- Config/source checks found all **19 boss models**, HP endpoints **280–3500**, all **30 location builders**, **124 upgrade transitions**, and no unknown upgrade-counter/drop/book-item references. Presence and reference integrity do not prove balance, visual quality or runtime correctness.
- Localization checks found **1,444 entries** with four locales and **510 literal client translation calls** resolving. Dynamic translation keys and actual text fitting still need scenario testing.
- Parent read-only Studio inspection confirmed the four invalid private gang-mine arrival tags. No pass was spent for this check.
- `scripts/qa-storage-load-failure.luau` reproduced S1 using an isolated ModuleScript, mocked DataStore and deterministic scheduler. It did not access real keys or player profiles; the temporary module was destroyed.
- Prior evidence remains separate: [network QA](network-validation-2026-11-02.json), [latency measurements](network-latency-2026-11-02.json), [mining-counter QA](mining-stats-validation-2026-11-02.json). Local steady-state latency is not WAN/mobile latency, and existing fixture/solo boss passes are not 4–6-player balance acceptance.
- Still required: crash/retry/concurrent-server persistence tests; receipt delivery under save failures; real 4–6-player late bosses with ordinary equipment; native-phone inventory/combat/settings/auction; initial-load frame-time and streaming stalls; end-to-end newcomer progression and late-game resource pacing.
- Resolve separate design ambiguities before implementing them: per-cell AoE XP/chance rewards, achievement multiplier consistency, artifact-case persistence, death-counter rules, boss star allocation, boss-state ownership across servers and paused industrial/Quarries scope. See the economy/combat reports; these were not silently promoted to confirmed bugs.
- Descending teleport fall-damage history is a strong conditional risk, with a source/state-model counterexample, but no actual unprotected teleport death was reproduced. Run its disposable-character trace rather than asserting it already happened.

## Delivery record

Production edits in this audit are limited to the owner's brightness/sensitivity responsiveness issue. The remaining findings form the next repair backlog. No publishing or map replacement was performed. Final checks and settings regression results are recorded in `audit-validation-2026-11-02.json` and the session journal.
