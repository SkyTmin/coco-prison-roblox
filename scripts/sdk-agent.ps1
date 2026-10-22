# Claude for this project on the Agent SDK — runs on the API PROMO credits ($100 "Agent SDK, API, Batch,
# Playground, Managed Agents"; Claude Code itself is not covered and answered «Credit balance too low»)
# [владелец 22.10]. tools/sdk-agent/agent.mjs is the chat; this sets the key, the VPN proxy and installs the SDK.
#
#   C:\Users\user\Documents\coco-prison-roblox\scripts\sdk-agent.ps1                       # from any folder
#   ...\sdk-agent.ps1 -Model claude-sonnet-5-5 -TurnBudget 5
param(
	[string]$Model = "claude-opus-5-5",
	[double]$TurnBudget = 10
)
$ErrorActionPreference = "Stop"
$key = $env:ANTHROPIC_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("ANTHROPIC_API_KEY", "User") }
if (-not $key) {
	Write-Host "Нет ANTHROPIC_API_KEY. Один раз в своём PowerShell выполни:" -ForegroundColor Yellow
	Write-Host "  `$k = Read-Host 'Вставь API-ключ' -MaskInput; [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', `$k, 'User')"
	exit 1
}
$env:ANTHROPIC_API_KEY = $key
# Account-linked keys all start with sk-ant-usr-; what matters is the scope chosen when the key was made. A key
# scoped to the organization needs the workspace id in a header («not scoped to a workspace»): pick the workspace
# scope when creating the key, or set ANTHROPIC_WORKSPACE_ID once (docs/SETUP.md).
$workspace = $env:ANTHROPIC_WORKSPACE_ID
if (-not $workspace) { $workspace = [Environment]::GetEnvironmentVariable("ANTHROPIC_WORKSPACE_ID", "User") }
if ($workspace) {
	$env:ANTHROPIC_CUSTOM_HEADERS = "anthropic-workspace-id: $workspace"
}
. (Join-Path $PSScriptRoot "use-system-proxy.ps1")
$dir = Join-Path (Split-Path -Parent $PSScriptRoot) "tools\sdk-agent"
if (-not (Test-Path (Join-Path $dir "node_modules\@anthropic-ai\claude-agent-sdk"))) {
	Write-Host "Ставлю Agent SDK (один раз)…" -ForegroundColor DarkGray
	npm install --prefix $dir --no-audit --no-fund | Out-Null
}
node (Join-Path $dir "agent.mjs") --model $Model --turn-budget $TurnBudget
