# Release HurtService peer review

Reviewed 2026-11-03 after parent's unified damage/feedback implementation. This agent made no production HurtService, CombatService, or client feedback changes and did not use Studio.

No concrete correctness defect was found in the requested scope. `HurtService.Damage` consumes absorption before HP, respects non-boss ForceFields, emits one impact for accepted damage, and records expected HP changes so the external-health watcher does not duplicate owned hits. Bosses bypass ForceFields/absorption as required. The positional sound excludes the victim; the accepted `HurtImpact` drives that victim's one local sound, display state, direction feedback, and impulse. Separate book impulses do not repeat impact/audio. `Knockback.velocity` retains current vertical velocity while airborne and halves only the existing horizontal momentum before adding the impulse.

`scripts/qa-release-hurt-offline.luau`: **40 PASS** using actual `HurtService`, `HurtFeedback`, `Shared.Knockback`, and `Sfx.broadcast` with isolated engine mocks.

- Synchronous and deferred HealthChanged delivery: ordinary/rapid owned damage, external damage, and healing.
- Exactly one victim impact/audio; one nearby observer positional sound; victim/distant observer excluded from that positional broadcast.
- Full and partial absorption; gold depletion; authoritative packet health/absorbed/source data.
- ForceField protection without HP/gold loss or feedback; boss bypass and heavy sound.
- Zero, negative, infinite and NaN damage; lethal clamping and dead-target rejection.
- Duplicate impact id and another-character packet ignored without repeated sound/impulse.
- Grounded primary push; airborne descending/rising Y retained; half horizontal momentum; mob scale; boss no push; zero/nonfinite impulse rejection; book impulse without another hurt effect.

Run: `C:/Users/user/AppData/Local/Temp/coco-case-warzone-qa/lune.exe run scripts/qa-release-hurt-offline.luau`.

Limits: signals, character physics and audio playback are mocked. This is not evidence for real Roblox event scheduling, packet transport, animation synchronization, camera/phone feel, or client-owned velocity replication. Parent's paired Roblox test remains authoritative for those. The current critical-hit rule still requires a ray against the server's physical root; cosmetic motion history cannot make a server-grounded attacker airborne. The newer history-derived vertical-speed fallback is used only when the physical velocity is near zero and Humanoid state is Freefall; native jump/fall acceptance is a separate parent test.
