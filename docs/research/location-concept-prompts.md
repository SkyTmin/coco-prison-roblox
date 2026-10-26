# Промпты для концепт-референсов локаций

Сгенерировано `node scripts/build-location-prompts.mjs` из [location-prompts.json](location-prompts.json). Каждый промпт самодостаточный: копировать целиком в генератор картинок (ChatGPT и т. п.), получится лист 2×2 — карта сверху, вид со старта, арена/вершина, крупные детали. Готовые картинки — в `assets/concepts/<id>/`, по ним строится локация.

## 21 · Рынок — босс Король нежити

Шумный тюремный базар: лабиринт лавок под навесами из красной, жёлтой и лаймовой шерсти; шахта «под прилавками» на площади; провал в земле открывает зелёный некрополь — арена Короля нежити.

```text
LEVEL: "Market", a noisy prison black market where everything is sold. A maze of wooden market stalls under striped wool awnings in red, yellow and lime green, crates and barrels, hand carts, hanging lanterns and bunting between roofs, smuggled goods, rugs, cages with chickens, guard watchtowers and barbed fences on the outer prison wall, graffiti. The mine is dug right under the stalls: stalls are pushed aside around a pit in the central square. MINE BLOCKS: red wool, yellow wool, lime wool. HERO LANDMARK: at the far end of the market the ground has cracked and collapsed into a huge pit glowing with green light - an ancient underground necropolis, a broken stone staircase leads down. BOSS ARENA: down in that crypt - tombs, bones, green fog, ghoul statues, 4 crypt pillars. The boss is the Undead King: he throws dark missiles, summons exploding skulls and a giant ghost sword, ghouls guard him. MOOD: bright busy sunny day above, dead silent green-lit crypt below - strong contrast.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the boss arena - an open round plaza about 60 blocks across with 4 thick pillars, reachable from at least 3 sides.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the boss arena seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 23 · Лепреконовая долина — босс Лесной дух

Зелёная долина в клевере, золото лепреконов, радуга; шахта из цветного цемента; туманная поляна с тотемом — арена Лесного духа.

```text
LEVEL: "Leprechaun Valley", a green valley overgrown with clover; they say leprechaun gold is hidden here. Rolling green hills, a rainbow ending in a pot of gold coins, giant toadstools, mossy boulders, a winding stream with small stone bridges, tiny leprechaun cottages with round doors, gold coins scattered in the grass. The mine looks like a rainbow quarry. MINE BLOCKS: yellow, orange, lime, purple and red concrete powder. HERO LANDMARK: a giant ancient carved wooden totem on a hill wrapped in roots and glowing runes. BOSS ARENA: a misty forest glade around that totem - ritual stones, hanging lanterns, roots breaking the ground, little flying skulls. The boss is the Forest Spirit, a horned dark spirit with a glowing yellow-green orb; cultists (shamans and lost explorers with lanterns) guard its totem. MOOD: sunny and magical in the valley, misty and eerie in the glade.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the boss arena - an open round plaza about 60 blocks across with 4 thick pillars, reachable from at least 3 sides.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the boss arena seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 25 · Замок — босс Вороний рыцарь

Старый замок с высокими стенами и тёмными коридорами, стаи воронов; шахта на дворцовой площади из кварца; разрушенный зал — арена Вороньего рыцаря.

```text
LEVEL: "Castle", an old castle with high walls and dark corridors; flocks of ravens and their cursed knight guard its stones. Massive outer walls with walkways and towers, a gatehouse with a raised portcullis, inner courtyards, a chapel, stables, a smithy, torch-lit corridors, crow nests on every battlement. The mine is the torn-up palace square in front of the keep. MINE BLOCKS: white quartz block and chiseled quartz block. HERO LANDMARK: a tall dark keep with a broken spire circled by a huge flock of ravens. BOSS ARENA: the ruined great hall with a collapsed roof open to the sky, torn banners, a cracked throne, black feathers on the floor, 4 stone pillars. The boss is the Raven Knight: crow swarms, black fog, spikes bursting from the floor, a summoned flying axe, he turns into a crow-reaper. MOOD: overcast grey evening, cold light, ravens everywhere.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the boss arena - an open round plaza about 60 blocks across with 4 thick pillars, reachable from at least 3 sides.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the boss arena seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 27 · Изнанка — босс Векна

Перевёрнутый мрачный мир: обрывки города парят в пустоте, красные молнии, чёрные лианы; шахта из листвы мрачного дуба; часы — арена Векны.

```text
LEVEL: "The Upside Down", a gloomy inverted mirror of an ordinary small town where nothing is what it seems. Chunks of streets and houses float in a dark void, some upside down, connected by rope bridges and fallen telephone poles; black vines and fleshy tendrils cover everything, ash-like spores drift in the air, red lightning flashes in a dark red-grey sky. The mine floats on its own chunk of land. MINE BLOCKS: dark oak leaves (overgrown, dark green-black). HERO LANDMARK: a huge old clock tower hanging upside down from a floating island, its clock face glowing red. BOSS ARENA: under that clock - a cracked town square with glowing red portal rifts in the ground, vines, a grandfather clock, 4 broken lamp posts as pillars. The boss is Vecna, a creature of flesh and darkness, with monster minions like demogorgons and demo-dogs. MOOD: dark, oppressive, red and black, horror but readable.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the boss arena - an open round plaza about 60 blocks across with 4 thick pillars, reachable from at least 3 sides.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the boss arena seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 29 · Киото — босс Самурай

