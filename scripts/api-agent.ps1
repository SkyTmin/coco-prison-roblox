# A second Claude agent for this project that runs on the API credits, not on the Max subscription
# [владелец 22.10: «я подключил ключ API, настрой его и запусти под наш проект»].
#
#   .\scripts\api-agent.ps1 "Изучи структуру проекта и предложи план проверки"            # read-only
#   .\scripts\api-agent.ps1 "Исправь ... и прогони selene/stylua" -Edit -Budget 2          # may edit files
#
# --bare makes the CLI authenticate ONLY with ANTHROPIC_API_KEY (never the Max login), so every run is paid
# from the API credits; --max-budget-usd caps one run. The key is read from the user's environment variable
# (set once by the owner, see docs/SETUP.md) and is never written to the repo or printed. CLAUDE.md is passed
# as the system prompt (bare mode does not discover it). The result and its cost are printed and logged to
# %LOCALAPPDATA%\coco-api-agent.
param(
	[Parameter(Mandatory = $true, Position = 0)][string]$Task,
	[switch]$Edit,
	[double]$Budget = 1.0,
	[string]$Model = "opus"
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
. (Join-Path $PSScriptRoot "use-system-proxy.ps1")
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$tools = if ($Edit) {
	"Read,Glob,Grep,Edit,Write,Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(selene:*),Bash(stylua:*),Bash(rojo build:*),Bash(node scripts/*)"
} else {
	"Read,Glob,Grep,Bash(git status:*),Bash(git log:*),Bash(git diff:*)"
}
$mode = if ($Edit) { "acceptEdits" } else { "default" }
$cliArgs = @(
	"-p", $Task,
	"--bare",
	"--model", $Model,
	"--max-budget-usd", "$Budget",
	"--allowedTools", $tools,
	"--permission-mode", $mode,
	"--append-system-prompt-file", (Join-Path $root "CLAUDE.md"),
	"--output-format", "json",
	"--no-session-persistence"
)
$logDir = Join-Path $env:LOCALAPPDATA "coco-api-agent"
New-Item -ItemType Directory -Force $logDir | Out-Null
$log = Join-Path $logDir ("run-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json")
Write-Host "API-агент: модель $Model, лимит `$$Budget, правки: $([bool]$Edit)" -ForegroundColor Cyan
$raw = & claude @cliArgs 2>&1 | Out-String
Set-Content -Path $log -Value $raw -Encoding UTF8
try {
	$res = $raw | ConvertFrom-Json
	Write-Host ""
	Write-Host $res.result
	Write-Host ""
	Write-Host ("Стоимость: `${0:N4}, ходов: {1}, ошибка: {2}" -f $res.total_cost_usd, $res.num_turns, $res.is_error) -ForegroundColor Cyan
} catch {
	Write-Host $raw
}
Write-Host "Лог: $log"
