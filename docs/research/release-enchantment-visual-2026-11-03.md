# Enchanted item visibility

Owner reported that enchantments were difficult to see both in the hand and inventory. The earlier instruction to remove equipment glow remains in force: this change creates no Neon material, BloomEffect, Highlight, PointLight or SurfaceLight, and does not change armor worn on bodies.

## Confirmed cause

Inventory renderSlot and SlotView rendered only the ordinary icon; HeldItem.MakeVisual produced only the base model. There was no active enchantment glint path left after removing glow. In addition, the replicated `HeldItem` value contained only `id:level`. Applying/removing an ancient book without changing that value could not communicate its visual status to another player's client.

## Implementation

`shared/ItemEnchantment.active` reads the existing Config truth: built-in Efficiency/Sharpness/Protection etc. from the actual upgrade level, accumulated bow Flame, or a valid compatible applied ancient book. It does not invent enchantment metadata or alter stacks. A plain level-one item without an applied book stays plain; stored unused ancient books retain their existing rarity treatment.

`ProfileService.Replicate` publishes a separate boolean `HeldEnchanted` from the selected actual stack. Third-person HeldItem reacts to that flag as well as id/level; FirstPersonHand includes it in its visual cache key. Both use the same MakeVisual path. Old visuals are destroyed before replacements, including same-level book application/removal, so the change does not create duplicate held models.

`EnchantmentVisual.slot` adds one alpha-matched copy of the existing item image with a travelling purple/cyan gradient, plus a small star/rune glyph in the top-left corner. Count and item selection remain separate. It reuses the existing image/UV rectangle, adds no icon asset and avoids a full rectangular tint over transparent sprite pixels. It updates an existing decoration instead of adding a new tween on each profile render; empty/plain slots and destroyed windows cancel/remove the decoration. Integrated into inventory/hotbar/equipment, SlotView-backed chest/book windows, Actions item selection, and the economy agent's Upgrade/Auction renderers.

Held enchanted models receive a restrained colour pulse on their actual visible voxel surfaces and a small diamond rune on each broad face of the largest visible piece. Original materials and transparency remain intact. SurfaceGui uses `LightInfluence=1` and `AlwaysOnTop=false`: these markings receive scene lighting and are occluded normally, as documented by [SurfaceGui](https://create.roblox.com/docs/reference/engine/classes/SurfaceGui). Existing non-enchantment swing trails are unchanged. No extra physical model is added. A single shared 15Hz animation connection handles current decorations, skips detached/over-120-stud visuals, and disconnects when the last model is destroyed.

## Verification

`scripts/qa-enchantment-visual-offline.luau`: **239 checks PASS**, using the actual Config, ItemEnchantment, EnchantmentVisual and HeldItem modules with mocked Instances/signals. Every actual tool upgrade level agrees with built-in enchant/Flame state; compatible/incompatible/malformed ancient books are distinguished; UI deduplication/update/clear/destroy; unchanged stack data; matte material retention; detached-model updates; shared heartbeat cleanup; actual held rendering plain → same-level ancient enchant → plain → built-in Efficiency III → empty without duplicate models; created-instance audit rejects emissive/glow classes; dependent client/server source compilation.

No Studio operation or visual acceptance was performed by this reviewer. Parent should inspect the same enchanted/plain tool in hotbar, backpack and chest, first and third person, apply/remove a book at unchanged level, swap slots and respawn. Check low/bright lighting and mobile icon sizes; tune pulse/rune visibility from actual rendered evidence if necessary. Sync ItemEnchantment, EnchantmentVisual, ProfileService, HeldItem, FirstPersonHand, SlotView, init.client, ActionsWindow and the Upgrade/Auction integrations together. Gameplay stats and server outcomes are unchanged.
