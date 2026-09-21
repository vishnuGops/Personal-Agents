<#
.SYNOPSIS
    Installs VpnCoordinator as an NSSM Windows Service on VISH-HOMESERVER.

.DESCRIPTION
    Requires Administrator elevation. If not elevated, attempts to self-elevate via UAC.
    Uses NSSM to register vpn-coordinator.ps1 to run automatically at boot under LocalSystem.
#>

$ErrorActionPreference = 'Stop'

# Ensure administrator privileges
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Elevating permissions to install Windows service..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    exit
}

$scriptDir = Split-Path -Parent $PSCommandPath
$serviceScript = Join-Path $scriptDir 'vpn-coordinator.ps1'
$serviceName = 'VpnCoordinator'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Installing $serviceName Service via NSSM" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Locate NSSM
$nssmPath = "C:\Users\Vishnu-Server\AppData\Local\Microsoft\WinGet\Packages\NSSM.NSSM_Microsoft.Winget.Source_8wekyb3d8bbwe\nssm-2.24-101-g897c7ad\win64\nssm.exe"
if (-not (Test-Path $nssmPath)) {
    $cmd = Get-Command nssm -ErrorAction SilentlyContinue
    if ($cmd) {
        $nssmPath = $cmd.Source
    } else {
        Write-Host "Error: nssm.exe not found at '$nssmPath' and not in PATH." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}
Write-Host "Using NSSM: $nssmPath" -ForegroundColor Gray

# If existing service is running, stop and remove it
$existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Stopping and removing existing $serviceName service..." -ForegroundColor Yellow
    & $nssmPath stop $serviceName 2>$null
    & $nssmPath remove $serviceName confirm 2>$null
    Start-Sleep -Seconds 2
}

# Install service
$powershellExe = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$appParams = "-NoProfile -ExecutionPolicy Bypass -File `"$serviceScript`""

Write-Host "Installing service '$serviceName'..." -ForegroundColor Cyan
& $nssmPath install $serviceName "$powershellExe" "$appParams"

# Configure NSSM parameters
& $nssmPath set $serviceName AppDirectory "$scriptDir"
& $nssmPath set $serviceName DisplayName "VPN Coordinator (Tailscale/Surfshark)"
& $nssmPath set $serviceName Description "Coordinates Tailscale connection state with Surfshark VPN to enforce mutual exclusion."
& $nssmPath set $serviceName Start SERVICE_AUTO_START

# Logging & file rotation
& $nssmPath set $serviceName AppStdout (Join-Path $scriptDir "vpn-coordinator.service.log")
& $nssmPath set $serviceName AppStderr (Join-Path $scriptDir "vpn-coordinator.err.log")
& $nssmPath set $serviceName AppRotateFiles 1
& $nssmPath set $serviceName AppRotateOnline 1
& $nssmPath set $serviceName AppRotateBytes 5242880
& $nssmPath set $serviceName AppRestartDelay 5000
& $nssmPath set $serviceName AppThrottle 5000

# Start service
Write-Host "Starting '$serviceName'..." -ForegroundColor Cyan
& $nssmPath start $serviceName

Start-Sleep -Seconds 2
$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
    Write-Host "SUCCESS: $serviceName is running with StartType Automatic." -ForegroundColor Green
} else {
    Write-Host "WARNING: Service status is '$($svc.Status)'." -ForegroundColor Yellow
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Service installation complete." -ForegroundColor Green
Start-Sleep -Seconds 3
