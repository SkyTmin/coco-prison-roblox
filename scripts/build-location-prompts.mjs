// Builds the concept-art prompts for the next locations from docs/research/location-prompts.json:
//   docs/research/location-concept-prompts.md  — the list for the repo
//   docs/research/location-prompts.html        — the phone page with copy buttons (published as an Artifact)
// node scripts/build-location-prompts.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dir = path.join(ROOT, "docs", "research");
const data = JSON.parse(fs.readFileSync(path.join(dir, "location-prompts.json"), "utf8"));

function fullPrompt(loc) {
	const gameplay = data.gameplay.replace("{ARENA}", loc.arena ? data.arena : data.summit);
	const place = loc.enclosed
		? "The level is a closed area surrounded by walls and fences; nothing else is visible on the horizon."
		: data.island;
	const sheet = data.sheet.replace("{PANEL3}", loc.arena ? "the boss arena" : "the summit");
	return [loc.prompt, data.style, gameplay, place, sheet].join("\n\n");
}

const locs = data.locations.map((l) => ({ ...l, full: fullPrompt(l) }));

// markdown
const md = [
	"# Промпты для концепт-референсов локаций",
	"",
	"Сгенерировано `node scripts/build-location-prompts.mjs` из [location-prompts.json](location-prompts.json). Каждый промпт самодостаточный: копировать целиком в генератор картинок (ChatGPT и т. п.), получится лист 2×2 — карта сверху, вид со старта, арена/вершина, крупные детали. Готовые картинки — в `assets/concepts/<id>/`, по ним строится локация.",
	"",
	...locs.flatMap((l) => [
		`## ${l.level} · ${l.name}${l.boss ? ` — босс ${l.boss}` : ""}`,
		"",
		l.ru,
		"",
		"```text",
		l.full,
		"```",
		"",
	]),
].join("\n");
fs.writeFileSync(path.join(dir, "location-concept-prompts.md"), md);

// style references: our own screenshots the owner picked as «наш стиль» (Подножье горы, Пустотная крепость)
const refs = [
	["style-ref-mountain-foot.jpg", "Подножье горы"],
	["style-ref-end-castle.jpg", "Пустотная крепость"],
].map(([file, label]) => ({
	label,
	src: "data:image/jpeg;base64," + fs.readFileSync(path.join(ROOT, "assets", "screenshots", file)).toString("base64"),
}));

// phone page
const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const cards = locs
	.map(
		(l) => `<article class="card" id="${l.id}">
  <header class="card-head">
    <span class="lvl">${l.level}</span>
    <div class="titles"><h2>${esc(l.name)}</h2><p class="boss">${l.boss ? "Босс: " + esc(l.boss) : "Небесная шахта, без босса"}</p></div>
  </header>
  <p class="ru">${esc(l.ru)}</p>
  <button class="copy" type="button" data-target="p-${l.id}" id="b-${l.id}">Скопировать промпт</button>
  <details><summary>Показать текст</summary><pre id="p-${l.id}">${esc(l.full)}</pre></details>
</article>`,
	)
	.join("\n");

