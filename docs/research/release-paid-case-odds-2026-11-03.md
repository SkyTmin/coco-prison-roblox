# Paid case probability engine — 2026-11-03

The owner explicitly requested missing paid-random-item restrictions and truthful outcome probabilities. This follow-up implements the probability engine and factors the actual reward math into shared pure modules. Policy enforcement and UI are owned by the root/UI agents. No configuration, reward weight, book proc chance, application chance, cooldown or item balance was changed here.

## Actual behavior and shared implementation

`src/shared/CaseRoll.luau` owns the ordinary/artifact draw count, configured weighted selection, currency rounding and concrete reward resolution. The root agent integrated its `drawCount`, `select` and `resolve` functions into `CaseService`; delivery remains in the server's staged inventory transaction.

- Ordinary case: uniformly choose 2, 3 or 4 draws, each with probability 1/3. Main draws use the configured weights with replacement. The current total weight is 144.9; a weight is not directly a percentage.
- Food: uniformly select the configured food, then an inclusive integer quantity. The resolver retains even the old unused first food-count RNG call, preserving seeded behavior.
- Armor: one of four level-I pieces; weapons: sword or bow, level I. The Silk Touch wooden pickaxe retains its exact level-I book metadata.
- Money: round both configured dollar endpoints using `floor(value * moneyScale + 0.5)`, then choose an inclusive uniform integer. `moneyScale` is **10000**. Ordinary money has 10,301 possibilities, 3700..14000 minor units ($0.37..$1.40); artifact money has 1,000,001 possibilities, 200000..1200000 minor units ($20..$120). The exact step is $0.0001. Artifact money remains a `money_bag` with the rolled `coins` metadata; ordinary money is credited directly.
- Artifact case: one main draw; current weight total 113. Counts, all three concrete booster item IDs, money-bag metadata and the nested ordinary ancient-book roll are represented. The nested book branch has probability 5/113, then multiplies every final book/apply-chance outcome by that parent probability.

`src/shared/AncientRoll.luau` owns actual book selection and its distribution. `AncientCase.roll` delegates to it. `BookTuning.roll` delegates to its adjustment function; `BookTuning.proc`, layer cooldown and player state remain in the original server module.

- Select configured rarity, then uniformly select an eligible effect in that rarity. If the rarity has no eligible effects, use the actual fallback pool.
- Normal keys sample configured I/II/III weights and clamp to the selected effect's supported levels.
- Improved keys exclude effects without III and always award III.
- At III, `plastolom`, `vampirism` and `enlightened` retain half of their originally selected mass; the other half is distributed uniformly among the pool's unadjusted alternatives. The probability calculation uses this same rule, including any final level clamp after substitution. It aggregates identical final effect/level outcomes rather than displaying duplicate branches or the nominal selection weight.
- Normal application chance: each integer 10..100 has conditional probability 1/91. Improved: low band 10..70 has mass 0.9, each integer 0.9/61; high band 71..100 has mass 0.1, each integer 0.1/30. This is independent of the awarded effect/level after selection.

Nickname odds use the actual `Nicknames` catalog and per-name weights, exclude owned names, and renormalize each individual remaining name. Owning every name yields an unavailable plan and `nickname_all_owned`, not an invented outcome or division by zero.

The ordinary bonus is independent and occurs once per opening: no fragment with probability 0.94; otherwise each of nine common mosaic tile indices has probability 0.06/9. The plan includes whether the selected tile is already owned, the deterministic granted indices after duplicate conversion, and the resulting duplicate counter. It describes mosaic state changes, not an invented inventory item. Projection was checked against the actual `ArtifactService.GrantFragment` implementation.

## Presentation API

`RewardOdds.case(caseId, profile?, keyId?) -> Plan`:

