// Generates src/shared/Config/*.json from confirmed wiki data + scripts/design-decisions.json.
// Usage: node scripts/build-configs.mjs
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => JSON.parse(readFileSync(join(root, p), "utf8"));
const outDir = join(root, "src", "shared", "Config");
mkdirSync(outDir, { recursive: true });
const write = (name, data) => {
	writeFileSync(join(outDir, name), JSON.stringify(data, null, 2) + "\n");
	console.log("wrote", name);
};

const decisions = read("scripts/design-decisions.json");
const levelsWiki = read("wiki/in-game-wiki/levels.json");
const pricesWiki = read("wiki/in-game-wiki/block-prices.json");
const pickaxeWiki = read("wiki/client-audit/content-analysis/pickaxe-upgrades-recovery.json");
const otherWiki = read("wiki/client-audit/content-analysis/other-upgrades-recovery.json");
const armorWiki = read("wiki/client-audit/content-analysis/armor-and-axe-recovery.json");
const bossWiki = read("wiki/client-audit/content-analysis/boss-menu-recovery.json");
const sharesWiki = read("wiki/in-game-wiki/mine-shares.json");

// ---------------------------------------------------------------- levels
const levels = levelsWiki.levels.map((l) => ({
	level: l.level,
	money: l.money,
	blocks: l.blocks,
	hearts: decisions.hearts.base + decisions.hearts.perLevel * (l.level - 1),
	skillPoints: l.level >= decisions.skillPoints.firstLevel ? decisions.skillPoints.perLevel : 0,
}));
write("levels.json", {
	source: "wiki/in-game-wiki/levels.json [вики]; сердца и очки навыков — [решение]",
	maxLevel: levelsWiki.rules.maxLevel,
	blocksSpent: false,
	moneySpent: true,
	levels,
});

// ---------------------------------------------------------------- blocks + locations
const counterByBlock = {
	sand: "Песок", gravel: "Гравий", dirt: "Земля", oak_log: "Дерево", melon: "Арбуз",
	stone: "Камень", cobblestone: "Камень", coal_ore: "Каменный уголь", coal: "Каменный уголь",
	iron_ore: "Железная руда", gold_ore: "Золотая руда",
};
const blocks = {};
const locations = [];
for (const loc of pricesWiki.locations) {
	const dec = decisions.mines[loc.id] || {};
	const def = decisions.mines._default;
	// Mine composition: confirmed menu tooltips ([меню]) win over design decisions; "air" = empty cells.
	const wikiShares = sharesWiki.mines[loc.id];
	const shares = wikiShares
		? Object.fromEntries(Object.entries(wikiShares).map(([k, v]) => [k, v / 100]))
		: dec.shares || Object.fromEntries(loc.blocks.map((b) => [b.id, 1 / loc.blocks.length]));
	if (wikiShares) for (const k of Object.keys(wikiShares)) if (k !== "air" && !loc.blocks.some((b) => b.id === k)) throw new Error(`share block ${k} not in price list of ${loc.id}`);
	for (const b of loc.blocks) {
		const phys = decisions.blocks[b.id];
		if (!phys) throw new Error(`no physics for block ${b.id}`);
		blocks[b.id] ??= {
			id: b.id,
			name: b.name,
			basePrice: b.base,
			hardness: phys.hardness,
			tool: phys.tool,
			minTier: phys.minTier,
			dropsAs: phys.dropsAs ?? null,
			itemOnly: phys.itemOnly ?? false,
			upgradeCounter: counterByBlock[b.id] ?? null,
		};
	}
	locations.push({
		id: loc.id,
		kind: dec.kind ?? "mine",
		name: loc.name,
		unlockLevel: loc.level,
		requiresPass: loc.requiresPass ?? false,
		pvp: dec.pvp ?? (loc.level >= decisions.pvpFromLevel && loc.id !== "fraction_base"),
		mine: {
			size: dec.size ?? def.size,
			resetSeconds: dec.resetSeconds ?? def.resetSeconds,
			warnSeconds: dec.warnSeconds ?? def.warnSeconds,
			shares,
		},
		mines: Object.fromEntries(Object.entries(decisions.mines).filter(([k, v]) => k.startsWith(loc.id + "_") && v.shares).map(([k, v]) => [k, { shares: v.shares, source: v._source || "[решение]" }])), // per-mine overrides (e.g. prison_small)
		sellList: loc.blocks.map((b) => b.id),
		sharesSource: wikiShares ? "[меню]" : "[решение]",
	});
}
write("blocks.json", { source: "wiki/in-game-wiki/block-prices.json [меню]; твёрдость [ваниль]", money: decisions.money, blocks });
write("locations.json", { source: "wiki/in-game-wiki/block-prices.json [меню]; размеры/доли/таймеры [решение]", locations });

