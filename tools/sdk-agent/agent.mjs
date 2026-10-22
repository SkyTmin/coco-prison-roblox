// The project's Claude on the Agent SDK, so it runs on the API promo credits [владелец 22.10: «он будет
// работать вместо тебя»]. The $100 promo credits cover the API, the Agent SDK, Batch, Playground and Managed
// Agents — not Claude Code, which answered «Credit balance too low». Start it with scripts/sdk-agent.ps1 (key,
// VPN proxy, dependencies). It reads CLAUDE.md, the project skills and the user's MCP servers (Roblox Studio,
// Codex) like a Claude Code session; edits inside the project are allowed, shell commands and MCP tools ask.
//
//   /exit — quit · /cost — money spent · /model <id> — switch the model · /new — a fresh conversation
//   Ctrl+C while it works stops the current answer; Ctrl+C at the prompt quits.
import { query } from "@anthropic-ai/claude-agent-sdk";
import readline from "node:readline/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const args = process.argv.slice(2);
const flag = (name, fallback) => {
	const i = args.indexOf(name);
	return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
let model = flag("--model", "claude-opus-5-5");
const turnBudget = Number(flag("--turn-budget", "10")); // USD a single answer may spend at most

// read-only and housekeeping tools never ask; Edit/Write go through acceptEdits; everything else asks once
const SAFE = new Set(["Read", "Glob", "Grep", "LS", "TodoWrite", "WebSearch", "WebFetch", "Skill", "Task", "Agent", "ToolSearch"]);
const allowedForSession = new Set();

const c = { dim: "\x1b[2m", cyan: "\x1b[36m", yellow: "\x1b[33m", red: "\x1b[31m", green: "\x1b[32m", off: "\x1b[0m" };
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
// lines through one iterator (rl.question loses lines that arrive before it is asked, e.g. piped input)
const lines = rl[Symbol.asyncIterator]();
async function ask(text) {
	process.stdout.write(text);
	const next = await lines.next();
	if (next.done) throw new Error("stdin closed");
	return next.value;
}

let sessionId = null;
let spent = 0; // USD over this window
let sessionTotal = 0; // the conversation's cumulative cost as the last result reported it
let running = null; // the active query, for Ctrl+C

function short(v, n = 160) {
	const s = typeof v === "string" ? v : JSON.stringify(v);
	return s.length > n ? s.slice(0, n) + "…" : s;
}

async function canUseTool(toolName, input) {
	if (SAFE.has(toolName) || allowedForSession.has(toolName)) {
		return { behavior: "allow", updatedInput: input };
	}
	const what = toolName === "Bash" ? input.command : short(input);
	const answer = (
		await ask(`${c.yellow}Разрешить ${toolName}: ${what}\n  [y] да · [a] да, всегда в этом окне · [n] нет > ${c.off}`)
	)
		.trim()
		.toLowerCase();
	if (answer === "a" || answer === "ф") {
		allowedForSession.add(toolName);
		return { behavior: "allow", updatedInput: input };
	}
	if (answer === "y" || answer === "н" || answer === "да" || answer === "") {
		return { behavior: "allow", updatedInput: input };
	}
	return { behavior: "deny", message: "Владелец не разрешил этот вызов." };
}

async function turn(prompt) {
	const q = query({
		prompt,
		options: {
			cwd: ROOT,
			model,
			resume: sessionId ?? undefined,
			settingSources: ["user", "project", "local"],
			systemPrompt: { type: "preset", preset: "claude_code" },
			skills: "all",
			permissionMode: "acceptEdits",
			canUseTool,
			maxBudgetUsd: turnBudget,
		},
	});
	running = q;
	try {
		for await (const msg of q) {
			if (msg.type === "system" && msg.subtype === "init") {
				sessionId = msg.session_id;
			} else if (msg.type === "assistant") {
				for (const block of msg.message.content) {
					if (block.type === "text" && block.text.trim()) {
						console.log(`\n${block.text}`);
					} else if (block.type === "tool_use") {
						console.log(`${c.dim}· ${block.name} ${short(block.input, 120)}${c.off}`);
					}
				}
			} else if (msg.type === "result") {
				sessionId = msg.session_id ?? sessionId;
				// total_cost_usd is cumulative over a resumed session: count only this answer's part
				const cost = msg.total_cost_usd ?? 0;
				const delta = Math.max(0, cost - sessionTotal);
				sessionTotal = cost;
				spent += delta;
				const err = msg.is_error || msg.subtype !== "success";
				console.log(
					`${err ? c.red : c.dim}— ${err ? "ошибка (" + msg.subtype + ") · " : ""}$${delta.toFixed(3)} за ответ, $${spent.toFixed(2)} за окно${c.off}`,
				);
			}
		}
	} catch (e) {
		console.log(`${c.red}Ошибка: ${e?.message ?? e}${c.off}`);
	} finally {
		running = null;
	}
}

process.on("SIGINT", () => {
	if (running) {
		console.log(`${c.yellow}\nОстанавливаю ответ…${c.off}`);
		running.interrupt().catch(() => {});
	} else {
		console.log(`\n$${spent.toFixed(2)} потрачено. Пока!`);
		process.exit(0);
	}
});

console.log(`${c.cyan}Claude на Agent SDK (промо-кредиты API) · модель ${model} · ${ROOT}`);
console.log(`/exit — выход · /cost — потрачено · /model <id> — модель · /new — новый разговор${c.off}`);
for (;;) {
	let line;
	try {
		line = (await ask(`\n${c.green}> ${c.off}`)).trim();
	} catch {
		break; // stdin closed
	}
	if (!line) continue;
	if (line === "/exit" || line === "/quit") break;
	if (line === "/cost") {
		console.log(`$${spent.toFixed(2)} за это окно`);
		continue;
	}
	if (line === "/new") {
		sessionId = null;
		sessionTotal = 0;
		console.log("Новый разговор.");
		continue;
	}
	if (line.startsWith("/model")) {
		const id = line.split(/\s+/)[1];
		if (id) model = id;
		console.log(`Модель: ${model}`);
		continue;
	}
	await turn(line);
}
console.log(`$${spent.toFixed(2)} потрачено. Пока!`);
rl.close();
process.exit(0);