Город сакуры и древних храмов: пагода, тории, каменные фонари, пруды с карпами; шахта во дворе храма; двор додзё — арена Самурая и духа его возлюбленной.

```text
LEVEL: "Kyoto", a city of blooming sakura and ancient temples where the samurai Hanashiguro fights in the streets. Curved tiled roofs, red torii gates in a row, stone lanterns, koi ponds with arched red bridges, bamboo groves, a zen rock garden, paper lanterns over narrow streets, cherry petals falling. The mine is in a temple courtyard. MINE BLOCKS: pink wool with scattered sea lanterns (glowing pale blocks). HERO LANDMARK: a five-story pagoda on a hill above the city. BOSS ARENA: a dojo courtyard in front of the main temple - wooden floor, cherry trees at the edges, hanging paper lanterns, a gong, 4 red lacquered pillars. The boss is the samurai Hanashiguro and the ghost of his beloved: rain of arrows, ghost spears, kusarigama, shuriken, three phases. MOOD: soft pink spring light, calm beauty with tension.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the boss arena - an open round plaza about 60 blocks across with 4 thick pillars, reachable from at least 3 sides.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the boss arena seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 31 · Ферма — босс Грут

Ухоженная ферма: ровные грядки, мельница, сад, ульи; шахта — урожайная яма из арбузов и тыкв; поляна с огромным пнём — арена Грута.

```text
LEVEL: "Farm", the well-kept part of a big farm with neat shining rows of crops and ripe harvest waiting to be picked. Orderly fields of wheat, carrots and potatoes, irrigation channels, wooden fences, beehives, haystacks, a red farmhouse with a porch, chicken coops, an orchard with fruit trees, a duck pond, sheep in a pen. The mine is a giant harvest pit. MINE BLOCKS: melons, pumpkins and green wool. HERO LANDMARK: a tall wooden windmill with turning sails on a hill. BOSS ARENA: an ancient orchard clearing around a gigantic tree stump - roots, fallen leaves, mossy logs as cover, 4 old trees as pillars. The boss is Groot, an Ent King: branches erupt from the ground, leaf storms, he summons tree minions. MOOD: warm golden summer afternoon, cozy and bright.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the boss arena - an open round plaza about 60 blocks across with 4 thick pillars, reachable from at least 3 sides.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the boss arena seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 33 · Амбар — босс Древесный хранитель

Запущенная старая ферма: покосившийся амбар, бурьян, хлам, пугала, светильники Джека; шахта перед амбаром; заросший двор — арена Древесного хранителя.