// ---------------------------------------------------------------- tools and gear
const val = (r) => r.exactValue ?? r.approximateValue ?? null;
function tiers(level) {
	return ["wood", "stone", "iron", "diamond"][Math.min(3, Math.floor((level - 1) / 4))];
}
function fromTransitions(list, mapReq) {
	return list.map((t) => ({
		from: t.fromLevel,
		to: t.toLevel,
		cost: t.cost.exactValue,
		requirements: mapReq(t),
		enchantAfter: (t.efficiencyChange ?? t.enchantmentChange)?.after ?? 0,
		materialAfter: tiers(t.toLevel),
	}));
}
const reqMap = (t) => Object.fromEntries(Object.entries(t.requirements).map(([k, v]) => [k, val(v)]));
const tools = {
	pickaxe: { buyPrice: decisions.toolShop.pickaxe, enchant: "efficiency", upgrades: fromTransitions(pickaxeWiki.transitions, reqMap) },
	shovel: { buyPrice: decisions.toolShop.shovel, enchant: "efficiency", upgrades: fromTransitions(otherWiki.shovel.transitions, reqMap) },
	sword: { buyPrice: null, enchant: "sharpness", upgrades: fromTransitions(otherWiki.sword.transitions, reqMap) },
};
const armorReq = (t) => {
	const r = {};
	if (t.counterThreshold && t.requiredCounter) r[t.requiredCounter] = t.counterThreshold.exactValue ?? t.counterThreshold.approximateValue;
	if (t.armorerLevel) r["Оружейник"] = t.armorerLevel;
	return r;
};
for (const [id, item] of Object.entries(armorWiki.items)) {
	tools[id] = {
		buyPrice: id === "axe" ? decisions.toolShop.axe : null,
		enchant: id === "axe" ? "efficiency" : "protection",
		upgrades: item.transitions.map((t) => ({
			from: t.fromLevel,
			to: t.toLevel,
			cost: t.moneyCost,
			requirements: armorReq(t),
			enchantAfter: t.enchantmentChangeShown?.after ?? 0,
			materialAfter: tiers(t.toLevel),
		})),
	};
}
// Sword upgrades beyond 12 need Оружейник from the sword table (field "Оружейник" is inside requirements already as a counter name).
write("tools.json", {
	source: "wiki/client-audit/content-analysis/*-recovery.json [меню]; материал по уровню — интерпретация",
	vanilla: {
		swordDamage: { wood: 4, stone: 5, iron: 6, diamond: 7 },
		sharpnessBonus: [0, 1.0, 1.5, 2.0, 2.5, 3.0],
		toolSpeed: { hand: 1, wood: 2, stone: 4, iron: 6, diamond: 8 },
		efficiencyBonus: "level^2 + 1 added to toolSpeed",
		armorPoints: { wood: [1, 3, 2, 1], stone: [2, 5, 4, 1], iron: [2, 6, 5, 2], diamond: [3, 8, 6, 3] },
		armorToughness: { wood: 0, stone: 0, iron: 0, diamond: 2 },
		protectionPerLevelPerPiece: 0.04,
		maxEpf: 20,
	},
	tools,
});

