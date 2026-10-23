# VoxeLibre textures (third-party)

Source: https://github.com/VoxeLibre/VoxeLibre (`textures/`), downloaded 2026-10-21.
Authors: Pixel Perfection resource pack by XSSheep (and VoxeLibre contributors); see VoxeLibre `LEGAL.md`.
License: Creative Commons Attribution-ShareAlike 4.0 (CC BY-SA 4.0) — https://creativecommons.org/licenses/by-sa/4.0/

Files: `default_tool_{wood,stone,steel,diamond}{pick,shovel,axe,sword}.png`, `default_tool_shears.png`,
`mcl_armor_{helmet,chestplate,leggings,boots}_{leather,chain,iron,diamond}.png` (Minecraft skin-layout armor layers),
`mcl_armor_inv_*` (inventory icons), `mcl_core_web.png` (cobweb; recoloured white → `assets/textures/sprites/cobweb.png`, the Minecraft-style cross sprite of the cobweb block and the decor webs).

Derived files in this repo (`assets/icons/items/*` for tools and armor, `assets/armor/*`, `assets/icons/voxels.json`
entries for tools) are modifications (nearest-neighbour upscales, face crops, voxel extrusions) and are shared under the
same CC BY-SA 4.0 license. In-game credits must name "Pixel Perfection by XSSheep, via VoxeLibre, CC BY-SA 4.0".

# VoxeLibre sounds (third-party)

Source: https://github.com/VoxeLibre/VoxeLibre (`mods/*/sounds/`), downloaded 2026-10-21 at the owner's request
(«замени все звуки на VoxeLibre»). Files: `assets/thirdparty/voxelibre/sounds/*.ogg`; per-mod license notes in
`assets/thirdparty/voxelibre/sounds/licenses/` (mcl_sounds, mcl_armor, mcl_chests, mcl_experience, mcl_hunger,
mcl_item_entity, LEGAL.md). Licenses: CC BY-SA 3.0 / CC BY-SA 4.0 / CC BY 3.0 / CC0 per file as listed there
(e.g. Mito551 CC BY-SA 3.0 for dig/footstep sounds; EdgardEdition CC BY 3.0 tool break; glass by cmusounddesign,
Tomlija, lsprice CC BY 3.0; metal by yadronoff CC BY 3.0, qubodup / mypantsfelldown / Ogrebane CC0; armor by
juryduty / mitchanary CC0, Mito551 CC BY-SA 3.0, artisticdude CC0); the rest per VoxeLibre `LEGAL.md`.

Derived file: `assets/sounds/build/atlas.ogg` (trimmed, peak-normalised and concatenated by
`scripts/build-sounds.mjs`) — a modification shared under CC BY-SA 4.0 (compatible with the CC BY-SA 3.0 parts).
In-game credits must name "Sounds: VoxeLibre contributors (Mito551 and others), CC BY-SA 3.0/4.0, CC BY 3.0, CC0".
