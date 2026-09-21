<#
.SYNOPSIS
    Restarts VpnCoordinator Windows Service on VISH-HOMESERVER.
#>

$ErrorActionPreference = 'Stop'

# Ensure administrator privileges
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Elevating permissions to restart Windows service..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    exit
}

$serviceName = 'VpnCoordinator'
Write-Host "Restarting $serviceName..." -ForegroundColor Cyan
Restart-Service -Name $serviceName -Force
Start-Sleep -Seconds 2

$svc = Get-Service -Name $serviceName
Write-Host "Service status: $($svc.Status)" -ForegroundColor Green
Start-Sleep -Seconds 3