// ---------------------------------------------------------------- bosses
const bosses = bossWiki.entries.map((e) => {
	const id = e.localizationMatch?.id ?? e.name;
	const dec = decisions.bosses[id] || {};
	return {
		id,
		name: e.name,
		location: e.location,
		unlockLevel: e.locationUnlockLevel,
		money: e.possibleRewards?.money ? [e.possibleRewards.money.min, e.possibleRewards.money.max] : null,
		ancientStars: e.possibleRewards?.ancientStars ? [e.possibleRewards.ancientStars.min, e.possibleRewards.ancientStars.max] : null,
		powderChance: e.possibleRewards?.ancientPowder ?? null,
		shard: e.possibleRewards?.shard ?? null,
		hp: dec.hp ?? null,
		damage: dec.damage ?? null,
		respawnSeconds: dec.respawnSeconds ?? null,
	};
});
for (const [id, b] of Object.entries(decisions.bosses)) if (b.name && !bosses.some((x) => x.id === id)) bosses.push({ id, name: b.name, location: b.location, unlockLevel: b.unlockLevel, money: b.money, ancientStars: b.ancientStars ?? null, powderChance: b.powderChance ?? null, shard: null, hp: b.hp, damage: b.damage, respawnSeconds: b.respawnSeconds });
write("bosses.json", { source: "boss-menu-recovery.json [меню]; hp/damage/respawn [решение]", rewards: decisions.bossRewards, bosses });

// ---------------------------------------------------------------- pure decisions
write("mobs.json", { source: "[решение]", mobs: decisions.mobs });
write("needs.json", { source: "эффекты и зоны снятия [вики]; таймеры и штрафы [решение]", ...decisions.needs });
write("trainer.json", { source: "первые требования [меню]; остальное [решение]", ...decisions.trainer });
write("keys.json", { source: "[решение]; цены ключей у обменника [меню]", starExchange: { ancient_key: 10, improved_ancient_key: 60, dispeller: 15 }, ...decisions.keys });
write("books.json", { source: "лимиты [вики]; остальное [решение]", ...decisions.books });
write("rules.json", { source: "[решение]; телепорт и UI — [владелец]", death: decisions.death, combo: decisions.combo, money: decisions.money, teleport: decisions.teleport, ui: decisions.ui, digging: decisions.digging, survival: decisions.survival });
write("effects.json", { source: "assets/cracks/ids.json + assets/sounds/ids.json — трещины и звуки блоков", cracks: read("assets/cracks/ids.json"), sounds: read("assets/sounds/ids.json") });
write("achievements.json", { source: "[меню] ступени; [владелец] цепочки по инструменту", ...decisions.achievements });
write("artifacts.json", { source: "[меню, клиент]; шансы [решение]", ...decisions.artifacts });
write("market.json", { source: "[меню] NPC-MENU-RECOVERY", ...decisions.market });
write("armor.json", { source: "assets/armor/ids.json — textured armor faces (CC BY-SA 4.0)", ...read("assets/armor/ids.json") });
write("itemvoxels.json", { source: "assets/icons/voxels.json — 3D extruded item sprites (16×16 rectangles)", ...read("assets/icons/voxels.json") });
write("icons.json", { source: "assets/icons/ids.json — Codex image gen + Studio upload; lookup: <id>_<material>, then <id>, then block texture", ...read("assets/icons/ids.json") });
write("textures.json", { source: "assets/textures/ids.json — Codex image gen + Studio upload", ...read("assets/textures/ids.json") });
write("previews.json", { source: "assets/previews/ids.json — Codex image gen + Studio upload; пусто = процедурная диорама", ...read("assets/previews/ids.json") });
// Rojo nested project for MaterialService: one MaterialVariant per texture (edit-time instances).
{
	const ids = read("assets/textures/ids.json");
	const tree = { "$className": "MaterialService" };
	for (const [id, assetId] of Object.entries(ids.textures)) {
		tree["px_" + id] = { "$className": "MaterialVariant", "$properties": { BaseMaterial: "Plastic", ColorMap: assetId, StudsPerTile: ids.studsPerTile || 4 } };
	}
	writeFileSync(join(root, "src", "materials.project.json"), JSON.stringify({ name: "materials", tree }, null, 2) + "\n");
	console.log("wrote src/materials.project.json");
}
write("professions.json", { source: "[меню] Работы/Прокачки; формула опыта [решение]", ...decisions.professions, boosters: decisions.boosters });
