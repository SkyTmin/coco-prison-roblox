# Dot-sourced by api-claude.ps1 / api-agent.ps1. Claude Code in a plain terminal ignores the Windows system proxy,
# so with the VPN (Happ, 127.0.0.1:10809) it cannot reach api.anthropic.com (ECONNREFUSED) [владелец 22.10]. This
# copies the system proxy into HTTPS_PROXY / HTTP_PROXY for this process only, unless they are already set.
$inet = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
if ($inet -and $inet.ProxyEnable -eq 1 -and $inet.ProxyServer -and -not $env:HTTPS_PROXY) {
	# "host:port" or "http=host:port;https=host:port"
	$server = $inet.ProxyServer
	if ($server -match 'https=([^;]+)') { $server = $Matches[1] } elseif ($server -match 'http=([^;]+)') { $server = $Matches[1] }
	if ($server -notmatch '^\w+://') { $server = "http://$server" }
	$env:HTTPS_PROXY = $server
	$env:HTTP_PROXY = $server
	if (-not $env:NO_PROXY) { $env:NO_PROXY = "localhost,127.0.0.1" }
	Write-Host "Прокси системы (VPN): $server" -ForegroundColor DarkGray
}
