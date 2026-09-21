<#
.SYNOPSIS
    Uninstalls VpnCoordinator NSSM Windows Service on VISH-HOMESERVER.
#>

$ErrorActionPreference = 'Stop'

# Ensure administrator privileges
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Elevating permissions to uninstall Windows service..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    exit
}

$serviceName = 'VpnCoordinator'
$nssmPath = "C:\Users\Vishnu-Server\AppData\Local\Microsoft\WinGet\Packages\NSSM.NSSM_Microsoft.Winget.Source_8wekyb3d8bbwe\nssm-2.24-101-g897c7ad\win64\nssm.exe"
if (-not (Test-Path $nssmPath)) {
    $cmd = Get-Command nssm -ErrorAction SilentlyContinue
    if ($cmd) { $nssmPath = $cmd.Source }
}

Write-Host "Stopping and removing $serviceName..." -ForegroundColor Cyan
& $nssmPath stop $serviceName 2>$null
& $nssmPath remove $serviceName confirm 2>$null

Write-Host "$serviceName removed successfully." -ForegroundColor Green
Start-Sleep -Seconds 3
