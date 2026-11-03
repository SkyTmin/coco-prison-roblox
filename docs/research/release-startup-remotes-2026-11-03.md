# Early client startup RemoteEvents

Parent observed the real cloud Play client waiting indefinitely at `HurtFeedback.Start:74` for `HurtImpact`, reached synchronously through `EffectsHud.start:188` and `init.client:2332`. `Shared.Remotes` calls `WaitForChild(name)` on clients (`Remotes.luau:106`), while the event was created only at the later `HurtService.Start`.

The sole production change adds six existing RemoteEvents to `src/server/init.server.luau`'s upfront creation list, before service loading and startup. The same nearby synchronous startup paths provide concrete evidence for each addition:

| Channels | Client consumer | Previous creation |
| --- | --- | --- |
| HurtImpact, Knockback | HurtFeedback.luau:74 / :104, both inside Start | HurtService.luau:243–244 |
| AuctionAnnounced, AuctionListed | AuctionBanner.luau:231 / :247; start called synchronously at init.client:2299 | AuctionService.luau:1510–1511 |
| DigAccepted, DigRejected | init.client.luau:2549 / :2576, direct startup subscriptions | DigService.luau:535–536 |

Adjacent AutoSold, HitConfirm, Ate, profile/case/teleport events and the existing unreliable FX channels already have upfront creation. No request-only channels, new handlers, gameplay rules or service ordering were changed. Later service calls reuse the same RemoteEvents through the existing idempotent helper. `RuntimeReady` continues to represent completed service startup; early object creation does not claim handlers are ready.

Validation: Selene on the changed server initializer reports zero errors/warnings; StyLua check and the initializer's scoped diff-whitespace check pass. No duplicate implementation tests were added. The repository-wide whitespace check reports pre-existing/concurrent CRLF trailing-whitespace changes in other files; those are outside this patch. This agent performed no Studio operations. Parent must sync the initializer and restart Play to verify that the reported HurtImpact wait is gone and ordinary client initialization completes.
