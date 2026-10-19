import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(fs.readFileSync(path.join(root, 'prototype-config.json'), 'utf8'));
const oreById = new Map(config.ores.map(ore => [ore.id, ore]));
const rankIndex = new Map(config.mines.map((mine, index) => [mine.id, index]));
const cents = amount => Math.round(amount * config.economy.moneyScale);
const miningSeconds = (ore, power) => Math.max(config.economy.minimumMineSeconds,
  config.economy.baseMineSeconds * ore.hardness / power);

function randomGenerator(seed) {
  let state = seed >>> 0;
  return () => {
    state += 0x6d2b79f5;
    let value = state;
    value = Math.imul(value ^ value >>> 15, value | 1);
    value ^= value + Math.imul(value ^ value >>> 7, value | 61);
    return ((value ^ value >>> 14) >>> 0) / 4294967296;
  };
}

function drawOre(mine, random) {
  let roll = random() * 100;
  for (const [id, weight] of Object.entries(mine.weights)) {
    roll -= weight;
    if (roll < 0) return oreById.get(id);
  }
  throw new Error('Invalid probability table');
}

function simulate(route, seed) {
  const random = randomGenerator(seed);
  let elapsed = 0, balance = cents(config.economy.startingCash), rank = 0;
  let pickaxe = 0, backpack = 0, mined = 0, earned = 0, spent = 0;
  let firstBag = null, firstUpgrade = null;
  const milestones = {};
  const purchases = [];
  while (elapsed < config.model.maximumSimulatedSeconds) {
    let bagValue = 0;
    const mine = config.mines[rank];
    for (let slot = 0; slot < config.backpacks[backpack].capacity; slot++) {
      const ore = drawOre(mine, random);
      elapsed += miningSeconds(ore, config.pickaxes[pickaxe].power);
      bagValue += cents(ore.sellPrice);
      mined++;
    }
    elapsed += config.economy.sellTripSeconds;
    if (firstBag === null) firstBag = elapsed;
    balance += bagValue;
    earned += bagValue;

    function buy(kind, item) {
      const cost = cents(item.purchaseCost);
      if (rankIndex.get(item.minimumRank) > rank || balance < cost) return false;
      balance -= cost;
      spent += cost;
      purchases.push({kind, level:item.level, time:elapsed, cost});
      if (firstUpgrade === null) firstUpgrade = elapsed;
      return true;
    }
    if (route.buyPickaxes && pickaxe + 1 < config.pickaxes.length &&
        buy('pickaxe', config.pickaxes[pickaxe + 1])) pickaxe++;
    if (route.buyBackpacks && backpack + 1 < config.backpacks.length &&
        buy('backpack', config.backpacks[backpack + 1])) backpack++;

    if (rank + 1 < config.mines.length && balance >= cents(config.mines[rank + 1].unlockCost)) {
      const cost = cents(config.mines[rank + 1].unlockCost);
      balance -= cost;
      spent += cost;
      rank++;
      milestones[config.mines[rank].id] = elapsed;
    }
    if (config.mines[rank].id === config.prestige.requiredRank &&
        balance >= cents(config.prestige.cashCost)) {
      const prestigeCost = cents(config.prestige.cashCost);
      balance -= prestigeCost;
      spent += prestigeCost;
      assert.equal(balance, earned - spent);
      assert.ok(balance >= 0);
      assert.equal(Object.keys(milestones).length, config.mines.length - 1);
      return {firstBag, firstUpgrade, B:milestones.B, C:milestones.C, prestige:elapsed,
        mined, earned, spent, cashBeforeReset:balance, tokens:Math.floor(mined / config.economy.tokenEveryMinedBlocks),
        purchases};
    }
  }
  throw new Error(`Simulation exceeded time limit: ${route.id}`);
}

function percentile(values, fraction) {
  const sorted = [...values].sort((a,b) => a-b);
  return sorted[Math.floor((sorted.length - 1) * fraction)];
}