const html = `<title>Промпты локаций</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Golos+Text:wght@400;600&family=Unbounded:wght@600;800&family=JetBrains+Mono:wght@400&display=swap">
<style>
/* Layout: a single column of prison-tag cards, one per level, read and copied on a phone. */
:root {
  --bg: #eceae6; --panel: #f8f7f4; --ink: #1d1b19; --muted: #6b655e; --line: #d4d0c8;
  --accent: #c8321e; --accent-ink: #ffffff; --lvl: #2b2724; --lvl-ink: #f2c94c;
  --display: "Unbounded", "Arial Black", sans-serif; --body: "Golos Text", "Segoe UI", system-ui, sans-serif;
  --mono: "JetBrains Mono", ui-monospace, Consolas, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #171513; --panel: #221f1c; --ink: #ece7df; --muted: #a39b90; --line: #3a3530;
  --accent: #e2533d; --accent-ink: #ffffff; --lvl: #f2c94c; --lvl-ink: #1d1b19; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #171513; --panel: #221f1c; --ink: #ece7df; --muted: #a39b90; --line: #3a3530;
  --accent: #e2533d; --accent-ink: #ffffff; --lvl: #f2c94c; --lvl-ink: #1d1b19; color-scheme: dark }
body { background: var(--bg); color: var(--ink); font: 15px/1.5 var(--body);
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 20px 40px; }
.wrap { max-width: 760px; margin: 0 auto; display: grid; gap: 16px; }
h1 { font: 800 clamp(22px, 6vw, 34px)/1.1 var(--display); margin: 0; text-wrap: balance; letter-spacing: -0.01em; }
.lead { color: var(--muted); margin: 0; max-width: 62ch; }
.how { background: var(--panel); border: 1px solid var(--line); border-radius: 6px; padding: 12px 14px; display: grid; gap: 4px; }
.how b { font-family: var(--display); font-weight: 600; font-size: 12px; letter-spacing: 0.06em; text-transform: uppercase; }
.refs { display: grid; gap: 10px; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); }
.refs figure { margin: 0; background: var(--panel); border: 1px solid var(--line); border-radius: 6px; overflow: hidden; }
.refs img { display: block; width: 100%; height: auto; }
.refs figcaption { padding: 6px 10px; font-size: 13px; color: var(--muted); }
.card { background: var(--panel); border: 1px solid var(--line); border-radius: 6px; padding: 14px; display: grid; gap: 10px; min-width: 0; }
.card-head { display: flex; gap: 12px; align-items: center; }
.lvl { flex: none; width: 44px; height: 44px; display: grid; place-items: center; background: var(--lvl); color: var(--lvl-ink);
  font: 800 17px var(--display); border-radius: 4px; font-variant-numeric: tabular-nums; }
.titles { min-width: 0; }
h2 { font: 600 18px/1.2 var(--display); margin: 0; text-wrap: balance; }
.boss { margin: 2px 0 0; color: var(--muted); font-size: 13px; }
.ru { margin: 0; }
.copy { justify-self: start; background: var(--accent); color: var(--accent-ink); border: 0; border-radius: 4px; padding: 10px 16px;
  font: 600 15px var(--body); cursor: pointer; min-height: 44px; }
.copy:focus-visible, summary:focus-visible { outline: 3px solid var(--lvl); outline-offset: 2px; }
.copy.done { background: var(--lvl); color: var(--lvl-ink); }
details summary { cursor: pointer; color: var(--muted); font-size: 13px; }
pre { white-space: pre-wrap; word-break: break-word; font: 12.5px/1.5 var(--mono); background: var(--bg); border: 1px solid var(--line);
  border-radius: 4px; padding: 10px; margin: 8px 0 0; max-height: 360px; overflow: auto; user-select: all; }
@media (prefers-reduced-motion: no-preference) { .copy { transition: background-color .15s; } }
</style>
<div class="wrap">
  <h1>Промпты локаций Prison</h1>
  <p class="lead">По одному на каждый следующий этаж. Каждый промпт полный: в нём уже есть стиль, масштаб, шахта, старт, арена и раскладка листа 2×2.</p>
  <div class="how">
    <b>Как пользоваться</b>
    <span>1. Сохрани один из скриншотов ниже (долгое нажатие на картинку). Это образец нашего стиля.</span>
    <span>2. Нажми «Скопировать промпт», вставь в генератор картинок (ChatGPT и т. п.) и прикрепи сохранённый скриншот к тому же сообщению.</span>
    <span>3. Сохрани результат и пришли мне вместе с названием локации.</span>
    <span>4. Если лимит маленький — сначала Рынок, Лепреконовая долина и Замок: они следующие.</span>
  </div>
  <div class="refs">
${refs.map((r) => `    <figure><img src="${r.src}" alt="Скриншот нашей игры: ${esc(r.label)}" loading="lazy"><figcaption>Образец стиля: ${esc(r.label)}</figcaption></figure>`).join("\n")}
  </div>
${cards}
</div>
<script>
document.querySelectorAll(".copy").forEach((btn) => {
  btn.addEventListener("click", () => {
    const pre = document.getElementById(btn.dataset.target);
    const text = pre.textContent;
    const ok = () => { btn.textContent = "Скопировано"; btn.classList.add("done"); setTimeout(() => { btn.textContent = "Скопировать промпт"; btn.classList.remove("done"); }, 2000); };
    const fallback = () => { pre.closest("details").open = true; const r = document.createRange(); r.selectNodeContents(pre); const s = getSelection(); s.removeAllRanges(); s.addRange(r); btn.textContent = "Текст выделен — скопируй"; };
    try { navigator.clipboard.writeText(text).then(ok, fallback); } catch (e) { fallback(); }
  });
});
</script>
`;
fs.writeFileSync(path.join(dir, "location-prompts.html"), html);
console.log(`prompts: ${locs.length}; longest ${Math.max(...locs.map((l) => l.full.length))} chars`);
