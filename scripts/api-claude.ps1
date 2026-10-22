# The working Claude for this project on the API credits, for when the Max limit runs out
# [владелец 22.10: «мне чтобы он работал, у тебя сейчас лимит будет. Он будет работать вместо тебя»].
#
#   C:\Users\user\Documents\coco-prison-roblox\scripts\api-claude.ps1            # from any folder
#
# Opens an interactive Claude Code session in the project folder with ANTHROPIC_API_KEY set, so it reads CLAUDE.md,
# the skills and the user-scope MCP servers (Roblox Studio, Codex) like the desktop session. On the first start
# Claude Code asks whether to use the detected API key: answer Yes. `/status` inside shows the API key as the
# login, `/cost` the money spent. Only one Claude may drive Roblox Studio at a time (CLAUDE.md, Studio loop §6):
# close the other session's Studio work first. The key comes from the user's environment variable (set once,
# docs/SETUP.md) and is never printed or written to the repo.
param([string]$Model = "opus")
$ErrorActionPreference = "Stop"
$key = $env:ANTHROPIC_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("ANTHROPIC_API_KEY", "User") }
if (-not $key) {
	Write-Host "Нет ANTHROPIC_API_KEY. Один раз в своём PowerShell выполни:" -ForegroundColor Yellow
	Write-Host "  `$k = Read-Host 'Вставь API-ключ' -MaskInput; [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', `$k, 'User')"
	exit 1
}
$env:ANTHROPIC_API_KEY = $key
. (Join-Path $PSScriptRoot "use-system-proxy.ps1")
Set-Location (Split-Path -Parent $PSScriptRoot)
Write-Host "Claude на API-кредитах, модель $Model, папка $(Get-Location)." -ForegroundColor Cyan
Write-Host "Если спросит про найденный API-ключ — ответь Yes. /status — чем вошёл, /cost — сколько потрачено." -ForegroundColor Cyan
claude --model $Model
