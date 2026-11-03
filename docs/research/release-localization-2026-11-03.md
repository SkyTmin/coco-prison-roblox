# Four-locale source audit and corrections

Scope: the merged Russian, English, Spanish and French string catalog; format placeholders; literal client/server references and direct refusal-key returns; generated item/block/location/counter/book/boss content; actual item tooltip rendering; source-built world labels. No Studio actions, player/profile mutations or purchases were performed by this reviewer.

## Confirmed defects fixed

1. `Strings.itemName` prioritizes `Config.block`, including item-only entries. The gang mine pass therefore displayed Russian in all other locales despite its complete `item_gang_mine_pass` translations. `Strings.blockName` now falls back to the existing item translation when the block-name dictionary has no entry.
2. The location dictionary contained old `Снежная даль` and misspelled `Снежная далнь`, but omitted current `Снежная длань`. Added Snowy hand / Mano nevada / Main enneigée; older aliases remain compatible.
3. `/help` retained the Russian `Авторитет` inside its English, Spanish and French text. The three entries now use the existing shop/status names Kingpin / Capo / Caïd.
4. All non-Russian boss names previously used English in BossHud, PrisWindow, reward toasts and boss-kill chat. Added four-locale names for all 19 configured bosses and a shared `Strings.bossName` helper. Only the name-selection expressions changed in those consumers. Russian and English names remain exactly equal to the current catalog.
5. Forty-eight distinct literal world labels in source map builders fell back to Russian in EN/ES/FR. This included gang/ghetto NPCs, mine/arena signs, location signs, directions and decorative notices. `worldText` now reuses existing menu/NPC translations and the location dictionary, plus 34 explicit map-text entries in ReleaseItems. Lua's ASCII-only upper/lower functions also failed to recognize Cyrillic uppercase `ТЕЛЕПОРТАТОР`; a small Unicode uppercase helper now preserves capitals, including accents needed by Spanish/French. Unrecognized labels and Russian originals are preserved.

New translations live in `src/shared/Strings/ReleaseItems.luau`. Existing ReleaseCombat/ReleaseWorld/ReleaseUi/ReleaseServers parts were not edited. Coordinator authorized the narrow Strings/init, BossHud/BossService/PrisWindow wiring and Part2 correction.

## Verification

`scripts/qa-release-localization-offline.luau` compiles the actual current Strings/ItemInfo/Config/Effects/Potions modules under Lune. Latest run passed with zero reported defects:

| Checked | Count |
| --- | ---: |
| Merged keys | 1,564 |
| Nonempty locale entries | 6,256 |
| Actual formatted string renders | 1,600 |
| Actual item/book tooltip renders | 568 |
| Literal translation references and direct refusal returns resolved | 969 |
| Block/location/upgrade-counter/boss/world-label and casing checks | 1,237 |

The fixture verifies locale format-token agreement and executes formatting with typed sample arguments. Literal percentages in static labels are distinguished from placeholders. It also calls ItemInfo.audit, renders configured book levels, checks all current blocks/locations/upgrade counters, extracts literal Russian labels from map builders, verifies all 19 boss keys and unchanged RU/EN names, and includes exact regressions for `TÉLÉPORTEUR`, `GALERÍA`, `MAIN ENNEIGÉE`, Russian casing, unknown-label preservation and the item-only gang pass. The only merged-key override is the intentional newer Springs description.

This is a source audit with targeted actual-module executions, not a full Luau AST analyzer or screenshot/device acceptance. Dynamic user names and labels absent from source builders are not inferred or translated. It does not assert that every translated phrase fits every viewport. Meaning review focused on identified defects; no claim of a complete native-speaker editorial review of all 6,256 entries is made.

Selene reports zero errors/warnings on the changed localization modules and fixture. StyLua/whitespace checks pass for the owned files. The UI agent independently reviewed worldUpper/worldText and the boss consumers: no blocking finding; requested explicit uppercase/accent regressions were added and pass. No unrelated BossService functions were changed.

## Additional integration finding handed to coordinator

At the audit checkpoint, ProximityPrompt ActionText/ObjectText was assigned on the server with default Russian Strings.t in EconomyService, LocationService, NeedsService, CaseService, DailyService, GangBaseService, GangHouseService, GhettoService and GhettoMineService. Client world localization only handled TextLabels, so NPC interaction button text could remain Russian even with complete translations. Coordinator assigned the UI agent explicit PromptText key/typed-argument metadata and PromptLocalizer integration; that agent owns its final verification. This review does not claim a live prompt-localization pass.