assert.equal(new Set(config.ores.map(ore => ore.id)).size, config.ores.length);
assert.equal(config.prestige.maximumLevel, 1);
assert.equal(config.economy.startingCash, 0);
for (const ore of config.ores) {
  assert.ok(ore.sellPrice > 0 && ore.hardness > 0);
  for (let i = 1; i < config.pickaxes.length; i++) {
    assert.ok(miningSeconds(ore, config.pickaxes[i].power) <= miningSeconds(ore, config.pickaxes[i-1].power));
  }
}
const mineStats = config.mines.map(mine => {
  assert.equal(Object.values(mine.weights).reduce((a,b) => a+b, 0), 100);
  assert.ok(Object.keys(mine.weights).every(id => oreById.has(id)));
  const expectedValue = Object.entries(mine.weights).reduce((sum,[id,weight]) =>
    sum + oreById.get(id).sellPrice * weight / 100, 0);
  const expectedTime = Object.entries(mine.weights).reduce((sum,[id,weight]) =>
    sum + miningSeconds(oreById.get(id), 1) * weight / 100, 0);
  const expectedCashPerSecond = expectedValue /
    (expectedTime + config.economy.sellTripSeconds / config.backpacks[0].capacity);
  return {id:mine.id, expectedValue, expectedMineSeconds:expectedTime, expectedCashPerSecond};
});
for (let i=1; i<mineStats.length; i++) assert.ok(mineStats[i].expectedValue > mineStats[i-1].expectedValue);
for (let p=0; p<config.economy.saleMultiplierByPrestige.length; p++) {
  assert.ok(config.economy.saleMultiplierByPrestige[p] > 0);
}
const routes = config.routes.map(route => {
  const runs = Array.from({length:config.model.runs}, (_,index) => simulate(route, config.model.seed + index));
  const metrics = {};
  for (const name of ['firstBag','firstUpgrade','B','C','prestige','mined','tokens']) {
    const values = runs.map(run => run[name]).filter(value => value !== null);
    metrics[name] = values.length ? {p10:percentile(values,.1), median:percentile(values,.5), p90:percentile(values,.9)} : null;
  }
  return {id:route.id, label:route.label, metrics, sample:runs[0]};
});
const output = {status:'superseded_mining_only_v0.1', scope:'Archive only: does not estimate the Cristalix-inspired RPG chapter', assumptions:config.model,
  formulas:{sale:'sum(ore quantity * sale price); first cycle multiplier = 1',
    mining:'max(minimumMineSeconds, baseMineSeconds * hardness / pickaxePower)',
    bag:'one unit per block; no yield bonus modeled',
    purchases:'after full-bag sale: next eligible pickaxe, next eligible backpack, next rank, prestige'},
  resetModel:'Common-mine contention, reset pauses and player movement variation are excluded.',
  mineStats, routes};
fs.writeFileSync(path.join(root, 'balance-results.json'), JSON.stringify(output,null,2)+'\n');
const minutes = seconds => (seconds / 60).toFixed(1);
let report = '# Архив: расчёт шахтёрского цикла v0.1\n\nЭта модель заменена расширенным замыслом RPG в PROTOTYPE-SPEC.md. Она не учитывает дерево, землю, бои, задания и потребности. Её время до престижа не является оценкой новой игры.\n\nЭто модель активной игры, а не результат прохождения Roblox. ';
report += `По ${config.model.runs} прогонов на маршрут с фиксированным seed.\n\n`;
report += '| Маршрут | Ранг B, мин | Ранг C, мин | Престиж, мин | Престиж P10–P90, мин |\n| --- | ---: | ---: | ---: | ---: |\n';
for (const route of routes) {
  const m=route.metrics;
  report += `| ${route.label} | ${minutes(m.B.median)} | ${minutes(m.C.median)} | ${minutes(m.prestige.median)} | ${minutes(m.prestige.p10)}–${minutes(m.prestige.p90)} |\n`;
}
report += '\n| Шахта | Средняя цена блока | Среднее время блока базовой киркой, с | Доход с учётом продажи, монет/с |\n| --- | ---: | ---: | ---: |\n';
for (const mine of mineStats) report += `| ${mine.id} | ${mine.expectedValue.toFixed(2)} | ${mine.expectedMineSeconds.toFixed(3)} | ${mine.expectedCashPerSecond.toFixed(2)} |\n`;
report += '\nРюкзак продаётся целиком после заполнения. Время пути к продаже и обратно — 10 с на сумку. Покупки делаются только после продажи; их порядок указан в balance-results.json. Токены учитываются по числу блоков, но их трата и бонус добычи не моделируются.\n\n';
report += 'Не учтены паузы игрока, обучение, выбор только дорогой руды, конкуренция за блоки, восстановление шахт и задержки сети. Модель добывает случайную последовательность по составу шахты. P10–P90 показывает только разброс этой последовательности. Реальные сессии могут отличаться в обе стороны.\n\n';
report += 'Проверки: суммы вероятностей, известные ID руд, рост ценности шахт, ускорение кирки, неотрицательный баланс, сохранение баланса earned − spent, прохождение рангов по порядку и завершение всех прогонов.\n\n';
report += 'Повторный запуск: `node simulate-balance.mjs` из этой папки. Цены и правила находятся в prototype-config.json.\n';
fs.writeFileSync(path.join(root, 'BALANCE.md'), report);
console.log(JSON.stringify({runs:config.model.runs * routes.length, routes:routes.map(route =>
  ({id:route.id, B:minutes(route.metrics.B.median), C:minutes(route.metrics.C.median), prestige:minutes(route.metrics.prestige.median)}))}));
