# Automatic UI language — 2026-11-03

## Behavior

A valid stored profile.locale remains an explicit manual choice, including existing Russian selections. A profile without that field uses the player's Roblox account language for the current session. ru-ru/en-us/es-mx/fr-fr (and underscore/case variants) normalize to ru/en/es/fr. Unsupported languages fall back to English. Automatic selection never writes profile.locale.

src/first/Locale.luau is standalone and available before Shared: normalize(raw), detect(player?), resolve(savedLocale, player?). LoadingController can call resolve(nil, player) initially and resolve(profile.locale, player) when the profile arrives. The loader integration/spinner is owned by the parent; this agent did not edit that file.

Player.LocaleId is the primary account-language input. LocalizationService.RobloxLocaleId is used only if the former is missing/unavailable, because Roblox documents that its core locale can differ from the account locale. Both properties are NotReplicated; the client therefore sends the validated short language through SetAutoLocale for server-side responses. Sources: [Player.LocaleId](https://create.roblox.com/docs/reference/engine/classes/Player#LocaleId), [LocalizationService.RobloxLocaleId](https://create.roblox.com/docs/reference/engine/classes/LocalizationService#RobloxLocaleId).

## Integration

- SetAutoLocale changes only session Player attributes; SetLocale remains the existing persistent manual path. A delayed automatic packet cannot override an existing manual profile language. Selecting the same currently visible automatic language through SetLocale still records a manual choice.
- Profile replication publishes LocaleManual and the effective Locale; no-language server responses fall back to English until the client reports its language.
- Main client render resolves the profile/device language, updates the effective attributes before prompt/world refresh, and rebuilds open UI when that language changes.
- TutorialGuide, PrisPerks and TopBoards no longer independently fall back to Russian. Existing canonical Russian source text for world/NPC localization and generated Config defaults were not rewritten.
- Before persisted settings arrive, an early loader cannot know a previous manual choice; it uses the account language, then honors the saved choice as soon as available.

## Verification

scripts/qa-locale-offline.luau:39 actual-source checks passed across normalization, early loading without Shared, actual ProfileService auto/manual handlers, replication, isolated save/rejoin, Strings response language and actual client render/rebuild prefix. No real profiles or native locale settings were changed.

Existing qa-profile-persistence-offline:39 PASS; qa-loading-offline:98 PASS (parent's updated loading fixture); prompt localization31 PASS; complete four-language catalog check has no issues. Scoped Selene0/0, StyLua and diff checks pass.

Native startup on accounts/devices with differing languages remains a parent acceptance check. Existing manually selected account language should not change during that check.
