# Studio Relay

Lets a cloud agent session drive the owner's Roblox Studio without any process on the owner's PC.

```
agent (cloud) --HTTPS--> Worker (Cloudflare, Durable Object "main") <--long-poll-- plugin in Studio
```

- `worker/` — Cloudflare Worker + Durable Object (in-memory queues/results/logs; pairing and plugin
  tokens in storage). Secret `AGENT_TOKEN` authenticates the agent. Deploy: `cd worker && npx wrangler deploy`
  (API token via the session proxy), `npx wrangler secret put AGENT_TOKEN`.
- `plugin/StudioRelay.server.luau` → `node build-plugin.mjs` → `StudioRelay.rbxmx` (relay URL baked in).
  The owner drops it into `%LOCALAPPDATA%\Roblox\Plugins`, presses «Подключить», gives the 6-digit code.
  The plugin runs in every DataModel: `edit`, and during a test `server`, `client` (+ `client:<Name>`).
  Widget: «Пауза» stops taking commands, «Отключить и забыть» revokes its token.
- `agent.mjs` — the agent's CLI (`status`, `pair`, `run`, `shot`, `logs`, `play`/`runmode`/`stop`, `sync`,
  `revoke`). URL from `relay.json` or `RELAY_URL`; the Authorization header is injected by the session proxy
  (saved network credential for the relay host), or `RELAY_TOKEN` locally.

Replaces the Studio MCP loop of CLAUDE.md: `execute_luau` → `agent.mjs run <dm> file.luau`, the
serve-repo/loader sync → `agent.mjs sync [list]`, `screen_capture` → `agent.mjs shot`, `get_console_output`
→ `agent.mjs logs`, `start_stop_play` → `play` / `stop`. Screenshots: CaptureService → EditableImage →
RGB, ≤ 1024 px; an all-black frame is reported as an error. Local test: `wrangler dev` + a fake plugin.