```text
LEVEL: "Barn", the old neglected part of the farm: overgrown, littered with junk, every job is exhausting. Thick tall weeds and thorny bushes, broken carts and wagons, rusty tools and old tires, collapsed fences, scarecrows, dead trees with crows, a dry well, piles of rotten hay, cobwebs. Dusk lighting, everything lit by glowing carved pumpkins. The mine is right in front of the barn doors. MINE BLOCKS: jack o'lanterns (carved glowing pumpkins). HERO LANDMARK: a huge sagging red barn with a broken roof and a crooked weathervane. BOSS ARENA: the overgrown barnyard behind it - roots coming out of the ground, glowing magical seed pods where creatures spawn, 4 old silos as pillars. The boss is the Forest Guardian, a giant woven of roots and bark; while its magical creatures live, no weapon can hurt it. MOOD: orange-purple dusk, spooky but cozy, autumn.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the boss arena - an open round plaza about 60 blocks across with 4 thick pillars, reachable from at least 3 sides.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the boss arena seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 35 · Врата края — босс Жнец

Врата Края среди хорусовых плантаций и странных минералов; шахта из пурпурного цемента и чёрного стекла; обсидиановый круг — арена Жнеца.

```text
LEVEL: "End Gates", the gates of the End among chorus fruit plantations and strange minerals; every step near them is a trial. Pale end-stone islands in a starry purple void, terraced plantations of chorus plants, clusters of purple and black crystals, end rods as lamps, obsidian monoliths, floating debris, small purpur shrines. The mine is on the main island. MINE BLOCKS: magenta concrete with veins of black stained glass. HERO LANDMARK: a colossal obsidian gateway arch with a swirling black-and-starry portal inside. BOSS ARENA: a dark obsidian circle in front of the gateway with glowing purple runes in a ring, 4 obsidian pillars with end rods. The boss is the Reaper, death incarnate with a scythe: he teleports, draws a soul circle on the ground, slams the ground. MOOD: night, purple glow, eerie silence.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the boss arena - an open round plaza about 60 blocks across with 4 thick pillars, reachable from at least 3 sides.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the boss arena seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 37 · Древо

Небесная шахта 1: исполинское древо, корни уходят сквозь облака; шахта на огромной ветви; начало пути наверх.

```text
LEVEL: "The Tree", the first sky mine: a colossal tree whose roots go down through the clouds; the path to the sky mines starts here. Platforms and rope bridges built between giant branches, a spiral wooden stair around the trunk, hanging lanterns, bird nests, leaves as big as roofs, waterfalls dripping from the canopy into the clouds below. The mine sits on a flat platform carved into the widest branch. MINE BLOCKS: white concrete. HERO LANDMARK: the glowing crown of the tree high above. SUMMIT: a wooden observation deck at the top of the crown above the clouds. MOOD: bright morning, airy, sense of height.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the summit plaza - the most beautiful spot of the level, open, about 50 blocks across.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the summit seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 39 · Церковь

Небесная шахта 2: тихая церковь над облаками; шахта в саду клуатра.

```text
LEVEL: "The Church", the second sky mine: a quiet church above the clouds where rare light rocks are mined under its vaults. A white-and-terracotta stone church with stained glass windows, a tall bell tower, cloister arcades around a garden, candles, an old graveyard with white flowers, stone angels, stairs going down to cloud docks. The mine is in the cloister garden. MINE BLOCKS: clay (soft blue-grey). HERO LANDMARK: the bell tower with a golden bell. SUMMIT: the open bell tower top with the bell and a view over endless clouds. MOOD: soft golden light through stained glass, peaceful and holy.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the summit plaza - the most beautiful spot of the level, open, about 50 blocks across.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the summit seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 41 · Чистилище

Небесная шахта 3: чистилище, где души ждут своего часа; туманные террасы, очередь призрачных душ.

```text
LEVEL: "Purgatory", the third sky mine: a place where souls wait for their hour, a mine for those ready for long labor. Grey-gold misty terraces going up, an endless calm queue of translucent ghostly souls, giant hourglasses, waiting benches, stone gates with ledgers, dim candle lanterns, a slow river of mist. The mine is on a sandstone terrace. MINE BLOCKS: chiseled sandstone. HERO LANDMARK: a giant hourglass tower with flowing golden sand. SUMMIT: a judgment plaza with scales at the top of the terraces. MOOD: muted gold and grey, melancholic, quiet.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the summit plaza - the most beautiful spot of the level, open, about 50 blocks across.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the summit seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 43 · Эдем

Небесная шахта 4: цветущий сад Эдема; шахта из грибных блоков на поляне.

```text
LEVEL: "Eden", the fourth sky mine: the blooming Garden of Eden where the ground is rich in valuable blocks. Lush meadows of colorful flowers, crystal waterfalls falling off the island edge, giant ferns, peaceful animals (deer, rabbits, birds), fruit trees, a clear lake with lilies, a winding river. The mine is in a mushroom clearing. MINE BLOCKS: brown mushroom blocks. HERO LANDMARK: the Tree of Knowledge with glowing red apples and a serpent coiled around it. SUMMIT: a flower-covered hill under that tree. MOOD: radiant spring, pure and abundant.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the summit plaza - the most beautiful spot of the level, open, about 50 blocks across.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the summit seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 45 · Херувимы

Небесная шахта 5: обитель херувимов, сияющая золотом; снежно-белые облака.

