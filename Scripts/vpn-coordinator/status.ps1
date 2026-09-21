<#
.SYNOPSIS
    Displays live status of Surfshark, Tailscale, and VpnCoordinator service.
#>

$TailscaleExe = "C:\Program Files\Tailscale\tailscale.exe"
$serviceName  = 'VpnCoordinator'
$scriptDir    = $PSScriptRoot
$logFile      = Join-Path $scriptDir 'vpn-coordinator.log'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " VPN Coordinator Status Report - VISH-HOMESERVER" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Surfshark
$surfsharkAdapters = Get-NetAdapter -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'Surfshark' }
Write-Host "`n[Surfshark VPN Status]" -ForegroundColor Yellow
if ($surfsharkAdapters) {
    foreach ($a in $surfsharkAdapters) {
        $ip = (Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.AddressState -eq 'Preferred' -and $_.IPAddress -notlike '169.254.*' }).IPAddress
        Write-Host ("  Adapter: {0,-25} Status: {1,-12} IP: {2}" -f $a.Name, $a.Status, ($ip -join ', '))
    }
} else {
    Write-Host "  No Surfshark adapters detected." -ForegroundColor Red
}

# 2. Tailscale
Write-Host "`n[Tailscale Status]" -ForegroundColor Yellow
$tsSvc = Get-Service -Name Tailscale -ErrorAction SilentlyContinue
Write-Host ("  Windows Service: {0} ({1})" -f $tsSvc.Status, $tsSvc.StartType)
if (Test-Path $TailscaleExe) {
    try {
        $json = & $TailscaleExe status --json 2>$null | ConvertFrom-Json
        $tsBackend = if ($json.BackendState) { $json.BackendState } else { 'Stopped' }
        $tsIPs = if ($json.Self.TailscaleIPs) { $json.Self.TailscaleIPs -join ', ' } else { 'None' }
        Write-Host ("  Backend State:   {0}" -f $tsBackend)
        Write-Host ("  Tailscale IPs:   {0}" -f $tsIPs)
    } catch {
        Write-Host "  Backend State:   Stopped / Error querying"
    }
} else {
    Write-Host "  Tailscale executable not found." -ForegroundColor Red
}

# 3. Coordinator Service
Write-Host "`n[VpnCoordinator Service]" -ForegroundColor Yellow
$coordSvc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($coordSvc) {
    Write-Host ("  Service: {0} | Status: {1} | StartType: {2}" -f $serviceName, $coordSvc.Status, $coordSvc.StartType)
} else {
    Write-Host "  Service '$serviceName' is NOT installed." -ForegroundColor DarkYellow
}

# 4. Recent Logs
Write-Host "`n[Recent Coordinator Activity]" -ForegroundColor Yellow
if (Test-Path $logFile) {
    Get-Content $logFile -Tail 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "  No log file found at $logFile" -ForegroundColor DarkGray
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