```text
Plan = {
  caseId, keyId,
  draws = [{count, probability}],
  outcomes = [Node], bonuses = [Node],
  unavailable, unavailableReason?
}
Node = {
  kind, id, probability,
  stack?, rarity?, nickname?, children?,
  range? = {field, min, max, probabilityPerValue},
  tier?, index?, duplicate?, grantedIndices?, duplicatesAfter?
}
```

All values are fractions 0..1. **Main node probabilities are joint probabilities within one main draw. Bonus node probabilities are joint probabilities per opening.** Children sum to their parent; they are not conditional percentages that should be multiplied again. A uniform range lists inclusive integers, and `probabilityPerValue` is already the final joint probability of each integer under that branch. Book nodes include their exact effect/level stack; child ranges encode application chance. Money ranges use integer minor units; divide by Config.moneyScale only for presentation.

For an ordered sequence of main outcomes, its complete opening probability is the corresponding draw-count probability multiplied by each per-draw leaf probability; multiply by the separate bonus leaf probability if specifying a bonus outcome as well. No giant enumeration is required. `RewardOdds.atLeastOne(plan, perDraw)` computes the marginal chance of one or more instances of a specified per-draw event across the count mixture.

For ancient tabs use `keyId = "ancient_key"` or `"improved_ancient_key"`; omitted key means normal. Node kinds: `item`, `money`, `book`, `bookPool`, `applyChance`, `nickname`, `none`, `artifactPool`, `artifactFragment`.

UI integration notes delivered to the UI agent: label main chances “per draw,” show the separate draw-count and bonus distributions, expose expandable nested branches, preserve $0.0001 in currency-step text, and use adaptive precision for nonzero tiny probabilities instead of displaying them as 0.00%.

## Capacity boundary found during audit

The old ordinary opening rolled first, then rejected an outcome that could not fit, spending no key on failure. With a full chest, all-money draws could consume a key while any item draw failed free. That makes the distribution of *paid successful openings* depend on capacity and contradicts fixed advertised raw odds.

The root agent was notified with this concrete counterexample and the narrow remedy: require at least four free ordinary-case slots before rolling, sufficient for every possible 2..4-draw outcome. This avoids outcome-dependent rejection without changing the configured probabilities. The root agent owns the `CaseService` preflight and its acceptance tests. Artifact cases always need one slot; ancient cases always need one book slot in inventory or overflow, so their capacity decision does not vary by selected reward identity.

## Verification

`scripts/qa-paid-odds-offline.luau` loads the actual shared/server modules and generated configs with local service mocks:

- **1,469 exact assertions** cover root and every hierarchical branch normalization, all uniform integer ranges, per-opening count mixture, concrete armor/weapon/Silk/booster metadata, nested books, exact final adjusted III probabilities, rarity totals, fallback pools, supported levels and improved low/high application bands.
- Nickname tests cover partial/full/one-name ownership, each remaining name's exact probability, and actual `Nicknames.pick` at each displayed weighted interval midpoint.
- Bonus tests compare the projection with actual `ArtifactService.GrantFragment` for all nine indices against empty, near-conversion, full and accumulated-duplicate mosaics; preview leaves the input profile unchanged.
- Before editing, the original `AncientCase`, `BookTuning` and `CaseService` files were saved locally under `%TEMP%/coco-paid-odds-baseline`. With `COCO_ODDS_BASELINE` set to that directory, **6,000 seeded actual-source comparisons** passed: 4,000 normal/improved ancient-book results and 2,000 ordinary/artifact category resolutions, comparing exact stack metadata and money amounts. The additional parity assertion makes that run report **1,470 PASS**. This proves unchanged outcomes against the pre-refactor source for those sequences, rather than comparing two copies of the new formula.
- Scoped Selene: **0 errors, 0 warnings**; StyLua and `git diff --check`: PASS.

No Studio, cloud action, real profile, key consumption, purchase or store access occurred. UI/policy/live acceptance is reported separately by its owning agents. New production modules in this scope are `AncientRoll`, `CaseRoll`, `RewardOdds`; server edits are limited to math delegation in `AncientCase` and `BookTuning`.