```text
LEVEL: "Cherubim", the fifth sky mine: the abode of cherubs shining with gold, where only the most stubborn dig. A palace of white marble and gold on snow-white clouds, golden harps and trumpets, wing motifs on every arch, golden domes, fountains of light, little cherub statues, colonnades. The mine is in a marble courtyard. MINE BLOCKS: snow blocks. HERO LANDMARK: a golden dome palace with giant marble wings on its sides. SUMMIT: a golden balcony with harps above the clouds. MOOD: dazzling white and gold, bright sun.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the summit plaza - the most beautiful spot of the level, open, about 50 blocks across.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the summit seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 47 · Врата

Небесная шахта 6: небесные врата, за которыми последний путь наверх; длинная лестница.

```text
LEVEL: "The Gates", the sixth sky mine: the heavenly gates beyond which the last path upward begins. Giant pearly-white and gold gates standing on clouds, a long wide stairway rising into the light, guardian statues with spears, gatekeeper booths, golden chains and lamps, floating stepping-stone islands. The mine is on a smooth sandstone plaza before the gates. MINE BLOCKS: smooth sandstone. HERO LANDMARK: the colossal pearly gates, half open with light pouring out. SUMMIT: the top of the stairway right at the open gates. MOOD: warm light, solemn, epic scale.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the summit plaza - the most beautiful spot of the level, open, about 50 blocks across.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the summit seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 49 · Рай

Небесная шахта 7: Рай, вершина небесных шахт; сияющий сад-город на самом верху.

```text
LEVEL: "Paradise", the seventh and last sky mine, the summit that only the best prisoners reach. A radiant garden-city at the very top of the sky: crystal-clear streams, golden bridges, white towers with gardens on every terrace, rainbow light beams, gentle waterfalls into the clouds, fruit trees and flowers everywhere. The mine is in a garden clearing. MINE BLOCKS: red mushroom blocks. HERO LANDMARK: a tall shining white-gold spire with a beam of light into space. SUMMIT: the garden at the foot of the spire. MOOD: ultimate reward, glowing, peaceful, the brightest level of the game.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the summit plaza - the most beautiful spot of the level, open, about 50 blocks across.

The whole level is a floating island high in the sky (every level floats at its own height): edges are cliffs or walls, nothing else on the horizon except sky and clouds.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the summit seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```

## 12 · Нефтезавод (по желанию)

По желанию (у нас её ещё нет): нефтезавод, где технологии уступили хаосу; плачущий обсидиан, охрана.

```text
LEVEL: "Oil Refinery", a place where technology gave way to chaos. A fenced industrial yard: rusted pipes and valves everywhere, cylindrical oil tanks, a flare stack burning, pools of black oil, broken conveyor belts, control rooms with flickering screens, catwalks and ladders, hazard stripes, patrolling security guards. The mine is a pit in the middle of the yard. MINE BLOCKS: crying obsidian (dark purple with glowing tears). HERO LANDMARK: the tallest distillation tower with a fire on top. SUMMIT: the roof of the control building with a view over the refinery. MOOD: smoggy orange sunset, dirty and dangerous.

STYLE: a Minecraft-like voxel game (it runs in Roblox). Everything is built from 1x1x1 blocks with crisp 16x16 pixel-art textures: no smooth curves, no realistic materials, no plastic look. Saturated but cohesive palette, strong silhouettes, lots of small hand-placed details. Three-quarter camera unless a panel says otherwise. SCALE: the player is 2 blocks tall; main paths are 4-6 blocks wide because players fight each other (PvP) here. COMPOSITION: one hero landmark visible from the arrival point, 3-4 districts with different character, height variety (bridges, terraces, rooftops, underground), no empty filler.

GAMEPLAY PIECES THAT MUST BE VISIBLE: (1) the mine - a square pit 32x32 blocks wide and 12 blocks deep, filled with the mine blocks listed below, ladders on its 4 walls; (2) the arrival platform and a small block-buyer stall right next to the mine; (3) the summit plaza - the most beautiful spot of the level, open, about 50 blocks across.

The level is a closed area surrounded by walls and fences; nothing else is visible on the horizon.

OUTPUT: one landscape 3:2 image laid out as a 2x2 concept sheet with thin gaps: top-left - top-down map of the whole level; top-right - eye-level view from the arrival platform toward the mine with the hero landmark behind it; bottom-left - the summit seen from player height; bottom-right - close-up of 6-8 signature props of this place. No text, no labels, no UI, no logos, no watermark.
```
