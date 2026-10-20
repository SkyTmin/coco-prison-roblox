// Economy pace simulation: minutes of continuous digging to reach each level.
// Model: one player, always digs in the best unlocked mine by $/s for the current tool,
// sells instantly, buys/upgrades tools greedily, levels up as soon as blocks and money allow.
// Needs, bosses, combo and key drops are ignored (conservative estimate).
// Usage: node scripts/simulate-economy.mjs [maxLevel=15]
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const cfg = (n) => JSON.parse(readFileSync(join(root, "src", "shared", "Config", n), "utf8"));
const levels = cfg("levels.json");
const { blocks } = cfg("blocks.json");
const { locations } = cfg("locations.json");
const toolsCfg = cfg("tools.json");
const maxLevel = Number(process.argv[2] ?? 15);

const TIER_INDEX = { wood: 0, stone: 1, iron: 2, diamond: 3 };
const TOOL_SPEED = toolsCfg.vanilla.toolSpeed;
const TICK = 0.05;
const OVERHEAD = 0.2; // seconds per block: aim + step, caps digging at ~5 blocks/s

function toolState(id, level) {
	const t = toolsCfg.tools[id];
	const up = t.upgrades.find((u) => u.to === level);
	const material = level === 1 ? "wood" : up.materialAfter;
	const enchant = level === 1 ? 0 : up.enchantAfter;
	return { material, enchant };
}
function breakTime(block, tool) {
	if (block.itemOnly) return null;
	if (block.tool === "any") return Math.max(TICK, (block.hardness * 1.5) / 1);
	if (!tool) return null;
	const { material, enchant } = tool;
	if (TIER_INDEX[material] < block.minTier) return null;
	const mult = TOOL_SPEED[material] + (enchant > 0 ? enchant * enchant + 1 : 0);
	return Math.max(TICK, (block.hardness * 1.5) / mult);
}

const player = {
	level: 1,
	money: 0,
	blocksTotal: 0,
	counters: {}, // upgrade counters: Земля, Камень, Крысы...
	tools: { shovel: 1, pickaxe: 0, axe: 0 },
	seconds: 0,
};
const milestones = [];
const log = [];

function priceMultiplier() {
	return 1 + 0.01 * (player.level - 1);
}
function bestMine() {
	let best = null;
	for (const loc of locations) {
		if (loc.unlockLevel > player.level || loc.requiresPass || loc.kind !== "mine") continue;
		let dollarsPerSec = 0;
		let total = 0;
		let detail = [];
		for (const [bid, share] of Object.entries(loc.mine.shares)) {
			const b = blocks[bid];
			const toolLevel = player.tools[b.tool];
			const tool = toolLevel > 0 ? toolState(b.tool, toolLevel) : null;
			const t = breakTime(b, tool);
			if (t === null) continue; // can't harvest this block type yet
			const sellId = b.dropsAs ?? bid;
			const price = blocks[sellId].basePrice * priceMultiplier();
			dollarsPerSec += (share * price) / (t + OVERHEAD); // +0.1 s to move to the next block
			total += share;
			detail.push({ bid, t, price });
		}
		if (total === 0) continue;
		const blocksPerSec = detail.reduce((s, d) => s + (loc.mine.shares[d.bid] / total) / (d.t + OVERHEAD), 0);
		const cand = { loc, dollarsPerSec: dollarsPerSec / total, blocksPerSec, detail, total };
		// Real players move to the newest mine as soon as most of it is diggable (prices grow ~x4 per tier).
		if (!best || (total >= 0.5 && loc.unlockLevel >= best.loc.unlockLevel) || (best.total < 0.5 && cand.dollarsPerSec > best.dollarsPerSec)) best = cand;
	}
	return best;
}
function tryUpgrades() {
	for (const toolId of ["shovel", "pickaxe", "axe"]) {
		const t = toolsCfg.tools[toolId];
		if (player.tools[toolId] === 0) {
			// buy when the first mine that needs it is unlocked
			const needed = locations.some((l) => l.kind === "mine" && l.unlockLevel <= player.level && !l.requiresPass && Object.keys(l.mine.shares).some((b) => blocks[b].tool === toolId));
			if (needed && player.money >= t.buyPrice) {
				player.money -= t.buyPrice;
				player.tools[toolId] = 1;
				log.push(`${fmt(player.seconds)} buy ${toolId}`);
			}
			continue;
		}
		const up = t.upgrades.find((u) => u.from === player.tools[toolId]);
		if (!up) continue;
		const ok = Object.entries(up.requirements).every(([k, v]) => v == null || (player.counters[k] ?? 0) >= v);
		if (ok && player.money >= up.cost) {
			player.money -= up.cost;
			player.tools[toolId] = up.to;
			log.push(`${fmt(player.seconds)} ${toolId} -> ${up.to} (${up.cost}$)`);
		}
	}
}
function tryLevelUp() {
	const next = levels.levels.find((l) => l.level === player.level + 1);
	if (!next) return false;
	if (player.blocksTotal >= next.blocks && player.money >= next.money) {
		player.money -= next.money;
		player.level = next.level;
		const bound = blocksReadyAt === null ? "blocks" : moneyReadyAt === null ? "money" : blocksReadyAt > moneyReadyAt ? "blocks" : "money";
		blocksReadyAt = null; moneyReadyAt = null;
		milestones.push({ level: player.level, minutes: player.seconds / 60, money: player.money, tools: { ...player.tools }, bound, mine: lastMine });
		return true;
	}
	return false;
}
const fmt = (s) => `${Math.floor(s / 60)}m${String(Math.floor(s % 60)).padStart(2, "0")}s`;

let blocksReadyAt = null, moneyReadyAt = null, lastMine = null;
while (player.level < maxLevel && player.seconds < 3600 * 200) {
	tryUpgrades();
	if (tryLevelUp()) continue;
	const mine = bestMine(); lastMine = mine.loc.id;
	if (!mine) throw new Error("nothing diggable");
	// dig 10 blocks worth of time
	for (let i = 0; i < 10; i++) {
		let r = Math.random() * mine.total;
		let chosen = mine.detail[mine.detail.length - 1];
		for (const d of mine.detail) {
			r -= mine.loc.mine.shares[d.bid];
			if (r <= 0) { chosen = d; break; }
		}
		player.seconds += chosen.t + OVERHEAD;
		player.blocksTotal += 1;
		player.money += chosen.price;
		const b = blocks[chosen.bid];
		if (b.upgradeCounter) player.counters[b.upgradeCounter] = (player.counters[b.upgradeCounter] ?? 0) + 1;
	}
	const next = levels.levels.find((l) => l.level === player.level + 1);
	if (blocksReadyAt === null && player.blocksTotal >= next.blocks) blocksReadyAt = player.seconds;
	if (moneyReadyAt === null && player.money >= next.money) moneyReadyAt = player.seconds;
}

console.log("Темп (чистое копание, без нужд/боссов/комбо):");
console.log("уровень | минут | накоплено $ | лопата | кирка | шахта | что держало этот уровень");
for (const m of milestones) {
	console.log(`${String(m.level).padStart(7)} | ${m.minutes.toFixed(1).padStart(5)} | ${m.money.toFixed(2).padStart(11)} | ${String(m.tools.shovel).padStart(6)} | ${String(m.tools.pickaxe).padStart(5)} | ${String(m.mine).padStart(13)} | ${m.bound}`);
}
console.log("\nПокупки и улучшения:");
for (const l of log) console.log("  " + l);
